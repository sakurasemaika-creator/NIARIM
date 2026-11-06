import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/vhs_noise_engine.dart';

void main() {
  Uint8List fixture(int width, int height) {
    final out = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        out[i] = (x * 17 + y * 3) & 0xff;
        out[i + 1] = (x * 5 + y * 19) & 0xff;
        out[i + 2] = (x * 11 + y * 7) & 0xff;
        out[i + 3] = (x + y) % 5 == 0 ? 0 : 180 + ((x + y) % 76);
      }
    }
    return out;
  }

  test('same seed and frame produce byte-identical VHS output', () {
    final source = fixture(24, 18);
    final a = VhsNoiseEngine.apply(
      source,
      24,
      18,
      noiseStrength: 55,
      scanlineStrength: 40,
      colorBleed: 45,
      tracking: 50,
      seed: 1984,
      frameIndex: 12,
    );
    final b = VhsNoiseEngine.apply(
      source,
      24,
      18,
      noiseStrength: 55,
      scanlineStrength: 40,
      colorBleed: 45,
      tracking: 50,
      seed: 1984,
      frameIndex: 12,
    );
    expect(a, orderedEquals(b));
  });

  test('timeline frame changes animated VHS pattern', () {
    final source = fixture(24, 18);
    final a = VhsNoiseEngine.apply(source, 24, 18, seed: 7, frameIndex: 3);
    final b = VhsNoiseEngine.apply(source, 24, 18, seed: 7, frameIndex: 4);
    expect(a, isNot(orderedEquals(b)));
  });

  test('VHS processing preserves every alpha byte', () {
    final source = fixture(24, 18);
    final filtered = VhsNoiseEngine.apply(
      source,
      24,
      18,
      noiseStrength: 100,
      scanlineStrength: 100,
      colorBleed: 100,
      tracking: 100,
      seed: 99,
      frameIndex: 20,
    );
    for (var i = 3; i < source.length; i += 4) {
      expect(filtered[i], source[i], reason: 'alpha at byte $i');
    }
  });

  test('all-zero controls are a no-op', () {
    final source = fixture(12, 9);
    final filtered = VhsNoiseEngine.apply(
      source,
      12,
      9,
      noiseStrength: 0,
      scanlineStrength: 0,
      colorBleed: 0,
      tracking: 0,
    );
    expect(filtered, orderedEquals(source));
    expect(identical(filtered, source), isFalse);
  });

  test('zero color bleed does not secretly shift RGB channels', () {
    const width = 8;
    const height = 4;
    final source = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        source[i] = 10 + x * 20;
        source[i + 1] = 20 + x * 20;
        source[i + 2] = 30 + x * 20;
        source[i + 3] = 255;
      }
    }

    final filtered = VhsNoiseEngine.apply(
      source,
      width,
      height,
      noiseStrength: 0,
      scanlineStrength: 50,
      colorBleed: 0,
      tracking: 0,
    );

    // Even rows are not darkened by scanlines. With color bleed disabled they
    // therefore remain byte-identical, proving there is no hidden channel shift.
    for (var x = 0; x < width; x++) {
      final i = x * 4;
      expect(filtered[i], source[i]);
      expect(filtered[i + 1], source[i + 1]);
      expect(filtered[i + 2], source[i + 2]);
      expect(filtered[i + 3], source[i + 3]);
    }
  });
}
