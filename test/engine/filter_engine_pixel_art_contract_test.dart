import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

void main() {
  test('applyPixelate uses the shared diagonal pixel-art contract', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 0, 0, 255, 255,
      0, 0, 255, 255, 255, 0, 0, 255,
    ]);
    final out = FilterEngine().applyPixelate(
      input, 2, 2,
      mosaicSize: 1,
      colorMode: PixelColorMode.none,
    );
    expect(out.sublist(4, 7), [128, 0, 128]);
    expect([out[3], out[7], out[11], out[15]], [255, 255, 255, 255]);
  });

  test('pixel-art contract keeps transparent exterior hard', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 0, 0, 0, 0,
      255, 0, 0, 255, 255, 0, 0, 255,
    ]);
    final out = FilterEngine().applyPixelate(input, 2, 2, mosaicSize: 1);
    expect([out[3], out[7], out[11], out[15]], [255, 0, 255, 255]);
  });
}
