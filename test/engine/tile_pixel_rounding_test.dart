// タイルへ1画素を重ねる・消す計算（blendPixel・blendPremultipliedPixel・
// erasePixel）は、丸め（double.round）と範囲（clamp）を呼び出しの要らない形で
// 書いてある（所有者の方針「機能を保ったまま軽く」、2026-11-27）。結果は以前の
// 式と1つも違わない：どの入力でも、以前の式で計算した画素と同じバイトになる。
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';

/// The pixel blends as they were written before (the reference).
void _blendBefore(Uint8List tile, int idx, int r, int g, int b, int a) {
  final srcA = a / 255.0;
  final keep = 1.0 - srcA;
  final outA = (a + tile[idx + 3] * keep).round().clamp(0, 255);
  tile[idx] = (r * srcA + tile[idx] * keep).round().clamp(0, outA);
  tile[idx + 1] = (g * srcA + tile[idx + 1] * keep).round().clamp(0, outA);
  tile[idx + 2] = (b * srcA + tile[idx + 2] * keep).round().clamp(0, outA);
  tile[idx + 3] = outA;
}

void _premultipliedBefore(Uint8List tile, int idx, int r, int g, int b, int a) {
  final keep = 1.0 - a / 255.0;
  final outA = (a + tile[idx + 3] * keep).round().clamp(0, 255);
  tile[idx] = (r + tile[idx] * keep).round().clamp(0, outA);
  tile[idx + 1] = (g + tile[idx + 1] * keep).round().clamp(0, outA);
  tile[idx + 2] = (b + tile[idx + 2] * keep).round().clamp(0, outA);
  tile[idx + 3] = outA;
}

void _eraseBefore(Uint8List tile, int idx, int a) {
  final keep = 1.0 - a / 255.0;
  final newA = (tile[idx + 3] * keep).round().clamp(0, 255);
  tile[idx + 3] = newA;
  tile[idx] = (tile[idx] * keep).round().clamp(0, newA);
  tile[idx + 1] = (tile[idx + 1] * keep).round().clamp(0, newA);
  tile[idx + 2] = (tile[idx + 2] * keep).round().clamp(0, newA);
}

void main() {
  test('roundHalfAway is double.round', () {
    final values = <double>[
      0,
      -0.0,
      0.49999999999999994,
      -0.49999999999999994,
      1 - 1e-16,
      4503599627370495.5,
      4503599627370496,
      -4503599627370495.5,
      1e15 + 0.5,
    ];
    for (var k = -600; k <= 600; k++) {
      final half = k + 0.5;
      values.addAll([half, half - 1e-12, half + 1e-12, k.toDouble()]);
    }
    final random = math.Random(7);
    for (var i = 0; i < 200000; i++) {
      values.add((random.nextDouble() * 2 - 1) * 1200);
      values.add(random.nextDouble() * 255 * 2);
    }
    for (final v in values) {
      expect(roundHalfAway(v), v.round(), reason: '$v');
    }
    for (final v in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(() => roundHalfAway(v), throwsUnsupportedError);
      expect(() => v.round(), throwsUnsupportedError);
    }
    for (var i = 0; i < 256; i++) {
      expect(byteDoubles[i], i.toDouble());
    }
  });

  test('blending and erasing a pixel give the same bytes as before', () {
    final tiles = TileManager(canvasWidth: 256, canvasHeight: 256);
    final random = math.Random(11);
    final now = Uint8List(4), before = Uint8List(4);
    void check(String what, void Function() mine, void Function() theirs) {
      final start = [for (var c = 0; c < 4; c++) random.nextInt(256)];
      // Premultiplied pixels (no channel above the alpha) and a few
      // invalid ones as well.
      if (random.nextInt(8) != 0) {
        for (var c = 0; c < 3; c++) {
          start[c] = math.min(start[c], start[3]);
        }
      }
      now.setAll(0, start);
      before.setAll(0, start);
      mine();
      theirs();
      expect(now, before, reason: '$what from $start');
    }

    final tile = Uint8List(TileManager.tileSize * TileManager.tileSize * 4);
    for (var i = 0; i < 300000; i++) {
      final a = random.nextInt(256);
      final r = random.nextInt(256);
      final g = random.nextInt(256);
      final b = random.nextInt(256);
      final idx = random.nextInt(TileManager.tileSize * TileManager.tileSize);
      final px = idx % TileManager.tileSize, py = idx ~/ TileManager.tileSize;
      void viaTile(void Function() draw) {
        tile.setAll(idx * 4, now);
        draw();
        now.setAll(0, tile.sublist(idx * 4, idx * 4 + 4));
      }

      check(
        'blend $r,$g,$b,$a',
        () => viaTile(() => tiles.blendPixel(tile, px, py, r, g, b, a)),
        () => a <= 0 ? null : _blendBefore(before, 0, r, g, b, a),
      );
      final pa = a, pr = math.min(r, a), pg = math.min(g, a);
      final pb = math.min(b, a);
      check(
        'premultiplied $pr,$pg,$pb,$pa',
        () => viaTile(
          () => tiles.blendPremultipliedPixel(tile, px, py, pr, pg, pb, pa),
        ),
        () => pa <= 0 ? null : _premultipliedBefore(before, 0, pr, pg, pb, pa),
      );
      check(
        'erase $a',
        () => viaTile(() => tiles.erasePixel(tile, px, py, a)),
        () => _eraseBefore(before, 0, a),
      );
    }
  });
}
