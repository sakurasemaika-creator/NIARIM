import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// Gaussian and Lens blur spread out of the drawing into the transparent
/// pixels around it (both sides of an edge soften, as in a paint app), at
/// every radius the panel offers, and stay valid premultiplied pixels. The
/// Lens blur gives bright points round discs that keep their brightness,
/// where the Gaussian melts them away.
void main() {
  final engine = FilterEngine();

  /// A [size]² canvas, transparent, with an opaque red square of side
  /// [side] in the middle.
  Uint8List square(int size, int side) {
    final out = Uint8List(size * size * 4);
    final start = (size - side) ~/ 2;
    for (var y = start; y < start + side; y++) {
      for (var x = start; x < start + side; x++) {
        out.setAll((y * size + x) * 4, [220, 30, 30, 255]);
      }
    }
    return out;
  }

  void expectValid(Uint8List data) {
    for (var i = 0; i < data.length; i += 4) {
      for (var c = 0; c < 3; c++) {
        expect(data[i + c], lessThanOrEqualTo(data[i + 3]));
      }
    }
  }

  /// Alpha along the middle row.
  List<int> alphaRow(Uint8List data, int size) => [
    for (var x = 0; x < size; x++) data[((size ~/ 2) * size + x) * 4 + 3],
  ];

  for (final (name, blur) in [
    ('Gaussian', engine.applyGaussianBlur),
    ('Lens', engine.applyLensBlur),
  ]) {
    for (final radius in [4, 12, 30, 60]) {
      test('$name blur of $radius px spreads outside the drawing', () {
        final size = radius * 6;
        final side = radius * 2;
        final out = blur(square(size, side), size, size, radius.toDouble());
        expectValid(out);
        final row = alphaRow(out, size);
        final edge = (size - side) ~/ 2;
        // Just outside the edge the transparent area is now partly
        // covered; just inside, the shape is no longer solid.
        expect(row[edge - radius ~/ 2], greaterThan(0), reason: 'outside');
        expect(row[edge + radius ~/ 4], lessThan(255), reason: 'inside');
        // The middle row is symmetric (the blur has no direction)…
        for (var x = 0; x < size; x++) {
          expect(row[x], closeTo(row[size - 1 - x], 2));
        }
        // …and reaches no further than its radius.
        expect(row[edge - radius - 2], 0, reason: 'beyond the radius');
        // The colour inside the spread is the shape's colour.
        final o = ((size ~/ 2) * size + edge - radius ~/ 2) * 4;
        expect(out[o] * 255 / out[o + 3], closeTo(220, 8));
      });
    }
  }

  test('the panel radius range above 20 px is honoured', () {
    // Radii are no longer capped at 20: 60 spreads three times as far.
    const size = 300;
    final input = square(size, 60);
    final narrow = alphaRow(
      engine.applyGaussianBlur(input, size, size, 20),
      size,
    );
    final wide = alphaRow(
      engine.applyGaussianBlur(input, size, size, 60),
      size,
    );
    int reach(List<int> row) => row.indexWhere((a) => a > 0);
    expect(reach(wide), lessThan(reach(narrow) - 25));
  });

  test('Lens blur keeps a bright point bright as a disc', () {
    // One white point on a dark grey opaque field.
    const size = 41;
    final input = Uint8List(size * size * 4);
    for (var i = 0; i < input.length; i += 4) {
      input.setAll(i, [40, 40, 40, 255]);
    }
    input.setAll(((size ~/ 2) * size + size ~/ 2) * 4, [255, 255, 255, 255]);
    final lens = engine.applyLensBlur(input, size, size, 6);
    final gauss = engine.applyGaussianBlur(input, size, size, 6);
    int at(Uint8List d, int dx, int dy) =>
        d[((size ~/ 2 + dy) * size + size ~/ 2 + dx) * 4];
    // The highlight weighs more, so the disc around it stays lighter than
    // the Gaussian's smear at the same spot…
    expect(at(lens, 3, 0), greaterThan(at(gauss, 3, 0)));
    // …and it is a flat disc: the same brightness across it, then the
    // background right outside it.
    expect(at(lens, 0, 0), closeTo(at(lens, 4, 0), 1));
    expect(at(lens, 0, 0), closeTo(at(lens, 0, -4), 1));
    expect(at(lens, 9, 0), 40);
  });
}
