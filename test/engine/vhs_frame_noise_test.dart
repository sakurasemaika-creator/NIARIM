import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

/// The VHS noise drawing filter takes each frame's own noise (applied to
/// several frames it flickers, as a tape does), the same frame always gets
/// the same noise, and the frame-free noises (film grain) do not change
/// between frames.
void main() {
  const w = 48, h = 32;
  Uint8List picture() {
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        out.setAll((y * w + x) * 4, [x * 5, y * 7, 120, 255]);
      }
    }
    return out;
  }

  Uint8List run(FilterDef filter, int frame) =>
      applyDrawFilterForFrameInIsolate((picture(), w, h, filter, null, frame));

  const vhs = FilterDef(
    id: 'v',
    name: 'vhs',
    kind: FilterKind.noise,
    noiseStyle: NoiseStyle.vhs,
    strength: 80,
  );

  test('each frame has its own VHS noise, and keeps it', () {
    expect(run(vhs, 0), isNot(orderedEquals(run(vhs, 1))));
    expect(run(vhs, 3), orderedEquals(run(vhs, 3)));
    // The old entry point is frame 0.
    expect(
      applyDrawFilterInIsolate((picture(), w, h, vhs, null)),
      orderedEquals(run(vhs, 0)),
    );
  });

  test('film grain is the same on every frame', () {
    final grain = vhs.copyWith(noiseStyle: NoiseStyle.filmGrain);
    expect(run(grain, 0), orderedEquals(run(grain, 5)));
  });
}
