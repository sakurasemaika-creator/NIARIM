import 'dart:math' as math;

import 'layer.dart';
import 'pixel_color_mode.dart';

enum FilterKind {
  gaussianBlur,
  lensBlur,
  animeStyle,
  outline,
  toneCurve,
  levels,
  sharpen,
  unsharpMask,
  vignette,
  noise,
  retroAnime,
  crt,
  colorAdjust,
  threshold,
  fisheye,
  chromaticAberration,
  lensDistortion,
  pixelate,
  mosaic,
  auroraHologram,
  backgroundBlend,
  inkPool,
  autoLineart,
  prism,
  sphereShading,
}

/// Shared noise algorithm, independent of preset identity.
enum NoiseStyle { filmGrain, color, vhs }

enum ToneCurvePreset {
  linear,
  brighten,
  darken,
  highContrast,
  lowContrast,
  invert,
}

enum AuroraHologramPreset {
  silverHologram,
  sampledGold,
  silverFoil,
  luminousPearl,
  auroraPastel,
  darkRainbow,
}

/// Serializable drawing-filter definition.
/// Prism uses [prismBlurPx] as Gaussian blur radius in pixels and
/// [prismDirectionDegrees] as the dark-rainbow gradient direction in degrees.
/// The largest block size the Mosaic and Pixel Art sliders reach, in canvas
/// pixels (100 steps from 1).
const int kPixelArtMaxBlockSize = 100;

/// Where a filter that draws onto a new layer puts that layer, given the
/// source layer's index (0 = the top layer): auto line art goes directly
/// above the source so the clean lines show over the rough sketch; outline
/// and ink pool go directly beneath it.
int generatedLayerInsertIndex(FilterKind kind, int sourceIndex) =>
    kind == FilterKind.autoLineart ? sourceIndex : sourceIndex + 1;

/// Names the layer a filter that draws onto a new layer makes from the
/// layer called [sourceName] (in the app's language, where one is known).
typedef GeneratedLayerNamer =
    String Function(String sourceName, FilterDef filter);

/// [created], a filter's new layer inserted at [insertIndex] among
/// [before] (the layers before it was added, index 0 = the top), set up to
/// fit there: it joins [source]'s folder, and it is clipped when the layer
/// directly above it is clipped. Otherwise it would become that layer's
/// clipping base: a clipped source would clip to its own outline beneath
/// it, and a layer clipped to the source to the line art put above it.
Layer generatedLayerFitted(
  Layer created,
  Layer source,
  List<Layer> before,
  int insertIndex,
) {
  final above = insertIndex > 0 && insertIndex <= before.length
      ? before[insertIndex - 1]
      : null;
  final clipped =
      above != null &&
      above.hasClipping &&
      above.parentFolderId == source.parentFolderId;
  return created.copyWith(
    parentFolderId: source.parentFolderId,
    hasClipping: clipped,
  );
}

/// Whether a filter of this kind works only where the selection layer is
/// painted (the glasses lens, and sphere shading when one is painted), so
/// applying it needs the selection layer's pixels.
/// Whether the filter draws its result on a new layer (beside the source)
/// rather than changing the layer itself.
bool filterGeneratesLayer(FilterKind kind) =>
    kind == FilterKind.outline ||
    kind == FilterKind.inkPool ||
    kind == FilterKind.autoLineart;

bool filterUsesSelectionMask(FilterKind kind) =>
    kind == FilterKind.lensDistortion || kind == FilterKind.sphereShading;

LayerBlendMode _blendModeNamed(Object? name, LayerBlendMode fallback) =>
    LayerBlendMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => fallback,
    );

class FilterDef {
  final String id;
  final String name;
  final FilterKind kind;
  final bool isFavorite;
  final double strength;
  final NoiseStyle noiseStyle;
  final int noiseSeed;
  final int colorLevels;
  final double edgeStrength;
  final int inputBlack;
  final int inputWhite;
  final double inputGamma;
  final int outputBlack;
  final int outputWhite;

  /// Optional per-channel Levels overrides: [inputBlack, inputWhite, gamma, outputBlack, outputWhite].
  final List<double> levelsRed;
  final List<double> levelsGreen;
  final List<double> levelsBlue;
  final ToneCurvePreset toneCurvePreset;
  final List<double> toneCurvePoints;
  final List<double> toneCurveRedPoints;
  final List<double> toneCurveGreenPoints;
  final List<double> toneCurveBluePoints;
  final int outlineColor;
  final double outlineWidth;
  final int vignetteColor;

  /// How far in from the corners the vignette reaches (0 to 100 % of the
  /// way to the centre; its darkness is [strength]).
  final double vignetteRange;
  final double caSaturation;
  final double caBrightness;
  final double caContrast;
  final double thresholdValue;
  final double lensCenterOffsetX;
  final double lensCenterOffsetY;
  final double fisheyeRadius;
  final double fisheyeCenterX;
  final double fisheyeCenterY;
  final double chromaticShiftX;
  final double chromaticShiftY;
  final double chromaticShiftZ;
  final PixelColorMode pixelColorMode;
  final List<int> pixelExplicitColors;

  /// Pixel art with limited colours: whether dots no single colour comes
  /// close to are made of a few of them in a regular pattern (dithering),
  /// or filled with the nearest one.
  final bool pixelDither;

  /// Pixel art: whether the panel shows the size as a dot count across and
  /// down the canvas rather than as the block-size slider. Either way the
  /// size itself is [strength] (see [pixelArtCellSize]).
  final bool pixelArtByDots;

  /// Cathode-ray tube: colour misregistration and beam bleed, 0 to 100.
  final double crtAberration;
  final double crtBleed;

  /// Anime style: how wide (px) the border lines drawn where colours
  /// change are (0 = none).
  final double animeBorderWidth;

  /// Anime style: how different (ΔE in CIELAB) two neighbouring colours
  /// must be for a border line between them.
  final double animeBorderThreshold;

  /// Outline: how faint a pixel may be and still count as the shape, 0 to
  /// 100 (see FilterEngine's outline): higher lets the outline reach in
  /// under a soft edge.
  final double outlineErosion;
  final double hologramBrightness;
  final double hologramSaturation;
  final AuroraHologramPreset hologramPreset;

  /// 質感変更: thin near-black line art drawn on the layer keeps its own
  /// colour, and only the surfaces take the texture.
  final bool hologramKeepLines;
  final int bgBlendColor;
  final double bgBlendDirection;
  final double bgBlendLength;
  final double bgBlendBlur;
  final bool bgBlendAutoLight;
  final double bgBlendStrength;
  final double bgBlendLightStrength;
  final double bgBlendShadowStrength;
  final double bgBlendAmbientStrength;
  final double bgBlendReflectionStrength;
  final double bgBlendColorBleed;
  final double bgBlendSoftness;
  final double bgBlendSecondaryStrength;
  final double bgBlendMaterialProtection;

  /// 背景馴染ませ: how far the drawing's brightness, saturation and colour
  /// in each tone are brought into the background's (0 to 100).
  final double bgBlendToneMatch;
  final double bgBlendSamplingBand;
  final int bgBlendLightColor;
  final int bgBlendAmbientColor;
  final int bgBlendShadowColor;
  final int bgBlendReflectionColor;
  final bool bgBlendShowAnalysis;
  final int inkPoolColor;
  final double inkPoolRange;
  final double inkPoolCenterWidth;

  /// The widest angle (degrees, 0 to 180) between two lines at which ink
  /// pools; 90 takes acute and right angles.
  final double inkPoolMaxAngle;
  final double autoLineartRoughWidth;
  final double autoLineartOutputWidth;
  final double autoLineartTaperLength;

  /// Whether the lines' ends taper (入り抜き) over [autoLineartTaperLength].
  final bool autoLineartTaper;
  final double autoLineartSmoothing;
  final int autoLineartColor;
  final double prismBlurPx;
  final double prismDirectionDegrees;

  /// Sphere shading: the colours (ARGB; their alpha is how strongly they go
  /// on, so transparent leaves that side alone) and the blend modes they go
  /// on in, either each its own ([sphereCombined] false) or both as one map
  /// in [sphereCombinedBlend].
  final int sphereShadowColor;
  final int sphereLightColor;
  final LayerBlendMode sphereShadowBlend;
  final LayerBlendMode sphereLightBlend;
  final bool sphereCombined;
  final LayerBlendMode sphereCombinedBlend;

  /// Sphere shading's light ellipse: its centre as a percentage of the
  /// canvas width and height, its width and height as a percentage of the
  /// canvas's shorter side (so equal sizes make a circle), and how much of
  /// its radius the edge fades over into the light ([sphereLightBlur]) and
  /// out into the shadow ([sphereShadowBlur]), 0 to 100 each.
  final double sphereLightX;
  final double sphereLightY;
  final double sphereLightWidth;
  final double sphereLightHeight;
  final double sphereLightBlur;
  final double sphereShadowBlur;

  const FilterDef({
    required this.id,
    required this.name,
    required this.kind,
    this.isFavorite = false,
    this.strength = 8,
    this.noiseStyle = NoiseStyle.filmGrain,
    this.noiseSeed = 1984,
    this.colorLevels = 6,
    this.edgeStrength = 0.4,
    this.inputBlack = 0,
    this.inputWhite = 255,
    this.inputGamma = 1.0,
    this.outputBlack = 0,
    this.outputWhite = 255,
    this.levelsRed = const [],
    this.levelsGreen = const [],
    this.levelsBlue = const [],
    this.toneCurvePreset = ToneCurvePreset.linear,
    this.toneCurvePoints = const [],
    this.toneCurveRedPoints = const [],
    this.toneCurveGreenPoints = const [],
    this.toneCurveBluePoints = const [],
    this.outlineColor = 0xFF000000,
    this.outlineWidth = 6,
    this.vignetteColor = 0xFF000000,
    this.vignetteRange = 40,
    this.caSaturation = 0,
    this.caBrightness = 0,
    this.caContrast = 0,
    this.thresholdValue = 128,
    this.lensCenterOffsetX = 0,
    this.lensCenterOffsetY = 0,
    this.fisheyeRadius = 100,
    this.fisheyeCenterX = 0,
    this.fisheyeCenterY = 0,
    this.chromaticShiftX = 100,
    this.chromaticShiftY = 0,
    this.chromaticShiftZ = 0,
    this.pixelColorMode = PixelColorMode.count,
    this.pixelExplicitColors = const [0xFF000000],
    this.pixelDither = true,
    this.pixelArtByDots = false,
    this.crtAberration = 30,
    this.crtBleed = 30,
    this.animeBorderWidth = 2,
    this.animeBorderThreshold = 20,
    this.outlineErosion = 0,
    this.hologramBrightness = 0,
    this.hologramSaturation = 0,
    this.hologramPreset = AuroraHologramPreset.silverHologram,
    this.hologramKeepLines = true,
    this.bgBlendColor = -1,
    this.bgBlendDirection = 315,
    this.bgBlendLength = 20,
    this.bgBlendBlur = 6,
    this.bgBlendAutoLight = true,
    this.bgBlendStrength = 70,
    this.bgBlendLightStrength = 65,
    this.bgBlendShadowStrength = 45,
    this.bgBlendAmbientStrength = 18,
    this.bgBlendReflectionStrength = 22,
    this.bgBlendColorBleed = 35,
    this.bgBlendSoftness = 55,
    this.bgBlendSecondaryStrength = 35,
    this.bgBlendMaterialProtection = 75,
    this.bgBlendToneMatch = 50,
    this.bgBlendSamplingBand = 28,
    this.bgBlendLightColor = -1,
    this.bgBlendAmbientColor = -1,
    this.bgBlendShadowColor = -1,
    this.bgBlendReflectionColor = -1,
    this.bgBlendShowAnalysis = true,
    this.inkPoolColor = 0xFF000000,
    this.inkPoolRange = 12,
    this.inkPoolCenterWidth = 6,
    this.inkPoolMaxAngle = 90,
    this.autoLineartRoughWidth = 12,
    this.autoLineartOutputWidth = 2,
    this.autoLineartTaperLength = 8,
    this.autoLineartTaper = true,
    this.autoLineartSmoothing = 5,
    this.autoLineartColor = 0xFF000000,
    this.prismBlurPx = 17,
    this.prismDirectionDegrees = 90,
    this.sphereShadowColor = 0x994B4270,
    this.sphereLightColor = 0x99FFF0C8,
    this.sphereShadowBlend = LayerBlendMode.multiply,
    this.sphereLightBlend = LayerBlendMode.screen,
    this.sphereCombined = false,
    this.sphereCombinedBlend = LayerBlendMode.hardLight,
    this.sphereLightX = 40,
    this.sphereLightY = 35,
    this.sphereLightWidth = 60,
    this.sphereLightHeight = 60,
    this.sphereLightBlur = 30,
    this.sphereShadowBlur = 30,
  });

  /// Sphere shading's light ellipse on a canvas of this size, in pixels.
  ({double centerX, double centerY, double radiusX, double radiusY})
  sphereLight(int width, int height) {
    final side = math.min(width, height).toDouble();
    return (
      centerX: width * sphereLightX / 100,
      centerY: height * sphereLightY / 100,
      radiusX: side * sphereLightWidth / 200,
      radiusY: side * sphereLightHeight / 200,
    );
  }

  /// The fisheye's centre on a canvas of this size, in pixels:
  /// [fisheyeCenterX] and [fisheyeCenterY] move it from the middle by a
  /// percentage of the width and height (±50 reaches the edges).
  ({double x, double y}) fisheyeCenter(int width, int height) => (
    x: width * (0.5 + fisheyeCenterX / 100),
    y: height * (0.5 + fisheyeCenterY / 100),
  );

  /// Chromatic aberration as canvas-pixel displacements of red (blue goes
  /// the other way): sideways (x, y) and radial (outwards at the corners).
  /// [strength] is how far, [chromaticShiftX]/[chromaticShiftY]/
  /// [chromaticShiftZ] how much of it goes each way (-100 to 100 %).
  (double, double, double) get chromaticDisplacement => (
    strength * chromaticShiftX / 100,
    strength * chromaticShiftY / 100,
    strength * chromaticShiftZ / 100,
  );

  /// The size of a pixel-art dot in canvas pixels on a canvas of this size.
  /// It is [strength], which may be fractional when it was set as a dot
  /// count (100 dots across 1920 pixels is 19.2), and may exceed the
  /// slider's [kPixelArtMaxBlockSize] when set that way.
  double pixelArtCellSize(int canvasWidth, int canvasHeight) {
    final longest = canvasWidth > canvasHeight ? canvasWidth : canvasHeight;
    return strength.clamp(1, longest < 1 ? 1 : longest).toDouble();
  }

  FilterDef copyWith({
    String? id,
    String? name,
    FilterKind? kind,
    bool? isFavorite,
    double? strength,
    NoiseStyle? noiseStyle,
    int? noiseSeed,
    int? colorLevels,
    double? edgeStrength,
    int? inputBlack,
    int? inputWhite,
    double? inputGamma,
    int? outputBlack,
    int? outputWhite,
    List<double>? levelsRed,
    List<double>? levelsGreen,
    List<double>? levelsBlue,
    ToneCurvePreset? toneCurvePreset,
    List<double>? toneCurvePoints,
    List<double>? toneCurveRedPoints,
    List<double>? toneCurveGreenPoints,
    List<double>? toneCurveBluePoints,
    int? outlineColor,
    double? outlineWidth,
    int? vignetteColor,
    double? vignetteRange,
    double? caSaturation,
    double? caBrightness,
    double? caContrast,
    double? thresholdValue,
    double? lensCenterOffsetX,
    double? lensCenterOffsetY,
    double? fisheyeRadius,
    double? fisheyeCenterX,
    double? fisheyeCenterY,
    double? chromaticShiftX,
    double? chromaticShiftY,
    double? chromaticShiftZ,
    PixelColorMode? pixelColorMode,
    List<int>? pixelExplicitColors,
    bool? pixelDither,
    bool? pixelArtByDots,
    double? crtAberration,
    double? crtBleed,
    double? animeBorderWidth,
    double? animeBorderThreshold,
    double? outlineErosion,
    double? hologramBrightness,
    double? hologramSaturation,
    AuroraHologramPreset? hologramPreset,
    bool? hologramKeepLines,
    int? bgBlendColor,
    double? bgBlendDirection,
    double? bgBlendLength,
    double? bgBlendBlur,
    bool? bgBlendAutoLight,
    double? bgBlendStrength,
    double? bgBlendLightStrength,
    double? bgBlendShadowStrength,
    double? bgBlendAmbientStrength,
    double? bgBlendReflectionStrength,
    double? bgBlendColorBleed,
    double? bgBlendSoftness,
    double? bgBlendSecondaryStrength,
    double? bgBlendMaterialProtection,
    double? bgBlendToneMatch,
    double? bgBlendSamplingBand,
    int? bgBlendLightColor,
    int? bgBlendAmbientColor,
    int? bgBlendShadowColor,
    int? bgBlendReflectionColor,
    bool? bgBlendShowAnalysis,
    int? inkPoolColor,
    double? inkPoolRange,
    double? inkPoolCenterWidth,
    double? inkPoolMaxAngle,
    double? autoLineartRoughWidth,
    double? autoLineartOutputWidth,
    double? autoLineartTaperLength,
    bool? autoLineartTaper,
    double? autoLineartSmoothing,
    int? autoLineartColor,
    double? prismBlurPx,
    double? prismDirectionDegrees,
    int? sphereShadowColor,
    int? sphereLightColor,
    LayerBlendMode? sphereShadowBlend,
    LayerBlendMode? sphereLightBlend,
    bool? sphereCombined,
    LayerBlendMode? sphereCombinedBlend,
    double? sphereLightX,
    double? sphereLightY,
    double? sphereLightWidth,
    double? sphereLightHeight,
    double? sphereLightBlur,
    double? sphereShadowBlur,
  }) {
    return FilterDef(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      isFavorite: isFavorite ?? this.isFavorite,
      strength: strength ?? this.strength,
      noiseStyle: noiseStyle ?? this.noiseStyle,
      noiseSeed: noiseSeed ?? this.noiseSeed,
      colorLevels: colorLevels ?? this.colorLevels,
      edgeStrength: edgeStrength ?? this.edgeStrength,
      inputBlack: inputBlack ?? this.inputBlack,
      inputWhite: inputWhite ?? this.inputWhite,
      inputGamma: inputGamma ?? this.inputGamma,
      outputBlack: outputBlack ?? this.outputBlack,
      outputWhite: outputWhite ?? this.outputWhite,
      levelsRed: levelsRed ?? this.levelsRed,
      levelsGreen: levelsGreen ?? this.levelsGreen,
      levelsBlue: levelsBlue ?? this.levelsBlue,
      toneCurvePreset: toneCurvePreset ?? this.toneCurvePreset,
      toneCurvePoints: toneCurvePoints ?? this.toneCurvePoints,
      toneCurveRedPoints: toneCurveRedPoints ?? this.toneCurveRedPoints,
      toneCurveGreenPoints: toneCurveGreenPoints ?? this.toneCurveGreenPoints,
      toneCurveBluePoints: toneCurveBluePoints ?? this.toneCurveBluePoints,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      vignetteColor: vignetteColor ?? this.vignetteColor,
      vignetteRange: vignetteRange ?? this.vignetteRange,
      caSaturation: caSaturation ?? this.caSaturation,
      caBrightness: caBrightness ?? this.caBrightness,
      caContrast: caContrast ?? this.caContrast,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      lensCenterOffsetX: lensCenterOffsetX ?? this.lensCenterOffsetX,
      lensCenterOffsetY: lensCenterOffsetY ?? this.lensCenterOffsetY,
      fisheyeRadius: fisheyeRadius ?? this.fisheyeRadius,
      fisheyeCenterX: fisheyeCenterX ?? this.fisheyeCenterX,
      fisheyeCenterY: fisheyeCenterY ?? this.fisheyeCenterY,
      chromaticShiftX: chromaticShiftX ?? this.chromaticShiftX,
      chromaticShiftY: chromaticShiftY ?? this.chromaticShiftY,
      chromaticShiftZ: chromaticShiftZ ?? this.chromaticShiftZ,
      pixelColorMode: pixelColorMode ?? this.pixelColorMode,
      pixelExplicitColors: pixelExplicitColors ?? this.pixelExplicitColors,
      pixelDither: pixelDither ?? this.pixelDither,
      pixelArtByDots: pixelArtByDots ?? this.pixelArtByDots,
      crtAberration: crtAberration ?? this.crtAberration,
      crtBleed: crtBleed ?? this.crtBleed,
      animeBorderWidth: animeBorderWidth ?? this.animeBorderWidth,
      animeBorderThreshold: animeBorderThreshold ?? this.animeBorderThreshold,
      outlineErosion: outlineErosion ?? this.outlineErosion,
      hologramBrightness: hologramBrightness ?? this.hologramBrightness,
      hologramSaturation: hologramSaturation ?? this.hologramSaturation,
      hologramPreset: hologramPreset ?? this.hologramPreset,
      hologramKeepLines: hologramKeepLines ?? this.hologramKeepLines,
      bgBlendColor: bgBlendColor ?? this.bgBlendColor,
      bgBlendDirection: bgBlendDirection ?? this.bgBlendDirection,
      bgBlendLength: bgBlendLength ?? this.bgBlendLength,
      bgBlendBlur: bgBlendBlur ?? this.bgBlendBlur,
      bgBlendAutoLight: bgBlendAutoLight ?? this.bgBlendAutoLight,
      bgBlendStrength: bgBlendStrength ?? this.bgBlendStrength,
      bgBlendLightStrength: bgBlendLightStrength ?? this.bgBlendLightStrength,
      bgBlendShadowStrength:
          bgBlendShadowStrength ?? this.bgBlendShadowStrength,
      bgBlendAmbientStrength:
          bgBlendAmbientStrength ?? this.bgBlendAmbientStrength,
      bgBlendReflectionStrength:
          bgBlendReflectionStrength ?? this.bgBlendReflectionStrength,
      bgBlendColorBleed: bgBlendColorBleed ?? this.bgBlendColorBleed,
      bgBlendSoftness: bgBlendSoftness ?? this.bgBlendSoftness,
      bgBlendSecondaryStrength:
          bgBlendSecondaryStrength ?? this.bgBlendSecondaryStrength,
      bgBlendMaterialProtection:
          bgBlendMaterialProtection ?? this.bgBlendMaterialProtection,
      bgBlendToneMatch: bgBlendToneMatch ?? this.bgBlendToneMatch,
      bgBlendSamplingBand: bgBlendSamplingBand ?? this.bgBlendSamplingBand,
      bgBlendLightColor: bgBlendLightColor ?? this.bgBlendLightColor,
      bgBlendAmbientColor: bgBlendAmbientColor ?? this.bgBlendAmbientColor,
      bgBlendShadowColor: bgBlendShadowColor ?? this.bgBlendShadowColor,
      bgBlendReflectionColor:
          bgBlendReflectionColor ?? this.bgBlendReflectionColor,
      bgBlendShowAnalysis: bgBlendShowAnalysis ?? this.bgBlendShowAnalysis,
      inkPoolColor: inkPoolColor ?? this.inkPoolColor,
      inkPoolRange: inkPoolRange ?? this.inkPoolRange,
      inkPoolCenterWidth: inkPoolCenterWidth ?? this.inkPoolCenterWidth,
      inkPoolMaxAngle: inkPoolMaxAngle ?? this.inkPoolMaxAngle,
      autoLineartRoughWidth:
          autoLineartRoughWidth ?? this.autoLineartRoughWidth,
      autoLineartOutputWidth:
          autoLineartOutputWidth ?? this.autoLineartOutputWidth,
      autoLineartTaperLength:
          autoLineartTaperLength ?? this.autoLineartTaperLength,
      autoLineartTaper: autoLineartTaper ?? this.autoLineartTaper,
      autoLineartSmoothing: autoLineartSmoothing ?? this.autoLineartSmoothing,
      autoLineartColor: autoLineartColor ?? this.autoLineartColor,
      prismBlurPx: prismBlurPx ?? this.prismBlurPx,
      prismDirectionDegrees:
          prismDirectionDegrees ?? this.prismDirectionDegrees,
      sphereShadowColor: sphereShadowColor ?? this.sphereShadowColor,
      sphereLightColor: sphereLightColor ?? this.sphereLightColor,
      sphereShadowBlend: sphereShadowBlend ?? this.sphereShadowBlend,
      sphereLightBlend: sphereLightBlend ?? this.sphereLightBlend,
      sphereCombined: sphereCombined ?? this.sphereCombined,
      sphereCombinedBlend: sphereCombinedBlend ?? this.sphereCombinedBlend,
      sphereLightX: sphereLightX ?? this.sphereLightX,
      sphereLightY: sphereLightY ?? this.sphereLightY,
      sphereLightWidth: sphereLightWidth ?? this.sphereLightWidth,
      sphereLightHeight: sphereLightHeight ?? this.sphereLightHeight,
      sphereLightBlur: sphereLightBlur ?? this.sphereLightBlur,
      sphereShadowBlur: sphereShadowBlur ?? this.sphereShadowBlur,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'id': id,
    'name': name,
    'kind': kind.name,
    'isFavorite': isFavorite,
    'strength': strength,
    'noiseStyle': noiseStyle.name,
    'noiseSeed': noiseSeed,
    'colorLevels': colorLevels,
    'edgeStrength': edgeStrength,
    'inputBlack': inputBlack,
    'inputWhite': inputWhite,
    'inputGamma': inputGamma,
    'outputBlack': outputBlack,
    'outputWhite': outputWhite,
    'levelsRed': levelsRed,
    'levelsGreen': levelsGreen,
    'levelsBlue': levelsBlue,
    'toneCurvePreset': toneCurvePreset.name,
    'toneCurvePoints': toneCurvePoints,
    'toneCurveRedPoints': toneCurveRedPoints,
    'toneCurveGreenPoints': toneCurveGreenPoints,
    'toneCurveBluePoints': toneCurveBluePoints,
    'outlineColor': outlineColor,
    'outlineWidth': outlineWidth,
    'vignetteColor': vignetteColor,
    'vignetteRange': vignetteRange,
    'caSaturation': caSaturation,
    'caBrightness': caBrightness,
    'caContrast': caContrast,
    'thresholdValue': thresholdValue,
    'lensCenterOffsetX': lensCenterOffsetX,
    'lensCenterOffsetY': lensCenterOffsetY,
    'fisheyeRadius': fisheyeRadius,
    'fisheyeCenterX': fisheyeCenterX,
    'fisheyeCenterY': fisheyeCenterY,
    'chromaticShiftX': chromaticShiftX,
    'chromaticShiftY': chromaticShiftY,
    'chromaticShiftZ': chromaticShiftZ,
    'pixelColorMode': pixelColorMode.name,
    'pixelExplicitColors': pixelExplicitColors,
    'pixelDither': pixelDither,
    'pixelArtByDots': pixelArtByDots,
    'crtAberration': crtAberration,
    'crtBleed': crtBleed,
    'animeBorderWidth': animeBorderWidth,
    'animeBorderThreshold': animeBorderThreshold,
    'outlineErosion': outlineErosion,
    'hologramBrightness': hologramBrightness,
    'hologramSaturation': hologramSaturation,
    'hologramPreset': hologramPreset.name,
    'hologramKeepLines': hologramKeepLines,
    'bgBlendColor': bgBlendColor,
    'bgBlendDirection': bgBlendDirection,
    'bgBlendLength': bgBlendLength,
    'bgBlendBlur': bgBlendBlur,
    'bgBlendAutoLight': bgBlendAutoLight,
    'bgBlendStrength': bgBlendStrength,
    'bgBlendLightStrength': bgBlendLightStrength,
    'bgBlendShadowStrength': bgBlendShadowStrength,
    'bgBlendAmbientStrength': bgBlendAmbientStrength,
    'bgBlendReflectionStrength': bgBlendReflectionStrength,
    'bgBlendColorBleed': bgBlendColorBleed,
    'bgBlendSoftness': bgBlendSoftness,
    'bgBlendSecondaryStrength': bgBlendSecondaryStrength,
    'bgBlendMaterialProtection': bgBlendMaterialProtection,
    'bgBlendToneMatch': bgBlendToneMatch,
    'bgBlendSamplingBand': bgBlendSamplingBand,
    'bgBlendLightColor': bgBlendLightColor,
    'bgBlendAmbientColor': bgBlendAmbientColor,
    'bgBlendShadowColor': bgBlendShadowColor,
    'bgBlendReflectionColor': bgBlendReflectionColor,
    'bgBlendShowAnalysis': bgBlendShowAnalysis,
    'inkPoolColor': inkPoolColor,
    'inkPoolRange': inkPoolRange,
    'inkPoolCenterWidth': inkPoolCenterWidth,
    'inkPoolMaxAngle': inkPoolMaxAngle,
    'autoLineartRoughWidth': autoLineartRoughWidth,
    'autoLineartOutputWidth': autoLineartOutputWidth,
    'autoLineartTaperLength': autoLineartTaperLength,
    'autoLineartTaper': autoLineartTaper,
    'autoLineartSmoothing': autoLineartSmoothing,
    'autoLineartColor': autoLineartColor,
    'prismBlurPx': prismBlurPx,
    'prismDirectionDegrees': prismDirectionDegrees,
    'sphereShadowColor': sphereShadowColor,
    'sphereLightColor': sphereLightColor,
    'sphereShadowBlend': sphereShadowBlend.name,
    'sphereLightBlend': sphereLightBlend.name,
    'sphereCombined': sphereCombined,
    'sphereCombinedBlend': sphereCombinedBlend.name,
    'sphereLightX': sphereLightX,
    'sphereLightY': sphereLightY,
    'sphereLightWidth': sphereLightWidth,
    'sphereLightHeight': sphereLightHeight,
    'sphereLightBlur': sphereLightBlur,
    'sphereShadowBlur': sphereShadowBlur,
  };

  /// The stored kind name; Prism snapshots written before schemaVersion
  /// existed carried another kind.
  static String? _kindName(Map<String, dynamic> j) =>
      j['schemaVersion'] == null && j['id'] == 'Filter0022'
      ? 'prism'
      : j['kind'] as String?;

  /// Whether [j] names a filter kind this app still has.
  static bool hasKnownKind(Map<String, dynamic> j) {
    final name = _kindName(j);
    return FilterKind.values.any((e) => e.name == name);
  }

  /// Throws a [FormatException] for a kind the app no longer has, so a
  /// recorded automation step reports it instead of applying another filter.
  factory FilterDef.fromJson(Map<String, dynamic> j) => FilterDef(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: FilterKind.values.firstWhere(
      (e) => e.name == _kindName(j),
      orElse: () =>
          throw FormatException('Unknown filter kind: ${_kindName(j)}'),
    ),
    isFavorite: j['isFavorite'] as bool? ?? false,
    strength: (j['strength'] as num?)?.toDouble() ?? 8,
    // One-time compatibility for snapshots written before noiseStyle existed.
    // New definitions and rendering never depend on a preset ID.
    noiseStyle: NoiseStyle.values.firstWhere(
      (e) => e.name == j['noiseStyle'],
      orElse: () => j['noiseStyle'] != null
          ? NoiseStyle.filmGrain
          : switch (j['id']) {
              'Filter0024' => NoiseStyle.vhs,
              'Filter0027' => NoiseStyle.color,
              _ => NoiseStyle.filmGrain,
            },
    ),
    noiseSeed:
        (j['noiseSeed'] as num?)?.toInt() ??
        (j['noiseStyle'] == null && j['id'] == 'Filter0024'
            ? (j['thresholdValue'] as num?)?.round() ?? 1984
            : 1984),
    colorLevels: j['colorLevels'] as int? ?? 6,
    edgeStrength: (j['edgeStrength'] as num?)?.toDouble() ?? 0.4,
    inputBlack: j['inputBlack'] as int? ?? 0,
    inputWhite: j['inputWhite'] as int? ?? 255,
    inputGamma: (j['inputGamma'] as num?)?.toDouble() ?? 1.0,
    outputBlack: j['outputBlack'] as int? ?? 0,
    outputWhite: j['outputWhite'] as int? ?? 255,
    levelsRed:
        (j['levelsRed'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
        const [],
    levelsGreen:
        (j['levelsGreen'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    levelsBlue:
        (j['levelsBlue'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    caSaturation: (j['caSaturation'] as num?)?.toDouble() ?? 0,
    caBrightness: (j['caBrightness'] as num?)?.toDouble() ?? 0,
    caContrast: (j['caContrast'] as num?)?.toDouble() ?? 0,
    toneCurvePreset: ToneCurvePreset.values.firstWhere(
      (e) => e.name == j['toneCurvePreset'],
      orElse: () => ToneCurvePreset.linear,
    ),
    toneCurvePoints:
        (j['toneCurvePoints'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    toneCurveRedPoints:
        (j['toneCurveRedPoints'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    toneCurveGreenPoints:
        (j['toneCurveGreenPoints'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    toneCurveBluePoints:
        (j['toneCurveBluePoints'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    outlineColor: j['outlineColor'] as int? ?? 0xFF000000,
    outlineWidth: (j['outlineWidth'] as num?)?.toDouble() ?? 6,
    vignetteColor: j['vignetteColor'] as int? ?? 0xFF000000,
    vignetteRange: (j['vignetteRange'] as num?)?.toDouble() ?? 40,
    thresholdValue: (j['thresholdValue'] as num?)?.toDouble() ?? 128,
    lensCenterOffsetX: (j['lensCenterOffsetX'] as num?)?.toDouble() ?? 0,
    lensCenterOffsetY: (j['lensCenterOffsetY'] as num?)?.toDouble() ?? 0,
    fisheyeRadius: (j['fisheyeRadius'] as num?)?.toDouble() ?? 100,
    fisheyeCenterX: (j['fisheyeCenterX'] as num?)?.toDouble() ?? 0,
    fisheyeCenterY: (j['fisheyeCenterY'] as num?)?.toDouble() ?? 0,
    chromaticShiftX: (j['chromaticShiftX'] as num?)?.toDouble() ?? 100,
    chromaticShiftY: (j['chromaticShiftY'] as num?)?.toDouble() ?? 0,
    chromaticShiftZ: (j['chromaticShiftZ'] as num?)?.toDouble() ?? 0,
    pixelColorMode: PixelColorMode.values.firstWhere(
      (e) => e.name == j['pixelColorMode'],
      orElse: () => PixelColorMode.count,
    ),
    pixelExplicitColors:
        (j['pixelExplicitColors'] as List<dynamic>?)?.cast<int>() ??
        const [0xFF000000],
    pixelDither: j['pixelDither'] as bool? ?? true,
    pixelArtByDots: j['pixelArtByDots'] as bool? ?? false,
    crtAberration: (j['crtAberration'] as num?)?.toDouble() ?? 30,
    crtBleed: (j['crtBleed'] as num?)?.toDouble() ?? 30,
    animeBorderWidth: (j['animeBorderWidth'] as num?)?.toDouble() ?? 2,
    animeBorderThreshold: (j['animeBorderThreshold'] as num?)?.toDouble() ?? 20,
    outlineErosion: (j['outlineErosion'] as num?)?.toDouble() ?? 0,
    hologramBrightness: (j['hologramBrightness'] as num?)?.toDouble() ?? 0,
    hologramSaturation: (j['hologramSaturation'] as num?)?.toDouble() ?? 0,
    hologramPreset: AuroraHologramPreset.values.firstWhere(
      (e) => e.name == j['hologramPreset'],
      orElse: () => AuroraHologramPreset.silverHologram,
    ),
    hologramKeepLines: j['hologramKeepLines'] as bool? ?? true,
    bgBlendColor: j['bgBlendColor'] as int? ?? -1,
    bgBlendDirection: (j['bgBlendDirection'] as num?)?.toDouble() ?? 315,
    bgBlendLength: (j['bgBlendLength'] as num?)?.toDouble() ?? 20,
    bgBlendBlur: (j['bgBlendBlur'] as num?)?.toDouble() ?? 6,
    bgBlendAutoLight: j['bgBlendAutoLight'] as bool? ?? true,
    bgBlendStrength: (j['bgBlendStrength'] as num?)?.toDouble() ?? 70,
    bgBlendLightStrength: (j['bgBlendLightStrength'] as num?)?.toDouble() ?? 65,
    bgBlendShadowStrength:
        (j['bgBlendShadowStrength'] as num?)?.toDouble() ?? 45,
    bgBlendAmbientStrength:
        (j['bgBlendAmbientStrength'] as num?)?.toDouble() ?? 18,
    bgBlendReflectionStrength:
        (j['bgBlendReflectionStrength'] as num?)?.toDouble() ?? 22,
    bgBlendColorBleed: (j['bgBlendColorBleed'] as num?)?.toDouble() ?? 35,
    bgBlendSoftness: (j['bgBlendSoftness'] as num?)?.toDouble() ?? 55,
    bgBlendSecondaryStrength:
        (j['bgBlendSecondaryStrength'] as num?)?.toDouble() ?? 35,
    bgBlendMaterialProtection:
        (j['bgBlendMaterialProtection'] as num?)?.toDouble() ?? 75,
    bgBlendToneMatch: (j['bgBlendToneMatch'] as num?)?.toDouble() ?? 50,
    bgBlendSamplingBand: (j['bgBlendSamplingBand'] as num?)?.toDouble() ?? 28,
    bgBlendLightColor: j['bgBlendLightColor'] as int? ?? -1,
    bgBlendAmbientColor: j['bgBlendAmbientColor'] as int? ?? -1,
    bgBlendShadowColor: j['bgBlendShadowColor'] as int? ?? -1,
    bgBlendReflectionColor: j['bgBlendReflectionColor'] as int? ?? -1,
    bgBlendShowAnalysis: j['bgBlendShowAnalysis'] as bool? ?? true,
    inkPoolColor: j['inkPoolColor'] as int? ?? 0xFF000000,
    inkPoolRange: (j['inkPoolRange'] as num?)?.toDouble() ?? 12,
    inkPoolCenterWidth: (j['inkPoolCenterWidth'] as num?)?.toDouble() ?? 6,
    inkPoolMaxAngle: (j['inkPoolMaxAngle'] as num?)?.toDouble() ?? 90,
    autoLineartRoughWidth:
        (j['autoLineartRoughWidth'] as num?)?.toDouble() ?? 12,
    autoLineartOutputWidth:
        (j['autoLineartOutputWidth'] as num?)?.toDouble() ?? 2,
    autoLineartTaperLength:
        (j['autoLineartTaperLength'] as num?)?.toDouble() ?? 8,
    autoLineartTaper: j['autoLineartTaper'] as bool? ?? true,
    autoLineartSmoothing: (j['autoLineartSmoothing'] as num?)?.toDouble() ?? 5,
    autoLineartColor: j['autoLineartColor'] as int? ?? 0xFF000000,
    prismBlurPx: (j['prismBlurPx'] as num?)?.toDouble() ?? 17,
    prismDirectionDegrees:
        (j['prismDirectionDegrees'] as num?)?.toDouble() ?? 90,
    sphereShadowColor: j['sphereShadowColor'] as int? ?? 0x994B4270,
    sphereLightColor: j['sphereLightColor'] as int? ?? 0x99FFF0C8,
    sphereShadowBlend: _blendModeNamed(
      j['sphereShadowBlend'],
      LayerBlendMode.multiply,
    ),
    sphereLightBlend: _blendModeNamed(
      j['sphereLightBlend'],
      LayerBlendMode.screen,
    ),
    sphereCombined: j['sphereCombined'] as bool? ?? false,
    sphereCombinedBlend: _blendModeNamed(
      j['sphereCombinedBlend'],
      LayerBlendMode.hardLight,
    ),
    sphereLightX: (j['sphereLightX'] as num?)?.toDouble() ?? 40,
    sphereLightY: (j['sphereLightY'] as num?)?.toDouble() ?? 35,
    sphereLightWidth: (j['sphereLightWidth'] as num?)?.toDouble() ?? 60,
    sphereLightHeight: (j['sphereLightHeight'] as num?)?.toDouble() ?? 60,
    sphereLightBlur: (j['sphereLightBlur'] as num?)?.toDouble() ?? 30,
    sphereShadowBlur: (j['sphereShadowBlur'] as num?)?.toDouble() ?? 30,
  );
}
