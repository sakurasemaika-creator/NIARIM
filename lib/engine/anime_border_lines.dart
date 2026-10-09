import 'dart:math' as math;
import 'dart:typed_data';

/// Where anime style draws its border lines: between neighbouring colours
/// that differ by at least [threshold] (CIE76 ΔE in CIELAB, as the eye sees
/// the difference), a line [lineWidth] px wide, on the darker side of the
/// border. On the darker side, line art keeps its width (the border of a
/// black line on white paper falls inside the line), the border between two
/// colours runs along the edge of the darker one, and a shape on a
/// transparent layer (seen on white paper) gets a line just inside its edge.
///
/// The edge of a shape on a transparent layer is a border too, whatever
/// its colour: opacity counts as a fourth channel of the difference, and
/// the shape is the darker side.
///
/// An anti-aliased edge spreads the change over a pixel or two between the
/// two colours. Those pixels are a mix of both: the border is placed where
/// the mix is half and half, and only their share of the darker colour is
/// darkened ([light] is the share of the lighter colour each pixel keeps,
/// in [rgba]'s straight RGB), so a soft edge stays soft instead of filling
/// in and thickening the line.
///
/// [rgba] is straight RGBA; borders are found in the picture as it looks on
/// white paper. [coverage] is how much of every pixel the line covers (0 to
/// 1, anti-aliased).
({Float32List coverage, Float32List light}) animeBorderLines(
  Uint8List rgba,
  int width,
  int height, {
  required double lineWidth,
  required double threshold,
}) {
  final n = width * height;
  final coverage = Float32List(n);
  final light = Float32List(n * 3);
  if (lineWidth <= 0 || n == 0) return (coverage: coverage, light: light);
  final lab = _lab(rgba, n);
  double difference(int p, int q) {
    var sum = 0.0;
    for (var c = 0; c < 4; c++) {
      final d = lab[p * 4 + c] - lab[q * 4 + c];
      sum += d * d;
    }
    return math.sqrt(sum);
  }

  // Lighter or darker: by lightness, and see-through counts as lighter.
  double shade(int p) => lab[p * 4] - lab[p * 4 + 3];

  // Where [m] lies from [from] (0) to [to] (1), along the line between
  // their colours.
  double towards(int m, int from, int to) {
    var along = 0.0, length = 0.0;
    for (var c = 0; c < 4; c++) {
      final axis = lab[to * 4 + c] - lab[from * 4 + c];
      along += (lab[m * 4 + c] - lab[from * 4 + c]) * axis;
      length += axis * axis;
    }
    return length > 0 ? along / length : .5;
  }

  // [m] is a mix of its neighbours [u] and [v] (an anti-aliased pixel
  // between two colours): a real step from each, and its colour close to
  // the line between theirs.
  bool mixes(int u, int m, int v) {
    final whole = difference(u, v);
    if (whole <= 0) return false;
    final first = difference(u, m), second = difference(m, v);
    return first >= whole * .1 &&
        second >= whole * .1 &&
        first + second <= whole * 1.2;
  }

  final reach = lineWidth + .5;
  // The border at ([ex], [ey]) (pixel coordinates, centres at +.5) between
  // [lighter] and [darker], with [ramp] the anti-aliased pixels between
  // them: a line on the darker side.
  void border(double ex, double ey, int lighter, int darker, List<int> ramp) {
    final x0 = math.max(0, (ex - reach).floor());
    final x1 = math.min(width - 1, (ex + reach).ceil());
    final y0 = math.max(0, (ey - reach).floor());
    final y1 = math.min(height - 1, (ey + reach).ceil());
    for (var y = y0; y <= y1; y++) {
      final dy = y + .5 - ey;
      for (var x = x0; x <= x1; x++) {
        final p = y * width + x;
        if (!ramp.contains(p) && towards(p, lighter, darker) < .5) continue;
        final dx = x + .5 - ex;
        final c = (reach - math.sqrt(dx * dx + dy * dy)).clamp(0.0, 1.0);
        if (c > coverage[p]) coverage[p] = c;
      }
    }
    // The lighter colour's share of each mixed pixel stays.
    final opacity = rgba[lighter * 4 + 3] / 255;
    for (final m in ramp) {
      final share = (1 - towards(m, lighter, darker)).clamp(0.0, 1.0) * opacity;
      for (var c = 0; c < 3; c++) {
        final keep = share * rgba[lighter * 4 + c];
        if (keep > light[m * 3 + c]) light[m * 3 + c] = keep;
      }
    }
  }

  // Every row and column, pixel by pixel.
  void scan(int start, int stride, int count, bool across) {
    int at(int k) => start + k * stride;
    bool mixed(int k) =>
        k > 0 && k < count - 1 && mixes(at(k - 1), at(k), at(k + 1));
    for (var k = 0; k + 1 < count; k++) {
      final p = at(k), q = at(k + 1);
      // The colours on either side, past up to two mixed pixels each.
      var i = k, j = k + 1;
      for (var s = 0; s < 2 && mixed(i); s++) {
        i--;
      }
      for (var s = 0; s < 2 && mixed(j); s++) {
        j++;
      }
      final a = at(i), c = at(j);
      if (difference(a, c) < threshold) continue;
      // The border is where the mix is half and half: between p and q
      // only if that is where it changes sides.
      final vp = towards(p, a, c), vq = towards(q, a, c);
      if (!(vp < .5 && vq >= .5)) continue;
      final t = vq - vp > 0 ? (.5 - vp) / (vq - vp) : .5;
      final along = k + .5 + t;
      final darker = shade(c) <= shade(a) ? c : a;
      border(
        across ? along : (start % width) + .5,
        across ? (start ~/ width) + .5 : along,
        darker == c ? a : c,
        darker,
        [for (var m = i + 1; m < j; m++) at(m)],
      );
    }
  }

  for (var y = 0; y < height; y++) {
    scan(y * width, 1, width, true);
  }
  for (var x = 0; x < width; x++) {
    scan(x, width, height, false);
  }
  return (coverage: coverage, light: light);
}

/// CIELAB (D65) of every pixel of straight [rgba] as it looks on white
/// paper, and its opacity on the same scale (0 to 100): 4 values a pixel.
Float32List _lab(Uint8List rgba, int n) {
  final linear = Float64List(256);
  for (var v = 0; v < 256; v++) {
    final c = v / 255;
    linear[v] = c <= .04045
        ? c / 12.92
        : math.pow((c + .055) / 1.055, 2.4).toDouble();
  }
  double f(double t) =>
      t > .008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final lab = Float32List(n * 4);
  for (var p = 0; p < n; p++) {
    final a = rgba[p * 4 + 3];
    double channel(int c) =>
        linear[(rgba[p * 4 + c] * a + 255 * (255 - a)) ~/ 255];
    final r = channel(0), g = channel(1), b = channel(2);
    final x = f((r * .4124 + g * .3576 + b * .1805) / .95047);
    final y = f(r * .2126 + g * .7152 + b * .0722);
    final z = f((r * .0193 + g * .1192 + b * .9505) / 1.08883);
    lab[p * 4] = 116 * y - 16;
    lab[p * 4 + 1] = 500 * (x - y);
    lab[p * 4 + 2] = 200 * (y - z);
    lab[p * 4 + 3] = a * 100 / 255;
  }
  return lab;
}
