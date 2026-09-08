import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  Uint8List sample() => Uint8List.fromList(
    List<int>.generate(8 * 8 * 4, (i) {
      if (i % 4 == 3) return 255;
      return (i * 17) & 0xff;
    }),
  );

  test('drawing VHS stable ID routes through deterministic VHS engine', () {
    final f = FilterDef(
      id: 'Filter0024',
      name: 'VHS',
      kind: FilterKind.noise,
      strength: 45,
      caSaturation: 30,
      caBrightness: 40,
      caContrast: 20,
      thresholdValue: 1984,
    );
    final a = applyDrawFilterInIsolate((sample(), 8, 8, f, null));
    final b = applyDrawFilterInIsolate((sample(), 8, 8, f, null));
    expect(a, orderedEquals(b));
  });

  test('timeline VHS changes by frame but stays deterministic per frame', () {
    const effect = EffectFilterInstance(
      id: 'vhs_test',
      type: EffectFilterType.vhsNoise,
      startFrame: 0,
      endFrame: 10,
      param1: 45,
      param2: 30,
      param3: 40,
      param4: 20,
    );
    final engine = FilterEngine();
    final a = engine.applyEffectFilters(sample(), 8, 8, const [effect], 2);
    final b = engine.applyEffectFilters(sample(), 8, 8, const [effect], 2);
    final c = engine.applyEffectFilters(sample(), 8, 8, const [effect], 3);
    expect(a, orderedEquals(b));
    expect(a, isNot(orderedEquals(c)));
  });
}
