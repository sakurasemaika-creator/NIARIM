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

/// The cross-section of an outline-pen stroke that pressure and taper (fade)
/// have scaled by [scale] to [width]: its fill and outer radii.
///
/// Pressure and taper shape the stroke as a whole, outline included, while
/// the outline itself keeps its width. Where the scaled stroke is thinner
/// than its outline no fill is left, and the outline-colored tip narrows to
/// a point instead of ending in a round outline dot or a faint hairline.
/// Both radii are linear in [width] and [scale], so they may be
/// interpolated between samples before [outlinedFill] snaps the fill.
({double fill, double outer}) outlinedStrokeRadii({
  required double width,
  required double scale,
  required double outlineWidth,
}) => (
  fill: outlinedFill(outlinedFillRadius(width, scale, outlineWidth)),
  outer: outlinedOuterRadius(width, scale, outlineWidth),
);

/// The fill radius of [outlinedStrokeRadii] before [outlinedFill] snaps it;
/// written without cancellation, so an unscaled stroke keeps exactly half
/// its width.
double outlinedFillRadius(double width, double scale, double outlineWidth) =>
    width / 2 - outlineWidth * (1 - math.max(0.0, scale));

/// The outer radius of [outlinedStrokeRadii].
double outlinedOuterRadius(double width, double scale, double outlineWidth) =>
    math.max(0.0, width / 2 + outlineWidth * math.max(0.0, scale));

/// A fill narrower than a pixel would only grey the solid outline tip.
double outlinedFill(double radius) => radius < .5 ? 0 : radius;

BrushStampPlan buildBrushStampPlan({
  required Brush brush,
  required Offset center,
  required double pathAngle,
  required double effectiveSize,
  // An outline pen's cross-section from [outlinedStrokeRadii], used as is:
  // under pressure and taper it is finer than effectiveSize can describe.
  ({double fill, double outer})? outlinedRadii,
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

  final outlined = brush.outlineEnabled && outlineWidth > 0;
  final radii =
      outlinedRadii ?? (fill: fillRadius, outer: fillRadius + outlineWidth);

  return BrushStampPlan(
    centers: List<Offset>.unmodifiable(centers),
    fillRadius: outlined ? radii.fill : fillRadius,
    outlineRadius: outlined ? radii.outer : null,
    hollowSquare: brush.tipShape == BrushTipShape.hollowSquare,
    // A 50% opening leaves a quarter-width frame on every side. It remains
    // clearly open at small sizes while joining predictably into a net/grid.
    hollowSquareInnerRatio: 0.5,
  );
}
