import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/pixel_art_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

const _six = [
  0xFF000000,
  0xFFFFFFFF,
  0xFFFF0000,
  0xFFFFFF00,
  0xFF0000FF,
  0xFF00FF00,
];

/// The colour one 8 x 8 block of opaque [r], [g], [b] becomes.
List<int> _dot(int r, int g, int b) {
  final data = Uint8List(8 * 8 * 4);
  for (var i = 0; i < data.length; i += 4) {
    data
      ..[i] = r
      ..[i + 1] = g
      ..[i + 2] = b
      ..[i + 3] = 255;
  }
  final out = const PixelArtEngine().convert(
    data,
    8,
    8,
    pixelSize: 8,
    colorMode: PixelColorMode.explicit,
    paletteColors: _six,
  );
  return out.sublist(0, 3);
}

/// ドット絵 with chosen colours picks the colour that looks nearest: the grey
/// edge between a white shape and its dark outline becomes white or black,
/// never yellow (which plain RGB distance put just as near).
void main() {
  test('greys become black or white, not yellow', () {
    // Neutral and slightly warm greys: the edge of an off-white shape with a
    // dark outline.
    for (final (r, g, b) in const [
      (96, 96, 96),
      (128, 128, 128),
      (160, 160, 160),
      (140, 140, 120),
      (150, 148, 128),
      (170, 168, 150),
    ]) {
      final dot = _dot(r, g, b);
      expect(
        dot,
        anyOf(equals([0, 0, 0]), equals([255, 255, 255])),
        reason: '($r, $g, $b) became $dot',
      );
    }
    expect(_dot(200, 200, 200), [255, 255, 255]);
    expect(_dot(50, 50, 50), [0, 0, 0]);
  });

  test('colours still go to their own hue', () {
    expect(_dot(230, 210, 40), [255, 255, 0], reason: 'a dull yellow');
    expect(_dot(220, 50, 60), [255, 0, 0], reason: 'a red');
    expect(_dot(40, 60, 210), [0, 0, 255], reason: 'a blue');
    expect(_dot(50, 190, 70), [0, 255, 0], reason: 'a green');
  });
}
