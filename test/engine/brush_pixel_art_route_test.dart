import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brush pixel mode routes through the shared PixelArtEngine', () {
    final source =
        File('lib/screens/canvas/widgets/canvas_area.dart').readAsStringSync();

    expect(source, contains("import '../../../engine/pixel_art_engine.dart';"));
    expect(source, contains('const PixelArtEngine().convert('));
    expect(source, contains('pixelSize: 1'));
    expect(
      source,
      isNot(contains('quantizeColors(\n        tile,')),
      reason: 'brush pixel mode must not bypass the shared converter',
    );
  });
}
