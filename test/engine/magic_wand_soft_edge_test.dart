// 自動選択は、選んだ色の柔らかい縁（ペンのアンチエイリアス）も選択に入れる。
//
// 実際に使ってみたとき（2026-11-27）、自動選択で選んだボールを動かす・縮める
// と、元の場所に薄い輪が残った（縁の半透明の画素が選択に入っていなかった）。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/bucket_fill_engine.dart';

void main() {
  const w = 40, h = 20;

  // A 10x10 square (x 10..19, y 5..14) of [inner], a ring of [ring1] one pixel
  // out and [ring2] two pixels out, on [outside]. Colours are premultiplied
  // RGBA, as the canvas reads them.
  Uint8List canvas(
    List<int> inner,
    List<int> ring1,
    List<int> ring2,
    List<int> outside,
  ) {
    final c = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final ring = [
          (x - 14.5).abs(),
          (y - 9.5).abs(),
        ].reduce((a, b) => a > b ? a : b);
        final colour = ring < 5
            ? inner
            : ring < 6
            ? ring1
            : ring < 7
            ? ring2
            : outside;
        c.setAll((y * w + x) * 4, colour);
      }
    }
    return c;
  }

  Uint8List select(Uint8List c) => BucketFillEngine().selectionMask(
    canvasData: c,
    width: w,
    height: h,
    startX: 14,
    startY: 9,
  );

  int at(Uint8List mask, int x, int y) => mask[y * w + x];

  test('the semi-transparent edge on a transparent layer is selected', () {
    // Red, its edge at 60% and 20% (premultiplied), then nothing.
    final mask = select(
      canvas(
        [220, 30, 30, 255],
        [132, 18, 18, 153],
        [44, 6, 6, 51],
        [0, 0, 0, 0],
      ),
    );
    expect(at(mask, 9, 9), 1, reason: 'first ring');
    expect(at(mask, 8, 9), 1, reason: 'second ring');
    expect(at(mask, 7, 9), 0, reason: 'the empty layer around it');
    expect(at(mask, 0, 0), 0);
  });

  test('the edge mixed with the paper is selected, the paper is not', () {
    // Red on white with a 2-pixel blend.
    final mask = select(
      canvas(
        [220, 30, 30, 255],
        [233, 128, 128, 255],
        [246, 220, 220, 255],
        [255, 255, 255, 255],
      ),
    );
    expect(at(mask, 9, 9), 1);
    expect(at(mask, 8, 9), 1);
    expect(at(mask, 7, 9), 0);
    expect(at(mask, 30, 10), 0);
  });

  test('a hard edge against another colour stays out', () {
    final mask = select(
      canvas(
        [220, 30, 30, 255],
        [30, 60, 220, 255],
        [30, 60, 220, 255],
        [30, 60, 220, 255],
      ),
    );
    expect(at(mask, 10, 9), 1);
    expect(at(mask, 9, 9), 0);
  });

  test('softEdge: false keeps the flood as it was', () {
    final mask = BucketFillEngine().selectionMask(
      canvasData: canvas(
        [220, 30, 30, 255],
        [132, 18, 18, 153],
        [44, 6, 6, 51],
        [0, 0, 0, 0],
      ),
      width: w,
      height: h,
      startX: 14,
      startY: 9,
      softEdge: false,
    );
    expect(at(mask, 10, 9), 1);
    expect(at(mask, 9, 9), 0);
  });
}
