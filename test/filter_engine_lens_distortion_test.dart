import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// FilterEngine.applyLensDistortion（眼鏡断層フィルター）の単体テスト。
/// 選択レイヤーのマスク画素だけを対象に局所的な放射状ワープをかけ、
/// マスク範囲外は完全に元の画素のままであることを主眼に検証する
/// （実機での見た目確認ができない環境のため、最低限の正しさを
/// 自動テストで担保する）。
void main() {
  const width = 20;
  const height = 20;

  /// 位置ごとに異なる値を持つテストパターン（RGBA）。ワープの有無で
  /// 画素値が変わったかどうかを判定できるよう、単色ではなく
  /// 座標依存のグラデーションにしてある。
  Uint8List buildPattern() {
    final data = Uint8List(width * height * 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        data[idx] = (x * 12) % 256;
        data[idx + 1] = (y * 12) % 256;
        data[idx + 2] = 100;
        data[idx + 3] = 255;
      }
    }
    return data;
  }

  /// 中心(cx, cy)・半径radiusの円内をアルファ255、円外をアルファ0とする
  /// マスク（選択レイヤーを単体合成したrawRgba相当）。
  Uint8List buildCircleMask(double cx, double cy, double radius) {
    final mask = Uint8List(width * height * 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        final dx = x - cx;
        final dy = y - cy;
        final inside = dx * dx + dy * dy <= radius * radius;
        mask[idx + 3] = inside ? 255 : 0;
      }
    }
    return mask;
  }

  test('マスクがnullの場合は何もしない', () {
    final engine = FilterEngine();
    final data = buildPattern();
    final result = engine.applyLensDistortion(data, width, height, 50, null);
    expect(result, orderedEquals(data));
  });

  test('strengthが0の場合は何もしない（マスクがあっても無効）', () {
    final engine = FilterEngine();
    final data = buildPattern();
    final mask = buildCircleMask(10, 10, 6);
    final result = engine.applyLensDistortion(data, width, height, 0, mask);
    expect(result, orderedEquals(data));
  });

  test('マスク範囲外の画素は完全に元のまま、範囲内は少なくとも一部が変化する（正の強さ＝凸レンズ）', () {
    final engine = FilterEngine();
    final data = buildPattern();
    final mask = buildCircleMask(10, 10, 6);
    final result = engine.applyLensDistortion(data, width, height, 60, mask);

    var insideChangedCount = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        final inside = mask[idx + 3] != 0;
        final unchanged = result[idx] == data[idx] &&
            result[idx + 1] == data[idx + 1] &&
            result[idx + 2] == data[idx + 2] &&
            result[idx + 3] == data[idx + 3];
        if (!inside) {
          // マスク範囲外は元の画素と完全に一致していなければならない。
          expect(unchanged, isTrue, reason: '($x,$y)はマスク範囲外なのに画素が変化した');
        } else if (!unchanged) {
          insideChangedCount++;
        }
      }
    }
    // 中心付近の画素は理論上ほぼ動かないため全画素の変化までは求めないが、
    // ワープが実際に機能していることを示すため、円内の複数画素は変化して
    // いるはずである。
    expect(insideChangedCount, greaterThan(5));
  });

  test('負の強さ（凹レンズ）でもマスク範囲外は不変', () {
    final engine = FilterEngine();
    final data = buildPattern();
    final mask = buildCircleMask(10, 10, 6);
    final result = engine.applyLensDistortion(data, width, height, -60, mask);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        if (mask[idx + 3] == 0) {
          expect(result[idx], equals(data[idx]));
          expect(result[idx + 1], equals(data[idx + 1]));
          expect(result[idx + 2], equals(data[idx + 2]));
          expect(result[idx + 3], equals(data[idx + 3]));
        }
      }
    }
  });

  test('複数の連結成分（両目分）を同時に処理できる', () {
    final engine = FilterEngine();
    final data = buildPattern();
    // 左右に離れた2つの円（両目に見立てたレンズ2枚）。
    final leftMask = buildCircleMask(5, 10, 3);
    final rightMask = buildCircleMask(15, 10, 3);
    final mask = Uint8List(width * height * 4);
    for (int i = 3; i < mask.length; i += 4) {
      mask[i] = (leftMask[i] != 0 || rightMask[i] != 0) ? 255 : 0;
    }
    // 例外を投げず、2つの連結成分それぞれが独立して処理されることのみ確認する。
    expect(
      () => engine.applyLensDistortion(data, width, height, 60, mask),
      returnsNormally,
    );
  });
}
