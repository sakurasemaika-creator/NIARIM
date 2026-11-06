import 'dart:math' as math;
import 'dart:typed_data';

import '../models/layer.dart';

/// The colour [mode] makes of source colour ([sr], [sg], [sb]) over
/// backdrop colour ([br], [bg], [bb]), all straight RGB in 0 to 1, before
/// any opacity is applied. Written into [out] (3 values) so a per-pixel loop
/// allocates nothing.
///
/// These are the formulas the layer compositor draws with (the W3C
/// Compositing and Blending ones; Addition adds the two colours), so a
/// filter that blends with a layer blend mode looks the same as a layer set
/// to that mode would.
void blendRgb(
  LayerBlendMode mode,
  double br,
  double bg,
  double bb,
  double sr,
  double sg,
  double sb,
  Float64List out,
) {
  switch (mode) {
    case LayerBlendMode.hue:
      _setSat(sr, sg, sb, _sat(br, bg, bb), out);
      _setLum(out[0], out[1], out[2], _lum(br, bg, bb), out);
    case LayerBlendMode.saturation:
      _setSat(br, bg, bb, _sat(sr, sg, sb), out);
      _setLum(out[0], out[1], out[2], _lum(br, bg, bb), out);
    case LayerBlendMode.color:
      _setLum(sr, sg, sb, _lum(br, bg, bb), out);
    case LayerBlendMode.luminosity:
      _setLum(br, bg, bb, _lum(sr, sg, sb), out);
    default:
      out[0] = blendChannel(mode, br, sr);
      out[1] = blendChannel(mode, bg, sg);
      out[2] = blendChannel(mode, bb, sb);
  }
}

/// [blendRgb] composited onto the backdrop at [weight] (the source's
/// opacity, 0 to 1), as the layer compositor draws it: Addition is the
/// GPU's Plus, so the source scaled by its weight is added and clipped at
/// white; every other mode, Linear Dodge included, mixes its blended colour
/// in by the weight. The two only differ below full opacity: at 50 %, a
/// mid-grey plus a bright colour comes out much lighter in Addition.
void blendRgbOver(
  LayerBlendMode mode,
  double br,
  double bg,
  double bb,
  double sr,
  double sg,
  double sb,
  double weight,
  Float64List out,
) {
  final w = weight.clamp(0.0, 1.0);
  if (mode == LayerBlendMode.addition) {
    out[0] = math.min(1.0, br + sr * w);
    out[1] = math.min(1.0, bg + sg * w);
    out[2] = math.min(1.0, bb + sb * w);
    return;
  }
  blendRgb(mode, br, bg, bb, sr, sg, sb, out);
  out[0] = br + (out[0] - br) * w;
  out[1] = bg + (out[1] - bg) * w;
  out[2] = bb + (out[2] - bb) * w;
}

/// One channel of a separable blend mode (see [blendRgb]). The
/// non-separable modes (hue, saturation, color, luminosity) are not
/// per-channel; for them this returns the source.
double blendChannel(LayerBlendMode mode, double b, double s) {
  switch (mode) {
    case LayerBlendMode.normal:
      return s;
    case LayerBlendMode.multiply:
      return b * s;
    case LayerBlendMode.screen:
      return b + s - b * s;
    case LayerBlendMode.overlay:
      return b <= 0.5 ? 2 * b * s : 1 - 2 * (1 - b) * (1 - s);
    case LayerBlendMode.addition:
    case LayerBlendMode.linearDodge:
      return math.min(1.0, b + s);
    case LayerBlendMode.subtract:
      return math.max(0.0, b - s);
    case LayerBlendMode.darken:
      return math.min(b, s);
    case LayerBlendMode.lighten:
      return math.max(b, s);
    case LayerBlendMode.colorBurn:
      if (b >= 1) return 1;
      return s <= 0 ? 0 : 1 - math.min(1.0, (1 - b) / s);
    case LayerBlendMode.colorDodge:
      if (b <= 0) return 0;
      return s >= 1 ? 1 : math.min(1.0, b / (1 - s));
    case LayerBlendMode.hardLight:
      return s <= 0.5 ? 2 * b * s : 1 - 2 * (1 - b) * (1 - s);
    case LayerBlendMode.softLight:
      if (s <= 0.5) return b - (1 - 2 * s) * b * (1 - b);
      final d = b <= 0.25 ? ((16 * b - 12) * b + 4) * b : math.sqrt(b);
      return b + (2 * s - 1) * (d - b);
    case LayerBlendMode.difference:
      return (b - s).abs();
    case LayerBlendMode.exclusion:
      return b + s - 2 * b * s;
    case LayerBlendMode.linearBurn:
      return (b + s - 1).clamp(0.0, 1.0);
    case LayerBlendMode.vividLight:
      return s <= 0.5
          ? (s <= 0 ? 0 : 1 - ((1 - b) / (2 * s)).clamp(0.0, 1.0))
          : (s >= 1 ? 1 : (b / (2 * (1 - s))).clamp(0.0, 1.0));
    case LayerBlendMode.linearLight:
      return (b + 2 * s - 1).clamp(0.0, 1.0);
    case LayerBlendMode.pinLight:
      return s < 0.5 ? b.clamp(0.0, 2 * s) : b.clamp(2 * s - 1, 1.0);
    case LayerBlendMode.hardMix:
      return blendChannel(LayerBlendMode.vividLight, b, s) < 0.5 ? 0 : 1;
    case LayerBlendMode.divide:
      return s <= 0 ? 1 : (b / s).clamp(0.0, 1.0);
    case LayerBlendMode.hue:
    case LayerBlendMode.saturation:
    case LayerBlendMode.color:
    case LayerBlendMode.luminosity:
      return s;
  }
}

double _lum(double r, double g, double b) => 0.3 * r + 0.59 * g + 0.11 * b;

double _sat(double r, double g, double b) =>
    math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));

void _setLum(double r, double g, double b, double l, Float64List out) {
  final d = l - _lum(r, g, b);
  r += d;
  g += d;
  b += d;
  // Clip back into gamut around the luminance.
  final lum = _lum(r, g, b);
  final n = math.min(r, math.min(g, b));
  final x = math.max(r, math.max(g, b));
  if (n < 0) {
    r = lum + (r - lum) * lum / (lum - n);
    g = lum + (g - lum) * lum / (lum - n);
    b = lum + (b - lum) * lum / (lum - n);
  }
  if (x > 1) {
    r = lum + (r - lum) * (1 - lum) / (x - lum);
    g = lum + (g - lum) * (1 - lum) / (x - lum);
    b = lum + (b - lum) * (1 - lum) / (x - lum);
  }
  out[0] = r;
  out[1] = g;
  out[2] = b;
}

void _setSat(double r, double g, double b, double s, Float64List out) {
  final mx = math.max(r, math.max(g, b));
  final mn = math.min(r, math.min(g, b));
  double scale(double c) => mx > mn ? (c - mn) * s / (mx - mn) : 0;
  out[0] = scale(r);
  out[1] = scale(g);
  out[2] = scale(b);
}
