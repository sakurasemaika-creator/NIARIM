import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled bangs brush assets are declared, referenced, and present', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('    - assets/brushes/'),
      reason: 'Flutter must package the bundled brush image directory',
    );

    final presets =
        File('lib/models/brush_presets_extension.dart').readAsStringSync();
    for (var i = 1; i <= 5; i++) {
      final name = 'bangs_${i.toString().padLeft(2, '0')}.png';
      final assetPath = 'assets/brushes/$name';
      expect(
        presets,
        contains("'\$assetPath'"),
        reason: 'the bundled bangs preset must reference $assetPath',
      );
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
