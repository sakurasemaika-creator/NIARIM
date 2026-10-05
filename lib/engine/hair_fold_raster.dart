import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';

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
  bool _crescentActive = false;
  // Set once this stroke has folded. The fold surface then keeps drawing the
  // whole stroke, even while the newest bend has not folded yet.
  bool _active = false;
  // Last move's composite, kept so a move only recomposites the tiles whose
  // sections or fold lines changed. Long strokes stay cheap per move.
  final Map<int, _SurfaceTile> _surfaces = {};
  Map<int, Set<int>> _runTiles = {};
  Map<int, (double, int)> _runSignatures = {};
  List<_CreaseSegment> _creases = const [];
  Uint8List? _cachedTexture;
  double _textureLeft = 0;
  double _textureRight = brushTextureSize - 1;
  HairFoldRaster(this.tiles, this.layer);

  /// The fold vertices this renderer finds in [points], as indices: direction
  /// changes plus one fold per further 270 degrees of continuous turning.
  @visibleForTesting
  static List<({int index, bool continuous})> foldVertices(
    List<HairRibbonPoint> points, {
    double triggerDegrees = 90,
    bool crescent = false,
  }) {
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(
        lengths.last + (points[i].position - points[i - 1].position).distance,
      );
    }
    return _strokeBends(
      points,
      lengths,
      triggerDegrees.clamp(30.0, 170.0) * math.pi / 180,
      anyCurl: crescent,
    );
  }

  /// Whether this stroke is drawn by the fold surface instead of ordinary
  /// stamps. A crescent only takes over once its curve is deep enough.
  bool get replacesStroke =>
      _active &&
      (_cachedBrush?.foldMode != HairFoldMode.crescent || _crescentActive);

  void rememberTile(int tx, int ty) {
    final key = '$tx,$ty';
    if (_before.containsKey(key)) return;
    final tile = tiles.getTile(layer, tx, ty);
    _before[key] = tile == null ? null : Uint8List.fromList(tile);
  }

  void render({
    required List<HairRibbonPoint> points,
    required Brush brush,
    required Color fillColor,
    Uint8List? texture,
    bool taperEnd = false,
  }) {
    if (points.length < 2) return;
    final bendLengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      bendLengths.add(
        bendLengths.last +
            (points[i].position - points[i - 1].position).distance,
      );
    }
    if (bendLengths.last <= 1e-6) return;
    // Folds come from the authored stroke itself: its direction changes and
    // every further 270 degrees of continuous turning.
    var bends = _strokeBends(
      points,
      bendLengths,
      brush.foldTriggerAngle.clamp(30.0, 170.0) * math.pi / 180,
      anyCurl: brush.foldMode == HairFoldMode.crescent,
    );
    final plainTail =
        taperEnd && brush.foldMode != HairFoldMode.crescent && bends.isEmpty;
    if (bends.isEmpty && !plainTail && !_active) return;
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
      _surfaces.clear();
      _runTiles = {};
      _runSignatures = {};
      _creases = const [];
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
    if (plainTail) bends = const [];
    final indices = <int>{
      0,
      ...bends.map((b) => b.index),
      points.length - 1,
    }.toList()..sort();
    if (indices.length < 3 &&
        brush.foldMode != HairFoldMode.crescent &&
        !taperEnd &&
        !_active) {
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
    // Lateral repeats offset every section, so they recomposite in full.
    final incremental = repeats.length == 1 && _active;
    // A full composite starts the kept surfaces afresh, so the following
    // incremental moves see every tile (fold lines query its coverage).
    if (!incremental) _surfaces.clear();
    final result = repeats.length == 1 ? _surfaces : <int, _SurfaceTile>{};
    final redrawn = <int, _Area>{};
    final runTiles = <int, Set<int>>{};
    final runSignatures = <int, (double, int)>{};
    final creases = <_CreaseSegment>[];
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
      final depths = _runDepths(points, lengths, indices, brush.foldMode);
      for (var i = 1; i < indices.length; i++) {
        final start = indices[i - 1], end = indices[i];
        if (end <= start) continue;
        runs.add(_RibbonRun(start, end, depths[i - 1], ownerBase + i));
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
        if (!_crescentActive) {
          // A wave shallower than the pen is mostly hidden inside its own
          // stroke, so a thick pen needs a deeper curve to become a crescent.
          // Once activated, the stroke stays a crescent: nothing was drawn
          // before this point, so no stale fold surface can remain.
          final threshold = Brush.clampFoldCrescentDepthThreshold(
            brush.foldCrescentDepthThreshold,
          );
          var deepEnough = false;
          for (var i = 1; i < indices.length && !deepEnough; i++) {
            final start = indices[i - 1], end = indices[i];
            final chord = points[end].position - points[start].position;
            final apex = points[crescentApices[start]!].position;
            final depth = chord.distance < 1e-6
                ? (apex - points[start].position).distance
                : _cross(chord, apex - points[start].position).abs() /
                      chord.distance;
            var width = 0.0;
            for (var index = start; index <= end; index++) {
              width = math.max(width, points[index].width);
            }
            deepEnough = depth >= width * threshold;
          }
          if (!deepEnough) return;
          _crescentActive = true;
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
      runs.sort((a, b) {
        final order = a.depth.compareTo(b.depth);
        return order != 0 ? order : a.start.compareTo(b.start);
      });
      // Each section with the area it changed this move: null when its mask
      // was rebuilt, otherwise only the area around its appended segments.
      final built = <(_RibbonRun, Map<int, _MaskTile>, Map<int, _Area>?)>[];
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
        final strength = brush.foldAngleRatio.clamp(0.0, 1.0);
        final innerPower = 1 + strength * .35;
        // The apex keeps the pen's own pressure-resolved width; curve depth
        // only shapes the bows and never thickens or thins the crescent.
        final widestHalf = [
          for (var i = run.start; i <= run.end; i++) points[i].width / 2,
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
              final curveWidth = point.width;
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
        built.add((
          run,
          mask,
          !reusable
              ? null
              : segmentStart > run.end
              ? const <int, _Area>{}
              : _areaAround(points, segmentStart - 1, run.end, brush),
        ));
      }
      final dirty = <int, _Area>{};
      void markWhole(Iterable<int> keys) {
        for (final key in keys) {
          dirty[key] = _Area.whole;
        }
      }

      for (final (run, mask, changed) in built) {
        final keys = mask.keys.toSet();
        final signature = (run.depth, run.id);
        if (offset == 0) {
          runTiles[run.start] = keys;
          runSignatures[run.start] = signature;
        }
        final previous = _runTiles[run.start];
        if (!incremental ||
            changed == null ||
            previous == null ||
            _runSignatures[run.start] != signature) {
          markWhole(keys);
          if (previous != null) markWhole(previous);
        } else {
          _mergeAreas(dirty, changed);
        }
      }
      if (incremental) {
        for (final entry in _runTiles.entries) {
          if (!runTiles.containsKey(entry.key)) markWhole(entry.value);
        }
      }
      void recomposite(Iterable<int> keys) {
        for (final key in keys) {
          final surface = incremental
              ? (result[key]?..reset()) ?? (result[key] = _SurfaceTile())
              : result.putIfAbsent(key, _SurfaceTile.new);
          for (final (run, mask, _) in built) {
            final m = mask[key];
            if (m != null) _composite(surface, key, m, run, points, brush);
          }
        }
      }

      recomposite(dirty.keys);
      _mergeAreas(redrawn, dirty);
      // The fold line: a thin line that branches from the stroke at the inner
      // corner, continues the front section's edge across the section folded
      // behind it, then curves with the stroke's own turn and tapers away.
      // Fold length is its length relative to the strand width; fold angle
      // scales how much of the stroke's turn it follows (50 % = natural);
      // curve start keeps it straight first, which reads as thinner material.
      if (brush.foldMode != HairFoldMode.crescent) {
        for (var i = 1; i < indices.length - 1; i++) {
          final pivot = indices[i];
          final p = points[pivot];
          final reach = math.max(2.0, p.width);
          final incoming = _unit(
            p.position -
                _positionAtDistance(points, lengths, lengths[pivot] - reach),
          );
          final outgoing = _unit(
            _positionAtDistance(points, lengths, lengths[pivot] + reach) -
                p.position,
          );
          final sign = _cross(incoming, outgoing).sign;
          if (sign == 0) continue;
          final inward =
              _unit(
                Offset(-incoming.dy - outgoing.dy, incoming.dx + outgoing.dx),
              ) *
              sign;
          final firstFront = depths[i - 1] > depths[i];
          // The line leaves along the front section's own local tangent at
          // the vertex, so on a smooth bend it runs into the strand like the
          // continuing edge of that section instead of straight out of it.
          final local = math.max(1.0, p.width * .25);
          final direction = firstFront
              ? _unit(
                  p.position -
                      _positionAtDistance(
                        points,
                        lengths,
                        lengths[pivot] - local,
                      ),
                )
              : -_unit(
                  _positionAtDistance(points, lengths, lengths[pivot] + local) -
                      p.position,
                );
          final continuation = firstFront ? outgoing : -incoming;
          var origin = p.position;
          for (var distance = .5; distance < p.width * 2; distance += .5) {
            final at = p.position + inward * distance;
            if (!_covered(result, at)) break;
            origin = at;
          }
          // A continuous 270-degree fold keeps the authored turn direction:
          // a shorter, later, gentler line than a direction change.
          final continuous = bends[i - 1].continuous;
          // 100 % is twice the strand width; the line is clipped to the
          // strand, so even the maximum never leaves its contour.
          final length =
              p.width *
              2 *
              brush.foldLengthRatio.clamp(0.0, 1.0) *
              (continuous ? .32 : 1.0);
          if (length < 1) continue;
          final delay = continuous
              ? math.max(.50, brush.foldCurveStartRatio.clamp(0.0, 1.0))
              : brush.foldCurveStartRatio.clamp(0.0, .95);
          final turn = math.atan2(
            _cross(direction, continuation),
            _dot(direction, continuation),
          );
          // 50 % follows the stroke's turn exactly; 0 % stays straight.
          final totalTurn = (turn * brush.foldAngleRatio.clamp(0.0, 1.0) * 2)
              .clamp(-math.pi * .9, math.pi * .9);
          final taper = brush.foldEndTaperRatio.clamp(.01, 1.0);
          final count = math.max(6, (length / 1.5).ceil());
          var previous = origin;
          for (var step = 1; step <= count; step++) {
            final t = step / count;
            final u = ((t - delay) / math.max(.001, 1 - delay)).clamp(0.0, 1.0);
            final angle = totalTurn * u;
            final c = math.cos(angle), sn = math.sin(angle);
            final heading = Offset(
              direction.dx * c - direction.dy * sn,
              direction.dx * sn + direction.dy * c,
            );
            final at = previous + heading * (length / count);
            // Never past the strand's own contour.
            if (step > 1 && !_covered(result, at)) break;
            final lineWidth =
                brush.outlineWidth *
                (1 - ((t - (1 - taper)) / taper).clamp(0.0, 1.0));
            creases.add(
              _CreaseSegment(previous, at, lineWidth, ownerBase + i, p.opacity),
            );
            previous = at;
          }
        }
      }
      // A changed fold line also needs its old and new area recomposited.
      if (incremental && !_sameCreases(creases, _creases)) {
        final areas = <int, _Area>{};
        for (final c in [...creases, ..._creases]) {
          _mergeAreas(areas, _creaseArea(c));
        }
        recomposite(areas.keys.where((key) => !redrawn.containsKey(key)));
        _mergeAreas(redrawn, areas);
      }
    }
    // Drawing a fold line is idempotent (maximum), so tiles that were not
    // recomposited keep exactly the same pixels.
    for (final c in creases) {
      _crease(result, c.a, c.b, c.width, c.owner, c.opacity);
    }
    _runs.removeWhere((start, _) => !indices.contains(start));
    final firstComposite = !incremental;
    _active = true;
    _runTiles = runTiles;
    _runSignatures = runSignatures;
    _creases = creases;
    // The first composite replaces the ordinary stroke drawn so far. Later
    // moves rewrite only the changed area of each changed tile, through
    // getOrCreateTile so that only those tiles' cached images are dropped.
    if (firstComposite) tiles.applyTileSnapshot(layer, _before);
    final outline = Color(brush.outlineColor);
    // Per-pixel Color.lerp allocates; mix the channels directly instead.
    final fillChannels = [fillColor.r, fillColor.g, fillColor.b, fillColor.a];
    final outlineChannels = [outline.r, outline.g, outline.b, outline.a];
    double channel(int c, double t) =>
        (fillChannels[c] * (1.0 - t) + outlineChannels[c] * t).clamp(0.0, 1.0);
    final keys = firstComposite ? result.keys.toList() : redrawn.keys.toList();
    for (final key in keys) {
      final tx = key % tiles.tilesX, ty = key ~/ tiles.tilesX;
      final area = firstComposite ? _Area.whole : redrawn[key]!;
      rememberTile(tx, ty);
      final target = tiles.getOrCreateTile(layer, tx, ty);
      if (!firstComposite) {
        final before = _before[_tileName(key)];
        for (var row = area.top; row <= area.bottom; row++) {
          final from = (row * _size + area.left) * 4;
          final to = (row * _size + area.right + 1) * 4;
          if (before == null) {
            target.fillRange(from, to, 0);
          } else {
            target.setRange(from, to, before, from);
          }
        }
      }
      final s = result[key];
      if (s != null) {
        final firstRow = math.max<int>(s.top, area.top);
        final lastRow = math.min<int>(s.bottom, area.bottom);
        for (var row = firstRow; row <= lastRow; row++) {
          final firstColumn = math.max<int>(s.left[row], area.left);
          final lastColumn = math.min<int>(s.right[row], area.right);
          for (
            var p = row * _size + firstColumn;
            p <= row * _size + lastColumn;
            p++
          ) {
            if (s.cover[p] <= 0) continue;
            final perimeter = (s.outer[p] - s.fill[p]) / s.cover[p];
            final mix = math.max(s.outline[p], perimeter).clamp(0.0, 1.0);
            final alpha = (255 * s.cover[p] * channel(3, mix)).round().clamp(
              0,
              255,
            );
            if (alpha == 0) continue;
            tiles.blendPixel(
              target,
              p % _size,
              p ~/ _size,
              (channel(0, mix) * 255).round(),
              (channel(1, mix) * 255).round(),
              (channel(2, mix) * 255).round(),
              alpha,
            );
          }
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
    final cornerX = [for (final c in corners) c.dx];
    final cornerY = [for (final c in corners) c.dy];
    final edgeX = [
      for (var i = 0; i < 4; i++) cornerX[(i + 1) % 4] - cornerX[i],
    ];
    final edgeY = [
      for (var i = 0; i < 4; i++) cornerY[(i + 1) % 4] - cornerY[i],
    ];
    final edgeSquared = [
      for (var i = 0; i < 4; i++) edgeX[i] * edgeX[i] + edgeY[i] * edgeY[i],
    ];
    var lastKey = -1;
    _MaskTile? lastTile;
    for (var y = top; y <= bottom; y++) {
      // Only the columns the quad (plus its outline margin) spans on this
      // row: a thin diagonal strip covers a small part of its bounding box.
      final bandTop = y + .5 - margin, bandBottom = y + .5 + margin;
      var rowLeft = double.infinity, rowRight = double.negativeInfinity;
      for (var i = 0; i < 4; i++) {
        final a = corners[i], b = corners[(i + 1) % 4];
        final low = math.min(a.dy, b.dy), high = math.max(a.dy, b.dy);
        if (high < bandTop || low > bandBottom) continue;
        final dy = b.dy - a.dy;
        double xAt(double yy) => dy.abs() < 1e-9
            ? a.dx
            : a.dx + (b.dx - a.dx) * ((yy - a.dy) / dy).clamp(0.0, 1.0);
        final x0 = xAt(math.max(low, bandTop)),
            x1 = xAt(math.min(high, bandBottom));
        rowLeft = math.min(rowLeft, math.min(x0, x1));
        rowRight = math.max(rowRight, math.max(x0, x1));
      }
      if (rowLeft > rowRight) continue;
      final fromX = math.max(left, (rowLeft - margin).floor());
      final toX = math.min(right, (rowRight + margin).ceil());
      final cy = y + .5;
      for (var x = fromX; x <= toX; x++) {
        // Plain doubles: this loop runs per pixel of every crescent strip.
        final cx = x + .5;
        var inside = false;
        var distance = double.infinity, sideDistance = double.infinity;
        for (var i = 0; i < 4; i++) {
          final fx = cx - cornerX[i], fy = cy - cornerY[i];
          final ex = edgeX[i], ey = edgeY[i];
          final along = edgeSquared[i] <= 1e-12
              ? 0.0
              : ((fx * ex + fy * ey) / edgeSquared[i]).clamp(0.0, 1.0);
          final rx = fx - ex * along, ry = fy - ey * along;
          final d = rx * rx + ry * ry;
          if (d < distance) distance = d;
          if (i.isEven && d < sideDistance) sideDistance = d;
          final nextY = cornerY[(i + 1) % 4];
          if ((cornerY[i] > cy) != (nextY > cy) &&
              cx < cornerX[i] + (cy - cornerY[i]) * ex / ey) {
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
            : (((cx - a.position.dx) * delta.dx +
                          (cy - a.position.dy) * delta.dy) /
                      squared)
                  .clamp(0.0, 1.0);
        final opacity = a.opacity + (b.opacity - a.opacity) * t;
        final key = (y ~/ _size) * tiles.tilesX + x ~/ _size;
        if (key != lastKey) {
          lastKey = key;
          lastTile = masks.putIfAbsent(key, _MaskTile.new);
        }
        final m = lastTile!;
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

  /// Composites one section's mask tile onto a surface tile. Maximum ink
  /// coverage is kept across faces; an equally opaque front face hides the
  /// rear outline, and a cross-section cap between sections is not drawn.
  void _composite(
    _SurfaceTile surface,
    int key,
    _MaskTile m,
    _RibbonRun run,
    List<HairRibbonPoint> points,
    Brush brush,
  ) {
    final tileOrigin = Offset(
      (key % tiles.tilesX) * _size.toDouble(),
      (key ~/ tiles.tilesX) * _size.toDouble(),
    );
    final start = points[run.start].position, end = points[run.end].position;
    final startTangent = points[run.start + 1].position - start;
    final endTangent = end - points[run.end - 1].position;
    final startReach = math.pow(points[run.start].width, 2).toDouble();
    final endReach = math.pow(points[run.end].width, 2).toDouble();
    final crescent = brush.foldMode == HairFoldMode.crescent;
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
        final below = surface.fill[p];
        if (surface.cover[p] <= 0) surface.include(p);
        surface.shape[p] = math.max(surface.shape[p], cover);
        surface.outer[p] = math.max(surface.outer[p], ink);
        surface.fill[p] = math.max(surface.fill[p], fill * m.opacity[p]);
        var edge = (cover - fill).clamp(0.0, 1.0);
        if (edge > 0 && !crescent) {
          final at = tileOrigin + Offset(p % _size + .5, p ~/ _size + .5);
          if ((run.start > 0 && _dot(at - start, startTangent) < 0) ||
              (run.end < points.length - 1 && _dot(at - end, endTangent) > 0)) {
            edge = 0;
          } else if (below > .5 &&
              ((run.start > 0 && (at - start).distanceSquared < startReach) ||
                  (run.end < points.length - 1 &&
                      (at - end).distanceSquared < endReach))) {
            // At a fold the curved fold line marks it. The front section's
            // own edge must not run straight across the section behind it;
            // how far it would run depends on the exact vertex sample.
            edge = 0;
          }
        }
        final total = math.max(ink, surface.cover[p]);
        final front = ink / total;
        // Crescents form a single surface: only the union perimeter is
        // visible, never a cross-section cap between connected runs.
        surface.outline[p] = crescent
            ? 0
            : edge / cover * front + surface.outline[p] * (1 - front);
        surface.cover[p] = total;
        if (front > .5) surface.owner[p] = run.id;
      }
    }
  }

  Map<int, _Area> _creaseArea(_CreaseSegment c) => _areaOf(
    math.min(c.a.dx, c.b.dx),
    math.min(c.a.dy, c.b.dy),
    math.max(c.a.dx, c.b.dx),
    math.max(c.a.dy, c.b.dy),
    c.width + 2,
  );

  Map<int, _Area> _areaAround(
    List<HairRibbonPoint> points,
    int first,
    int last,
    Brush brush,
  ) {
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    var margin = 0.0;
    for (var i = math.max(0, first); i <= last; i++) {
      final p = points[i].position;
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
      margin = math.max(margin, points[i].width);
    }
    return _areaOf(
      left,
      top,
      right,
      bottom,
      margin + brush.outlineWidth * 2 + 2,
    );
  }

  /// The canvas rectangle, grown by [margin], split into per-tile areas.
  Map<int, _Area> _areaOf(
    double left,
    double top,
    double right,
    double bottom,
    double margin,
  ) {
    final x0 = (left - margin).floor().clamp(0, tiles.canvasWidth - 1).toInt();
    final x1 = (right + margin).ceil().clamp(0, tiles.canvasWidth - 1).toInt();
    final y0 = (top - margin).floor().clamp(0, tiles.canvasHeight - 1).toInt();
    final y1 = (bottom + margin)
        .ceil()
        .clamp(0, tiles.canvasHeight - 1)
        .toInt();
    final result = <int, _Area>{};
    for (var ty = y0 ~/ _size; ty <= y1 ~/ _size; ty++) {
      for (var tx = x0 ~/ _size; tx <= x1 ~/ _size; tx++) {
        result[ty * tiles.tilesX + tx] = _Area(
          math.max(0, x0 - tx * _size),
          math.max(0, y0 - ty * _size),
          math.min(_size - 1, x1 - tx * _size),
          math.min(_size - 1, y1 - ty * _size),
        );
      }
    }
    return result;
  }

  String _tileName(int key) => '${key % tiles.tilesX},${key ~/ tiles.tilesX}';

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

  /// Clears only the used span instead of allocating a fresh tile.
  void reset() {
    for (var row = top; row <= bottom; row++) {
      final from = row * _size + left[row], to = row * _size + right[row] + 1;
      if (to > from) {
        owner.fillRange(from, to, 0);
        outer.fillRange(from, to, 0);
        fill.fillRange(from, to, 0);
        cover.fillRange(from, to, 0);
        outline.fillRange(from, to, 0);
        shape.fillRange(from, to, 0);
      }
      left[row] = _size;
      right[row] = -1;
    }
    top = _size;
    bottom = -1;
  }
}

/// A tile-local pixel rectangle (inclusive).
class _Area {
  final int left, top, right, bottom;
  const _Area(this.left, this.top, this.right, this.bottom);
  static const whole = _Area(0, 0, _size - 1, _size - 1);

  _Area union(_Area other) => _Area(
    math.min(left, other.left),
    math.min(top, other.top),
    math.max(right, other.right),
    math.max(bottom, other.bottom),
  );
}

void _mergeAreas(Map<int, _Area> into, Map<int, _Area> from) {
  for (final entry in from.entries) {
    final existing = into[entry.key];
    into[entry.key] = existing == null
        ? entry.value
        : existing.union(entry.value);
  }
}

class _CreaseSegment {
  final Offset a, b;
  final double width, opacity;
  final int owner;
  const _CreaseSegment(this.a, this.b, this.width, this.owner, this.opacity);

  @override
  bool operator ==(Object other) =>
      other is _CreaseSegment &&
      other.a == a &&
      other.b == b &&
      other.width == width &&
      other.owner == owner &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(a, b, width, owner, opacity);
}

bool _sameCreases(List<_CreaseSegment> a, List<_CreaseSegment> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

/// Fold vertices of the authored stroke.
///
/// The stroke is split into bends at its inflections. A bend that changes
/// direction by at least [trigger] folds at its vertex, where half of its
/// turn has happened, if it sits between inflections (a wave) or is a sharp
/// corner ([anyCurl]: any bend, for crescents). Independently, every
/// further 270 degrees of continuous turning in
/// one direction adds a fold that keeps the turn direction, so 265 degrees
/// does not fold, 275 folds once, 545 twice and 815 three times.
/// Linear in the sample count, so it runs on every pointer move.
List<({int index, bool continuous})> _strokeBends(
  List<HairRibbonPoint> points,
  List<double> lengths,
  double trigger, {
  bool anyCurl = false,
}) {
  final count = points.length;
  if (count < 3) return const [];
  final turns = List<double>.filled(count, 0);
  var previous = Offset.zero;
  for (var i = 0; i < count; i++) {
    // Tangents over a quarter strand width: pointer jitter within the
    // strand cannot read as a bend.
    final reach = math.max(1.0, points[i].width * .25);
    final tangent = _unit(
      _positionAtDistance(points, lengths, lengths[i] + reach) -
          _positionAtDistance(points, lengths, lengths[i] - reach),
    );
    if (previous != Offset.zero && tangent != Offset.zero) {
      turns[i] = math.atan2(_cross(previous, tangent), _dot(previous, tangent));
    }
    if (tangent != Offset.zero) previous = tangent;
  }
  // Raw heading change at each sample. Summed over a bend it telescopes to
  // the total change in direction, so continuous turns count exactly.
  final rawTurns = List<double>.filled(count, 0);
  var heading = Offset.zero;
  for (var i = 1; i < count; i++) {
    final segment = _unit(points[i].position - points[i - 1].position);
    if (segment == Offset.zero) continue;
    if (heading != Offset.zero) {
      rawTurns[i - 1] = math.atan2(
        _cross(heading, segment),
        _dot(heading, segment),
      );
    }
    heading = segment;
  }
  final spans = <(int, int, double)>[];
  var direction = 0.0, start = 0, opposite = 0.0, candidate = -1;
  for (var i = 1; i < count; i++) {
    final turn = turns[i];
    if (turn.abs() < 1e-6) continue;
    if (direction == 0) direction = turn.sign;
    if (turn.sign == direction) {
      opposite = 0;
      candidate = -1;
      continue;
    }
    if (candidate < 0) candidate = i;
    opposite += turn.abs();
    // Angular hysteresis: hand jitter is not an inflection.
    if (opposite >= .15) {
      spans.add((start, candidate - 1, direction));
      start = candidate;
      direction = turn.sign;
      opposite = 0;
      candidate = -1;
    }
  }
  if (direction != 0) spans.add((start, count - 1, direction));
  final result = <({int index, bool continuous})>[];
  for (var k = 0; k < spans.length; k++) {
    final (first, last, sign) = spans[k];
    var total = 0.0, width = 0.0;
    for (var i = first; i <= last; i++) {
      total += turns[i] * sign;
      width = math.max(width, points[i].width);
    }
    int at(double turn) {
      var accumulated = 0.0;
      for (var i = first; i <= last; i++) {
        accumulated += turns[i] * sign;
        if (accumulated >= turn) return i.clamp(1, count - 2);
      }
      return last.clamp(1, count - 2);
    }

    final folds = <({int index, bool continuous})>[];
    if (total >= trigger) {
      // Radius of the central 80 % of the turn: a broad arc is a curve,
      // not a fold.
      final radius =
          (lengths[at(total * .9)] - lengths[at(total * .1)]) / (total * .8);
      final betweenInflections = spans.length > 1;
      // A crescent curls any bend that turns far enough, even a lone one.
      if (anyCurl ||
          (betweenInflections && radius <= math.max(width * 4, 48)) ||
          radius <= width * .5) {
        folds.add((index: at(total / 2), continuous: false));
      }
    }
    var rawTotal = 0.0;
    for (var i = first; i <= last; i++) {
      rawTotal += rawTurns[i] * sign;
    }
    for (
      var turn = math.pi * 1.5;
      turn <= rawTotal + 1e-6;
      turn += math.pi * 1.5
    ) {
      final index = at(turn * total / math.max(rawTotal, 1e-9));
      if (folds.any(
        (f) => (lengths[f.index] - lengths[index]).abs() < width * .5,
      )) {
        continue;
      }
      folds.add((index: index, continuous: true));
    }
    folds.sort((a, b) => a.index.compareTo(b.index));
    for (final fold in folds) {
      if (result.isEmpty || result.last.index < fold.index) result.add(fold);
    }
  }
  return result;
}

/// Stacking order of the sections between folds, relative to the stroke:
/// the top view keeps earlier sections in front, the low angle later ones.
/// A right curl puts the incoming section in front at right turns and the
/// outgoing one at left turns (a left curl mirrors it), so rotating the
/// stroke never changes which way it curls.
List<double> _runDepths(
  List<HairRibbonPoint> points,
  List<double> lengths,
  List<int> indices,
  HairFoldMode mode,
) {
  final depths = <double>[0];
  for (var i = 1; i + 1 < indices.length; i++) {
    final pivot = indices[i];
    final reach = math.max(2.0, points[pivot].width);
    final incoming =
        points[pivot].position -
        _positionAtDistance(points, lengths, lengths[pivot] - reach);
    final outgoing =
        _positionAtDistance(points, lengths, lengths[pivot] + reach) -
        points[pivot].position;
    final rightTurn = _cross(incoming, outgoing) >= 0;
    final incomingFront = switch (mode) {
      HairFoldMode.waveTopView => true,
      HairFoldMode.waveLowAngle => false,
      HairFoldMode.curlRight => rightTurn,
      HairFoldMode.curlLeft => !rightTurn,
      HairFoldMode.crescent => false,
    };
    depths.add(depths.last + (incomingFront ? -1 : 1));
  }
  return depths;
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
