import 'dart:math' as math;
import 'dart:ui';

const double _epsilon = 1e-6;

int _repeatCount(int count) => count.clamp(1, 10).toInt();

double _finiteOr(double value, double fallback) => value.isFinite ? value : fallback;

/// Symmetric offsets along the local stroke normal. Even counts straddle the
/// centerline; odd counts include it.
List<double> lateralOffsets({required int count, required double spacing}) {
  final n = _repeatCount(count);
  final gap = math.max(0.0, _finiteOr(spacing, 0));
  final center = (n - 1) / 2.0;
  return List<double>.generate(n, (i) => (i - center) * gap, growable: false);
}

/// Returns lateral stamp centers using a normal derived from [tangent].
List<Offset> lateralCenters({
  required Offset center,
  required Offset tangent,
  required int count,
  required double spacing,
}) {
  final length = tangent.distance;
  final unitTangent = length > _epsilon ? tangent / length : const Offset(1, 0);
  final normal = Offset(-unitTangent.dy, unitTangent.dx);
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

  double widthAt(double t) {
    final u = t.clamp(0.0, 1.0);
    final taper = taperRatio.clamp(0.0, 1.0);
    if (taper <= _epsilon || u <= 1 - taper) return width;
    return width * ((1 - u) / taper).clamp(0.0, 1.0);
  }
}

/// Bounded, distance-resampled fold detector. All thresholds are logical
/// screen-space distances, so document zoom/canvas resolution do not alter the
/// gesture threshold. Document coordinates are retained only for rendering.
class ScreenSpaceFoldDetector {
  final double triggerAngleDegrees;
  final double sampleSpacing;
  final double minimumTravel;
  final double windowLength;
  final double cooldownDistance;

  final List<BrushStrokeSample> _samples = <BrushStrokeSample>[];
  double _distanceSinceEvent = double.infinity;
  BrushStrokeSample? _lastInput;
  BrushStrokeSample? _lastAccepted;

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
    _distanceSinceEvent = double.infinity;
    _lastInput = null;
    _lastAccepted = null;
  }

  FoldEvent? add(BrushStrokeSample sample) {
    final previousInput = _lastInput;
    _lastInput = sample;
    if (previousInput != null) {
      _distanceSinceEvent +=
          (sample.screenPosition - previousInput.screenPosition).distance;
    }

    final accepted = _lastAccepted;
    if (accepted != null &&
        (sample.screenPosition - accepted.screenPosition).distance <
            math.max(.25, sampleSpacing)) {
      return null;
    }
    _lastAccepted = sample;
    _samples.add(sample);
    _trimWindow();

    if (_samples.length < 3 || _pathLength() < minimumTravel) return null;
    if (_distanceSinceEvent < cooldownDistance) return null;

    final pivotIndex = _bestPivotIndex();
    if (pivotIndex <= 0 || pivotIndex >= _samples.length - 1) return null;
    final incoming = _direction(_samples.first, _samples[pivotIndex]);
    final outgoing = _direction(_samples[pivotIndex], _samples.last);
    if (incoming == null || outgoing == null) return null;

    final signedTurn = math.atan2(
      incoming.dx * outgoing.dy - incoming.dy * outgoing.dx,
      incoming.dx * outgoing.dx + incoming.dy * outgoing.dy,
    );
    final threshold = triggerAngleDegrees.clamp(30.0, 170.0) * math.pi / 180;
    if (signedTurn.abs() < threshold) return null;

    // In screen coordinates positive y points down. Rotating the outgoing
    // tangent toward the signed turn gives the bend's inside normal.
    final inward = signedTurn > 0
        ? Offset(-outgoing.dy, outgoing.dx)
        : Offset(outgoing.dy, -outgoing.dx);
    final event = FoldEvent(
      sample: _samples[pivotIndex],
      tangent: outgoing,
      inwardNormal: inward,
      signedTurnRadians: signedTurn,
      screenDistance: _pathLength(),
    );
    _distanceSinceEvent = 0;
    return event;
  }

  void _trimWindow() {
    while (_samples.length > 3 && _pathLength() > windowLength) {
      _samples.removeAt(0);
    }
    // Hard memory bound even with pathological zero-distance input.
    final maxSamples = math.max(8, (windowLength / math.max(.25, sampleSpacing)).ceil() + 4);
    if (_samples.length > maxSamples) {
      _samples.removeRange(0, _samples.length - maxSamples);
    }
  }

  double _pathLength() {
    var distance = 0.0;
    for (var i = 1; i < _samples.length; i++) {
      distance += (_samples[i].screenPosition - _samples[i - 1].screenPosition).distance;
    }
    return distance;
  }

  int _bestPivotIndex() {
    // Favor a pivot near the middle of the distance window rather than event
    // density, keeping results stable on high-refresh-rate devices.
    final total = _pathLength();
    var walked = 0.0;
    var best = 1;
    var error = double.infinity;
    for (var i = 1; i < _samples.length - 1; i++) {
      walked += (_samples[i].screenPosition - _samples[i - 1].screenPosition).distance;
      final e = (walked - total / 2).abs();
      if (e < error) {
        error = e;
        best = i;
      }
    }
    return best;
  }

  Offset? _direction(BrushStrokeSample a, BrushStrokeSample b) {
    final d = b.screenPosition - a.screenPosition;
    final length = d.distance;
    return length > _epsilon ? d / length : null;
  }
}

/// Builds a three-ray Y mark in document space. Length and width are ratios of
/// the pressure/fade-resolved effective brush width at the fold sample.
List<FoldBranch> buildFoldY(
  FoldEvent event, {
  required double branchAngleDegrees,
  required double lengthRatio,
  required double widthRatio,
  required double taperRatio,
}) {
  final widthBase = math.max(0.0, _finiteOr(event.sample.effectiveWidth, 0));
  final length = widthBase * _finiteOr(lengthRatio, .6).clamp(.1, 1.0);
  final width = widthBase * _finiteOr(widthRatio, .08).clamp(.01, .3);
  final taper = _finiteOr(taperRatio, .4).clamp(0.0, 1.0);
  final angle = _finiteOr(branchAngleDegrees, 45).clamp(10.0, 120.0) * math.pi / 180;

  // screen/document transforms may include zoom but not an arbitrary rotation
  // in current CanvasArea. Use the event's inward/tangent directions and scale
  // only by document effective width, keeping the generated mark inside the
  // brush body at any zoom.
  final inward = _unit(event.inwardNormal, const Offset(0, 1));
  final tangent = _unit(event.tangent, const Offset(1, 0));
  final start = event.sample.documentPosition;
  final directions = <Offset>[
    inward,
    _unit(inward * math.cos(angle) + tangent * math.sin(angle), inward),
    _unit(inward * math.cos(angle) - tangent * math.sin(angle), inward),
  ];
  return [
    for (final direction in directions)
      FoldBranch(
        start: start,
        end: start + direction * length,
        width: width,
        taperRatio: taper,
      ),
  ];
}

Offset _unit(Offset value, Offset fallback) {
  final length = value.distance;
  return length > _epsilon ? value / length : fallback;
}
