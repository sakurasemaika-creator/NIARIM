import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

/// quantizeColors（ブラシのピクセルモード配色・ドット絵フィルター共通の
/// 減色関数）の単体テスト。Task#151の回帰テスト。
void main() {
  /// [r],[g],[b],[a]の単色4画素分のRGBAデータを作る。
  Uint8List solidPixels(int r, int g, int b, int a, {int count = 4}) {
    final data = Uint8List(count * 4);
    for (int i = 0; i < count; i++) {
      data[i * 4] = r;
      data[i * 4 + 1] = g;
      data[i * 4 + 2] = b;
      data[i * 4 + 3] = a;
    }
    return data;
  }

  group('PixelColorMode.none', () {
    test('元の画素をそのまま返す', () {
      final data = solidPixels(123, 45, 200, 255);
      final result = quantizeColors(data, colorMode: PixelColorMode.none);
      expect(result, equals(data));
    });
  });

  group('PixelColorMode.count', () {
    test('指定色数以内の共通PixelArt paletteへ減色される', () {
      final data = Uint8List.fromList([
        12, 12, 12, 255,
        80, 80, 80, 255,
        170, 170, 170, 255,
        245, 245, 245, 255,
      ]);
      final result = quantizeColors(
        data,
        colorMode: PixelColorMode.count,
        colorLevels: 2,
      );
      final colors = <int>{};
      for (var i = 0; i < result.length; i += 4) {
        colors.add((result[i] << 16) | (result[i + 1] << 8) | result[i + 2]);
      }
      expect(colors.length, lessThanOrEqualTo(2));
    });

    test('透明画素（alpha=0）は変化しない', () {
      final data = solidPixels(130, 130, 130, 0);
      final result = quantizeColors(
        data,
        colorMode: PixelColorMode.count,
        colorLevels: 2,
      );
      expect(result, equals(data));
    });

    test('colorLevels=256はほぼ元の値のまま（1刻み）', () {
      final data = solidPixels(77, 200, 5, 255);
      final result = quantizeColors(
        data,
        colorMode: PixelColorMode.count,
        colorLevels: 256,
      );
      expect(result[0], 77);
      expect(result[1], 200);
      expect(result[2], 5);
    });
  });

  group('PixelColorMode.explicit / palette', () {
    test('最も近いパレット色へスナップする（黒寄りの画素は黒になる）', () {
      final data = solidPixels(30, 30, 30, 255); // 黒に近い暗色
      final result = quantizeColors(
        data,
        colorMode: PixelColorMode.explicit,
        paletteColors: const [0xFF000000, 0xFFFFFFFF],
      );
      expect(result[0], 0);
      expect(result[1], 0);
      expect(result[2], 0);
    });

    test('白寄りの画素は白になる', () {
      final data = solidPixels(220, 220, 220, 255);
      final result = quantizeColors(
        data,
        colorMode: PixelColorMode.explicit,
        paletteColors: const [0xFF000000, 0xFFFFFFFF],
      );
      expect(result[0], 255);
      expect(result[1], 255);
      expect(result[2], 255);
    });

    test('paletteが空の場合は何もしない', () {
      final data = solidPixels(30, 30, 30, 255);
      final result = quantizeColors(
        data,
        colorMode: PixelColorMode.explicit,
        paletteColors: const [],
      );
      expect(result, equals(data));
    });

    test('透明画素（alpha=0）はスナップされない', () {
      final data = solidPixels(30, 30, 30, 0);
      final result = quantizeColors(
        data,
        colorMode: PixelColorMode.explicit,
        paletteColors: const [0xFF000000, 0xFFFFFFFF],
      );
      expect(result, equals(data));
    });

    test('palette（PixelColorMode.palette）もexplicitと同じロジックで動く', () {
      final data = solidPixels(220, 220, 220, 255);
      final result = quantizeColors(
        data,
        colorMode: PixelColorMode.palette,
        paletteColors: const [0xFF000000, 0xFFFFFFFF],
      );
      expect(result[0], 255);
    });
  });

  group('FilterEngine.applyPixelate（Pixel Art＋配色）', () {
    test('mosaicSize=1・colorMode=noneでは色は変化しない', () {
      final engine = FilterEngine();
      final data = solidPixels(77, 200, 5, 255, count: 16); // 4x4画像を想定
      final result = engine.applyPixelate(
        data,
        4,
        4,
        mosaicSize: 1,
        colorMode: PixelColorMode.none,
      );
      expect(result, equals(data));
    });
  });
}
