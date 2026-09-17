import 'dart:math' as math;
import 'dart:ui';

import 'brush_stroke_geometry.dart';

class WaveFoldPathSample {
  final Offset position;
  final double distanceFromStart;
  final double width;
  final bool isWave;
  final int waveSide;
  final bool isTransition;
  final bool isJoin;

  const WaveFoldPathSample({
    required this.position,
    required this.distanceFromStart,
    required this.width,
    required this.isWave,
    this.waveSide = 0,
    this.isTransition = false,
    this.isJoin = false,
  });
}

/// Builds the approved hair-fold Wave mode.
///
/// The Straight fold is the centerline and therefore remains the exact result
/// when waveEndRatio is zero or the source turn has not reached the wave
/// threshold. The wave region is measured backwards from the fold endpoint.
/// Its maximum crescent thickness is the pressure/fade-resolved brush width.
List<WaveFoldPathSample> buildWaveFoldPath(
  FoldEvent event, {
  required double curveStartRatio,
  required double depthRatio,
  required double lengthRatio,
  required double waveEndRatio,
  required double waveTriggerAngleDegrees,
  double taperRatio = .35,
  double outlineWidth = 1,
  int sampleCount = 48,
}) {
  final straight = buildStraightFoldPath(
    event,
    curveStartRatio: curveStartRatio,
    depthRatio: depthRatio,
    lengthRatio: lengthRatio,
    taperRatio: taperRatio,
    outlineWidth: outlineWidth,
    sampleCount: sampleCount,
  );
  if (straight.isEmpty) return const [];

  final totalLength = straight.last.distanceFromStart;
  final safeWaveRatio = _finiteClamp(waveEndRatio, 0, 1, 0);
  final threshold = _finiteClamp(waveTriggerAngleDegrees, 1, 180, 45) * math.pi / 180;
  if (safeWaveRatio <= 0 || event.signedTurnRadians.abs() < threshold) {
    return [
      for (final sample in straight)
        WaveFoldPathSample(
          position: sample.position,
          distanceFromStart: sample.distanceFromStart,
          width: sample.width,
          isWave: false,
        ),
    ];
  }

  final waveStartDistance = totalLength * (1 - safeWaveRatio);
  final effectiveWidth = event.sample.effectiveWidth;
  if (!effectiveWidth.isFinite || effectiveWidth <= 0) return const [];

  // One crescent spans roughly half a brush width along the centerline. This
  // keeps the lobe size visually tied to the brush while allowing pressure and
  // fade to scale the whole motif naturally.
  final halfPeriod = math.max(effectiveWidth * .5, 1e-6);
  final amplitude = effectiveWidth * .5;
  final result = <WaveFoldPathSample>[];
  var previousLobe = -1;

  for (var i = 0; i < straight.length; i++) {
    final sample = straight[i];
    if (sample.distanceFromStart + 1e-9 < waveStartDistance) {
      result.add(WaveFoldPathSample(
        position: sample.position,
        distanceFromStart: sample.distanceFromStart,
        width: sample.width,
        isWave: false,
      ));
      continue;
    }

    final localDistance = math.max(0, sample.distanceFromStart - waveStartDistance);
    final lobe = (localDistance / halfPeriod).floor();
    final phase = (localDistance % halfPeriod) / halfPeriod;
    final side = lobe.isEven ? 1 : -1;
    final tangent = _pathTangent(straight, i);
    final normal = Offset(-tangent.dy, tangent.dx);

    // sin(pi*t) is zero at each midpoint-to-midpoint join and reaches one at
    // the crescent apex. Adjacent lobes flip sides, so joins remain continuous.
    final bulge = math.sin(math.pi * phase) * amplitude * side;
    final pressureProgress = totalLength <= 1e-9
        ? 1.0
        : (sample.distanceFromStart / totalLength).clamp(0.0, 1.0).toDouble();
    final pressureWidth = effectiveWidth * _endTaper(pressureProgress, taperRatio);
    final isFirstWaveSample = result.every((entry) => !entry.isWave);
    final isJoin = !isFirstWaveSample && lobe != previousLobe;

    result.add(WaveFoldPathSample(
      position: sample.position + normal * bulge,
      distanceFromStart: sample.distanceFromStart,
      width: pressureWidth,
      isWave: true,
      waveSide: side,
      isTransition: isFirstWaveSample,
      isJoin: isJoin,
    ));
    previousLobe = lobe;
  }
  return result;
}

Offset _pathTangent(List<FoldPathSample> path, int index) {
  Offset delta;
  if (index <= 0) {
    delta = path[1].position - path[0].position;
  } else if (index >= path.length - 1) {
    delta = path.last.position - path[path.length - 2].position;
  } else {
    delta = path[index + 1].position - path[index - 1].position;
  }
  final length = delta.distance;
  return !length.isFinite || length <= 1e-9 ? const Offset(1, 0) : delta / length;
}

double _endTaper(double progress, double taperRatio) {
  final taper = _finiteClamp(taperRatio, 0, 1, .35);
  if (taper <= 0) return 1;
  final start = 1 - taper;
  if (progress <= start) return 1;
  final local = ((progress - start) / taper).clamp(0.0, 1.0).toDouble();
  final eased = local * local * (3 - 2 * local);
  return 1 - eased;
}

double _finiteClamp(double value, double min, double max, double fallback) {
  if (!value.isFinite) return fallback.clamp(min, max).toDouble();
  return value.clamp(min, max).toDouble();
}
