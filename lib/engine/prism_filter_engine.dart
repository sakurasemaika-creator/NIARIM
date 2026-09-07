import 'dart:math' as math;
import 'dart:typed_data';

import 'filter_engine.dart';

/// プリズムフィルターのピクセル処理。
///
/// 処理順は仕様どおり次の順序に固定する。
/// 1. 元レイヤーのアルファへ暗い虹色グラデーションをクリッピング
/// 2. 元レイヤーとクリップ済み虹色レイヤーを通常合成して結合
/// 3. 結合結果をガウスぼかし（この段階ではクリッピングしない）
/// 4. ぼかした結果を元レイヤーへ「覆い焼き（リニア）/ Linear Dodge(Add)」で合成
///
/// [blurPx] はガウスぼかし半径の px 数そのもの。
/// [gradientDirectionDegrees] は塗りグラデーションの向きを度数で表す。
/// 0°=左→右、90°=上→下。値は内部で 0〜360° に正規化する。
///
/// ガウスぼかし時にクリッピングを解除する仕様のため、ぼかしによる虹色の
/// にじみは元レイヤーの不透明領域の外側にも広がり得る。
class PrismFilterEngine {
  PrismFilterEngine({FilterEngine? filterEngine})
    : _filterEngine = filterEngine ?? FilterEngine();

  final FilterEngine _filterEngine;

  Uint8List apply(
    Uint8List source,
    int width,
    int height, {
    required double blurPx,
    required double gradientDirectionDegrees,
  }) {
    if (width <= 0 || height <= 0 || source.length != width * height * 4) {
      return Uint8List.fromList(source);
    }

    final clippedGradient = _buildClippedDarkRainbow(
      source,
      width,
      height,
      gradientDirectionDegrees,
    );
    final merged = _normalMerge(source, clippedGradient);

    // blurPx は既存のガウスぼかしと同じ「px数」としてそのまま渡す。
    // 0px は実質無効として結合結果をそのまま使用する。
    final blurred = blurPx <= 0
        ? merged
        : _filterEngine.applyGaussianBlur(
            merged,
            width,
            height,
            blurPx,
          );

    return _linearDodge(source, blurred);
  }

  Uint8List _buildClippedDarkRainbow(
    Uint8List source,
    int width,
    int height,
    double directionDegrees,
  ) {
    final out = Uint8List(source.length);
    final radians = _normalizeDegrees(directionDegrees) * math.pi / 180.0;
    final dx = math.cos(radians);
    final dy = math.sin(radians);

    // 画像四隅を方向ベクトルへ射影した最小・最大値を使うことで、どの角度でも
    // グラデーションがキャンバス全体を端から端まで使う。
    final maxX = math.max(0, width - 1).toDouble();
    final maxY = math.max(0, height - 1).toDouble();
    final projections = <double>[
      0.0,
      maxX * dx,
      maxY * dy,
      maxX * dx + maxY * dy,
    ];
    final minProjection = projections.reduce(math.min);
    final maxProjection = projections.reduce(math.max);
    final span = math.max(1e-9, maxProjection - minProjection).toDouble();

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final sourceAlpha = source[i + 3];
        if (sourceAlpha == 0) continue;

        final projection = x * dx + y * dy;
        final t = ((projection - minProjection) / span)
            .clamp(0.0, 1.0)
            .toDouble();
        final rgb = _darkRainbowAt(t);
        out[i] = rgb.$1;
        out[i + 1] = rgb.$2;
        out[i + 2] = rgb.$3;
        // クリッピングは元レイヤーのアルファをそのままマスクとして使用する。
        out[i + 3] = sourceAlpha;
      }
    }
    return out;
  }

  Uint8List _normalMerge(Uint8List base, Uint8List overlay) {
    final out = Uint8List(base.length);
    for (var i = 0; i < base.length; i += 4) {
      final ba = base[i + 3] / 255.0;
      final oa = overlay[i + 3] / 255.0;
      final outA = oa + ba * (1.0 - oa);
      if (outA <= 0) continue;

      out[i] = _clampByte(
        ((overlay[i] * oa) + (base[i] * ba * (1.0 - oa))) / outA,
      );
      out[i + 1] = _clampByte(
        ((overlay[i + 1] * oa) + (base[i + 1] * ba * (1.0 - oa))) / outA,
      );
      out[i + 2] = _clampByte(
        ((overlay[i + 2] * oa) + (base[i + 2] * ba * (1.0 - oa))) / outA,
      );
      out[i + 3] = _clampByte(outA * 255.0);
    }
    return out;
  }

  Uint8List _linearDodge(Uint8List base, Uint8List effect) {
    final out = Uint8List(base.length);
    for (var i = 0; i < base.length; i += 4) {
      final ba = base[i + 3] / 255.0;
      final ea = effect[i + 3] / 255.0;
      final outA = ea + ba * (1.0 - ea);
      if (outA <= 0) continue;

      // Linear Dodge(Add): RGB は加算。effect 側はアルファで寄与量を制御する。
      out[i] = _clampByte(base[i] + effect[i] * ea);
      out[i + 1] = _clampByte(base[i + 1] + effect[i + 1] * ea);
      out[i + 2] = _clampByte(base[i + 2] + effect[i + 2] * ea);
      out[i + 3] = _clampByte(outA * 255.0);
    }
    return out;
  }

  /// 明るすぎるネオン虹ではなく、覆い焼きリニアで持ち上げたときに
  /// 色が残るよう意図的に低明度へ寄せた虹色。
  (int, int, int) _darkRainbowAt(double t) {
    const stops = <(double, int, int, int)>[
      (0.00, 92, 18, 38),
      (0.17, 104, 48, 16),
      (0.33, 86, 78, 12),
      (0.50, 18, 82, 46),
      (0.67, 14, 60, 96),
      (0.83, 48, 30, 104),
      (1.00, 92, 18, 72),
    ];

    final v = t.clamp(0.0, 1.0).toDouble();
    for (var i = 0; i < stops.length - 1; i++) {
      final a = stops[i];
      final b = stops[i + 1];
      if (v > b.$1) continue;
      final local = ((v - a.$1) / (b.$1 - a.$1))
          .clamp(0.0, 1.0)
          .toDouble();
      return (
        _lerpChannel(a.$2, b.$2, local),
        _lerpChannel(a.$3, b.$3, local),
        _lerpChannel(a.$4, b.$4, local),
      );
    }
    final last = stops.last;
    return (last.$2, last.$3, last.$4);
  }

  int _lerpChannel(int a, int b, double t) =>
      _clampByte(a + (b - a) * t);

  int _clampByte(num value) => value.round().clamp(0, 255).toInt();

  double _normalizeDegrees(double value) {
    final normalized = value % 360.0;
    return normalized < 0 ? normalized + 360.0 : normalized;
  }
}
