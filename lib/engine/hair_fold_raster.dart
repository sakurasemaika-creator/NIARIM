import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/brush.dart';
import 'brush_stroke_geometry.dart';
import 'brush_texture_cache.dart';
import 'tile_manager.dart';

/// One real, pressure/fade-resolved point. Folding never moves its center.
class HairRibbonPoint {
  final Offset position;
  final double width;
  final double opacity;
  const HairRibbonPoint(this.position, this.width, this.opacity);
}

/// Replaces this stroke over its original tiles, so the front surface can hide
/// an earlier outline without erasing the artwork underneath. All masks use
/// maximum coverage; a translucent stroke is composited only once.
class HairFoldRaster {
  final TileManager tiles;
  final String layer;
  final Map<String, Uint8List?> _before = {};
  final Map<int, _RunCache> _runs = {};
  Brush? _cachedBrush;
  Uint8List? _cachedTexture;
  HairFoldRaster(this.tiles, this.layer);

  void rememberTile(int tx, int ty) {
    final key = '$tx,$ty';
    if (_before.containsKey(key)) return;
    final tile = tiles.getTile(layer, tx, ty);
    _before[key] = tile == null ? null : Uint8List.fromList(tile);
  }

  void render({
    required List<HairRibbonPoint> points,
    required List<FoldEvent> folds,
    required Brush brush,
    required Color fillColor,
    Uint8List? texture,
  }) {
    if (points.length < 3 || folds.isEmpty) return;
    if (!identical(brush, _cachedBrush) ||
        !identical(texture, _cachedTexture)) {
      _runs.clear();
      _cachedBrush = brush;
      _cachedTexture = texture;
    }
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(
        lengths.last + (points[i].position - points[i - 1].position).distance,
      );
    }
    final candidates = <({int index, double strength, double sign})>[];
    for (final fold in folds) {
      final source = fold.sourceCurve;
      if (source.length < 3) continue;
      // Locate the bend itself, rather than the detector's delayed endpoint.
      var best = 0.0;
      var pivotSourceIndex = source.length ~/ 2;
      var pivot = source[pivotSourceIndex];
      for (var i = 1; i < source.length - 1; i++) {
        final a = source[i] - source[i - 1];
        final b = source[i + 1] - source[i];
        if (a.distance < .001 || b.distance < .001) continue;
        final turn = math.atan2(_cross(a, b), _dot(a, b)).abs();
        if (turn > best) {
          best = turn;
          pivot = source[i];
          pivotSourceIndex = i;
        }
      }
      var nearest = fold.sourceIndices.length == source.length
          ? fold.sourceIndices[pivotSourceIndex] ?? 0
          : 0;
      var error = double.infinity;
      for (
        var i = nearest > 0 ? points.length : 1;
        i < points.length - 1;
        i++
      ) {
        final d = (points[i].position - pivot).distanceSquared;
        if (d < error) {
          error = d;
          nearest = i;
        }
      }
      if (nearest > 0) {
        candidates.add((
          index: nearest,
          strength: best,
          sign: fold.signedTurnRadians.sign,
        ));
      }
    }
    candidates.sort((a, b) => a.index.compareTo(b.index));
    final bends = <({int index, double strength, double sign})>[];
    for (final candidate in candidates) {
      if (bends.isNotEmpty &&
          bends.last.sign == candidate.sign &&
          lengths[candidate.index] - lengths[bends.last.index] <
              points[candidate.index].width * 2) {
        if (candidate.strength > bends.last.strength) {
          bends[bends.length - 1] = candidate;
        }
      } else {
        bends.add(candidate);
      }
    }
    final indices = <int>{
      0,
      ...bends.map((b) => b.index),
      points.length - 1,
    }.toList()..sort();
    if (indices.length < 3) return;
    if (brush.foldMode == HairFoldMode.crescent) {
      final bendIndices = indices.sublist(1, indices.length - 1);
      indices.clear();
      indices.add(0);
      for (var i = 1; i < bendIndices.length; i++) {
        final target =
            (lengths[bendIndices[i - 1]] + lengths[bendIndices[i]]) / 2;
        indices.add(lengths.indexWhere((d) => d >= target));
      }
      indices.add(points.length - 1);
    }
    final result = <int, _SurfaceTile>{};

    final sourcePoints = points;
    final repeats = lateralOffsets(
      count: brush.lateralRepeatEnabled ? brush.lateralRepeatCount : 1,
      spacing: brush.lateralRepeatSpacing.clamp(0.0, 4.0).toDouble(),
    );
    var repeatIndex = 0;
    for (final offset in repeats) {
      final ownerBase = repeatIndex++ * indices.length;
      points = offset == 0
          ? sourcePoints
          : List.generate(sourcePoints.length, (i) {
              final p = sourcePoints[i];
              final before = sourcePoints[math.max(0, i - 1)].position;
              final after =
                  sourcePoints[math.min(sourcePoints.length - 1, i + 1)]
                      .position;
              final tangent = _unit(after - before);
              return HairRibbonPoint(
                p.position + Offset(-tangent.dy, tangent.dx) * p.width * offset,
                p.width,
                p.opacity,
              );
            });
      if (brush.foldMode == HairFoldMode.crescent) {
        // The authored stroke is the crescent centerline. Smooth only sampling
        // noise; do not move it toward either outline. Outer/inner curvature is
        // produced explicitly by the asymmetric width sweep below.
        points = _smoothCrescentCenterline(points);
      }
      final runs = <_RibbonRun>[];
      for (var i = 1; i < indices.length; i++) {
        final start = indices[i - 1], end = indices[i];
        if (end <= start) continue;
        final a = points[start].position, b = points[end].position;
        final diagonal = (b.dx - a.dx) * (b.dy - a.dy);
        final y = (a.dy + b.dy) / 2;
        final depth = switch (brush.foldMode) {
          HairFoldMode.waveTopView => -y,
          HairFoldMode.waveLowAngle => y,
          HairFoldMode.curlRight => (diagonal >= 0 ? 1e8 : 0) - y,
          HairFoldMode.curlLeft => (diagonal < 0 ? 1e8 : 0) - y,
          HairFoldMode.crescent => i.toDouble(),
        };
        runs.add(_RibbonRun(start, end, depth, ownerBase + i));
      }
      runs.sort((a, b) => a.depth.compareTo(b.depth));
      for (final run in runs) {
        final canCache = offset == 0;
        final cached = canCache ? _runs[run.start] : null;
        final reusable =
            cached != null &&
            cached.end <= run.end &&
            (brush.foldMode != HairFoldMode.crescent ||
                cached.end == run.end) &&
            _samePoint(cached.last, points[cached.end]) &&
            _samePoint(cached.first, points[run.start]);
        final mask = reusable ? cached.mask : <int, _MaskTile>{};
        final segmentStart = reusable ? cached.end + 1 : run.start + 1;
        final runLength = lengths[run.end] - lengths[run.start];
        for (var i = segmentStart; i <= run.end; i++) {
          var a = points[i - 1], b = points[i];
          if (brush.foldMode != HairFoldMode.crescent &&
              a.width == b.width &&
              a.opacity == b.opacity) {
            final direction = b.position - a.position;
            while (i < run.end && direction.distanceSquared > 1e-10) {
              final next = points[i + 1],
                  delta = points[i + 1].position - a.position;
              if (next.width != a.width ||
                  next.opacity != a.opacity ||
                  _cross(direction, delta).abs() > 1e-7 ||
                  _dot(delta, direction) <
                      _dot(b.position - a.position, direction)) {
                break;
              }
              b = next;
              i++;
            }
          }
          if (brush.foldMode == HairFoldMode.crescent) {
            double widthAt(int index) {
              final t =
                  ((lengths[index] - lengths[run.start]) /
                          math.max(.001, runLength))
                      .clamp(0.0, 1.0);
              // A crescent must leave and rejoin the authored curve with a
              // rounded tangent. Smoothstep the half-sine phase instead of
              // applying a sub-linear power near the tips; the old profile
              // produced a pinched V-shaped inner edge.
              final phase = t * t * (3 - 2 * t);
              final strength = (brush.foldCurveStrength - 1) / 9;
              final profile = math.sin(math.pi * phase);
              final rounded = math.pow(
                profile.clamp(0.0, 1.0),
                1.0 + strength * .35,
              ).toDouble();
              // The configured brush width is the crescent's full
              // thickness at its middle. Both sides converge continuously to
              // the authored centerline at the two tips.
              return points[index].width * rounded;
            }

            a = HairRibbonPoint(a.position, widthAt(i - 1), a.opacity);
            b = HairRibbonPoint(b.position, widthAt(i), b.opacity);
          }
          if (texture == null) {
            if (brush.foldMode == HairFoldMode.crescent) {
              _crescentSegment(mask, a, b, brush.outlineWidth);
            } else {
              _segment(mask, a, b, brush.outlineWidth);
            }
          } else {
            _texturedSegment(mask, a, b, brush, texture);
          }
        }
        if (canCache) {
          _runs[run.start] = _RunCache(
            run.end,
            points[run.start],
            points[run.end],
            mask,
          );
        }
        for (final entry in mask.entries) {
          final surface = result.putIfAbsent(entry.key, _SurfaceTile.new);
          final m = entry.value;
          final tileOrigin = Offset(
            (entry.key % tiles.tilesX) * _size.toDouble(),
            (entry.key ~/ tiles.tilesX) * _size.toDouble(),
          );
          final start = points[run.start].position,
              end = points[run.end].position;
          final startTangent = points[run.start + 1].position - start;
          final endTangent = end - points[run.end - 1].position;
          for (var p = 0; p < _pixels; p++) {
            final cover = m.outer[p];
            if (cover <= 0) continue;
            final fill = m.fill[p];
            final ink = cover * m.opacity[p];
            if (ink <= 0) continue;
            surface.shape[p] = math.max(surface.shape[p], cover);
            surface.outer[p] = math.max(surface.outer[p], ink);
            surface.fill[p] = math.max(surface.fill[p], fill * m.opacity[p]);
            var edge = (cover - fill).clamp(0.0, 1.0);
            if (edge > 0 && brush.foldMode != HairFoldMode.crescent) {
              final at = tileOrigin + Offset(p % _size + .5, p ~/ _size + .5);
              if ((run.start > 0 && _dot(at - start, startTangent) < 0) ||
                  (run.end < points.length - 1 &&
                      _dot(at - end, endTangent) > 0)) {
                edge = 0;
              }
            }
            // A stroke keeps maximum ink coverage across its faces. Equal
            // opacity front ink hides rear edges; weaker or invisible ink
            // cannot erase a stronger face beneath it.
            final total = math.max(ink, surface.cover[p]);
            final front = ink / total;
            surface.outline[p] =
                edge / cover * front + surface.outline[p] * (1 - front);
            surface.cover[p] = total;
            if (front > .5) surface.owner[p] = run.id;
          }
        }
      }
      // The visible inner edge continues a short distance into the bend and
      // tapers there. Its tangent comes from the chosen front section.
      if (brush.foldMode != HairFoldMode.crescent) {
        for (var i = 1; i < indices.length - 1; i++) {
          final pivot = indices[i];
          final p = points[pivot];
          final before = points[math.max(indices[i - 1], pivot - 8)].position;
          final after = points[math.min(indices[i + 1], pivot + 8)].position;
          final incoming = _unit(p.position - before),
              outgoing = _unit(after - p.position);
          final sign = _cross(incoming, outgoing).sign;
          if (sign == 0) continue;
          final inward =
              _unit(
                Offset(-incoming.dy - outgoing.dy, incoming.dx + outgoing.dx),
              ) *
              sign;
          final firstFront = switch (brush.foldMode) {
            HairFoldMode.waveTopView => before.dy <= after.dy,
            HairFoldMode.waveLowAngle => before.dy > after.dy,
            HairFoldMode.curlRight =>
              incoming.dx * incoming.dy >= outgoing.dx * outgoing.dy,
            HairFoldMode.curlLeft =>
              incoming.dx * incoming.dy < outgoing.dx * outgoing.dy,
            HairFoldMode.crescent => true,
          };
          final direction = firstFront ? incoming : -outgoing;
          final continuation = firstFront ? outgoing : -incoming;
          var origin = p.position;
          for (var distance = .5; distance < p.width * 2; distance += .5) {
            final at = p.position + inward * distance;
            if (!_covered(result, at)) break;
            origin = at;
          }
          final length = p.width * brush.foldLengthRatio.clamp(0.0, 2.0);
          final delay = brush.foldCurveStartRatio.clamp(0.0, 1.0);
          final bend = (brush.foldCurveStrength - 1) / 9;
          var previous = origin;
          final count = math.max(4, (length * 2).ceil());
          for (var step = 1; step <= count; step++) {
            final t = step / count;
            final u = ((t - delay) / math.max(.001, 1 - delay)).clamp(0.0, 1.0);
            final at =
                origin +
                direction * (length * t * .65) +
                continuation * (length * u * u * bend * .35);
            final taper = brush.foldEndTaperRatio.clamp(.01, 1.0);
            final lineWidth =
                brush.outlineWidth *
                (1 - ((t - (1 - taper)) / taper).clamp(0.0, 1.0));
            _crease(result, previous, at, lineWidth, ownerBase + i, p.opacity);
            previous = at;
          }
        }
      }
    }
    _runs.removeWhere((start, _) => !indices.contains(start));
    tiles.applyTileSnapshot(layer, _before);
    final outline = Color(brush.outlineColor);
    for (final entry in result.entries) {
      final tx = entry.key % tiles.tilesX, ty = entry.key ~/ tiles.tilesX;
      rememberTile(tx, ty);
      final target = tiles.getOrCreateTile(layer, tx, ty);
      final s = entry.value;
      for (var p = 0; p < _pixels; p++) {
        if (s.cover[p] <= 0) continue;
        final perimeter = (s.outer[p] - s.fill[p]) / s.cover[p];
        final mix = math.max(s.outline[p], perimeter).clamp(0.0, 1.0);
        final color = Color.lerp(fillColor, outline, mix)!;
        final alpha = (255 * s.cover[p] * color.a).round().clamp(0, 255);
        if (alpha == 0) continue;
        tiles.blendPixel(
          target,
          p % _size,
          p ~/ _size,
          (color.r * 255).round(),
          (color.g * 255).round(),
          (color.b * 255).round(),
          alpha,
        );
      }
      tiles.markDirty(layer, tx, ty);
    }
  }

  void _crescentSegment(
    Map<int, _MaskTile> masks,
    HairRibbonPoint a,
    HairRibbonPoint b,
    double outline,
  ) {
    final d = b.position - a.position;
    final squared = d.distanceSquared;
    if (squared < 1e-10) return;
    final tangent = _unit(d);
    final normal = Offset(-tangent.dy, tangent.dx);
    // Build the two crescent outlines directly from the authored centerline.
    // The outside bows farther than a normal ribbon offset while the inside
    // stays closer to the centerline, so both are smooth curves rather than a
    // union cusp that must be repaired afterward.
    final turnBias = _cross(a.position, b.position).sign;
    final outerScale = 1.18;
    final innerScale = .82;
    final side = turnBias == 0 ? 1.0 : turnBias;
    final aOuter = a.position + normal * (a.width * .5 * outerScale * side);
    final bOuter = b.position + normal * (b.width * .5 * outerScale * side);
    final aInner = a.position - normal * (a.width * .5 * innerScale * side);
    final bInner = b.position - normal * (b.width * .5 * innerScale * side);
    _quadStrip(masks, aInner, aOuter, bInner, bOuter, a.opacity, b.opacity, outline);
  }

  void _quadStrip(
    Map<int, _MaskTile> masks,
    Offset aInner,
    Offset aOuter,
    Offset bInner,
    Offset bOuter,
    double opacityA,
    double opacityB,
    double outline,
  ) {
    final minX = math.min(math.min(aInner.dx, aOuter.dx), math.min(bInner.dx, bOuter.dx));
    final maxX = math.max(math.max(aInner.dx, aOuter.dx), math.max(bInner.dx, bOuter.dx));
    final minY = math.min(math.min(aInner.dy, aOuter.dy), math.min(bInner.dy, bOuter.dy));
    final maxY = math.max(math.max(aInner.dy, aOuter.dy), math.max(bInner.dy, bOuter.dy));
    final left = (minX - outline - 1).floor().clamp(0, tiles.canvasWidth - 1);
    final right = (maxX + outline + 1).ceil().clamp(0, tiles.canvasWidth - 1);
    final top = (minY - outline - 1).floor().clamp(0, tiles.canvasHeight - 1);
    final bottom = (maxY + outline + 1).ceil().clamp(0, tiles.canvasHeight - 1);
    final centerA = (aInner + aOuter) * .5;
    final centerB = (bInner + bOuter) * .5;
    final centerDelta = centerB - centerA;
    final centerSquared = centerDelta.distanceSquared;
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final at = Offset(x + .5, y + .5);
        final t = centerSquared < 1e-10
            ? 0.0
            : (_dot(at - centerA, centerDelta) / centerSquared).clamp(0.0, 1.0);
        final inner = Offset.lerp(aInner, bInner, t)!;
        final outer = Offset.lerp(aOuter, bOuter, t)!;
        final span = outer - inner;
        final spanSquared = span.distanceSquared;
        if (spanSquared < 1e-10) continue;
        final across = (_dot(at - inner, span) / spanSquared).clamp(0.0, 1.0);
        final nearest = inner + span * across;
        final distance = (at - nearest).distance;
        final insideProjection = _dot(at - inner, span) / spanSquared;
        final inside = insideProjection >= 0 && insideProjection <= 1;
        final fill = inside ? (1.0 - distance).clamp(0.0, 1.0) : 0.0;
        final outerCoverage = inside
            ? 1.0
            : (outline + .5 - distance).clamp(0.0, 1.0);
        if (outerCoverage <= 0 && fill <= 0) continue;
        final key = (y ~/ _size) * tiles.tilesX + x ~/ _size;
        final mask = masks.putIfAbsent(key, _MaskTile.new);
        final p = (y % _size) * _size + x % _size;
        final opacity = opacityA + (opacityB - opacityA) * t;
        if (fill > mask.fill[p]) mask.opacity[p] = opacity;
        mask.fill[p] = math.max(mask.fill[p], fill);
        mask.outer[p] = math.max(mask.outer[p], math.max(fill, outerCoverage));
      }
    }
  }

  void _segment(
    Map<int, _MaskTile> masks,
    HairRibbonPoint a,
    HairRibbonPoint b,
    double outline,
  ) {
    final d = b.position - a.position;
    final squared = d.distanceSquared;
    if (squared < 1e-10) return;
    final radius = math.max(a.width, b.width) / 2 + outline + 1;
    final left = (math.min(a.position.dx, b.position.dx) - radius)
        .floor()
        .clamp(0, tiles.canvasWidth - 1);
    final right = (math.max(a.position.dx, b.position.dx) + radius)
        .ceil()
        .clamp(0, tiles.canvasWidth - 1);
    final top = (math.min(a.position.dy, b.position.dy) - radius).floor().clamp(
      0,
      tiles.canvasHeight - 1,
    );
    final bottom = (math.max(a.position.dy, b.position.dy) + radius)
        .ceil()
        .clamp(0, tiles.canvasHeight - 1);
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final delta = Offset(x + .5, y + .5) - a.position;
        final radiusDelta = (b.width - a.width) / 2;
        final length = math.sqrt(squared);
        final projection = _dot(delta, d) / length;
        final perpendicular = _cross(d, delta).abs() / length;
        final slope = radiusDelta / length;
        final t = slope.abs() >= 1
            ? (slope > 0 ? 1.0 : 0.0)
            : ((projection +
                          slope *
                              perpendicular /
                              math.sqrt(1 - slope * slope)) /
                      length)
                  .clamp(0.0, 1.0);
        final offset = delta - d * t;
        final distance = offset.distance;
        final half = (a.width + (b.width - a.width) * t) / 2;
        final outer = (half + outline + .5 - distance).clamp(0.0, 1.0);
        if (outer <= 0) continue;
        final fill = (half + .5 - distance).clamp(0.0, 1.0);
        final opacity = a.opacity + (b.opacity - a.opacity) * t;
        final key = (y ~/ _size) * tiles.tilesX + (x ~/ _size);
        final m = masks.putIfAbsent(key, _MaskTile.new);
        final p = (y % _size) * _size + (x % _size);
        if (fill > m.fill[p]) {
          m.opacity[p] = opacity;
        } else if (fill == m.fill[p]) {
          m.opacity[p] = math.max(m.opacity[p], opacity);
        }
        m.outer[p] = math.max(m.outer[p], outer);
        m.fill[p] = math.max(m.fill[p], fill);
      }
    }
  }

  // Sweep the selected authored tip itself, including its endpoints and
  // fixed/rotating orientation; never flatten it into a one-dimensional mask.
  void _texturedSegment(
    Map<int, _MaskTile> masks,
    HairRibbonPoint a,
    HairRibbonPoint b,
    Brush brush,
    Uint8List texture,
  ) {
    final delta = b.position - a.position;
    final steps = math.max(1, delta.distance.ceil());
    final angle =
        (brush.rotation ? math.atan2(delta.dy, delta.dx) : 0.0) +
        (brush.calligraphyAngle ?? 0) * math.pi / 180;
    final cosA = math.cos(-angle), sinA = math.sin(-angle);
    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      final center = a.position + delta * t;
      final radius = math.max(.001, (a.width + (b.width - a.width) * t) / 2);
      final outerRadius = radius + brush.outlineWidth;
      final opacity = a.opacity + (b.opacity - a.opacity) * t;
      final left = (center.dx - outerRadius - 1).floor().clamp(
        0,
        tiles.canvasWidth - 1,
      );
      final right = (center.dx + outerRadius + 1).ceil().clamp(
        0,
        tiles.canvasWidth - 1,
      );
      final top = (center.dy - outerRadius - 1).floor().clamp(
        0,
        tiles.canvasHeight - 1,
      );
      final bottom = (center.dy + outerRadius + 1).ceil().clamp(
        0,
        tiles.canvasHeight - 1,
      );
      for (var y = top; y <= bottom; y++) {
        for (var x = left; x <= right; x++) {
          final dx = x + .5 - center.dx, dy = y + .5 - center.dy;
          final u = dx * cosA - dy * sinA, v = dx * sinA + dy * cosA;
          final distSquared = u * u + v * v;
          double coverage(double r) {
            if (distSquared > r * r) return 0;
            final tx = (((u / r + 1) / 2) * (brushTextureSize - 1))
                .round()
                .clamp(0, brushTextureSize - 1);
            final ty = (((v / r + 1) / 2) * (brushTextureSize - 1))
                .round()
                .clamp(0, brushTextureSize - 1);
            return texture[(ty * brushTextureSize + tx) * 4 + 3] / 255;
          }

          final fill = coverage(radius);
          final outer = math.max(fill, coverage(outerRadius));
          if (outer <= 0) continue;
          final key = (y ~/ _size) * tiles.tilesX + x ~/ _size;
          final mask = masks.putIfAbsent(key, _MaskTile.new);
          final p = (y % _size) * _size + x % _size;
          if (fill > mask.fill[p]) {
            mask.opacity[p] = opacity;
          } else if (fill == mask.fill[p]) {
            mask.opacity[p] = math.max(mask.opacity[p], opacity);
          }
          mask.fill[p] = math.max(mask.fill[p], fill);
          mask.outer[p] = math.max(mask.outer[p], outer);
        }
      }
    }
  }

  bool _covered(Map<int, _SurfaceTile> surface, Offset at) {
    final x = at.dx.floor(), y = at.dy.floor();
    if (x < 0 || y < 0 || x >= tiles.canvasWidth || y >= tiles.canvasHeight) {
      return false;
    }
    final tile = surface[(y ~/ _size) * tiles.tilesX + x ~/ _size];
    return tile != null && tile.shape[(y % _size) * _size + x % _size] > .5;
  }

  void _crease(
    Map<int, _SurfaceTile> masks,
    Offset a,
    Offset b,
    double width,
    int owner,
    double opacity,
  ) {
    final d = b - a;
    if (d.distanceSquared < 1e-10 || width <= 0) return;
    final left = (math.min(a.dx, b.dx) - width - 1).floor().clamp(
      0,
      tiles.canvasWidth - 1,
    );
    final right = (math.max(a.dx, b.dx) + width + 1).ceil().clamp(
      0,
      tiles.canvasWidth - 1,
    );
    final top = (math.min(a.dy, b.dy) - width - 1).floor().clamp(
      0,
      tiles.canvasHeight - 1,
    );
    final bottom = (math.max(a.dy, b.dy) + width + 1).ceil().clamp(
      0,
      tiles.canvasHeight - 1,
    );
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final delta = Offset(x + .5, y + .5) - a;
        final t = (_dot(delta, d) / d.distanceSquared).clamp(0.0, 1.0);
        final coverage = (width / 2 + .5 - (delta - d * t).distance).clamp(
          0.0,
          1.0,
        );
        if (coverage <= 0) continue;
        final s = masks[(y ~/ _size) * tiles.tilesX + x ~/ _size];
        if (s == null) continue;
        final p = (y % _size) * _size + x % _size;
        // Never draw a crease outside the actual ribbon silhouette.
        if (s.cover[p] > 0 &&
            s.shape[p] > .5 &&
            (s.owner[p] == owner || s.owner[p] == owner + 1)) {
          s.outline[p] = math.max(
            s.outline[p],
            coverage * (opacity / s.cover[p]).clamp(0.0, 1.0),
          );
        }
      }
    }
  }
}

const _size = TileManager.tileSize;
const _pixels = _size * _size;

class _MaskTile {
  final outer = Float32List(_pixels),
      fill = Float32List(_pixels),
      opacity = Float32List(_pixels);
}

class _SurfaceTile {
  final owner = Int32List(_pixels);
  final outer = Float32List(_pixels), fill = Float32List(_pixels);
  final cover = Float32List(_pixels),
      outline = Float32List(_pixels),
      shape = Float32List(_pixels);
}

class _RibbonRun {
  final int start, end, id;
  final double depth;
  const _RibbonRun(this.start, this.end, this.depth, this.id);
}


List<HairRibbonPoint> _smoothCrescentCenterline(
  List<HairRibbonPoint> source,
) {
  if (source.length < 3) return source;
  var current = List<HairRibbonPoint>.from(source);
  for (var pass = 0; pass < 6; pass++) {
    final next = List<HairRibbonPoint>.from(current);
    for (var i = 1; i < current.length - 1; i++) {
      final before = current[i - 1], at = current[i], after = current[i + 1];
      final position =
          before.position * .25 + at.position * .5 + after.position * .25;
      next[i] = HairRibbonPoint(position, at.width, at.opacity);
    }
    current = next;
  }
  current[0] = source[0];
  current[current.length - 1] = source.last;
  return current;
}

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
Offset _unit(Offset a) => a.distance < 1e-9 ? Offset.zero : a / a.distance;

class _RunCache {
  final int end;
  final HairRibbonPoint first, last;
  final Map<int, _MaskTile> mask;
  const _RunCache(this.end, this.first, this.last, this.mask);
}

bool _samePoint(HairRibbonPoint a, HairRibbonPoint b) =>
    a.position == b.position && a.width == b.width && a.opacity == b.opacity;
