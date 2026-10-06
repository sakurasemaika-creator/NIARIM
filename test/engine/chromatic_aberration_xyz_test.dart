import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

/// Chromatic aberration's X, Y and Z each move red and blue apart for real:
/// X and Y sideways, Z radially (more towards the corners, none at the
/// centre). Strength is how far; X/Y/Z how much of it goes each way.
void main() {
  final engine = FilterEngine();

  /// An opaque black canvas with white pixels where [lit] says.
  Uint8List canvas(int w, int h, bool Function(int x, int y) lit) {
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final v = lit(x, y) ? 255 : 0;
        rgba
          ..[i] = v
          ..[i + 1] = v
          ..[i + 2] = v
          ..[i + 3] = 255;
      }
    }
    return rgba;
  }

  /// Where a channel is brightest along a row (or a column).
  int peak(Uint8List rgba, int w, int h, int channel, {int? row, int? col}) {
    var best = -1, at = -1;
    final n = row != null ? w : h;
    for (var k = 0; k < n; k++) {
      final i = row != null ? (row * w + k) * 4 : (k * w + col!) * 4;
      if (rgba[i + channel] > best) {
        best = rgba[i + channel];
        at = k;
      }
    }
    return at;
  }

  test('X moves red right and blue left; green stays', () {
    const w = 41, h = 9;
    final out = engine.applyChromaticShift(
      canvas(w, h, (x, _) => x == 20),
      w,
      h,
      shiftX: 3,
    );
    expect(peak(out, w, h, 0, row: 4), 23);
    expect(peak(out, w, h, 1, row: 4), 20);
    expect(peak(out, w, h, 2, row: 4), 17);
  });

  test('Y moves red down and blue up', () {
    const w = 9, h = 41;
    final out = engine.applyChromaticShift(
      canvas(w, h, (_, y) => y == 20),
      w,
      h,
      shiftY: -4,
    );
    expect(peak(out, w, h, 0, col: 4), 16);
    expect(peak(out, w, h, 1, col: 4), 20);
    expect(peak(out, w, h, 2, col: 4), 24);
  });

  test('Z separates the colours outwards, more towards the corners, and '
      'leaves the centre sharp', () {
    const w = 81, h = 81; // centre (40, 40), corner distance 56.6
    final out = engine.applyChromaticShift(
      canvas(w, h, (x, y) => y == 40 && (x == 40 || x == 70 || x == 10)),
      w,
      h,
      radial: 8,
    );
    int brightest(int channel, int from, int to) {
      var best = -1, at = -1;
      for (var x = from; x < to; x++) {
        final v = out[(40 * w + x) * 4 + channel];
        if (v > best) {
          best = v;
          at = x;
        }
      }
      return at;
    }

    // The shift is 8px at the corner (56.6px out) and proportional inwards,
    // measured where the colour lands: the dot 30px right of centre shows
    // its red at 75 (35px out, 4.9px shift) and its blue at 66.
    expect(brightest(0, 55, w), 75);
    expect(brightest(2, 55, w), 66);
    // 30px left of centre: mirrored.
    expect(brightest(0, 0, 25), 5);
    expect(brightest(2, 0, 25), 14);
    // The centre does not move.
    expect(out.sublist((40 * w + 40) * 4, (40 * w + 40) * 4 + 3), [
      255,
      255,
      255,
    ]);
  });

  test('on a transparent layer the fringe reaches past the edge and stays a '
      'valid premultiplied colour', () {
    const w = 30, h = 10;
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 10; x < 20; x++) {
        rgba.setAll((y * w + x) * 4, [255, 255, 255, 255]);
      }
    }
    final out = engine.applyChromaticShift(rgba, w, h, shiftX: 2);
    final outside = (5 * w + 21) * 4;
    expect(out[outside + 3], greaterThan(0), reason: 'red fringe outside');
    expect(out[outside], out[outside + 3]);
    expect(out[outside + 1], 0);
    expect(out[outside + 2], 0);
    for (var i = 0; i < out.length; i += 4) {
      expect(out[i], lessThanOrEqualTo(out[i + 3]));
      expect(out[i + 1], lessThanOrEqualTo(out[i + 3]));
      expect(out[i + 2], lessThanOrEqualTo(out[i + 3]));
    }
  });

  test('applying the filter uses strength × the X/Y/Z weights', () {
    const filter = FilterDef(
      id: 'ca',
      name: 'CA',
      kind: FilterKind.chromaticAberration,
      strength: 6,
      chromaticShiftX: 50,
      chromaticShiftY: -100,
      chromaticShiftZ: 25,
    );
    expect(filter.chromaticDisplacement, (3.0, -6.0, 1.5));
    const w = 33, h = 33;
    final input = canvas(w, h, (x, y) => (x + y) % 7 == 0);
    expect(
      applyDrawFilterInIsolate((input, w, h, filter, null)),
      orderedEquals(
        engine.applyChromaticShift(
          input,
          w,
          h,
          shiftX: 3,
          shiftY: -6,
          radial: 1.5,
        ),
      ),
    );
    expect(
      applyDrawFilterInIsolate((
        input,
        w,
        h,
        filter.copyWith(strength: 0),
        null,
      )),
      orderedEquals(input),
      reason: 'no strength, no shift',
    );
  });
}
