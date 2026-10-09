import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// Retro Anime's 2 px colour glitch shifts the red and blue of each pixel
/// from its neighbours 2 px away: on a blue ramp across the picture, the
/// blue follows the ramp (shifted), instead of one blue being smeared
/// along the whole row.
void main() {
  test('the final colour correction: contrast down 3%, saturation up 5% '
      '(the user asked for +5% where the recipe has -2%)', () {
    // Grey only moves towards the middle.
    expect(retroAnimeColourCorrection(200, 200, 200), (198, 198, 198));
    expect(retroAnimeColourCorrection(40, 40, 40), (43, 43, 43));
    // A colour, after the contrast step (197.8, 100.8, 52.3; its grey
    // 124.3), moves 5% further from its grey.
    expect(retroAnimeColourCorrection(200, 100, 50), (202, 100, 49));
  });

  test('the blue of a ramp is shifted, not smeared along the row', () {
    const w = 120, h = 20;
    final data = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        data.setAll((y * w + x) * 4, [120, 120, (x * 2).clamp(0, 255), 255]);
      }
    }
    final out = FilterEngine().applyRetroAnime(data, w, h, 1, seed: 7);
    final row = h ~/ 2;
    int blueAt(int x) => out[(row * w + x) * 4 + 2];
    // The blue still rises across the row (it was flat before the fix).
    expect(blueAt(100), greaterThan(blueAt(20) + 80));
    expect(blueAt(60), greaterThan(blueAt(20) + 30));
    for (var i = 0; i < out.length; i += 4) {
      for (var c = 0; c < 3; c++) {
        expect(out[i + c], lessThanOrEqualTo(out[i + 3]));
      }
    }
  });
}
