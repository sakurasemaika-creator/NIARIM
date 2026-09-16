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
  static const double yBranchAngle = 45.0;
  static const double yBranchLengthRatio = 0.6;
  static const double yBranchWidthRatio = 0.08;
  static const double yBranchEndTaperRatio = 0.4;

  static int clampLateralRepeatCount(int value) =>
      value.clamp(minLateralRepeatCount, maxLateralRepeatCount).toInt();
}
