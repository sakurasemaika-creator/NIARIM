// CIELAB (D65) and the CIEDE2000 colour difference, for tests that compare
// painted colours with the colour that was chosen.
import 'dart:math' as math;

/// sRGB 8-bit ([r], [g], [b]) → CIELAB (L, a, b).
List<double> labOf(num r, num g, num b) {
  double linear(num c) {
    final v = c / 255;
    return v > 0.04045
        ? math.pow((v + 0.055) / 1.055, 2.4).toDouble()
        : v / 12.92;
  }

  final lr = linear(r), lg = linear(g), lb = linear(b);
  final x = (0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb) / 0.95047;
  final y = 0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb;
  final z = (0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb) / 1.08883;
  double f(double t) => t > 216 / 24389
      ? math.pow(t, 1 / 3).toDouble()
      : (24389 / 27 * t + 16) / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

/// 0xRRGGBB → CIELAB.
List<double> labOfRgb(int rgb) =>
    labOf(rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF);

/// The mean of [labs] (each L, a, b).
List<double> meanLab(Iterable<List<double>> labs) {
  var l = 0.0, a = 0.0, b = 0.0;
  var n = 0;
  for (final lab in labs) {
    l += lab[0];
    a += lab[1];
    b += lab[2];
    n++;
  }
  return [l / n, a / n, b / n];
}

/// CIEDE2000 between two CIELAB colours.
double deltaE2000(List<double> lab1, List<double> lab2) {
  double rad(double d) => d * math.pi / 180;
  double deg(double r) => r * 180 / math.pi;
  final l1 = lab1[0], a1 = lab1[1], b1 = lab1[2];
  final l2 = lab2[0], a2 = lab2[1], b2 = lab2[2];
  final c1 = math.sqrt(a1 * a1 + b1 * b1);
  final c2 = math.sqrt(a2 * a2 + b2 * b2);
  final cm = (c1 + c2) / 2;
  final cm7 = math.pow(cm, 7);
  final g = 0.5 * (1 - math.sqrt(cm7 / (cm7 + math.pow(25, 7))));
  final a1p = (1 + g) * a1, a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);
  double hue(double b, double a) {
    if (a == 0 && b == 0) return 0;
    final h = deg(math.atan2(b, a));
    return h < 0 ? h + 360 : h;
  }

  final h1p = hue(b1, a1p), h2p = hue(b2, a2p);
  final dLp = l2 - l1;
  final dCp = c2p - c1p;
  var dhp = h2p - h1p;
  if (c1p * c2p == 0) {
    dhp = 0;
  } else if (dhp > 180) {
    dhp -= 360;
  } else if (dhp < -180) {
    dhp += 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dhp) / 2);
  final lpm = (l1 + l2) / 2;
  final cpm = (c1p + c2p) / 2;
  var hpm = h1p + h2p;
  if (c1p * c2p != 0) {
    if ((h1p - h2p).abs() > 180) {
      hpm = hpm < 360 ? (hpm + 360) / 2 : (hpm - 360) / 2;
    } else {
      hpm /= 2;
    }
  }
  final t =
      1 -
      0.17 * math.cos(rad(hpm - 30)) +
      0.24 * math.cos(rad(2 * hpm)) +
      0.32 * math.cos(rad(3 * hpm + 6)) -
      0.20 * math.cos(rad(4 * hpm - 63));
  final dTheta = 30 * math.exp(-math.pow((hpm - 275) / 25, 2));
  final cpm7 = math.pow(cpm, 7);
  final rc = 2 * math.sqrt(cpm7 / (cpm7 + math.pow(25, 7)));
  final sl =
      1 +
      0.015 * (lpm - 50) * (lpm - 50) / math.sqrt(20 + (lpm - 50) * (lpm - 50));
  final sc = 1 + 0.045 * cpm;
  final sh = 1 + 0.015 * cpm * t;
  final rt = -math.sin(rad(2 * dTheta)) * rc;
  return math.sqrt(
    math.pow(dLp / sl, 2) +
        math.pow(dCp / sc, 2) +
        math.pow(dHp / sh, 2) +
        rt * (dCp / sc) * (dHp / sh),
  );
}
