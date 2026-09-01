import 'pixel_color_mode.dart';

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
  // カリグラフィーペン用：ペン先の固定角度（度、0〜360）。nullなら通常の
  // 円形ブラシ（スタイラスの傾き検知があればそちらで扁平化する）。指定時は
  // 実際のスタイラス傾きに関わらず、常にこの角度へ扁平化したペン先で
  // スタンプする（進行方向によって線の太さが変わるカリグラフィー特有の
  // 見た目を、傾き検知非対応の端末でも一定の見た目で再現するため）。
  final double? calligraphyAngle;
  // ふち滲み：trueのとき、ブラシスタンプのふち付近のピクセルに微小な
  // ランダムオフセットを加え、輪郭をわずかにがたがたさせる。
  // マーカーペンのインクが紙の繊維に沿って滲む様子を再現する。
  final bool edgeJitter;
  // ふち滲みの強度（0〜100）。0は最小限のがたがた、100は最大限の滲み。
  // edgeJitterがtrueのときのみ有効。
  final int edgeJitterStrength;
  // ピクセルモード時の配色方式。既定はnone（従来通り、描画色をそのまま
  // 使い色数の制限を行わない）。ストローク確定直後にタッチした範囲だけへ
  // 適用される（drawing_engine.dart・canvas_area.dartの
  // _quantizeStrokeIfNeeded参照）。
  final PixelColorMode pixelColorMode;
  final int pixelColorLevels;
  final List<int> pixelExplicitColors;

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
    this.calligraphyAngle,
    this.edgeJitter = false,
    this.edgeJitterStrength = 50,
    this.pixelColorMode = PixelColorMode.none,
    this.pixelColorLevels = 8,
    this.pixelExplicitColors = const [0xFF000000],
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
    double? calligraphyAngle,
    bool? edgeJitter,
    int? edgeJitterStrength,
    PixelColorMode? pixelColorMode,
    int? pixelColorLevels,
    List<int>? pixelExplicitColors,
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
      calligraphyAngle: calligraphyAngle ?? this.calligraphyAngle,
      edgeJitter: edgeJitter ?? this.edgeJitter,
      edgeJitterStrength: edgeJitterStrength ?? this.edgeJitterStrength,
      pixelColorMode: pixelColorMode ?? this.pixelColorMode,
      pixelColorLevels: pixelColorLevels ?? this.pixelColorLevels,
      pixelExplicitColors: pixelExplicitColors ?? this.pixelExplicitColors,
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
        'calligraphyAngle': calligraphyAngle,
        'edgeJitter': edgeJitter,
        'edgeJitterStrength': edgeJitterStrength,
        'pixelColorMode': pixelColorMode.name,
        'pixelColorLevels': pixelColorLevels,
        'pixelExplicitColors': pixelExplicitColors,
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
        calligraphyAngle: (j['calligraphyAngle'] as num?)?.toDouble(),
        edgeJitter: j['edgeJitter'] as bool? ?? false,
        edgeJitterStrength: j['edgeJitterStrength'] as int? ?? 50,
        pixelColorMode: PixelColorMode.values.firstWhere(
            (e) => e.name == j['pixelColorMode'], orElse: () => PixelColorMode.none),
        pixelColorLevels: j['pixelColorLevels'] as int? ?? 8,
        pixelExplicitColors: (j['pixelExplicitColors'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [0xFF000000],
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
