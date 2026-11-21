import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

/// Per-channel Levels edits show in the preview, so Apply (which runs in a
/// background isolate) must use them too.
void main() {
  Uint8List gradient() {
    final rgba = Uint8List(64 * 4);
    for (var i = 0; i < 64; i++) {
      rgba[i * 4] = i * 4;
      rgba[i * 4 + 1] = 255 - i * 4;
      rgba[i * 4 + 2] = (i * 37) % 256;
      rgba[i * 4 + 3] = 255;
    }
    return rgba;
  }

  test('Apply keeps the red, green and blue channel levels', () {
    const filter = FilterDef(
      id: 'levels-channels',
      name: 'Levels',
      kind: FilterKind.levels,
      levelsRed: [40, 200, 1.4, 10, 240],
      levelsGreen: [0, 255, 0.6, 0, 255],
      levelsBlue: [20, 255, 1.0, 60, 200],
    );
    final input = gradient();

    final applied = applyDrawFilterInIsolate((input, 64, 1, filter, null));
    final preview = FilterEngine().applyLevels(
      input,
      64,
      1,
      inputBlack: filter.inputBlack,
      inputWhite: filter.inputWhite,
      inputGamma: filter.inputGamma,
      outputBlack: filter.outputBlack,
      outputWhite: filter.outputWhite,
      redLevels: filter.levelsRed,
      greenLevels: filter.levelsGreen,
      blueLevels: filter.levelsBlue,
    );

    expect(applied, orderedEquals(preview));
    expect(
      applied,
      isNot(orderedEquals(input)),
      reason: 'the channel levels change the picture',
    );
  });
}
