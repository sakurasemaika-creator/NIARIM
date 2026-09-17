import 'dart:io';

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
}
