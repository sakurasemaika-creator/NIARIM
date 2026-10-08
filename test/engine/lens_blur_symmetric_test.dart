import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// Lens blur spreads a drawing's edge as far out as in, whatever its colour:
/// the transparent pixels around it add no colour, so a white shape does not
/// swell outwards more than a red one (they used to count as black, weighing
/// the opacity towards the bright side).
void main() {
  final engine = FilterEngine();
  const size = 80, side = 40, radius = 10;

  Uint8List square(List<int> rgb) {
    final out = Uint8List(size * size * 4);
    const start = (size - side) ~/ 2;
    for (var y = start; y < start + side; y++) {
      for (var x = start; x < start + side; x++) {
        out.setAll((y * size + x) * 4, [...rgb, 255]);
      }
    }
    return out;
  }

  int alphaAt(Uint8List d, int x) => d[((size ~/ 2) * size + x) * 4 + 3];

  test('a white and a red square spread alike, out as far as in', () {
    final white = engine.applyLensBlur(square([255, 255, 255]), size, size, 10);
    final red = engine.applyLensBlur(square([220, 30, 30]), size, size, 10);
    const edge = (size - side) ~/ 2;
    for (var d = 1; d <= radius; d++) {
      final outside = alphaAt(white, edge - d);
      final inside = alphaAt(white, edge + d - 1);
      expect(outside + inside, closeTo(255, 12), reason: '$d px from the edge');
      expect(alphaAt(red, edge - d), closeTo(outside, 2));
    }
    // The colour stays the square's own, and valid premultiplied.
    final i = ((size ~/ 2) * size + edge - 3) * 4;
    expect(white[i] * 255 / white[i + 3], closeTo(255, 2));
    for (final d in [white, red]) {
      for (var p = 0; p < d.length; p += 4) {
        for (var c = 0; c < 3; c++) {
          expect(d[p + c], lessThanOrEqualTo(d[p + 3]));
        }
      }
    }
  });

  test('bright points still open into bright discs', () {
    final data = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        data.setAll((y * size + x) * 4, [40, 40, 40, 255]);
      }
    }
    data.setAll(((size ~/ 2) * size + size ~/ 2) * 4, [255, 255, 255, 255]);
    final out = engine.applyLensBlur(data, size, size, 4);
    final near = ((size ~/ 2) * size + size ~/ 2 + 2) * 4;
    final gaussian = engine.applyGaussianBlur(data, size, size, 4);
    expect(out[near], greaterThan(gaussian[near]));
  });
}
