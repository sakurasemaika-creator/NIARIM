import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

void main() {
  test('mosaic averages RGBA inside each block without pixel-art edge synthesis', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 0, 0, 255, 0,
      0, 255, 0, 255, 255, 255, 255, 255,
    ]);

    final out = FilterEngine().applyMosaic(input, 2, 2, blockSize: 2);

    // One 2x2 block: each channel, including alpha, is the arithmetic mean.
    expect(out.sublist(0, 4), [128, 128, 128, 191]);
    for (var i = 4; i < out.length; i += 4) {
      expect(out.sublist(i, i + 4), out.sublist(0, 4));
    }
  });
}
