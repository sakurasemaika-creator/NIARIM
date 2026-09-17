import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/layer.dart';

void main() {
  test('requested production blend modes are available without reordering legacy values', () {
    const legacy = <String>[
      'normal', 'multiply', 'screen', 'overlay', 'addition', 'subtract',
      'darken', 'lighten', 'colorBurn', 'colorDodge', 'hardLight', 'softLight',
      'difference', 'hue', 'saturation', 'color', 'luminosity',
    ];
    expect(BlendMode.values.take(legacy.length).map((e) => e.name), legacy);

    expect(
      BlendMode.values.map((e) => e.name),
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
}
