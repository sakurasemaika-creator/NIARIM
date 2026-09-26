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
  final int? strokeIndex;

  const BrushStrokeSample({
    required this.screenPosition,
    required this.documentPosition,
    required this.effectiveWidth,
    this.strokeIndex,
  });
}

class FoldEvent {
  final BrushStrokeSample sample;
  final Offset tangent;
  final Offset inwardNormal;
  final double signedTurnRadians;
  final double screenDistance;
  final bool isContinuousTurnFold;
  final List<Offset> sourceCurve;
  final List<int?> sourceIndices;

  const FoldEvent({
    required this.sample,
    required this.tangent,
    required this.inwardNormal,
    required this.signedTurnRadians,
    required this.screenDistance,
    this.isContinuousTurnFold = false,
    this.sourceCurve = const <Offset>[],
    this.sourceIndices = const <int?>[],
  });
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
  double _unwrappedTurn = 0;
  double _lastEmittedContinuousFolds = 0;
  double _lastSegmentHeading = 0;
  bool _hasSegmentHeading = false;

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
    _unwrappedTurn = 0;
    _lastEmittedContinuousFolds = 0;
    _lastSegmentHeading = 0;
    _hasSegmentHeading = false;
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
    if (!distance.isFinite || distance < math.max(sampleSpacing, 0.1)) {
      return null;
    }

    _totalDistance += distance;
    if (delta.distanceSquared > 1e-10) {
      final heading = math.atan2(delta.dy, delta.dx);
      if (_hasSegmentHeading) {
        var change = heading - _lastSegmentHeading;
        while (change > math.pi) {
          change -= math.pi * 2;
        }
        while (change < -math.pi) {
          change += math.pi * 2;
        }
        _unwrappedTurn += change;
      }
      _lastSegmentHeading = heading;
      _hasSegmentHeading = true;
    }
    _samples.add(_DistanceSample(sample, _totalDistance));
    final safeWindow = math.max(windowLength, minimumTravel * 2);
    while (_samples.length > 3 &&
        _totalDistance - _samples.first.distance > safeWindow) {
      _samples.removeAt(0);
    }

    if (_totalDistance < minimumTravel || _samples.length < 3) {
      return null;
    }
    // Besides direction reversals, every additional 270 degrees of continuous
    // turning is a fold boundary. This keeps the current turn direction: a
    // spiral/crescent continues folding along the authored curve rather than
    // pretending the stroke reversed.
    final continuousFolds =
        (_unwrappedTurn.abs() / (math.pi * 1.5)).floorToDouble();
    final continuousFullTurn =
        continuousFolds > _lastEmittedContinuousFolds &&
        _totalDistance - _lastFoldDistance >= math.max(sampleSpacing, 0.1);
    if (!continuousFullTurn &&
        _totalDistance - _lastFoldDistance < cooldownDistance) {
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
    final before =
        _samples[pivotIndex].sample.screenPosition -
        _samples.first.sample.screenPosition;
    final after =
        _samples.last.sample.screenPosition -
        _samples[pivotIndex].sample.screenPosition;
    if (before.distance < minimumTravel / 3 ||
        after.distance < minimumTravel / 3) {
      return null;
    }

    final a = before / before.distance;
    final b = after / after.distance;
    final cross = a.dx * b.dy - a.dy * b.dx;
    final dot = (a.dx * b.dx + a.dy * b.dy).clamp(-1.0, 1.0).toDouble();
    final signedTurn = math.atan2(cross, dot);
    final threshold =
        triggerAngleDegrees.clamp(30.0, 170.0).toDouble() * math.pi / 180.0;
    if (signedTurn.abs() < threshold && !continuousFullTurn) return null;

    final tangentLength = b.distance;
    if (tangentLength <= 1e-9) return null;
    final tangent = b / tangentLength;
    final leftNormal = Offset(-tangent.dy, tangent.dx);
    final inward = cross >= 0 ? leftNormal : -leftNormal;
    _lastFoldDistance = _totalDistance;
    if (continuousFullTurn) _lastEmittedContinuousFolds = continuousFolds;

    return FoldEvent(
      sample: sample,
      tangent: tangent,
      inwardNormal: inward,
      signedTurnRadians: signedTurn,
      screenDistance: _totalDistance,
      isContinuousTurnFold: continuousFullTurn,
      sourceIndices: _samples
          .map((entry) => entry.sample.strokeIndex)
          .toList(growable: false),
      sourceCurve: _samples
          .map((entry) => entry.sample.documentPosition)
          .toList(growable: false),
    );
  }
}

// Kept temporarily for renderer compatibility while the next task migrates
// DrawingEngine from Y branches to FoldPathSample geometry.
class _DistanceSample {
  final BrushStrokeSample sample;
  final double distance;
  const _DistanceSample(this.sample, this.distance);
}

bool _isFiniteOffset(Offset value) => value.dx.isFinite && value.dy.isFinite;
