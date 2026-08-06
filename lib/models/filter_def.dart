/// 描画フィルターの種別（仕様書18：初期実装フィルター）。
/// 実際のピクセル処理はlib/engine/filter_engine.dartのFilterEngineが行う。
enum FilterKind { gaussianBlur, lensBlur, animeStyle }

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

  const FilterDef({
    required this.id,
    required this.name,
    required this.kind,
    this.isFavorite = false,
    this.strength = 8,
    this.colorLevels = 6,
    this.edgeStrength = 0.4,
  });

  FilterDef copyWith({
    String? id,
    String? name,
    FilterKind? kind,
    bool? isFavorite,
    double? strength,
    int? colorLevels,
    double? edgeStrength,
  }) {
    return FilterDef(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      isFavorite: isFavorite ?? this.isFavorite,
      strength: strength ?? this.strength,
      colorLevels: colorLevels ?? this.colorLevels,
      edgeStrength: edgeStrength ?? this.edgeStrength,
    );
  }
}
