import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// Anime Style's line width works on line art drawn on a transparent layer
/// too: the lines thicken as it goes up (the new edge is a dark line, not a
/// darkened transparent pixel no one sees), and 0 leaves the line width as
/// it was. On an opaque picture it darkens the edges as before.
void main() {
  final engine = FilterEngine();
  const w = 40, h = 30;

  /// A black vertical line, 3 px wide, on transparency.
  Uint8List line() {
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 19; x < 22; x++) {
        out.setAll((y * w + x) * 4, [0, 0, 0, 255]);
      }
    }
    return out;
  }

  /// How many pixels of the middle row show (alpha above 128).
  int widthOf(Uint8List data) {
    var n = 0;
    for (var x = 0; x < w; x++) {
      if (data[((h ~/ 2) * w + x) * 4 + 3] > 128) n++;
    }
    return n;
  }

  Uint8List anime(Uint8List data, double lineWidth) => engine.applyAnimeStyle(
    data,
    w,
    h,
    strength: 100,
    colorCount: 8,
    edgeStrength: 1,
    lineWidth: lineWidth,
  );

  test('0 keeps the line as wide as it was', () {
    expect(widthOf(anime(line(), 0)), 3);
  });

  test('the line thickens as the width goes up', () {
    final w2 = widthOf(anime(line(), 2));
    final w4 = widthOf(anime(line(), 4));
    expect(w2, greaterThan(3));
    expect(w4, greaterThan(w2));
    // The added edge is dark, as a line is.
    final out = anime(line(), 2);
    final i = ((h ~/ 2) * w + 18) * 4;
    expect(out[i + 3], greaterThan(128));
    expect(out[i], lessThan(60));
  });

  test('every output pixel stays valid premultiplied', () {
    final out = anime(line(), 3);
    for (var i = 0; i < out.length; i += 4) {
      for (var c = 0; c < 3; c++) {
        expect(out[i + c], lessThanOrEqualTo(out[i + 3]));
      }
    }
  });
}
