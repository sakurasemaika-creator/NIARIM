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
  double _textureLeft = 0;
  double _textureRight = brushTextureSize - 1;
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
    bool taperEnd = false,
  }) {
    final plainTail =
        taperEnd && brush.foldMode != HairFoldMode.crescent && folds.isEmpty;
    if (points.length < 2 || (folds.isEmpty && !plainTail)) return;
    if (plainTail) {
      // Even a straight wave/curl stroke gets a pointed tip. Insert only
      // collinear samples so sparse input does not taper the whole segment.
      final samples = <HairRibbonPoint>[points.first];
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1], b = points[i];
        final count = math.max(
          1,
          ((b.position - a.position).distance / 2).ceil(),
        );
        for (var j = 1; j <= count; j++) {
          final t = j / count;
          samples.add(
            HairRibbonPoint(
              Offset.lerp(a.position, b.position, t)!,
              a.width + (b.width - a.width) * t,
              a.opacity + (b.opacity - a.opacity) * t,
            ),
          );
        }
      }
      points = samples;
    }
    if (!identical(brush, _cachedBrush) ||
        !identical(texture, _cachedTexture)) {
      _runs.clear();
      _cachedBrush = brush;
      _cachedTexture = texture;
      _textureLeft = 0;
      _textureRight = brushTextureSize - 1;
      if (texture != null) {
        // Fit the ink, rather than the transparent image padding, to the
        // crescent's full-width outline. Keep the two-dimensional tip intact.
        var peak = 0;
        final columns = List<int>.filled(brushTextureSize, 0);
        for (var y = 0; y < brushTextureSize; y++) {
          for (var x = 0; x < brushTextureSize; x++) {
            final alpha = texture[(y * brushTextureSize + x) * 4 + 3];
            columns[x] = math.max(columns[x], alpha);
            peak = math.max(peak, alpha);
          }
        }
        if (peak > 0) {
          final left = columns.indexWhere((alpha) => alpha >= peak * .95);
          final right = columns.lastIndexWhere((alpha) => alpha >= peak * .95);
          if (right > left) {
            _textureLeft = left.toDouble();
            _textureRight = right.toDouble();
          }
        }
      }
    }
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(
        lengths.last + (points[i].position - points[i - 1].position).distance,
      );
    }
    // Duplicate stationary/constrained input must preserve its existing tap.
    if (lengths.last <= 1e-6) return;
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
    if (indices.length < 3 &&
        brush.foldMode != HairFoldMode.crescent &&
        !taperEnd) {
      return;
    }
    final crescentContinuous = <int>{};
    if (brush.foldMode == HairFoldMode.crescent) {
      // Once folding is active, every actual reversal separates crescents.
      // Detector cooldown may skip a small final curl; midpoints between its
      // sparse events can then put both turn directions in one crescent.
      final crescentBoundaries = <int>{
        0,
        points.length - 1,
        ..._curveReversals(
          points,
          lengths,
          brush.foldTriggerAngle * math.pi / 180,
        ),
      };
      crescentContinuous.addAll(
        _crescentTurnBoundaries(
          points,
          lengths,
          crescentBoundaries.toList()..sort(),
        ),
      );
      crescentBoundaries.addAll(crescentContinuous);
      indices
        ..clear()
        ..addAll(crescentBoundaries.toList()..sort());
    }
    final result = <int, _SurfaceTile>{};

    final originalPoints = points;
    var sourcePoints = points;
    if (taperEnd && brush.foldMode != HairFoldMode.crescent) {
      // Folded wave/curl strands finish at a point. This is shared mode
      // geometry, independent of preset identity and the ordinary fade mode.
      // Allow the tail to extend before a nearby fold. Limiting it to a
      // fraction of the last run leaves full-width disks covering the tip.
      final tailLength = math.min(lengths.last, brush.size * 2);
      if (tailLength > 0) {
        sourcePoints = List.generate(points.length, (i) {
          final p = points[i];
          final t = ((lengths.last - lengths[i]) / tailLength).clamp(0.0, 1.0);
          final taper = t * t * (3 - 2 * t);
          final tip = (t / .1).clamp(0.0, 1.0);
          return HairRibbonPoint(
            p.position,
            // For a dash shorter than its diameter, the ordinary head disk
            // would cover the point. Fit its width to the available tail span.
            math.min(p.width, tailLength) * taper,
            // Keep the narrowed body opaque; only the last outline pixels
            // fade away, so zero width cannot leave an outline-only dot.
            p.opacity * tip * tip * (3 - 2 * tip),
          );
        });
      }
    }
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
                p.position +
                    Offset(-tangent.dy, tangent.dx) *
                        originalPoints[i].width *
                        offset,
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
      final crescentSides = <int, double>{};
      final crescentBlend = <int, double>{};
      final crescentApices = <int, int>{};
      final crescentAngles = <int, double>{};
      var crescentCurveStart = 0;
      if (brush.foldMode == HairFoldMode.crescent) {
        final turns = <double>[0];
        var accumulated = 0.0;
        for (var index = 0; index < points.length; index++) {
          // Resolve only the edge normal over document distance. The authored
          // axis is never resampled into another curve or moved by smoothing.
          final reach = math.max(.5, points[index].width * .3);
          final tangent = _unit(
            _positionAtDistance(points, lengths, lengths[index] + reach) -
                _positionAtDistance(points, lengths, lengths[index] - reach),
          );
          crescentTangents[index] = tangent;
          if (index == 0) {
            final angle = math.atan2(tangent.dy, tangent.dx) - math.pi / 2;
            crescentAngles[index] = math.atan2(
              math.sin(angle),
              math.cos(angle),
            );
          } else {
            final previous = crescentTangents[index - 1]!;
            final turn =
                previous.distanceSquared < 1e-8 ||
                    tangent.distanceSquared < 1e-8
                ? 0.0
                : math.atan2(
                    _cross(previous, tangent),
                    _dot(previous, tangent),
                  );
            accumulated += turn.abs();
            turns.add(accumulated);
            // Unwrap once along the authored stroke. Blending a fixed tip into
            // a curve must not flip at the +/-pi boundary between two samples.
            crescentAngles[index] = crescentAngles[index - 1]! + turn;
          }
        }
        crescentCurveStart = math.max(
          0,
          turns.indexWhere((turn) => turn > .005),
        );
        for (var i = 1; i < indices.length; i++) {
          final start = indices[i - 1], end = indices[i];
          final chord = points[end].position - points[start].position;
          var apex = (start + end) ~/ 2;
          var deviation = 0.0;
          var signedTurn = 0.0;
          for (var index = start + 1; index <= end; index++) {
            final distance = _cross(
              chord,
              points[index].position - points[start].position,
            );
            if (distance.abs() > deviation) {
              deviation = distance.abs();
              apex = index;
            }
            signedTurn += _cross(
              crescentTangents[index - 1]!,
              crescentTangents[index]!,
            );
          }
          crescentApices[start] = apex;
          crescentSides[start] = signedTurn == 0
              ? (i > 1 ? crescentSides[indices[i - 2]]! : 1)
              : signedTurn.sign;
        }
        final transitionTurn = math.max(
          .15,
          math.min(math.pi / 3, turns[crescentApices[0]!] * .75),
        );
        for (var index = 0; index < points.length; index++) {
          final t = (turns[index] / transitionTurn).clamp(0.0, 1.0);
          crescentBlend[index] = t * t * (3 - 2 * t);
        }
      }
      runs.sort((a, b) => a.depth.compareTo(b.depth));
      for (final run in runs) {
        // A crescent is a pair of bows across the same authored chord.
        // Parallel normal offsets make the inside sharper than the input.
        // Scale the actual chord deviation instead, preserving the source path.
        final chordStart = points[run.start].position;
        final chord = points[run.end].position - chordStart;
        final apexIndex = crescentApices[run.start];
        final chordNormal = _unit(Offset(-chord.dy, chord.dx));
        final apexBow = apexIndex == null
            ? 0.0
            : _dot(points[apexIndex].position - chordStart, chordNormal);
        final outward = chordNormal * apexBow.sign;
        final bowDepth = apexBow.abs();
        final strength = (brush.foldCurveStrength - 1) / 9;
        final innerPower = 1 + strength * .35;
        // Partial curls already have a smaller authored depth. No extra
        // turn-based multiplier may change the selected proportional ratio.
        final curveDiameter =
            bowDepth *
            Brush.clampFoldCrescentWidthRatio(brush.foldCrescentWidthRatio);
        final widthScale = curveDiameter / math.max(.001, brush.size);
        final widestHalf = [
          for (var i = run.start; i <= run.end; i++)
            points[i].width * widthScale / 2,
        ].reduce(math.max);
        // One bound per run prevents hooks with unusually large pressure
        // widths. The remaining diameter is distributed outside.
        final insideScale = widestHalf <= 0
            ? 1.0
            : math.min(1.0, .98 * bowDepth / (widestHalf * innerPower));
        final chordAxis = _unit(chord);
        final leadIndex = math.min(crescentCurveStart, apexIndex ?? run.start);
        final leadNormal = brush.foldMode == HairFoldMode.crescent
            ? Offset(
                    -crescentTangents[leadIndex]!.dy,
                    crescentTangents[leadIndex]!.dx,
                  ) *
                  -crescentSides[run.start]!
            : Offset.zero;
        final leadSpan = apexIndex == null
            ? 0.0
            : _dot(
                points[apexIndex].position - points[leadIndex].position,
                chordAxis,
              );
        final geometry = brush.foldMode == HairFoldMode.crescent
            ? <Object>[
                crescentApices[run.start]!,
                crescentSides[run.start]!,
                if (run.start == 0) crescentCurveStart,
                for (var index = run.start; index <= run.end; index++)
                  (
                    points[index].position,
                    points[index].width,
                    points[index].opacity,
                    crescentTangents[index],
                    crescentBlend[index],
                    crescentAngles[index],
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
        final envelope =
            brush.foldMode == HairFoldMode.crescent && texture != null
            ? <int, _MaskTile>{}
            : mask;
        final segmentStart = reusable ? cached.end + 1 : run.start + 1;
        if (!reusable &&
            brush.foldMode == HairFoldMode.crescent &&
            run.start == 0) {
          final first = points.first;
          _segment(
            envelope,
            first,
            HairRibbonPoint(
              first.position + crescentTangents[0]! * .001,
              first.width,
              first.opacity,
            ),
            brush.outlineWidth,
          );
        }
        for (var i = segmentStart; i <= run.end; i++) {
          final firstIndex = i - 1;
          var a = points[firstIndex], b = points[i];
          var textureAngleA = crescentAngles[i - 1];
          var textureAngleB = crescentAngles[i];
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
            ({HairRibbonPoint point, Offset outer, Offset inner, double angle})
            edgeAt(int index) {
              final point = points[index];
              final blend = crescentBlend[index]!;
              final tangent = crescentTangents[index]!;
              final normal =
                  Offset(-tangent.dy, tangent.dx) * -crescentSides[run.start]!;
              final bow = bowDepth < 1e-6
                  ? 0.0
                  : (_dot(point.position - chordStart, outward) / bowDepth)
                        .clamp(0.0, 1.0);
              final outerProfile = math.pow(bow, 1 - strength * .2).toDouble();
              final innerProfile = math.pow(bow, innerPower).toDouble();
              // Preserve the ordinary pen until it starts turning.
              var ordinary = normal * point.width / 2 * (1 - blend);
              if (run.start == 0 && index > leadIndex && leadSpan > 1e-6) {
                final q =
                    (_dot(
                              point.position - points[leadIndex].position,
                              chordAxis,
                            ) /
                            leadSpan)
                        .clamp(0.0, 1.0);
                // A cap wider than the whole bend must not push the join
                // backwards. The original ordinary head/lead remains covered.
                final along = (_dot(leadNormal, chordAxis) * point.width / 2)
                    .clamp(-leadSpan * .98, leadSpan * .98);
                ordinary =
                    ordinary -
                    chordAxis * _dot(ordinary, chordAxis) +
                    chordAxis *
                        along *
                        _ordinaryLeadFade(q, along.abs() / leadSpan);
              }
              final curveWidth = point.width * widthScale;
              final outerEdge =
                  point.position +
                  ordinary +
                  outward *
                      curveWidth *
                      (1 - insideScale / 2) *
                      outerProfile *
                      blend;
              final innerEdge =
                  point.position -
                  ordinary -
                  outward * curveWidth / 2 * insideScale * innerProfile * blend;
              final across =
                  (outerEdge - innerEdge) * crescentSides[run.start]!;
              final sourceAngle = crescentAngles[index]!;
              final edgeAngle = across.distanceSquared < 1e-10
                  ? sourceAngle
                  : math.atan2(across.dy, across.dx);
              return (
                point: HairRibbonPoint(
                  (outerEdge + innerEdge) / 2,
                  (outerEdge - innerEdge).distance,
                  point.opacity,
                ),
                outer: outerEdge,
                inner: innerEdge,
                angle:
                    sourceAngle +
                    math.atan2(
                      math.sin(edgeAngle - sourceAngle),
                      math.cos(edgeAngle - sourceAngle),
                    ),
              );
            }

            final first = edgeAt(i - 1), last = edgeAt(i);
            a = first.point;
            b = last.point;
            textureAngleA = first.angle;
            textureAngleB = last.angle;
            if (crescentBlend[i]! == 0) {
              _segment(envelope, a, b, brush.outlineWidth);
            } else {
              final before = edgeAt(math.max(run.start, i - 2));
              final after = edgeAt(math.min(run.end, i + 1));
              final count =
                  (math.max(
                            (last.outer - first.outer).distance,
                            (last.inner - first.inner).distance,
                          ) /
                          2)
                      .ceil()
                      .clamp(1, 32);
              var previousOuter = first.outer, previousInner = first.inner;
              var previous = a;
              for (var step = 1; step <= count; step++) {
                final t = step / count;
                final outer = _smoothEdge(
                  before.outer,
                  first.outer,
                  last.outer,
                  after.outer,
                  t,
                );
                final inner = _smoothEdge(
                  before.inner,
                  first.inner,
                  last.inner,
                  after.inner,
                  t,
                );
                final current = HairRibbonPoint(
                  Offset.lerp(a.position, b.position, t)!,
                  a.width + (b.width - a.width) * t,
                  a.opacity + (b.opacity - a.opacity) * t,
                );
                _ribbonSegment(envelope, previous, current, [
                  previousOuter,
                  outer,
                  inner,
                  previousInner,
                ], brush.outlineWidth);
                previous = current;
                previousOuter = outer;
                previousInner = inner;
              }
            }
          }
          final tailOutline =
              taperEnd && brush.foldMode != HairFoldMode.crescent;
          // Compare with the original pressure/fade width: unaffected cached
          // body masks keep their existing outline, and only the new tail thins.
          final outlineScaleA = tailOutline
              ? (a.width / math.max(.001, originalPoints[firstIndex].width))
                    .clamp(0.0, 1.0)
              : 1.0;
          final outlineScaleB = tailOutline
              ? (b.width / math.max(.001, originalPoints[i].width)).clamp(
                  0.0,
                  1.0,
                )
              : 1.0;
          if (texture == null) {
            if (brush.foldMode != HairFoldMode.crescent) {
              final outline =
                  brush.outlineWidth * math.max(outlineScaleA, outlineScaleB);
              _segment(mask, a, b, outline);
            }
          } else {
            _texturedSegment(
              mask,
              a,
              b,
              brush,
              texture,
              outlineScaleA: outlineScaleA,
              outlineScaleB: outlineScaleB,
              angleA: textureAngleA,
              angleB: textureAngleB,
              blendA: crescentBlend[i - 1] ?? 1,
              blendB: crescentBlend[i] ?? 1,
            );
          }
        }
        if (!reusable && !identical(envelope, mask)) {
          for (final entry in mask.entries) {
            final limit = envelope[entry.key];
            final m = entry.value;
            for (var row = m.top; row <= m.bottom; row++) {
              for (
                var p = row * _size + m.left[row];
                p <= row * _size + m.right[row];
                p++
              ) {
                m.outer[p] = math.min(m.outer[p], limit?.outer[p] ?? 0);
                m.fill[p] = math.min(m.fill[p], limit?.fill[p] ?? 0);
              }
            }
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

  // Rasterize the two authored outline edges directly. Cross-section edges
  // are internal to the ribbon and must not introduce antialias seams.
  void _ribbonSegment(
    Map<int, _MaskTile> masks,
    HairRibbonPoint a,
    HairRibbonPoint b,
    List<Offset> corners,
    double outline,
  ) {
    final margin = outline + 1;
    final left = (corners.map((p) => p.dx).reduce(math.min) - margin)
        .floor()
        .clamp(0, tiles.canvasWidth - 1);
    final right = (corners.map((p) => p.dx).reduce(math.max) + margin)
        .ceil()
        .clamp(0, tiles.canvasWidth - 1);
    final top = (corners.map((p) => p.dy).reduce(math.min) - margin)
        .floor()
        .clamp(0, tiles.canvasHeight - 1);
    final bottom = (corners.map((p) => p.dy).reduce(math.max) + margin)
        .ceil()
        .clamp(0, tiles.canvasHeight - 1);
    final delta = b.position - a.position;
    final squared = delta.distanceSquared;
    final edges = [
      for (var i = 0; i < 4; i++) corners[(i + 1) % 4] - corners[i],
    ];
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final at = Offset(x + .5, y + .5);
        var inside = false;
        var distance = double.infinity, sideDistance = double.infinity;
        for (var i = 0; i < 4; i++) {
          final first = corners[i], last = corners[(i + 1) % 4];
          final edge = edges[i];
          final from = at - first;
          final along = edge.distanceSquared <= 1e-12
              ? 0.0
              : (_dot(from, edge) / edge.distanceSquared).clamp(0.0, 1.0);
          final d = (from - edge * along).distanceSquared;
          distance = math.min(distance, d);
          if (i.isEven) sideDistance = math.min(sideDistance, d);
          if ((first.dy > at.dy) != (last.dy > at.dy) &&
              at.dx < first.dx + (at.dy - first.dy) * edge.dx / edge.dy) {
            inside = !inside;
          }
        }
        final outer = inside
            ? 1.0
            : (outline + .5 - math.sqrt(distance)).clamp(0.0, 1.0);
        if (outer <= 0) continue;
        final fill = inside
            ? (.5 + math.sqrt(sideDistance)).clamp(0.0, 1.0)
            : (.5 - math.sqrt(distance)).clamp(0.0, 1.0);
        final t = squared < 1e-12
            ? 0.0
            : (_dot(at - a.position, delta) / squared).clamp(0.0, 1.0);
        final opacity = a.opacity + (b.opacity - a.opacity) * t;
        final key = (y ~/ _size) * tiles.tilesX + x ~/ _size;
        final m = masks.putIfAbsent(key, _MaskTile.new);
        final p = (y % _size) * _size + x % _size;
        if (m.outer[p] <= 0) m.include(p);
        if (fill > m.fill[p]) {
          m.opacity[p] = opacity;
        } else if (fill == m.fill[p]) {
          m.opacity[p] = math.max(m.opacity[p], opacity);
        }
        m.fill[p] = math.max(m.fill[p], fill);
        m.outer[p] = math.max(m.outer[p], outer);
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
    double? angleA,
    double? angleB,
    double blendA = 1,
    double blendB = 1,
    double outlineScaleA = 1,
    double outlineScaleB = 1,
  }) {
    final delta = b.position - a.position;
    final steps = math.max(1, delta.distance.ceil());
    final crescent = brush.foldMode == HairFoldMode.crescent;
    final fixedAngle = brush.rotation ? math.atan2(delta.dy, delta.dx) : 0.0;
    final startAngle = angleA ?? fixedAngle;
    final endAngle = angleB ?? fixedAngle;
    final radiusA = a.width / 2, radiusB = b.width / 2;
    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      final center = a.position + delta * t;
      final radius = math.max(.001, radiusA + (radiusB - radiusA) * t);
      final blend = blendA + (blendB - blendA) * t;
      final followingAngle = startAngle + (endAngle - startAngle) * t;
      final ordinaryAngle = brush.rotation
          ? followingAngle + math.pi / 2
          : fixedAngle;
      final angle =
          (crescent
              ? ordinaryAngle + (followingAngle - ordinaryAngle) * blend
              : fixedAngle) +
          (brush.calligraphyAngle ?? 0) * math.pi / 180;
      final cosA = math.cos(-angle), sinA = math.sin(-angle);
      final outlineScale = outlineScaleA + (outlineScaleB - outlineScaleA) * t;
      final outerRadius = radius + brush.outlineWidth * outlineScale;
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
            if (crescent && blend > 0) {
              final clip = (r + .5 - math.sqrt(distSquared)).clamp(0.0, 1.0);
              if (clip <= 0) return 0;
              final left = _textureLeft * blend;
              final right =
                  brushTextureSize -
                  1 +
                  (_textureRight - (brushTextureSize - 1)) * blend;
              return _textureAlpha(
                    texture,
                    left + ((u / r + 1) / 2) * (right - left),
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

// Integral of a ramp, constant middle, and fall. A bounded longitudinal
// derivative prevents the ordinary-to-crescent join from folding back.
double _ordinaryLeadFade(double q, double offsetRatio) {
  final ramp = ((1 - offsetRatio) / 2).clamp(.01, .25);
  if (q < ramp) return 1 - q * q / (2 * ramp * (1 - ramp));
  if (q <= 1 - ramp) return 1 - (q - ramp / 2) / (1 - ramp);
  return (1 - q) * (1 - q) / (2 * ramp * (1 - ramp));
}

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
Offset _unit(Offset a) => a.distance < 1e-9 ? Offset.zero : a / a.distance;

// Interpolate only the outline, retaining each authored sample and apex.
Offset _smoothEdge(Offset before, Offset a, Offset b, Offset after, double t) {
  final t2 = t * t, t3 = t2 * t;
  return a * (2 * t3 - 3 * t2 + 1) +
      (b - before) * (.5 * (t3 - 2 * t2 + t)) +
      b * (-2 * t3 + 3 * t2) +
      (after - a) * (.5 * (t3 - t2));
}

class _RunCache {
  final int end;
  final HairRibbonPoint first, last;
  final Map<int, _MaskTile> mask;
  // Completed crescents depend on neighboring tangents and the opening blend.
  // Compare the actual geometry, not only endpoints or a lossy hash.
  final List<Object>? geometry;
  const _RunCache(this.end, this.first, this.last, this.mask, {this.geometry});
}

bool _samePoint(HairRibbonPoint a, HairRibbonPoint b) =>
    a.position == b.position && a.width == b.width && a.opacity == b.opacity;

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

// Split only the authored curve into half-turns. Detector events activate
// folding; their periodic bookkeeping must never reshape an existing curl.
Set<int> _crescentTurnBoundaries(
  List<HairRibbonPoint> points,
  List<double> lengths,
  List<int> reversals,
) {
  final tangents = [
    for (var i = 0; i < points.length; i++)
      _unit(
        _positionAtDistance(
              points,
              lengths,
              lengths[i] + math.max(.5, points[i].width * .3),
            ) -
            _positionAtDistance(
              points,
              lengths,
              lengths[i] - math.max(.5, points[i].width * .3),
            ),
      ),
  ];
  final result = <int>{};
  for (var run = 1; run < reversals.length; run++) {
    var turn = 0.0;
    for (var i = reversals[run - 1] + 1; i <= reversals[run]; i++) {
      final a = tangents[i - 1], b = tangents[i];
      if (a.distanceSquared < 1e-8 || b.distanceSquared < 1e-8) continue;
      turn += math.atan2(_cross(a, b), _dot(a, b));
      if (turn.abs() >= math.pi) {
        result.add(i);
        turn = 0;
      }
    }
  }
  return result;
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

List<int> _curveReversals(
  List<HairRibbonPoint> points,
  List<double> lengths,
  double minimumEndTurn,
) {
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
  // A tiny unfinished reverse at pointer-up is part of the preceding curl.
  // Giving it a full-width apex before it reaches the trigger angle creates
  // a box-like terminal lobe on an almost straight tail.
  if (boundaries.isNotEmpty && accumulated < minimumEndTurn) {
    boundaries.removeLast();
  }
  return boundaries;
}
