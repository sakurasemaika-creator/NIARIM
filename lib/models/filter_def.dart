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

  /// Pixel art: one pixel-art pixel per canvas pixel instead of
  /// [strength]-sized blocks (for pictures drawn at their final resolution).
  final bool pixelArtMatchCanvas;
  final double hologramBrightness;
  final double hologramSaturation;
  final AuroraHologramPreset hologramPreset;
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
  final double bgBlendSamplingBand;
  final int bgBlendLightColor;
  final int bgBlendAmbientColor;
  final int bgBlendShadowColor;
  final int bgBlendReflectionColor;
  final bool bgBlendShowAnalysis;
  final int inkPoolColor;
  final double inkPoolRange;
  final double inkPoolCenterWidth;
  final double autoLineartRoughWidth;
  final double autoLineartOutputWidth;
  final double autoLineartTaperLength;
  final double autoLineartSmoothing;
  final int autoLineartColor;
  final double prismBlurPx;
  final double prismDirectionDegrees;

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
    this.caSaturation = 0,
    this.caBrightness = 0,
    this.caContrast = 0,
    this.thresholdValue = 128,
    this.lensCenterOffsetX = 0,
    this.lensCenterOffsetY = 0,
    this.fisheyeRadius = 100,
    this.fisheyeCenterX = 0,
    this.fisheyeCenterY = 0,
    this.chromaticShiftX = 8,
    this.chromaticShiftY = 0,
    this.chromaticShiftZ = 0,
    this.pixelColorMode = PixelColorMode.count,
    this.pixelExplicitColors = const [0xFF000000],
    this.pixelArtMatchCanvas = false,
    this.hologramBrightness = 0,
    this.hologramSaturation = 0,
    this.hologramPreset = AuroraHologramPreset.silverHologram,
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
    this.bgBlendSamplingBand = 28,
    this.bgBlendLightColor = -1,
    this.bgBlendAmbientColor = -1,
    this.bgBlendShadowColor = -1,
    this.bgBlendReflectionColor = -1,
    this.bgBlendShowAnalysis = true,
    this.inkPoolColor = 0xFF000000,
    this.inkPoolRange = 12,
    this.inkPoolCenterWidth = 6,
    this.autoLineartRoughWidth = 12,
    this.autoLineartOutputWidth = 2,
    this.autoLineartTaperLength = 8,
    this.autoLineartSmoothing = 5,
    this.autoLineartColor = 0xFF000000,
    this.prismBlurPx = 17,
    this.prismDirectionDegrees = 90,
  });

  /// Pixel art block size in canvas pixels.
  int get pixelArtBlockSize =>
      pixelArtMatchCanvas ? 1 : strength.round().clamp(1, 64);

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
    bool? pixelArtMatchCanvas,
    double? hologramBrightness,
    double? hologramSaturation,
    AuroraHologramPreset? hologramPreset,
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
    double? bgBlendSamplingBand,
    int? bgBlendLightColor,
    int? bgBlendAmbientColor,
    int? bgBlendShadowColor,
    int? bgBlendReflectionColor,
    bool? bgBlendShowAnalysis,
    int? inkPoolColor,
    double? inkPoolRange,
    double? inkPoolCenterWidth,
    double? autoLineartRoughWidth,
    double? autoLineartOutputWidth,
    double? autoLineartTaperLength,
    double? autoLineartSmoothing,
    int? autoLineartColor,
    double? prismBlurPx,
    double? prismDirectionDegrees,
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
      pixelArtMatchCanvas: pixelArtMatchCanvas ?? this.pixelArtMatchCanvas,
      hologramBrightness: hologramBrightness ?? this.hologramBrightness,
      hologramSaturation: hologramSaturation ?? this.hologramSaturation,
      hologramPreset: hologramPreset ?? this.hologramPreset,
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
      autoLineartRoughWidth:
          autoLineartRoughWidth ?? this.autoLineartRoughWidth,
      autoLineartOutputWidth:
          autoLineartOutputWidth ?? this.autoLineartOutputWidth,
      autoLineartTaperLength:
          autoLineartTaperLength ?? this.autoLineartTaperLength,
      autoLineartSmoothing: autoLineartSmoothing ?? this.autoLineartSmoothing,
      autoLineartColor: autoLineartColor ?? this.autoLineartColor,
      prismBlurPx: prismBlurPx ?? this.prismBlurPx,
      prismDirectionDegrees:
          prismDirectionDegrees ?? this.prismDirectionDegrees,
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
    'pixelArtMatchCanvas': pixelArtMatchCanvas,
    'hologramBrightness': hologramBrightness,
    'hologramSaturation': hologramSaturation,
    'hologramPreset': hologramPreset.name,
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
    'bgBlendSamplingBand': bgBlendSamplingBand,
    'bgBlendLightColor': bgBlendLightColor,
    'bgBlendAmbientColor': bgBlendAmbientColor,
    'bgBlendShadowColor': bgBlendShadowColor,
    'bgBlendReflectionColor': bgBlendReflectionColor,
    'bgBlendShowAnalysis': bgBlendShowAnalysis,
    'inkPoolColor': inkPoolColor,
    'inkPoolRange': inkPoolRange,
    'inkPoolCenterWidth': inkPoolCenterWidth,
    'autoLineartRoughWidth': autoLineartRoughWidth,
    'autoLineartOutputWidth': autoLineartOutputWidth,
    'autoLineartTaperLength': autoLineartTaperLength,
    'autoLineartSmoothing': autoLineartSmoothing,
    'autoLineartColor': autoLineartColor,
    'prismBlurPx': prismBlurPx,
    'prismDirectionDegrees': prismDirectionDegrees,
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
    thresholdValue: (j['thresholdValue'] as num?)?.toDouble() ?? 128,
    lensCenterOffsetX: (j['lensCenterOffsetX'] as num?)?.toDouble() ?? 0,
    lensCenterOffsetY: (j['lensCenterOffsetY'] as num?)?.toDouble() ?? 0,
    fisheyeRadius: (j['fisheyeRadius'] as num?)?.toDouble() ?? 100,
    fisheyeCenterX: (j['fisheyeCenterX'] as num?)?.toDouble() ?? 0,
    fisheyeCenterY: (j['fisheyeCenterY'] as num?)?.toDouble() ?? 0,
    chromaticShiftX: (j['chromaticShiftX'] as num?)?.toDouble() ?? 8,
    chromaticShiftY: (j['chromaticShiftY'] as num?)?.toDouble() ?? 0,
    chromaticShiftZ: (j['chromaticShiftZ'] as num?)?.toDouble() ?? 0,
    pixelColorMode: PixelColorMode.values.firstWhere(
      (e) => e.name == j['pixelColorMode'],
      orElse: () => PixelColorMode.count,
    ),
    pixelExplicitColors:
        (j['pixelExplicitColors'] as List<dynamic>?)?.cast<int>() ??
        const [0xFF000000],
    pixelArtMatchCanvas: j['pixelArtMatchCanvas'] as bool? ?? false,
    hologramBrightness: (j['hologramBrightness'] as num?)?.toDouble() ?? 0,
    hologramSaturation: (j['hologramSaturation'] as num?)?.toDouble() ?? 0,
    hologramPreset: AuroraHologramPreset.values.firstWhere(
      (e) => e.name == j['hologramPreset'],
      orElse: () => AuroraHologramPreset.silverHologram,
    ),
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
    bgBlendSamplingBand: (j['bgBlendSamplingBand'] as num?)?.toDouble() ?? 28,
    bgBlendLightColor: j['bgBlendLightColor'] as int? ?? -1,
    bgBlendAmbientColor: j['bgBlendAmbientColor'] as int? ?? -1,
    bgBlendShadowColor: j['bgBlendShadowColor'] as int? ?? -1,
    bgBlendReflectionColor: j['bgBlendReflectionColor'] as int? ?? -1,
    bgBlendShowAnalysis: j['bgBlendShowAnalysis'] as bool? ?? true,
    inkPoolColor: j['inkPoolColor'] as int? ?? 0xFF000000,
    inkPoolRange: (j['inkPoolRange'] as num?)?.toDouble() ?? 12,
    inkPoolCenterWidth: (j['inkPoolCenterWidth'] as num?)?.toDouble() ?? 6,
    autoLineartRoughWidth:
        (j['autoLineartRoughWidth'] as num?)?.toDouble() ?? 12,
    autoLineartOutputWidth:
        (j['autoLineartOutputWidth'] as num?)?.toDouble() ?? 2,
    autoLineartTaperLength:
        (j['autoLineartTaperLength'] as num?)?.toDouble() ?? 8,
    autoLineartSmoothing: (j['autoLineartSmoothing'] as num?)?.toDouble() ?? 5,
    autoLineartColor: j['autoLineartColor'] as int? ?? 0xFF000000,
    prismBlurPx: (j['prismBlurPx'] as num?)?.toDouble() ?? 17,
    prismDirectionDegrees:
        (j['prismDirectionDegrees'] as num?)?.toDouble() ?? 90,
  );
}
