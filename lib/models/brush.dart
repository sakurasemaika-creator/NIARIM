import 'asset_tags.dart';
import 'brush_extension_defaults.dart';
import 'pixel_color_mode.dart';

enum BrushImageInkMode { dark, light, alpha }

enum HairFoldMode { waveTopView, waveLowAngle, curlRight, curlLeft, crescent }

class Brush {
  final String id;
  final String name;
  final double size;
  final int opacity;
  final int spacing;
  final bool stabilization;
  final int stabilizationStrength;
  final bool pixelMode;
  final BrushPressureOnSettings pressureOn;
  final BrushPressureOffSettings pressureOff;
  final FadeMode fadeMode;
  final FadeEndpointSettings fadeIn;
  final FadeEndpointSettings fadeOut;
  final bool strokeDecay;
  final bool isFavorite;
  final String? folderId;
  final String? customImagePath;
  final List<String> customImagePaths;
  final BrushImageSelectionMode customImageSelectionMode;
  final BrushImageInkMode imageInkMode;
  final double tipSpacingFactor;
  final double chainAspect;
  final double chainThickness;
  final bool rotation;
  final double density;
  final double scatter;
  final double? calligraphyAngle;
  final PixelColorMode pixelColorMode;
  final int pixelColorLevels;
  final List<int> pixelExplicitColors;
  final List<String> tags;

  final bool lateralRepeatEnabled;
  final int lateralRepeatCount;
  final double lateralRepeatSpacing;
  final bool outlineEnabled;
  final double outlineWidth;
  final int outlineColor;
  final bool foldEnabled;
  final double foldTriggerAngle;
  final double foldCurveStartRatio;
  final int foldCurveStrength;
  final double foldCrescentDepthThreshold;
  final double foldLengthRatio;
  final double foldEndTaperRatio;
  final HairFoldMode foldMode;
  final double yBranchAngle;
  final double yBranchLengthRatio;
  final double yBranchWidthRatio;
  final double yBranchEndTaperRatio;
  final BrushTipShape tipShape;

  const Brush({
    required this.id,
    required this.name,
    required this.size,
    required this.opacity,
    required this.spacing,
    required this.stabilization,
    required this.stabilizationStrength,
    required this.pixelMode,
    this.pressureOn = BrushPressureOnSettings.defaults,
    this.pressureOff = BrushPressureOffSettings.defaults,
    required this.fadeMode,
    this.fadeIn = FadeEndpointSettings.full,
    this.fadeOut = FadeEndpointSettings.full,
    required this.strokeDecay,
    this.isFavorite = false,
    this.folderId,
    this.customImagePath,
    this.customImagePaths = const [],
    this.customImageSelectionMode = BrushImageSelectionMode.random,
    this.imageInkMode = BrushImageInkMode.dark,
    this.tipSpacingFactor = 0,
    this.chainAspect = .64,
    this.chainThickness = .25,
    this.rotation = false,
    this.density = 1.0,
    this.scatter = 0.0,
    this.calligraphyAngle,
    this.pixelColorMode = PixelColorMode.none,
    this.pixelColorLevels = 8,
    this.pixelExplicitColors = const [0xFF000000],
    this.tags = const [],
    this.lateralRepeatEnabled = false,
    this.lateralRepeatCount = 1,
    this.lateralRepeatSpacing = 1.0,
    this.outlineEnabled = false,
    this.outlineWidth = 1.5,
    this.outlineColor = 0xFF000000,
    this.foldEnabled = false,
    this.foldTriggerAngle = 90.0,
    this.foldCurveStartRatio = 0.25,
    this.foldCurveStrength = 5,
    this.foldCrescentDepthThreshold =
        BrushExtensionDefaults.foldCrescentDepthThreshold,
    this.foldLengthRatio = 0.8,
    this.foldEndTaperRatio = 0.35,
    this.foldMode = HairFoldMode.waveTopView,
    this.yBranchAngle = 45.0,
    this.yBranchLengthRatio = 0.6,
    this.yBranchWidthRatio = 0.08,
    this.yBranchEndTaperRatio = 0.4,
    this.tipShape = BrushTipShape.round,
  });

  List<String> get resolvedCustomImagePaths {
    if (customImagePaths.isNotEmpty) return List.unmodifiable(customImagePaths);
    final legacy = customImagePath;
    return legacy == null || legacy.isEmpty ? const [] : [legacy];
  }

  static int clampLateralRepeatCount(int value) => value.clamp(1, 10).toInt();
  static double clampFoldRatio(double value, double fallback) =>
      value.isFinite ? value.clamp(0.0, 1.0).toDouble() : fallback;
  static double clampFoldCrescentDepthThreshold(double value) => value.isFinite
      ? value
            .clamp(0.0, BrushExtensionDefaults.maxFoldCrescentDepthThreshold)
            .toDouble()
      : BrushExtensionDefaults.foldCrescentDepthThreshold;
  static int clampFoldCurveStrength(int value) => value.clamp(1, 10).toInt();
  static double clampFoldAngle(double value, double fallback) =>
      value.isFinite ? value.clamp(1.0, 180.0).toDouble() : fallback;

  Brush copyWith({
    String? id,
    String? name,
    double? size,
    int? opacity,
    int? spacing,
    bool? stabilization,
    int? stabilizationStrength,
    bool? pixelMode,
    BrushPressureOnSettings? pressureOn,
    BrushPressureOffSettings? pressureOff,
    FadeMode? fadeMode,
    FadeEndpointSettings? fadeIn,
    FadeEndpointSettings? fadeOut,
    bool? strokeDecay,
    bool? isFavorite,
    String? folderId,
    String? customImagePath,
    List<String>? customImagePaths,
    BrushImageSelectionMode? customImageSelectionMode,
    BrushImageInkMode? imageInkMode,
    double? tipSpacingFactor,
    double? chainAspect,
    double? chainThickness,
    bool? rotation,
    double? density,
    double? scatter,
    double? calligraphyAngle,
    bool clearCalligraphyAngle = false,
    bool clearCustomImages = false,
    PixelColorMode? pixelColorMode,
    int? pixelColorLevels,
    List<int>? pixelExplicitColors,
    List<String>? tags,
    bool? lateralRepeatEnabled,
    int? lateralRepeatCount,
    double? lateralRepeatSpacing,
    bool? outlineEnabled,
    double? outlineWidth,
    int? outlineColor,
    bool? foldEnabled,
    double? foldTriggerAngle,
    double? foldCurveStartRatio,
    int? foldCurveStrength,
    double? foldCrescentDepthThreshold,
    double? foldLengthRatio,
    double? foldEndTaperRatio,
    HairFoldMode? foldMode,
    double? yBranchAngle,
    double? yBranchLengthRatio,
    double? yBranchWidthRatio,
    double? yBranchEndTaperRatio,
    BrushTipShape? tipShape,
  }) => Brush(
    id: id ?? this.id,
    name: name ?? this.name,
    size: size ?? this.size,
    opacity: opacity ?? this.opacity,
    spacing: spacing ?? this.spacing,
    stabilization: stabilization ?? this.stabilization,
    stabilizationStrength: stabilizationStrength ?? this.stabilizationStrength,
    pixelMode: pixelMode ?? this.pixelMode,
    pressureOn: pressureOn ?? this.pressureOn,
    pressureOff: pressureOff ?? this.pressureOff,
    fadeMode: fadeMode ?? this.fadeMode,
    fadeIn: fadeIn ?? this.fadeIn,
    fadeOut: fadeOut ?? this.fadeOut,
    strokeDecay: strokeDecay ?? this.strokeDecay,
    isFavorite: isFavorite ?? this.isFavorite,
    folderId: folderId ?? this.folderId,
    customImagePath: clearCustomImages
        ? null
        : customImagePath ?? this.customImagePath,
    customImagePaths: clearCustomImages
        ? const []
        : customImagePaths ?? this.customImagePaths,
    customImageSelectionMode:
        customImageSelectionMode ?? this.customImageSelectionMode,
    imageInkMode: imageInkMode ?? this.imageInkMode,
    tipSpacingFactor: tipSpacingFactor ?? this.tipSpacingFactor,
    chainAspect: chainAspect ?? this.chainAspect,
    chainThickness: chainThickness ?? this.chainThickness,
    rotation: rotation ?? this.rotation,
    density: density ?? this.density,
    scatter: scatter ?? this.scatter,
    calligraphyAngle: clearCalligraphyAngle
        ? null
        : calligraphyAngle ?? this.calligraphyAngle,
    pixelColorMode: pixelColorMode ?? this.pixelColorMode,
    pixelColorLevels: pixelColorLevels ?? this.pixelColorLevels,
    pixelExplicitColors: pixelExplicitColors ?? this.pixelExplicitColors,
    tags: tags ?? this.tags,
    lateralRepeatEnabled: lateralRepeatEnabled ?? this.lateralRepeatEnabled,
    lateralRepeatCount: clampLateralRepeatCount(
      lateralRepeatCount ?? this.lateralRepeatCount,
    ),
    lateralRepeatSpacing: lateralRepeatSpacing ?? this.lateralRepeatSpacing,
    outlineEnabled: outlineEnabled ?? this.outlineEnabled,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    outlineColor: outlineColor ?? this.outlineColor,
    foldEnabled: foldEnabled ?? this.foldEnabled,
    foldTriggerAngle: foldTriggerAngle ?? this.foldTriggerAngle,
    foldCurveStartRatio: clampFoldRatio(
      foldCurveStartRatio ?? this.foldCurveStartRatio,
      .25,
    ),
    foldCurveStrength: clampFoldCurveStrength(
      foldCurveStrength ?? this.foldCurveStrength,
    ),
    foldCrescentDepthThreshold: clampFoldCrescentDepthThreshold(
      foldCrescentDepthThreshold ?? this.foldCrescentDepthThreshold,
    ),
    foldLengthRatio: clampFoldRatio(
      foldLengthRatio ?? this.foldLengthRatio,
      .8,
    ),
    foldEndTaperRatio: clampFoldRatio(
      foldEndTaperRatio ?? this.foldEndTaperRatio,
      .35,
    ),
    foldMode: foldMode ?? this.foldMode,
    yBranchAngle: yBranchAngle ?? this.yBranchAngle,
    yBranchLengthRatio: yBranchLengthRatio ?? this.yBranchLengthRatio,
    yBranchWidthRatio: yBranchWidthRatio ?? this.yBranchWidthRatio,
    yBranchEndTaperRatio: yBranchEndTaperRatio ?? this.yBranchEndTaperRatio,
    tipShape: tipShape ?? this.tipShape,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'opacity': opacity,
    'spacing': spacing,
    'stabilization': stabilization,
    'stabilizationStrength': stabilizationStrength,
    'pixelMode': pixelMode,
    'pressureOn': pressureOn.toJson(),
    'pressureOff': pressureOff.toJson(),
    'fadeMode': fadeMode.name,
    'fadeIn': fadeIn.toJson(),
    'fadeOut': fadeOut.toJson(),
    'strokeDecay': strokeDecay,
    'isFavorite': isFavorite,
    'folderId': folderId,
    'customImagePath': customImagePath,
    'customImagePaths': customImagePaths,
    'customImageSelectionMode': customImageSelectionMode.name,
    'imageInkMode': imageInkMode.name,
    'tipSpacingFactor': tipSpacingFactor,
    'chainAspect': chainAspect,
    'chainThickness': chainThickness,
    'rotation': rotation,
    'density': density,
    'scatter': scatter,
    'calligraphyAngle': calligraphyAngle,
    'pixelColorMode': pixelColorMode.name,
    'pixelColorLevels': pixelColorLevels,
    'pixelExplicitColors': pixelExplicitColors,
    'tags': tags,
    'lateralRepeatEnabled': lateralRepeatEnabled,
    'lateralRepeatCount': clampLateralRepeatCount(lateralRepeatCount),
    'lateralRepeatSpacing': lateralRepeatSpacing,
    'outlineEnabled': outlineEnabled,
    'outlineWidth': outlineWidth,
    'outlineColor': outlineColor,
    'foldEnabled': foldEnabled,
    'foldTriggerAngle': foldTriggerAngle,
    'foldCurveStartRatio': clampFoldRatio(foldCurveStartRatio, .25),
    'foldCurveStrength': clampFoldCurveStrength(foldCurveStrength),
    'foldCrescentDepthThreshold': clampFoldCrescentDepthThreshold(
      foldCrescentDepthThreshold,
    ),
    'foldLengthRatio': clampFoldRatio(foldLengthRatio, .8),
    'foldEndTaperRatio': clampFoldRatio(foldEndTaperRatio, .35),
    'foldMode': foldMode.name,
    'yBranchAngle': yBranchAngle,
    'yBranchLengthRatio': yBranchLengthRatio,
    'yBranchWidthRatio': yBranchWidthRatio,
    'yBranchEndTaperRatio': yBranchEndTaperRatio,
    'tipShape': tipShape.name,
  };

  factory Brush.fromJson(Map<String, dynamic> j) => Brush(
    id: j['id'] as String,
    name: j['name'] as String,
    size: (j['size'] as num).toDouble(),
    opacity: j['opacity'] as int,
    spacing: j['spacing'] as int,
    stabilization: j['stabilization'] as bool,
    stabilizationStrength: j['stabilizationStrength'] as int,
    pixelMode: (j['pixelMode'] ?? j['dotPenMode']) as bool? ?? false,
    pressureOn: BrushPressureOnSettings.fromJson(
      j['pressureOn'] as Map<String, dynamic>,
    ),
    pressureOff: BrushPressureOffSettings.fromJson(
      j['pressureOff'] as Map<String, dynamic>,
    ),
    fadeMode: FadeMode.values.firstWhere(
      (e) => e.name == j['fadeMode'],
      orElse: () => FadeMode.off,
    ),
    fadeIn: FadeEndpointSettings.fromJson(j['fadeIn'] as Map<String, dynamic>),
    fadeOut: FadeEndpointSettings.fromJson(
      j['fadeOut'] as Map<String, dynamic>,
    ),
    strokeDecay: j['strokeDecay'] as bool,
    isFavorite: j['isFavorite'] as bool? ?? false,
    folderId: j['folderId'] as String?,
    customImagePath: j['customImagePath'] as String?,
    customImagePaths:
        (j['customImagePaths'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const [],
    customImageSelectionMode: BrushImageSelectionMode.values.firstWhere(
      (e) => e.name == j['customImageSelectionMode'],
      orElse: () => BrushImageSelectionMode.random,
    ),
    imageInkMode: BrushImageInkMode.values.firstWhere(
      (e) => e.name == j['imageInkMode'],
      // Older snapshots did not store the source-ink setting. Preserve their
      // bundled light-on-dark material once, then serialize an explicit mode.
      orElse: () =>
          j['imageInkMode'] == null &&
              [
                j['customImagePath'],
                ...?j['customImagePaths'] as List<dynamic>?,
              ].whereType<String>().any(
                (path) => path.startsWith('assets/brushes/bangs_'),
              )
          ? BrushImageInkMode.light
          : BrushImageInkMode.dark,
    ),
    tipSpacingFactor: (j['tipSpacingFactor'] as num?)?.toDouble() ?? 0,
    chainAspect: (j['chainAspect'] as num?)?.toDouble() ?? .64,
    chainThickness: (j['chainThickness'] as num?)?.toDouble() ?? .25,
    rotation: j['rotation'] as bool? ?? false,
    density: (j['density'] as num?)?.toDouble() ?? 1,
    scatter: (j['scatter'] as num?)?.toDouble() ?? 0,
    calligraphyAngle: (j['calligraphyAngle'] as num?)?.toDouble(),
    pixelColorMode: PixelColorMode.values.firstWhere(
      (e) => e.name == j['pixelColorMode'],
      orElse: () => PixelColorMode.none,
    ),
    pixelColorLevels: j['pixelColorLevels'] as int? ?? 8,
    pixelExplicitColors:
        (j['pixelExplicitColors'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        const [0xFF000000],
    tags: parseTags(j['tags']),
    lateralRepeatEnabled: j['lateralRepeatEnabled'] as bool? ?? false,
    lateralRepeatCount: clampLateralRepeatCount(
      (j['lateralRepeatCount'] as num?)?.toInt() ?? 1,
    ),
    lateralRepeatSpacing: (j['lateralRepeatSpacing'] as num?)?.toDouble() ?? 1,
    outlineEnabled: j['outlineEnabled'] as bool? ?? false,
    outlineWidth: (j['outlineWidth'] as num?)?.toDouble() ?? 1.5,
    outlineColor: (j['outlineColor'] as num?)?.toInt() ?? 0xFF000000,
    foldEnabled: j['foldEnabled'] as bool? ?? false,
    foldTriggerAngle: (j['foldTriggerAngle'] as num?)?.toDouble() ?? 90,
    foldCurveStartRatio: clampFoldRatio(
      (j['foldCurveStartRatio'] as num?)?.toDouble() ?? .25,
      .25,
    ),
    foldCurveStrength: clampFoldCurveStrength(
      (j['foldCurveStrength'] as num?)?.toInt() ?? 5,
    ),
    foldCrescentDepthThreshold: clampFoldCrescentDepthThreshold(
      (j['foldCrescentDepthThreshold'] as num?)?.toDouble() ??
          BrushExtensionDefaults.foldCrescentDepthThreshold,
    ),
    foldLengthRatio: clampFoldRatio(
      (j['foldLengthRatio'] as num?)?.toDouble() ?? .8,
      .8,
    ),
    foldEndTaperRatio: clampFoldRatio(
      (j['foldEndTaperRatio'] as num?)?.toDouble() ?? .35,
      .35,
    ),
    foldMode: HairFoldMode.values.firstWhere(
      (e) => e.name == j['foldMode'],
      orElse: () => HairFoldMode.waveTopView,
    ),
    yBranchAngle: (j['yBranchAngle'] as num?)?.toDouble() ?? 45,
    yBranchLengthRatio: (j['yBranchLengthRatio'] as num?)?.toDouble() ?? .6,
    yBranchWidthRatio: (j['yBranchWidthRatio'] as num?)?.toDouble() ?? .08,
    yBranchEndTaperRatio: (j['yBranchEndTaperRatio'] as num?)?.toDouble() ?? .4,
    tipShape: BrushTipShape.values.firstWhere(
      (e) => e.name == j['tipShape'],
      orElse: () => BrushTipShape.round,
    ),
  );
}

class PressureRangeSetting {
  final bool enabled;
  final int weak;
  final int strong;
  const PressureRangeSetting({
    required this.enabled,
    required this.weak,
    required this.strong,
  });
  PressureRangeSetting copyWith({bool? enabled, int? weak, int? strong}) =>
      PressureRangeSetting(
        enabled: enabled ?? this.enabled,
        weak: weak ?? this.weak,
        strong: strong ?? this.strong,
      );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'weak': weak,
    'strong': strong,
  };
  factory PressureRangeSetting.fromJson(Map<String, dynamic> j) =>
      PressureRangeSetting(
        enabled: j['enabled'] as bool,
        weak: j['weak'] as int,
        strong: j['strong'] as int,
      );
  @override
  bool operator ==(Object other) =>
      other is PressureRangeSetting &&
      enabled == other.enabled &&
      weak == other.weak &&
      strong == other.strong;
  @override
  int get hashCode => Object.hash(enabled, weak, strong);
}

class FixedBrushSetting {
  final bool enabled;
  final int value;
  const FixedBrushSetting({required this.enabled, required this.value});
  FixedBrushSetting copyWith({bool? enabled, int? value}) => FixedBrushSetting(
    enabled: enabled ?? this.enabled,
    value: value ?? this.value,
  );
  Map<String, dynamic> toJson() => {'enabled': enabled, 'value': value};
  factory FixedBrushSetting.fromJson(Map<String, dynamic> j) =>
      FixedBrushSetting(
        enabled: j['enabled'] as bool,
        value: j['value'] as int,
      );
  @override
  bool operator ==(Object other) =>
      other is FixedBrushSetting &&
      enabled == other.enabled &&
      value == other.value;
  @override
  int get hashCode => Object.hash(enabled, value);
}

class PressureMixingOnSetting {
  final bool enabled;
  final BrushMixingMode mode;
  final int weakRate;
  final int strongRate;
  const PressureMixingOnSetting({
    required this.enabled,
    required this.mode,
    required this.weakRate,
    required this.strongRate,
  });
  PressureMixingOnSetting copyWith({
    bool? enabled,
    BrushMixingMode? mode,
    int? weakRate,
    int? strongRate,
  }) => PressureMixingOnSetting(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    weakRate: weakRate ?? this.weakRate,
    strongRate: strongRate ?? this.strongRate,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'mode': mode.name,
    'weakRate': weakRate,
    'strongRate': strongRate,
  };
  factory PressureMixingOnSetting.fromJson(Map<String, dynamic> j) =>
      PressureMixingOnSetting(
        enabled: j['enabled'] as bool,
        mode: BrushMixingMode.values.firstWhere(
          (e) => e.name == j['mode'],
          orElse: () => BrushMixingMode.simple,
        ),
        weakRate: j['weakRate'] as int,
        strongRate: j['strongRate'] as int,
      );
  @override
  bool operator ==(Object other) =>
      other is PressureMixingOnSetting &&
      enabled == other.enabled &&
      mode == other.mode &&
      weakRate == other.weakRate &&
      strongRate == other.strongRate;
  @override
  int get hashCode => Object.hash(enabled, mode, weakRate, strongRate);
}

class PressureMixingOffSetting {
  final bool enabled;
  final BrushMixingMode mode;
  final int rate;
  const PressureMixingOffSetting({
    required this.enabled,
    required this.mode,
    required this.rate,
  });
  PressureMixingOffSetting copyWith({
    bool? enabled,
    BrushMixingMode? mode,
    int? rate,
  }) => PressureMixingOffSetting(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    rate: rate ?? this.rate,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'mode': mode.name,
    'rate': rate,
  };
  factory PressureMixingOffSetting.fromJson(Map<String, dynamic> j) =>
      PressureMixingOffSetting(
        enabled: j['enabled'] as bool,
        mode: BrushMixingMode.values.firstWhere(
          (e) => e.name == j['mode'],
          orElse: () => BrushMixingMode.simple,
        ),
        rate: j['rate'] as int,
      );
  @override
  bool operator ==(Object other) =>
      other is PressureMixingOffSetting &&
      enabled == other.enabled &&
      mode == other.mode &&
      rate == other.rate;
  @override
  int get hashCode => Object.hash(enabled, mode, rate);
}

class BrushPressureOnSettings {
  final PressureRangeSetting size;
  final PressureRangeSetting opacity;
  final PressureRangeSetting blur;
  final PressureRangeSetting edgeJitter;
  final PressureMixingOnSetting mixing;
  const BrushPressureOnSettings({
    required this.size,
    required this.opacity,
    required this.blur,
    required this.edgeJitter,
    required this.mixing,
  });
  static const defaults = BrushPressureOnSettings(
    size: PressureRangeSetting(enabled: false, weak: 100, strong: 100),
    opacity: PressureRangeSetting(enabled: false, weak: 100, strong: 100),
    blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
    edgeJitter: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
    mixing: PressureMixingOnSetting(
      enabled: false,
      mode: BrushMixingMode.simple,
      weakRate: 0,
      strongRate: 0,
    ),
  );
  BrushPressureOnSettings copyWith({
    PressureRangeSetting? size,
    PressureRangeSetting? opacity,
    PressureRangeSetting? blur,
    PressureRangeSetting? edgeJitter,
    PressureMixingOnSetting? mixing,
  }) => BrushPressureOnSettings(
    size: size ?? this.size,
    opacity: opacity ?? this.opacity,
    blur: blur ?? this.blur,
    edgeJitter: edgeJitter ?? this.edgeJitter,
    mixing: mixing ?? this.mixing,
  );
  Map<String, dynamic> toJson() => {
    'size': size.toJson(),
    'opacity': opacity.toJson(),
    'blur': blur.toJson(),
    'edgeJitter': edgeJitter.toJson(),
    'mixing': mixing.toJson(),
  };
  factory BrushPressureOnSettings.fromJson(Map<String, dynamic> j) =>
      BrushPressureOnSettings(
        size: PressureRangeSetting.fromJson(j['size'] as Map<String, dynamic>),
        opacity: PressureRangeSetting.fromJson(
          j['opacity'] as Map<String, dynamic>,
        ),
        blur: PressureRangeSetting.fromJson(j['blur'] as Map<String, dynamic>),
        edgeJitter: PressureRangeSetting.fromJson(
          j['edgeJitter'] as Map<String, dynamic>,
        ),
        mixing: PressureMixingOnSetting.fromJson(
          j['mixing'] as Map<String, dynamic>,
        ),
      );
  @override
  bool operator ==(Object other) =>
      other is BrushPressureOnSettings &&
      size == other.size &&
      opacity == other.opacity &&
      blur == other.blur &&
      edgeJitter == other.edgeJitter &&
      mixing == other.mixing;
  @override
  int get hashCode => Object.hash(size, opacity, blur, edgeJitter, mixing);
}

class BrushPressureOffSettings {
  final FixedBrushSetting blur;
  final FixedBrushSetting edgeJitter;
  final PressureMixingOffSetting mixing;
  const BrushPressureOffSettings({
    required this.blur,
    required this.edgeJitter,
    required this.mixing,
  });
  static const defaults = BrushPressureOffSettings(
    blur: FixedBrushSetting(enabled: false, value: 0),
    edgeJitter: FixedBrushSetting(enabled: false, value: 0),
    mixing: PressureMixingOffSetting(
      enabled: false,
      mode: BrushMixingMode.simple,
      rate: 0,
    ),
  );
  BrushPressureOffSettings copyWith({
    FixedBrushSetting? blur,
    FixedBrushSetting? edgeJitter,
    PressureMixingOffSetting? mixing,
  }) => BrushPressureOffSettings(
    blur: blur ?? this.blur,
    edgeJitter: edgeJitter ?? this.edgeJitter,
    mixing: mixing ?? this.mixing,
  );
  Map<String, dynamic> toJson() => {
    'blur': blur.toJson(),
    'edgeJitter': edgeJitter.toJson(),
    'mixing': mixing.toJson(),
  };
  factory BrushPressureOffSettings.fromJson(Map<String, dynamic> j) =>
      BrushPressureOffSettings(
        blur: FixedBrushSetting.fromJson(j['blur'] as Map<String, dynamic>),
        edgeJitter: FixedBrushSetting.fromJson(
          j['edgeJitter'] as Map<String, dynamic>,
        ),
        mixing: PressureMixingOffSetting.fromJson(
          j['mixing'] as Map<String, dynamic>,
        ),
      );
  @override
  bool operator ==(Object other) =>
      other is BrushPressureOffSettings &&
      blur == other.blur &&
      edgeJitter == other.edgeJitter &&
      mixing == other.mixing;
  @override
  int get hashCode => Object.hash(blur, edgeJitter, mixing);
}

enum FadeMode { off, weak, medium, strong, custom }

enum BrushTipShape { round, hollowSquare, hexagon, chainLink, ballChain }

enum BrushImageSelectionMode { random, sequential }

class FadeEndpointSettings {
  final double value;
  final double rangePx;
  const FadeEndpointSettings({required this.value, required this.rangePx});
  static const full = FadeEndpointSettings(value: 100, rangePx: 500);
  FadeEndpointSettings copyWith({double? value, double? rangePx}) =>
      FadeEndpointSettings(
        value: value ?? this.value,
        rangePx: rangePx ?? this.rangePx,
      );
  Map<String, dynamic> toJson() => {'value': value, 'rangePx': rangePx};
  factory FadeEndpointSettings.fromJson(Map<String, dynamic> j) =>
      FadeEndpointSettings(
        value: (j['value'] as num).toDouble(),
        rangePx: (j['rangePx'] as num).toDouble(),
      );
}

const List<int> kMixingRateOptions = [0, 20, 40, 60, 80, 100];

enum BrushMixingMode { off, simple, bleed }
