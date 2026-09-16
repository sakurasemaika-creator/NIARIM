import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stamp pixel mode routes through the shared PixelArtEngine', () {
    final source = File('lib/engine/procedural_texture.dart').readAsStringSync();

    expect(source, contains("import 'pixel_art_engine.dart';"));
    expect(
      source,
      contains('const PixelArtEngine().convert(texture, size, size)'),
    );
    expect(
      source,
      isNot(contains('FilterEngine().applyPixelate(texture, size, size)')),
    );
  });
}
