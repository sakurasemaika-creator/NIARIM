import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/vhs_noise_engine.dart';

void main() {
  test('retro anime grading differs from neutral film grain', () {
    final engine = FilterEngine();
    final input = Uint8List.fromList(
      List<int>.generate(16, (i) => const <int>[120, 100, 80, 255][i % 4]),
    );
    final grain = engine.applyFilmGrain(input, 2, 2, 0.15, seed: 7);
    final retro = engine.applyRetroAnime(input, 2, 2, 100, seed: 7);
    for (var i = 0; i < input.length; i += 4) {
      expect(grain[i] - grain[i + 1], 20);
      expect(grain[i + 1] - grain[i + 2], 20);
    }
    expect(retro, isNot(equals(grain)));
  });

  test('CRT produces static alternating scanlines and preserves alpha', () {
    final engine = FilterEngine();
    final input = Uint8List(4 * 4 * 4);
    for (var i = 0; i < input.length; i += 4) {
      input[i] = 140;
      input[i + 1] = 140;
      input[i + 2] = 140;
      input[i + 3] = 200;
    }
    final out = engine.applyCrt(input, 4, 4, 100);
    expect(out[0], lessThan(out[16]));
    for (var i = 3; i < out.length; i += 4) {
      expect(out[i], 200);
    }
  });

  test('VHS tracking changes by frame while CRT remains static', () {
    final engine = FilterEngine();
    const w = 24, h = 24;
    final input = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        input[i] = x * 10;
        input[i + 1] = y * 10;
        input[i + 2] = 80;
        input[i + 3] = 255;
      }
    }
    expect(engine.applyCrt(input, w, h, 80), equals(engine.applyCrt(input, w, h, 80)));
    final a = VhsNoiseEngine.apply(input, w, h,
      noiseStrength: 0, scanlineStrength: 0, colorBleed: 0,
      tracking: 100, seed: 1984, frameIndex: 0);
    final b = VhsNoiseEngine.apply(input, w, h,
      noiseStrength: 0, scanlineStrength: 0, colorBleed: 0,
      tracking: 100, seed: 1984, frameIndex: 1);
    expect(a, isNot(equals(b)));
    for (var i = 3; i < a.length; i += 4) {
      expect(a[i], 255);
      expect(b[i], 255);
    }
  });
}
