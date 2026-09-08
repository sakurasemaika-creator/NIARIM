import 'dart:math' as math;
import 'dart:typed_data';

/// Pixel-wise HSL adjustment used by the official line-art color-trace
/// automation. Defaults intentionally match Autofill's trace-adjust values.
Uint8List applyColorTraceAdjust(
  Uint8List src, {
  double hueShift = -10,
  double saturationShift = 60,
  double lightnessShift = -50,
}) {
  final out = Uint8List.fromList(src);
  for (var i = 0; i < out.length; i += 4) {
    if (out[i + 3] == 0) continue;
    final rgb = _rgbToHsl(out[i], out[i + 1], out[i + 2]);
    var h = (rgb.$1 + hueShift) % 360.0;
    if (h < 0) h += 360.0;
    final s = (rgb.$2 + saturationShift / 100.0).clamp(0.0, 1.0);
    final l = (rgb.$3 + lightnessShift / 100.0).clamp(0.0, 1.0);
    final adjusted = _hslToRgb(h, s, l);
    out[i] = adjusted.$1;
    out[i + 1] = adjusted.$2;
    out[i + 2] = adjusted.$3;
  }
  return out;
}

(double, double, double) _rgbToHsl(int r8, int g8, int b8) {
  final r = r8 / 255.0;
  final g = g8 / 255.0;
  final b = b8 / 255.0;
  final maxV = math.max(r, math.max(g, b));
  final minV = math.min(r, math.min(g, b));
  final l = (maxV + minV) / 2.0;
  if (maxV == minV) return (0, 0, l);
  final d = maxV - minV;
  final s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
  double h;
  if (maxV == r) {
    h = (g - b) / d + (g < b ? 6 : 0);
  } else if (maxV == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return (h * 60.0, s, l);
}

(int, int, int) _hslToRgb(double h, double s, double l) {
  if (s == 0) {
    final v = (l * 255).round().clamp(0, 255);
    return (v, v, v);
  }
  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  final hk = h / 360.0;
  double hue(double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }
  return (
    (hue(hk + 1 / 3) * 255).round().clamp(0, 255),
    (hue(hk) * 255).round().clamp(0, 255),
    (hue(hk - 1 / 3) * 255).round().clamp(0, 255),
  );
}
