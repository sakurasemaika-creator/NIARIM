import 'dart:math' as math;
import 'dart:ui';

List<double> lateralOffsets({required int count, required double spacing}) {
  final safeCount = count.clamp(1, 10).toInt();
  final safeSpacing = spacing.isFinite ? spacing.abs() : 0.0;
  final center = (safeCount - 1) / 2.0;
  return List<double>.generate(
    safeCount,
    (index) => (index - center) * safeSpacing,
    growable: false,
  );
}

List<Offset> lateralCenters({
  required Offset center,
  required Offset tangent,
  required int count,
  required double spacing,
}) {
  final length = tangent.distance;
  if (!length.isFinite || length <= 1e-9) {
    return [
      for (final offset in lateralOffsets(count: count, spacing: spacing))
        center + Offset(0, offset),
    ];
  }
  final unit = tangent / length;
  final normal = Offset(-unit.dy, unit.dx);
  return [
    for (final offset in lateralOffsets(count: count, spacing: spacing))
      center + normal * offset,
  ];
}

class BrushStrokeSample {
  final Offset screenPosition;
  final Offset documentPosition;
  final double effectiveWidth;

  const BrushStrokeSample({
    required this.screenPosition,
    required this.documentPosition,
    required this.effectiveWidth,
  });
}

class FoldEvent {
  final BrushStrokeSample sample;
  final Offset tangent;
  final Offset inwardNormal;
  final double signedTurnRadians;
  final double screenDistance;

  const FoldEvent({
    required this.sample,
    required this.tangent,
    required this.inwardNormal,
    required this.signedTurnRadians,
    required this.screenDistance,
  });
}

class FoldBranch {
  final Offset start;
  final Offset end;
  final double width;
  final double taperRatio;

  const FoldBranch({
    required this.start,
    required this.end,
    required this.width,
    required this.taperRatio,
  });

  double get length => (end - start).distance;

  double widthAt(double t) {
    final clampedT = t.clamp(0.0, 1.0).toDouble();
    final taper = taperRatio.clamp(0.0, 1.0).toDouble();
    if (taper <= 0) return width;
    final taperStart = 1.0 - taper;
    if (clampedT <= taperStart) return width;
    final local = ((clampedT - taperStart) / taper).clamp(0.0, 1.0).toDouble();
    final eased = local * local * (3.0 - 2.0 * local);
    return width * (1.0 - eased);
  }
}

/// One arc-length ordered sample of the generated fold line.
class FoldPathSample {
  final Offset position;
  final double distanceFromStart;
  final double width;

  const FoldPathSample({
    required this.position,
    required this.distanceFromStart,
    required this.width,
  });
}

/// Builds the approved Straight hair-fold shape in document space.
///
/// The fold leaves the branch point along the local stroke tangent, then bends
/// smoothly toward the detected inward side. Ratios are resolved against the
/// pressure/fade-resolved effective brush width. [outlineWidth] is deliberately
/// independent of effective brush width: the fold is a continuation of the
/// outline, not a third brush stroke.
List<FoldPathSample> buildStraightFoldPath(
  FoldEvent event, {
  required double curveStartRatio,
  required double depthRatio,
  required double lengthRatio,
  required double taperRatio,
  double outlineWidth = 1,
  int sampleCount = 24,
}) {
  final effectiveWidth = event.sample.effectiveWidth;
  if (!effectiveWidth.isFinite || effectiveWidth <= 0) return const [];

  final tangent = _normalized(event.tangent);
  final inward = _normalized(event.inwardNormal);
  if (tangent == Offset.zero || inward == Offset.zero) return const [];

  final safeLengthRatio = _finiteClamp(lengthRatio, .1, 3.0, .6);
  final safeDepthRatio = _finiteClamp(depthRatio, 0, 1.5, .5);
  final safeCurveStartRatio = _finiteClamp(curveStartRatio, 0, safeLengthRatio, .25);
  final safeTaper = _finiteClamp(taperRatio, 0, 1, .4);
  final safeOutlineWidth = outlineWidth.isFinite ? math.max(0.0, outlineWidth) : 0.0;
  final totalLength = effectiveWidth * safeLengthRatio;
  final curveStartDistance = math.min(effectiveWidth * safeCurveStartRatio, totalLength * .9);
  final targetDepth = effectiveWidth * safeDepthRatio;
  final straightFraction = totalLength <= 1e-9 ? 0.0 : curveStartDistance / totalLength;
  final count = sampleCount.clamp(8, 96).toInt();
  final origin = event.sample.documentPosition;

  // Cubic control points preserve the initial tangent. The first control point
  // is placed at the requested curve-start distance, so increasing the setting
  // visibly delays the inward bend. The terminal tangent is biased by the
  // source signed curvature instead of a user-authored Y angle.
  final p0 = origin;
  final p1 = origin + tangent * curveStartDistance;
  final curvature = (event.signedTurnRadians.abs() / math.pi).clamp(.15, 1.0).toDouble();
  final remaining = math.max(totalLength - curveStartDistance, totalLength * .1);
  final p3 = origin + tangent * (totalLength * .72) + inward * targetDepth;
  final p2 = p3 - tangent * (remaining * (.28 + .22 * curvature)) - inward * (targetDepth * .12);

  final positions = <Offset>[];
  for (var i = 0; i <= count; i++) {
    final t = i / count;
    // Before the requested curve-start fraction, keep an explicit tangent run.
    // Afterwards remap into the cubic while retaining C1-like visual flow.
    if (straightFraction > 0 && t < straightFraction) {
      positions.add(origin + tangent * (totalLength * t));
    } else {
      final localT = straightFraction >= .999
          ? 1.0
          : ((t - straightFraction) / (1 - straightFraction)).clamp(0.0, 1.0).toDouble();
      final q0 = origin + tangent * curveStartDistance;
      final q1 = q0 + tangent * math.max(remaining * .22, 0);
      positions.add(_cubic(q0, q1, p2, p3, localT));
    }
  }

  final distances = <double>[0];
  for (var i = 1; i < positions.length; i++) {
    distances.add(distances.last + (positions[i] - positions[i - 1]).distance);
  }
  final measured = distances.last;
  if (measured <= 1e-9) return const [];

  // Re-scale the measured path to the requested effective-width length. This
  // makes foldLengthRatio an actual path-length control rather than a chord.
  final scale = totalLength / measured;
  final scaled = <Offset>[origin];
  for (var i = 1; i < positions.length; i++) {
    final delta = positions[i] - positions[i - 1];
    scaled.add(scaled.last + delta * scale);
  }

  final result = <FoldPathSample>[];
  var distance = 0.0;
  for (var i = 0; i < scaled.length; i++) {
    if (i > 0) distance += (scaled[i] - scaled[i - 1]).distance;
    final progress = totalLength <= 1e-9 ? 1.0 : (distance / totalLength).clamp(0.0, 1.0).toDouble();
    result.add(FoldPathSample(
      position: scaled[i],
      distanceFromStart: distance,
      width: _taperedWidth(safeOutlineWidth, progress, safeTaper),
    ));
  }
  return result;
}

class ScreenSpaceFoldDetector {
  final double triggerAngleDegrees;
  final double sampleSpacing;
  final double minimumTravel;
  final double windowLength;
  final double cooldownDistance;

  final List<_DistanceSample> _samples = <_DistanceSample>[];
  double _totalDistance = 0;
  double _lastFoldDistance = double.negativeInfinity;

  ScreenSpaceFoldDetector({
    this.triggerAngleDegrees = 90,
    this.sampleSpacing = 2,
    this.minimumTravel = 12,
    this.windowLength = 48,
    this.cooldownDistance = 24,
  });

  int get bufferedSampleCount => _samples.length;

  void reset() {
    _samples.clear();
    _totalDistance = 0;
    _lastFoldDistance = double.negativeInfinity;
  }

  FoldEvent? add(BrushStrokeSample sample) {
    if (!_isFiniteOffset(sample.screenPosition) ||
        !_isFiniteOffset(sample.documentPosition) ||
        !sample.effectiveWidth.isFinite ||
        sample.effectiveWidth <= 0) {
      return null;
    }
    if (_samples.isEmpty) {
      _samples.add(_DistanceSample(sample, 0));
      return null;
    }

    final previous = _samples.last.sample.screenPosition;
    final delta = sample.screenPosition - previous;
    final distance = delta.distance;
    if (!distance.isFinite || distance < math.max(sampleSpacing, 0.1)) return null;

    _totalDistance += distance;
    _samples.add(_DistanceSample(sample, _totalDistance));
    final safeWindow = math.max(windowLength, minimumTravel * 2);
    while (_samples.length > 3 && _totalDistance - _samples.first.distance > safeWindow) {
      _samples.removeAt(0);
    }

    if (_totalDistance < minimumTravel ||
        _totalDistance - _lastFoldDistance < cooldownDistance ||
        _samples.length < 3) {
      return null;
    }

    final pivotTarget = _totalDistance - math.max(minimumTravel / 2, 1.0);
    var pivotIndex = 1;
    var best = double.infinity;
    for (var i = 1; i < _samples.length - 1; i++) {
      final error = (_samples[i].distance - pivotTarget).abs();
      if (error < best) {
        best = error;
        pivotIndex = i;
      }
    }
    final before = _samples[pivotIndex].sample.screenPosition - _samples.first.sample.screenPosition;
    final after = _samples.last.sample.screenPosition - _samples[pivotIndex].sample.screenPosition;
    if (before.distance < minimumTravel / 3 || after.distance < minimumTravel / 3) return null;

    final a = before / before.distance;
    final b = after / after.distance;
    final cross = a.dx * b.dy - a.dy * b.dx;
    final dot = (a.dx * b.dx + a.dy * b.dy).clamp(-1.0, 1.0).toDouble();
    final signedTurn = math.atan2(cross, dot);
    final threshold = triggerAngleDegrees.clamp(30.0, 170.0).toDouble() * math.pi / 180.0;
    if (signedTurn.abs() < threshold) return null;

    final tangentLength = b.distance;
    if (tangentLength <= 1e-9) return null;
    final tangent = b / tangentLength;
    final leftNormal = Offset(-tangent.dy, tangent.dx);
    final inward = cross >= 0 ? leftNormal : -leftNormal;
    _lastFoldDistance = _totalDistance;

    return FoldEvent(
      sample: sample,
      tangent: tangent,
      inwardNormal: inward,
      signedTurnRadians: signedTurn,
      screenDistance: _totalDistance,
    );
  }
}

// Kept temporarily for renderer compatibility while the next task migrates
// DrawingEngine from Y branches to FoldPathSample geometry.
List<FoldBranch> buildFoldY(
  FoldEvent event, {
  required double branchAngleDegrees,
  required double lengthRatio,
  required double widthRatio,
  required double taperRatio,
}) {
  final width = event.sample.effectiveWidth;
  final branchLength = width * lengthRatio.clamp(0.1, 1.0).toDouble();
  final branchWidth = width * widthRatio.clamp(0.01, 0.3).toDouble();
  final taper = taperRatio.clamp(0.0, 1.0).toDouble();
  final angle = branchAngleDegrees.clamp(10.0, 120.0).toDouble() * math.pi / 180.0;
  final inward = _normalized(event.inwardNormal);
  final tangent = _normalized(event.tangent);
  final origin = event.sample.documentPosition;
  final armA = _normalized(inward * math.cos(angle) + tangent * math.sin(angle));
  final armB = _normalized(inward * math.cos(angle) - tangent * math.sin(angle));
  return <FoldBranch>[
    FoldBranch(start: origin, end: origin + inward * branchLength, width: branchWidth, taperRatio: taper),
    FoldBranch(start: origin, end: origin + armA * branchLength, width: branchWidth, taperRatio: taper),
    FoldBranch(start: origin, end: origin + armB * branchLength, width: branchWidth, taperRatio: taper),
  ];
}

class _DistanceSample {
  final BrushStrokeSample sample;
  final double distance;
  const _DistanceSample(this.sample, this.distance);
}

Offset _cubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final u = 1 - t;
  return p0 * (u * u * u) +
      p1 * (3 * u * u * t) +
      p2 * (3 * u * t * t) +
      p3 * (t * t * t);
}

double _taperedWidth(double width, double progress, double taperRatio) {
  if (taperRatio <= 0) return width;
  final start = 1 - taperRatio;
  if (progress <= start) return width;
  final local = ((progress - start) / taperRatio).clamp(0.0, 1.0).toDouble();
  final eased = local * local * (3 - 2 * local);
  return width * (1 - eased);
}

double _finiteClamp(double value, double min, double max, double fallback) {
  if (!value.isFinite) return fallback.clamp(min, max).toDouble();
  return value.clamp(min, max).toDouble();
}

Offset _normalized(Offset value) {
  final length = value.distance;
  return length <= 1e-9 || !length.isFinite ? Offset.zero : value / length;
}

bool _isFiniteOffset(Offset value) => value.dx.isFinite && value.dy.isFinite;
