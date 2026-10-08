import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// Retro Anime's 2 px colour glitch shifts the red and blue of each pixel
/// from its neighbours 2 px away: on a blue ramp across the picture, the
/// blue follows the ramp (shifted), instead of one blue being smeared
/// along the whole row.
void main() {
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
