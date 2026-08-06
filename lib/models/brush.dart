class Brush {
  final String id;
  final String name;
  final double size;
  final int opacity;
  final int spacing;
  final int blurRadius;
  final bool stabilization;
  final int stabilizationStrength;
  final bool dotPenMode;
  final PressureMode pressureMode;
  final int pressureStrength;
  final FadeMode fadeMode;
  final FadeCustomSettings? fadeCustom;
  final bool strokeDecay;
  final BrushMixingMode mixingMode;
  final int mixingRate;
  final bool isFavorite;
  final String? folderId;
  final String? customImagePath;

  const Brush({
    required this.id,
    required this.name,
    required this.size,
    required this.opacity,
    required this.spacing,
    required this.blurRadius,
    required this.stabilization,
    required this.stabilizationStrength,
    required this.dotPenMode,
    required this.pressureMode,
    required this.pressureStrength,
    required this.fadeMode,
    this.fadeCustom,
    required this.strokeDecay,
    required this.mixingMode,
    required this.mixingRate,
    this.isFavorite = false,
    this.folderId,
    this.customImagePath,
  });

  Brush copyWith({
    String? id,
    String? name,
    double? size,
    int? opacity,
    int? spacing,
    int? blurRadius,
    bool? stabilization,
    int? stabilizationStrength,
    bool? dotPenMode,
    PressureMode? pressureMode,
    int? pressureStrength,
    FadeMode? fadeMode,
    FadeCustomSettings? fadeCustom,
    bool? strokeDecay,
    BrushMixingMode? mixingMode,
    int? mixingRate,
    bool? isFavorite,
    String? folderId,
    String? customImagePath,
  }) {
    return Brush(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      spacing: spacing ?? this.spacing,
      blurRadius: blurRadius ?? this.blurRadius,
      stabilization: stabilization ?? this.stabilization,
      stabilizationStrength: stabilizationStrength ?? this.stabilizationStrength,
      dotPenMode: dotPenMode ?? this.dotPenMode,
      pressureMode: pressureMode ?? this.pressureMode,
      pressureStrength: pressureStrength ?? this.pressureStrength,
      fadeMode: fadeMode ?? this.fadeMode,
      fadeCustom: fadeCustom ?? this.fadeCustom,
      strokeDecay: strokeDecay ?? this.strokeDecay,
      mixingMode: mixingMode ?? this.mixingMode,
      mixingRate: mixingRate ?? this.mixingRate,
      isFavorite: isFavorite ?? this.isFavorite,
      folderId: folderId ?? this.folderId,
      customImagePath: customImagePath ?? this.customImagePath,
    );
  }
}

enum PressureMode { off, size, opacity, sizeAndOpacity }

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

// 混色率の選択肢: 0=OFF, 20, 40, 60, 80, 100
const List<int> kMixingRateOptions = [0, 20, 40, 60, 80, 100];

enum BrushMixingMode { off, simple, bleed }
