/// Canonical bounds/defaults for NIARIM brush extensions.
///
/// Kept separate from rendering so model, import, UI and tests can share the
/// same contract without depending on canvas code.
abstract final class BrushExtensionDefaults {
  static const int minLateralRepeatCount = 1;
  static const int maxLateralRepeatCount = 10;
  static const double lateralRepeatSpacing = 1.0;
  static const double outlineWidth = 1.5;
  static const int outlineColor = 0xff000000;
  static const double foldTriggerAngle = 90.0;

  // Fold line controls. Length is relative to the effective brush width
  // (100 % = two widths); angle scales how much of the stroke's own turn the
  // fold line follows (50 % = exactly); curve start is the straight share
  // of the fold line before it curves (0 % = thick material).
  static const double foldCurveStartRatio = 0.0;
  static const double foldAngleRatio = 0.5;
  // Minimum curve depth, as a ratio of the pen width, for a crescent.
  static const double foldCrescentDepthThreshold = 1.0;
  static const double maxFoldCrescentDepthThreshold = 3.0;
  static const double foldLengthRatio = 0.5;
  static const double foldEndTaperRatio = 0.35;

  // Legacy Y defaults remain for pre-release development data only.
  static const double yBranchAngle = 45.0;
  static const double yBranchLengthRatio = 0.6;
  static const double yBranchWidthRatio = 0.08;
  static const double yBranchEndTaperRatio = 0.4;

  static int clampLateralRepeatCount(int value) =>
      value.clamp(minLateralRepeatCount, maxLateralRepeatCount).toInt();
}
