import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

// Contract: pixel-art conversion must preserve source alpha per canvas pixel.
void main() {
  group('FilterEngine.applyPixelate true pixel art', () {
    test('does not average alpha inside a pixel cell', () {
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
      expect(output[7], 0);
      expect(output[11], 0);
      expect(output[15], 0);
    });

    test('explicit one-color mode recolors opaque pixels without changing alpha', () {
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

      expect(output.sublist(0, 4), [0, 0, 0, 255]);
      expect(output.sublist(4, 8), [0, 0, 0, 128]);
      expect(output.sublist(8, 12), [0, 0, 0, 0]);
      expect(output.sublist(12, 16), [0, 0, 0, 255]);
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
  });
}
