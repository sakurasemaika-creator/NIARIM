import 'dart:math' as math;
import 'dart:ui';

import '../models/brush.dart';
import 'brush_stroke_geometry.dart';

/// Geometry-only description of one resampled brush stamp.
///
/// DrawingEngine can consume this without changing the legacy fast path when
/// every extension is disabled. Keeping placement math here also makes repeat
/// symmetry and pressure-scaled spacing independently testable.
class BrushStampPlan {
  final List<Offset> centers;
  final double fillRadius;
  final double? outlineRadius;
  final bool hollowSquare;
  final double hollowSquareInnerRatio;

  const BrushStampPlan({
    required this.centers,
    required this.fillRadius,
    required this.outlineRadius,
    required this.hollowSquare,
    required this.hollowSquareInnerRatio,
  });
}

BrushStampPlan buildBrushStampPlan({
  required Brush brush,
  required Offset center,
  required double pathAngle,
  required double effectiveSize,
}) {
  final safeSize = effectiveSize.isFinite
      ? effectiveSize.clamp(0.5, 2000.0).toDouble()
      : 0.5;
  final fillRadius = safeSize / 2;
  final repeatCount = brush.lateralRepeatEnabled
      ? Brush.clampLateralRepeatCount(brush.lateralRepeatCount)
      : 1;

  // The UI spacing value is a brush-width ratio rather than document pixels.
  // This keeps a Net preset visually identical when brush size or pressure
  // changes and avoids resolution-dependent gaps.
  final repeatSpacing = brush.lateralRepeatEnabled
      ? safeSize * brush.lateralRepeatSpacing.clamp(0.0, 4.0).toDouble()
      : 0.0;
  final tangent = Offset(math.cos(pathAngle), math.sin(pathAngle));
  final centers = repeatCount == 1
      ? <Offset>[center]
      : lateralCenters(
          center: center,
          tangent: tangent,
          count: repeatCount,
          spacing: repeatSpacing,
        );

  final outlineWidth = brush.outlineWidth.isFinite
      ? brush.outlineWidth.clamp(0.0, 200.0).toDouble()
      : 0.0;

  return BrushStampPlan(
    centers: List<Offset>.unmodifiable(centers),
    fillRadius: fillRadius,
    outlineRadius: brush.outlineEnabled && outlineWidth > 0
        ? fillRadius + outlineWidth
        : null,
    hollowSquare: brush.tipShape == BrushTipShape.hollowSquare,
    // A 50% opening leaves a quarter-width frame on every side. It remains
    // clearly open at small sizes while joining predictably into a net/grid.
    hollowSquareInnerRatio: 0.5,
  );
}
