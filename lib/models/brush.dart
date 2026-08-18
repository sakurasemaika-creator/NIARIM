class Brush {
  final String id;
  final String name;
  final double size;
  final int opacity;
  final int spacing;
  final int blurRadius;
  final bool stabilization;
  final int stabilizationStrength;
  final bool pixelMode;
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
    required this.pixelMode,
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
    bool? pixelMode,
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
      pixelMode: pixelMode ?? this.pixelMode,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'opacity': opacity,
        'spacing': spacing,
        'blurRadius': blurRadius,
        'stabilization': stabilization,
        'stabilizationStrength': stabilizationStrength,
        'pixelMode': pixelMode,
        'pressureMode': pressureMode.name,
        'pressureStrength': pressureStrength,
        'fadeMode': fadeMode.name,
        'fadeCustom': fadeCustom == null
            ? null
            : {
                'startValue': fadeCustom!.startValue,
                'endValue': fadeCustom!.endValue,
                'distancePx': fadeCustom!.distancePx,
              },
        'strokeDecay': strokeDecay,
        'mixingMode': mixingMode.name,
        'mixingRate': mixingRate,
        'isFavorite': isFavorite,
        'folderId': folderId,
        'customImagePath': customImagePath,
      };

  factory Brush.fromJson(Map<String, dynamic> j) => Brush(
        id: j['id'] as String,
        name: j['name'] as String,
        size: (j['size'] as num).toDouble(),
        opacity: j['opacity'] as int,
        spacing: j['spacing'] as int,
        blurRadius: j['blurRadius'] as int,
        stabilization: j['stabilization'] as bool,
        stabilizationStrength: j['stabilizationStrength'] as int,
        // pixelModeは旧称dotPenModeからの改称（「ドット」だと水玉模様と
        // 誤認される恐れがあるため）。旧バージョンで保存・共有
        // 済みのブラシ（.niabrush・SharedPreferences永続化データ）を
        // 引き続き読み込めるよう、旧キーからのフォールバックを残す。
        pixelMode: (j['pixelMode'] ?? j['dotPenMode']) as bool? ?? false,
        pressureMode: PressureMode.values
            .firstWhere((e) => e.name == j['pressureMode'], orElse: () => PressureMode.off),
        pressureStrength: j['pressureStrength'] as int,
        fadeMode:
            FadeMode.values.firstWhere((e) => e.name == j['fadeMode'], orElse: () => FadeMode.off),
        fadeCustom: j['fadeCustom'] == null
            ? null
            : FadeCustomSettings(
                startValue: ((j['fadeCustom'] as Map<String, dynamic>)['startValue'] as num)
                    .toDouble(),
                endValue:
                    ((j['fadeCustom'] as Map<String, dynamic>)['endValue'] as num).toDouble(),
                distancePx:
                    ((j['fadeCustom'] as Map<String, dynamic>)['distancePx'] as num).toDouble(),
              ),
        strokeDecay: j['strokeDecay'] as bool,
        mixingMode: BrushMixingMode.values
            .firstWhere((e) => e.name == j['mixingMode'], orElse: () => BrushMixingMode.off),
        mixingRate: j['mixingRate'] as int,
        isFavorite: j['isFavorite'] as bool? ?? false,
        folderId: j['folderId'] as String?,
        customImagePath: j['customImagePath'] as String?,
      );
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
