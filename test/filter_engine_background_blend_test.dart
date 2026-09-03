import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// FilterEngine.applyBackgroundBlend／mostFrequentOpaqueColor
/// （背景馴染ませフィルター、Task#162）の単体テスト。
void main() {
  final engine = FilterEngine();

  group('mostFrequentOpaqueColor', () {
    test('不透明画素が1つも無い場合はnullを返す', () {
      final data = Uint8List(4 * 4 * 4); // 全画素アルファ0
      expect(FilterEngine.mostFrequentOpaqueColor(data), isNull);
    });

    test('最も多い色を検出する（透明画素は無視する）', () {
      const width = 4, height = 4;
      final data = Uint8List(width * height * 4);
      for (int i = 0; i < width * height; i++) {
        final idx = i * 4;
        if (i < 12) {
          // 12画素は赤。
          data[idx] = 255;
          data[idx + 1] = 0;
          data[idx + 2] = 0;
          data[idx + 3] = 255;
        } else if (i < 15) {
          // 3画素は青。
          data[idx] = 0;
          data[idx + 1] = 0;
          data[idx + 2] = 255;
          data[idx + 3] = 255;
        } else {
          // 残り1画素は透明（無視されるはず）。
          data[idx + 3] = 0;
        }
      }
      final result = FilterEngine.mostFrequentOpaqueColor(data)!;
      expect((result >> 16) & 0xFF, 255); // R
      expect((result >> 8) & 0xFF, 0); // G
      expect(result & 0xFF, 0); // B
    });
  });

  group('applyBackgroundBlend', () {
    const width = 20, height = 20;
    const blendColor = 0xFF00FF00; // 緑

    Uint8List buildSquare() {
      final data = Uint8List(width * height * 4);
      for (int y = 5; y <= 14; y++) {
        for (int x = 5; x <= 14; x++) {
          final idx = (y * width + x) * 4;
          data[idx] = 100;
          data[idx + 1] = 100;
          data[idx + 2] = 100;
          data[idx + 3] = 255;
        }
      }
      return data;
    }

    (int, int, int) pixelAt(Uint8List data, int x, int y) {
      final idx = (y * width + x) * 4;
      return (data[idx], data[idx + 1], data[idx + 2]);
    }

    test('透明画素（アルファ0）は変化しない', () {
      final data = buildSquare();
      final result = engine.applyBackgroundBlend(
        data,
        width,
        height,
        blendColor,
        0,
        3,
        0,
      );
      // 完全に外側（形の外）の透明画素を確認する。
      const idx = (0 * width + 0) * 4;
      expect(result[idx], data[idx]);
      expect(result[idx + 1], data[idx + 1]);
      expect(result[idx + 2], data[idx + 2]);
      expect(result[idx + 3], data[idx + 3]); // アルファも不変
    });

    test('輪郭から十分離れた中心画素は変化しない', () {
      final data = buildSquare();
      final result = engine.applyBackgroundBlend(
        data,
        width,
        height,
        blendColor,
        0,
        3,
        0,
      );
      // 正方形は5..14、中心付近(9,9)は上下左右とも輪郭までlengthより離れている。
      expect(pixelAt(result, 9, 9), pixelAt(data, 9, 9));
    });

    test('向き0°（+x方向）では、+x側の輪郭付近が明るく（光）、-x側が暗く（影）なる', () {
      final data = buildSquare();
      final result = engine.applyBackgroundBlend(
        data,
        width,
        height,
        blendColor,
        0,
        3,
        0,
      );
      // 右端(x=13, 光が当たる側)は明るくなる＝輝度が元より上がるはず。
      final (r1, g1, b1) = pixelAt(result, 13, 9);
      final (or1, og1, ob1) = pixelAt(data, 13, 9);
      expect(r1 + g1 + b1, greaterThan(or1 + og1 + ob1));
      // 左端(x=6, 影になる側)は暗くなる＝輝度が元より下がるはず。
      final (r2, g2, b2) = pixelAt(result, 6, 9);
      final (or2, og2, ob2) = pixelAt(data, 6, 9);
      expect(r2 + g2 + b2, lessThan(or2 + og2 + ob2));
    });

    test('向きを180°反転すると、光と影の側も入れ替わる（連動）', () {
      final data = buildSquare();
      final at0 = engine.applyBackgroundBlend(
        data,
        width,
        height,
        blendColor,
        0,
        3,
        0,
      );
      final at180 = engine.applyBackgroundBlend(
        data,
        width,
        height,
        blendColor,
        180,
        3,
        0,
      );
      // 0°で明るかった右端(13,9)は、180°では暗くなるはず。
      final (r0, g0, b0) = pixelAt(at0, 13, 9);
      final (r180, g180, b180) = pixelAt(at180, 13, 9);
      expect(r180 + g180 + b180, lessThan(r0 + g0 + b0));
    });

    test('lengthを大きくするほど影響範囲が広がる', () {
      final data = buildSquare();
      final shortLength = engine.applyBackgroundBlend(
        data,
        width,
        height,
        blendColor,
        0,
        1,
        0,
      );
      final longLength = engine.applyBackgroundBlend(
        data,
        width,
        height,
        blendColor,
        0,
        8,
        0,
      );
      // 中心(9,9)はlength=1では無変化のはずだが、length=8では影響を受けるはず。
      expect(pixelAt(shortLength, 9, 9), pixelAt(data, 9, 9));
      expect(pixelAt(longLength, 9, 9), isNot(pixelAt(data, 9, 9)));
    });
  });
}
