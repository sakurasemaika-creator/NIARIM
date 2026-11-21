import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pixelate filter routes through the shared PixelArtEngine', () {
    final source = File('lib/engine/filter_engine.dart').readAsStringSync();

    expect(source, contains("import 'pixel_art_engine.dart';"));
    expect(source, contains('PixelArtEngine().convert('));
  });
}
