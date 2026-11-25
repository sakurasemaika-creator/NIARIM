import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/brush.dart';
import '../models/brush_extension_defaults.dart';
import 'brush_render_plan.dart';
import 'brush_stroke_geometry.dart';
import 'brush_texture_cache.dart';
import 'tile_manager.dart';

/// One real, pressure/fade-resolved point. Folding never moves its center.
class HairRibbonPoint {
  final Offset position;
  final double width;
  final double opacity;

  /// The pressure/taper scale already applied to [width]. It shapes the
  /// strand as a whole, outline included, while the outline keeps its width
  /// (see [outlinedStrokeRadii]).
  final double scale;

  /// This point's own outline width (the outline's 強弱), or null for the
  /// brush's.
  final double? outline;
  const HairRibbonPoint(
    this.position,
    this.width,
    this.opacity, [
    this.scale = 1,
    this.outline,
  ]);

  /// The outline's width here: its own, or else [outlineWidth].
  double outlineOr(double outlineWidth) => outline ?? outlineWidth;

  /// The fill radius before [outlinedFill] snaps it.
  double fillRadius(double outlineWidth) =>
      outlinedFillRadius(width, scale, outlineOr(outlineWidth));

  double outerRadius(double outlineWidth) =>
      outlinedOuterRadius(width, scale, outlineOr(outlineWidth));
}

/// Project the tip onto the normal of the local stroke tangent. At a bend,
/// the bisector keeps the width continuous between adjacent sections.
List<HairRibbonPoint> _projectNib(
  List<HairRibbonPoint> points,
  Brush brush,
  Offset tipScale,
) {
  final angle = (brush.calligraphyAngle ?? 0) * math.pi / 180;
  final xScale =
      tipScale.dx *
      (brush.calligraphyAngle == null
          ? 1
          : Brush.clampNibWidthRatio(brush.nibWidthRatio));
  final yScale = tipScale.dy;
  final projected = <HairRibbonPoint>[];
  var incoming = Offset.zero;
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final outgoing = i + 1 < points.length
        ? _unit(points[i + 1].position - point.position)
        : Offset.zero;
    final bisector = _unit(incoming + outgoing);
    final tangent = bisector != Offset.zero ? bisector : incoming;
    final widthScale = tangent == Offset.zero
        ? 1.0
        : nibWidthAcross(
            brush.rotation ? const Offset(1, 0) : tangent,
            xScale,
            angle,
            yScale: yScale,
          );
    projected.add(
      HairRibbonPoint(
        point.position,
        point.width * widthScale,
        point.opacity,
        point.scale,
        point.outline,
      ),
    );
    incoming = outgoing;
  }
  return projected;
}

/// The own outline width between [a] and [b], [t] of the way.
double? _outlineBetween(HairRibbonPoint a, HairRibbonPoint b, double t) {
  final from = a.outline ?? b.outline;
  final to = b.outline ?? a.outline;
  return from == null || to == null ? null : from + (to - from) * t;
}

/// Replaces this stroke over its original tiles, so the front surface can hide
/// an earlier outline without erasing the artwork underneath. All masks use
/// maximum coverage; a translucent stroke is composited only once.
class HairFoldRaster {
  final TileManager tiles;
  final String layer;
  final Map<String, Uint8List?> _before = {};
  final Map<int, _RunCache> _runs = {};
  // Mask tiles of sections drawn again, kept to draw the next ones on: they
  // are large, and a crescent being drawn is drawn again on every move.
  final List<_MaskTile> _spareMasks = [];
  Brush? _cachedBrush;
  bool _crescentActive = false;
  // Set once this stroke has folded. The fold surface then keeps drawing the
  // whole stroke, even while the newest bend has not folded yet.
  bool _active = false;
  // Last move's composite, kept so a move only recomposites the tiles whose
  // sections or fold lines changed. Long strokes stay cheap per move.
  final Map<int, _SurfaceTile> _surfaces = {};
  Map<int, Set<int>> _runTiles = {};
  Map<int, (double, int, double, double)> _runSignatures = {};
  Map<int, int> _runEnds = {};

  /// Fold line starts by (repeat, vertex, front end, back end), with the
  /// samples they were found from: while drawing, only new folds search.
  final Map<(int, int, int, int), _FoldStartCache> _foldStarts = {};
  List<_CreaseSegment> _creases = const [];
  Uint8List? _cachedTexture;
  static final _tipMasks = Expando<_FoldTipMask>();
  _FoldTipMask? _tipMask;
  HairFoldRaster(this.tiles, this.layer);

  /// The fold vertices this renderer finds in [points], as indices: direction
  /// changes plus one fold per further 270 degrees of continuous turning.
  @visibleForTesting
  static List<({int index, bool continuous})> foldVertices(
    List<HairRibbonPoint> points, {
    double depthRatio = BrushExtensionDefaults.foldTriggerDepthRatio,
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
      Brush.clampFoldTriggerDepthRatio(depthRatio),
      anyCurl: crescent,
    );
  }

  /// Each fold of [points] drawn with [brush], with where its fold line
  /// starts and heads, as this renderer finds them; no start for a fold
  /// without a line (straight, or an overlapping hairpin).
  @visibleForTesting
  static List<
    ({Offset vertex, ({Offset origin, Offset direction, bool smooth})? start})
  >
  foldLineStarts(List<HairRibbonPoint> points, Brush brush) {
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(
        lengths.last + (points[i].position - points[i - 1].position).distance,
      );
    }
    final bends = _strokeBends(
      points,
      lengths,
      Brush.clampFoldTriggerDepthRatio(brush.foldTriggerDepthRatio),
      anyCurl: brush.foldMode == HairFoldMode.crescent,
    );
    final indices = <int>{
      0,
      ...bends.map((b) => b.index),
      points.length - 1,
    }.toList()..sort();
    final depths = _runDepths(points, lengths, indices, brush.foldMode);
    return [
      for (var i = 1; i < indices.length - 1; i++)
        (
          vertex: points[indices[i]].position,
          start: switch (_foldSides(points, lengths, indices, depths, i)) {
            null => null,
            final fold => _foldLineStart(
              points,
              lengths,
              indices[i],
              fold.frontEnd,
              fold.backEnd,
              fold.sign,
              brush.outlineWidth,
            ),
          },
        ),
    ];
  }

  /// Whether this stroke is drawn by the fold surface instead of ordinary
  /// stamps. A crescent only takes over once its curve is deep enough.
  bool get replacesStroke =>
      _active &&
      (_cachedBrush?.foldMode != HairFoldMode.crescent ||
          _crescentActive ||
          _cachedBrush?.foldFlatEnds == true);

  _MaskTile _blankMask() =>
      _spareMasks.isEmpty ? _MaskTile() : (_spareMasks.removeLast()..reset());

  void _spare(Map<int, _MaskTile> masks) {
    for (final m in masks.values) {
      if (_spareMasks.length >= 16) return;
      _spareMasks.add(m);
    }
  }

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
    final tip = _tipMask = texture == null
        ? null
        : (_tipMasks[texture] ??= _FoldTipMask(texture));
    final tipScale = tip?.scales ?? const Offset(1, 1);
    final directionalTip = tipScale.dx != tipScale.dy;
    final crescent = brush.foldMode == HairFoldMode.crescent;
    final depthRatio = Brush.clampFoldTriggerDepthRatio(
      brush.foldTriggerDepthRatio,
    );
    // A crescent fits the tip to the face of the curve. Other modes keep
    // the image's orientation fixed unless the brush enables rotation.
    if (brush.calligraphyAngle != null || (!crescent && directionalTip)) {
      points = _projectNib(points, brush, tipScale);
    }
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
      // Crescent runs are tested below after splitting at their own reversals.
      crescent ? 0 : depthRatio,
      anyCurl: crescent,
    );
    final flatEnds = brush.foldFlatEnds;
    // A directional image tip with fade disabled keeps its own cap. Round
    // tips and custom fade strokes keep the existing pointed tail.
    final shouldTaperTip =
        taperEnd &&
        !flatEnds &&
        (!directionalTip || brush.fadeMode != FadeMode.off);
    final plainTail =
        shouldTaperTip &&
        brush.foldMode != HairFoldMode.crescent &&
        bends.isEmpty;
    if (bends.isEmpty && !plainTail && !flatEnds && !_active) return;
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
              a.scale + (b.scale - a.scale) * t,
              _outlineBetween(a, b, t),
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
      _runEnds = {};
      _foldStarts.clear();
      _creases = const [];
      _cachedBrush = brush;
      _cachedTexture = texture;
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
        !flatEnds &&
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
        ..._curveReversals(points, lengths, depthRatio),
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
    final outlineWidth = brush.outlineWidth;
    final last = points.last;
    // A brush taper or pen lift that already ends the strand at a point is
    // the user's own taper, drawn exactly like the ordinary outline pen.
    if (shouldTaperTip &&
        brush.foldMode != HairFoldMode.crescent &&
        last.outerRadius(outlineWidth) > .5) {
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
          return HairRibbonPoint(
            p.position,
            // For a dash shorter than its diameter, the ordinary head disk
            // would cover the point. Fit its width to the available tail span.
            math.min(p.width, tailLength) * taper,
            // Like pressure and a brush taper, the tail narrows the whole
            // strand, outline included; it never fades it.
            p.opacity,
            p.scale * taper,
            p.outline,
          );
        });
      }
    }
    final repeats = lateralOffsets(
      count: brush.lateralRepeatEnabled ? brush.lateralRepeatCount : 1,
      spacing: brush.lateralRepeatSpacing.clamp(0.0, 4.0).toDouble(),
    );
    // Lateral repeats offset every section, so they recomposite in full.
    final incremental =
        repeats.length == 1 && _active && !(flatEnds && taperEnd);
    // A full composite starts the kept surfaces afresh, so the following
    // incremental moves see every tile (fold lines query its coverage).
    if (!incremental) _surfaces.clear();
    final result = repeats.length == 1 ? _surfaces : <int, _SurfaceTile>{};
    final redrawn = <int, _Area>{};
    final runTiles = <int, Set<int>>{};
    final runSignatures = <int, (double, int, double, double)>{};
    final runEnds = <int, int>{};
    final creases = <_CreaseSegment>[];
    var repeatIndex = 0;
    final foldStartsUsed = <(int, int, int, int)>{};
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
                p.scale,
                p.outline,
              );
            });
      // The engine already resolved stabilization. Keep these authored centers
      // unchanged; only the outline normals and width profile are derived here.
      final runs = <_RibbonRun>[];
      final depths = _runDepths(points, lengths, indices, brush.foldMode);
      // Each fold line starts where the inner outlines meet; the front
      // section's own edge is hidden over the back section up to there.
      final foldLines =
          <
            int,
            ({
              Offset origin,
              Offset direction,
              Offset continuation,
              bool smooth,
              double side,
              bool firstFront,
            })
          >{};
      final hidden = <int, double>{};
      if (brush.foldMode != HairFoldMode.crescent) {
        for (var i = 1; i < indices.length - 1; i++) {
          final pivot = indices[i];
          final p = points[pivot];
          final fold = _foldSides(points, lengths, indices, depths, i);
          if (fold == null) continue;
          final sign = fold.sign, firstFront = fold.firstFront;
          final incoming = fold.incoming, outgoing = fold.outgoing;
          // The start depends only on samples a few widths from the fold, so
          // a stroke growing further on keeps it cached.
          final reachable =
              (p.width + p.outlineOr(brush.outlineWidth) * 2) * 6 + 8;
          int within(int end) {
            final step = end < pivot ? -1 : 1;
            var j = pivot;
            while (j != end &&
                (lengths[j] - lengths[pivot]).abs() <= reachable) {
              j += step;
            }
            return j;
          }

          final frontEnd = within(fold.frontEnd);
          final backEnd = within(fold.backEnd);
          final key = (repeatIndex, pivot, frontEnd, backEnd);
          foldStartsUsed.add(key);
          final low = math.max(0, math.min(frontEnd, backEnd) - 2);
          final high = math.min(
            points.length - 1,
            math.max(frontEnd, backEnd) + 2,
          );
          final cached = _foldStarts[key];
          final start =
              cached != null && cached.matches(points, low, high, sign)
              ? cached.start
              : (_foldStarts[key] = _FoldStartCache(
                  points.sublist(low, high + 1),
                  low,
                  sign,
                  _foldLineStart(
                    points,
                    lengths,
                    pivot,
                    frontEnd,
                    backEnd,
                    sign,
                    brush.outlineWidth,
                  ),
                )).start;
          if (start == null) {
            // An overlapping hairpin: the front's own edge marks the fold.
            hidden[pivot] = 0;
            continue;
          }
          foldLines[i] = (
            origin: start.origin,
            direction: start.direction,
            continuation: firstFront ? outgoing : -incoming,
            smooth: start.smooth,
            side: sign,
            firstFront: firstFront,
          );
          hidden[pivot] = math.max(
            p.width,
            (start.origin - p.position).distance +
                p.outlineOr(brush.outlineWidth) +
                1,
          );
        }
      }
      for (var i = 1; i < indices.length; i++) {
        final start = indices[i - 1], end = indices[i];
        if (end <= start) continue;
        runs.add(_RibbonRun(start, end, depths[i - 1], ownerBase + i));
      }
      final crescentTangents = <int, Offset>{};
      final crescentSides = <int, double>{};
      final crescentBlend = <int, double>{};
      final foldBlend = <int, double>{};
      // Where the folded crescent narrows to a waist before a lobe: from
      // the run's start to its apex (head) or from its apex to its end
      // (tail), when its own blend changes faster than the strand's.
      (int, int)? foldHead, foldTail;
      var crescentTurns = const <double>[];
      final crescentApices = <int, int>{};
      final crescentAngles = <int, double>{};
      var crescentCurveStart = 0;
      if (brush.foldMode == HairFoldMode.crescent) {
        final turns = crescentTurns = <double>[0];
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
        final deepRuns = <int>[];
        for (var i = 1; i < indices.length; i++) {
          final start = indices[i - 1], end = indices[i];
          final extent = _curveExtent(points, start, end);
          var signedTurn = 0.0;
          for (var index = start + 1; index <= end; index++) {
            signedTurn += _cross(
              crescentTangents[index - 1]!,
              crescentTangents[index]!,
            );
          }
          crescentApices[start] = extent.apex;
          crescentSides[start] = signedTurn == 0
              ? (i > 1 ? crescentSides[indices[i - 2]]! : 1)
              : signedTurn.sign;
          if (extent.depth > 1e-6 &&
              extent.depth >= extent.width * depthRatio) {
            deepRuns.add(start);
          }
        }
        if (!_crescentActive) {
          // Once activated, the stroke stays a crescent: nothing was drawn
          // before this point, so no stale fold surface can remain.
          if (deepRuns.isEmpty && !flatEnds) return;
          _crescentActive = deepRuns.isNotEmpty;
        }
        // The stroke's ends blend between the ordinary strand and the
        // nearest real crescent, over the turn up to its apex. A sliver of a
        // curve before the first or after the last one (a wave started just
        // before a bend, a C turned a little past half a turn) is too shallow
        // to be a crescent of its own: measured from it, the blend was so
        // short that the sliver bulged into a lump at the start, and at the
        // end its bow ran out into a thread before the tip or square cut.
        // A sliver outside them stays the ordinary strand, so it joins
        // the crescent at full width on both sides of their shared point.
        final headStart = deepRuns.isEmpty ? indices.first : deepRuns.first;
        final firstApex = crescentApices[headStart]!;
        // The strand's change is spread over the whole turn to the apex,
        // however long. Within it the bow runs out towards the chord's end
        // while the ordinary strand keeps the pen's width, so a crescent left
        // at full strength over part of that turn thinned to a waist and the
        // strand then swelled back: its inner edge bent against the curve.
        // That waist and swell are the folded crescent's own shape, which
        // changes over at most 60 degrees: it is drawn as the fold line
        // inside the strand ([foldBlend]), along its outer side.
        final headTurn =
            (turns[firstApex] - turns[headStart]) *
            (headStart == indices.first ? .75 : 1);
        final transitionTurn = math.max(
          .15,
          // From a sliver the crescent starts at full width, not at its
          // tip: spread the change over the whole turn to its apex.
          headTurn,
        );
        final foldTransitionTurn = math.max(
          .15,
          math.min(math.pi / 3, headTurn),
        );
        // The finished stroke's end mirrors its start.
        final tailStart = deepRuns.isEmpty
            ? indices[indices.length - 2]
            : deepRuns.last;
        final tailEnd = indices[indices.indexOf(tailStart) + 1];
        final lastApex = crescentApices[tailStart]!;
        final tailTurn =
            (turns[tailEnd] - turns[lastApex]) *
            (tailEnd == indices.last ? .75 : 1);
        final endTransition = taperEnd ? math.max(.15, tailTurn) : null;
        final foldEndTransition = taperEnd
            ? math.max(.15, math.min(math.pi / 3, tailTurn))
            : null;
        double blendAt(int index, double head, double? end) {
          final t = ((turns[index] - turns[headStart]) / head).clamp(0.0, 1.0);
          var blend = index < headStart ? 0.0 : t * t * (3 - 2 * t);
          if (end != null) {
            final e = ((turns[tailEnd] - turns[index]) / end).clamp(0.0, 1.0);
            blend *= index > tailEnd ? 0 : e * e * (3 - 2 * e);
          }
          return _crescentActive ? blend : 0;
        }

        if (_crescentActive && foldTransitionTurn < transitionTurn) {
          foldHead = (headStart, firstApex);
        }
        if (_crescentActive &&
            endTransition != null &&
            foldEndTransition! < endTransition) {
          foldTail = (lastApex, tailEnd);
        }
        for (var index = 0; index < points.length; index++) {
          crescentBlend[index] = blendAt(index, transitionTurn, endTransition);
          foldBlend[index] = blendAt(
            index,
            foldTransitionTurn,
            foldEndTransition,
          );
        }
      }
      runs.sort((a, b) {
        final order = a.depth.compareTo(b.depth);
        return order != 0 ? order : a.start.compareTo(b.start);
      });
      // Each section with the area it changed this move: null when its mask
      // was rebuilt, otherwise only the area around its appended segments.
      // With the area its mask covered before, when it was drawn again.
      final built =
          <
            (
              _RibbonRun,
              Map<int, _MaskTile>,
              Map<int, _Area>?,
              Map<int, _Area>?,
            )
          >[];
      // Every crescent section's edges, by section: they are found before
      // any is drawn, so the inner edge can be kept to the curve across the
      // joins between sections (see _keepInnerEdgeWithCurve).
      final crescentEdges =
          <
            int,
            List<
              ({
                HairRibbonPoint point,
                Offset outer,
                Offset inner,
                double angle,
              })
            >
          >{};
      final innerPulls = <int, double>{};
      final foldWidths = <int, double>{};
      if (brush.foldMode == HairFoldMode.crescent) {
        ({HairRibbonPoint point, Offset outer, Offset inner, double angle})
        sectionEdge(
          _RibbonRun run,
          int index,
          Offset outerEdge,
          Offset innerEdge,
        ) {
          final point = points[index];
          final across = (outerEdge - innerEdge) * crescentSides[run.start]!;
          final sourceAngle = crescentAngles[index]!;
          final edgeAngle = across.distanceSquared < 1e-10
              ? sourceAngle
              : math.atan2(across.dy, across.dx);
          return (
            point: HairRibbonPoint(
              (outerEdge + innerEdge) / 2,
              (outerEdge - innerEdge).distance,
              point.opacity,
              point.scale,
              point.outline,
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

        for (final run in runs) {
          // A crescent is a pair of bows across the same authored chord.
          // Parallel normal offsets make the inside sharper than the input.
          // Scale the actual chord deviation instead, preserving the source
          // path.
          final chordStart = points[run.start].position;
          final chord = points[run.end].position - chordStart;
          final apexIndex = crescentApices[run.start];
          final chordNormal = _unit(Offset(-chord.dy, chord.dx));
          final apexBow = apexIndex == null
              ? 0.0
              : _dot(points[apexIndex].position - chordStart, chordNormal);
          final outward = chordNormal * apexBow.sign;
          final bowDepth = apexBow.abs();
          // The crescent has no crease. Use its own contour, independent of
          // the controls that shape a crease in the other four modes.
          const crescentShapeStrength = .5;
          const innerPower = 1 + crescentShapeStrength * .35;
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
          final leadIndex = math.min(
            crescentCurveStart,
            apexIndex ?? run.start,
          );
          final leadNormal =
              Offset(
                -crescentTangents[leadIndex]!.dy,
                crescentTangents[leadIndex]!.dx,
              ) *
              -crescentSides[run.start]!;
          final leadSpan = apexIndex == null
              ? 0.0
              : _dot(
                  points[apexIndex].position - points[leadIndex].position,
                  chordAxis,
                );
          ({HairRibbonPoint point, Offset outer, Offset inner, double angle})
          edgeAt(int index, [double? folded]) {
            final point = points[index];
            final crescent = folded ?? crescentBlend[index]!;
            final tangent = crescentTangents[index]!;
            final normal =
                Offset(-tangent.dy, tangent.dx) * -crescentSides[run.start]!;
            final bow = bowDepth < 1e-6
                ? 0.0
                : (_dot(point.position - chordStart, outward) / bowDepth).clamp(
                    0.0,
                    1.0,
                  );
            final outerProfile = math
                .pow(bow, 1 - crescentShapeStrength * .2)
                .toDouble();
            final innerProfile = math.pow(bow, innerPower).toDouble();
            // Return to a symmetric, pressure-resolved cross-section at a
            // tapered endpoint. Otherwise the displaced crescent sides can
            // continue bulging while the ordinary taper is narrowing.
            var endpointBlend = 1.0;
            if (brush.fadeMode == FadeMode.custom) {
              final fromStart = lengths[index];
              final fromEnd = lengths.last - fromStart;
              double transition(FadeEndpointSettings fade, double distance) {
                if (fade.value == 100 || fade.rangePx <= 0) return 1;
                final t = (distance / fade.rangePx).clamp(0.0, 1.0);
                return t * t * (3 - 2 * t);
              }

              endpointBlend = transition(brush.fadeIn, fromStart);
              if (taperEnd) {
                endpointBlend *= transition(brush.fadeOut, fromEnd);
              }
            }
            if (taperEnd && flatEnds) {
              final remaining = lengths.last - lengths[index];
              final t = (remaining / (brush.size * 2)).clamp(0.0, 1.0);
              endpointBlend *= t * t * (3 - 2 * t);
            }
            final blend = crescent * endpointBlend;
            var ordinary = normal * point.width / 2 * (1 - blend);
            // Only the head, up to the apex: past it the ordinary strand
            // comes back at the end, and its edge along the chord (across
            // the bottom of a C) must keep its width.
            if (run.start == 0 &&
                leadSpan > 1e-6 &&
                index > leadIndex &&
                index <= apexIndex!) {
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
            return sectionEdge(run, index, outerEdge, innerEdge);
          }

          crescentEdges[run.start] = [
            for (var index = run.start; index <= run.end; index++)
              edgeAt(index),
          ];
          for (var index = run.start; index <= run.end; index++) {
            // Across the strand, not along it: near a crescent's tip its
            // edges lean far along the strand.
            final tangent = crescentTangents[index]!;
            final across = Offset(-tangent.dy, tangent.dx);
            final fold = foldBlend[index] == crescentBlend[index]
                ? crescentEdges[run.start]![index - run.start]
                : edgeAt(index, foldBlend[index]);
            foldWidths[index] = _dot(fold.outer - fold.inner, across).abs();
          }
        }
        if (_crescentActive) {
          innerPulls.addAll(
            _keepInnerEdgeWithCurve(
              runs,
              points,
              lengths,
              crescentTangents,
              crescentSides,
              crescentEdges,
              brush.outlineWidth,
            ),
          );
          for (final run in runs) {
            final edges = crescentEdges[run.start]!;
            for (var index = run.start; index <= run.end; index++) {
              final pull = innerPulls[index];
              if (pull == null) continue;
              final edge = edges[index - run.start];
              final tangent = crescentTangents[index]!;
              final inward =
                  Offset(-tangent.dy, tangent.dx) * crescentSides[run.start]!;
              edges[index - run.start] = sectionEdge(
                run,
                index,
                edge.outer,
                edge.inner - inward * pull,
              );
            }
          }
          // The folded crescent lies along the strand's outer side, and its
          // inner edge is the strand's inner edge: inside it nothing is
          // drawn. By sample, the share of the strand's width it keeps from
          // the outer edge (the whole strand elsewhere). In the curl its
          // inner edge leaves the strand's, curving with the curl, and
          // closes onto the outer edge at the waist; from there it opens
          // again into a lobe that narrows to the tip (or widens back into
          // the strand where the strand runs on).
          final strandWidths = <int, double>{
            for (final run in runs)
              for (var index = run.start; index <= run.end; index++)
                index: () {
                  final edge = crescentEdges[run.start]![index - run.start];
                  final tangent = crescentTangents[index]!;
                  return _dot(
                    edge.outer - edge.inner,
                    Offset(-tangent.dy, tangent.dx),
                  ).abs();
                }(),
          };
          final bandEdges =
              <
                int,
                ({
                  HairRibbonPoint point,
                  Offset outer,
                  Offset inner,
                  double angle,
                })
              >{};
          final bandSides = <int, double>{};
          for (final run in runs) {
            for (var index = run.start; index <= run.end; index++) {
              bandEdges[index] = crescentEdges[run.start]![index - run.start];
              bandSides[index] = crescentSides[run.start]!;
            }
          }
          final shares = <int, double>{};
          // The strand's edge's heading at a sample, in drawing order.
          Offset headingAt(Offset Function(int) at, int index) => _unit(
            at(math.min(points.length - 1, index + 1)) -
                at(math.max(0, index - 1)),
          );
          Offset outerAt(int index) => bandEdges[index]!.outer;
          Offset innerAt(int index) => bandEdges[index]!.inner;
          // Where the section at a sample crosses a path, as the share of
          // the strand kept from its outer edge, looking along the path from
          // [cursor.first] on (the sections cross it in turn).
          double? crossing(List<Offset> path, int index, List<int> cursor) {
            final outer = outerAt(index);
            final across = innerAt(index) - outer;
            final width = across.distance;
            if (width < 1e-6) return null;
            final unit = across / width;
            for (var j = cursor.first; j < path.length - 1; j++) {
              final a = _cross(unit, path[j] - outer);
              final b = _cross(unit, path[j + 1] - outer);
              if ((a > 0 && b > 0) || (a < 0 && b < 0) || a == b) continue;
              final at = path[j] + (path[j + 1] - path[j]) * (a / (a - b));
              cursor.first = j;
              return _dot(at - outer, unit) / width;
            }
            return null;
          }

          // The folded crescent's inner edge is drawn as curves of its own,
          // each turning with the curl all the way, rather than as a share
          // of the strand's width changing along it: a share that changes
          // smoothly still bends the edge unevenly (the strand's own width
          // and edges change along the curl), and an edge kept from turning
          // against the curl afterwards was left with straight runs and
          // corners between them.
          void lobe((int, int) range, int end, int towards) {
            var waist = range.$1;
            for (var index = range.$1; index <= range.$2; index++) {
              if (foldWidths[index]! < foldWidths[waist]!) waist = index;
            }
            // The lobe lasts as long as the curl: up to where the stroke
            // stops turning (a straight run after it keeps no fold).
            var far = waist;
            while (far != end &&
                (crescentTurns[far] - crescentTurns[end]).abs() >
                    math.pi / 180) {
              far += towards;
            }
            final crescentApex = towards > 0 ? range.$1 : range.$2;
            var curlStart = crescentApex;
            while (curlStart - towards >= 0 &&
                curlStart - towards < points.length &&
                (crescentTurns[curlStart] - crescentTurns[curlStart - towards])
                        .abs() >
                    1e-3) {
              curlStart -= towards;
            }
            if (waist == curlStart || far == waist) return;
            final width = strandWidths[waist]!;
            final narrowest = width <= 1e-9
                ? 1.0
                : math.min(1.0, foldWidths[waist]! / width);
            // Only a crescent that narrows to a waist (under a quarter of
            // the strand, fading out by half) folds: a shallow dip keeps the
            // strand whole.
            final g = ((.5 - narrowest) / .25).clamp(0.0, 1.0);
            // And only a curl that turns half a circle or more from where it
            // starts to the lobe's end, fading out by a third of a circle: a
            // wobble along a straight run narrows the strand much the same.
            final curled =
                (crescentAngles[far]! - crescentAngles[curlStart]!) *
                bandSides[waist]! *
                towards;
            final c = ((curled - math.pi * 2 / 3) / (math.pi / 3)).clamp(
              0.0,
              1.0,
            );
            final folds = g * g * (3 - 2 * g) * c * c * (3 - 2 * c);
            if (folds == 0) return;
            // On the way from where the fold leaves the strand's inner edge
            // to the lobe's end, the curl turns towards [sigma] (see
            // [_cross]).
            final sigma = bandSides[waist]! * towards;
            Offset heading(Offset Function(int) at, int index) =>
                headingAt(at, index) * towards.toDouble();
            Offset turned(Offset direction, double angle) =>
                direction * math.cos(angle) +
                Offset(-direction.dy, direction.dx) * (sigma * math.sin(angle));
            final waistHeading = heading(outerAt, waist);
            // The sweep: an arc of a circle, from the strand's inner edge
            // (along it) to the outer edge at the waist, so that with the
            // outer edge it bounds a crescent. The earlier in the curl it
            // leaves the strand's inner edge, the more gradually the strand
            // narrows, and the more nearly along the outer edge it reaches
            // the waist. It leaves where the stroke still turns a quarter
            // circle before the waist, or earlier so that it reaches the
            // outer edge at no more than [steepest] (on a thick strand), or
            // later so that it reaches it at no less than [shallowest] (on
            // a thin one): the two outlines meet at a horn's angle and part
            // at once, rather than run along together into one thick line.
            const steepest = 25 * math.pi / 180,
                shallowest = 10 * math.pi / 180;
            // The arc from a sample: half its turn, and the angle at which
            // it meets the outer edge (null when it cannot reach it from
            // inside, turning with the curl).
            (double, double)? arcFrom(int index) {
              final startHeading = heading(innerAt, index);
              final chord = outerAt(waist) - innerAt(index);
              final half =
                  math.atan2(
                    _cross(startHeading, chord),
                    _dot(startHeading, chord),
                  ) *
                  sigma;
              if (half <= 0 || half >= math.pi / 2) return null;
              final arriving = turned(startHeading, 2 * half);
              final meets =
                  math.atan2(
                    _cross(arriving, waistHeading),
                    _dot(arriving, waistHeading),
                  ) *
                  sigma;
              return meets > 0 ? (half, meets) : null;
            }

            // The arc's points from a sample.
            List<Offset> arcPath(int index, double half) {
              final start = innerAt(index);
              final startHeading = heading(innerAt, index);
              final radius =
                  (outerAt(waist) - start).distance / (2 * math.sin(half));
              final inwards = Offset(-startHeading.dy, startHeading.dx) * sigma;
              final steps = (2 * half * radius / 2).ceil().clamp(16, 512);
              return [
                for (var k = 0; k <= steps; k++)
                  () {
                    final turn = 2 * half * k / steps;
                    return start +
                        startHeading * (radius * math.sin(turn)) +
                        inwards * (radius * (1 - math.cos(turn)));
                  }(),
              ];
            }

            // Whether the arc stays within the strand up to the waist: where
            // the outer edge curves more than the arc, it can leave the
            // strand before the waist, and the strand would be no more than
            // its outline there.
            bool within(int index, List<Offset> path) {
              final cursor = [0];
              for (var i = index + towards; i != waist; i += towards) {
                final share = crossing(path, i, cursor);
                if (share != null && (share < -.02 || share > 1.02)) {
                  return false;
                }
              }
              return true;
            }

            List<Offset>? sweep;
            var leave = -1;
            final feasible = <int>[];
            for (
              var index = waist - towards;
              index != curlStart - towards;
              index -= towards
            ) {
              final arc = arcFrom(index);
              if (arc == null) continue;
              feasible.add(index);
              final curl =
                  (crescentAngles[waist]! - crescentAngles[index]!) *
                  bandSides[waist]! *
                  towards;
              if (arc.$2 <= steepest &&
                  (curl >= math.pi / 2 || arc.$2 <= shallowest)) {
                final path = arcPath(index, arc.$1);
                if (within(index, path)) {
                  sweep = path;
                  leave = index;
                  break;
                }
              }
            }
            // Otherwise from as early in the curl as it can.
            for (final index in feasible.reversed) {
              if (sweep != null) break;
              final path = arcPath(index, arcFrom(index)!.$1);
              if (within(index, path)) {
                sweep = path;
                leave = index;
              }
            }
            if (sweep == null) return;
            // The lobe, from the waist. Where the strand runs on after the
            // curl: a curve back onto its inner edge (along it), leaving the
            // outer edge at a horn's angle. Where it ends at the tip: the
            // outer edge pressed towards its chord from the waist to the
            // tip, so that it bends with the outer edge, a little less, and
            // narrows to both ends.
            final runsOn = strandWidths[far]! > 4 * brush.outlineWidth;
            List<Offset>? onward;
            if (runsOn) {
              for (final angle in const [20.0, 12.0, 6.0]) {
                onward = _convexCubic(
                  outerAt(waist),
                  turned(waistHeading, angle * math.pi / 180),
                  innerAt(far),
                  heading(innerAt, far),
                  sigma,
                );
                if (onward != null) break;
              }
              if (onward == null) return;
            }
            final lobeEnd = runsOn ? far : end;
            final kept = <int, double>{};
            void place(List<Offset> path, int from, int to) {
              final cursor = [0];
              for (var index = from; index != to + towards; index += towards) {
                final share = crossing(path, index, cursor);
                if (share != null) kept[index] = share.clamp(0.0, 1.0);
              }
            }

            place(sweep, leave, waist);
            kept[waist] = 0;
            if (onward != null) {
              place(onward, waist, far);
            } else {
              final from = outerAt(waist);
              final axis = _unit((outerAt(end) + innerAt(end)) / 2 - from);
              var widest = 0.0;
              for (
                var index = waist;
                index != end + towards;
                index += towards
              ) {
                widest = math.max(
                  widest,
                  _cross(axis, outerAt(index) - from).abs(),
                );
              }
              // At its widest the lobe is half the pen's width at the waist,
              // or narrower so that its inner edge bends at least about
              // half as much as the outer edge. Within the strand: pressed
              // further where it would leave it.
              var keep = widest <= 1e-9
                  ? 1.0
                  : (1 - .5 * points[waist].width / widest).clamp(.55, 1.0);
              final lobe = <int, double>{};
              for (var attempt = 0; attempt < 6; attempt++) {
                final pressed = [
                  for (
                    var index = waist;
                    index != end + towards;
                    index += towards
                  )
                    () {
                      final outer = outerAt(index);
                      final foot = from + axis * _dot(outer - from, axis);
                      return foot + (outer - foot) * keep;
                    }(),
                ];
                lobe.clear();
                final cursor = [0];
                var fullest = 0.0;
                for (
                  var index = waist + towards;
                  index != end + towards;
                  index += towards
                ) {
                  final share = crossing(pressed, index, cursor);
                  if (share == null) continue;
                  lobe[index] = share;
                  fullest = math.max(fullest, share);
                }
                if (fullest <= .95) break;
                keep = 1 - (1 - keep) * .95 / fullest;
              }
              for (final entry in lobe.entries) {
                kept[entry.key] = entry.value.clamp(0.0, 1.0);
              }
            }
            if (folds < 1) {
              // A shallower fold lies between the strand and the folded
              // crescent, and does not close: its inner edge passes the
              // waist inside the strand, without the horns' corner. Where it
              // would turn there, it turns along a parabola tangent to the
              // edge either side instead, over a stretch the longer the
              // shallower the fold.
              final order = [
                for (
                  var index = leave;
                  index != lobeEnd + towards;
                  index += towards
                )
                  if (kept.containsKey(index)) index,
              ];
              final shallower = {
                for (final index in order)
                  index: 1 - folds * (1 - kept[index]!),
              };
              kept.addAll(shallower);
              final at = [
                for (final index in order)
                  outerAt(index) +
                      (innerAt(index) - outerAt(index)) * shallower[index]!,
              ];
              final corner = order.indexOf(waist);
              final along = <double>[0];
              for (var k = 1; k < at.length; k++) {
                along.add(along.last + (at[k] - at[k - 1]).distance);
              }
              if (corner > 0 && corner < at.length - 1) {
                final reach =
                    math.min(math.sqrt(1 - folds), .9) *
                    math.min(along[corner], along.last - along[corner]);
                // A point on the edge at a distance along it, with the
                // heading of the stretch it lies on and the next sample.
                (Offset, Offset, int) pointAt(double distance) {
                  var k = 1;
                  while (k < at.length - 1 && along[k] < distance) {
                    k++;
                  }
                  final span = along[k] - along[k - 1];
                  final t = span <= 1e-9
                      ? 0.0
                      : ((distance - along[k - 1]) / span).clamp(0.0, 1.0);
                  return (
                    at[k - 1] + (at[k] - at[k - 1]) * t,
                    _unit(at[k] - at[k - 1]),
                    k,
                  );
                }

                // Shorter where the parabola would leave the strand (its
                // tangents meet beyond the outer edge).
                for (var stretch = reach; stretch > 1; stretch /= 2) {
                  final (a, aHeading, aNext) = pointAt(along[corner] - stretch);
                  final (b, bHeading, bNext) = pointAt(along[corner] + stretch);
                  // Where the two headings meet.
                  var control = at[corner];
                  final denominator = _cross(aHeading, bHeading);
                  if (denominator.abs() > 1e-6) {
                    final t = _cross(b - a, bHeading) / denominator;
                    final meet = a + aHeading * t;
                    if (t > 0 && _dot(b - meet, bHeading) > 0) control = meet;
                  }
                  final count = math.max(8, stretch.ceil());
                  final rounded = [
                    ...at.sublist(0, aNext),
                    for (var k = 0; k <= count; k++)
                      () {
                        final t = k / count, u = 1 - t;
                        return a * (u * u) +
                            control * (2 * u * t) +
                            b * (t * t);
                      }(),
                    ...at.sublist(bNext),
                  ];
                  final cursor = [0];
                  final placed = <int, double>{};
                  var inside = true;
                  for (final index in order) {
                    final share = crossing(rounded, index, cursor);
                    if (share == null) continue;
                    if (share < -.02 || share > 1.02) {
                      inside = false;
                      break;
                    }
                    placed[index] = share.clamp(0.0, 1.0);
                  }
                  if (!inside) continue;
                  kept.addAll(placed);
                  break;
                }
              }
            }
            for (final entry in kept.entries) {
              shares[entry.key] = math.min(shares[entry.key] ?? 1, entry.value);
            }
          }

          if (foldHead != null) lobe(foldHead, 0, -1);
          if (foldTail != null) lobe(foldTail, points.length - 1, 1);
          if (shares.isNotEmpty) {
            for (final run in runs) {
              final edges = crescentEdges[run.start]!;
              for (var index = run.start; index <= run.end; index++) {
                final share = shares[index];
                if (share == null || share >= 1) continue;
                final edge = edges[index - run.start];
                edges[index - run.start] = sectionEdge(
                  run,
                  index,
                  edge.outer,
                  edge.outer + (edge.inner - edge.outer) * share,
                );
                innerPulls[index] =
                    (innerPulls[index] ?? 0) +
                    (1 - share) * strandWidths[index]!;
              }
            }
            // The folded edge, too, never turns against the curve.
            final pulls = _keepInnerEdgeWithCurve(
              runs,
              points,
              lengths,
              crescentTangents,
              crescentSides,
              crescentEdges,
              brush.outlineWidth,
            );
            for (final run in runs) {
              final edges = crescentEdges[run.start]!;
              for (var index = run.start; index <= run.end; index++) {
                final pull = pulls[index];
                if (pull == null) continue;
                final edge = edges[index - run.start];
                final tangent = crescentTangents[index]!;
                final inward =
                    Offset(-tangent.dy, tangent.dx) * crescentSides[run.start]!;
                edges[index - run.start] = sectionEdge(
                  run,
                  index,
                  edge.outer,
                  edge.inner - inward * pull,
                );
                innerPulls[index] = (innerPulls[index] ?? 0) + pull;
              }
            }
          }
        }
      }
      // Up to the first sample the crescent shapes, the strand is drawn as
      // ordinary stamps. From there on every segment is drawn from its
      // edges: along a fast taper, stamps reach wider than the edges, so
      // where a crescent gave way to stamps the outline stepped out.
      var firstShaped = points.length;
      if (brush.foldMode == HairFoldMode.crescent) {
        for (var index = 0; index < points.length; index++) {
          if (crescentBlend[index]! > 0) {
            firstShaped = index;
            break;
          }
        }
      }
      for (final run in runs) {
        final geometry = brush.foldMode == HairFoldMode.crescent
            ? <Object>[
                crescentApices[run.start]!,
                crescentSides[run.start]!,
                if (taperEnd) lengths.last,
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
                    innerPulls[index] ?? 0.0,
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
              first.scale,
              first.outline,
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
              a.opacity == b.opacity &&
              a.outline == b.outline) {
            final direction = b.position - a.position;
            while (i < run.end && direction.distanceSquared > 1e-10) {
              final next = points[i + 1],
                  delta = points[i + 1].position - a.position;
              if (next.width != a.width ||
                  next.opacity != a.opacity ||
                  next.outline != a.outline ||
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
            final edges = crescentEdges[run.start]!;
            ({HairRibbonPoint point, Offset outer, Offset inner, double angle})
            edgeAt(int index) => edges[index - run.start];

            final first = edgeAt(i - 1), last = edgeAt(i);
            a = first.point;
            b = last.point;
            textureAngleA = first.angle;
            textureAngleB = last.angle;
            if (crescentBlend[i]! == 0 &&
                i <= firstShaped &&
                !innerPulls.containsKey(i - 1) &&
                !innerPulls.containsKey(i)) {
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
                var currentOuter = outer;
                var currentInner = inner;
                if (brush.fadeMode == FadeMode.custom) {
                  final maximum = math.max(a.width, b.width);
                  final across = outer - inner;
                  if (across.distance > maximum) {
                    final center = (outer + inner) / 2;
                    final half = across * (maximum / (2 * across.distance));
                    currentOuter = center + half;
                    currentInner = center - half;
                  }
                }
                final current = HairRibbonPoint(
                  Offset.lerp(a.position, b.position, t)!,
                  a.width + (b.width - a.width) * t,
                  a.opacity + (b.opacity - a.opacity) * t,
                  a.scale + (b.scale - a.scale) * t,
                  _outlineBetween(a, b, t),
                );
                // The bowed edges bound the strand; pressure and taper inset
                // its fill so the outline keeps its width.
                final from = _insetEdges(
                  previousOuter,
                  previousInner,
                  previous.scale,
                  previous.outlineOr(brush.outlineWidth),
                );
                final to = _insetEdges(
                  currentOuter,
                  currentInner,
                  current.scale,
                  current.outlineOr(brush.outlineWidth),
                );
                if (from.fill > 0 || to.fill > 0) {
                  _ribbonSegment(
                    envelope,
                    previous,
                    current,
                    [from.outer, to.outer, to.inner, from.inner],
                    from.band,
                    to.band,
                  );
                } else {
                  // No fill left: a solid outline tip.
                  _segment(
                    envelope,
                    HairRibbonPoint(
                      (previousOuter + previousInner) / 2,
                      (previousOuter - previousInner).distance,
                      previous.opacity,
                      previous.scale,
                      previous.outline,
                    ),
                    HairRibbonPoint(
                      (currentOuter + currentInner) / 2,
                      (currentOuter - currentInner).distance,
                      current.opacity,
                      current.scale,
                      current.outline,
                    ),
                    brush.outlineWidth,
                  );
                }
                previous = current;
                previousOuter = currentOuter;
                previousInner = currentInner;
              }
              if (i == points.length - 1 && crescentBlend[i]! == 0) {
                // The ordinary strand's own round end, as its stamps drew it.
                _segment(
                  envelope,
                  HairRibbonPoint(
                    b.position - crescentTangents[i]! * .001,
                    b.width,
                    b.opacity,
                    b.scale,
                    b.outline,
                  ),
                  b,
                  brush.outlineWidth,
                );
              }
            }
          }
          if (texture == null) {
            if (brush.foldMode != HairFoldMode.crescent) {
              _segment(mask, a, b, brush.outlineWidth);
            }
          } else {
            _texturedSegment(
              mask,
              a,
              b,
              brush,
              texture,
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
          _spare(envelope);
        }
        Map<int, _Area>? replaced;
        if (canCache) {
          if (cached != null && !reusable) {
            replaced = _extentOf(cached.mask);
            _spare(cached.mask);
          }
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
          replaced,
        ));
      }
      final dirty = <int, _Area>{};
      void markWhole(Iterable<int> keys) {
        for (final key in keys) {
          dirty[key] = _Area.whole;
        }
      }

      for (final (run, mask, changed, replaced) in built) {
        final keys = mask.keys.toSet();
        final signature = (
          run.depth,
          run.id,
          hidden[run.start] ?? -1,
          hidden[run.end] ?? -1,
        );
        if (offset == 0) {
          runTiles[run.start] = keys;
          runSignatures[run.start] = signature;
          runEnds[run.start] = run.end;
        }
        final previous = _runTiles[run.start];
        final was = _runSignatures[run.start];
        if (!incremental ||
            (changed == null && replaced == null) ||
            previous == null ||
            was == null ||
            was.$1 != signature.$1 ||
            was.$2 != signature.$2 ||
            (was.$4 != signature.$4 && _runEnds[run.start] != run.end)) {
          markWhole(keys);
          if (previous != null) markWhole(previous);
        } else {
          // Drawn again, or where a fold hides its own edge moved: only in
          // the tiles it is drawn on, as when they were all drawn again.
          final drawn = changed == null || was != signature
              ? {...keys, ...previous}
              : null;
          void mark(Map<int, _Area> areas) => _mergeAreas(
            dirty,
            drawn == null
                ? areas
                : {
                    for (final MapEntry(:key, :value) in areas.entries)
                      if (drawn.contains(key)) key: value,
                  },
          );
          // What its mask covers now, and covered before when it was drawn
          // again (a crescent being drawn, whose whole shape follows its
          // newest point): anywhere else this section is not drawn.
          mark(changed ?? _extentOf(mask));
          if (replaced != null) mark(replaced);
          // Where a fold hides the section's own edge moved (its fold line
          // starts further on as the stroke grows): only pixels that close
          // to the fold change.
          for (final (index, before, after) in [
            (run.start, was.$3, signature.$3),
            (run.end, was.$4, signature.$4),
          ]) {
            if (before == after) continue;
            final width = points[index].width;
            final reach = math.max(
              before < 0 ? width : before,
              after < 0 ? width : after,
            );
            final at = points[index].position;
            mark(_areaOf(at.dx, at.dy, at.dx, at.dy, reach + 2));
          }
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
          for (final (run, mask, _, _) in built) {
            final m = mask[key];
            if (m != null) {
              _composite(
                surface,
                key,
                m,
                run,
                points,
                brush,
                hidden,
                cutEnd: flatEnds && taperEnd,
              );
            }
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
      // On a smooth bend, where the outlines never cross, it leads in from
      // the front's inner outline further back ([_smoothFoldLead]).
      if (brush.foldMode != HairFoldMode.crescent) {
        for (var i = 1; i < indices.length - 1; i++) {
          final line = foldLines[i];
          if (line == null) continue;
          final p = points[indices[i]];
          var origin = line.origin, direction = line.direction;
          final continuation = line.continuation;
          // A continuous 270-degree fold keeps the authored turn direction:
          // a shorter, later, gentler line than a direction change.
          final continuous = bends[i - 1].continuous;
          // On a smooth bend the line carries the front's inner outline on
          // straight from where it is straightest ([_smoothFoldLead]), up to
          // about the apex, before it turns: it never runs outside that
          // extension, where the folded part would look suddenly thinner.
          var lead = 0.0;
          if (!continuous && (line.smooth || directionalTip)) {
            final straight = _smoothFoldLead(
              points,
              lengths,
              indices[i],
              line.firstFront ? indices[i - 1] : indices[i + 1],
              line.side,
              brush.outlineWidth,
              followOutline: directionalTip,
            );
            if (straight != null) {
              origin = straight.origin;
              direction = straight.direction;
              lead = straight.lead;
            }
          }
          if (texture != null) {
            // The projected nib gives us a candidate, but the swept alpha
            // mask can put the visible inner outline several pixels away.
            final inner =
                Offset(-direction.dy, direction.dx) *
                (line.firstFront ? line.side : -line.side);
            origin = _creaseOriginOnOutline(
              result,
              origin,
              direction,
              inner,
              (math.max(brush.size, p.width) / 2 +
                      p.outlineOr(brush.outlineWidth))
                  .clamp(2.0, 24.0),
              ownerBase + i,
            );
          }
          final departure = Brush.clampFoldDepartureAngle(
            brush.foldDepartureAngle,
          );
          if (departure != 0) {
            // Mirror the offset on opposite bends. Positive points away from
            // the inner edge and into the face on either side of the stroke.
            final sign = line.firstFront ? -line.side : line.side;
            final angle = departure * sign * math.pi / 180;
            final cos = math.cos(angle), sin = math.sin(angle);
            direction = Offset(
              direction.dx * cos - direction.dy * sin,
              direction.dx * sin + direction.dy * cos,
            );
          }
          // Measure the straight section from the visible join. Constrain
          // its range to this bend so a late curve can still begin inside it.
          final lengthRatio = brush.foldLengthRatio.clamp(0.0, 1.0);
          if (lengthRatio == 0) continue;
          final owner = ownerBase + i;
          final limit = lead + p.width * 2 * (continuous ? .32 : 1.0);
          final delay = brush.foldCurveStartRatio.clamp(0.0, 1.0);
          final curvedShare = 1 - delay;
          final straightReach = _creaseReach(
            result,
            origin,
            direction,
            limit,
            p.width * .15,
            owner,
          );
          // An earlier curve can turn back into the ribbon and travel
          // farther than its straight extension. A sharp corner turns
          // faster, so it has more room for that continuation.
          final extra =
              (line.smooth ? straightReach * .35 : limit) *
              curvedShare *
              curvedShare;
          final available = math.min(limit, straightReach + extra);
          final length = available * lengthRatio;
          if (length < 1) continue;
          final straight = length * delay;
          final curved = length - straight;
          final turn = math.atan2(
            _cross(direction, continuation),
            _dot(direction, continuation),
          );
          // The curve follows the stroke's turn. Smooth bends turn gradually;
          // the later they start, the less of the turn they can follow.
          final turnRate = (turn * brush.foldAngleRatio.clamp(0.0, 1.0) * 2)
              .clamp(-math.pi * .9, math.pi * .9);
          final taper = brush.foldEndTaperRatio.clamp(.01, 1.0);
          final width = p.outlineOr(brush.outlineWidth);
          const sampleStep = 1.25;
          var distance = 0.0;
          var previous = origin;
          while (distance < length) {
            var next = math.min(length, distance + sampleStep);
            // Put a sample exactly at the join of the straight and curved
            // parts. No sample before it rotates away from the tangent.
            if (distance < straight) next = math.min(next, straight);
            final progress = curved <= 0
                ? 0.0
                : math.max(0, (distance + next) / 2 - straight) / curved;
            final angle =
                turnRate *
                (line.smooth ? progress * progress * curvedShare : progress);
            final c = math.cos(angle), sn = math.sin(angle);
            final heading = Offset(
              direction.dx * c - direction.dy * sn,
              direction.dx * sn + direction.dy * c,
            );
            final at = previous + heading * (next - distance);
            if (distance > 0 && !_covered(result, at)) break;
            final t = (distance + next) / (2 * length);
            final lineWidth =
                width * (1 - ((t - (1 - taper)) / taper).clamp(0.0, 1.0));
            creases.add(
              _CreaseSegment(previous, at, lineWidth, owner, p.opacity),
            );
            previous = at;
            distance = next;
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
    _runs.removeWhere((start, run) {
      if (indices.contains(start)) return false;
      _spare(run.mask);
      return true;
    });
    _foldStarts.removeWhere((key, _) => !foldStartsUsed.contains(key));
    final firstComposite = !incremental;
    _active = true;
    _runTiles = runTiles;
    _runSignatures = runSignatures;
    _runEnds = runEnds;
    _creases = creases;
    // The first composite replaces the ordinary stroke drawn so far. Later
    // moves rewrite only the changed area of each changed tile, through
    // getOrCreateTile so that only those tiles' cached images are dropped.
    if (firstComposite) tiles.applyTileSnapshot(layer, _before);
    final outline = Color(brush.outlineColor);
    // Per-pixel Color.lerp allocates; mix the channels directly instead.
    final fillR = fillColor.r, fillG = fillColor.g;
    final fillB = fillColor.b, fillA = fillColor.a;
    final lineR = outline.r, lineG = outline.g;
    final lineB = outline.b, lineA = outline.a;
    double unit(double v) => v < 0
        ? 0.0
        : v > 1
        ? 1.0
        : v;
    final behind = !brush.outlineKeepOverlap;
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
            var cover = s.cover[p];
            if (cover <= 0) continue;
            final perimeter = unit((s.outer[p] - s.fill[p]) / cover);
            var mix = unit(math.max(s.outline[p], perimeter));
            if (behind && mix > 0) {
              // Not keeping overlaps, the strand's outline and fold lines go
              // behind what the layer showed before the stroke (restored just
              // above), so where it merges with earlier strokes they vanish
              // together; its fill stays on top. Only the silhouette's
              // perimeter lies outside the fill, so only there does the
              // earlier picture show through; fold lines and section edges
              // lie on the strand's own fill, which shows in their place
              // rather than a notch.
              final earlier = target[p * 4 + 3] / 255;
              final kept = 1 - perimeter * earlier;
              if (kept <= 0) continue;
              mix = mix * (1 - earlier) / kept;
              cover *= kept;
            }
            final rest = 1.0 - mix;
            final alpha = (255 * cover * unit(fillA * rest + lineA * mix))
                .round()
                .clamp(0, 255);
            if (alpha == 0) continue;
            // TileManager.blendPixel, inline: this runs per pixel.
            final r = (unit(fillR * rest + lineR * mix) * 255).round();
            final g = (unit(fillG * rest + lineG * mix) * 255).round();
            final b = (unit(fillB * rest + lineB * mix) * 255).round();
            final i = p * 4, ig = i + 1, ib = i + 2, ia = i + 3;
            final srcA = alpha / 255.0;
            final keep = 1.0 - srcA;
            final outA = (alpha + target[ia] * keep).round().clamp(0, 255);
            target[i] = _over(r, target[i], srcA, keep, outA);
            target[ig] = _over(g, target[ig], srcA, keep, outA);
            target[ib] = _over(b, target[ib], srcA, keep, outA);
            target[ia] = outA;
          }
        }
      }
      tiles.markDirty(layer, tx, ty);
    }
  }

  /// One channel of [TileManager.blendPixel]: [c] (straight) over [under]
  /// (premultiplied, as the tiles are).
  static int _over(int c, int under, double srcA, double keep, int outA) =>
      (c * srcA + under * keep).round().clamp(0, outA);

  /// The fill and outer radii come from each end's width and scale
  /// ([outlinedStrokeRadii]); being linear in both, they are interpolated
  /// along the segment, so sparse samples still keep the outline's width.
  void _segment(
    Map<int, _MaskTile> masks,
    HairRibbonPoint a,
    HairRibbonPoint b,
    double outlineWidth,
  ) {
    final dX = b.position.dx - a.position.dx,
        dY = b.position.dy - a.position.dy;
    final squared = dX * dX + dY * dY;
    if (squared < 1e-10) return;
    final outerA = a.outerRadius(outlineWidth);
    final outerB = b.outerRadius(outlineWidth);
    final fillA = a.fillRadius(outlineWidth);
    final fillB = b.fillRadius(outlineWidth);
    final radius = math.max(outerA, outerB) + 1;
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
    final ax = a.position.dx, ay = a.position.dy;
    // The outer edge's cone.
    final radiusDelta = outerB - outerA;
    final length = math.sqrt(squared);
    final slope = radiusDelta / length;
    final steep = slope.abs() >= 1;
    final lean = steep ? 0.0 : math.sqrt(1 - slope * slope);
    final fillRise = fillB - fillA;
    final opacityA = a.opacity, opacityRise = b.opacity - a.opacity;
    // Nearer than this to the line through the segment, a pixel may be
    // inked; any further, its distance from the segment is further still.
    final within = math.max(outerA, outerB) + .5 + 1e-6;
    final tilesX = tiles.tilesX;
    var lastKey = -1;
    _MaskTile? lastTile;
    for (var y = top; y <= bottom; y++) {
      final deltaY = y + .5 - ay;
      final row = (y % _size) * _size;
      final tileRow = (y ~/ _size) * tilesX;
      for (var x = left; x <= right; x++) {
        final deltaX = x + .5 - ax;
        final perpendicular = (dX * deltaY - dY * deltaX).abs() / length;
        if (perpendicular >= within) continue;
        final projection = (deltaX * dX + deltaY * dY) / length;
        double t;
        if (steep) {
          t = slope > 0 ? 1.0 : 0.0;
        } else {
          t = (projection + slope * perpendicular / lean) / length;
          if (t < 0) {
            t = 0.0;
          } else if (t > 1) {
            t = 1.0;
          }
        }
        final offsetX = deltaX - dX * t, offsetY = deltaY - dY * t;
        final distance = math.sqrt(offsetX * offsetX + offsetY * offsetY);
        final reach = outerA + radiusDelta * t;
        final half = outlinedFill(fillA + fillRise * t);
        // A tip thinner than a pixel covers only its own width of it, so a
        // tip tapered to nothing ends there and, with no fill left, is solid
        // outline even on its center line.
        var edge = reach + .5 - distance;
        if (edge < 0) {
          edge = 0.0;
        } else if (edge > 1) {
          edge = 1.0;
        }
        final outer = math.min(edge, reach * 2);
        if (outer <= 0) continue;
        var fill = 0.0;
        if (half > 0) {
          fill = half + .5 - distance;
          if (fill < 0) {
            fill = 0.0;
          } else if (fill > 1) {
            fill = 1.0;
          }
        }
        final opacity = opacityA + opacityRise * t;
        final key = tileRow + x ~/ _size;
        if (key != lastKey) {
          lastKey = key;
          lastTile = masks.putIfAbsent(key, _blankMask);
        }
        final m = lastTile!;
        final p = row + x % _size;
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
  // are internal to the ribbon and must not introduce antialias seams. The
  // outline reaches [outlineA] past the fill at [a]'s end and [outlineB] at
  // [b]'s, and between them in proportion: where the fill runs out at one
  // end (a solid outline tip begins), that end's outline is the whole
  // section, and reaching as far at the other end would swell the edge.
  void _ribbonSegment(
    Map<int, _MaskTile> masks,
    HairRibbonPoint a,
    HairRibbonPoint b,
    List<Offset> corners,
    double outlineA,
    double outlineB,
  ) {
    final margin = math.max(outlineA, outlineB) + 1;
    final c0 = corners[0], c1 = corners[1], c2 = corners[2], c3 = corners[3];
    final x0 = c0.dx, y0 = c0.dy, x1 = c1.dx, y1 = c1.dy;
    final x2 = c2.dx, y2 = c2.dy, x3 = c3.dx, y3 = c3.dy;
    final left = (math.min(math.min(math.min(x0, x1), x2), x3) - margin)
        .floor()
        .clamp(0, tiles.canvasWidth - 1);
    final right = (math.max(math.max(math.max(x0, x1), x2), x3) + margin)
        .ceil()
        .clamp(0, tiles.canvasWidth - 1);
    final top = (math.min(math.min(math.min(y0, y1), y2), y3) - margin)
        .floor()
        .clamp(0, tiles.canvasHeight - 1);
    final bottom = (math.max(math.max(math.max(y0, y1), y2), y3) + margin)
        .ceil()
        .clamp(0, tiles.canvasHeight - 1);
    final ax = a.position.dx, ay = a.position.dy;
    final deltaX = b.position.dx - ax, deltaY = b.position.dy - ay;
    final squared = deltaX * deltaX + deltaY * deltaY;
    final opacityA = a.opacity, opacityRise = b.opacity - a.opacity;
    // The four edges, corner i to corner i + 1.
    final ex0 = x1 - x0, ey0 = y1 - y0, ex1 = x2 - x1, ey1 = y2 - y1;
    final ex2 = x3 - x2, ey2 = y3 - y2, ex3 = x0 - x3, ey3 = y0 - y3;
    final es0 = ex0 * ex0 + ey0 * ey0, es1 = ex1 * ex1 + ey1 * ey1;
    final es2 = ex2 * ex2 + ey2 * ey2, es3 = ex3 * ex3 + ey3 * ey3;
    final reachA = outlineA + .5, reachRise = outlineB - outlineA;
    final tilesX = tiles.tilesX;
    var lastKey = -1;
    _MaskTile? lastTile;
    // Per pixel, its squared distance from each edge and whether it is
    // inside (a ray to its left crosses the edges an odd number of times),
    // in plain doubles: this runs per pixel of every crescent strip.
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
      final fy0 = cy - y0, fy1 = cy - y1, fy2 = cy - y2, fy3 = cy - y3;
      // Which edges a ray to the left of the pixel centre crosses on this
      // row, and where.
      final cross0 = (y0 > cy) != (y1 > cy);
      final cross1 = (y1 > cy) != (y2 > cy);
      final cross2 = (y2 > cy) != (y3 > cy);
      final cross3 = (y3 > cy) != (y0 > cy);
      final at0 = cross0 ? x0 + (cy - y0) * ex0 / ey0 : 0.0;
      final at1 = cross1 ? x1 + (cy - y1) * ex1 / ey1 : 0.0;
      final at2 = cross2 ? x2 + (cy - y2) * ex2 / ey2 : 0.0;
      final at3 = cross3 ? x3 + (cy - y3) * ex3 / ey3 : 0.0;
      final row = (y % _size) * _size;
      final tileRow = (y ~/ _size) * tilesX;
      for (var x = fromX; x <= toX; x++) {
        final cx = x + .5;
        var inside = false;
        double distance, sideDistance;
        {
          final fx = cx - x0;
          var along = es0 <= 1e-12 ? 0.0 : (fx * ex0 + fy0 * ey0) / es0;
          if (along < 0) {
            along = 0.0;
          } else if (along > 1) {
            along = 1.0;
          }
          final rx = fx - ex0 * along, ry = fy0 - ey0 * along;
          distance = sideDistance = rx * rx + ry * ry;
          if (cross0 && cx < at0) inside = !inside;
        }
        {
          final fx = cx - x1;
          var along = es1 <= 1e-12 ? 0.0 : (fx * ex1 + fy1 * ey1) / es1;
          if (along < 0) {
            along = 0.0;
          } else if (along > 1) {
            along = 1.0;
          }
          final rx = fx - ex1 * along, ry = fy1 - ey1 * along;
          final d = rx * rx + ry * ry;
          if (d < distance) distance = d;
          if (cross1 && cx < at1) inside = !inside;
        }
        {
          final fx = cx - x2;
          var along = es2 <= 1e-12 ? 0.0 : (fx * ex2 + fy2 * ey2) / es2;
          if (along < 0) {
            along = 0.0;
          } else if (along > 1) {
            along = 1.0;
          }
          final rx = fx - ex2 * along, ry = fy2 - ey2 * along;
          final d = rx * rx + ry * ry;
          if (d < distance) distance = d;
          if (d < sideDistance) sideDistance = d;
          if (cross2 && cx < at2) inside = !inside;
        }
        {
          final fx = cx - x3;
          var along = es3 <= 1e-12 ? 0.0 : (fx * ex3 + fy3 * ey3) / es3;
          if (along < 0) {
            along = 0.0;
          } else if (along > 1) {
            along = 1.0;
          }
          final rx = fx - ex3 * along, ry = fy3 - ey3 * along;
          final d = rx * rx + ry * ry;
          if (d < distance) distance = d;
          if (cross3 && cx < at3) inside = !inside;
        }
        var t = squared < 1e-12
            ? 0.0
            : ((cx - ax) * deltaX + (cy - ay) * deltaY) / squared;
        if (t < 0) {
          t = 0.0;
        } else if (t > 1) {
          t = 1.0;
        }
        double outer;
        if (inside) {
          outer = 1.0;
        } else {
          outer = reachA + reachRise * t - math.sqrt(distance);
          if (outer <= 0) continue;
          if (outer > 1) outer = 1.0;
        }
        var fill = inside
            ? .5 + math.sqrt(sideDistance)
            : .5 - math.sqrt(distance);
        if (fill < 0) {
          fill = 0.0;
        } else if (fill > 1) {
          fill = 1.0;
        }
        final opacity = opacityA + opacityRise * t;
        final key = tileRow + x ~/ _size;
        if (key != lastKey) {
          lastKey = key;
          lastTile = masks.putIfAbsent(key, _blankMask);
        }
        final m = lastTile!;
        final p = row + x % _size;
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
  }) {
    final delta = b.position - a.position;
    final steps = math.max(1, delta.distance.ceil());
    final crescent = brush.foldMode == HairFoldMode.crescent;
    final fixedAngle = brush.rotation ? math.atan2(delta.dy, delta.dx) : 0.0;
    final startAngle = angleA ?? fixedAngle;
    final endAngle = angleB ?? fixedAngle;
    final outlineWidth = brush.outlineWidth;
    final nibAngle = brush.calligraphyAngle;
    final nibRatio = nibAngle == null
        ? 1.0
        : Brush.clampNibWidthRatio(brush.nibWidthRatio);
    final angleOffset = (nibAngle ?? 0) * math.pi / 180;
    final tipMask = _tipMask!;
    final shape = tipMask.scales;
    final usesProjection =
        nibAngle != null || (!crescent && shape.dx != shape.dy);
    final direction = _unit(delta);
    final radiusA = a.fillRadius(outlineWidth);
    final radiusB = b.fillRadius(outlineWidth);
    final outerA = a.outerRadius(outlineWidth);
    final outerB = b.outerRadius(outlineWidth);
    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      final center = a.position + delta * t;
      final radius = math.max(0.0, radiusA + (radiusB - radiusA) * t);
      final blend = blendA + (blendB - blendA) * t;
      final followingAngle = startAngle + (endAngle - startAngle) * t;
      final ordinaryAngle = brush.rotation
          ? followingAngle + math.pi / 2
          : fixedAngle;
      final angle =
          (crescent && nibAngle == null
              ? ordinaryAngle + (followingAngle - ordinaryAngle) * blend
              : fixedAngle) +
          angleOffset;
      final crop = crescent && nibAngle == null ? blend : 0.0;
      final leftTexel = tipMask.left * crop;
      final rightTexel =
          (brushTextureSize - 1) * (1 - crop) + tipMask.right * crop;
      final tipProjection = !usesProjection || direction == Offset.zero
          ? 1.0
          : nibWidthAcross(
              direction,
              shape.dx * nibRatio,
              angle,
              yScale: shape.dy,
            );
      final cosA = math.cos(-angle), sinA = math.sin(-angle);
      final outerRadius = outerA + (outerB - outerA) * t;
      final followsCrescent = crescent && blend > 0 && nibAngle == null;
      final rectangle = followsCrescent || brush.pixelMode
          ? null
          : tipMask.opaqueRectangle;
      var reachX =
          outerRadius *
          nibWidthAcross(const Offset(0, 1), nibRatio, angle) /
          tipProjection;
      var reachY =
          outerRadius *
          nibWidthAcross(const Offset(1, 0), nibRatio, angle) /
          tipProjection;
      final absCos = cosA.abs(), absSin = sinA.abs();
      final pixelSpan = (absCos + absSin) * tipProjection;
      if (rectangle != null) {
        final halfWidth =
            math.max(rectangle.left.abs(), rectangle.right.abs()) * nibRatio;
        final halfHeight = math.max(
          rectangle.top.abs(),
          rectangle.bottom.abs(),
        );
        reachX =
            outerRadius *
            (halfWidth * absCos + halfHeight * absSin) /
            tipProjection;
        reachY =
            outerRadius *
            (halfWidth * absSin + halfHeight * absCos) /
            tipProjection;
      }
      final opacity = a.opacity + (b.opacity - a.opacity) * t;
      final left = (center.dx - reachX - 1).floor().clamp(
        0,
        tiles.canvasWidth - 1,
      );
      final right = (center.dx + reachX + 1).ceil().clamp(
        0,
        tiles.canvasWidth - 1,
      );
      final top = (center.dy - reachY - 1).floor().clamp(
        0,
        tiles.canvasHeight - 1,
      );
      final bottom = (center.dy + reachY + 1).ceil().clamp(
        0,
        tiles.canvasHeight - 1,
      );
      for (var y = top; y <= bottom; y++) {
        for (var x = left; x <= right; x++) {
          final dx = x + .5 - center.dx, dy = y + .5 - center.dy;
          final u = (dx * cosA - dy * sinA) * tipProjection / nibRatio;
          final v = (dx * sinA + dy * cosA) * tipProjection;
          final distSquared = u * u + v * v;
          double coverage(double r) {
            if (r <= 0) return 0;
            if (followsCrescent) {
              final clip = (r + .5 - math.sqrt(distSquared)).clamp(0.0, 1.0);
              if (clip <= 0) return 0;
              return _textureAlpha(
                    texture,
                    leftTexel + ((u / r + 1) / 2) * (rightTexel - leftTexel),
                    ((v / r + 1) / 2) * (brushTextureSize - 1),
                  ) *
                  clip;
            }
            if (rectangle != null) {
              // Measure the pixel footprint against the four straight edges
              // in canvas units. A 128-texel tip can be much smaller on the
              // canvas, so filtering only in texel space still leaves steps.
              return _intervalCoverage(
                    u,
                    rectangle.left * r,
                    rectangle.right * r,
                    pixelSpan / nibRatio,
                  ) *
                  _intervalCoverage(
                    v,
                    rectangle.top * r,
                    rectangle.bottom * r,
                    pixelSpan,
                  );
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
          final mask = masks.putIfAbsent(key, _blankMask);
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

  double _creaseReach(
    Map<int, _SurfaceTile> surface,
    Offset origin,
    Offset direction,
    double limit,
    double inset,
    int owner,
  ) {
    // The join can lie on an antialiased pixel. Look for the first exit
    // after entering the folded surface, ignoring the subpixel start.
    for (var distance = 1.5; distance < limit; distance += 1) {
      if (!_covered(surface, origin + direction * distance, owner)) {
        return math.max(0, distance - math.max(.5, inset));
      }
    }
    return limit;
  }

  bool _covered(Map<int, _SurfaceTile> surface, Offset at, [int? owner]) {
    final x = at.dx.floor(), y = at.dy.floor();
    if (x < 0 || y < 0 || x >= tiles.canvasWidth || y >= tiles.canvasHeight) {
      return false;
    }
    final tile = surface[(y ~/ _size) * tiles.tilesX + x ~/ _size];
    if (tile == null) return false;
    final p = (y % _size) * _size + x % _size;
    final face = tile.owner[p];
    return tile.shape[p] > .5 &&
        (owner == null || face == owner || face == owner + 1);
  }

  Offset _creaseOriginOnOutline(
    Map<int, _SurfaceTile> surface,
    Offset origin,
    Offset direction,
    Offset inner,
    double reach,
    int owner,
  ) {
    // Only consider the visible perimeter behind the crease or on the inner
    // side of its bend. The perimeter does not include cached crease ink.
    final left = math.max(0, (origin.dx - reach).floor());
    final right = math.min(tiles.canvasWidth - 1, (origin.dx + reach).ceil());
    final top = math.max(0, (origin.dy - reach).floor());
    final bottom = math.min(tiles.canvasHeight - 1, (origin.dy + reach).ceil());
    var nearest = reach * reach;
    var joined = origin;
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final point = Offset(x + .5, y + .5);
        final delta = point - origin;
        final distance = delta.distanceSquared;
        if (distance >= nearest ||
            _dot(delta, direction) > 1 ||
            _dot(delta, inner) < -1.5) {
          continue;
        }
        final tile = surface[(y ~/ _size) * tiles.tilesX + x ~/ _size];
        if (tile == null) continue;
        final p = (y % _size) * _size + x % _size;
        final face = tile.owner[p];
        if ((face != owner && face != owner + 1) ||
            tile.shape[p] <= .5 ||
            tile.outer[p] - tile.fill[p] < tile.cover[p] * .25) {
          continue;
        }
        nearest = distance;
        joined = point;
      }
    }
    return joined;
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
    Map<int, double> hidden, {
    required bool cutEnd,
  }) {
    final originX = (key % tiles.tilesX) * _size.toDouble();
    final originY = (key ~/ tiles.tilesX) * _size.toDouble();
    final start = points[run.start].position, end = points[run.end].position;
    final startTangent = points[run.start + 1].position - start;
    final endTangent = end - points[run.end - 1].position;
    final startX = start.dx, startY = start.dy, endX = end.dx, endY = end.dy;
    final startTX = startTangent.dx, startTY = startTangent.dy;
    final endTX = endTangent.dx, endTY = endTangent.dy;
    // How far from a fold the front's edge is hidden over the back section:
    // up to where the fold line starts.
    final startReach = math
        .pow(hidden[run.start] ?? points[run.start].width, 2)
        .toDouble();
    final endReach = math
        .pow(hidden[run.end] ?? points[run.end].width, 2)
        .toDouble();
    final crescent = brush.foldMode == HairFoldMode.crescent;
    final afterStart = run.start > 0, beforeEnd = run.end < points.length - 1;
    final cutStart = brush.foldFlatEnds && !afterStart;
    final cutStop = cutEnd && !beforeEnd;
    final startAxis = cutStart ? _unit(startTangent) : Offset.zero;
    final endAxis = cutStop ? _unit(endTangent) : Offset.zero;
    final startBand = points[run.start].outlineOr(brush.outlineWidth);
    final endBand = points[run.end].outlineOr(brush.outlineWidth);
    double capReach(HairRibbonPoint point, Offset tangent) {
      if (tangent == Offset.zero) return 0;
      final outer = point.outerRadius(brush.outlineWidth);
      final baseAngle = brush.calligraphyAngle;
      var radius = outer;
      if (baseAngle != null) {
        final ratio = Brush.clampNibWidthRatio(brush.nibWidthRatio);
        final angle =
            baseAngle * math.pi / 180 +
            (brush.rotation ? math.atan2(tangent.dy, tangent.dx) : 0.0);
        // The section width is the nib's cross-stroke projection. Include
        // its full footprint when trimming along the stroke at the cap.
        radius *= math.max(1.0, ratio) / nibWidthAcross(tangent, ratio, angle);
      }
      return (radius + 1) * (radius + 1);
    }

    final startCapReach = capReach(points[run.start], startAxis);
    final endCapReach = capReach(points[run.end], endAxis);
    final outer = m.outer, fills = m.fill, opacities = m.opacity;
    final shape = surface.shape, covers = surface.cover;
    final surfaceOuter = surface.outer, surfaceFill = surface.fill;
    final outlines = surface.outline, owners = surface.owner;
    for (var row = m.top; row <= m.bottom; row++) {
      // Plain doubles: this runs per pixel of every section's tiles.
      final atY = originY + (row + .5);
      final last = row * _size + m.right[row];
      for (var p = row * _size + m.left[row]; p <= last; p++) {
        var cover = outer[p];
        if (cover <= 0) continue;
        var fill = fills[p];
        final atX = originX + (p % _size + .5);
        final fromStartX = atX - startX, fromStartY = atY - startY;
        final fromEndX = atX - endX, fromEndY = atY - endY;
        if (cutStart &&
            fromStartX * fromStartX + fromStartY * fromStartY < startCapReach) {
          final distance =
              fromStartX * startAxis.dx + fromStartY * startAxis.dy;
          cover = math.min(cover, (distance + .5).clamp(0.0, 1.0));
          fill = math.min(fill, (distance + .5 - startBand).clamp(0.0, 1.0));
        }
        if (cutStop &&
            fromEndX * fromEndX + fromEndY * fromEndY < endCapReach) {
          final distance = -fromEndX * endAxis.dx - fromEndY * endAxis.dy;
          cover = math.min(cover, (distance + .5).clamp(0.0, 1.0));
          fill = math.min(fill, (distance + .5 - endBand).clamp(0.0, 1.0));
        }
        if (cover <= 0) continue;
        final opacity = opacities[p];
        final ink = cover * opacity;
        if (ink <= 0) continue;
        final below = surfaceFill[p];
        final covered = covers[p];
        if (covered <= 0) surface.include(p);
        shape[p] = math.max(shape[p], cover);
        surfaceOuter[p] = math.max(surfaceOuter[p], ink);
        surfaceFill[p] = math.max(below, fill * opacity);
        var edge = cover - fill;
        if (edge < 0) {
          edge = 0.0;
        } else if (edge > 1) {
          edge = 1.0;
        }
        if (edge > 0 && !crescent) {
          if ((afterStart && fromStartX * startTX + fromStartY * startTY < 0) ||
              (beforeEnd && fromEndX * endTX + fromEndY * endTY > 0)) {
            edge = 0;
          } else if (below > .5 &&
              ((afterStart &&
                      fromStartX * fromStartX + fromStartY * fromStartY <
                          startReach) ||
                  (beforeEnd &&
                      fromEndX * fromEndX + fromEndY * fromEndY < endReach))) {
            // At a fold the curved fold line marks it. The front section's
            // own edge must not run straight across the section behind it;
            // how far it would run depends on the exact vertex sample.
            edge = 0;
          }
        }
        final total = math.max(ink, covered);
        final front = ink / total;
        // Crescents form a single surface: only the union perimeter is
        // visible, never a cross-section cap between connected runs.
        outlines[p] = crescent
            ? 0
            : edge / cover * front + outlines[p] * (1 - front);
        covers[p] = total;
        if (front > .5) owners[p] = run.id;
      }
    }
  }

  /// The rectangle each tile of [masks] covers.
  static Map<int, _Area> _extentOf(Map<int, _MaskTile> masks) {
    final result = <int, _Area>{};
    for (final MapEntry(:key, value: m) in masks.entries) {
      var left = _size, right = -1;
      for (var row = m.top; row <= m.bottom; row++) {
        if (m.left[row] < left) left = m.left[row];
        if (m.right[row] > right) right = m.right[row];
      }
      if (right >= left) result[key] = _Area(left, m.top, right, m.bottom);
    }
    return result;
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
      margin = math.max(
        margin,
        points[i].width + points[i].outlineOr(brush.outlineWidth) * 2,
      );
    }
    return _areaOf(left, top, right, bottom, margin + 2);
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

  /// Clears only the used span, as good as a fresh tile.
  void reset() {
    for (var row = top; row <= bottom; row++) {
      final from = row * _size + left[row], to = row * _size + right[row] + 1;
      if (to > from) {
        outer.fillRange(from, to, 0);
        fill.fillRange(from, to, 0);
        opacity.fillRange(from, to, 0);
      }
      left[row] = _size;
      right[row] = -1;
    }
    top = _size;
    bottom = -1;
  }
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

/// How far a cubic from [p0] heading [t0] to [p3] heading [t3] turns
/// towards [sigma] (see [_cross]) from [t0] to its chord, and from its chord
/// to [t3]. It turns only that way, without an inflection, when both are
/// positive.
(double, double) _chordTurns(
  Offset p0,
  Offset t0,
  Offset p3,
  Offset t3,
  double sigma,
) {
  final chord = p3 - p0;
  return (
    math.atan2(_cross(t0, chord), _dot(t0, chord)) * sigma,
    math.atan2(_cross(chord, t3), _dot(chord, t3)) * sigma,
  );
}

/// A cubic from [p0] heading [t0] to [p3] heading [t3] (unit headings) that
/// turns only towards [sigma] (see [_cross]), as points about 2px apart, or
/// null when the headings leave no such cubic. Its handles reach two thirds
/// of the way to where the two headings meet: turning as much either side
/// of its chord, it is close to an arc of a circle.
List<Offset>? _convexCubic(
  Offset p0,
  Offset t0,
  Offset p3,
  Offset t3,
  double sigma,
) {
  final (a0, a1) = _chordTurns(p0, t0, p3, t3, sigma);
  if (a0 <= 0 || a1 <= 0 || a0 + a1 >= .95 * math.pi) return null;
  final chord = (p3 - p0).distance;
  if (chord < 1e-6) return null;
  final sine = math.sin(a0 + a1);
  final p1 = p0 + t0 * (2 / 3 * chord * math.sin(a1) / sine);
  final p2 = p3 - t3 * (2 / 3 * chord * math.sin(a0) / sine);
  final count = (chord / 2).ceil().clamp(16, 512);
  return [
    for (var k = 0; k <= count; k++)
      () {
        final t = k / count, u = 1 - t;
        return p0 * (u * u * u) +
            p1 * (3 * u * u * t) +
            p2 * (3 * u * t * t) +
            p3 * (t * t * t);
      }(),
  ];
}

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

class _FoldStartCache {
  final List<HairRibbonPoint> samples;
  final int first;
  final double side;
  final ({Offset origin, Offset direction, bool smooth})? start;
  _FoldStartCache(this.samples, this.first, this.side, this.start);

  bool matches(List<HairRibbonPoint> points, int low, int high, double sign) {
    if (sign != side || low != first || high - low + 1 != samples.length) {
      return false;
    }
    for (var i = low; i <= high; i++) {
      if (!_samePoint(samples[i - low], points[i])) return false;
    }
    return true;
  }
}

bool _samePoint(HairRibbonPoint a, HairRibbonPoint b) =>
    a.position == b.position &&
    a.width == b.width &&
    a.opacity == b.opacity &&
    a.scale == b.scale &&
    a.outline == b.outline;

/// Measure the ink instead of the transparent square containing the image.
class _FoldTipMask {
  final Offset scales;
  final double left;
  final double right;
  final Rect? opaqueRectangle;
  const _FoldTipMask._(
    this.scales,
    this.left,
    this.right,
    this.opaqueRectangle,
  );

  factory _FoldTipMask(Uint8List texture) {
    final columns = List<int>.filled(brushTextureSize, 0);
    final rows = List<int>.filled(brushTextureSize, 0);
    var peak = 0, opaquePixels = 0;
    var hasTranslucentPixels = false;
    for (var y = 0; y < brushTextureSize; y++) {
      for (var x = 0; x < brushTextureSize; x++) {
        final alpha = texture[(y * brushTextureSize + x) * 4 + 3];
        if (alpha == 255) {
          opaquePixels++;
        } else if (alpha != 0) {
          hasTranslucentPixels = true;
        }
        columns[x] = math.max(columns[x], alpha);
        rows[y] = math.max(rows[y], alpha);
        peak = math.max(peak, alpha);
      }
    }
    final core = peak * .95;
    final left = columns.indexWhere((alpha) => alpha >= core);
    final right = columns.lastIndexWhere((alpha) => alpha >= core);
    final top = rows.indexWhere((alpha) => alpha >= core);
    final bottom = rows.lastIndexWhere((alpha) => alpha >= core);
    final width = right - left + 1, height = bottom - top + 1;
    final longSide = math.max(width, height);
    // Match the mask itself so the same imported tip renders like the preset.
    final rectangle =
        width != height &&
            !hasTranslucentPixels &&
            opaquePixels == width * height
        ? Rect.fromLTRB(
            left * 2 / brushTextureSize - 1,
            top * 2 / brushTextureSize - 1,
            (right + 1) * 2 / brushTextureSize - 1,
            (bottom + 1) * 2 / brushTextureSize - 1,
          )
        : null;
    return _FoldTipMask._(
      Offset(width / longSide, height / longSide),
      right > left ? left.toDouble() : 0,
      right > left ? right.toDouble() : brushTextureSize - 1.0,
      rectangle,
    );
  }
}

double _intervalCoverage(double at, double low, double high, double span) {
  final half = span / 2;
  final overlap = math.min(high, at + half) - math.max(low, at - half);
  return (overlap / span).clamp(0.0, 1.0);
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

/// The two sections meeting at fold [i]: which is in front, where each ends,
/// and the turn's side; null for a fold that does not turn.
({
  double sign,
  bool firstFront,
  int frontEnd,
  int backEnd,
  Offset incoming,
  Offset outgoing,
})?
_foldSides(
  List<HairRibbonPoint> points,
  List<double> lengths,
  List<int> indices,
  List<double> depths,
  int i,
) {
  final pivot = indices[i];
  final p = points[pivot];
  final reach = math.max(2.0, p.width);
  final incoming = _unit(
    p.position - _positionAtDistance(points, lengths, lengths[pivot] - reach),
  );
  final outgoing = _unit(
    _positionAtDistance(points, lengths, lengths[pivot] + reach) - p.position,
  );
  final sign = _cross(incoming, outgoing).sign;
  if (sign == 0) return null;
  final firstFront = depths[i - 1] > depths[i];
  return (
    sign: sign,
    firstFront: firstFront,
    frontEnd: firstFront ? indices[i - 1] : indices[i + 1],
    backEnd: firstFront ? indices[i + 1] : indices[i - 1],
    incoming: incoming,
    outgoing: outgoing,
  );
}

/// Where a fold line starts: it continues the front section's inner
/// outline beyond the point where that outline meets the back section's.
///
/// Walking the front's inner outline centre line (each sample offset by its
/// own half width plus half its outline band) away from the fold, the point
/// where it leaves the back section's body is where both inner outlines
/// meet, whether the corner is sharp, rounded or between input samples. On
/// a bend too smooth for the outlines to cross, the front's outline is never
/// inside the back section and the line starts at the bend's apex.
///
/// [frontEnd] and [backEnd] bound the two sections; [side] is the turn's
/// sign, the side of the inner outlines. Returns the start on the outline's
/// centre line and the outline's direction there, heading into the fold; or
/// null when the front outline never leaves the back section (an
/// overlapping hairpin), where there is no outline left to continue.
({Offset origin, Offset direction, bool smooth})? _foldLineStart(
  List<HairRibbonPoint> points,
  List<double> lengths,
  int pivot,
  int frontEnd,
  int backEnd,
  double side,
  double outlineWidth,
) {
  final vertex = lengths[pivot];
  final away = frontEnd < pivot ? -1.0 : 1.0;
  final width = points[pivot].width + points[pivot].outlineOr(outlineWidth) * 2;
  // The centre of the outline band, which keeps the outline's width unless
  // the whole strand has narrowed below it.
  double outlineCentre(HairRibbonPoint p) {
    final outer = p.outerRadius(outlineWidth);
    return outer - math.min(p.outlineOr(outlineWidth), outer) / 2;
  }

  // Tangents are taken over a few pixels, so jittery input still gives clean
  // normals; a corner rounded this little keeps its legs' outline lines.
  final reach = (width / 16).clamp(1.0, 4.0);
  Offset tangentAt(double at) => _unit(
    _positionAtDistance(points, lengths, at + reach) -
        _positionAtDistance(points, lengths, at - reach),
  );
  final frontLength = (lengths[frontEnd] - vertex).abs();
  // A hairpin's outlines meet ever further out; past four widths they no
  // longer meet in the strand.
  final limit = math.min(frontLength, width * 4);
  Offset outlineAt(double distance) {
    final at = vertex + away * distance;
    final p = _pointAtDistance(points, lengths, at);
    final t = tangentAt(at);
    return p.position + Offset(-t.dy, t.dx) * side * outlineCentre(p);
  }

  // The back section, nearest the fold first.
  final back = <int>[];
  for (
    var j = pivot;
    away < 0 ? j <= backEnd : j >= backEnd;
    j += away < 0 ? 1 : -1
  ) {
    back.add(j);
    if ((lengths[j] - vertex).abs() > limit + width * 2) break;
  }
  // The stroke's unwound heading at each sample of both sections. A fold's
  // two sections differ by its turn, less than half a turn; where the strand
  // crosses itself further round, as a curl's loop does, it is more.
  final low = math.max(1, math.min(frontEnd, back.last));
  final high = math.max(frontEnd, back.last);
  final heading = Float64List(high + 1);
  var angle = 0.0;
  var previousDirection = Offset.zero;
  for (var j = low; j <= high; j++) {
    final direction = _unit(points[j].position - points[j - 1].position);
    if (direction == Offset.zero) {
      heading[j] = angle;
      continue;
    }
    if (previousDirection != Offset.zero) {
      angle += math.atan2(
        _cross(previousDirection, direction),
        _dot(previousDirection, direction),
      );
    }
    previousDirection = direction;
    heading[j] = angle;
  }
  int sampleAt(double at) {
    var lowIndex = low - 1, highIndex = high;
    while (highIndex - lowIndex > 1) {
      final middle = (lowIndex + highIndex) ~/ 2;
      if (lengths[middle] < at) {
        lowIndex = middle;
      } else {
        highIndex = middle;
      }
    }
    return math.max(low, highIndex);
  }

  bool insideBack(Offset q, double distance) {
    final frontHeading = heading[sampleAt(vertex + away * distance)];
    for (var k = 1; k < back.length; k++) {
      // Only the part of the back section about as far from the fold, and
      // within half a turn of this front sample, meets it at this fold.
      if ((lengths[back[k - 1]] - vertex).abs() > distance + width) break;
      if ((heading[math.max(back[k - 1], back[k])] - frontHeading).abs() >=
          math.pi) {
        continue;
      }
      final a = points[back[k - 1]], b = points[back[k]];
      final d = b.position - a.position;
      final squared = d.distanceSquared;
      final t = squared < 1e-12
          ? 0.0
          : (_dot(q - a.position, d) / squared).clamp(0.0, 1.0);
      // The back section's inner outline centre line.
      final half = outlineCentre(
        HairRibbonPoint(
          a.position,
          a.width + (b.width - a.width) * t,
          1,
          a.scale + (b.scale - a.scale) * t,
          _outlineBetween(a, b, t),
        ),
      );
      if ((q - (a.position + d * t)).distance < half - .01) return true;
    }
    return false;
  }

  // Right at the fold the front's outline can dip in and out of the back
  // section's rounded start, and pass outside it where the back is the
  // narrower: the outlines meet where it leaves the back section for good.
  final step = (width / 32).clamp(.5, 2.0);
  var inside = -1.0;
  double? outside;
  for (var distance = step; distance <= limit; distance += step) {
    if (insideBack(outlineAt(distance), distance)) {
      inside = distance;
      outside = null;
    } else if (inside >= 0) {
      outside ??= distance;
      if (distance - outside > width) break;
    }
  }
  if (inside < 0) {
    // A smooth bend: the front's inner outline runs on from the apex. Its
    // fold line leads in from further back ([_smoothFoldLead]).
    final t = tangentAt(vertex);
    return (origin: outlineAt(0), direction: away < 0 ? t : -t, smooth: true);
  }
  if (outside == null) return null;
  var exit = outside;
  for (var k = 0; k < 8; k++) {
    final middle = (inside + exit) / 2;
    if (insideBack(outlineAt(middle), middle)) {
      inside = middle;
    } else {
      exit = middle;
    }
  }
  final origin = outlineAt(exit);
  // Along the front's own inner outline into the fold, from just beyond the
  // start but within the front section (clear of its far end's corner), so
  // it follows a narrowing strand.
  final span = math.min(
    (width / 4).clamp(2.0, 16.0),
    frontLength - exit - reach,
  );
  if (span < 1) {
    final t = tangentAt(vertex + away * exit);
    return (origin: origin, direction: away < 0 ? t : -t, smooth: false);
  }
  return (
    origin: origin,
    direction: _unit(origin - outlineAt(exit + span)),
    smooth: false,
  );
}

/// Where the fold line of a smooth bend starts, which the strand's outlines
/// never cross: on the front section's inner outline where it is straightest
/// (a wave's inflection, or where a straight leg meets the bend), heading
/// straight on along it. Carried on straight, the line is that outline's own
/// extension: it leaves the outline at no angle and passes under the apex.
/// [lead] is the strand distance from there to the apex.
///
/// [frontEnd] bounds the front section; [side] is the side of the inner
/// outlines. Null for a front too short or too straight to lead in from.
({Offset origin, Offset direction, double lead})? _smoothFoldLead(
  List<HairRibbonPoint> points,
  List<double> lengths,
  int pivot,
  int frontEnd,
  double side,
  double outlineWidth, {
  required bool followOutline,
}) {
  final vertex = lengths[pivot];
  final away = frontEnd < pivot ? -1.0 : 1.0;
  final width = points[pivot].width + points[pivot].outlineOr(outlineWidth) * 2;
  final reach = (width / 16).clamp(1.0, 4.0);
  Offset tangentAt(double at) => _unit(
    _positionAtDistance(points, lengths, at + reach) -
        _positionAtDistance(points, lengths, at - reach),
  );
  final limit = math.min((lengths[frontEnd] - vertex).abs() * .85, width * 3);
  if (limit < reach * 2) return null;
  final apex = tangentAt(vertex);
  final step = (width / 24).clamp(.5, 2.0);
  final turns = <(double, double)>[];
  var straightest = 0.0;
  for (var d = step; d <= limit; d += step) {
    final t = tangentAt(vertex + away * d);
    final turn = math.atan2(_cross(apex, t), _dot(apex, t)).abs();
    turns.add((d, turn));
    straightest = math.max(straightest, turn);
  }
  if (straightest < .02) return null;
  // Choose the departure just inside the turn of a directional tip. Its
  // varying width changes the outline tangent relative to the stroke axis.
  final turnAtDeparture = followOutline
      ? straightest * .94
      : straightest - math.pi / 180;
  final (lead, _) = turns.firstWhere((sample) => sample.$2 >= turnAtDeparture);
  final at = vertex + away * lead;
  Offset innerOutlineAt(double distance) {
    final point = _pointAtDistance(points, lengths, distance);
    final tangent = tangentAt(distance);
    final outer = point.outerRadius(outlineWidth);
    final centre = outer - math.min(point.outlineOr(outlineWidth), outer) / 2;
    return point.position + Offset(-tangent.dy, tangent.dx) * side * centre;
  }

  final tangent = followOutline
      ? _unit(innerOutlineAt(at + reach) - innerOutlineAt(at - reach))
      : tangentAt(at);
  if (tangent == Offset.zero) return null;
  return (
    origin: innerOutlineAt(at),
    direction: away < 0 ? tangent : -tangent,
    lead: lead,
  );
}

/// How far to pull each crescent sample's inner edge towards its centre
/// line, by sample, so that where the stroke curves the inner edge never
/// bends against the curve.
///
/// Along a curve of curvature k, an edge h in from the centre line bends the
/// same way as the curve while h'' >= -k(1 - hk) (while it stays short of
/// the curve's centre). A swell of the inner edge, the strand widening and
/// narrowing again (from pressure, a taper, or the crescent giving way to
/// the ordinary strand), that turns faster than that bends the edge against
/// the curve: a lump on the inside of a curl. Where the drawn edge does turn
/// against the curve inside such a swell, the swell is lowered to the
/// largest profile under it that keeps the bound: the convex envelope once
/// the bound is lifted out (by Q with Q'' = k(1 - hk)), from where it leaves
/// the drawn edge to where it meets it again, so the edge stays smooth and
/// is only ever pulled back towards the centre line. The edge's outline is
/// part of the measured edge. A strand that only narrows (a taper) is left
/// as drawn, and so is any edge that already bends with the curve.

Map<int, double> _keepInnerEdgeWithCurve(
  List<_RibbonRun> runs,
  List<HairRibbonPoint> points,
  List<double> lengths,
  Map<int, Offset> tangents,
  Map<int, double> sides,
  Map<
    int,
    List<({HairRibbonPoint point, Offset outer, Offset inner, double angle})>
  >
  edges,
  double outlineWidth,
) {
  final ordered = [...runs]..sort((a, b) => a.start.compareTo(b.start));
  final pulls = <int, double>{};
  // Sections turning the same way share one inner side.
  final spans = <(double, List<int>, List<int>)>[];
  for (final run in ordered) {
    final side = sides[run.start]!;
    if (spans.isEmpty ||
        spans.last.$1 != side ||
        spans.last.$2.last != run.start) {
      spans.add((side, [run.start], [run.start]));
    }
    final span = spans.last;
    for (var index = run.start + 1; index <= run.end; index++) {
      span.$2.add(index);
      span.$3.add(run.start);
    }
  }
  for (final (side, indices, owners) in spans) {
    final count = indices.length;
    if (count < 3) continue;
    final ink = List<Offset>.filled(count, Offset.zero);
    final depth = List<double>.filled(count, 0);
    final along = List<double>.filled(count, 0);
    final curvature = List<double>.filled(count, 0);
    final room = List<double>.filled(count, 0);
    for (var k = 0; k < count; k++) {
      final index = indices[k];
      final edge = edges[owners[k]]![index - owners[k]];
      final point = points[index];
      final tangent = tangents[index]!;
      final inward = Offset(-tangent.dy, tangent.dx) * side;
      final across = edge.inner - edge.outer;
      final width = across.distance;
      final outline = width < 1e-9
          ? 0.0
          : outlinedOuterRadius(
                  width,
                  point.scale,
                  point.outlineOr(outlineWidth),
                ) -
                width / 2;
      ink[k] =
          edge.inner + (width < 1e-9 ? Offset.zero : across / width * outline);
      depth[k] = _dot(ink[k] - point.position, inward);
      room[k] = _dot(across, inward);
      if (k > 0 && k < count - 1) {
        final before = tangents[indices[k - 1]]!;
        final after = tangents[indices[k + 1]]!;
        final distance = lengths[indices[k + 1]] - lengths[indices[k - 1]];
        if (distance > 1e-9) {
          curvature[k] =
              math.atan2(_cross(before, after), _dot(before, after)) *
              side /
              distance;
        }
      }
      // Where the edge leans along the strand, the curve through it is
      // reached at the foot of its offset rather than at its own sample.
      along[k] =
          lengths[index] +
          _dot(ink[k] - point.position, tangent) /
              math.max(.25, 1 - depth[k] * curvature[k]);
    }
    // A swell: deeper than the shallowest edge both before and after.
    final lowestBefore = List<double>.filled(count, 0);
    final lowestAfter = List<double>.filled(count, 0);
    for (var k = 0; k < count; k++) {
      lowestBefore[k] = k == 0
          ? depth[k]
          : math.min(lowestBefore[k - 1], depth[k]);
    }
    for (var k = count - 1; k >= 0; k--) {
      lowestAfter[k] = k == count - 1
          ? depth[k]
          : math.min(lowestAfter[k + 1], depth[k]);
    }
    // Where the bound applies: the stroke curves to this side, the edge is
    // short of the curve's centre, and samples follow one another.
    bool bends(int k) =>
        k > 0 &&
        k < count - 1 &&
        curvature[k] > 0 &&
        depth[k] * curvature[k] < 1 &&
        along[k - 1] < along[k] &&
        along[k] < along[k + 1];
    // Where the drawn edge turns against the curve, inside a swell.
    bool against(int k) {
      if (!bends(k) ||
          depth[k] <= math.max(lowestBefore[k], lowestAfter[k]) + 1e-9) {
        return false;
      }
      final a = ink[k] - ink[k - 1], b = ink[k + 1] - ink[k];
      return _cross(a, b) * side < -1e-9 * a.distance * b.distance;
    }

    // Each stretch curving to this side is lowered as a whole, once: the
    // lowered edge leaves and meets the drawn one where it already keeps
    // the bound, somewhere either side of where it turns against the curve.
    var k = 1;
    while (k < count - 1) {
      if (!bends(k)) {
        k++;
        continue;
      }
      var reach = k;
      while (reach + 1 < count - 1 && bends(reach + 1)) {
        reach++;
      }
      final turns = [
        for (var j = k; j <= reach; j++)
          if (against(j)) j,
      ];
      if (turns.isNotEmpty) {
        // With a free sample on either side, which stay.
        final first = k - 1, end = reach + 1;
        final n = end - first + 1;
        // Lifting by Q with Q'' = k(1 - hk) turns the bound into convexity.
        final lift = List<double>.filled(n, 0);
        var slope = 0.0;
        for (var j = 1; j < n; j++) {
          final a = first + j - 1, b = first + j;
          lift[j] = lift[j - 1] + slope * (along[b] - along[a]);
          if (b < end) {
            final bend =
                curvature[b] * math.max(0.0, 1 - depth[b] * curvature[b]);
            slope += bend * (along[b + 1] - along[a]) / 2;
          }
        }
        // The lower convex hull of the lifted depths.
        final hull = <int>[];
        for (var j = 0; j < n; j++) {
          final x = along[first + j], y = depth[first + j] + lift[j];
          while (hull.length >= 2) {
            final p = hull[hull.length - 2], q = hull[hull.length - 1];
            final px = along[first + p], py = depth[first + p] + lift[p];
            final qx = along[first + q], qy = depth[first + q] + lift[q];
            if ((qx - px) * (y - py) - (qy - py) * (x - px) <= 0) {
              hull.removeLast();
            } else {
              break;
            }
          }
          hull.add(j);
        }
        // Lowered only over the hull's spans across a turn against the
        // curve: elsewhere the drawn edge already keeps the bound.
        final lowered = List<bool>.filled(hull.length - 1, false);
        var h = 0;
        for (final j in turns) {
          while (hull[h + 1] <= j - first) {
            h++;
          }
          lowered[h] = true;
        }
        // The kept profile, lifted: the hull over lowered spans, the drawn
        // edge elsewhere.
        double y(int j) => depth[first + j] + lift[j];
        double x(int j) => along[first + j];
        final kept = [for (var j = 0; j < n; j++) y(j)];
        final changed = List<bool>.filled(n, false);
        for (var e = 0; e < hull.length - 1; e++) {
          if (!lowered[e]) continue;
          final p = hull[e], q = hull[e + 1];
          for (var j = p + 1; j < q; j++) {
            kept[j] = y(p) + (y(q) - y(p)) * (x(j) - x(p)) / (x(q) - x(p));
            changed[j] = true;
          }
        }
        // Where one lowered span meets the next, the edge turns at once: it
        // would show a corner. The turn is spread over a short fillet
        // instead, a parabola tangent to both spans (it still only turns
        // with the curve, and reaches at most a quarter of the turn times
        // its half width past the corner). Where a span leaves the drawn
        // edge, it already leaves along it.
        for (var v = 1; v < hull.length - 1; v++) {
          if (!lowered[v - 1] || !lowered[v]) continue;
          final at = hull[v], leftEnd = hull[v - 1], rightEnd = hull[v + 1];
          final leftSlope = (y(at) - y(leftEnd)) / (x(at) - x(leftEnd));
          final rightSlope = (y(rightEnd) - y(at)) / (x(rightEnd) - x(at));
          final turn = rightSlope - leftSlope;
          if (!(turn > 1e-9)) continue;
          final half = math.min(
            math.max(6.0, 3 * outlineWidth),
            .45 * math.min(x(at) - x(leftEnd), x(rightEnd) - x(at)),
          );
          if (!(half > 1e-6)) continue;
          for (var j = 0; j < n; j++) {
            final t = x(j) - x(at);
            if (t.abs() >= half) continue;
            kept[j] =
                y(at) +
                leftSlope * t +
                turn * (t + half) * (t + half) / (4 * half);
            changed[j] = true;
          }
        }
        for (var j = 0; j < n; j++) {
          if (!changed[j]) continue;
          final pull = math.min(
            depth[first + j] - (kept[j] - lift[j]),
            room[first + j],
          );
          if (pull.abs() > 1e-6) pulls[indices[first + j]] = pull;
        }
      }
      k = reach + 1;
    }
  }
  return pulls;
}

/// A bowed crescent cross-section between [outer] and [inner] edges, its fill
/// inset so the outline keeps its width under pressure and taper ([scale]).
({Offset outer, Offset inner, double fill, double band}) _insetEdges(
  Offset outer,
  Offset inner,
  double scale,
  double outlineWidth,
) {
  final across = outer - inner;
  final radii = outlinedStrokeRadii(
    width: across.distance,
    scale: scale,
    outlineWidth: outlineWidth,
  );
  final middle = (outer + inner) / 2;
  final unit = across.distance < 1e-9 ? Offset.zero : across / across.distance;
  return (
    outer: middle + unit * radii.fill,
    inner: middle - unit * radii.fill,
    fill: radii.fill,
    band: radii.outer - radii.fill,
  );
}

HairRibbonPoint _pointAtDistance(
  List<HairRibbonPoint> points,
  List<double> lengths,
  double distance,
) {
  if (distance <= 0) return points.first;
  if (distance >= lengths.last) return points.last;
  var low = 0, high = lengths.length - 1;
  while (high - low > 1) {
    final middle = (low + high) ~/ 2;
    if (lengths[middle] < distance) {
      low = middle;
    } else {
      high = middle;
    }
  }
  final a = points[low], b = points[high];
  final span = lengths[high] - lengths[low];
  final t = span <= 0 ? 0.0 : (distance - lengths[low]) / span;
  return HairRibbonPoint(
    Offset.lerp(a.position, b.position, t)!,
    a.width + (b.width - a.width) * t,
    a.opacity + (b.opacity - a.opacity) * t,
    a.scale + (b.scale - a.scale) * t,
    _outlineBetween(a, b, t),
  );
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

({int apex, double depth, double width}) _curveExtent(
  List<HairRibbonPoint> points,
  int start,
  int end,
) {
  final origin = points[start].position;
  final chord = points[end].position - origin;
  final unit = _unit(chord);
  var apex = (start + end) ~/ 2;
  var depth = 0.0, width = 0.0;
  for (var i = start; i <= end; i++) {
    final delta = points[i].position - origin;
    final distance = unit == Offset.zero
        ? delta.distance
        : _cross(unit, delta).abs();
    if (distance > depth) {
      depth = distance;
      apex = i;
    }
    width = math.max(width, points[i].width);
  }
  return (apex: apex, depth: depth, width: width);
}

/// Fold vertices of the authored stroke.
///
/// The stroke is split into bends at its inflections. A bend deep enough
/// for [depthRatio] folds at its vertex, where half of its
/// turn has happened, if it sits between inflections (a wave), joins two
/// straight legs, or is a sharp corner ([anyCurl]: any bend, for crescents).
/// Independently, every
/// further 270 degrees of continuous turning in
/// one direction adds a fold that keeps the turn direction, so 265 degrees
/// does not fold, 275 folds once, 545 twice and 815 three times.
/// Linear in the sample count, so it runs on every pointer move.
List<({int index, bool continuous})> _strokeBends(
  List<HairRibbonPoint> points,
  List<double> lengths,
  double depthRatio, {
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
    var total = 0.0;
    for (var i = first; i <= last; i++) {
      total += turns[i] * sign;
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
    final extent = _curveExtent(points, first, last);
    final width = extent.width;
    // Ignore tiny direction changes using the same tolerance as reversals.
    if (total >= .15 &&
        extent.depth > 1e-6 &&
        extent.depth >= width * depthRatio) {
      // Radius of the central 80 % of the turn: a broad arc is a curve,
      // not a fold.
      final radius =
          (lengths[at(total * .9)] - lengths[at(total * .1)]) / (total * .8);
      final betweenInflections = spans.length > 1;
      // A single rounded corner can fold when it has straight legs on both
      // sides. A long arc or a spiral without those legs retains its own rule.
      const straightTolerance = math.pi / 180;
      final betweenStraightLegs =
          total < math.pi &&
          lengths[at(straightTolerance)] - lengths[first] >= width &&
          lengths[last] - lengths[at(total - straightTolerance)] >= width;
      if (anyCurl ||
          ((betweenInflections || betweenStraightLegs) &&
              radius <= math.max(width * 4, 48)) ||
          radius <= width * .5) {
        folds.add((index: at(total / 2), continuous: false));
      }
    }
    var rawTotal = 0.0;
    for (var i = first; i <= last; i++) {
      rawTotal += rawTurns[i] * sign;
    }
    const fullFoldTurn = math.pi * 1.5;
    var turnStart = first;
    for (
      var turn = fullFoldTurn;
      turn <= rawTotal + 1e-6;
      turn += fullFoldTurn
    ) {
      final index = at(turn * total / math.max(rawTotal, 1e-9));
      final turnExtent = _curveExtent(points, turnStart, index);
      turnStart = index;
      if (turnExtent.depth <= 1e-6 ||
          turnExtent.depth < turnExtent.width * depthRatio) {
        continue;
      }
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
  double depthRatio,
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
  // Giving it a full-width apex before it reaches the minimum depth creates
  // a box-like terminal lobe on an almost straight tail.
  if (boundaries.isNotEmpty) {
    final tail = _curveExtent(points, boundaries.last, points.length - 1);
    if (tail.depth <= 1e-6 || tail.depth < tail.width * depthRatio) {
      boundaries.removeLast();
    }
  }
  return boundaries;
}
