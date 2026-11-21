import 'dart:math' as math;
import 'dart:ui';

/// 強弱 of an outline pen: along a stroke, the outline thickens towards the
/// apex of every curve, from [base] where the curve begins and ends to
/// [apex] at its apex, and stays [base] along straight parts.
///
/// A curve is a stretch of the stroke that keeps bending one way (between
/// changes of direction of the bend, or the stroke's ends). It begins and
/// ends where its turning starts and stops (5% and 95% of its total turn, so
/// straight lead-ins stay [base]), and its apex is halfway through its turn.
/// The width eases in and out (smoothstep), so it grows gradually from each
/// end and has no kink at the apex. Gentle bends (under 30°) thicken only
/// in proportion, and wobbles under 10° not at all.
class OutlineAccent {
  final double base;
  final double apex;
  final List<_Bend> _bends;

  const OutlineAccent._(this.base, this.apex, this._bends);

  /// The accent of the stroke through [points], with bends measured over
  /// [span] px (about the pen's width, so the jitter of a hand-drawn line
  /// within it is not a curve).
  factory OutlineAccent.of(
    List<Offset> points, {
    required double base,
    required double apex,
    required double span,
  }) => OutlineAccent._(base, apex, _bendsOf(points, math.max(12.0, span)));

  /// The outline's width [s] px along the stroke.
  double at(double s) {
    var bump = 0.0;
    for (final bend in _bends) {
      bump = math.max(bump, bend.at(s));
    }
    return base + (apex - base) * bump;
  }

  /// The widest the outline gets.
  double get widest => _bends.isEmpty ? base : math.max(base, apex);
}

class _Bend {
  final double start, apex, end, amount;
  const _Bend(this.start, this.apex, this.end, this.amount);

  double at(double s) {
    if (s <= start || s >= end) return 0;
    final f = s <= apex
        ? (apex > start ? (s - start) / (apex - start) : 1.0)
        : (end > apex ? (end - s) / (end - apex) : 1.0);
    final t = f.clamp(0.0, 1.0);
    return amount * t * t * (3 - 2 * t);
  }
}

const _wobble = 10 * math.pi / 180;
const _full = 30 * math.pi / 180;

List<_Bend> _bendsOf(List<Offset> points, double span) {
  if (points.length < 3) return const [];
  final lengths = <double>[0];
  for (var i = 1; i < points.length; i++) {
    lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
  }
  final total = lengths.last;
  if (total < span / 2) return const [];
  // Resampled every [step] px along the stroke.
  final step = math.max(1.0, span / 8);
  final count = (total / step).floor() + 1;
  final samples = <Offset>[];
  var j = 0;
  for (var k = 0; k < count; k++) {
    final s = k * step;
    while (j + 1 < lengths.length - 1 && lengths[j + 1] < s) {
      j++;
    }
    final run = lengths[j + 1] - lengths[j];
    final t = run > 0 ? ((s - lengths[j]) / run).clamp(0.0, 1.0) : 0.0;
    samples.add(Offset.lerp(points[j], points[j + 1], t)!);
  }
  if (samples.length < 3) return const [];
  // The heading at each sample, over [span].
  final reach = math.max(1, (span / 2 / step).round());
  final headings = <double>[];
  for (var k = 0; k < samples.length; k++) {
    final d =
        samples[math.min(samples.length - 1, k + reach)] -
        samples[math.max(0, k - reach)];
    headings.add(math.atan2(d.dy, d.dx));
  }
  // How much it turns from each sample to the next, smoothed a little so
  // the bend's direction does not flicker along a hand-drawn line.
  final raw = <double>[
    for (var k = 0; k + 1 < headings.length; k++)
      _wrap(headings[k + 1] - headings[k]),
  ];
  final sigma = math.max(1.0, reach / 2);
  final radius = (sigma * 2).ceil();
  final turns = <double>[
    for (var k = 0; k < raw.length; k++)
      () {
        var sum = 0.0, weights = 0.0;
        for (var o = -radius; o <= radius; o++) {
          final i = k + o;
          if (i < 0 || i >= raw.length) continue;
          final w = math.exp(-o * o / (2 * sigma * sigma));
          sum += raw[i] * w;
          weights += w;
        }
        return sum / weights;
      }(),
  ];
  // Stretches that turn one way. A wobble the other way between two that
  // turn the same way is part of one curve.
  final runs = <List<int>>[]; // [first, end) turning steps
  for (var k = 0; k < turns.length; k++) {
    final sign = turns[k] >= 0;
    if (runs.isNotEmpty && (_sum(turns, runs.last) >= 0) == sign) {
      runs.last[1] = k + 1;
    } else {
      runs.add([k, k + 1]);
    }
  }
  var merged = true;
  while (merged && runs.length >= 3) {
    merged = false;
    for (var r = 1; r + 1 < runs.length; r++) {
      final before = _sum(turns, runs[r - 1]);
      final after = _sum(turns, runs[r + 1]);
      if (_sum(turns, runs[r]).abs() < _wobble &&
          (before >= 0) == (after >= 0)) {
        runs[r - 1][1] = runs[r + 1][1];
        runs.removeRange(r, r + 2);
        merged = true;
        break;
      }
    }
  }
  final bends = <_Bend>[];
  for (final run in runs) {
    final turn = _sum(turns, run);
    final amount = ((turn.abs() - _wobble) / (_full - _wobble)).clamp(0.0, 1.0);
    if (amount <= 0) continue;
    final sign = turn >= 0 ? 1.0 : -1.0;
    // Where the turn so far reaches [share] of the whole: the turn of step
    // k happens between samples k and k + 1.
    var whole = 0.0;
    for (var k = run[0]; k < run[1]; k++) {
      whole += math.max(0.0, turns[k] * sign);
    }
    double reaching(double share) {
      final target = whole * share;
      var so = 0.0;
      for (var k = run[0]; k < run[1]; k++) {
        final here = math.max(0.0, turns[k] * sign);
        if (so + here >= target && here > 0) {
          return (k + (target - so) / here) * step;
        }
        so += here;
      }
      return run[1] * step;
    }

    bends.add(_Bend(reaching(.05), reaching(.5), reaching(.95), amount));
  }
  return bends;
}

double _sum(List<double> turns, List<int> run) {
  var sum = 0.0;
  for (var k = run[0]; k < run[1]; k++) {
    sum += turns[k];
  }
  return sum;
}

double _wrap(double angle) {
  var a = angle;
  while (a > math.pi) {
    a -= 2 * math.pi;
  }
  while (a < -math.pi) {
    a += 2 * math.pi;
  }
  return a;
}
