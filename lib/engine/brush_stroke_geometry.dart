import 'dart:math' as math;
import 'dart:ui';

/// Returns offsets centered on the stroke centerline. [count] is always
/// treated as 1..10 so malformed imported brushes cannot fan out without
/// bound. Even counts straddle the centerline instead of occupying it.
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

/// Places repeat centers along the local normal of [tangent].
List<Offset> lateralCenters({
  required Offset center,
  required Offset tangent,
  required int count,
  required double spacing,
}) {
  final length = tangent.distance;
  if (!length.isFinite || length <= 1e-9) {
    return [for (final offset in lateralOffsets(count: count, spacing: spacing)) center + Offset(0, offset)];
  }
  final unit = tangent / length;
  final normal = Offset(-unit.dy, unit.dx);
  return [for (final offset in lateralOffsets(count: count, spacing: spacing)) center + normal * offset];
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

  /// Width along the branch. Taper affects only the configured final fraction.
  double widthAt(double t) {
    final clampedT = t.clamp(0.0, 1.0).toDouble();
    final taper = taperRatio.clamp(0.0, 1.0).toDouble();
    if (taper <= 0) return width;
    final taperStart = 1.0 - taper;
    if (clampedT <= taperStart) return width;
    final local = ((clampedT - taperStart) / taper).clamp(0.0, 1.0).toDouble();
    // Smoothstep avoids a visible kink where taper begins.
    final eased = local * local * (3.0 - 2.0 * local);
    return width * (1.0 - eased);
  }
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

    // Compare directions on either side of a distance-based pivot. This keeps
    // event density from changing the result and smooths tiny hand jitter.
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
    // A positive mathematical cross in Flutter's y-down screen coordinates
    // visually bends downward; rotating the outgoing tangent toward that side
    // yields the curve's interior normal.
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

  // The stem and two arms all remain biased into the bend interior. The arm
  // angle is measured away from the inward normal toward ± tangent.
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

Offset _normalized(Offset value) {
  final length = value.distance;
  return length <= 1e-9 || !length.isFinite ? Offset.zero : value / length;
}

bool _isFiniteOffset(Offset value) => value.dx.isFinite && value.dy.isFinite;
