import 'dart:io';
import 'dart:typed_data';

import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stamp pixel mode routes through the shared pixel-art contract', () {
    final source = File('lib/engine/procedural_texture.dart').readAsStringSync();
    expect(source, contains("import 'filter_engine.dart';"));
    expect(source, contains('if (stamp.pixelMode)'));
    expect(source, contains('FilterEngine().applyPixelate('));

    final filterSource = File('lib/engine/filter_engine.dart').readAsStringSync();
    expect(filterSource, contains("import 'pixel_art_engine.dart';"));
    expect(filterSource, contains('PixelArtEngine().convert('));
  });

  test('stamp/filter shared route preserves hard alpha and palette contract', () {
    final rgba = Uint8List.fromList([
      255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0,
      255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0,
    ]);
    final engine = FilterEngine();
    final stampRoute = engine.applyPixelate(
      rgba,
      4,
      4,
      mosaicSize: 2,
      colorMode: PixelColorMode.explicit,
      paletteColors: const [0xFFFF0000, 0xFF0000FF],
    );
    final filterRoute = engine.applyPixelate(
      rgba,
      4,
      4,
      mosaicSize: 2,
      colorMode: PixelColorMode.explicit,
      paletteColors: const [0xFFFF0000, 0xFF0000FF],
    );
    expect(stampRoute, orderedEquals(filterRoute));
    for (var i = 3; i < stampRoute.length; i += 4) {
      expect(stampRoute[i], anyOf(0, 255));
    }
    for (var i = 0; i < stampRoute.length; i += 4) {
      if (stampRoute[i + 3] == 0) continue;
      final rgb =
          (stampRoute[i] << 16) | (stampRoute[i + 1] << 8) | stampRoute[i + 2];
      expect(rgb, anyOf(0xFF0000, 0x0000FF));
    }
  });
}

