import 'dart:typed_data';

/// Layer pixels are premultiplied RGBA: each colour channel already carries
/// the pixel's alpha (50 % opaque yellow is `[128, 128, 0, 128]`). Colour
/// adjustments (curves, levels, hue/saturation...) are defined on the
/// straight colour, so they must take the alpha out first and put it back
/// after; applied to the premultiplied values directly they darken
/// half-transparent edges differently from solid paint and turn transparent
/// pixels into colour (RGB above alpha), which shows as a glowing fringe.

/// The straight value of premultiplied channel [value] at [alpha].
int straightChannel(int value, int alpha) {
  if (alpha <= 0) return 0;
  if (alpha >= 255) return value;
  final v = (value * 255 + (alpha >> 1)) ~/ alpha;
  return v > 255 ? 255 : v;
}

/// The premultiplied value of straight channel [value] at [alpha].
int premultipliedChannel(int value, int alpha) {
  if (alpha >= 255) return value;
  if (alpha <= 0) return 0;
  return (value * alpha + 127) ~/ 255;
}

/// [data] with each pixel's straight red, green and blue looked up in
/// [red], [green] and [blue] (256 entries each), alpha unchanged.
/// Fully transparent pixels stay `0, 0, 0, 0`.
Uint8List applyStraightChannelLuts(
  Uint8List data,
  List<int> red,
  List<int> green,
  List<int> blue,
) {
  final out = Uint8List.fromList(data);
  for (var i = 0; i + 3 < out.length; i += 4) {
    final a = out[i + 3];
    if (a == 0) {
      out[i] = 0;
      out[i + 1] = 0;
      out[i + 2] = 0;
      continue;
    }
    out[i] = premultipliedChannel(red[straightChannel(out[i], a)], a);
    out[i + 1] = premultipliedChannel(green[straightChannel(out[i + 1], a)], a);
    out[i + 2] = premultipliedChannel(blue[straightChannel(out[i + 2], a)], a);
  }
  return out;
}

/// A straight-colour copy of premultiplied [data] (alpha unchanged).
Uint8List unpremultiplied(Uint8List data) {
  final out = Uint8List.fromList(data);
  for (var i = 0; i + 3 < out.length; i += 4) {
    final a = out[i + 3];
    if (a == 255) continue;
    out[i] = straightChannel(out[i], a);
    out[i + 1] = straightChannel(out[i + 1], a);
    out[i + 2] = straightChannel(out[i + 2], a);
  }
  return out;
}

/// Premultiplies straight-colour [data] by each pixel's own alpha, in
/// place, and returns it.
Uint8List premultiplyInPlace(Uint8List data) {
  for (var i = 0; i + 3 < data.length; i += 4) {
    final a = data[i + 3];
    if (a == 255) continue;
    data[i] = premultipliedChannel(data[i], a);
    data[i + 1] = premultipliedChannel(data[i + 1], a);
    data[i + 2] = premultipliedChannel(data[i + 2], a);
  }
  return data;
}

/// Runs a colour filter written for straight colour on premultiplied
/// [data]: takes the alpha out, applies [filter], puts the (new) alpha back.
Uint8List onStraightColour(
  Uint8List data,
  Uint8List Function(Uint8List straight) filter,
) => premultiplyInPlace(filter(unpremultiplied(data)));

/// Keeps every colour channel at or below its pixel's alpha, in place (a
/// sharpening overshoot on a half-transparent edge would otherwise draw
/// brighter than the paint), and returns [data].
Uint8List clampChannelsToAlpha(Uint8List data) {
  for (var i = 0; i + 3 < data.length; i += 4) {
    final a = data[i + 3];
    if (a == 255) continue;
    if (data[i] > a) data[i] = a;
    if (data[i + 1] > a) data[i + 1] = a;
    if (data[i + 2] > a) data[i + 2] = a;
  }
  return data;
}
