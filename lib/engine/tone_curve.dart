import 'dart:math' as math;
import 'dart:ui';

/// A tone curve through control points ([Offset] x = input, y = output,
/// both 0..1), drawn and applied the same way: a smooth curve through every
/// point (monotone cubic, Fritsch–Carlson), so it bends like the curves of
/// other painting apps without overshooting between points (an output never
/// runs above or below its neighbours). Outside the first and last point it
/// stays flat at their outputs.
class ToneCurve {
  ToneCurve(Iterable<Offset> points) : _points = _normalise(points) {
    _tangents = _computeTangents(_points);
  }

  final List<Offset> _points;
  late final List<double> _tangents;

  static const identity = [Offset(0, 0), Offset(1, 1)];

  static List<Offset> _normalise(Iterable<Offset> points) {
    final sorted = [
      for (final p in points)
        Offset(p.dx.clamp(0.0, 1.0), p.dy.clamp(0.0, 1.0)),
    ]..sort((a, b) => a.dx.compareTo(b.dx));
    // Points at the same input: the later one wins.
    final unique = <Offset>[];
    for (final p in sorted) {
      if (unique.isNotEmpty && (p.dx - unique.last.dx).abs() < 1e-9) {
        unique[unique.length - 1] = p;
      } else {
        unique.add(p);
      }
    }
    return unique.isEmpty ? identity : unique;
  }

  static List<double> _computeTangents(List<Offset> p) {
    final n = p.length;
    if (n < 2) return List.filled(n, 0);
    final secants = [
      for (var k = 0; k < n - 1; k++)
        (p[k + 1].dy - p[k].dy) / (p[k + 1].dx - p[k].dx),
    ];
    final m = List<double>.filled(n, 0);
    m[0] = secants.first;
    m[n - 1] = secants.last;
    for (var k = 1; k < n - 1; k++) {
      final a = secants[k - 1], b = secants[k];
      m[k] = a * b <= 0 ? 0 : (a + b) / 2;
    }
    for (var k = 0; k < n - 1; k++) {
      final d = secants[k];
      if (d == 0) {
        m[k] = 0;
        m[k + 1] = 0;
        continue;
      }
      final alpha = m[k] / d, beta = m[k + 1] / d;
      final s = alpha * alpha + beta * beta;
      if (s > 9) {
        final tau = 3 / math.sqrt(s);
        m[k] = tau * alpha * d;
        m[k + 1] = tau * beta * d;
      }
    }
    return m;
  }

  /// The curve's output at input [x] (0..1).
  double valueAt(double x) {
    final p = _points;
    if (p.length == 1 || x <= p.first.dx) return p.first.dy;
    if (x >= p.last.dx) return p.last.dy;
    var k = 0;
    while (k < p.length - 2 && x > p[k + 1].dx) {
      k++;
    }
    final h = p[k + 1].dx - p[k].dx;
    final t = (x - p[k].dx) / h;
    final t2 = t * t, t3 = t2 * t;
    final y =
        (2 * t3 - 3 * t2 + 1) * p[k].dy +
        (t3 - 2 * t2 + t) * h * _tangents[k] +
        (-2 * t3 + 3 * t2) * p[k + 1].dy +
        (t3 - t2) * h * _tangents[k + 1];
    return y.clamp(0.0, 1.0);
  }

  /// The curve as a 256-entry lookup table for 8-bit channels.
  List<int> lut() => [
    for (var i = 0; i < 256; i++) (valueAt(i / 255) * 255).round(),
  ];
}
