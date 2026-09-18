import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:niarim/models/layer.dart';

void main() {
  test('requested production blend modes are available without reordering legacy values', () {
    const legacy = <String>[
      'normal', 'multiply', 'screen', 'overlay', 'addition', 'subtract',
      'darken', 'lighten', 'colorBurn', 'colorDodge', 'hardLight', 'softLight',
      'difference', 'hue', 'saturation', 'color', 'luminosity',
    ];
    expect(LayerBlendMode.values.take(legacy.length).map((e) => e.name), legacy);

    expect(
      LayerBlendMode.values.map((e) => e.name),
      containsAll(<String>[
        'linearBurn',
        'linearDodge',
        'vividLight',
        'linearLight',
        'pinLight',
        'hardMix',
        'exclusion',
        'divide',
      ]),
    );
  });
  test('all extended blend modes are serialized by stable names', () {
    final source = File('lib/engine/niapro_serializer.dart').readAsStringSync();
    expect(source, contains("'blendMode': l.blendMode.name"));
    expect(source, contains("e.name == j['blendMode']"));
    for (final mode in LayerBlendMode.values.skip(17)) {
      expect(mode.name, isNotEmpty);
    }
  });

  test('addition and linear dodge remain distinct persisted modes', () {
    expect(LayerBlendMode.addition.name, 'addition');
    expect(LayerBlendMode.linearDodge.name, 'linearDodge');
    expect(LayerBlendMode.addition, isNot(LayerBlendMode.linearDodge));
  });
}
