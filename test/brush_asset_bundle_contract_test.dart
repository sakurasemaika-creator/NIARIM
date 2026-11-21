import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush_presets_extension.dart';

void main() {
  test('bundled bangs brush assets are declared, referenced, and present', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('    - assets/brushes/'),
      reason: 'Flutter must package the bundled brush image directory',
    );

    final bangs = brushExtensionPresets().singleWhere(
      (brush) => brush.id == 'Brush0024',
    );
    final expected = [
      for (var index = 1; index <= 5; index++)
        'assets/brushes/bangs_cut_${index.toString().padLeft(2, '0')}.png',
    ];
    expect(bangs.customImagePaths, expected);
    for (final assetPath in expected) {
      expect(
        File(assetPath).existsSync(),
        isTrue,
        reason: '$assetPath must be tracked in the repository',
      );
      expect(
        File(assetPath).lengthSync(),
        greaterThan(0),
        reason: '$assetPath must not be an empty placeholder',
      );
    }
  });
}
