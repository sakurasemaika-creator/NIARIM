/// 描画フィルターの種別（仕様書18：初期実装フィルター）。
/// 実際のピクセル処理はlib/engine/filter_engine.dartのFilterEngineが行う。
/// toneCurve・levelsはプレミアム限定（仕様書01・13・20）。
enum FilterKind { gaussianBlur, lensBlur, animeStyle, toneCurve, levels }

/// トーンカーブのプリセット形状（仕様書20：トーンカーブ）。
/// 本格的な自由曲線編集の代わりに、よく使う形状をプリセットとして提供する。
enum ToneCurvePreset { linear, brighten, darken, highContrast, lowContrast, invert }

/// フィルター定義＋現在のパラメータ値。
///
/// [strength]の意味は種別によって異なる（FilterEngineの各メソッドの引数に
/// そのまま渡される）：
/// - gaussianBlur / lensBlur：ぼかし半径（px、1〜20）
/// - animeStyle：現状FilterEngine内では未使用（将来の強さ調整用に保持）
///
/// [colorLevels]・[edgeStrength]はanimeStyleのみで使用する
/// （edgeStrengthはSobelエッジ強度（0〜255程度）へ掛ける係数のため、
/// 0.0〜1.0程度の小さい値を想定）。
class FilterDef {
  final String id;
  final String name;
  final FilterKind kind;
  final bool isFavorite;
  final double strength;
  final int colorLevels;
  final double edgeStrength;
  // レベル補正（levelsのみ使用。仕様書20：入力・出力レベル）
  final int inputBlack;
  final int inputWhite;
  final int outputBlack;
  final int outputWhite;
  // トーンカーブ（toneCurveのみ使用）
  final ToneCurvePreset toneCurvePreset;

  const FilterDef({
    required this.id,
    required this.name,
    required this.kind,
    this.isFavorite = false,
    this.strength = 8,
    this.colorLevels = 6,
    this.edgeStrength = 0.4,
    this.inputBlack = 0,
    this.inputWhite = 255,
    this.outputBlack = 0,
    this.outputWhite = 255,
    this.toneCurvePreset = ToneCurvePreset.linear,
  });

  FilterDef copyWith({
    String? id,
    String? name,
    FilterKind? kind,
    bool? isFavorite,
    double? strength,
    int? colorLevels,
    double? edgeStrength,
    int? inputBlack,
    int? inputWhite,
    int? outputBlack,
    int? outputWhite,
    ToneCurvePreset? toneCurvePreset,
  }) {
    return FilterDef(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      isFavorite: isFavorite ?? this.isFavorite,
      strength: strength ?? this.strength,
      colorLevels: colorLevels ?? this.colorLevels,
      edgeStrength: edgeStrength ?? this.edgeStrength,
      inputBlack: inputBlack ?? this.inputBlack,
      inputWhite: inputWhite ?? this.inputWhite,
      outputBlack: outputBlack ?? this.outputBlack,
      outputWhite: outputWhite ?? this.outputWhite,
      toneCurvePreset: toneCurvePreset ?? this.toneCurvePreset,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'isFavorite': isFavorite,
        'strength': strength,
        'colorLevels': colorLevels,
        'edgeStrength': edgeStrength,
        'inputBlack': inputBlack,
        'inputWhite': inputWhite,
        'outputBlack': outputBlack,
        'outputWhite': outputWhite,
        'toneCurvePreset': toneCurvePreset.name,
      };

  factory FilterDef.fromJson(Map<String, dynamic> j) => FilterDef(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: FilterKind.values
            .firstWhere((e) => e.name == j['kind'], orElse: () => FilterKind.gaussianBlur),
        isFavorite: j['isFavorite'] as bool? ?? false,
        strength: (j['strength'] as num?)?.toDouble() ?? 8,
        colorLevels: j['colorLevels'] as int? ?? 6,
        edgeStrength: (j['edgeStrength'] as num?)?.toDouble() ?? 0.4,
        inputBlack: j['inputBlack'] as int? ?? 0,
        inputWhite: j['inputWhite'] as int? ?? 255,
        outputBlack: j['outputBlack'] as int? ?? 0,
        outputWhite: j['outputWhite'] as int? ?? 255,
        toneCurvePreset: ToneCurvePreset.values.firstWhere(
            (e) => e.name == j['toneCurvePreset'],
            orElse: () => ToneCurvePreset.linear),
      );
}
