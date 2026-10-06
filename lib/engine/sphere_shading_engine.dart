import 'dart:math' as math;
import 'dart:typed_data';

import '../models/layer.dart';
import 'blend_math.dart';

/// Shades what is drawn on a layer like a lit sphere: an elliptical light
/// (centre [centerX], [centerY], radii [radiusX], [radiusY], in pixels)
/// gets the light colour and everything outside it the shadow colour, with
/// a soft edge of [blur] (0 to 100: how much of the radius the edge fades
/// over, inwards and outwards).
///
/// The colours go on like a clipping layer in a blend mode: only over what
/// is already drawn, never changing its opacity. Each colour's own alpha is
/// how strongly it goes on, so a transparent colour leaves that side as it
/// is. Separately ([combined] false), the shadow colour goes on in
/// [shadowBlend] and the light colour in [lightBlend]. Combined, the two
/// colours form one map (shadow outside, light inside, blending across the
/// edge) that goes on in a single [combinedBlend] — Hard Light by default,
/// which darkens with colours below mid-grey and brightens with those above
/// it, so the light and the dark are one blend.
///
/// [mask] (the selection layer, same size as [data]) limits where the
/// shading goes; null, or with nothing in it, shades the whole layer.
/// [data] is premultiplied RGBA, as layers are stored.
Uint8List applySphereShading(
  Uint8List data,
  int width,
  int height, {
  required int shadowColor,
  required int lightColor,
  LayerBlendMode shadowBlend = LayerBlendMode.multiply,
  LayerBlendMode lightBlend = LayerBlendMode.screen,
  bool combined = false,
  LayerBlendMode combinedBlend = LayerBlendMode.hardLight,
  required double centerX,
  required double centerY,
  required double radiusX,
  required double radiusY,
  double blur = 0,
  Uint8List? mask,
}) {
  final out = Uint8List.fromList(data);
  if (width <= 0 || height <= 0) return out;
  final useMask = mask != null && mask.length >= data.length && _any(mask);
  final rx = math.max(0.5, radiusX);
  final ry = math.max(0.5, radiusY);
  // The edge fades from 1 - band to 1 + band (in units of the radius); with
  // no blur it is still one pixel wide so it is not jagged.
  final band = math.max((blur / 100).clamp(0.0, 1.0), 0.5 / math.min(rx, ry));

  final (sa, sr, sg, sb) = _straight(shadowColor);
  final (la, lr, lg, lb) = _straight(lightColor);
  final mixed = Float64List(3);
  final first = Float64List(3);

  for (var y = 0; y < height; y++) {
    final dy = (y + 0.5 - centerY) / ry;
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final a = data[i + 3];
      if (a == 0) continue;
      final m = useMask ? mask[i + 3] / 255 : 1.0;
      if (m <= 0) continue;
      final dx = (x + 0.5 - centerX) / rx;
      final d = math.sqrt(dx * dx + dy * dy);
      final light = 1 - _smoothstep(1 - band, 1 + band, d);

      final alpha = a / 255;
      final br = math.min(1.0, data[i] / 255 / alpha);
      final bg = math.min(1.0, data[i + 1] / 255 / alpha);
      final bb = math.min(1.0, data[i + 2] / 255 / alpha);
      double r, g, b;
      if (combined) {
        // One map: the two colours mixed (premultiplied) across the edge.
        final ma = sa + (la - sa) * light;
        if (ma <= 0) continue;
        final mr = (sr * sa + (lr * la - sr * sa) * light) / ma;
        final mg = (sg * sa + (lg * la - sg * sa) * light) / ma;
        final mb = (sb * sa + (lb * la - sb * sa) * light) / ma;
        blendRgb(combinedBlend, br, bg, bb, mr, mg, mb, mixed);
        final w = ma * m;
        r = br + (mixed[0] - br) * w;
        g = bg + (mixed[1] - bg) * w;
        b = bb + (mixed[2] - bb) * w;
      } else {
        final ws = (1 - light) * sa * m;
        r = br;
        g = bg;
        b = bb;
        if (ws > 0) {
          blendRgb(shadowBlend, r, g, b, sr, sg, sb, first);
          r += (first[0] - r) * ws;
          g += (first[1] - g) * ws;
          b += (first[2] - b) * ws;
        }
        final wl = light * la * m;
        if (wl > 0) {
          blendRgb(lightBlend, r, g, b, lr, lg, lb, mixed);
          r += (mixed[0] - r) * wl;
          g += (mixed[1] - g) * wl;
          b += (mixed[2] - b) * wl;
        }
      }
      out[i] = (r.clamp(0.0, 1.0) * a).round();
      out[i + 1] = (g.clamp(0.0, 1.0) * a).round();
      out[i + 2] = (b.clamp(0.0, 1.0) * a).round();
    }
  }
  return out;
}

/// An ARGB colour as (alpha, red, green, blue), 0 to 1.
(double, double, double, double) _straight(int argb) => (
  ((argb >> 24) & 0xFF) / 255,
  ((argb >> 16) & 0xFF) / 255,
  ((argb >> 8) & 0xFF) / 255,
  (argb & 0xFF) / 255,
);

double _smoothstep(double edge0, double edge1, double x) {
  if (x <= edge0) return 0;
  if (x >= edge1) return 1;
  final t = (x - edge0) / (edge1 - edge0);
  return t * t * (3 - 2 * t);
}

bool _any(Uint8List mask) {
  for (var i = 3; i < mask.length; i += 4) {
    if (mask[i] != 0) return true;
  }
  return false;
}
