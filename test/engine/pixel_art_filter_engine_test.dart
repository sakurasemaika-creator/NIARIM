import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

// Contract: pixel-art conversion fills each kept block whole with one colour
// and one alpha (never averaged), so blocks stay square; mosaic remains a
// separate alpha-averaging effect. Internal smoothing is permitted only for
// diagonal boundaries between opaque colors and must obey the active color
// constraint; transparency and axis-aligned edges stay hard.
void main() {
  group('FilterEngine.applyPixelate true pixel art', () {
    test('does not average alpha inside a pixel cell: a lone dot becomes '
        'one whole opaque block', () {
      final engine = FilterEngine();
      final input = Uint8List.fromList([
        255, 0, 0, 255,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);

      final output = engine.applyPixelate(
        input,
        2,
        2,
        mosaicSize: 2,
        colorMode: PixelColorMode.none,
      );

      expect(output[3], 255);
      expect(output[7], 255);
      expect(output[11], 255);
      expect(output[15], 255);
    });

    test('explicit one-color mode recolors the block with no semi-transparent '
        'pixel', () {
      final engine = FilterEngine();
      final input = Uint8List.fromList([
        240, 180, 90, 255,
        240, 180, 90, 128,
        0, 0, 0, 0,
        240, 180, 90, 255,
      ]);

      final output = engine.applyPixelate(
        input,
        2,
        2,
        mosaicSize: 2,
        colorMode: PixelColorMode.explicit,
        paletteColors: const [0xFF000000],
      );

      for (var i = 0; i < output.length; i += 4) {
        expect(output.sublist(i, i + 4), [0, 0, 0, 255]);
      }
    });

    test('mosaic remains an alpha-averaging effect separate from pixel art', () {
      final engine = FilterEngine();
      final input = Uint8List.fromList([
        255, 0, 0, 255,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);

      final output = engine.applyMosaic(input, 2, 2, 2);

      expect(output[3], 64);
      expect(output[7], 64);
      expect(output[11], 64);
      expect(output[15], 64);
    });

    test('transparent diagonal outer edge never gains intermediate alpha', () {
      final engine = FilterEngine();
      final input = Uint8List.fromList([
        255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0,
        255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0, 0,
        255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255,
      ]);

      final output = engine.applyPixelate(
        input,
        3,
        3,
        mosaicSize: 1,
        colorMode: PixelColorMode.none,
      );

      for (var i = 3; i < output.length; i += 4) {
        expect(output[i], anyOf(0, 255));
      }
    });

    test('axis-aligned opaque color boundary does not invent a middle color', () {
      final engine = FilterEngine();
      final input = Uint8List.fromList([
        255, 0, 0, 255, 255, 0, 0, 255,
        0, 0, 255, 255, 0, 0, 255, 255,
      ]);

      final output = engine.applyPixelate(
        input,
        2,
        2,
        mosaicSize: 1,
        colorMode: PixelColorMode.none,
      );

      final rgb = <String>{};
      for (var i = 0; i < output.length; i += 4) {
        rgb.add('${output[i]},${output[i + 1]},${output[i + 2]}');
      }
      expect(rgb, {'255,0,0', '0,0,255'});
    });

    test('explicit palette never synthesizes a color outside the palette', () {
      final engine = FilterEngine();
      final input = Uint8List.fromList([
        255, 0, 0, 255, 0, 0, 255, 255, 0, 0, 255, 255,
        255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 255, 255,
        255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255,
      ]);
      const palette = [0xFFFF0000, 0xFF800080, 0xFF0000FF];

      final output = engine.applyPixelate(
        input,
        3,
        3,
        mosaicSize: 1,
        colorMode: PixelColorMode.explicit,
        paletteColors: palette,
      );

      final allowed = {'255,0,0', '128,0,128', '0,0,255'};
      for (var i = 0; i < output.length; i += 4) {
        expect(allowed, contains('${output[i]},${output[i + 1]},${output[i + 2]}'));
      }
    });
  });
}
