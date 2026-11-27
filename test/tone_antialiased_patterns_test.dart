import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/models/tone.dart';

/// 網点・同心円・波線は縁を画素の中の覆う割合で描く。網点のインクの量は
/// 以前の2値の網点と同じ。
///
/// 以前は画素の角で内外を決めた2値で、網点は点が半画素ずれて左右非対称、
/// 縁は段になっていた。インクの量を変えると、すでに描いた網点の隣に描き
/// 足した所だけ濃さが変わるので、量はそのまま（名前の割合へ合わせるかは
/// 所有者の判断を待つ）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double ink(Uint8List rgba) {
    var sum = 0;
    for (var i = 3; i < rgba.length; i += 4) {
      sum += rgba[i];
    }
    return sum / 255 / (rgba.length / 4);
  }

  bool hasSoftEdges(Uint8List rgba) {
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] > 0 && rgba[i] < 255) return true;
    }
    return false;
  }

  test('網点のインクの量は以前の2値の網点と同じ（10%〜90%）', () {
    // Ink of the earlier built-in images (pixels inked out of the 256 of a
    // cell), measured from assets/tones before the edges were smoothed.
    const earlier = {
      10: 21,
      20: 37,
      30: 45,
      40: 69,
      50: 89,
      60: 97,
      70: 121,
      80: 137,
      90: 145,
    };
    for (final MapEntry(key: percent, value: inked) in earlier.entries) {
      final rgba = generateBuiltInToneTexture(
        Tone(id: 'd$percent', name: '網点 $percent%'),
      );
      expect(ink(rgba), closeTo(inked / 256, 0.01), reason: '$percent%');
      expect(hasSoftEdges(rgba), isTrue, reason: '$percent%');
    }
  });

  test('網点の点はセルの真ん中にあり、上下左右に対称', () {
    final tone = const Tone(id: 'd', name: '網点 40%');
    final size = toneTileSize(tone);
    final rgba = generateBuiltInToneTexture(tone);
    int a(int x, int y) => rgba[(y * size + x) * 4 + 3];
    const cell = 16;
    for (var y = 0; y < cell; y++) {
      for (var x = 0; x < cell; x++) {
        expect(a(x, y), a(cell - 1 - x, y), reason: '($x, $y)');
        expect(a(x, y), a(x, cell - 1 - y), reason: '($x, $y)');
      }
    }
  });

  test('濃い網点も点は隣とつながらない（以前と同じ並び）', () {
    final rgba = generateBuiltInToneTexture(
      const Tone(id: 'd', name: '網点 90%'),
    );
    // The middle of a cell edge (between two dots) stays paper.
    expect(rgba[(8 * 64 + 0) * 4 + 3], 0);
    expect(rgba[(0 * 64 + 8) * 4 + 3], 0);
  });

  test('同心円と波線の縁はなめらかで、波線は傾いた所も同じ太さ', () {
    for (final name in ['同心円', '波線']) {
      final rgba = generateBuiltInToneTexture(Tone(id: name, name: name));
      expect(hasSoftEdges(rgba), isTrue, reason: name);
    }
    final wave = generateBuiltInToneTexture(const Tone(id: 'w', name: '波線'));
    // Ink across each column: the line is about 2px thick measured across
    // the curve, so a column through a steep part holds more ink, but never
    // the 2px-per-line of a line measured straight down.
    const size = 64;
    for (final x in [0, 4, 8, 12]) {
      var sum = 0.0;
      for (var y = 0; y < size; y++) {
        sum += wave[(y * size + x) * 4 + 3] / 255;
      }
      final perLine = sum / (size / 8);
      expect(perLine, greaterThan(1.9), reason: 'column $x');
      expect(perLine, lessThan(3.4), reason: 'column $x');
    }
  });
}
