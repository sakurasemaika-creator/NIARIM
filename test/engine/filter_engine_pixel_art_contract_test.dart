import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/pixel_art_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

void main() {
  // 色を指定しない（元の色のまま）では、斜めに交わる2色の間にも絵に無い
  // 中間の色を作らない。描画フィルターは共通のドット絵の決まりをそのまま使う。
  test('applyPixelate uses the shared diagonal pixel-art contract', () {
    final input = Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      0,
      255,
      255,
      0,
      0,
      255,
      255,
      255,
      0,
      0,
      255,
    ]);
    final out = FilterEngine().applyPixelate(
      input,
      2,
      2,
      mosaicSize: 1,
      colorMode: PixelColorMode.none,
    );
    final shared = const PixelArtEngine().convert(
      input,
      2,
      2,
      pixelSize: 1,
      colorMode: PixelColorMode.none,
    );
    expect(out, shared);
    expect(out.sublist(4, 7), [0, 0, 255]);
    expect([out[3], out[7], out[11], out[15]], [255, 255, 255, 255]);
  });

  test('pixel-art contract keeps transparent exterior hard', () {
    final input = Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      255,
      255,
      0,
      0,
      255,
    ]);
    final out = FilterEngine().applyPixelate(input, 2, 2, mosaicSize: 1);
    expect([out[3], out[7], out[11], out[15]], [255, 0, 255, 255]);
  });
}
