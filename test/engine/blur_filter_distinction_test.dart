import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

void main() {
  test('lens blur circular aperture stays distinct from gaussian blur', () {
    const width = 9;
    const height = 9;
    final input = Uint8List(width * height * 4);
    final center = (4 * width + 4) * 4;
    input[center] = 255;
    input[center + 1] = 255;
    input[center + 2] = 255;
    input[center + 3] = 255;

    final engine = FilterEngine();
    final gaussian = engine.applyGaussianBlur(input, width, height, 2);
    final lens = engine.applyLensBlur(input, width, height, 2);

    expect(lens, isNot(orderedEquals(gaussian)));

    // A circular radius-2 aperture excludes the diagonal (2,2) sample while
    // the separable Gaussian kernel still spreads energy there.
    final diagonal = (6 * width + 6) * 4;
    expect(lens[diagonal], 0);
    expect(gaussian[diagonal], greaterThan(0));

    // Both remain actual blur operations rather than a no-op.
    final neighbor = (4 * width + 5) * 4;
    expect(lens[neighbor], greaterThan(0));
    expect(gaussian[neighbor], greaterThan(0));
  });
}
