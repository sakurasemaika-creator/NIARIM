import 'asset_tags.dart';
import 'pixel_color_mode.dart';

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
  final FadeCustomSettings? fadeCustom;
  final bool strokeDecay;
  final bool isFavorite;
  final String? folderId;
  final String? customImagePath;
  final bool rotation;
  final double density;
  final double scatter;
  final double? calligraphyAngle;
  final PixelColorMode pixelColorMode;
  final int pixelColorLevels;
  final List<int> pixelExplicitColors;
  final List<String> tags;

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
    this.fadeCustom,
    required this.strokeDecay,
    this.isFavorite = false,
    this.folderId,
    this.customImagePath,
    this.rotation = false,
    this.density = 1.0,
    this.scatter = 0.0,
    this.calligraphyAngle,
    this.pixelColorMode = PixelColorMode.none,
    this.pixelColorLevels = 8,
    this.pixelExplicitColors = const [0xFF000000],
    this.tags = const [],
  });

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
    FadeCustomSettings? fadeCustom,
    bool? strokeDecay,
    bool? isFavorite,
    String? folderId,
    String? customImagePath,
    bool? rotation,
    double? density,
    double? scatter,
    double? calligraphyAngle,
    PixelColorMode? pixelColorMode,
    int? pixelColorLevels,
    List<int>? pixelExplicitColors,
    List<String>? tags,
  }) {
    return Brush(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      spacing: spacing ?? this.spacing,
      stabilization: stabilization ?? this.stabilization,
      stabilizationStrength:
          stabilizationStrength ?? this.stabilizationStrength,
      pixelMode: pixelMode ?? this.pixelMode,
      pressureOn: pressureOn ?? this.pressureOn,
      pressureOff: pressureOff ?? this.pressureOff,
      fadeMode: fadeMode ?? this.fadeMode,
      fadeCustom: fadeCustom ?? this.fadeCustom,
      strokeDecay: strokeDecay ?? this.strokeDecay,
      isFavorite: isFavorite ?? this.isFavorite,
      folderId: folderId ?? this.folderId,
      customImagePath: customImagePath ?? this.customImagePath,
      rotation: rotation ?? this.rotation,
      density: density ?? this.density,
      scatter: scatter ?? this.scatter,
      calligraphyAngle: calligraphyAngle ?? this.calligraphyAngle,
      pixelColorMode: pixelColorMode ?? this.pixelColorMode,
      pixelColorLevels: pixelColorLevels ?? this.pixelColorLevels,
      pixelExplicitColors: pixelExplicitColors ?? this.pixelExplicitColors,
      tags: tags ?? this.tags,
    );
  }

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
    'fadeCustom': fadeCustom == null
        ? null
        : {
            'startValue': fadeCustom!.startValue,
            'endValue': fadeCustom!.endValue,
            'distancePx': fadeCustom!.distancePx,
          },
    'strokeDecay': strokeDecay,
    'isFavorite': isFavorite,
    'folderId': folderId,
    'customImagePath': customImagePath,
    'rotation': rotation,
    'density': density,
    'scatter': scatter,
    'calligraphyAngle': calligraphyAngle,
    'pixelColorMode': pixelColorMode.name,
    'pixelColorLevels': pixelColorLevels,
    'pixelExplicitColors': pixelExplicitColors,
    'tags': tags,
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
    fadeCustom: j['fadeCustom'] == null
        ? null
        : FadeCustomSettings(
            startValue:
                ((j['fadeCustom'] as Map<String, dynamic>)['startValue'] as num)
                    .toDouble(),
            endValue:
                ((j['fadeCustom'] as Map<String, dynamic>)['endValue'] as num)
                    .toDouble(),
            distancePx:
                ((j['fadeCustom'] as Map<String, dynamic>)['distancePx'] as num)
                    .toDouble(),
          ),
    strokeDecay: j['strokeDecay'] as bool,
    isFavorite: j['isFavorite'] as bool? ?? false,
    folderId: j['folderId'] as String?,
    customImagePath: j['customImagePath'] as String?,
    rotation: j['rotation'] as bool? ?? false,
    density: (j['density'] as num?)?.toDouble() ?? 1.0,
    scatter: (j['scatter'] as num?)?.toDouble() ?? 0.0,
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
        mode: BrushMixingMode.values.firstWhere((e) => e.name == j['mode']),
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
        mode: BrushMixingMode.values.firstWhere((e) => e.name == j['mode']),
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
    size: PressureRangeSetting(enabled: true, weak: 50, strong: 100),
    opacity: PressureRangeSetting(enabled: true, weak: 50, strong: 100),
    blur: PressureRangeSetting(enabled: false, weak: 50, strong: 0),
    edgeJitter: PressureRangeSetting(enabled: false, weak: 50, strong: 0),
    mixing: PressureMixingOnSetting(
      enabled: false,
      mode: BrushMixingMode.simple,
      weakRate: 50,
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

class FadeCustomSettings {
  final double startValue;
  final double endValue;
  final double distancePx;
  const FadeCustomSettings({
    required this.startValue,
    required this.endValue,
    required this.distancePx,
  });
}

const List<int> kMixingRateOptions = [0, 20, 40, 60, 80, 100];

enum BrushMixingMode { off, simple, bleed }
