import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test('levels channel overrides affect only their selected RGB channel', () {
    final engine = FilterEngine();
    final source = Uint8List.fromList([64, 64, 64, 255]);
    final out = engine.applyLevels(
      source,
      1,
      1,
      inputBlack: 0,
      inputWhite: 255,
      inputGamma: 1,
      outputBlack: 0,
      outputWhite: 255,
      redLevels: const [0, 255, 1, 128, 255],
    );
    expect(out[0], greaterThan(64));
    expect(out[1], 64);
    expect(out[2], 64);
    expect(out[3], 255);
  });

  test('per-channel levels survive FilterDef serialization', () {
    const filter = FilterDef(
      id: 'levels-test',
      name: 'Levels',
      kind: FilterKind.levels,
      levelsRed: [1, 240, .9, 2, 250],
      levelsGreen: [2, 241, 1.1, 3, 251],
      levelsBlue: [3, 242, 1.2, 4, 252],
    );
    final restored = FilterDef.fromJson(filter.toJson());
    expect(restored.levelsRed, filter.levelsRed);
    expect(restored.levelsGreen, filter.levelsGreen);
    expect(restored.levelsBlue, filter.levelsBlue);
  });
}
