import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

/// The CRT filter's three sliders each do their own visible thing: colour
/// misregistration moves red and blue apart, beam bleed smears sideways, and
/// the screen strength draws RGB phosphor stripes and scan lines.
void main() {
  final engine = FilterEngine();
  const w = 41, h = 12;

  Uint8List bar() {
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = x == 20 ? 255 : 0;
        rgba.setAll((y * w + x) * 4, [v, v, v, 255]);
      }
    }
    return rgba;
  }

  int brightest(Uint8List rgba, int channel, int row) {
    var best = -1, at = -1;
    for (var x = 0; x < w; x++) {
      final v = rgba[(row * w + x) * 4 + channel];
      if (v > best) {
        best = v;
        at = x;
      }
    }
    return at;
  }

  test('colour misregistration moves red right and blue left, up to 4px', () {
    final none = engine.applyCrt(bar(), w, h, 0, aberration: 0, bleed: 0);
    expect(none, orderedEquals(bar()), reason: 'all sliders at 0');
    final full = engine.applyCrt(bar(), w, h, 0, aberration: 100, bleed: 0);
    expect(brightest(full, 0, 4), 24);
    expect(brightest(full, 1, 4), 20);
    expect(brightest(full, 2, 4), 16);
    final half = engine.applyCrt(bar(), w, h, 0, aberration: 50, bleed: 0);
    expect(brightest(half, 0, 4), 22);
  });

  test('beam bleed smears the picture sideways only', () {
    final crisp = engine.applyCrt(bar(), w, h, 0, aberration: 0, bleed: 0);
    final smeared = engine.applyCrt(bar(), w, h, 0, aberration: 0, bleed: 100);
    int lit(Uint8List rgba) => [
      for (var x = 0; x < w; x++) rgba[(4 * w + x) * 4 + 1],
    ].where((v) => v > 8).length;
    expect(lit(crisp), 1);
    expect(lit(smeared), greaterThanOrEqualTo(5));
    // Every row smears the same way: nothing bleeds up or down.
    for (var y = 1; y < h; y++) {
      expect(
        smeared.sublist(y * w * 4, (y + 1) * w * 4),
        orderedEquals(smeared.sublist(0, w * 4)),
      );
    }
  });

  test('the screen strength draws RGB phosphor stripes and scan lines', () {
    final white = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 200);
    for (var i = 3; i < white.length; i += 4) {
      white[i] = 255;
    }
    final out = engine.applyCrt(white, w, h, 100, aberration: 0, bleed: 0);
    // In the middle (away from the vignette), column x shows colour x % 3.
    for (var x = 18; x < 24; x++) {
      final i = (4 * w + x) * 4;
      final lit = x % 3;
      for (var c = 0; c < 3; c++) {
        if (c == lit) continue;
        expect(out[i + lit], greaterThan(out[i + c]), reason: 'column $x');
      }
    }
    // Every other row (the even ones) is a darker gap between scan lines.
    final even = (4 * w + 20) * 4, odd = (5 * w + 20) * 4;
    expect(out[odd + 2], greaterThan(out[even + 2]));
  });

  test('applying the filter uses its misregistration and bleed', () {
    const filter = FilterDef(
      id: 'crt',
      name: 'CRT',
      kind: FilterKind.crt,
      strength: 40,
      crtAberration: 75,
      crtBleed: 25,
    );
    final restored = FilterDef.fromJson(filter.toJson());
    expect(restored.crtAberration, 75);
    expect(restored.crtBleed, 25);
    final applied = applyDrawFilterInIsolate((bar(), w, h, filter, null));
    expect(
      applied,
      orderedEquals(
        engine.applyCrt(bar(), w, h, 40, aberration: 75, bleed: 25),
      ),
    );
    expect(
      applied,
      isNot(
        orderedEquals(
          applyDrawFilterInIsolate((
            bar(),
            w,
            h,
            filter.copyWith(crtAberration: 0),
            null,
          )),
        ),
      ),
    );
  });
}
