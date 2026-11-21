import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/pixel_art_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

const _skin = 0xFFF8D7A4, _ink = 0xFF182746;
const _palette = [0xFF182746, 0xFFE36B87, 0xFFF8D7A4, 0xFFFFFFFF];

/// A face of skin on a transparent layer, 64 x 64 with 8 px dots: two eyes
/// (3 x 6 px of dark ink, about a quarter of their dot) and a mouth (a 2 px
/// line across two dots).
Uint8List _face() {
  const w = 64;
  final rgba = Uint8List(w * w * 4);
  void fill(int x0, int y0, int x1, int y1, int color) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * w + x) * 4;
        rgba[i] = (color >> 16) & 0xff;
        rgba[i + 1] = (color >> 8) & 0xff;
        rgba[i + 2] = color & 0xff;
        rgba[i + 3] = 255;
      }
    }
  }

  fill(8, 8, 56, 56, _skin);
  fill(19, 25, 22, 31, _ink); // left eye, in the dot at (2, 3)
  fill(42, 25, 45, 31, _ink); // right eye, in the dot at (5, 3)
  fill(26, 44, 38, 46, _ink); // mouth, across the dots at (3, 5), (4, 5)
  return rgba;
}

int _dot(Uint8List out, int cx, int cy) {
  final i = ((cy * 8 + 4) * 64 + cx * 8 + 4) * 4;
  return 0xFF000000 | out[i] << 16 | out[i + 1] << 8 | out[i + 2];
}

/// Pixel art keeps a face's eyes and mouth: a dot holding a small dark
/// feature takes the feature's colour, rather than the block's average,
/// which is barely darker than the skin and came out as skin (a blank
/// face) once colours were matched by how they look.
void main() {
  const engine = PixelArtEngine();
  final face = _face();
  for (final dither in [false, true]) {
    for (final (name, mode, colors) in [
      ('palette', PixelColorMode.palette, _palette),
      ('colour count', PixelColorMode.count, const <int>[]),
    ]) {
      test(
        '$name, dithering ${dither ? 'on' : 'off'}: eyes and mouth stay',
        () {
          final out = engine.convert(
            face,
            64,
            64,
            pixelSize: 8,
            colorMode: mode,
            colorLevels: 4,
            paletteColors: colors,
            dither: dither,
          );
          int luma(int c) =>
              ((c >> 16) & 0xff) * 3 + ((c >> 8) & 0xff) * 6 + (c & 0xff);
          final skin = luma(_dot(out, 3, 2));
          for (final (cx, cy, what) in [
            (2, 3, 'left eye'),
            (5, 3, 'right eye'),
            (3, 5, 'mouth, left'),
            (4, 5, 'mouth, right'),
          ]) {
            expect(
              luma(_dot(out, cx, cy)),
              lessThan(skin ~/ 2),
              reason: '$what at ($cx, $cy) is dark, not skin',
            );
          }
          // The plain skin around them stays skin.
          for (final (cx, cy) in [(3, 2), (4, 3), (2, 5), (5, 5)]) {
            expect(luma(_dot(out, cx, cy)), skin, reason: 'skin at ($cx, $cy)');
          }
        },
      );
    }
  }
}
