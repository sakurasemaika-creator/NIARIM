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
    final candidates =
        <({int index, double strength, double sign, bool continuous})>[];
    for (final fold in folds) {
      final source = fold.sourceCurve;
      if (source.length < 3) continue;
      // A direction-change fold belongs at the strongest local bend. A
      // continuous 270-degree fold has no single sharp bend, so place it at
      // the detector's cumulative-turn boundary instead of arbitrarily picking
      // one equally curved sample from the arc.
      var best = 0.0;
      var pivotSourceIndex = source.length ~/ 2;
      var pivot = source[pivotSourceIndex];
      final continuousTurnFold = fold.isContinuousTurnFold;
      if (continuousTurnFold) {
        pivotSourceIndex = source.length - 1;
        pivot = source.last;
        best = fold.signedTurnRadians.abs();
      } else {
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
          continuous: continuousTurnFold,
        ));
      }
    }
    candidates.sort((a, b) => a.index.compareTo(b.index));
    final bends =
        <({int index, double strength, double sign, bool continuous})>[];
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
      // Once folding is active, every actual reversal separates crescents.
      // Detector cooldown may skip a small final curl; midpoints between its
      // sparse events can then put both turn directions in one crescent.
      final crescentBoundaries = <int>{
        0,
        points.length - 1,
        ..._curveReversals(points, lengths),
        ...bends.where((bend) => bend.continuous).map((bend) => bend.index),
      };
      indices
        ..clear()
        ..addAll(crescentBoundaries.toList()..sort());
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
      // The engine already resolved stabilization. Keep these authored centers
      // unchanged; only the outline normals and width profile are derived here.
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
      final crescentTangents = <int, Offset>{};
      final crescentWidths = <int, double>{};
      final crescentSides = <int, double>{};
      if (brush.foldMode == HairFoldMode.crescent) {
        final radii = <double>[];
        final turns = <double>[];
        // Measure curvature over document distance, not adjacent events:
        // interpolated pointer samples alternate straight sections and tiny
        // corners. A per-sample width clamp creates dents at those corners.
        for (var index = 0; index < points.length; index++) {
          final reach = math.max(.5, points[index].width * .3);
          final before = _positionAtDistance(
            points,
            lengths,
            lengths[index] - reach,
          );
          final after = _positionAtDistance(
            points,
            lengths,
            lengths[index] + reach,
          );
          final incoming = points[index].position - before;
          final outgoing = after - points[index].position;
          crescentTangents[index] = _unit(after - before);
          radii.add(_curveRadius(before, points[index].position, after));
          turns.add(
            incoming.distanceSquared < 1e-8 || outgoing.distanceSquared < 1e-8
                ? 0
                : math.atan2(
                    _cross(incoming, outgoing),
                    _dot(incoming, outgoing),
                  ),
          );
        }
        var groupStart = 0;
        var limit = double.infinity;
        var strongestTurn = 0.0;
        var groupTurn = 0.0;
        for (var boundary = 1; boundary < indices.length; boundary++) {
          final start = indices[boundary - 1], end = indices[boundary];
          for (var index = start; index <= end; index++) {
            if (index > start) {
              final a = crescentTangents[index - 1]!,
                  b = crescentTangents[index]!;
              groupTurn += math.atan2(_cross(a, b), _dot(a, b)).abs();
            }
            if (turns[index].abs() > strongestTurn.abs()) {
              strongestTurn = turns[index];
            }
            final reach = math.max(.5, points[index].width * .3);
            if (lengths[index] < reach ||
                lengths.last - lengths[index] < reach) {
              continue;
            }
            limit = math.min(
              limit,
              math.max(.5, 2 * (radii[index] * .7 - brush.outlineWidth)),
            );
          }
          final continues = bends.any(
            (bend) => bend.index == end && bend.continuous,
          );
          if (!continues || boundary == indices.length - 1) {
            // A very short or nearly straight terminal arc cannot support a
            // full-width crescent. Scale its envelope to its actual bend so
            // its tip remains a curl rather than a round bead.
            final groupLength = lengths[end] - lengths[indices[groupStart]];
            limit = math.min(
              limit,
              math.max(
                .5,
                groupLength * math.sin(math.min(math.pi, groupTurn) / 2) * .5,
              ),
            );
            // Continuous folds share one width and orientation at their neck.
            // Reversal boundaries start an independent crescent again.
            for (var member = groupStart; member < boundary; member++) {
              crescentWidths[indices[member]] = limit;
              crescentSides[indices[member]] = strongestTurn == 0
                  ? 1
                  : strongestTurn.sign;
            }
            groupStart = boundary;
            limit = double.infinity;
            strongestTurn = 0;
            groupTurn = 0;
          }
        }
      }
      runs.sort((a, b) => a.depth.compareTo(b.depth));
      for (final run in runs) {
        final runLength = lengths[run.end] - lengths[run.start];
        final crescentWidthLimit = crescentWidths[run.start] ?? double.infinity;
        final startsContinuous =
            run.start > 0 &&
            bends.any((bend) => bend.index == run.start && bend.continuous);
        final endsContinuous =
            run.end < points.length - 1 &&
            bends.any((bend) => bend.index == run.end && bend.continuous);
        final geometry = brush.foldMode == HairFoldMode.crescent
            ? <Object>[
                crescentWidthLimit,
                crescentSides[run.start]!,
                startsContinuous,
                endsContinuous,
                for (var index = run.start; index <= run.end; index++)
                  (
                    points[index].position,
                    points[index].width,
                    points[index].opacity,
                    crescentTangents[index],
                    lengths[index] - lengths[run.start],
                  ),
              ]
            : null;
        final canCache = offset == 0;
        final cached = canCache ? _runs[run.start] : null;
        final reusable =
            cached != null &&
            cached.end <= run.end &&
            (brush.foldMode != HairFoldMode.crescent ||
                (cached.end == run.end &&
                    _sameGeometry(cached.geometry, geometry))) &&
            _samePoint(cached.last, points[cached.end]) &&
            _samePoint(cached.first, points[run.start]);
        final mask = reusable ? cached.mask : <int, _MaskTile>{};
        final segmentStart = reusable ? cached.end + 1 : run.start + 1;
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
              final rounded = math
                  .pow(profile.clamp(0.0, 1.0), 1.0 + strength * .35)
                  .toDouble();
              // The configured brush width is the crescent's full
              // thickness at its middle. Authored/reversal tips converge to
              // the centerline. At a cumulative 270-degree boundary the curve
              // is still turning in the same direction, so adjacent crescents
              // share a small neck instead of pinching to zero and reopening.
              var joined = rounded;
              // A shared 270-degree boundary should read as the waist
              // between two consecutive crescents, not as a near-zero cut.
              // Keep most of the configured width at the join
              // and ease that support away over the neighboring segment.
              const neck = .72;
              // A continuous 270-degree fold is a fold *inside one ribbon*, not the
              // tip of one crescent followed by the tip of another. Preserve a
              // broad waist at that boundary and blend it over the adjacent
              // third so the outline stays C1-like instead of forming a cusp.
              if (startsContinuous && t < .34) {
                final local = (t / .34).clamp(0.0, 1.0);
                final ease = local * local * (3 - 2 * local);
                joined = math.max(joined, neck * (1 - ease));
              }
              if (endsContinuous && t > .66) {
                final local = ((t - .66) / .34).clamp(0.0, 1.0);
                final ease = local * local * (3 - 2 * local);
                joined = math.max(joined, neck * ease);
              }
              if (startsContinuous && !endsContinuous) {
                // Immediately after a continuous fold there may be too little
                // travel for another full crescent. Finish that shared neck
                // with a rounded cap, easing into the normal profile as the
                // next arc grows, instead of swelling wider than the join.
                final width = math.min(
                  points[run.start].width,
                  crescentWidthLimit,
                );
                final shortness =
                    ((width - runLength) / math.max(.001, width * .5)).clamp(
                      0.0,
                      1.0,
                    );
                final cap = neck * math.sqrt(math.max(0.0, 1 - t * t));
                joined = joined * (1 - shortness) + cap * shortness;
              }
              return math.min(points[index].width, crescentWidthLimit) * joined;
            }

            a = HairRibbonPoint(a.position, widthAt(i - 1), a.opacity);
            b = HairRibbonPoint(b.position, widthAt(i), b.opacity);
          }
          if (texture == null) {
            if (brush.foldMode == HairFoldMode.crescent) {
              _crescentSegment(
                mask,
                a,
                b,
                brush.outlineWidth,
                turnSide: crescentSides[run.start]!,
                tangentA: crescentTangents[i - 1]!,
                tangentB: crescentTangents[i]!,
              );
            } else {
              _segment(mask, a, b, brush.outlineWidth);
            }
          } else {
            _texturedSegment(
              mask,
              a,
              b,
              brush,
              texture,
              tangentA: crescentTangents[i - 1],
              tangentB: crescentTangents[i],
            );
          }
        }
        if (canCache) {
          _runs[run.start] = _RunCache(
            run.end,
            points[run.start],
            points[run.end],
            mask,
            geometry: geometry,
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
          for (var row = m.top; row <= m.bottom; row++) {
            for (
              var p = row * _size + m.left[row];
              p <= row * _size + m.right[row];
              p++
            ) {
              final cover = m.outer[p];
              if (cover <= 0) continue;
              final fill = m.fill[p];
              final ink = cover * m.opacity[p];
              if (ink <= 0) continue;
              if (surface.cover[p] <= 0) surface.include(p);
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
              // Crescents form a single surface: only the union perimeter below
              // is visible, never a cross-section cap between connected runs.
              surface.outline[p] = brush.foldMode == HairFoldMode.crescent
                  ? 0
                  : edge / cover * front + surface.outline[p] * (1 - front);
              surface.cover[p] = total;
              if (front > .5) surface.owner[p] = run.id;
            }
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
          // A continuous 270-degree fold keeps the authored turn direction.
          // It still needs a visible fold cue for the two wave views, but use
          // a shorter, later crease than a true direction reversal so it does
          // not read as a cusp or spike.
          final continuous = bends[i - 1].continuous;
          final length =
              p.width *
              brush.foldLengthRatio.clamp(0.0, 2.0) *
              (continuous ? .32 : 1.0);
          final delay = continuous
              ? math.max(.50, brush.foldCurveStartRatio.clamp(0.0, 1.0))
              : brush.foldCurveStartRatio.clamp(0.0, 1.0);
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
      for (var row = s.top; row <= s.bottom; row++) {
        for (
          var p = row * _size + s.left[row];
          p <= row * _size + s.right[row];
          p++
        ) {
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
      }
      tiles.markDirty(layer, tx, ty);
    }
  }

  void _crescentSegment(
    Map<int, _MaskTile> masks,
    HairRibbonPoint a,
    HairRibbonPoint b,
    double outline, {
    required double turnSide,
    required Offset tangentA,
    required Offset tangentB,
  }) {
    // Reuse the outline pen's analytic variable-width envelope. Independent
    // quadrilateral caps made a short crescent polygonal; round envelope joins
    // stay smooth even when only a few pointer samples describe the curl.
    // The normal offset distributes .59 of the width outside and .41 inside
    // the authored curve, without generating or resmoothing a centerline.
    final inwardA = Offset(-tangentA.dy, tangentA.dx) * turnSide;
    final inwardB = Offset(-tangentB.dy, tangentB.dx) * turnSide;
    _segment(
      masks,
      HairRibbonPoint(
        a.position - inwardA * (a.width * .09),
        a.width,
        a.opacity,
      ),
      HairRibbonPoint(
        b.position - inwardB * (b.width * .09),
        b.width,
        b.opacity,
      ),
      outline,
    );
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
        if (m.outer[p] <= 0) m.include(p);
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
    Uint8List texture, {
    Offset? tangentA,
    Offset? tangentB,
  }) {
    final delta = b.position - a.position;
    final steps = math.max(1, delta.distance.ceil());
    final crescent = brush.foldMode == HairFoldMode.crescent;
    final startTangent = tangentA ?? delta;
    final endTangent = tangentB ?? delta;
    final startAngle = math.atan2(startTangent.dy, startTangent.dx);
    final endAngle = math.atan2(endTangent.dy, endTangent.dx);
    final angleDelta = math.atan2(
      math.sin(endAngle - startAngle),
      math.cos(endAngle - startAngle),
    );
    final fixedAngle = brush.rotation ? math.atan2(delta.dy, delta.dx) : 0.0;
    final radiusA = a.width / 2, radiusB = b.width / 2;
    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      final center = a.position + delta * t;
      final radius = math.max(.001, radiusA + (radiusB - radiusA) * t);
      // The authored tip's vertical axis follows the stroke in crescent mode.
      // Interpolated vertex tangents avoid a new corner at every input sample.
      final angle =
          (crescent ? startAngle + angleDelta * t - math.pi / 2 : fixedAngle) +
          (brush.calligraphyAngle ?? 0) * math.pi / 180;
      final cosA = math.cos(-angle), sinA = math.sin(-angle);
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
            if (crescent) {
              final clip = (r + .5 - math.sqrt(distSquared)).clamp(0.0, 1.0);
              if (clip <= 0) return 0;
              return _textureAlpha(
                    texture,
                    ((u / r + 1) / 2) * (brushTextureSize - 1),
                    ((v / r + 1) / 2) * (brushTextureSize - 1),
                  ) *
                  clip;
            }
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
          if (mask.outer[p] <= 0) mask.include(p);
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

class _MaskTile extends _PixelSpans {
  final outer = Float32List(_pixels),
      fill = Float32List(_pixels),
      opacity = Float32List(_pixels);
}

class _SurfaceTile extends _PixelSpans {
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

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
Offset _unit(Offset a) => a.distance < 1e-9 ? Offset.zero : a / a.distance;

class _RunCache {
  final int end;
  final HairRibbonPoint first, last;
  final Map<int, _MaskTile> mask;
  // Completed crescents can depend on neighboring tangents or a shared width
  // limit. Compare the actual geometry, not only endpoints or a lossy hash.
  final List<Object>? geometry;
  const _RunCache(this.end, this.first, this.last, this.mask, {this.geometry});
}

bool _samePoint(HairRibbonPoint a, HairRibbonPoint b) =>
    a.position == b.position && a.width == b.width && a.opacity == b.opacity;

// Circumradius of a sampled turn; straight and duplicate samples are unbounded.
double _curveRadius(Offset before, Offset at, Offset after) {
  final a = at - before, b = after - at;
  final twiceArea = _cross(a, b).abs();
  if (twiceArea < 1e-9) return double.infinity;
  return a.distance * b.distance * (after - before).distance / (2 * twiceArea);
}

// Bilinear alpha avoids stair-stepping when a tip rotates through a curve.
double _textureAlpha(Uint8List texture, double x, double y) {
  final fx = x.clamp(0.0, brushTextureSize - 1.0);
  final fy = y.clamp(0.0, brushTextureSize - 1.0);
  final x0 = fx.floor(), y0 = fy.floor();
  final x1 = math.min(x0 + 1, brushTextureSize - 1);
  final y1 = math.min(y0 + 1, brushTextureSize - 1);
  final u = fx - x0, v = fy - y0;
  double alpha(int x, int y) =>
      texture[(y * brushTextureSize + x) * 4 + 3] / 255;
  return (alpha(x0, y0) * (1 - u) + alpha(x1, y0) * u) * (1 - v) +
      (alpha(x0, y1) * (1 - u) + alpha(x1, y1) * u) * v;
}

Offset _positionAtDistance(
  List<HairRibbonPoint> points,
  List<double> lengths,
  double distance,
) {
  if (distance <= 0) return points.first.position;
  if (distance >= lengths.last) return points.last.position;
  var low = 0, high = lengths.length - 1;
  while (high - low > 1) {
    final middle = (low + high) ~/ 2;
    if (lengths[middle] < distance) {
      low = middle;
    } else {
      high = middle;
    }
  }
  final span = lengths[high] - lengths[low];
  return Offset.lerp(
    points[low].position,
    points[high].position,
    span <= 0 ? 0 : (distance - lengths[low]) / span,
  )!;
}

// Scanline bounds avoid walking every pixel of a 256-square tile for a narrow
// strand. Bounds only expand and are retained with cached run masks.
class _PixelSpans {
  final left = Int16List(_size)..fillRange(0, _size, _size);
  final right = Int16List(_size)..fillRange(0, _size, -1);
  int top = _size, bottom = -1;
  void include(int p) {
    final y = p ~/ _size, x = p % _size;
    if (x < left[y]) left[y] = x;
    if (x > right[y]) right[y] = x;
    if (y < top) top = y;
    if (y > bottom) bottom = y;
  }
}

bool _sameGeometry(List<Object>? a, List<Object>? b) {
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<int> _curveReversals(List<HairRibbonPoint> points, List<double> lengths) {
  final boundaries = <int>[];
  var previous = Offset.zero;
  var direction = 0.0, accumulated = 0.0, opposite = 0.0;
  var candidate = -1;
  for (var i = 0; i < points.length; i++) {
    final reach = math.max(.5, points[i].width * .3);
    final tangent = _unit(
      _positionAtDistance(points, lengths, lengths[i] + reach) -
          _positionAtDistance(points, lengths, lengths[i] - reach),
    );
    if (previous == Offset.zero || tangent == Offset.zero) {
      previous = tangent;
      continue;
    }
    final turn = math.atan2(_cross(previous, tangent), _dot(previous, tangent));
    previous = tangent;
    if (turn.abs() < 1e-5) continue;
    if (direction == 0) direction = turn.sign;
    if (turn.sign == direction) {
      accumulated += turn.abs();
      opposite = 0;
      candidate = -1;
    } else {
      if (candidate < 0) candidate = i - 1;
      opposite += turn.abs();
      // Angular hysteresis rejects sampling noise without a screen-distance
      // cooldown that would swallow a small but real reversal near the tip.
      if (opposite >= .15) {
        if (accumulated >= .25 && candidate > 0) boundaries.add(candidate);
        direction = turn.sign;
        accumulated = opposite;
        opposite = 0;
        candidate = -1;
      }
    }
  }
  return boundaries;
}
