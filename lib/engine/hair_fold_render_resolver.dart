import '../models/brush.dart';
import 'brush_stroke_geometry.dart';
import 'wave_hair_fold_geometry.dart';

/// Resolves the production hair-fold centerline from the brush fold controls.
///
/// Wave OFF deliberately uses the same straight builder as Wave 0%, so toggling
/// Wave cannot perturb the established Straight geometry. Wave percentages are
/// measured from the fold endpoint, matching the brush UI contract.
List<WaveFoldPathSample> resolveHairFoldRenderPath({
  required FoldEvent event,
  required HairFoldMode mode,
  required double curveStartRatio,
  required int curveStrength,
  required double lengthRatio,
  required double waveEndRatio,
  required double waveTriggerAngleDegrees,
  double taperRatio = .35,
  double outlineWidth = 1,
  int sampleCount = 48,
}) {
  return buildWaveFoldPath(
    event,
    curveStartRatio: curveStartRatio,
    curveStrength: curveStrength,
    lengthRatio: lengthRatio,
    mode: mode,
    waveEndRatio: waveEndRatio,
    waveTriggerAngleDegrees: waveTriggerAngleDegrees,
    taperRatio: taperRatio,
    outlineWidth: outlineWidth,
    sampleCount: sampleCount,
  );
}
