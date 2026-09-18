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

  // Current Straight fold controls, expressed as effective-brush-width ratios.
  static const double foldCurveStartRatio = 0.25;
  static const int foldCurveStrength = 5;
  static const double foldLengthRatio = 0.8;
  static const double foldEndTaperRatio = 0.35;

  // Wave is opt-in for custom brushes. The Hair preset overrides the endpoint
  // ratio to 30% (Straight:Wave = 7:3); Bangs intentionally remains at 0%.
  static const bool foldWaveEnabled = false;
  static const double foldWaveEndRatio = 0.0;
  static const double hairFoldWaveEndRatio = 0.30;
  static const double foldWaveTriggerAngle = 45.0;

  // Legacy Y defaults remain for pre-release development data only.
  static const double yBranchAngle = 45.0;
  static const double yBranchLengthRatio = 0.6;
  static const double yBranchWidthRatio = 0.08;
  static const double yBranchEndTaperRatio = 0.4;

  static int clampLateralRepeatCount(int value) =>
      value.clamp(minLateralRepeatCount, maxLateralRepeatCount).toInt();
}
