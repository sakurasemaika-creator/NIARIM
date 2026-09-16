import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

void main() {
  test('film grain keeps each noise sample neutral across RGB channels', () {
    final input = Uint8List.fromList(List<int>.generate(16, (i) {
      switch (i % 4) {
        case 0:
        case 1:
        case 2:
          return 128;
        default:
          return 255;
      }
    }));
    final out = FilterEngine().applyFilmGrain(input, 2, 2, 0.5, seed: 7);
    for (var i = 0; i < out.length; i += 4) {
      expect(out[i], out[i + 1]);
      expect(out[i + 1], out[i + 2]);
      expect(out[i + 3], 255);
    }
  });

  test('generic noise can vary RGB channels independently', () {
    final input = Uint8List.fromList(List<int>.generate(64, (i) {
      switch (i % 4) {
        case 0:
        case 1:
        case 2:
          return 128;
        default:
          return 255;
      }
    }));
    final out = FilterEngine().applyColorNoise(input, 4, 4, 0.5, seed: 7);
    expect(
      List<int>.generate(16, (p) => p * 4).any(
        (i) => out[i] != out[i + 1] || out[i + 1] != out[i + 2],
      ),
      isTrue,
    );
    for (var i = 3; i < out.length; i += 4) {
      expect(out[i], 255);
    }
  });
}
