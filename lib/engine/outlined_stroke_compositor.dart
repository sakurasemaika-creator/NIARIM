import 'dart:math' as math;

/// Coverage-only composition rules for outlined brushes.
///
/// The renderer owns rasterization; this helper defines how fill, outline and
/// fold coverages combine so overlapping stamps/segments do not create dark
/// seams inside a stroke. Fill union always wins over outline union, while fold
/// marks remain visible on top but are clipped to the filled interior.
abstract final class OutlinedStrokeCompositor {
  static double clampCoverage(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;

  static double union(double a, double b) =>
      math.max(clampCoverage(a), clampCoverage(b));

  static CoverageLayers compose({
    required double fillCoverage,
    required double outerCoverage,
    required double foldCoverage,
  }) {
    final fill = clampCoverage(fillCoverage);
    final outer = clampCoverage(outerCoverage);
    final fold = math.min(clampCoverage(foldCoverage), fill);
    final outlineOnly = math.max(0.0, clampCoverage(outer) - fill);
    return CoverageLayers(fill: fill, outline: outlineOnly, fold: fold);
  }
}

class CoverageLayers {
  final double fill;
  final double outline;
  final double fold;

  const CoverageLayers({
    required this.fill,
    required this.outline,
    required this.fold,
  });
}
