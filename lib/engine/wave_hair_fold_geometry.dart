import 'dart:math' as math;
import 'dart:ui';

import '../models/brush.dart';
import 'brush_stroke_geometry.dart';

class WaveFoldPathSample {
  final Offset position;
  final double distanceFromStart;
  final double width;
  final bool isWave;
  final int waveSide;
  final bool isTransition;
  final bool isJoin;
  final bool isForeground;

  const WaveFoldPathSample({
    required this.position,
    required this.distanceFromStart,
    required this.width,
    required this.isWave,
    this.waveSide = 0,
    this.isTransition = false,
    this.isJoin = false,
    this.isForeground = true,
  });
}

/// Builds fold-outline geometry from the curve the user actually drew.
///
/// No mode synthesizes a sinusoidal centerline. The detector supplies the
/// tangent, signed turn and inward side of the real stroke; modes only decide
/// which outline segment is foreground/background. Crescent mode is the one
/// exception: it follows the same detected bend while increasing the inward
/// offset smoothly to form a single C-shaped crescent.
List<WaveFoldPathSample> buildWaveFoldPath(
  FoldEvent event, {
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
  final base = _sourceCurvePath(
    event,
    outlineWidth: outlineWidth,
    taperRatio: taperRatio,
  );
  if (base.isEmpty) return const [];

  final total = base.last.distanceFromStart;
  final turnRight = event.signedTurnRadians < 0;
  final tangent = _normalized(event.tangent);

  return [
    for (var i = 0; i < base.length; i++)
      _sampleForMode(
        base[i],
        event: event,
        mode: mode,
        progress: total <= 1e-9 ? 1 : base[i].distanceFromStart / total,
        turnRight: turnRight,
        localTangent: _localTangent(base, i, tangent),
      ),
  ];
}

List<FoldPathSample> _sourceCurvePath(
  FoldEvent event, {
  required double outlineWidth,
  required double taperRatio,
}) {
  final points = event.sourceCurve;
  if (points.length < 2) return const [];
  var distance = 0.0;
  final distances = <double>[0];
  for (var i = 1; i < points.length; i++) {
    distance += (points[i] - points[i - 1]).distance;
    distances.add(distance);
  }
  if (distance <= 1e-9) return const [];
  final taper = taperRatio.clamp(0.0, 1.0).toDouble();
  return [
    for (var i = 0; i < points.length; i++)
      FoldPathSample(
        position: points[i],
        distanceFromStart: distances[i],
        width: outlineWidth *
            (1.0 - taper * (distances[i] / distance).clamp(0.0, 1.0)),
      ),
  ];
}

WaveFoldPathSample _sampleForMode(
  FoldPathSample sample, {
  required FoldEvent event,
  required HairFoldMode mode,
  required double progress,
  required bool turnRight,
  required Offset localTangent,
}) {
  var position = sample.position;
  var foreground = true;

  switch (mode) {
    case HairFoldMode.waveTopView:
      // On a crossing, the visually upper strand stays in front.
      final localNormal = Offset(-localTangent.dy, localTangent.dx);
      foreground = localNormal.dy <= 0;
      break;
    case HairFoldMode.waveLowAngle:
      // Low-angle view is the exact depth inverse of top view.
      final localNormal = Offset(-localTangent.dy, localTangent.dx);
      foreground = localNormal.dy > 0;
      break;
    case HairFoldMode.curlRight:
      // Left-top -> right-bottom is foreground; the opposite diagonal recedes.
      foreground = localTangent.dx * localTangent.dy >= 0;
      break;
    case HairFoldMode.curlLeft:
      foreground = localTangent.dx * localTangent.dy < 0;
      break;
    case HairFoldMode.crescent:
      // Follow the detected curve; do not create a wave. Curvature controls
      // the C-shaped inward excursion and length/angle come from the event.
      final strength =
          (event.signedTurnRadians.abs() / math.pi).clamp(.15, 1.0).toDouble();
      final envelope = math.sin(math.pi * progress);
      final depth = event.sample.effectiveWidth * .45 * strength * envelope;
      position = sample.position + _normalized(event.inwardNormal) * depth;
      foreground = true;
      break;
  }

  return WaveFoldPathSample(
    position: position,
    distanceFromStart: sample.distanceFromStart,
    width: sample.width,
    isWave: false,
    waveSide: event.signedTurnRadians.sign.toInt(),
    isForeground: foreground,
  );
}

Offset _localTangent(List<FoldPathSample> path, int index, Offset fallback) {
  if (path.length < 2) return fallback;
  final a = path[index == 0 ? 0 : index - 1].position;
  final b = path[index == path.length - 1 ? path.length - 1 : index + 1].position;
  final tangent = _normalized(b - a);
  return tangent == Offset.zero ? fallback : tangent;
}

Offset _normalized(Offset value) {
  final length = value.distance;
  return !length.isFinite || length <= 1e-9 ? Offset.zero : value / length;
}
