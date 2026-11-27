import 'dart:math' as math;
import 'dart:typed_data';

/// The side of the paper tooth tile (canvas pixels). It repeats across the
/// canvas.
const int kPaperToothSize = 256;

/// A tileable paper surface, fixed to the canvas: the height of the paper
/// at each pixel (0 = the bottom of a hollow, 255 = the top of a bump).
///
/// Dry media (graphite, charcoal, pastel, chalk, gouache) catch on the
/// bumps and skip the hollows, so the same tooth shows through every stroke
/// at the same place, as on real paper. It is made of soft bumps of a few
/// sizes (blurred noise, so there is no grid to it) with a few fibres laid
/// over them, and its heights are spread evenly over 0–255: a threshold at
/// `t` leaves about `t` of the paper bare.
final Uint8List paperTooth = _buildPaperTooth();

/// The paper's height (0–255) at canvas pixel ([x], [y]).
int paperToothAt(int x, int y) =>
    paperTooth[(y & (kPaperToothSize - 1)) * kPaperToothSize +
        (x & (kPaperToothSize - 1))];

/// How much of a dry medium's paint stays on canvas pixel ([x], [y]) (0–1).
///
/// [strength] is the brush's paper grain (紙目・粒子, 0–100) and [pressure]
/// the pen pressure (0–1; 1 without pressure). [edge] is how near the pixel
/// is to the rim of the dab (0 inside, 1 at the rim). The medium fills the
/// paper up to a level: the hollows below it hold only a little of it and
/// the bumps above it take the paint as it is (the chosen colour). A firm
/// press fills nearly all of it, leaving the tooth as a fine texture; a
/// light touch and the rim of the stroke, where the medium only grazes the
/// paper, leave the hollows bare.
double paperToothCover(
  int x,
  int y,
  int strength,
  double pressure, {
  double edge = 0,
}) {
  final g = strength / 100;
  final p = pressure < 0 ? 0.0 : (pressure > 1 ? 1.0 : pressure);
  final e = edge < 0 ? 0.0 : (edge > 1 ? 1.0 : edge);
  final level = g * (0.6 - 0.5 * p + 0.55 * e * e);
  if (level <= 0) return 1;
  // The level's edge is soft (the medium thins over the slope of a bump),
  // in proportion: a medium that fills nearly all of the paper leaves only
  // the deepest hollows a little lighter.
  final soft = 0.03 + 0.6 * level;
  final t = (paperToothAt(x, y) / 255 - level + soft) / (2 * soft);
  if (t >= 1) return 1;
  // Pressed firmly, the medium is pushed into the hollows too: they are
  // only lighter (a fine texture). At a light touch and at the rim they
  // stay bare.
  final floor = 0.65 * p * p * (1 - e);
  if (t <= 0) return floor;
  return floor + (1 - floor) * t * t * (3 - 2 * t);
}

Uint8List _buildPaperTooth() {
  const n = kPaperToothSize;
  final rng = math.Random(0x5EED);
  Float64List noise() {
    final out = Float64List(n * n);
    for (var i = 0; i < out.length; i++) {
      out[i] = rng.nextDouble();
    }
    return out;
  }

  // Bumps of three sizes: the fine surface of a bump, the bumps of the
  // paper (a few pixels across, in clusters) and a slow undulation. Most of
  // the height is in the bumps, so bare paper shows in soft clusters, not
  // as single specks.
  final fine = _blur(noise(), 0.8);
  final mid = _blur(noise(), 1.9);
  final broad = _blur(noise(), 4.5);
  _normalise(fine);
  _normalise(mid);
  _normalise(broad);
  final height = Float64List(n * n);
  for (var i = 0; i < height.length; i++) {
    height[i] = fine[i] * 0.18 + mid[i] * 0.52 + broad[i] * 0.3;
  }
  // Fibres: short raised threads in every direction.
  final fibres = Float64List(n * n);
  for (var k = 0; k < 520; k++) {
    final x0 = rng.nextDouble() * n;
    final y0 = rng.nextDouble() * n;
    final angle = rng.nextDouble() * math.pi;
    final length = 5 + rng.nextDouble() * 16;
    final lift = 0.5 + rng.nextDouble() * 0.5;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    for (var s = 0.0; s <= length; s += 0.5) {
      final x = (x0 + dx * s).floor() & (n - 1);
      final y = (y0 + dy * s).floor() & (n - 1);
      final i = y * n + x;
      if (fibres[i] < lift) fibres[i] = lift;
    }
  }
  final softFibres = _blur(fibres, 0.7);
  _normalise(softFibres);
  for (var i = 0; i < height.length; i++) {
    height[i] += softFibres[i] * 0.18;
  }
  // Spread the heights evenly over 0–255 (by rank).
  final order = List<int>.generate(n * n, (i) => i)
    ..sort((a, b) => height[a].compareTo(height[b]));
  final out = Uint8List(n * n);
  for (var r = 0; r < order.length; r++) {
    out[order[r]] = r * 256 ~/ order.length;
  }
  return out;
}

void _normalise(Float64List v) {
  var lo = double.infinity, hi = -double.infinity;
  for (final x in v) {
    if (x < lo) lo = x;
    if (x > hi) hi = x;
  }
  final span = hi - lo;
  if (span <= 0) return;
  for (var i = 0; i < v.length; i++) {
    v[i] = (v[i] - lo) / span;
  }
}

/// A Gaussian blur with standard deviation [sigma] that wraps at the edges
/// (so the tile repeats without a seam).
Float64List _blur(Float64List src, double sigma) {
  const n = kPaperToothSize;
  final reach = (sigma * 3).ceil();
  final kernel = Float64List(reach * 2 + 1);
  var sum = 0.0;
  for (var k = -reach; k <= reach; k++) {
    final w = math.exp(-k * k / (2 * sigma * sigma));
    kernel[k + reach] = w;
    sum += w;
  }
  for (var k = 0; k < kernel.length; k++) {
    kernel[k] /= sum;
  }
  final tmp = Float64List(n * n);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      var acc = 0.0;
      for (var k = -reach; k <= reach; k++) {
        acc += src[y * n + ((x + k) & (n - 1))] * kernel[k + reach];
      }
      tmp[y * n + x] = acc;
    }
  }
  final out = Float64List(n * n);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      var acc = 0.0;
      for (var k = -reach; k <= reach; k++) {
        acc += tmp[((y + k) & (n - 1)) * n + x] * kernel[k + reach];
      }
      out[y * n + x] = acc;
    }
  }
  return out;
}
