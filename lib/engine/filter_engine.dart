import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/effect_filter_instance.dart';
import '../models/filter_def.dart';

/// 描画フィルターの本適用（低スペック端末でのUIスレッドブロック防止のため
/// compute()経由でバックグラウンドisolate実行する想定のトップレベル関数）。
Uint8List applyDrawFilterInIsolate(
    (Uint8List data, int width, int height, FilterDef filter) args) {
  final (data, width, height, filter) = args;
  final engine = FilterEngine();
  return switch (filter.kind) {
    FilterKind.gaussianBlur => engine.applyGaussianBlur(data, width, height, filter.strength),
    FilterKind.lensBlur => engine.applyLensBlur(data, width, height, filter.strength),
    FilterKind.animeStyle => engine.applyAnimeStyle(
        data,
        width,
        height,
        strength: filter.strength,
        colorCount: filter.colorLevels,
        edgeStrength: filter.edgeStrength,
      ),
    // 本適用は選択レイヤーを書き換えず新規レイヤーへ縁取りリングのみを
    // 描画するため、applyOutline（元の描画内容を保持した合成結果。
    // プレビュー専用）ではなくapplyOutlineLayer（リング部分のみ）を使う。
    FilterKind.outline => engine.applyOutlineLayer(
        data,
        width,
        height,
        color: filter.outlineColor,
        widthPx: filter.outlineWidth,
      ),
    FilterKind.toneCurve => engine.applyToneCurve(
        data, width, height, toneCurvePoints(filter.toneCurvePreset)),
    FilterKind.levels => engine.applyLevels(
        data, width, height,
        inputBlack: filter.inputBlack,
        inputWhite: filter.inputWhite,
        outputBlack: filter.outputBlack,
        outputWhite: filter.outputWhite,
      ),
    FilterKind.sharpen => engine.applySharpen(data, width, height, filter.strength),
    FilterKind.unsharpMask =>
      engine.applyUnsharpMask(data, width, height, filter.strength, filter.edgeStrength),
  };
}

/// トーンカーブのプリセット形状を制御点（0.0〜1.0の正規化座標）へ変換する
/// （仕様書20：トーンカーブ。プレビュー・本適用の両方から共通利用する）。
List<ui.Offset> toneCurvePoints(ToneCurvePreset preset) {
  return switch (preset) {
    ToneCurvePreset.linear => const [ui.Offset(0, 0), ui.Offset(1, 1)],
    ToneCurvePreset.brighten => const [ui.Offset(0, 0), ui.Offset(0.5, 0.65), ui.Offset(1, 1)],
    ToneCurvePreset.darken => const [ui.Offset(0, 0), ui.Offset(0.5, 0.35), ui.Offset(1, 1)],
    ToneCurvePreset.highContrast =>
      const [ui.Offset(0, 0), ui.Offset(0.25, 0.15), ui.Offset(0.75, 0.85), ui.Offset(1, 1)],
    ToneCurvePreset.lowContrast =>
      const [ui.Offset(0, 0.15), ui.Offset(0.5, 0.5), ui.Offset(1, 0.85)],
    ToneCurvePreset.invert => const [ui.Offset(0, 1), ui.Offset(1, 0)],
  };
}

class FilterEngine {
  /// タイムラインの演出フィルター一覧を、[frameIndex]が範囲内かつ有効なものだけ、
  /// タイムライン上の並び順（[effects]の順）に適用する（仕様書18：演出フィルター）。
  Uint8List applyEffectFilters(
    Uint8List data,
    int width,
    int height,
    List<EffectFilterInstance> effects,
    int frameIndex,
  ) {
    var result = data;
    for (final e in effects) {
      if (!e.enabled || frameIndex < e.startFrame || frameIndex > e.endFrame) continue;
      result = switch (e.type) {
        EffectFilterType.fade => applyFade(
            result,
            width,
            height,
            e.fadeColor,
            e.endFrame > e.startFrame
                ? (frameIndex - e.startFrame) / (e.endFrame - e.startFrame)
                : 1.0,
          ),
        EffectFilterType.gaussianBlur => applyGaussianBlur(result, width, height, e.param1),
        EffectFilterType.lensBlur => applyLensBlur(result, width, height, e.param1),
        EffectFilterType.mosaic => applyMosaic(result, width, height, e.param1.round()),
        EffectFilterType.chromaticAberration =>
          applyChromaticAberration(result, width, height, e.param1, 0),
        EffectFilterType.noise =>
          applyNoise(result, width, height, (e.param1 / 20).clamp(0.0, 1.0), NoiseType.gaussian),
      };
    }
    return result;
  }
  Uint8List applyGaussianBlur(Uint8List data, int width, int height, double strength) {
    final radius = strength.round().clamp(1, 20);
    final kernel = _gaussianKernel(radius);
    final tmp = _convolveH(data, width, height, kernel);
    return _convolveV(tmp, width, height, kernel);
  }

  /// シャープ化：3x3の固定小カーネルによる畳み込み（負荷はガウスぼかし
  /// 半径1回分よりさらに軽い）。[strength]は0〜100（%）で、カーネルの
  /// かかり具合を調整する。中心画素の重みを上げ、上下左右の重みを下げる
  /// 古典的なシャープカーネルの応用。アルファは変化させない（線画の輪郭を
  /// 崩さないため）。
  Uint8List applySharpen(Uint8List data, int width, int height, double strength) {
    final amount = (strength / 100.0).clamp(0.0, 2.0);
    if (amount <= 0) return Uint8List.fromList(data);
    final result = Uint8List.fromList(data);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        if (data[idx + 3] == 0) continue;
        for (int c = 0; c < 3; c++) {
          final center = data[idx + c];
          double sum = 0;
          int n = 0;
          if (y > 0) { sum += data[((y - 1) * width + x) * 4 + c]; n++; }
          if (y < height - 1) { sum += data[((y + 1) * width + x) * 4 + c]; n++; }
          if (x > 0) { sum += data[(y * width + x - 1) * 4 + c]; n++; }
          if (x < width - 1) { sum += data[(y * width + x + 1) * 4 + c]; n++; }
          final neighborAvg = n > 0 ? sum / n : center.toDouble();
          final sharpened = center + amount * (center - neighborAvg);
          result[idx + c] = sharpened.round().clamp(0, 255);
        }
      }
    }
    return result;
  }

  /// アンシャープマスク：元画像からガウスぼかし版を引いた差分（＝輪郭付近の
  /// 高周波成分）を[amount]倍して元画像へ加算する、写真編集ソフトでも定番の
  /// シャープ化手法。内部で使うガウスぼかしは既存のapplyGaussianBlurと同じ
  /// 実装のため、負荷はガウスぼかしフィルター1回分＋差分計算のみで軽い。
  /// [radiusStrength]はぼかし半径（px、1〜20。gaussianBlurと同じ意味）、
  /// [amount]はかかり具合（0.0〜3.0程度、既定1.0）。
  Uint8List applyUnsharpMask(Uint8List data, int width, int height, double radiusStrength, double amount) {
    final blurred = applyGaussianBlur(data, width, height, radiusStrength);
    final result = Uint8List.fromList(data);
    for (int i = 0; i < data.length; i += 4) {
      if (data[i + 3] == 0) continue;
      for (int c = 0; c < 3; c++) {
        final orig = data[i + c];
        final blur = blurred[i + c];
        final sharpened = orig + amount * (orig - blur);
        result[i + c] = sharpened.round().clamp(0, 255);
      }
    }
    return result;
  }

  Uint8List applyLensBlur(Uint8List data, int width, int height, double strength) {
    // レンズぼかし = 円形カーネルによるボックスブラー近似
    final radius = strength.round().clamp(1, 20);
    final result = Uint8List.fromList(data);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int r = 0, g = 0, b = 0, a = 0, count = 0;
        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            if (dx * dx + dy * dy > radius * radius) continue;
            final nx = (x + dx).clamp(0, width - 1);
            final ny = (y + dy).clamp(0, height - 1);
            final idx = (ny * width + nx) * 4;
            r += data[idx]; g += data[idx + 1];
            b += data[idx + 2]; a += data[idx + 3];
            count++;
          }
        }
        if (count == 0) continue;
        final idx = (y * width + x) * 4;
        result[idx] = (r / count).round();
        result[idx + 1] = (g / count).round();
        result[idx + 2] = (b / count).round();
        result[idx + 3] = (a / count).round();
      }
    }
    return result;
  }

  Uint8List applyMosaic(Uint8List data, int width, int height, int mosaicSize) {
    final size = mosaicSize.clamp(2, 64);
    final result = Uint8List.fromList(data);
    for (int y = 0; y < height; y += size) {
      for (int x = 0; x < width; x += size) {
        int r = 0, g = 0, b = 0, a = 0, count = 0;
        for (int dy = 0; dy < size && y + dy < height; dy++) {
          for (int dx = 0; dx < size && x + dx < width; dx++) {
            final idx = ((y + dy) * width + (x + dx)) * 4;
            r += data[idx]; g += data[idx + 1];
            b += data[idx + 2]; a += data[idx + 3];
            count++;
          }
        }
        if (count == 0) continue;
        final ar = (r / count).round();
        final ag = (g / count).round();
        final ab = (b / count).round();
        final aa = (a / count).round();
        for (int dy = 0; dy < size && y + dy < height; dy++) {
          for (int dx = 0; dx < size && x + dx < width; dx++) {
            final idx = ((y + dy) * width + (x + dx)) * 4;
            result[idx] = ar; result[idx + 1] = ag;
            result[idx + 2] = ab; result[idx + 3] = aa;
          }
        }
      }
    }
    return result;
  }

  Uint8List applyChromaticAberration(
      Uint8List data, int width, int height, double strength, double direction) {
    final shift = strength.round().clamp(1, 30);
    final dx = (math.cos(direction) * shift).round();
    final dy = (math.sin(direction) * shift).round();
    final result = Uint8List.fromList(data);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        // Rチャンネルをdx,dyずらす
        final rx = (x + dx).clamp(0, width - 1);
        final ry = (y + dy).clamp(0, height - 1);
        result[idx] = data[(ry * width + rx) * 4];
        // Bチャンネルを逆方向にずらす
        final bx = (x - dx).clamp(0, width - 1);
        final by = (y - dy).clamp(0, height - 1);
        result[idx + 2] = data[(by * width + bx) * 4 + 2];
      }
    }
    return result;
  }

  Uint8List applyNoise(Uint8List data, int width, int height, double strength, NoiseType type) {
    final result = Uint8List.fromList(data);
    final rng = math.Random();
    final s = (strength * 255).round().clamp(0, 255);
    for (int i = 0; i < result.length; i += 4) {
      if (result[i + 3] == 0) continue;
      final n = type == NoiseType.gaussian
          ? (_gaussianRandom(rng) * s).round().clamp(-s, s)
          : (rng.nextInt(s * 2 + 1) - s);
      result[i] = (result[i] + n).clamp(0, 255);
      result[i + 1] = (result[i + 1] + n).clamp(0, 255);
      result[i + 2] = (result[i + 2] + n).clamp(0, 255);
    }
    return result;
  }

  Uint8List applyAnimeStyle(Uint8List data, int width, int height, {
    required double strength,
    required int colorCount,
    required double edgeStrength,
  }) {
    // ① 色数削減（ポスタリゼーション）
    final step = (256 / colorCount.clamp(2, 32)).round();
    final posterized = Uint8List.fromList(data);
    for (int i = 0; i < posterized.length; i += 4) {
      posterized[i] = ((posterized[i] / step).round() * step).clamp(0, 255);
      posterized[i + 1] = ((posterized[i + 1] / step).round() * step).clamp(0, 255);
      posterized[i + 2] = ((posterized[i + 2] / step).round() * step).clamp(0, 255);
    }
    // ② エッジ検出（Sobelフィルタ）して輪郭を黒く
    if (edgeStrength > 0) {
      final edges = _sobelEdge(data, width, height);
      for (int i = 0; i < posterized.length; i += 4) {
        final e = (edges[i ~/ 4] * edgeStrength).clamp(0, 255).round();
        posterized[i] = (posterized[i] - e).clamp(0, 255);
        posterized[i + 1] = (posterized[i + 1] - e).clamp(0, 255);
        posterized[i + 2] = (posterized[i + 2] - e).clamp(0, 255);
      }
    }
    return posterized;
  }

  /// 縁取りフィルター（プレビュー・単一レイヤー合成用）：選択レイヤーの
  /// 描画内容（不透明部分）はそのまま残し、その周囲へ指定色・指定px幅の
  /// 縁取りを重ねた画像を返す。プレビューサムネイルの生成にのみ使用する
  /// （実際の本適用は、選択レイヤーを書き換えずリング部分だけを新規
  /// レイヤーへ描画するため[applyOutlineLayer]を使う）。
  Uint8List applyOutline(Uint8List data, int width, int height, {
    required int color,
    required double widthPx,
  }) => _outlineFill(data, width, height, color: color, widthPx: widthPx, keepSource: true);

  /// 縁取りフィルター（本適用用）：選択レイヤーの描画内容はコピーせず、
  /// 縁取りリング部分だけを描画した画像（それ以外は透明）を返す。
  /// ユーザー指示「選択中のレイヤーとは別に縁どった内容は新規レイヤーに
  /// 描画してください」を受け、選択レイヤーの直下へ挿入する新規レイヤーの
  /// ピクセルデータとして使う（filter_panel.dartの`_applyToFrame`参照）。
  Uint8List applyOutlineLayer(Uint8List data, int width, int height, {
    required int color,
    required double widthPx,
  }) => _outlineFill(data, width, height, color: color, widthPx: widthPx, keepSource: false);

  /// 縁取り計算の共通処理。[keepSource]がtrueなら元の不透明画素をそのまま
  /// 結果へコピーする（[applyOutline]）。falseなら縁取りリング部分だけを
  /// 書き込み、それ以外は透明のまま返す（[applyOutlineLayer]）。
  /// いずれも元画像側で不透明だった画素はリングの対象から除外するため、
  /// 元の描画内容の上にリングが重なって隠すことはない。
  /// [color]はARGB32形式のint値（FilterDef.outlineColorと同じ表現）。
  Uint8List _outlineFill(Uint8List data, int width, int height, {
    required int color,
    required double widthPx,
    required bool keepSource,
  }) {
    final radius = widthPx.round().clamp(1, 100);
    final result = keepSource ? Uint8List.fromList(data) : Uint8List(data.length);
    final ca = (color >> 24) & 0xFF;
    final cr = (color >> 16) & 0xFF;
    final cg = (color >> 8) & 0xFF;
    final cb = color & 0xFF;
    const alphaThreshold = 10;

    // 元画像の不透明部分のバウンディングボックスを求め、縁取り半径分広げた
    // 範囲だけを探索する（全画面を毎回スキャンする無駄を避けるための最適化）。
    int minX = width, minY = height, maxX = -1, maxY = -1;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (data[(y * width + x) * 4 + 3] > alphaThreshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return result; // 描画内容が無い場合は何もしない

    final startX = (minX - radius).clamp(0, width - 1);
    final endX = (maxX + radius).clamp(0, width - 1);
    final startY = (minY - radius).clamp(0, height - 1);
    final endY = (maxY + radius).clamp(0, height - 1);
    final r2 = radius * radius;

    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        final idx = (y * width + x) * 4;
        if (data[idx + 3] > alphaThreshold) continue; // 元々の描画部分は保持
        bool hit = false;
        for (int dy = -radius; dy <= radius && !hit; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          final dxMax2 = r2 - dy * dy;
          if (dxMax2 < 0) continue;
          final dxMax = math.sqrt(dxMax2).floor();
          final rowBase = ny * width;
          for (int dx = -dxMax; dx <= dxMax; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            if (data[(rowBase + nx) * 4 + 3] > alphaThreshold) {
              hit = true;
              break;
            }
          }
        }
        if (hit) {
          result[idx] = cr;
          result[idx + 1] = cg;
          result[idx + 2] = cb;
          result[idx + 3] = ca;
        }
      }
    }
    return result;
  }

  /// ピクセル化（ドット絵化）：ブロック平均化（モザイク）で低解像度化した
  /// うえで色数削減（ポスタリゼーション）を行い、ドット絵らしい見た目に
  /// する。スタンプ画像のピクセルモード（ユーザー指示により新規追加）で
  /// 使用する。ペン・テキストのピクセルモード（アルファの二値化のみで
  /// 済む単色描画）と異なり、スタンプ画像は任意の多色RGBA画像のため、
  /// 単純な二値化だけでは真のドット絵にはならず、実際に低解像度化＋
  /// 色数削減の両方が必要になる。
  Uint8List applyPixelate(Uint8List data, int width, int height, {
    int mosaicSize = 8,
    int colorLevels = 6,
  }) {
    final mosaic = applyMosaic(data, width, height, mosaicSize);
    final step = (256 / colorLevels.clamp(2, 32)).round();
    final result = Uint8List.fromList(mosaic);
    for (int i = 0; i < result.length; i += 4) {
      result[i] = ((result[i] / step).round() * step).clamp(0, 255);
      result[i + 1] = ((result[i + 1] / step).round() * step).clamp(0, 255);
      result[i + 2] = ((result[i + 2] / step).round() * step).clamp(0, 255);
    }
    return result;
  }

  Uint8List applyFade(Uint8List data, int width, int height, ui.Color fadeColor, double progress) {
    final result = Uint8List.fromList(data);
    final fr = (fadeColor.r * 255).round();
    final fg = (fadeColor.g * 255).round();
    final fb = (fadeColor.b * 255).round();
    final t = progress.clamp(0.0, 1.0);
    for (int i = 0; i < result.length; i += 4) {
      result[i] = (result[i] * (1 - t) + fr * t).round().clamp(0, 255);
      result[i + 1] = (result[i + 1] * (1 - t) + fg * t).round().clamp(0, 255);
      result[i + 2] = (result[i + 2] * (1 - t) + fb * t).round().clamp(0, 255);
    }
    return result;
  }

  Uint8List applyToneCurve(Uint8List data, int width, int height, List<ui.Offset> curvePoints) {
    if (curvePoints.length < 2) return data;
    // LUT生成（0-255 → 0-255）
    final lut = List<int>.generate(256, (i) {
      final x = i / 255.0;
      // 線形補間
      for (int j = 0; j < curvePoints.length - 1; j++) {
        final p0 = curvePoints[j];
        final p1 = curvePoints[j + 1];
        if (x >= p0.dx && x <= p1.dx) {
          final t = (x - p0.dx) / (p1.dx - p0.dx);
          return ((p0.dy + t * (p1.dy - p0.dy)) * 255).round().clamp(0, 255);
        }
      }
      return i;
    });
    final result = Uint8List.fromList(data);
    for (int i = 0; i < result.length; i += 4) {
      result[i] = lut[result[i]];
      result[i + 1] = lut[result[i + 1]];
      result[i + 2] = lut[result[i + 2]];
    }
    return result;
  }

  Uint8List applyLevels(Uint8List data, int width, int height, {
    required int inputBlack,
    required int inputWhite,
    required int outputBlack,
    required int outputWhite,
  }) {
    final inRange = (inputWhite - inputBlack).clamp(1, 255);
    final outRange = outputWhite - outputBlack;
    final result = Uint8List.fromList(data);
    for (int i = 0; i < result.length; i += 4) {
      for (int c = 0; c < 3; c++) {
        final v = ((result[i + c] - inputBlack) / inRange * outRange + outputBlack)
            .round().clamp(0, 255);
        result[i + c] = v;
      }
    }
    return result;
  }

  // ─── ヘルパー ─────────────────────────────────────────────────────────

  List<double> _gaussianKernel(int radius) {
    final sigma = radius / 3.0;
    final kernel = List<double>.generate(radius * 2 + 1, (i) {
      final x = i - radius;
      return math.exp(-(x * x) / (2 * sigma * sigma));
    });
    final sum = kernel.fold(0.0, (a, b) => a + b);
    return kernel.map((v) => v / sum).toList();
  }

  Uint8List _convolveH(Uint8List data, int width, int height, List<double> kernel) {
    final radius = kernel.length ~/ 2;
    final result = Uint8List(data.length);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double r = 0, g = 0, b = 0, a = 0;
        for (int k = 0; k < kernel.length; k++) {
          final nx = (x + k - radius).clamp(0, width - 1);
          final idx = (y * width + nx) * 4;
          r += data[idx] * kernel[k];
          g += data[idx + 1] * kernel[k];
          b += data[idx + 2] * kernel[k];
          a += data[idx + 3] * kernel[k];
        }
        final idx = (y * width + x) * 4;
        result[idx] = r.round().clamp(0, 255);
        result[idx + 1] = g.round().clamp(0, 255);
        result[idx + 2] = b.round().clamp(0, 255);
        result[idx + 3] = a.round().clamp(0, 255);
      }
    }
    return result;
  }

  Uint8List _convolveV(Uint8List data, int width, int height, List<double> kernel) {
    final radius = kernel.length ~/ 2;
    final result = Uint8List(data.length);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double r = 0, g = 0, b = 0, a = 0;
        for (int k = 0; k < kernel.length; k++) {
          final ny = (y + k - radius).clamp(0, height - 1);
          final idx = (ny * width + x) * 4;
          r += data[idx] * kernel[k];
          g += data[idx + 1] * kernel[k];
          b += data[idx + 2] * kernel[k];
          a += data[idx + 3] * kernel[k];
        }
        final idx = (y * width + x) * 4;
        result[idx] = r.round().clamp(0, 255);
        result[idx + 1] = g.round().clamp(0, 255);
        result[idx + 2] = b.round().clamp(0, 255);
        result[idx + 3] = a.round().clamp(0, 255);
      }
    }
    return result;
  }

  List<int> _sobelEdge(Uint8List data, int width, int height) {
    final result = List<int>.filled(width * height, 0);
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int gx = 0, gy = 0;
        const kx = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
        const ky = [-1, -2, -1, 0, 0, 0, 1, 2, 1];
        for (int ky2 = -1; ky2 <= 1; ky2++) {
          for (int kx2 = -1; kx2 <= 1; kx2++) {
            final idx = ((y + ky2) * width + (x + kx2)) * 4;
            final gray = (data[idx] * 0.299 + data[idx + 1] * 0.587 + data[idx + 2] * 0.114).round();
            final ki = (ky2 + 1) * 3 + (kx2 + 1);
            gx += gray * kx[ki];
            gy += gray * ky[ki];
          }
        }
        result[y * width + x] = math.sqrt(gx * gx + gy * gy).round().clamp(0, 255);
      }
    }
    return result;
  }

  double _gaussianRandom(math.Random rng) {
    // Box-Muller変換
    final u1 = rng.nextDouble();
    final u2 = rng.nextDouble();
    return math.sqrt(-2 * math.log(u1 + 1e-10)) * math.cos(2 * math.pi * u2);
  }
}

enum NoiseType { gaussian, uniform }

class EffectFilter {
  final EffectFilterType type;
  final int startFrame;
  final int endFrame;
  final Map<String, dynamic> parameters;
  final bool isEnabled;
  final bool isFavorite;

  const EffectFilter({
    required this.type,
    required this.startFrame,
    required this.endFrame,
    required this.parameters,
    this.isEnabled = true,
    this.isFavorite = false,
  });
}

enum EffectFilterType {
  fade, gaussianBlur, lensBlur, mosaic, chromaticAberration, noise,
}

enum DrawFilterType {
  animeBackground,
}

class DrawFilter {
  final DrawFilterType type;
  final Map<String, dynamic> parameters;
  final bool isFavorite;

  const DrawFilter({
    required this.type,
    this.parameters = const {},
    this.isFavorite = false,
  });
}
