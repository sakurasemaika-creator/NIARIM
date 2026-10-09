import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/effect_filter_instance.dart';
import '../models/filter_def.dart';
import '../models/pixel_color_mode.dart';
import 'anime_border_lines.dart';
import 'background_acclimation_engine.dart';
import 'auto_lineart_engine.dart';
import 'ink_pool_engine.dart';
import 'prism_filter_engine.dart';
import 'pixel_art_engine.dart';
import 'sphere_shading_engine.dart';
import 'vhs_noise_engine.dart';
import 'premultiplied.dart';
import 'tone_curve.dart';

/// Preview, apply and recorded replay share the same seeded noise settings.
/// The largest blur radius the drawing filters take, in canvas pixels.
const int kMaxBlurRadius = 100;

Uint8List applyNoiseFilter(
  Uint8List data,
  int width,
  int height,
  FilterDef filter, {
  int frameIndex = 0,
}) {
  final engine = FilterEngine();
  final strength = (filter.strength / 100).clamp(0.0, 1.0);
  // Grain is added to the straight colour (premultiplied pixels would get
  // colour in their transparent parts); the VHS shifts and smears across
  // pixels, so it is kept within each pixel's alpha instead.
  return switch (filter.noiseStyle) {
    NoiseStyle.filmGrain => onStraightColour(
      data,
      (straight) => engine.applyFilmGrain(
        straight,
        width,
        height,
        strength,
        seed: filter.noiseSeed,
      ),
    ),
    NoiseStyle.color => onStraightColour(
      data,
      (straight) => engine.applyColorNoise(
        straight,
        width,
        height,
        strength,
        seed: filter.noiseSeed,
      ),
    ),
    NoiseStyle.vhs => clampChannelsToAlpha(
      VhsNoiseEngine.apply(
        data,
        width,
        height,
        noiseStrength: filter.strength,
        scanlineStrength: filter.caSaturation,
        colorBleed: filter.caBrightness,
        tracking: filter.caContrast,
        seed: filter.noiseSeed,
        // Each frame takes its own noise, so applied to several frames
        // the VHS flickers as a tape does.
        frameIndex: frameIndex,
      ),
    ),
  };
}

/// Sphere shading as [filter] describes it, on a canvas of this size (the
/// preview passes its own smaller size: the light is measured in
/// proportions of the canvas, so it lands in the same place).
Uint8List applySphereShadingFilter(
  Uint8List data,
  int width,
  int height,
  FilterDef filter,
  Uint8List? mask,
) {
  final light = filter.sphereLight(width, height);
  return applySphereShading(
    data,
    width,
    height,
    shadowColor: filter.sphereShadowColor,
    lightColor: filter.sphereLightColor,
    shadowBlend: filter.sphereShadowBlend,
    lightBlend: filter.sphereLightBlend,
    combined: filter.sphereCombined,
    combinedBlend: filter.sphereCombinedBlend,
    centerX: light.centerX,
    centerY: light.centerY,
    radiusX: light.radiusX,
    radiusY: light.radiusY,
    lightBlur: filter.sphereLightBlur,
    shadowBlur: filter.sphereShadowBlur,
    mask: mask,
  );
}

/// 描画フィルターの本適用（低スペック端末でのUIスレッドブロック防止のため
/// compute()経由でバックグラウンドisolate実行する想定のトップレベル関数）。
/// [maskData]は、眼鏡断層フィルター・球体陰影では選択レイヤーを単体合成した
/// rawRgba画像（[filterUsesSelectionMask]）、背景なじませでは対象レイヤー以外を
/// 合成した画像で、それ以外のフィルター種別では無視される。
Uint8List applyDrawFilterInIsolate(
  (Uint8List data, int width, int height, FilterDef filter, Uint8List? maskData)
  args,
) {
  final (data, width, height, filter, maskData) = args;
  return applyDrawFilterForFrameInIsolate((
    data,
    width,
    height,
    filter,
    maskData,
    0,
  ));
}

/// [applyDrawFilterInIsolate] for frame [frameIndex] of the scene (filters
/// that change over time, such as the VHS noise, take that frame's state).
Uint8List applyDrawFilterForFrameInIsolate(
  (
    Uint8List data,
    int width,
    int height,
    FilterDef filter,
    Uint8List? maskData,
    int frameIndex,
  )
  args,
) {
  final (data, width, height, filter, maskData, frameIndex) = args;
  final engine = FilterEngine();
  return switch (filter.kind) {
    FilterKind.gaussianBlur => engine.applyGaussianBlur(
      data,
      width,
      height,
      filter.strength,
    ),
    FilterKind.lensBlur => engine.applyLensBlur(
      data,
      width,
      height,
      filter.strength,
    ),
    FilterKind.animeStyle => engine.applyAnimeStyle(
      data,
      width,
      height,
      strength: filter.strength,
      colorCount: filter.colorLevels,
      edgeStrength: filter.edgeStrength,
      borderWidth: filter.animeBorderWidth,
      borderThreshold: filter.animeBorderThreshold,
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
      erosion: filter.outlineErosion,
    ),
    FilterKind.toneCurve => engine.applyToneCurve(
      data,
      width,
      height,
      filter.toneCurvePoints.length >= 4
          ? [
              for (var i = 0; i + 1 < filter.toneCurvePoints.length; i += 2)
                ui.Offset(
                  filter.toneCurvePoints[i],
                  filter.toneCurvePoints[i + 1],
                ),
            ]
          : toneCurvePoints(filter.toneCurvePreset),
      redPoints: _storedCurve(filter.toneCurveRedPoints),
      greenPoints: _storedCurve(filter.toneCurveGreenPoints),
      bluePoints: _storedCurve(filter.toneCurveBluePoints),
    ),
    FilterKind.levels => engine.applyLevels(
      data,
      width,
      height,
      inputBlack: filter.inputBlack,
      inputWhite: filter.inputWhite,
      inputGamma: filter.inputGamma,
      outputBlack: filter.outputBlack,
      outputWhite: filter.outputWhite,
      redLevels: filter.levelsRed.length >= 5 ? filter.levelsRed : null,
      greenLevels: filter.levelsGreen.length >= 5 ? filter.levelsGreen : null,
      blueLevels: filter.levelsBlue.length >= 5 ? filter.levelsBlue : null,
    ),
    FilterKind.sharpen => engine.applySharpen(
      data,
      width,
      height,
      filter.strength,
    ),
    FilterKind.unsharpMask => engine.applyUnsharpMask(
      data,
      width,
      height,
      filter.strength,
      filter.edgeStrength,
    ),
    FilterKind.vignette => engine.applyVignette(
      data,
      width,
      height,
      filter.strength,
      color: filter.vignetteColor,
      range: filter.vignetteRange,
    ),
    FilterKind.noise => applyNoiseFilter(
      data,
      width,
      height,
      filter,
      frameIndex: frameIndex,
    ),
    FilterKind.retroAnime => engine.applyRetroAnime(
      data,
      width,
      height,
      filter.strength,
    ),
    FilterKind.crt => engine.applyCrt(
      data,
      width,
      height,
      filter.strength,
      aberration: filter.crtAberration,
      bleed: filter.crtBleed,
    ),
    FilterKind.colorAdjust => engine.applyColorAdjust(
      data,
      width,
      height,
      saturation: filter.caSaturation,
      brightness: filter.caBrightness,
      contrast: filter.caContrast,
    ),
    FilterKind.threshold => engine.applyThreshold(
      data,
      width,
      height,
      filter.thresholdValue,
    ),
    FilterKind.fisheye => engine.applyFisheye(
      data,
      width,
      height,
      filter.strength,
      radiusPercent: filter.fisheyeRadius,
      centerOffsetX: filter.fisheyeCenter(width, height).x - width / 2,
      centerOffsetY: filter.fisheyeCenter(width, height).y - height / 2,
    ),
    FilterKind.sphereShading => applySphereShadingFilter(
      data,
      width,
      height,
      filter,
      maskData,
    ),
    FilterKind.chromaticAberration => engine.applyChromaticShift(
      data,
      width,
      height,
      shiftX: filter.chromaticDisplacement.$1,
      shiftY: filter.chromaticDisplacement.$2,
      radial: filter.chromaticDisplacement.$3,
    ),
    FilterKind.lensDistortion => engine.applyLensDistortion(
      data,
      width,
      height,
      filter.strength,
      maskData,
      centerOffsetX: filter.lensCenterOffsetX,
      centerOffsetY: filter.lensCenterOffsetY,
    ),
    FilterKind.pixelate => engine.applyPixelate(
      data,
      width,
      height,
      mosaicSize: filter.pixelArtCellSize(width, height),
      colorMode: filter.pixelColorMode,
      colorLevels: filter.colorLevels,
      paletteColors: filter.pixelExplicitColors,
      dither: filter.pixelDither,
    ),
    FilterKind.mosaic => engine.applyMosaic(
      data,
      width,
      height,
      filter.strength.round().clamp(1, kPixelArtMaxBlockSize),
    ),
    FilterKind.auroraHologram => engine.applyAuroraHologram(
      data,
      width,
      height,
      strength: filter.strength,
      brightness: filter.hologramBrightness,
      saturation: filter.hologramSaturation,
      preset: filter.hologramPreset,
      keepLines: filter.hologramKeepLines,
    ),
    // 背景馴染ませv2：maskDataは対象外の表示中レイヤーを合成した背景RGBA。
    FilterKind.backgroundBlend => BackgroundAcclimationEngine.apply(
      data,
      maskData,
      width,
      height,
      filter,
    ),
    // 墨溜まりの本適用は参照レイヤーを書き換えず、墨溜まり部分だけを
    // 新規レイヤーへ描くため透明背景の出力レイヤーを返す。
    FilterKind.inkPool => engine.applyInkPoolLayer(
      data,
      width,
      height,
      color: filter.inkPoolColor,
      rangePx: filter.inkPoolRange,
      centerWidthPx: filter.inkPoolCenterWidth,
      maxAngleDegrees: filter.inkPoolMaxAngle,
    ),
    FilterKind.prism => PrismFilterEngine(filterEngine: engine).apply(
      data,
      width,
      height,
      blurPx: filter.prismBlurPx,
      gradientDirectionDegrees: filter.prismDirectionDegrees,
    ),
    FilterKind.autoLineart => AutoLineartEngine.render(
      AutoLineartEngine.prepareEditableGraph(
        AutoLineartEngine.analyze(
          data,
          width,
          height,
          roughWidthPx: filter.autoLineartRoughWidth,
        ),
        smoothingLevel: filter.autoLineartSmoothing.round().clamp(0, 10),
      ),
      width,
      height,
      outputWidthPx: filter.autoLineartOutputWidth,
      taperLengthPx: filter.autoLineartTaper
          ? filter.autoLineartTaperLength
          : 0,
      smoothing: 0,
      color: filter.autoLineartColor,
    ),
  };
}

/// トーンカーブのプリセット形状を制御点（0.0〜1.0の正規化座標）へ変換する。
/// プレビュー・本適用の両方から共通利用する。
List<ui.Offset>? _storedCurve(List<double> values) => values.length >= 4
    ? [
        for (var i = 0; i + 1 < values.length; i += 2)
          ui.Offset(values[i], values[i + 1]),
      ]
    : null;

List<ui.Offset> toneCurvePoints(ToneCurvePreset preset) {
  return switch (preset) {
    ToneCurvePreset.linear => const [ui.Offset(0, 0), ui.Offset(1, 1)],
    ToneCurvePreset.brighten => const [
      ui.Offset(0, 0),
      ui.Offset(0.5, 0.65),
      ui.Offset(1, 1),
    ],
    ToneCurvePreset.darken => const [
      ui.Offset(0, 0),
      ui.Offset(0.5, 0.35),
      ui.Offset(1, 1),
    ],
    ToneCurvePreset.highContrast => const [
      ui.Offset(0, 0),
      ui.Offset(0.25, 0.15),
      ui.Offset(0.75, 0.85),
      ui.Offset(1, 1),
    ],
    ToneCurvePreset.lowContrast => const [
      ui.Offset(0, 0.15),
      ui.Offset(0.5, 0.5),
      ui.Offset(1, 0.85),
    ],
    ToneCurvePreset.invert => const [ui.Offset(0, 1), ui.Offset(1, 0)],
  };
}

/// 描画フィルター > 質感変更フィルターの配色プリセット。
/// 各要素は(入力明度0.0〜1.0の位置, R, G, B)で、位置は昇順に並べる。
/// 右端(1.0)は元絵の白いハイライトに対応するため、各配色で最も明るい色を置く。
/// プレビュー・本適用の両方から共通利用する。
/// 各プリセットの配色意図：
/// - aurora（オーロラ）：夜空を思わせる藍色から、オーロラらしい緑〜水色〜
///   薄紫へ抜ける配色。
/// - soapBubble（シャボン玉）：石鹸膜・オイルスリックのような、ピンク→
///   紫→水色→緑→黄と巡る虹色。
/// - cyberNeon（サイバーネオン）：濃紺からマゼンタ・シアンへ抜ける、
///   高彩度でくっきりした配色。
/// - pastelDream（パステルドリーム）：ラベンダー→ミント→ピーチと、
///   全体的に明るく淡い配色。
/// - sunsetGold（サンセットゴールド）：紫がかった夕焼けからピンク・
///   ゴールドへ抜ける暖色寄りの配色。
/// - silverFoil（シルバーホイル）：スレートグレー→白→薄紫グレーと、
///   彩度を抑えたホログラム箔紙のような配色。
List<(double, int, int, int)> auroraHologramStops(AuroraHologramPreset preset) {
  return switch (preset) {
    AuroraHologramPreset.silverHologram => const [
      (0.00, 78, 170, 208),
      (0.055, 104, 219, 239),
      (0.11, 183, 248, 241),
      (0.165, 250, 254, 238),
      (0.19, 255, 250, 220),
      (0.235, 255, 213, 195),
      (0.285, 250, 181, 222),
      (0.335, 216, 187, 247),
      (0.385, 157, 201, 251),
      (0.435, 111, 235, 243),
      (0.485, 172, 251, 224),
      (0.535, 250, 252, 224),
      (0.565, 255, 248, 217),
      (0.615, 255, 214, 188),
      (0.665, 251, 178, 221),
      (0.715, 213, 184, 248),
      (0.765, 149, 207, 252),
      (0.815, 116, 239, 242),
      (0.865, 198, 251, 227),
      (0.91, 255, 250, 224),
      (0.95, 255, 221, 201),
      (0.98, 255, 248, 229),
      (1.00, 255, 255, 255),
    ],
    AuroraHologramPreset.sampledGold => const [
      // ~50 clusters sampled only from gold-material pixels in the four supplied
      // references (costumes, sphere, band, cylinder); backgrounds/skin/black
      // framing were masked out. Smooth luminance ordering preserves metal form.
      (0.00, 70, 50, 31),
      (0.06, 104, 64, 41),
      (0.12, 130, 88, 45),
      (0.18, 150, 108, 56),
      (0.24, 170, 129, 71),
      (0.30, 183, 147, 92),
      (0.36, 197, 157, 81),
      (0.42, 208, 168, 105),
      (0.48, 216, 174, 119),
      (0.54, 222, 184, 111),
      (0.60, 227, 188, 135),
      (0.66, 238, 197, 141),
      (0.72, 241, 206, 157),
      (0.78, 247, 218, 145),
      (0.84, 251, 231, 126),
      (0.90, 253, 244, 126),
      (0.95, 254, 249, 163),
      (0.98, 255, 252, 205),
      (1.00, 255, 255, 244),
    ],
    AuroraHologramPreset.silverFoil => const [
      // Silver keeps most of the sphere below near-white. Narrow reflection
      // ramps provide a harder metallic boundary while preventing broad
      // clipped-white regions.
      (0.00, 7, 10, 14),
      (0.14, 34, 40, 47),
      (0.28, 75, 84, 94),
      (0.42, 126, 137, 148),
      (0.54, 170, 181, 192),
      (0.60, 196, 207, 216),
      (0.635, 226, 234, 240),
      (0.665, 242, 247, 250),
      (0.72, 213, 222, 230),
      (0.80, 185, 196, 207),
      (0.88, 207, 217, 226),
      (0.94, 226, 234, 241),
      (0.975, 241, 246, 250),
      (0.992, 249, 252, 254),
      (1.00, 255, 255, 255),
    ],
    AuroraHologramPreset.luminousPearl => const [
      // Object-output correction against the supplied pearl photograph/zoom:
      // only the deepest ~10% uses the sampled orange-beige shadow. Most
      // luminance maps to the sampled light rosy-cream body, never broad grey.
      (0.000, 190, 157, 123),
      (0.030, 198, 169, 139),
      (0.070, 205, 180, 153),
      (0.115, 211, 188, 164),
      (0.175, 217, 197, 178),
      (0.245, 221, 205, 191),
      (0.325, 222, 211, 203),
      (0.410, 225, 217, 211),
      (0.500, 228, 221, 215),
      (0.585, 231, 226, 221),
      (0.655, 234, 230, 225),
      (0.715, 237, 233, 229),
      (0.765, 240, 237, 234),
      (0.805, 234, 235, 237),
      (0.835, 218, 230, 237),
      (0.860, 205, 224, 235),
      (0.885, 229, 235, 235),
      (0.915, 239, 232, 218),
      (0.945, 246, 240, 230),
      (0.972, 251, 247, 240),
      (0.988, 253, 251, 247),
      (1.000, 255, 254, 252),
    ],
    AuroraHologramPreset.auroraPastel => const [
      // Transparent holographic film: most of the tonal range stays close to
      // clear/white-silver. Saturated colours are narrow interference flashes
      // beside bright specular planes, rather than broad painted colour bands.
      (0.000, 205, 230, 246), // cool transparent shadow
      (0.055, 215, 238, 250),
      (0.110, 225, 244, 252), // clear silver-blue body
      (0.165, 229, 246, 254),
      (0.215, 244, 250, 255), // near-clear face
      (0.250, 220, 241, 251), // pale cyan reflection
      (0.285, 185, 232, 248), // cyan flash
      (0.310, 157, 222, 243),
      (0.330, 203, 244, 250), // return quickly toward clear
      (0.350, 250, 253, 254),
      (0.365, 255, 255, 255), // sharp white specular
      (0.385, 238, 239, 250),
      (0.405, 194, 184, 247), // violet interference edge
      (0.425, 239, 190, 239), // pink interference edge
      (0.445, 252, 222, 239),
      (0.470, 250, 246, 255), // clear body again
      (0.515, 218, 240, 252),
      (0.550, 197, 233, 249), // ice blue
      (0.580, 166, 224, 245),
      (0.602, 91, 232, 222), // tiny emerald spectral flash
      (0.620, 178, 241, 241),
      (0.642, 246, 251, 252),
      (0.658, 255, 255, 255), // second white reflection plane
      (0.680, 239, 236, 250),
      (0.705, 205, 190, 247), // lavender
      (0.728, 244, 190, 234), // narrow magenta-pink
      (0.750, 252, 222, 231),
      (0.775, 255, 241, 252), // clear/white film face
      (0.815, 215, 239, 252),
      (0.845, 192, 232, 248), // cyan-blue edge
      (0.872, 165, 216, 244), // small deeper blue reflection
      (0.895, 204, 240, 255),
      (0.918, 252, 253, 253),
      (0.936, 255, 255, 255), // strongest white glint
      // Spectral warm edge is deliberately tiny and nearly white.
      (0.950, 255, 254, 220),
      (0.960, 255, 239, 219), // faint peach edge
      (0.972, 250, 224, 242),
      (0.984, 233, 235, 251),
      (0.992, 247, 251, 253),
      (1.000, 255, 255, 255),
    ],
    AuroraHologramPreset.darkRainbow => const [
      // Rebuilt from the supplied dark diffraction reference. Black/navy owns
      // most of the value range; sampled spectral colours appear as compact,
      // bright reflections rather than replacing the substrate.
      (0.000, 4, 3, 8),
      (0.180, 5, 4, 17),
      (0.330, 8, 8, 38),
      (0.460, 15, 13, 63),
      (0.560, 35, 24, 91),
      (0.620, 71, 30, 145),
      (0.670, 118, 36, 207),
      (0.710, 62, 70, 235),
      (0.750, 24, 137, 247),
      (0.790, 24, 214, 230),
      (0.825, 41, 231, 147),
      (0.855, 109, 226, 72),
      (0.885, 213, 226, 46),
      (0.910, 250, 225, 57),
      (0.932, 252, 160, 57),
      (0.950, 247, 83, 91),
      (0.966, 232, 58, 168),
      (0.980, 172, 58, 226),
      (0.990, 74, 112, 245),
      (1.000, 236, 248, 252),
    ],
  };
}

/// 画素の色を指定方式で減色する（モザイク化は行わない、色のみの処理）。
/// ドット絵フィルター（[FilterEngine.applyPixelate]がモザイク化と組み合わせて
/// 使う）と、ブラシのピクセルモード（ストローク確定直後、タッチした範囲
/// だけに適用する。canvas_area.dart参照）の両方から共用する、トップレベル
/// の純粋関数。
///
/// - [PixelColorMode.none]：何もしない（元の色をそのまま返す）。
/// - [PixelColorMode.count]：共通[PixelArtEngine]の減色規則で、生成色を
///   [colorLevels]以下へ制限する。
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
  if (data.isEmpty) return Uint8List.fromList(data);
  // Brush pixel mode already rasterizes at one canvas pixel per sample. Route
  // its color policy through the same PixelArtEngine contract as filter/stamp
  // pixelization, with pixelSize=1 so geometry is left untouched.
  final pixelCount = data.length ~/ 4;
  return const PixelArtEngine().convert(
    data,
    pixelCount,
    1,
    pixelSize: 1,
    colorMode: colorMode,
    colorLevels: colorLevels,
    paletteColors: paletteColors,
    squareBlocks: false,
  );
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
      if (!e.enabled || frameIndex < e.startFrame || frameIndex > e.endFrame) {
        continue;
      }
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
        EffectFilterType.gaussianBlur => applyGaussianBlur(
          result,
          width,
          height,
          e.param1,
        ),
        EffectFilterType.lensBlur => applyLensBlur(
          result,
          width,
          height,
          e.param1,
        ),
        EffectFilterType.mosaic => applyMosaic(
          result,
          width,
          height,
          e.param1.round(),
        ),
        EffectFilterType.chromaticAberration => applyChromaticAberration(
          result,
          width,
          height,
          e.param1,
          0,
        ),
        EffectFilterType.noise => applyNoise(
          result,
          width,
          height,
          (e.param1 / 20).clamp(0.0, 1.0),
          NoiseType.gaussian,
        ),
        EffectFilterType.sepia => applySepia(
          result,
          width,
          height,
          (e.param1 / 20).clamp(0.0, 1.0),
        ),
        // 単色化：param1=混合量（0〜20相当を0.0〜1.0へ換算）、
        // fadeColor（他の演出フィルターと共用のColorスロットを流用）=単色化する色。
        EffectFilterType.monochrome => applyMonochrome(
          result,
          width,
          height,
          (e.param1 / 20).clamp(0.0, 1.0),
          targetColor: e.fadeColor.toARGB32(),
        ),
        // 色調調整：param1=彩度、param2=明度、param3=コントラスト（いずれも-100〜100）。
        EffectFilterType.colorAdjust => applyColorAdjust(
          result,
          width,
          height,
          saturation: e.param1,
          brightness: e.param2,
          contrast: e.param3,
        ),
        // 二値化：param1=閾値（0〜255）。
        EffectFilterType.threshold => applyThreshold(
          result,
          width,
          height,
          e.param1,
        ),
        EffectFilterType.animeStyle => applyAnimeStyle(
          result,
          width,
          height,
          strength: e.param1,
          colorCount: 6,
          edgeStrength: (e.param1 / 20).clamp(0.0, 1.0),
        ),
        EffectFilterType.retroAnime => applyRetroAnime(
          result,
          width,
          height,
          (e.param1 / 20 * 100).clamp(0.0, 100.0),
        ),
        EffectFilterType.crt => applyCrt(
          result,
          width,
          height,
          (e.param1 / 20 * 100).clamp(0.0, 100.0),
        ),
        EffectFilterType.animatedNoise => applyAnimatedNoise(
          result,
          width,
          height,
          frameIndex,
          strength: (e.param1 / 20).clamp(0.0, 1.0),
          amount: (e.param2 / 100).clamp(0.0, 1.0),
          size: e.param3.round().clamp(1, 8),
        ),
        EffectFilterType.rain => applyRain(
          result,
          width,
          height,
          frameIndex,
          intensity: e.param1.round().clamp(1, 20),
          speed: e.param2,
          size: e.param3,
          windAngleDeg: e.param4,
        ),
        EffectFilterType.fisheye => applyFisheye(
          result,
          width,
          height,
          (e.param1 / 20 * 100).clamp(0.0, 100.0),
        ),
        // ドット絵：param1=モザイクブロックサイズ（1〜64px）、
        // param2=色数（2〜32）。スタンプのピクセルモードと同じ
        // applyPixelateを使う。
        EffectFilterType.pixelate => applyPixelate(
          result,
          width,
          height,
          mosaicSize: e.param1.round().clamp(1, kPixelArtMaxBlockSize),
          colorMode: e.pixelColorMode,
          colorLevels: e.param2.round().clamp(1, 256),
          paletteColors: e.pixelExplicitColors,
          dither: e.pixelDither,
        ),
        // オーロラホログラム：param1=フィルター強度（0〜100）、
        // param2=明度、param3=彩度（いずれも-100〜100）、
        // param4=配色プリセットのインデックス（AuroraHologramPreset.values）。
        EffectFilterType.auroraHologram => applyAuroraHologram(
          result,
          width,
          height,
          strength: e.param1,
          brightness: e.param2,
          saturation: e.param3,
          preset:
              AuroraHologramPreset.values[e.param4.round().clamp(
                0,
                AuroraHologramPreset.values.length - 1,
              )],
          keepLines: true,
        ),
        // 墨溜まり：param1=範囲(px)、param2=鋭角中央の太さ(px)、
        // fadeColorスロットを色として共用する。演出フィルターでは
        // レイヤー追加を行わず、フレーム合成結果へ非破壊で重ねる。
        EffectFilterType.inkPool => applyInkPoolComposite(
          result,
          width,
          height,
          color: e.fadeColor.toARGB32(),
          rangePx: e.param1,
          centerWidthPx: e.param2,
        ),
        EffectFilterType.vhsNoise => VhsNoiseEngine.apply(
          result,
          width,
          height,
          noiseStrength: e.param1,
          scanlineStrength: e.param2,
          colorBleed: e.param3,
          tracking: e.param4,
          seed: VhsNoiseEngine.seedFromString(e.id),
          frameIndex: frameIndex,
        ),
        // トーンカーブ：param1=プリセット（ToneCurvePreset.values）、
        // param2=強さ（0〜100%、元の色との混ぜ具合）。
        EffectFilterType.toneCurve => _mixWith(
          result,
          applyToneCurve(
            result,
            width,
            height,
            toneCurvePoints(
              ToneCurvePreset.values[e.param1.round().clamp(
                0,
                ToneCurvePreset.values.length - 1,
              )],
            ),
          ),
          (e.param2 / 100).clamp(0.0, 1.0),
        ),
        // レベル補正：param1=入力の黒、param2=入力の白、param3=ガンマ、
        // param4=出力の黒、param5=出力の白。
        EffectFilterType.levels => applyLevels(
          result,
          width,
          height,
          inputBlack: e.param1.round().clamp(0, 254),
          inputWhite: e.param2.round().clamp(
            e.param1.round().clamp(0, 254) + 1,
            255,
          ),
          inputGamma: e.param3.clamp(0.1, 9.99),
          outputBlack: e.param4.round().clamp(0, 255),
          outputWhite: e.param5.round().clamp(0, 255),
        ),
        // シャープ：param1=強さ（0〜100）。
        EffectFilterType.sharpen => applySharpen(
          result,
          width,
          height,
          e.param1,
        ),
        // アンシャープマスク：param1=ぼかし半径（1〜20）、param2=量（0〜3）。
        EffectFilterType.unsharpMask => applyUnsharpMask(
          result,
          width,
          height,
          e.param1.clamp(1.0, 20.0),
          e.param2.clamp(0.0, 3.0),
        ),
        // 周辺減光：param1=範囲（0〜100%）、param2=濃さ（0〜100）、
        // fadeColor=減光の色。
        EffectFilterType.vignette => applyVignette(
          result,
          width,
          height,
          e.param2,
          color: e.fadeColor.toARGB32(),
          range: e.param1,
        ),
      };
    }
    return result;
  }

  /// [filtered] mixed back towards [original] so only [amount] (0 to 1) of
  /// the change is kept.
  Uint8List _mixWith(Uint8List original, Uint8List filtered, double amount) {
    if (amount >= 1) return filtered;
    final out = Uint8List(original.length);
    for (var i = 0; i < original.length; i++) {
      out[i] = (original[i] + (filtered[i] - original[i]) * amount).round();
    }
    return out;
  }

  /// Gaussian blur of radius [strength] px (1..[kMaxBlurRadius]). All four
  /// premultiplied channels are blurred, so the blur spreads out of the
  /// drawn shape into the transparent pixels around it as far as it eats
  /// into it. Radii up to 20 use the exact kernel; larger ones three box
  /// passes (the usual fast approximation), which keeps the cost flat.
  Uint8List applyGaussianBlur(
    Uint8List data,
    int width,
    int height,
    double strength,
  ) {
    final radius = strength.round().clamp(1, kMaxBlurRadius);
    if (radius > 20) return _boxGaussian(data, width, height, radius / 3.0);
    final kernel = _gaussianKernel(radius);
    final tmp = _convolveH(data, width, height, kernel);
    return _convolveV(tmp, width, height, kernel);
  }

  /// A Gaussian blur of standard deviation [sigma] px, the way most painting
  /// apps measure a Gaussian blur's size ([applyGaussianBlur]'s strength is
  /// three times it).
  Uint8List applyGaussianBlurSigma(
    Uint8List data,
    int width,
    int height,
    double sigma,
  ) {
    if (sigma <= 0) return Uint8List.fromList(data);
    return sigma * 3 <= 20
        ? applyGaussianBlur(data, width, height, sigma * 3)
        : _boxGaussian(data, width, height, sigma);
  }

  /// A Gaussian of [sigma] approximated by three box blurs.
  Uint8List _boxGaussian(Uint8List data, int width, int height, double sigma) {
    // Box widths whose three passes match the Gaussian's variance.
    const n = 3;
    final ideal = math.sqrt(12 * sigma * sigma / n + 1);
    var lower = ideal.floor();
    if (lower.isEven) lower--;
    final upper = lower + 2;
    final m =
        ((12 * sigma * sigma - n * lower * lower - 4 * n * lower - 3 * n) /
                (-4 * lower - 4))
            .round();
    var out = data;
    for (var i = 0; i < n; i++) {
      final r = ((i < m ? lower : upper) - 1) ~/ 2;
      out = _boxPass(out, width, height, r, horizontal: true);
      out = _boxPass(out, width, height, r, horizontal: false);
    }
    return out;
  }

  /// One running-sum box blur of radius [r] along rows or columns (edges
  /// extend the outermost pixel, as the exact kernel does).
  Uint8List _boxPass(
    Uint8List data,
    int width,
    int height,
    int r, {
    required bool horizontal,
  }) {
    if (r <= 0) return Uint8List.fromList(data);
    final out = Uint8List(data.length);
    final lines = horizontal ? height : width;
    final length = horizontal ? width : height;
    final step = horizontal ? 4 : width * 4;
    final window = 2 * r + 1;
    final sum = Int32List(4);
    for (var line = 0; line < lines; line++) {
      final base = horizontal ? line * width * 4 : line * 4;
      int at(int i) => base + i.clamp(0, length - 1) * step;
      for (var c = 0; c < 4; c++) {
        var acc = 0;
        for (var k = -r; k <= r; k++) {
          acc += data[at(k) + c];
        }
        sum[c] = acc;
      }
      for (var i = 0; i < length; i++) {
        final o = base + i * step;
        for (var c = 0; c < 4; c++) {
          out[o + c] = (sum[c] / window).round();
          sum[c] += data[at(i + r + 1) + c] - data[at(i - r) + c];
        }
      }
    }
    return out;
  }

  /// シャープ化：3x3の固定小カーネルによる畳み込み（負荷はガウスぼかし
  /// 半径1回分よりさらに軽い）。[strength]は0〜100（%）で、カーネルの
  /// かかり具合を調整する。中心画素の重みを上げ、上下左右の重みを下げる
  /// 古典的なシャープカーネルの応用。アルファは変化させない（線画の輪郭を
  /// 崩さないため）。
  Uint8List applySharpen(
    Uint8List data,
    int width,
    int height,
    double strength,
  ) {
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
          if (y > 0) {
            sum += data[((y - 1) * width + x) * 4 + c];
            n++;
          }
          if (y < height - 1) {
            sum += data[((y + 1) * width + x) * 4 + c];
            n++;
          }
          if (x > 0) {
            sum += data[(y * width + x - 1) * 4 + c];
            n++;
          }
          if (x < width - 1) {
            sum += data[(y * width + x + 1) * 4 + c];
            n++;
          }
          final neighborAvg = n > 0 ? sum / n : center.toDouble();
          final sharpened = center + amount * (center - neighborAvg);
          result[idx + c] = sharpened.round().clamp(0, 255);
        }
      }
    }
    return clampChannelsToAlpha(result);
  }

  /// アンシャープマスク：元画像からガウスぼかし版を引いた差分（＝輪郭付近の
  /// 高周波成分）を[amount]倍して元画像へ加算する、写真編集ソフトでも定番の
  /// シャープ化手法。内部で使うガウスぼかしは既存のapplyGaussianBlurと同じ
  /// 実装のため、負荷はガウスぼかしフィルター1回分＋差分計算のみで軽い。
  /// [radiusStrength]はぼかし半径（px、1〜20。gaussianBlurと同じ意味）、
  /// [amount]はかかり具合（0.0〜3.0程度、既定1.0）。
  Uint8List applyUnsharpMask(
    Uint8List data,
    int width,
    int height,
    double radiusStrength,
    double amount,
  ) {
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
    return clampChannelsToAlpha(result);
  }

  /// Lens blur (bokeh) of radius [strength] px (1..[kMaxBlurRadius]): each
  /// pixel takes the average over a disc, like an out-of-focus lens, and
  /// brighter pixels count for more, so highlights open into round bright
  /// discs instead of melting away as in [applyGaussianBlur]. Like it, it
  /// spreads into the transparent pixels around the drawing, as far out as
  /// in: the opacity is a plain average over the disc, and only the colour
  /// is weighted by brightness (transparent pixels add no colour, so they
  /// do not count as black). Each row of
  /// the disc is summed from running row totals, so the cost grows with the
  /// radius, not with its square.
  Uint8List applyLensBlur(
    Uint8List data,
    int width,
    int height,
    double strength,
  ) {
    final radius = strength.round().clamp(1, kMaxBlurRadius);
    final pixels = width * height;
    // Weight 1 for black up to 16 for white (the colour's own luma, before
    // its opacity, to the 4th power).
    final weight = Int32List(pixels);
    for (var p = 0; p < pixels; p++) {
      final i = p * 4;
      final alpha = data[i + 3];
      if (alpha == 0) {
        weight[p] = 1;
        continue;
      }
      final luma = (data[i] * 77 + data[i + 1] * 150 + data[i + 2] * 29) >> 8;
      final t = (luma / alpha).clamp(0.0, 1.0);
      weight[p] = 1 + (15 * t * t * t * t).round();
    }
    final rowLength = width + 1;
    final ring = 2 * radius + 1;
    // Running totals along each of the last [ring] rows: weight × each
    // premultiplied colour channel, weight × opacity, and opacity.
    final totals = List.generate(5, (_) => Int32List(ring * rowLength));
    void buildRow(int y) {
      final slot = (y % ring) * rowLength;
      var r = 0, g = 0, b = 0, wa = 0, a = 0;
      for (var x = 0; x < width; x++) {
        final p = y * width + x;
        final i = p * 4;
        final wt = weight[p];
        r += data[i] * wt;
        g += data[i + 1] * wt;
        b += data[i + 2] * wt;
        wa += data[i + 3] * wt;
        a += data[i + 3];
        totals[0][slot + x + 1] = r;
        totals[1][slot + x + 1] = g;
        totals[2][slot + x + 1] = b;
        totals[3][slot + x + 1] = wa;
        totals[4][slot + x + 1] = a;
      }
    }

    final halfWidths = [
      for (var dy = -radius; dy <= radius; dy++)
        math.sqrt(radius * radius - dy * dy).floor(),
    ];
    final result = Uint8List(data.length);
    var built = -1;
    final sums = List<int>.filled(5, 0);
    for (var y = 0; y < height; y++) {
      final last = math.min(height - 1, y + radius);
      while (built < last) {
        built++;
        buildRow(built);
      }
      for (var x = 0; x < width; x++) {
        sums.fillRange(0, 5, 0);
        var count = 0;
        for (var dy = -radius; dy <= radius; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          final half = halfWidths[dy + radius];
          final x0 = math.max(0, x - half);
          final x1 = math.min(width - 1, x + half);
          count += x1 - x0 + 1;
          final slot = (ny % ring) * rowLength;
          for (var c = 0; c < 5; c++) {
            final row = totals[c];
            sums[c] += row[slot + x1 + 1] - row[slot + x0];
          }
        }
        final weightedAlpha = sums[3];
        if (weightedAlpha == 0 || count == 0) continue;
        final o = (y * width + x) * 4;
        final a = (sums[4] / count).round().clamp(0, 255);
        result[o + 3] = a;
        // The brightness-weighted straight colour, at the disc's opacity.
        final scale = a / weightedAlpha;
        result[o] = math.min(a, (sums[0] * scale).round());
        result[o + 1] = math.min(a, (sums[1] * scale).round());
        result[o + 2] = math.min(a, (sums[2] * scale).round());
      }
    }
    return result;
  }

  Uint8List applyMosaic(Uint8List data, int width, int height, int mosaicSize) {
    // 1 leaves every pixel as it is.
    final size = mosaicSize.clamp(1, kPixelArtMaxBlockSize);
    final result = Uint8List.fromList(data);
    for (int y = 0; y < height; y += size) {
      for (int x = 0; x < width; x += size) {
        int r = 0, g = 0, b = 0, a = 0, count = 0;
        for (int dy = 0; dy < size && y + dy < height; dy++) {
          for (int dx = 0; dx < size && x + dx < width; dx++) {
            final idx = ((y + dy) * width + (x + dx)) * 4;
            r += data[idx];
            g += data[idx + 1];
            b += data[idx + 2];
            a += data[idx + 3];
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
            result[idx] = ar;
            result[idx + 1] = ag;
            result[idx + 2] = ab;
            result[idx + 3] = aa;
          }
        }
      }
    }
    return result;
  }

  /// 色収差（[strength]px、[direction]ラジアンの向き）。演出フィルター・
  /// ブラウン管が使う。向きと量を横・縦のずれに直して[applyChromaticShift]へ
  /// 渡す。
  Uint8List applyChromaticAberration(
    Uint8List data,
    int width,
    int height,
    double strength,
    double direction,
  ) {
    final shift = strength.clamp(1, 30).toDouble();
    return applyChromaticShift(
      data,
      width,
      height,
      shiftX: math.cos(direction) * shift,
      shiftY: math.sin(direction) * shift,
    );
  }

  /// Chromatic aberration: red is displaced one way and blue the other, green
  /// stays put. [shiftX]/[shiftY] move them sideways (canvas px); [radial]
  /// moves them apart along the line from the centre, by [radial] px at the
  /// corners and proportionally less inwards (a lens magnifying each colour
  /// slightly differently), so the centre stays sharp.
  ///
  /// Pixels are premultiplied, so each channel is sampled together with the
  /// alpha it was painted with and the result takes the strongest of them:
  /// the coloured fringes may extend past the shape's edge instead of being
  /// clipped to it, and stay valid premultiplied colours.
  Uint8List applyChromaticShift(
    Uint8List data,
    int width,
    int height, {
    double shiftX = 0,
    double shiftY = 0,
    double radial = 0,
  }) {
    if (width <= 0 || height <= 0) return Uint8List.fromList(data);
    if (shiftX == 0 && shiftY == 0 && radial == 0) {
      return Uint8List.fromList(data);
    }
    final cx = (width - 1) / 2.0, cy = (height - 1) / 2.0;
    final corner = math.max(1.0, math.sqrt(cx * cx + cy * cy));
    final perPixel = radial / corner;
    final result = Uint8List(data.length);
    // Bilinear sample of one channel and its alpha, clamped at the edges so
    // a picture that fills the canvas doesn't gain a dark border.
    (double, double) sample(double x, double y, int channel) {
      final fx = x.clamp(0.0, width - 1.0), fy = y.clamp(0.0, height - 1.0);
      final x0 = fx.floor(), y0 = fy.floor();
      final x1 = math.min(x0 + 1, width - 1), y1 = math.min(y0 + 1, height - 1);
      final tx = fx - x0, ty = fy - y0;
      double at(int px, int py, int c) => data[(py * width + px) * 4 + c] * 1.0;
      double mix(int c) {
        final top = at(x0, y0, c) * (1 - tx) + at(x1, y0, c) * tx;
        final bottom = at(x0, y1, c) * (1 - tx) + at(x1, y1, c) * tx;
        return top * (1 - ty) + bottom * ty;
      }

      return (mix(channel), mix(3));
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final dx = shiftX + (x - cx) * perPixel;
        final dy = shiftY + (y - cy) * perPixel;
        // Red appears moved by (dx, dy): read it from the opposite side.
        final (red, redAlpha) = sample(x - dx, y - dy, 0);
        final (blue, blueAlpha) = sample(x + dx, y + dy, 2);
        final alpha = math.max(
          data[i + 3] * 1.0,
          math.max(redAlpha, blueAlpha),
        );
        result[i] = red.round().clamp(0, 255);
        result[i + 1] = data[i + 1];
        result[i + 2] = blue.round().clamp(0, 255);
        result[i + 3] = alpha.round().clamp(0, 255);
      }
    }
    return result;
  }

  /// 魚眼レンズ風の湾曲。中心を膨らませ、外側ほど圧縮して見せることで、
  /// 魚眼・広角レンズで撮影したような歪みを再現する。中心から各画素までの
  /// 距離（効く範囲の半径を1.0とする正規化距離）を[exponent]乗した位置から
  /// サンプリングする。[strength]（歪み）は-100〜100（%）で、正なら
  /// [exponent]が1より大きくなり、中心付近の画素ほど中心寄りから取られる
  /// ＝中心が膨らんで周辺が圧縮される魚眼（樽型）、負なら逆に中心がすぼまる
  /// （糸巻き型）。
  Uint8List applyFisheye(
    Uint8List data,
    int width,
    int height,
    double strength, {
    double radiusPercent = 100,
    double centerOffsetX = 0,
    double centerOffsetY = 0,
  }) {
    final amount = (strength / 100.0).clamp(-1.0, 1.0);
    if (amount == 0) return Uint8List.fromList(data);
    final exponent = amount > 0 ? 1.0 + amount * 1.5 : 1.0 + amount * 0.85;
    final cx = width / 2.0 + centerOffsetX;
    final cy = height / 2.0 + centerOffsetY;
    final maxCanvasR = math.sqrt(width * width + height * height) / 2.0;
    final maxR = math.max(
      1.0,
      maxCanvasR * (radiusPercent / 100.0).clamp(0.01, 1.0),
    );
    final result = Uint8List(data.length);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final nx = (x - cx) / maxR;
        final ny = (y - cy) / maxR;
        final r = math.sqrt(nx * nx + ny * ny);
        double srcX, srcY;
        if (r > 1.0) {
          final q = (y * width + x) * 4;
          result[q] = data[q];
          result[q + 1] = data[q + 1];
          result[q + 2] = data[q + 2];
          result[q + 3] = data[q + 3];
          continue;
        } else if (r <= 1e-6) {
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

  /// 眼鏡断層フィルター：塗った範囲（[maskData]、眼鏡のレンズ部分）を、
  /// 度の強い眼鏡のレンズ越しに見たように写す。[maskData]は[data]と同じ
  /// 大きさのrawRgbaで、アルファ0の画素は対象外。null・全画素透明なら
  /// 何もしない。
  ///
  /// 本物のレンズと同じく、レンズ越しの景色は**レンズの中心を基準に一様に**
  /// 縮む（凹レンズ＝近視用、[strength]が負）か、膨らむ（凸レンズ＝遠視用、
  /// 正）だけで、渦のように吸い込まれる歪みにはならない。縮んだ分レンズの
  /// 縁の外側の景色がレンズ内に入り込むので、顔の輪郭がレンズの縁で内側へ
  /// ずれる「断層」になる。縁へ行くほど少しだけ倍率が変わる（凹レンズの
  /// 樽型・凸レンズの糸巻き型の歪み）。
  ///
  /// マスクを4連結の連結成分（＝レンズ1枚）ごとに分け、各成分の重心
  /// （＋[centerOffsetX]・[centerOffsetY]）をレンズの中心とする。
  /// [strength]は-100〜100で、倍率は中心で1＋strength/400（-100で0.75倍、
  /// -50で約0.88倍＝強度近視の眼鏡程度）。マスクの縁が半透明の画素は、
  /// レンズ越しの色と元の色をアルファでブレンドする。
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
    // Magnification at the centre, and how much it changes towards the rim
    // (barrel distortion for a minus lens, pincushion for a plus lens).
    final centreScale = 1.0 + amount * 0.25;
    final rimChange = amount * 0.08;
    final result = Uint8List.fromList(data);
    final total = width * height;
    final visited = Uint8List(total);
    final queue = <int>[];
    final pixels = <int>[];
    for (int start = 0; start < total; start++) {
      if (visited[start] != 0) continue;
      if (maskData[start * 4 + 3] == 0) {
        visited[start] = 1;
        continue;
      }
      // このマスク画素を起点に4連結のフラッドフィルで連結成分を集める。
      queue
        ..clear()
        ..add(start);
      visited[start] = 1;
      pixels.clear();
      double sumX = 0, sumY = 0;
      while (queue.isNotEmpty) {
        final idx = queue.removeLast();
        final px = idx % width;
        final py = idx ~/ width;
        pixels.add(idx);
        sumX += px;
        sumY += py;
        void visit(int n) {
          if (visited[n] == 0 && maskData[n * 4 + 3] != 0) {
            visited[n] = 1;
            queue.add(n);
          }
        }

        if (px > 0) visit(idx - 1);
        if (px < width - 1) visit(idx + 1);
        if (py > 0) visit(idx - width);
        if (py < height - 1) visit(idx + width);
      }
      if (pixels.isEmpty) continue;
      final cx = (sumX / pixels.length) + centerOffsetX;
      final cy = (sumY / pixels.length) + centerOffsetY;
      double rimRadius = 1.0;
      for (final idx in pixels) {
        final dx = (idx % width) - cx;
        final dy = (idx ~/ width) - cy;
        final r = math.sqrt(dx * dx + dy * dy);
        if (r > rimRadius) rimRadius = r;
      }
      final sample = Uint8List(4);
      for (final idx in pixels) {
        final dx = (idx % width) - cx;
        final dy = (idx ~/ width) - cy;
        final rr = (dx * dx + dy * dy) / (rimRadius * rimRadius);
        // What is seen here lies 1/scale times as far from the centre.
        final scale = centreScale * (1 + rimChange * rr);
        _sampleBilinear(
          data,
          width,
          height,
          cx + dx / scale,
          cy + dy / scale,
          sample,
        );
        final dstIdx = idx * 4;
        // マスクの縁（フェザリング済みの半透明画素）は、レンズ越しの色と
        // 元の色をアルファでブレンドして継ぎ目を目立たなくする。
        final maskAlpha = maskData[dstIdx + 3] / 255.0;
        for (int c = 0; c < 4; c++) {
          result[dstIdx +
              c] = (sample[c] * maskAlpha + data[dstIdx + c] * (1 - maskAlpha))
              .round()
              .clamp(0, 255);
        }
      }
    }
    return result;
  }

  /// Bilinear sample of premultiplied RGBA at ([x], [y]) (pixel centres at
  /// integer coordinates), clamped to the image, into [out].
  static void _sampleBilinear(
    Uint8List data,
    int width,
    int height,
    double x,
    double y,
    Uint8List out,
  ) {
    final fx = x.clamp(0.0, width - 1.0);
    final fy = y.clamp(0.0, height - 1.0);
    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = math.min(x0 + 1, width - 1);
    final y1 = math.min(y0 + 1, height - 1);
    final tx = fx - x0;
    final ty = fy - y0;
    final i00 = (y0 * width + x0) * 4;
    final i10 = (y0 * width + x1) * 4;
    final i01 = (y1 * width + x0) * 4;
    final i11 = (y1 * width + x1) * 4;
    for (var c = 0; c < 4; c++) {
      final top = data[i00 + c] + (data[i10 + c] - data[i00 + c]) * tx;
      final bottom = data[i01 + c] + (data[i11 + c] - data[i01 + c]) * tx;
      out[c] = (top + (bottom - top) * ty).round().clamp(0, 255);
    }
  }

  Uint8List applyFilmGrain(
    Uint8List data,
    int width,
    int height,
    double strength, {
    int? seed,
  }) {
    final result = Uint8List.fromList(data);
    final rng = seed == null ? math.Random() : math.Random(seed);
    final amount = (strength.clamp(0.0, 1.0) * 255).round();
    for (var i = 0; i < result.length; i += 4) {
      if (result[i + 3] == 0) continue;
      final n = (_gaussianRandom(rng) * amount).round().clamp(-amount, amount);
      result[i] = (result[i] + n).clamp(0, 255);
      result[i + 1] = (result[i + 1] + n).clamp(0, 255);
      result[i + 2] = (result[i + 2] + n).clamp(0, 255);
    }
    return result;
  }

  Uint8List applyColorNoise(
    Uint8List data,
    int width,
    int height,
    double strength, {
    int? seed,
  }) {
    final result = Uint8List.fromList(data);
    final rng = seed == null ? math.Random() : math.Random(seed);
    final amount = (strength.clamp(0.0, 1.0) * 255).round();
    for (var i = 0; i < result.length; i += 4) {
      if (result[i + 3] == 0) continue;
      for (var c = 0; c < 3; c++) {
        final n = (_gaussianRandom(rng) * amount).round().clamp(
          -amount,
          amount,
        );
        result[i + c] = (result[i + c] + n).clamp(0, 255);
      }
    }
    return result;
  }

  Uint8List applyNoise(
    Uint8List data,
    int width,
    int height,
    double strength,
    NoiseType type,
  ) {
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
          result[idx] = (result[idx] + (220 - result[idx]) * alpha)
              .round()
              .clamp(0, 255);
          result[idx + 1] = (result[idx + 1] + (235 - result[idx + 1]) * alpha)
              .round()
              .clamp(0, 255);
          result[idx + 2] = (result[idx + 2] + (255 - result[idx + 2]) * alpha)
              .round()
              .clamp(0, 255);
        }
      }
    }
    return result;
  }

  /// アニメ調：色数を減らし（ポスタリゼーション）、色が変わる境目に
  /// 境界線を引く（[animeBorderLines]）。境界線は隣どうしの色の差が
  /// [borderThreshold]（CIELABのΔE）以上の所に、幅[borderWidth]（px）で、
  /// 境目の**暗い側**へ引く（線画の黒い線は太らない）。[edgeStrength]は
  /// 線の濃さ（0〜1、1で黒）。
  /// Anime style on the straight colour of the premultiplied layer (see
  /// [onStraightColour]): colours are quantised as painted, not darkened by
  /// their edge transparency.
  Uint8List applyAnimeStyle(
    Uint8List data,
    int width,
    int height, {
    required double strength,
    required int colorCount,
    required double edgeStrength,
    double borderWidth = 2,
    double borderThreshold = 20,
  }) => onStraightColour(
    data,
    (straight) => _animeStyleStraight(
      straight,
      width,
      height,
      strength: strength,
      colorCount: colorCount,
      edgeStrength: edgeStrength,
      borderWidth: borderWidth,
      borderThreshold: borderThreshold,
    ),
  );

  Uint8List _animeStyleStraight(
    Uint8List data,
    int width,
    int height, {
    required double strength,
    required int colorCount,
    required double edgeStrength,
    required double borderWidth,
    required double borderThreshold,
  }) {
    // ① 色数削減（ポスタリゼーション）
    final step = (256 / colorCount.clamp(2, 32)).round();
    final posterized = Uint8List.fromList(data);
    for (int i = 0; i < posterized.length; i += 4) {
      posterized[i] = ((posterized[i] / step).round() * step).clamp(0, 255);
      posterized[i + 1] = ((posterized[i + 1] / step).round() * step).clamp(
        0,
        255,
      );
      posterized[i + 2] = ((posterized[i + 2] / step).round() * step).clamp(
        0,
        255,
      );
    }
    // ② 色が変わる境目に境界線
    if (edgeStrength <= 0 || borderWidth <= 0) return posterized;
    // Borders are found in the picture as it looks on white paper, so a
    // shape on a transparent layer has one along its edge too (its
    // see-through pixels carry no colour of their own).
    final lines = animeBorderLines(
      data,
      width,
      height,
      lineWidth: borderWidth,
      threshold: borderThreshold,
    );
    final darkness = edgeStrength.clamp(0.0, 1.0);
    for (var p = 0; p < lines.coverage.length; p++) {
      final cover = lines.coverage[p];
      if (cover <= 0) continue;
      final i = p * 4;
      if (posterized[i + 3] == 0) continue;
      // Only the darker colour's share of an anti-aliased pixel darkens.
      for (var c = 0; c < 3; c++) {
        final ink = math.max(0.0, posterized[i + c] - lines.light[p * 3 + c]);
        posterized[i + c] = (posterized[i + c] - ink * darkness * cover)
            .round()
            .clamp(0, 255);
      }
    }
    return posterized;
  }

  /// 縁取りフィルター（プレビュー・単一レイヤー合成用）：選択レイヤーの
  /// 描画内容（不透明部分）はそのまま残し、その周囲へ指定色・指定px幅の
  /// 縁取りを重ねた画像を返す。プレビューサムネイルの生成にのみ使用する
  /// （実際の本適用は、選択レイヤーを書き換えずリング部分だけを新規
  /// レイヤーへ描画するため[applyOutlineLayer]を使う）。
  Uint8List applyOutline(
    Uint8List data,
    int width,
    int height, {
    required int color,
    required double widthPx,
    double erosion = 0,
  }) => _outlineFill(
    data,
    width,
    height,
    color: color,
    widthPx: widthPx,
    erosion: erosion,
    keepSource: true,
  );

  /// 縁取りフィルター（本適用用）：選択レイヤーの描画内容はコピーせず、
  /// 縁取りリング部分だけを描画した画像（それ以外は透明）を返す。
  /// 選択レイヤーの直下へ挿入する新規レイヤーのピクセルデータとして使う
  /// （filter_panel.dartの`_applyToFrame`参照）。
  Uint8List applyOutlineLayer(
    Uint8List data,
    int width,
    int height, {
    required int color,
    required double widthPx,
    double erosion = 0,
  }) => _outlineFill(
    data,
    width,
    height,
    color: color,
    widthPx: widthPx,
    erosion: erosion,
    keepSource: false,
  );

  /// 縁取り計算の共通処理。[keepSource]がtrueなら元の絵を縁取りの上に
  /// 重ねた結果を返す（[applyOutline]、適用後の見た目と同じ）。falseなら
  /// 縁取りリング部分だけを書き込み、それ以外は透明のまま返す
  /// （[applyOutlineLayer]）。形と見なした画素はリングの対象から除外する
  /// ため、元の描画内容がリングで隠れることはない。
  /// [color]はARGB32形式のint値（FilterDef.outlineColorと同じ表現）。
  ///
  /// [erosion]（0〜100）は、どこまで薄い画素を「形」と見なすかのしきい値。
  /// 0では不透明度10より濃い画素がすべて形で、縁取りはその外側だけに付く
  /// （従来どおり）。上げるほど薄い画素を形から外すので、縁取りがぼかした
  /// 縁の薄い部分の下まで食い込み、見えている本体に沿うようになる
  /// （縁取りは元のレイヤーの下に置くので、薄い部分から透けて見える）。
  /// 100では完全に不透明な画素だけが形になる。
  Uint8List _outlineFill(
    Uint8List data,
    int width,
    int height, {
    required int color,
    required double widthPx,
    required bool keepSource,
    double erosion = 0,
  }) {
    final radius = widthPx.round().clamp(1, 100);
    final result = Uint8List(data.length);
    final ca = (color >> 24) & 0xFF;
    final cr = (color >> 16) & 0xFF;
    final cg = (color >> 8) & 0xFF;
    final cb = color & 0xFF;
    final alphaThreshold = (10 + (erosion / 100).clamp(0.0, 1.0) * (254 - 10))
        .round();

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
        if (data[idx + 3] > alphaThreshold) continue; // 形の中には付けない
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
          // Premultiplied, like the layers.
          result[idx] = (cr * ca + 127) ~/ 255;
          result[idx + 1] = (cg * ca + 127) ~/ 255;
          result[idx + 2] = (cb * ca + 127) ~/ 255;
          result[idx + 3] = ca;
        }
      }
    }
    if (!keepSource) return result;
    // The preview shows the picture over its outline, as the applied result
    // (the outline on its own layer beneath) looks.
    for (var i = 0; i < result.length; i += 4) {
      final keep = 255 - data[i + 3];
      for (var c = 0; c < 4; c++) {
        result[i + c] = (data[i + c] + (result[i + c] * keep + 127) ~/ 255)
            .clamp(0, 255);
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
  /// 周辺減光（ビネット）：画面中心からの距離に応じて四隅を[color]（既定は
  /// 黒）で覆う、イラスト・漫画の演出で定番の効果。キャンバス全体が対象で、
  /// 透明な所にも四隅の影を描く（描いた絵の上だけに限らない）。中心からの
  /// 距離計算のみの単純な1パス処理で負荷は軽い。[strength]（濃さ）は
  /// 0〜100（%）で四隅の暗さ、[range]（範囲）は0〜100（%）で四隅から中心へ
  /// 向かってどこまで暗くするか（既定40＝中心から6割の所までは変えない）。
  /// [color]に黒以外を指定すると、暗くするのではなく
  /// 指定色を周辺へかぶせる（夕焼けオレンジ・夜の青など）演出にも使える。
  /// [onlyOnPaint]がtrueなら描いた絵の上だけを、その不透明度のまま暗くする
  /// （ブラウン管の画面の縁など、絵の一部として使うとき）。
  Uint8List applyVignette(
    Uint8List data,
    int width,
    int height,
    double strength, {
    int color = 0xFF000000,
    bool onlyOnPaint = false,
    double range = 40,
  }) {
    final amount = (strength / 100.0).clamp(0.0, 1.0);
    final reach = (range / 100.0).clamp(0.0, 1.0);
    if (amount <= 0 || reach <= 0) return Uint8List.fromList(data);
    final result = Uint8List.fromList(data);
    final cr = (color >> 16) & 0xFF;
    final cg = (color >> 8) & 0xFF;
    final cb = color & 0xFF;
    final cx = width / 2.0;
    final cy = height / 2.0;
    // 対角線の半分を最大距離とし、中心付近は影響なし・外周に近づくほど
    // 指定色へ寄っていくようにする（中心から1−範囲までは変化なし、そこから
    // 外周へ滑らかに変化する古典的なビネット形状）。
    final maxDist = math.sqrt(cx * cx + cy * cy);
    final innerRadius = 1 - reach;
    for (int y = 0; y < height; y++) {
      final dy = (y + .5 - cy) / maxDist;
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        final a = data[idx + 3];
        if (onlyOnPaint && a == 0) continue;
        final dx = (x + .5 - cx) / maxDist;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= innerRadius) continue;
        final t = ((dist - innerRadius) / (1.0 - innerRadius)).clamp(0.0, 1.0);
        // A smooth ramp, so the shadow has no visible inner edge.
        final mix = t * t * (3 - 2 * t) * amount;
        if (onlyOnPaint) {
          // Towards the colour at this pixel's own opacity (premultiplied).
          result[idx] =
              (data[idx] + (premultipliedChannel(cr, a) - data[idx]) * mix)
                  .round()
                  .clamp(0, 255);
          result[idx + 1] =
              (data[idx + 1] +
                      (premultipliedChannel(cg, a) - data[idx + 1]) * mix)
                  .round()
                  .clamp(0, 255);
          result[idx + 2] =
              (data[idx + 2] +
                      (premultipliedChannel(cb, a) - data[idx + 2]) * mix)
                  .round()
                  .clamp(0, 255);
          continue;
        }
        // The shadow, of opacity [mix], laid over the pixel (premultiplied
        // source-over): on transparent canvas it is the shadow itself.
        final keep = 1 - mix;
        result[idx] = (cr * mix + data[idx] * keep).round().clamp(0, 255);
        result[idx + 1] = (cg * mix + data[idx + 1] * keep).round().clamp(
          0,
          255,
        );
        result[idx + 2] = (cb * mix + data[idx + 2] * keep).round().clamp(
          0,
          255,
        );
        result[idx + 3] = (255 * mix + a * keep).round().clamp(0, 255);
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
  Uint8List applyMonochrome(
    Uint8List data,
    int width,
    int height,
    double amount, {
    int targetColor = 0xFFFFFFFF,
  }) {
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

  /// 描画フィルター > 質感変更：画素の明度をもとに選択中の配色
  /// （[preset]のカラーストップ、[auroraHologramStops]参照）へ置き換え、
  /// 元の色と[strength]でブレンドする。strength=100では元絵の明度階調を
  /// 配色帯へ100%マッピングし、白いハイライトは帯の右端色になる。
  /// [strength]（0〜100、ブレンド比率）・[brightness]・[saturation]
  /// （いずれも-100〜100、グラデーションマップ結果へのHSL調整量）は独立に
  /// 効く。配色パターン自体はプリセットのみ選択可能（ユーザー個別指定不可）。
  /// On the straight colour of the premultiplied layer (see
  /// [onStraightColour]).
  Uint8List applyAuroraHologram(
    Uint8List data,
    int width,
    int height, {
    required double strength,
    required double brightness,
    required double saturation,
    required AuroraHologramPreset preset,
    bool keepLines = false,
  }) => onStraightColour(
    data,
    (straight) => _auroraHologramStraight(
      straight,
      width,
      height,
      strength: strength,
      brightness: brightness,
      saturation: saturation,
      preset: preset,
      keepLines: keepLines,
    ),
  );

  /// How much of each pixel is line art drawn on the layer (0 to 1): a
  /// dark pixel (luminance under 100) with something clearly lighter (by 30
  /// or more) within 5 px on both sides of it in some direction, as across
  /// a line. The edge of a wide dark area is lighter on one side only, so
  /// shadows and dark clothes are not lines; an outline next to shading is
  /// still lighter on both sides. See-through pixels count as white paper.
  /// The share fades out towards the lighter, anti-aliased edge of the line.
  /// [data] is straight RGBA.
  Float32List _lineArtShare(Uint8List data, int width, int height) {
    final n = width * height;
    final share = Float32List(n);
    final luma = Float32List(n);
    for (var p = 0; p < n; p++) {
      final i = p * 4;
      luma[p] = data[i + 3] == 0
          ? 255
          : data[i] * .299 + data[i + 1] * .587 + data[i + 2] * .114;
    }
    const reach = 5;
    double lumaAt(int x, int y, int dx, int dy, int k) {
      if (k <= 0) return luma[y * width + x];
      return luma[(y + dy * k) * width + x + dx * k];
    }

    // A line ends in a step: most of the way up to the lighter side is
    // climbed within the last two pixels (a pen's soft edge), where shading
    // that darkens towards a shape's edge climbs gradually. 0: no step; 1: a
    // step out to transparency; 2: a step up to a lighter surface.
    int stepWithin(int x, int y, int dx, int dy, double than) {
      for (var k = 1; k <= reach; k++) {
        final qx = x + dx * k, qy = y + dy * k;
        if (qx < 0 || qy < 0 || qx >= width || qy >= height) return 0;
        final q = qy * width + qx;
        final here = luma[q];
        if (here < than) continue;
        final rise = here - luma[y * width + x];
        if (here - lumaAt(x, y, dx, dy, k - 2) < rise * .75) return 0;
        return data[q * 4 + 3] == 0 ? 1 : 2;
      }
      return 0;
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = y * width + x;
        if (data[p * 4 + 3] == 0 || luma[p] >= 100) continue;
        final than = luma[p] + 20;
        var line = false;
        for (final (dx, dy) in const [(1, 0), (0, 1), (1, 1), (1, -1)]) {
          final ahead = stepWithin(x, y, dx, dy, than);
          if (ahead == 0) continue;
          final behind = stepWithin(x, y, -dx, -dy, than);
          // Line art borders a surface on at least one side; a thin dark
          // shape alone on the transparency is a surface itself.
          if (behind != 0 && (ahead == 2 || behind == 2)) {
            line = true;
            break;
          }
        }
        if (line) share[p] = ((100 - luma[p]) / 40).clamp(0.0, 1.0);
      }
    }
    // Lines run on; a few pixels on their own are where shading turns
    // steeply at a shape's edge.
    final seen = Uint8List(n);
    final stack = <int>[], piece = <int>[];
    for (var start = 0; start < n; start++) {
      if (share[start] == 0 || seen[start] != 0) continue;
      seen[start] = 1;
      stack.add(start);
      piece.clear();
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        piece.add(p);
        final px = p % width, py = p ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final qx = px + dx, qy = py + dy;
            if (qx < 0 || qy < 0 || qx >= width || qy >= height) continue;
            final q = qy * width + qx;
            if (share[q] == 0 || seen[q] != 0) continue;
            seen[q] = 1;
            stack.add(q);
          }
        }
      }
      if (piece.length < 24) {
        for (final p in piece) {
          share[p] = 0;
        }
      }
    }
    return share;
  }

  Uint8List _auroraHologramStraight(
    Uint8List data,
    int width,
    int height, {
    required double strength,
    required double brightness,
    required double saturation,
    required AuroraHologramPreset preset,
    bool keepLines = false,
  }) {
    final amount = (strength / 100).clamp(0.0, 1.0);
    if (amount <= 0) return Uint8List.fromList(data);
    final stops = auroraHologramStops(preset);
    // Line art drawn on the layer keeps its own colour: the texture goes on
    // the surfaces, not on the ink outlining them.
    final lines = keepLines ? _lineArtShare(data, width, height) : null;
    final result = Uint8List.fromList(data);
    // 同じ明度の画素は同じ結果になるため、256階調ぶんだけ事前計算して
    // キャッシュする（フルHD相当の画素数でも1画素ずつHSL変換し直すより
    // 大幅に軽い）。
    final cache = List<(int, int, int)?>.filled(256, null);
    // Material presets still use luminance as their only colour coordinate,
    // but preserve a small amount of source micro-contrast. This keeps sphere
    // volume and fabric folds/speculars from flattening into a colour strip.
    final materialPreset =
        preset == AuroraHologramPreset.auroraPastel ||
        preset == AuroraHologramPreset.darkRainbow;
    final preserveLuma = switch (preset) {
      // Transparent-film look: retain substantially more of the source
      // relief so folds read through the pastel interference colour.
      AuroraHologramPreset.auroraPastel => 0.08,
      AuroraHologramPreset.darkRainbow => 0.16,
      _ => 0.0,
    };
    final sourceLumaBlend = switch (preset) {
      // Blend only neutral source luminance, never source hue. This gives the
      // iridescent map a translucent-film appearance without turning it into
      // ordinary opacity mixing.
      AuroraHologramPreset.auroraPastel => 0.03,
      _ => 0.0,
    };

    // Aurora Pastel is a material filter, not only a gradient-map preset.
    // Estimate local surface orientation from source luminance. Fold edges get
    // a narrow white specular core and a chromatic interference shoulder.
    // Broad faces stay translucent/near-neutral, matching clear holographic
    // vinyl instead of painting every luminance band a pastel colour.
    final holographicFilm = preset == AuroraHologramPreset.auroraPastel;
    int sourceLumaAt(int x, int y) {
      final sx = x < 0 ? 0 : (x >= width ? width - 1 : x);
      final sy = y < 0 ? 0 : (y >= height ? height - 1 : y);
      final p = (sy * width + sx) * 4;
      return (data[p] * 0.299 + data[p + 1] * 0.587 + data[p + 2] * 0.114)
          .round();
    }

    for (int i = 0; i < data.length; i += 4) {
      if (data[i + 3] == 0) continue;
      final r = data[i], g = data[i + 1], b = data[i + 2];
      final luminanceIdx = ((r * 0.299 + g * 0.587 + b * 0.114)).round().clamp(
        0,
        255,
      );
      var mapped = cache[luminanceIdx];
      if (mapped == null) {
        final (mr, mg, mb) = _sampleGradient(stops, luminanceIdx / 255.0);
        mapped = _adjustHsl(
          mr,
          mg,
          mb,
          saturationDelta: saturation / 100,
          lightnessDelta: brightness / 100,
        );
        cache[luminanceIdx] = mapped;
      }
      var outR = mapped.$1.toDouble();
      var outG = mapped.$2.toDouble();
      var outB = mapped.$3.toDouble();
      if (materialPreset) {
        // Re-introduce only luminance detail, never the source hue. The
        // gradient map remains deterministic for colour while highlights,
        // rounded shading and cloth creases retain their material relief.
        final mappedLuma = outR * 0.299 + outG * 0.587 + outB * 0.114;
        final lumaDelta = (luminanceIdx - mappedLuma) * preserveLuma;
        outR = (outR + lumaDelta).clamp(0.0, 255.0);
        outG = (outG + lumaDelta).clamp(0.0, 255.0);
        outB = (outB + lumaDelta).clamp(0.0, 255.0);
        if (sourceLumaBlend > 0.0) {
          final neutral = luminanceIdx.toDouble();
          outR += (neutral - outR) * sourceLumaBlend;
          outG += (neutral - outG) * sourceLumaBlend;
          outB += (neutral - outB) * sourceLumaBlend;
        }
      }

      if (holographicFilm) {
        final pixel = i ~/ 4;
        final x = pixel % width;
        final y = pixel ~/ width;
        // Use a wider derivative than a single pixel. It reacts to actual
        // cloth/sphere planes instead of texture noise, so reflections form
        // coherent facets rather than glittery outlines.
        final gx =
            sourceLumaAt(x + 2, y) -
            sourceLumaAt(x - 2, y) +
            sourceLumaAt(x + 4, y) -
            sourceLumaAt(x - 4, y);
        final gy =
            sourceLumaAt(x, y + 2) -
            sourceLumaAt(x, y - 2) +
            sourceLumaAt(x, y + 4) -
            sourceLumaAt(x, y - 4);
        final edge =
            math.sqrt((gx * gx + gy * gy).toDouble()).clamp(0.0, 180.0) / 180.0;
        // Line art drawn on the same layer is ink, not a fold of the film:
        // next to near-black ink the edge would light a white core and a
        // rainbow fringe along both sides of every line (a doubled,
        // glittering outline). Reflections fade out beside dark ink.
        var darkest = luminanceIdx;
        for (final (dx, dy) in const [
          (2, 0),
          (-2, 0),
          (4, 0),
          (-4, 0),
          (0, 2),
          (0, -2),
          (0, 4),
          (0, -4),
        ]) {
          darkest = math.min(darkest, sourceLumaAt(x + dx, y + dy));
        }
        final besideInk = ((darkest - 40) / 70).clamp(0.0, 1.0);

        // A second, much wider derivative approximates the orientation of the
        // whole material face. Blend it with the local fold normal so a sphere
        // gets a continuous curved reflection while cloth keeps coherent
        // reflection planes instead of breaking into tiny edge-colour bands.
        final planeGx =
            sourceLumaAt(x + 8, y) -
            sourceLumaAt(x - 8, y) +
            sourceLumaAt(x + 14, y) -
            sourceLumaAt(x - 14, y);
        final planeGy =
            sourceLumaAt(x, y + 8) -
            sourceLumaAt(x, y - 8) +
            sourceLumaAt(x, y + 14) -
            sourceLumaAt(x, y - 14);
        final planeStrength =
            math
                .sqrt((planeGx * planeGx + planeGy * planeGy).toDouble())
                .clamp(0.0, 220.0) /
            220.0;
        final localAngle = math.atan2(gy.toDouble(), gx.toDouble());
        final planeAngle = math.atan2(planeGy.toDouble(), planeGx.toDouble());
        final orientationBlend = (0.28 + planeStrength * 0.58).clamp(
          0.28,
          0.78,
        );
        final vx =
            math.cos(localAngle) * (1.0 - orientationBlend) +
            math.cos(planeAngle) * orientationBlend;
        final vy =
            math.sin(localAngle) * (1.0 - orientationBlend) +
            math.sin(planeAngle) * orientationBlend;
        final materialAngle = math.atan2(vy, vx);

        // Measure how consistently the wide material face points in one
        // direction. Cloth facets should hold one reflection family across
        // the face, while rounded surfaces keep a continuous orientation.
        final planeCoherence = (planeStrength * (1.0 - edge * 0.34)).clamp(
          0.0,
          1.0,
        );
        // Quantize only coherent planar regions. This prevents a cloth facet
        // from cycling through several rainbow colours because of tiny luma
        // changes, but leaves spheres/soft curves continuous.
        const facetSteps = 12.0;
        final rawMaterialPhase = (materialAngle + math.pi) / (2 * math.pi);
        final facetPhase =
            (rawMaterialPhase * facetSteps).roundToDouble() / facetSteps;
        final coherentPhase =
            rawMaterialPhase +
            (facetPhase - rawMaterialPhase) * planeCoherence * 0.72;

        final localMean =
            (sourceLumaAt(x - 3, y) +
                sourceLumaAt(x + 3, y) +
                sourceLumaAt(x, y - 3) +
                sourceLumaAt(x, y + 3)) /
            4.0;
        final ridge = ((luminanceIdx - localMean) / 42.0).clamp(0.0, 1.0);

        // Reference film has broad pale reflective faces plus a much sharper
        // white core on fold ridges. The face term gives reflection area;
        // ridge keeps the brightest highlight crisp instead of foggy.
        final faceSpecular = math.pow(edge, 1.65).toDouble() * 0.30;
        final ridgeSpecular = math.pow(ridge, 2.25).toDouble() * 0.80;
        final specular =
            (faceSpecular + ridgeSpecular - faceSpecular * ridgeSpecular).clamp(
              0.0,
              0.84,
            ) *
            besideInk;
        outR += (255.0 - outR) * specular;
        outG += (255.0 - outG) * specular;
        outB += (255.0 - outB) * specular;

        // Interference colour follows plane direction, but remains strongest
        // beside (not inside) the white ridge. This creates the reference
        // material's cyan/pink/violet edge flashes without rainbow contouring.
        if (edge > 0.075) {
          final phase = coherentPhase.clamp(0.0, 1.0);
          const interferenceStops = <(double, int, int, int)>[
            // Luminous film reflections: chromatic, but mixed toward the
            // reflected light so they read as iridescence rather than paint.
            (0.00, 126, 232, 250), // clear cyan
            (0.15, 126, 241, 221), // aqua-mint
            (0.29, 139, 196, 249), // sky/electric blue
            (0.44, 190, 164, 247), // luminous violet
            (0.59, 244, 157, 228), // pearly magenta
            (0.73, 251, 183, 215), // rose-pink
            (0.87, 255, 245, 174), // pale spectral yellow
            (1.00, 150, 230, 250), // cyan return
          ];
          final spectral = _sampleGradient(
            interferenceStops,
            phase.clamp(0.0, 1.0),
          );
          final shoulder = (1.0 - ridge * 0.82).clamp(0.12, 1.0);
          // Preserve quiet transparent faces. Strong colour appears mainly
          // where a coherent facet catches the light; weak/flat regions keep
          // the pale transmission map instead of receiving a uniform rainbow.
          final reflectionGate = (edge * 0.62 + planeStrength * 0.38).clamp(
            0.0,
            1.0,
          );
          final gatedReflection = math.pow(reflectionGate, 1.35).toDouble();
          final colourMix =
              ((edge - 0.055) / 0.945).clamp(0.0, 1.0) *
              (0.62 + planeStrength * 0.38) *
              gatedReflection *
              shoulder *
              besideInk *
              0.52;
          outR += (spectral.$1 - outR) * colourMix;
          outG += (spectral.$2 - outG) * colourMix;
          outB += (spectral.$3 - outB) * colourMix;

          // Keep the body pale and transparent, but let a very narrow fringe
          // beside the white reflection become genuinely high-chroma.
          final fringe =
              math
                  .pow((edge * 0.70 + ridge * 0.30).clamp(0.0, 1.0), 3.1)
                  .toDouble() *
              (1.0 - math.pow(ridge.clamp(0.0, 1.0), 5.0).toDouble()) *
              (0.52 + planeStrength * 0.48);
          final spectralMean = (spectral.$1 + spectral.$2 + spectral.$3) / 3.0;
          final vividR = (spectralMean + (spectral.$1 - spectralMean) * 1.55)
              .clamp(0.0, 255.0);
          final vividG = (spectralMean + (spectral.$2 - spectralMean) * 1.55)
              .clamp(0.0, 255.0);
          final vividB = (spectralMean + (spectral.$3 - spectralMean) * 1.55)
              .clamp(0.0, 255.0);
          final fringeMix = (fringe * 0.54).clamp(0.0, 0.46) * besideInk;
          outR += (vividR - outR) * fringeMix;
          outG += (vividG - outG) * fringeMix;
          outB += (vividB - outB) * fringeMix;
        }
      }
      final mix = amount * (1 - (lines?[i ~/ 4] ?? 0));
      result[i] = (r + (outR - r) * mix).round().clamp(0, 255);
      result[i + 1] = (g + (outG - g) * mix).round().clamp(0, 255);
      result[i + 2] = (b + (outB - b) * mix).round().clamp(0, 255);
    }
    return result;
  }

  /// [stops]（明度0.0〜1.0の位置とRGB色のペア。位置は昇順）を[t]（0.0〜1.0）
  /// で線形補間する。
  (int, int, int) _sampleGradient(
    List<(double, int, int, int)> stops,
    double t,
  ) {
    final clamped = t.clamp(0.0, 1.0);
    for (int i = 0; i < stops.length - 1; i++) {
      final (pos0, r0, g0, b0) = stops[i];
      final (pos1, r1, g1, b1) = stops[i + 1];
      if (clamped <= pos1 || i == stops.length - 2) {
        final span = pos1 - pos0;
        final localT = span <= 0
            ? 0.0
            : ((clamped - pos0) / span).clamp(0.0, 1.0);
        return (
          (r0 + (r1 - r0) * localT).round(),
          (g0 + (g1 - g0) * localT).round(),
          (b0 + (b1 - b0) * localT).round(),
        );
      }
    }
    final (_, r, g, b) = stops.last;
    return (r, g, b);
  }

  /// RGB色をHSLへ変換し、彩度・明度へそれぞれ[saturationDelta]・
  /// [lightnessDelta]（-1.0〜1.0）を加算してRGBへ戻す。
  (int, int, int) _adjustHsl(
    int r,
    int g,
    int b, {
    required double saturationDelta,
    required double lightnessDelta,
  }) {
    final (h, s, l) = _rgbToHsl(r / 255.0, g / 255.0, b / 255.0);
    final newS = (s + saturationDelta).clamp(0.0, 1.0);
    final newL = (l + lightnessDelta).clamp(0.0, 1.0);
    final (nr, ng, nb) = _hslToRgb(h, newS, newL);
    return (
      (nr * 255).round().clamp(0, 255),
      (ng * 255).round().clamp(0, 255),
      (nb * 255).round().clamp(0, 255),
    );
  }

  (double, double, double) _rgbToHsl(double r, double g, double b) {
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    final l = (maxV + minV) / 2;
    if (maxV == minV) return (0, 0, l);
    final d = maxV - minV;
    final s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
    double h;
    if (maxV == r) {
      h = ((g - b) / d) % 6;
    } else if (maxV == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h *= 60;
    if (h < 0) h += 360;
    return (h, s, l);
  }

  (double, double, double) _hslToRgb(double h, double s, double l) {
    if (s == 0) return (l, l, l);
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    final hk = h / 360;
    double hue2rgb(double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    return (hue2rgb(hk + 1 / 3), hue2rgb(hk), hue2rgb(hk - 1 / 3));
  }

  /// 二値化：輝度が[threshold]（0〜255）以上の画素を白、未満を黒に分ける。
  /// アルファはそのまま維持する。色調調整・単色化・「明度で透過」と組み合わせて
  /// 線画抽出に使うことを想定している。
  /// Threshold on the straight colour (see [onStraightColour]): a
  /// half-transparent edge turns black or white like the solid paint.
  Uint8List applyThreshold(
    Uint8List data,
    int width,
    int height,
    double threshold,
  ) => onStraightColour(
    data,
    (straight) => _thresholdStraight(straight, width, height, threshold),
  );

  Uint8List _thresholdStraight(
    Uint8List data,
    int width,
    int height,
    double threshold,
  ) {
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
    if (saturation == 0 && brightness == 0 && contrast == 0) {
      return Uint8List.fromList(data);
    }
    final result = Uint8List.fromList(data);
    final satFactor = 1.0 + saturation / 100.0;
    final briOffset = brightness / 100.0 * 255.0;
    // 古典的なコントラスト補正式：F = 259*(C+255) / (255*(259-C))
    final contrastScaled = (contrast / 100.0 * 255.0).clamp(-255.0, 255.0);
    final conF =
        (259 * (contrastScaled + 255)) / (255 * (259 - contrastScaled));
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
  /// Retro anime on the straight colour of the premultiplied layer (see
  /// [onStraightColour]).
  Uint8List applyRetroAnime(
    Uint8List data,
    int width,
    int height,
    double strength, {
    int? seed,
  }) => onStraightColour(
    data,
    (straight) =>
        _retroAnimeStraight(straight, width, height, strength, seed: seed),
  );

  Uint8List _retroAnimeStraight(
    Uint8List data,
    int width,
    int height,
    double strength, {
    int? seed,
  }) {
    // Reference workflow: colour overlays -> low-contrast merge -> unsharp ->
    // glow -> shifted edge/cel overlap -> degraded glass/glitch -> final
    // colour correction -> mixed monochrome/colour noise. The UI strength
    // controls how far the flattened result is mixed back into the source.
    // NIARIM intentionally uses +5% saturation at the final colour-correction
    // stage (the referenced recipe uses -2%).
    final amount = (strength / 100.0).clamp(0.0, 1.0);
    if (amount <= 0) return Uint8List.fromList(data);

    final original = Uint8List.fromList(data);
    var work = Uint8List.fromList(data);

    // 1) Pale cyan, Difference, 11%.
    const cyan = (r: 180, g: 229, b: 232);
    for (var i = 0; i < work.length; i += 4) {
      if (work[i + 3] == 0) continue;
      final dr = (work[i] - cyan.r).abs();
      final dg = (work[i + 1] - cyan.g).abs();
      final db = (work[i + 2] - cyan.b).abs();
      work[i] = (work[i] * 0.89 + dr * 0.11).round().clamp(0, 255);
      work[i + 1] = (work[i + 1] * 0.89 + dg * 0.11).round().clamp(0, 255);
      work[i + 2] = (work[i + 2] * 0.89 + db * 0.11).round().clamp(0, 255);
    }

    // 2) Warm beige, Multiply, 85%.
    const beige = (r: 244, g: 222, b: 183);
    for (var i = 0; i < work.length; i += 4) {
      if (work[i + 3] == 0) continue;
      final mr = work[i] * beige.r / 255.0;
      final mg = work[i + 1] * beige.g / 255.0;
      final mb = work[i + 2] * beige.b / 255.0;
      work[i] = (work[i] * 0.15 + mr * 0.85).round().clamp(0, 255);
      work[i + 1] = (work[i + 1] * 0.15 + mg * 0.85).round().clamp(0, 255);
      work[i + 2] = (work[i + 2] * 0.15 + mb * 0.85).round().clamp(0, 255);
    }

    // 3) Inverted merged copy at 5% to soften contrast.
    for (var i = 0; i < work.length; i += 4) {
      if (work[i + 3] == 0) continue;
      work[i] = (work[i] * 0.95 + (255 - work[i]) * 0.05).round();
      work[i + 1] = (work[i + 1] * 0.95 + (255 - work[i + 1]) * 0.05).round();
      work[i + 2] = (work[i + 2] * 0.95 + (255 - work[i + 2]) * 0.05).round();
    }

    // 4) Unsharp mask: radius 5 px, amount 70%.
    work = applyUnsharpMask(work, width, height, 5, 0.70);

    // 5) Glow: Gaussian radius 10 px, merged at 27%.
    final glow = applyGaussianBlur(work, width, height, 10);
    for (var i = 0; i < work.length; i += 4) {
      if (work[i + 3] == 0) continue;
      for (var ch = 0; ch < 3; ch++) {
        work[i + ch] = (work[i + ch] * 0.73 + glow[i + ch] * 0.27)
            .round()
            .clamp(0, 255);
      }
    }

    // 6) Cel-overlap impression: shifted Sobel edge, Multiply at 28%.
    final edges = _sobelEdge(work, width, height);
    final edged = Uint8List.fromList(work);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final dst = (y * width + x) * 4;
        if (work[dst + 3] == 0) continue;
        final sx = (x - 1).clamp(0, width - 1);
        final sy = (y - 1).clamp(0, height - 1);
        final e = edges[sy * width + sx] / 255.0;
        final multiplier = 1.0 - e * 0.28;
        edged[dst] = (work[dst] * multiplier).round().clamp(0, 255);
        edged[dst + 1] = (work[dst + 1] * multiplier).round().clamp(0, 255);
        edged[dst + 2] = (work[dst + 2] * multiplier).round().clamp(0, 255);
      }
    }
    work = edged;

    // 7/8) Degraded glass + 2 px RGB glitch. A deterministic seed keeps
    // preview, apply and recorded replay visually stable.
    final rng = math.Random(seed ?? 43098);
    final glass = Uint8List.fromList(work);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (work[i + 3] == 0) continue;
        final jitterX = (rng.nextDouble() * 7 - 3.5).round();
        final jitterY = (rng.nextDouble() * 7 - 3.5).round();
        final sx = (x + jitterX).clamp(0, width - 1);
        final sy = (y + jitterY).clamp(0, height - 1);
        final s = (sy * width + sx) * 4;
        for (var ch = 0; ch < 3; ch++) {
          glass[i + ch] = (work[i + ch] * 0.75 + work[s + ch] * 0.25).round();
        }
      }
    }
    // The glitch reads the glass result only (never a pixel this pass has
    // already shifted, which smeared one blue along whole rows).
    final degraded = Uint8List.fromList(glass);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (glass[i + 3] == 0) continue;
        final rx = (x + 2).clamp(0, width - 1);
        final bx = (x - 2).clamp(0, width - 1);
        degraded[i] = glass[(y * width + rx) * 4];
        degraded[i + 2] = glass[(y * width + bx) * 4 + 2];
      }
    }
    work = degraded;

    // 9) Contrast -3%, saturation +5% (user-requested deviation from recipe).
    for (var i = 0; i < work.length; i += 4) {
      if (work[i + 3] == 0) continue;
      var r = 128 + (work[i] - 128) * 0.97;
      var g = 128 + (work[i + 1] - 128) * 0.97;
      var b = 128 + (work[i + 2] - 128) * 0.97;
      final gray = r * 0.299 + g * 0.587 + b * 0.114;
      r = gray + (r - gray) * 1.05;
      g = gray + (g - gray) * 1.05;
      b = gray + (b - gray) * 1.05;
      work[i] = r.round().clamp(0, 255);
      work[i + 1] = g.round().clamp(0, 255);
      work[i + 2] = b.round().clamp(0, 255);
    }

    // 10) Overlay-like neutral grain: grayscale body plus sparse colour grain.
    final grayGrain = applyFilmGrain(
      work,
      width,
      height,
      0.17,
      seed: seed ?? 43098,
    );
    final colorGrain = applyColorNoise(
      grayGrain,
      width,
      height,
      0.015,
      seed: (seed ?? 43098) + 1,
    );
    for (var i = 0; i < work.length; i += 4) {
      if (work[i + 3] == 0) continue;
      for (var ch = 0; ch < 3; ch++) {
        final grain = colorGrain[i + ch];
        final base = work[i + ch];
        final overlay = base < 128
            ? (2 * base * grain / 255.0)
            : (255 - 2 * (255 - base) * (255 - grain) / 255.0);
        work[i + ch] = (base * 0.25 + overlay * 0.75).round().clamp(0, 255);
      }
    }

    final result = Uint8List.fromList(original);
    for (var i = 0; i < result.length; i += 4) {
      if (original[i + 3] == 0) continue;
      for (var ch = 0; ch < 3; ch++) {
        result[i + ch] =
            (original[i + ch] + (work[i + ch] - original[i + ch]) * amount)
                .round()
                .clamp(0, 255);
      }
    }
    return result;
  }

  /// ブラウン管：電子ビームのにじみ（横方向のぼかし）→色ずれ（RとBの横ずれ）
  /// →RGBの蛍光体の縦じま＋走査線→周辺減光の順に重ねる。VHS（時間で揺れる
  /// トラッキング・色のにじみ・ノイズ）とは違い、画面そのものの構造を見せる。
  /// [strength]は蛍光体・走査線・周辺減光の濃さ、[aberration]は色ずれ
  /// （100で4px）、[bleed]はにじみ（100で半径4pxの横ぼかし）。いずれも0〜100。
  Uint8List applyCrt(
    Uint8List data,
    int width,
    int height,
    double strength, {
    double aberration = 30,
    double bleed = 30,
  }) {
    final amount = (strength / 100.0).clamp(0.0, 1.0);
    final shift = (aberration / 100.0).clamp(0.0, 1.0) * 4;
    final smear = ((bleed / 100.0).clamp(0.0, 1.0) * 4).round();
    var result = smear > 0
        ? _convolveH(data, width, height, _gaussianKernel(smear))
        : Uint8List.fromList(data);
    if (shift > 0) {
      result = applyChromaticShift(result, width, height, shiftX: shift);
    }
    if (amount <= 0) return result;
    // Each column shows one phosphor colour more than the other two (an
    // aperture grille), and every other row (the even ones) is a darker gap
    // between scan lines. The lit colour is lifted a little so the screen doesn't just
    // get darker; premultiplied channels never exceed their alpha.
    final dim = 1 - amount * 0.45;
    final lift = 1 + amount * 0.25;
    final gap = 1 - amount * 0.35;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final a = result[i + 3];
        if (a == 0) continue;
        for (var c = 0; c < 3; c++) {
          var f = c == x % 3 ? lift : dim;
          if (y.isEven) f *= gap;
          result[i + c] = (result[i + c] * f).round().clamp(0, a);
        }
      }
    }
    return applyVignette(
      result,
      width,
      height,
      20 + amount * 30,
      onlyOnPaint: true,
    );
  }

  /// モザイク化（[mosaicSize]）＋配色処理（[colorMode]）を組み合わせた
  /// ドット絵化。色を限るときは、[dither]なら1色では遠いドットを2色の
  /// 組み合わせ（4×4の規則的な配置）で近づける。
  Uint8List applyPixelate(
    Uint8List data,
    int width,
    int height, {
    num mosaicSize = 8,
    PixelColorMode colorMode = PixelColorMode.count,
    int colorLevels = 6,
    List<int> paletteColors = const [],
    bool dither = true,
  }) => const PixelArtEngine().convert(
    data,
    width,
    height,
    pixelSize: mosaicSize,
    colorMode: colorMode,
    colorLevels: colorLevels,
    paletteColors: paletteColors,
    dither: dither,
  );

  Uint8List applyFade(
    Uint8List data,
    int width,
    int height,
    ui.Color fadeColor,
    double progress,
  ) {
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

  /// The tone curve: [curvePoints] (the master, RGB) and then each channel's
  /// own curve, as smooth curves ([ToneCurve]) on the straight colour, so a
  /// half-transparent edge changes like solid paint and transparent pixels
  /// stay transparent.
  Uint8List applyToneCurve(
    Uint8List data,
    int width,
    int height,
    List<ui.Offset> curvePoints, {
    List<ui.Offset>? redPoints,
    List<ui.Offset>? greenPoints,
    List<ui.Offset>? bluePoints,
  }) {
    List<int> lutOf(List<ui.Offset>? points) =>
        points == null || points.length < 2
        ? List<int>.generate(256, (i) => i)
        : ToneCurve(points).lut();
    final master = lutOf(curvePoints);
    List<int> through(List<ui.Offset>? channel) {
      final own = lutOf(channel);
      return [for (var i = 0; i < 256; i++) own[master[i]]];
    }

    return applyStraightChannelLuts(
      data,
      through(redPoints),
      through(greenPoints),
      through(bluePoints),
    );
  }

  /// 墨溜まりフィルターの「効果レイヤー」だけを生成する（[InkPoolEngine]）。
  /// 線が[maxAngleDegrees]以下の角度で出会う所（既定90°：角・T字・交差の
  /// 狭い側）の中心線に沿って、出会う点で
  /// [centerWidthPx]の太さ、そこから[rangePx]離れた両端で0px（なめらかな
  /// 先端）になるよう直線的に細くなる墨溜まりを描く。返り値は透明背景＋墨溜まり色だけ
  /// なので、描画フィルターでは参照レイヤーの直下へ新規レイヤーとして置ける。
  Uint8List applyInkPoolLayer(
    Uint8List data,
    int width,
    int height, {
    required int color,
    required double rangePx,
    required double centerWidthPx,
    double maxAngleDegrees = 90,
  }) => InkPoolEngine.layer(
    data,
    width,
    height,
    color: color,
    rangePx: rangePx,
    centreWidthPx: centerWidthPx,
    maxAngleDegrees: maxAngleDegrees,
  );

  /// 演出フィルター向け墨溜まり。上の効果レイヤーをフレーム合成結果へ
  /// アルファ合成する。描画フィルター版と違いプロジェクトのレイヤー構造は
  /// 変更せず、指定フレーム範囲でだけ非破壊に見える。
  Uint8List applyInkPoolComposite(
    Uint8List data,
    int width,
    int height, {
    required int color,
    required double rangePx,
    required double centerWidthPx,
    double maxAngleDegrees = 90,
  }) {
    final ink = applyInkPoolLayer(
      data,
      width,
      height,
      color: color,
      rangePx: rangePx,
      centerWidthPx: centerWidthPx,
      maxAngleDegrees: maxAngleDegrees,
    );
    final out = Uint8List.fromList(data);
    for (var i = 0; i < out.length; i += 4) {
      final a = ink[i + 3] / 255.0;
      if (a <= 0) continue;
      out[i] = (ink[i] * a + out[i] * (1 - a)).round().clamp(0, 255);
      out[i + 1] = (ink[i + 1] * a + out[i + 1] * (1 - a)).round().clamp(
        0,
        255,
      );
      out[i + 2] = (ink[i + 2] * a + out[i + 2] * (1 - a)).round().clamp(
        0,
        255,
      );
      out[i + 3] = math.max(out[i + 3], ink[i + 3]);
    }
    return out;
  }

  /// Levels: the master (RGB) settings first, then each channel's own on
  /// top, as in other painting apps (a channel left at its defaults changes
  /// nothing). Applied to the straight colour, like [applyToneCurve].
  /// A channel's values are `[inputBlack, inputWhite, gamma, outputBlack,
  /// outputWhite]`.
  Uint8List applyLevels(
    Uint8List data,
    int width,
    int height, {
    required int inputBlack,
    required int inputWhite,
    double inputGamma = 1.0,
    required int outputBlack,
    required int outputWhite,
    List<double>? redLevels,
    List<double>? greenLevels,
    List<double>? blueLevels,
  }) {
    final master = levelsLut(
      inputBlack,
      inputWhite,
      inputGamma,
      outputBlack,
      outputWhite,
    );
    List<int> through(List<double>? values) {
      if (values == null || values.length < 5) return master;
      final own = levelsLut(
        values[0].round(),
        values[1].round(),
        values[2],
        values[3].round(),
        values[4].round(),
      );
      return [for (var i = 0; i < 256; i++) own[master[i]]];
    }

    return applyStraightChannelLuts(
      data,
      through(redLevels),
      through(greenLevels),
      through(blueLevels),
    );
  }

  /// One channel's levels as a lookup table.
  static List<int> levelsLut(
    int inputBlack,
    int inputWhite,
    double gamma,
    int outputBlack,
    int outputWhite,
  ) {
    final inRange = (inputWhite - inputBlack).clamp(1, 255);
    final outRange = outputWhite - outputBlack;
    final g = gamma.clamp(0.1, 10.0);
    return List<int>.generate(256, (v) {
      final normalized = ((v - inputBlack) / inRange).clamp(0.0, 1.0);
      final corrected = math.pow(normalized, 1.0 / g);
      return (corrected * outRange + outputBlack).round().clamp(0, 255);
    });
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

  Uint8List _convolveH(
    Uint8List data,
    int width,
    int height,
    List<double> kernel,
  ) {
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

  Uint8List _convolveV(
    Uint8List data,
    int width,
    int height,
    List<double> kernel,
  ) {
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
            final gray =
                (data[idx] * 0.299 +
                        data[idx + 1] * 0.587 +
                        data[idx + 2] * 0.114)
                    .round();
            final ki = (ky2 + 1) * 3 + (kx2 + 1);
            gx += gray * kx[ki];
            gy += gray * ky[ki];
          }
        }
        result[y * width + x] = math
            .sqrt(gx * gx + gy * gy)
            .round()
            .clamp(0, 255);
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

enum EffectFilterType {
  fade,
  gaussianBlur,
  lensBlur,
  mosaic,
  chromaticAberration,
  noise,
  sepia,
  animeStyle,
  retroAnime,
  crt,
  animatedNoise,
  rain,
  monochrome,
  colorAdjust,
  threshold,
  fisheye,
  pixelate,
  auroraHologram,
  inkPool,
  vhsNoise,
  toneCurve,
  levels,
  sharpen,
  unsharpMask,
  vignette,
}
