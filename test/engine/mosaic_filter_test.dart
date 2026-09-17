import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

void main() {
  test('classic mosaic averages RGBA independently from pixel-art conversion', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255,
      0, 255, 0, 255,
      0, 0, 255, 0,
      255, 255, 255, 0,
    ]);

    // Mosaic is deliberately arithmetic block averaging; it must never route
    // through the shared PixelArtEngine edge/palette synthesis contract.
    final output = FilterEngine().applyMosaic(input, 2, 2, 2);

    expect(output, [
      128, 128, 128, 128,
      128, 128, 128, 128,
      128, 128, 128, 128,
      128, 128, 128, 128,
    ]);
  });
}
