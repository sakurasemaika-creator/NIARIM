import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/effect_filter_instance.dart';
import '../models/filter_def.dart';
import '../models/pixel_color_mode.dart';

/// 描画フィルターの本適用（低スペック端末でのUIスレッドブロック防止のため
/// compute()経由でバックグラウンドisolate実行する想定のトップレベル関数）。
/// [maskData]はlensDistortion（眼鏡断層フィルター）専用（選択レイヤーを
/// 単体合成したrawRgba画像）で、それ以外のフィルター種別では無視される。
Uint8List applyDrawFilterInIsolate(
    (Uint8List data, int width, int height, FilterDef filter, Uint8List? maskData) args) {
  final (data, width, height, filter, maskData) = args;
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
    FilterKind.vignette =>
      engine.applyVignette(data, width, height, filter.strength, color: filter.vignetteColor),
    FilterKind.noise =>
      engine.applyNoise(data, width, height, (filter.strength / 100).clamp(0.0, 1.0), NoiseType.gaussian),
    FilterKind.retroAnime => engine.applyRetroAnime(data, width, height, filter.strength),
    FilterKind.crt => engine.applyCrt(data, width, height, filter.strength),
    FilterKind.monochrome => engine.applyMonochrome(
        data, width, height, (filter.strength / 100).clamp(0.0, 1.0),
        targetColor: filter.monochromeColor),
    FilterKind.colorAdjust => engine.applyColorAdjust(
        data, width, height,
        saturation: filter.caSaturation, brightness: filter.caBrightness, contrast: filter.caContrast),
    FilterKind.threshold => engine.applyThreshold(data, width, height, filter.thresholdValue),
    FilterKind.fisheye => engine.applyFisheye(data, width, height, filter.strength),
    FilterKind.chromaticAberration =>
      engine.applyChromaticAberration(data, width, height, filter.strength, 0),
    FilterKind.lensDistortion => engine.applyLensDistortion(
        data, width, height, filter.strength, maskData,
        centerOffsetX: filter.lensCenterOffsetX, centerOffsetY: filter.lensCenterOffsetY),
    FilterKind.pixelate => engine.applyPixelate(
        data, width, height,
        mosaicSize: filter.strength.round().clamp(1, 64),
        colorMode: filter.pixelColorMode,
        colorLevels: filter.colorLevels,
        paletteColors: filter.pixelExplicitColors,
      ),
  };
}

/// トーンカーブのプリセット形状を制御点（0.0〜1.0の正規化座標）へ変換する。
/// プレビュー・本適用の両方から共通利用する。
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

/// 画素の色を指定方式で減色する（モザイク化は行わない、色のみの処理）。
/// ドット絵フィルター（[FilterEngine.applyPixelate]がモザイク化と組み合わせて
/// 使う）と、ブラシのピクセルモード（ストローク確定直後、タッチした範囲
/// だけに適用する。canvas_area.dart参照）の両方から共用する、トップレベル
/// の純粋関数。
///
/// - [PixelColorMode.none]：何もしない（元の色をそのまま返す）。
/// - [PixelColorMode.count]：チャンネルごとに[colorLevels]段階へ均等割り
///   （ポスタライズ）する。厳密に「使用する色の数」がN色になるとは限らない
///   簡易実装だが、既存のドット絵フィルターと同じ挙動を保つ。
/// - [PixelColorMode.explicit] / [PixelColorMode.palette]：[paletteColors]
///   （ARGB int）のうち最も近い色（RGB二乗距離）へ各画素をスナップする。
///   パレット選択（palette）は選んだ瞬間にexplicitへ解決されるため
///   （UI層でパレットの色をpaletteColorsとして渡す）、本関数の時点では
///   両者を区別せず同じロジックで扱う。[paletteColors]が空の場合は何もしない。
/// 透明画素（alpha=0）は常にスキップする（トーン等と同様、地の色を
/// 荒らさないため）。
Uint8List quantizeColors(
  Uint8List data, {
  required PixelColorMode colorMode,
  int colorLevels = 6,
  List<int> paletteColors = const [],
}) {
  switch (colorMode) {
    case PixelColorMode.none:
      return Uint8List.fromList(data);
    case PixelColorMode.count:
      final step = (256 / colorLevels.clamp(1, 256)).round().clamp(1, 256);
      final result = Uint8List.fromList(data);
      for (int i = 0; i < result.length; i += 4) {
        if (result[i + 3] == 0) continue;
        result[i] = ((result[i] / step).round() * step).clamp(0, 255);
        result[i + 1] = ((result[i + 1] / step).round() * step).clamp(0, 255);
        result[i + 2] = ((result[i + 2] / step).round() * step).clamp(0, 255);
      }
      return result;
    case PixelColorMode.explicit:
    case PixelColorMode.palette:
      if (paletteColors.isEmpty) return Uint8List.fromList(data);
      final pr = <int>[];
      final pg = <int>[];
      final pb = <int>[];
      for (final c in paletteColors) {
        pr.add((c >> 16) & 0xFF);
        pg.add((c >> 8) & 0xFF);
        pb.add(c & 0xFF);
      }
      final result = Uint8List.fromList(data);
      for (int i = 0; i < result.length; i += 4) {
        if (result[i + 3] == 0) continue;
        final r = result[i];
        final g = result[i + 1];
        final b = result[i + 2];
        int bestIdx = 0;
        int bestDist = 1 << 30;
        for (int k = 0; k < pr.length; k++) {
          final dr = r - pr[k];
          final dg = g - pg[k];
          final db = b - pb[k];
          final dist = dr * dr + dg * dg + db * db;
          if (dist < bestDist) {
            bestDist = dist;
            bestIdx = k;
          }
        }
        result[i] = pr[bestIdx];
        result[i + 1] = pg[bestIdx];
        result[i + 2] = pb[bestIdx];
      }
      return result;
  }
}

class FilterEngine {
  /// タイムラインの演出フィルター一覧を、[frameIndex]が範囲内かつ有効なものだけ、
  /// タイムライン上の並び順（[effects]の順）に適用する。
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
        EffectFilterType.sepia => applySepia(result, width, height, (e.param1 / 20).clamp(0.0, 1.0)),
        // 単色化：param1=混合量（0〜20相当を0.0〜1.0へ換算）、
        // fadeColor（他の演出フィルターと共用のColorスロットを流用）=単色化する色。
        EffectFilterType.monochrome => applyMonochrome(
            result, width, height, (e.param1 / 20).clamp(0.0, 1.0),
            targetColor: e.fadeColor.toARGB32()),
        // 色調調整：param1=彩度、param2=明度、param3=コントラスト（いずれも-100〜100）。
        EffectFilterType.colorAdjust => applyColorAdjust(
            result, width, height,
            saturation: e.param1, brightness: e.param2, contrast: e.param3),
        // 二値化：param1=閾値（0〜255）。
        EffectFilterType.threshold => applyThreshold(result, width, height, e.param1),
        EffectFilterType.animeStyle => applyAnimeStyle(
            result, width, height,
            strength: e.param1, colorCount: 6, edgeStrength: (e.param1 / 20).clamp(0.0, 1.0)),
        EffectFilterType.retroAnime =>
          applyRetroAnime(result, width, height, (e.param1 / 20 * 100).clamp(0.0, 100.0)),
        EffectFilterType.crt => applyCrt(result, width, height, (e.param1 / 20 * 100).clamp(0.0, 100.0)),
        EffectFilterType.animatedNoise => applyAnimatedNoise(
            result, width, height, frameIndex,
            strength: (e.param1 / 20).clamp(0.0, 1.0),
            amount: (e.param2 / 100).clamp(0.0, 1.0),
            size: e.param3.round().clamp(1, 8),
          ),
        EffectFilterType.rain => applyRain(
            result, width, height, frameIndex,
            intensity: e.param1.round().clamp(1, 20),
            speed: e.param2,
            size: e.param3,
            windAngleDeg: e.param4,
          ),
        EffectFilterType.fisheye =>
          applyFisheye(result, width, height, (e.param1 / 20 * 100).clamp(0.0, 100.0)),
        // ドット絵：param1=モザイクブロックサイズ（1〜64px）、
        // param2=色数（2〜32）。スタンプのピクセルモードと同じ
        // applyPixelateを使う。
        EffectFilterType.pixelate => applyPixelate(
            result, width, height,
            mosaicSize: e.param1.round().clamp(1, 64),
            colorMode: e.pixelColorMode,
            colorLevels: e.param2.round().clamp(1, 256),
            paletteColors: e.pixelExplicitColors,
          ),
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

  /// 魚眼レンズ風の湾曲。中心を膨らませ、外側ほど圧縮して見せることで、
  /// 魚眼・広角レンズで撮影したような歪みを再現する。中心から各画素までの
  /// 距離（対角線の半分を1.0とする正規化距離）を[exponent]乗することで
  /// サンプリング元の位置をずらす（[exponent]が1より小さいほど、外側の
  /// 画素も中心付近の画素からサンプリングされるため、中心が拡大されて
  /// 見える）。[strength]は0〜100（%）。
  Uint8List applyFisheye(Uint8List data, int width, int height, double strength) {
    final amount = (strength / 100.0).clamp(0.0, 1.0);
    if (amount <= 0) return Uint8List.fromList(data);
    final exponent = (1.0 - amount * 0.85).clamp(0.15, 1.0);
    final cx = width / 2.0;
    final cy = height / 2.0;
    final maxR = math.sqrt(cx * cx + cy * cy);
    final result = Uint8List(data.length);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final nx = (x - cx) / maxR;
        final ny = (y - cy) / maxR;
        final r = math.sqrt(nx * nx + ny * ny);
        double srcX, srcY;
        if (r <= 1e-6) {
          srcX = cx;
          srcY = cy;
        } else {
          final newR = math.pow(r, exponent).toDouble();
          final theta = math.atan2(ny, nx);
          srcX = cx + math.cos(theta) * newR * maxR;
          srcY = cy + math.sin(theta) * newR * maxR;
        }
        final sx = srcX.round().clamp(0, width - 1);
        final sy = srcY.round().clamp(0, height - 1);
        final srcIdx = (sy * width + sx) * 4;
        final dstIdx = (y * width + x) * 4;
        result[dstIdx] = data[srcIdx];
        result[dstIdx + 1] = data[srcIdx + 1];
        result[dstIdx + 2] = data[srcIdx + 2];
        result[dstIdx + 3] = data[srcIdx + 3];
      }
    }
    return result;
  }

  /// 眼鏡断層フィルター（選択レイヤーで塗った範囲に、度の強い
  /// レンズの光学屈折を模した局所的な放射状ワープをかける）。
  /// [maskData]は選択レイヤー（LayerType.selection）を単体合成した
  /// rawRgba画像（[data]と同じ幅・高さ）で、アルファ値0の画素は対象外、
  /// それ以外の画素が塗られた範囲となる。[maskData]がnull・全画素透明
  /// （＝選択レイヤー無し・未使用）の場合は何もしない。
  ///
  /// マスクを4連結の連結成分（フラッドフィル）ごとに分け、各成分の
  /// 重心（＋[centerOffsetX]・[centerOffsetY]による手動オフセット）を
  /// 中心として、その成分に含まれる画素だけを対象にapplyFisheyeと同じ
  /// r^exponent型の放射状ワープを適用する（正規化半径は成分内の最大距離
  /// を1とする＝魚眼フィルターの画像全体版を、成分1つぶんの局所範囲へ
  /// 縮小適用したもの）。[strength]は-100〜100（0で無効。負で凹レンズ風に
  /// 縮小、正で凸レンズ風に拡大）。マスクの縁が半透明（フェザリング）の
  /// 画素は、ワープ後の色と元の色をアルファでブレンドし、境界の継ぎ目を
  /// 目立たなくする。
  Uint8List applyLensDistortion(
    Uint8List data,
    int width,
    int height,
    double strength,
    Uint8List? maskData, {
    double centerOffsetX = 0,
    double centerOffsetY = 0,
  }) {
    if (maskData == null) return Uint8List.fromList(data);
    final amount = (strength / 100.0).clamp(-1.0, 1.0);
    if (amount == 0) return Uint8List.fromList(data);
    // fisheyeと同じ換算式を符号付きへ拡張：0で1（無変化）、+100で0.15
    // （凸レンズ・魚眼と同じ最大湾曲）、-100で1.85（凹レンズ・逆方向へ
    // 同程度の湾曲）。
    final exponent = (1.0 - amount * 0.85).clamp(0.15, 1.85);
    final result = Uint8List.fromList(data);
    final total = width * height;
    final visited = List<bool>.filled(total, false);
    final queue = <int>[];
    for (int start = 0; start < total; start++) {
      if (visited[start] || maskData[start * 4 + 3] == 0) {
        visited[start] = true;
        continue;
      }
      // このマスク画素を起点に4連結のフラッドフィルで連結成分を集める。
      queue
        ..clear()
        ..add(start);
      visited[start] = true;
      final pixels = <int>[];
      double sumX = 0, sumY = 0;
      while (queue.isNotEmpty) {
        final idx = queue.removeLast();
        final px = idx % width;
        final py = idx ~/ width;
        pixels.add(idx);
        sumX += px;
        sumY += py;
        if (px > 0) {
          final n = idx - 1;
          if (!visited[n] && maskData[n * 4 + 3] != 0) {
            visited[n] = true;
            queue.add(n);
          }
        }
        if (px < width - 1) {
          final n = idx + 1;
          if (!visited[n] && maskData[n * 4 + 3] != 0) {
            visited[n] = true;
            queue.add(n);
          }
        }
        if (py > 0) {
          final n = idx - width;
          if (!visited[n] && maskData[n * 4 + 3] != 0) {
            visited[n] = true;
            queue.add(n);
          }
        }
        if (py < height - 1) {
          final n = idx + width;
          if (!visited[n] && maskData[n * 4 + 3] != 0) {
            visited[n] = true;
            queue.add(n);
          }
        }
      }
      if (pixels.isEmpty) continue;
      final cx = (sumX / pixels.length) + centerOffsetX;
      final cy = (sumY / pixels.length) + centerOffsetY;
      double maxR = 1.0;
      for (final idx in pixels) {
        final dx = (idx % width) - cx;
        final dy = (idx ~/ width) - cy;
        final r = math.sqrt(dx * dx + dy * dy);
        if (r > maxR) maxR = r;
      }
      for (final idx in pixels) {
        final px = (idx % width).toDouble();
        final py = (idx ~/ width).toDouble();
        final nx = (px - cx) / maxR;
        final ny = (py - cy) / maxR;
        final r = math.sqrt(nx * nx + ny * ny);
        double srcX, srcY;
        if (r <= 1e-6) {
          srcX = cx;
          srcY = cy;
        } else {
          final newR = math.pow(r, exponent).toDouble();
          final theta = math.atan2(ny, nx);
          srcX = cx + math.cos(theta) * newR * maxR;
          srcY = cy + math.sin(theta) * newR * maxR;
        }
        final sx = srcX.round().clamp(0, width - 1);
        final sy = srcY.round().clamp(0, height - 1);
        final srcIdx = (sy * width + sx) * 4;
        final dstIdx = idx * 4;
        // マスクの縁（フェザリング済みの半透明画素）は、ワープ後の色と
        // 元の色をアルファでブレンドして継ぎ目を目立たなくする。
        final maskAlpha = maskData[idx * 4 + 3] / 255.0;
        for (int c = 0; c < 4; c++) {
          final warped = data[srcIdx + c];
          final original = data[dstIdx + c];
          result[dstIdx + c] =
              (warped * maskAlpha + original * (1 - maskAlpha)).round().clamp(0, 255);
        }
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

  /// 動くノイズ（フィルムグレイン風）：[frameIndex]をシードにすることで、
  /// 同じフレームへ戻ってきた時は毎回同じ粒状になり（スクラブ時にちらつかない）、
  /// 次のフレームでは別の粒状になる（再生すると粒がちらついて動いて見える）。
  /// [size]px四方のブロック単位でノイズを乗せることで粒の大きさを、
  /// [amount]（0〜1）で乗る確率（密度）を、[strength]（0〜1）で強さを調整する。
  Uint8List applyAnimatedNoise(
    Uint8List data,
    int width,
    int height,
    int frameIndex, {
    required double strength,
    required double amount,
    required int size,
  }) {
    final result = Uint8List.fromList(data);
    final blockSize = size.clamp(1, 8);
    final rng = math.Random(frameIndex * 7919 + 13);
    final s = (strength * 255).round().clamp(0, 255);
    for (int by = 0; by < height; by += blockSize) {
      final y1 = math.min(by + blockSize, height);
      for (int bx = 0; bx < width; bx += blockSize) {
        final hit = rng.nextDouble() < amount;
        final n = hit ? (_gaussianRandom(rng) * s).round().clamp(-s, s) : 0;
        if (n == 0) continue;
        final x1 = math.min(bx + blockSize, width);
        for (int y = by; y < y1; y++) {
          for (int x = bx; x < x1; x++) {
            final i = (y * width + x) * 4;
            if (result[i + 3] == 0) continue;
            result[i] = (result[i] + n).clamp(0, 255);
            result[i + 1] = (result[i + 1] + n).clamp(0, 255);
            result[i + 2] = (result[i + 2] + n).clamp(0, 255);
          }
        }
      }
    }
    return result;
  }

  /// 動く雨：[frameIndex]に応じて雨粒が[speed]で降り落ち、[windAngleDeg]
  /// （0=真下、正負で左右に傾く）方向へ流れる。各雨粒は自身のインデックスで
  /// シードした乱数から開始位置・速度のばらつきを決めるため、フレームが
  /// 変わっても同じ粒が連続して動いて見える（フレームごとに乱数を振り直す
  /// と粒がテレポートして見えてしまうため）。[intensity]は粒の本数、
  /// [size]は線の太さ。
  Uint8List applyRain(
    Uint8List data,
    int width,
    int height,
    int frameIndex, {
    required int intensity,
    required double speed,
    required double size,
    required double windAngleDeg,
  }) {
    final result = Uint8List.fromList(data);
    final count = (intensity * 15).clamp(15, 300);
    final angleRad = windAngleDeg * math.pi / 180.0;
    final dirX = math.sin(angleRad);
    final dirY = math.cos(angleRad);
    final streakLen = (12 + speed * 2).clamp(8.0, 60.0);
    final thickness = size.clamp(1.0, 6.0).round();
    for (int i = 0; i < count; i++) {
      final rng = math.Random(i * 92821 + 17);
      final x0 = rng.nextDouble() * width;
      final y0 = rng.nextDouble() * (height + streakLen) - streakLen;
      final fallSpeed = speed * (0.7 + rng.nextDouble() * 0.6);
      final travel = frameIndex * fallSpeed;
      final y = (y0 + travel) % (height + streakLen * 2) - streakLen;
      final x = (x0 + travel * dirX) % width;
      final steps = streakLen.round();
      for (int step = 0; step < steps; step++) {
        final px = (x - dirX * step).round();
        final py = (y - dirY * step).round();
        if (py < 0 || py >= height) continue;
        final alpha = (1.0 - step / steps) * 0.5;
        for (int tx = -thickness ~/ 2; tx <= thickness ~/ 2; tx++) {
          final rx = ((px + tx) % width + width) % width;
          final idx = (py * width + rx) * 4;
          if (result[idx + 3] == 0) continue;
          result[idx] = (result[idx] + (220 - result[idx]) * alpha).round().clamp(0, 255);
          result[idx + 1] = (result[idx + 1] + (235 - result[idx + 1]) * alpha).round().clamp(0, 255);
          result[idx + 2] = (result[idx + 2] + (255 - result[idx + 2]) * alpha).round().clamp(0, 255);
        }
      }
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
  /// 選択レイヤーの直下へ挿入する新規レイヤーのピクセルデータとして使う
  /// （filter_panel.dartの`_applyToFrame`参照）。
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
  /// する。スタンプ画像のピクセルモードで使用する。ペン・テキストの
  /// ピクセルモード（アルファの二値化のみで
  /// 済む単色描画）と異なり、スタンプ画像は任意の多色RGBA画像のため、
  /// 単純な二値化だけでは真のドット絵にはならず、実際に低解像度化＋
  /// 色数削減の両方が必要になる。
  /// 周辺減光（ビネット）：画面中心からの距離に応じて周辺を[color]（既定は
  /// 黒）へ寄せる、イラスト・漫画の演出で定番の効果。中心からの距離計算のみの
  /// 単純な1パス処理で負荷は軽い。[strength]は0〜100（%）で減光の強さを
  /// 調整する。[color]に黒以外を指定すると、暗くするのではなく指定色を
  /// 周辺へかぶせる（夕焼けオレンジ・夜の青など）演出にも使える。
  Uint8List applyVignette(Uint8List data, int width, int height, double strength,
      {int color = 0xFF000000}) {
    final amount = (strength / 100.0).clamp(0.0, 1.0);
    if (amount <= 0) return Uint8List.fromList(data);
    final result = Uint8List.fromList(data);
    final cr = (color >> 16) & 0xFF;
    final cg = (color >> 8) & 0xFF;
    final cb = color & 0xFF;
    final cx = width / 2.0;
    final cy = height / 2.0;
    // 対角線の半分を最大距離とし、中心付近は影響なし・外周に近づくほど
    // 指定色へ寄っていくようにする（中心60%程度までは変化なし、そこから
    // 外周へ滑らかに変化する古典的なビネット形状）。
    final maxDist = math.sqrt(cx * cx + cy * cy);
    const innerRadius = 0.6;
    for (int y = 0; y < height; y++) {
      final dy = (y - cy) / maxDist;
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        if (data[idx + 3] == 0) continue;
        final dx = (x - cx) / maxDist;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= innerRadius) continue;
        final t = ((dist - innerRadius) / (1.0 - innerRadius)).clamp(0.0, 1.0);
        final mix = t * amount;
        result[idx] = (data[idx] + (cr - data[idx]) * mix).round().clamp(0, 255);
        result[idx + 1] = (data[idx + 1] + (cg - data[idx + 1]) * mix).round().clamp(0, 255);
        result[idx + 2] = (data[idx + 2] + (cb - data[idx + 2]) * mix).round().clamp(0, 255);
      }
    }
    return result;
  }

  /// セピア調（回想・過去シーンの演出で定番の褐色トーン）。輝度を求めて
  /// 古典的なセピア変換式でRGBを求め、[amount]（0.0〜1.0）で元の色との
  /// ブレンド量を調整する。1画素あたりの計算のみで負荷は軽い。
  Uint8List applySepia(Uint8List data, int width, int height, double amount) {
    if (amount <= 0) return Uint8List.fromList(data);
    final result = Uint8List.fromList(data);
    for (int i = 0; i < data.length; i += 4) {
      if (data[i + 3] == 0) continue;
      final r = data[i], g = data[i + 1], b = data[i + 2];
      final sr = (r * 0.393 + g * 0.769 + b * 0.189).clamp(0, 255);
      final sg = (r * 0.349 + g * 0.686 + b * 0.168).clamp(0, 255);
      final sb = (r * 0.272 + g * 0.534 + b * 0.131).clamp(0, 255);
      result[i] = (r + (sr - r) * amount).round().clamp(0, 255);
      result[i + 1] = (g + (sg - g) * amount).round().clamp(0, 255);
      result[i + 2] = (b + (sb - b) * amount).round().clamp(0, 255);
    }
    return result;
  }

  /// 単色化：輝度を求め、[targetColor]（既定は白＝従来通りのグレースケール）を
  /// 輝度で明暗づけした色へ置き換える（duotone的な処理：白を指定すれば普通の
  /// 白黒、セピア色を指定すればセピア調、というように任意の1色で単色化できる）。
  /// [amount]（0.0〜1.0）で元の色との混合量を調整する（100%で完全な単色化）。
  /// 1画素あたりの計算のみで負荷は軽い。描画フィルター・演出フィルター両方から使う。
  Uint8List applyMonochrome(Uint8List data, int width, int height, double amount,
      {int targetColor = 0xFFFFFFFF}) {
    if (amount <= 0) return Uint8List.fromList(data);
    final tr = (targetColor >> 16) & 0xFF;
    final tg = (targetColor >> 8) & 0xFF;
    final tb = targetColor & 0xFF;
    final result = Uint8List.fromList(data);
    for (int i = 0; i < data.length; i += 4) {
      if (data[i + 3] == 0) continue;
      final r = data[i], g = data[i + 1], b = data[i + 2];
      final luminance = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0;
      final mr = (tr * luminance).round().clamp(0, 255);
      final mg = (tg * luminance).round().clamp(0, 255);
      final mb = (tb * luminance).round().clamp(0, 255);
      result[i] = (r + (mr - r) * amount).round().clamp(0, 255);
      result[i + 1] = (g + (mg - g) * amount).round().clamp(0, 255);
      result[i + 2] = (b + (mb - b) * amount).round().clamp(0, 255);
    }
    return result;
  }

  /// 二値化：輝度が[threshold]（0〜255）以上の画素を白、未満を黒に分ける。
  /// アルファはそのまま維持する。色調調整・単色化・「明度で透過」と組み合わせて
  /// 線画抽出に使うことを想定している。
  Uint8List applyThreshold(Uint8List data, int width, int height, double threshold) {
    final result = Uint8List.fromList(data);
    for (int i = 0; i < data.length; i += 4) {
      if (data[i + 3] == 0) continue;
      final r = data[i], g = data[i + 1], b = data[i + 2];
      final luminance = r * 0.299 + g * 0.587 + b * 0.114;
      final v = luminance >= threshold ? 255 : 0;
      result[i] = v;
      result[i + 1] = v;
      result[i + 2] = v;
    }
    return result;
  }

  /// 色調調整：彩度・明度・コントラストをそれぞれ独立に調整する
  /// （キャンバス上部バーの設定/編集メニュー「色調調整」、描画・演出
  /// フィルターの「色調調整」種別で共通利用）。各パラメータは-100〜100
  /// （0が変化なし）。1画素あたりの計算のみで負荷は軽い。
  Uint8List applyColorAdjust(
    Uint8List data,
    int width,
    int height, {
    required double saturation,
    required double brightness,
    required double contrast,
  }) {
    if (saturation == 0 && brightness == 0 && contrast == 0) return Uint8List.fromList(data);
    final result = Uint8List.fromList(data);
    final satFactor = 1.0 + saturation / 100.0;
    final briOffset = brightness / 100.0 * 255.0;
    // 古典的なコントラスト補正式：F = 259*(C+255) / (255*(259-C))
    final contrastScaled = (contrast / 100.0 * 255.0).clamp(-255.0, 255.0);
    final conF = (259 * (contrastScaled + 255)) / (255 * (259 - contrastScaled));
    for (int i = 0; i < data.length; i += 4) {
      if (data[i + 3] == 0) continue;
      var r = data[i].toDouble();
      var g = data[i + 1].toDouble();
      var b = data[i + 2].toDouble();
      if (saturation != 0) {
        final gray = r * 0.299 + g * 0.587 + b * 0.114;
        r = gray + (r - gray) * satFactor;
        g = gray + (g - gray) * satFactor;
        b = gray + (b - gray) * satFactor;
      }
      if (brightness != 0) {
        r += briOffset;
        g += briOffset;
        b += briOffset;
      }
      if (contrast != 0) {
        r = conF * (r - 128) + 128;
        g = conF * (g - 128) + 128;
        b = conF * (b - 128) + 128;
      }
      result[i] = r.round().clamp(0, 255);
      result[i + 1] = g.round().clamp(0, 255);
      result[i + 2] = b.round().clamp(0, 255);
    }
    return result;
  }

  /// レトロアニメ風：暖色寄りのカラーグレーディング・彩度低下・粒状ノイズを
  /// 組み合わせた、昔のセルアニメ・VHS録画のような質感。1画素あたりの
  /// 色変換とノイズ処理1回分のみで、既存のanimeStyle（ポスタリゼーション＋
  /// Sobelエッジ検出）より軽い。
  Uint8List applyRetroAnime(Uint8List data, int width, int height, double strength) {
    final amount = (strength / 100.0).clamp(0.0, 1.0);
    if (amount <= 0) return Uint8List.fromList(data);
    final result = Uint8List.fromList(data);
    for (int i = 0; i < data.length; i += 4) {
      if (data[i + 3] == 0) continue;
      final r = data[i], g = data[i + 1], b = data[i + 2];
      final warmR = (r * 1.08).clamp(0, 255);
      final warmB = (b * 0.92).clamp(0, 255);
      final gray = r * 0.3 + g * 0.59 + b * 0.11;
      final targetR = warmR + (gray - warmR) * 0.15;
      final targetG = g + (gray - g) * 0.15;
      final targetB = warmB + (gray - warmB) * 0.15;
      result[i] = (r + (targetR - r) * amount).round().clamp(0, 255);
      result[i + 1] = (g + (targetG - g) * amount).round().clamp(0, 255);
      result[i + 2] = (b + (targetB - b) * amount).round().clamp(0, 255);
    }
    return applyNoise(result, width, height, amount * 0.15, NoiseType.gaussian);
  }

  /// ブラウン管（CRT）風：色収差・周辺減光・走査線を組み合わせた昔のテレビ・
  /// モニター表示のような質感。いずれも既存メソッドの組み合わせ＋1画素
  /// ごとの単純な走査線処理のみで、負荷は軽い。
  Uint8List applyCrt(Uint8List data, int width, int height, double strength) {
    final amount = (strength / 100.0).clamp(0.0, 1.0);
    if (amount <= 0) return Uint8List.fromList(data);
    var result = applyChromaticAberration(data, width, height, 1 + amount * 2, 0);
    result = applyVignette(result, width, height, 20 + amount * 30);
    final darken = 1.0 - amount * 0.35;
    for (int y = 0; y < height; y += 2) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        if (result[idx + 3] == 0) continue;
        result[idx] = (result[idx] * darken).round().clamp(0, 255);
        result[idx + 1] = (result[idx + 1] * darken).round().clamp(0, 255);
        result[idx + 2] = (result[idx + 2] * darken).round().clamp(0, 255);
      }
    }
    return result;
  }

  /// モザイク化（[mosaicSize]）＋配色処理（[colorMode]）を組み合わせた
  /// ドット絵化。配色の実際の処理は[quantizeColors]（モザイク化と分離した
  /// 純粋な減色関数。ブラシのピクセルモードのストローク確定直後の色スナップ
  /// でも共用する）に委譲する。
  Uint8List applyPixelate(Uint8List data, int width, int height, {
    int mosaicSize = 8,
    PixelColorMode colorMode = PixelColorMode.count,
    int colorLevels = 6,
    List<int> paletteColors = const [],
  }) {
    final mosaic = applyMosaic(data, width, height, mosaicSize);
    return quantizeColors(
      mosaic,
      colorMode: colorMode,
      colorLevels: colorLevels,
      paletteColors: paletteColors,
    );
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
  fade, gaussianBlur, lensBlur, mosaic, chromaticAberration, noise, sepia,
  animeStyle, retroAnime, crt,
  animatedNoise, rain, monochrome, colorAdjust, threshold, fisheye, pixelate,
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
