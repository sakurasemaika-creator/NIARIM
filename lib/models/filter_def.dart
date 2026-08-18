/// 描画フィルターの種別（仕様書18：初期実装フィルター）。
/// 実際のピクセル処理はlib/engine/filter_engine.dartのFilterEngineが行う。
/// toneCurve・levelsはプレミアム限定（仕様書01・13・20）。
/// outline：選択レイヤーの描画内容（不透明部分）の周囲を指定色・指定px幅で
/// 縁取る（ユーザー指示により新規追加）。
/// sharpen：3x3カーネルによるシャープ化。unsharpMask：ぼかしとの差分を
/// 使った強めのシャープ化（アンシャープマスク）。いずれも小さな畳み込み
/// カーネル・既存のガウスぼかし1回分程度の負荷しかなく、低スペック端末
/// でも軽く動作する（ユーザー確認済みの上で新規追加）。
/// vignette：周辺減光（画面の四隅を暗くして中央を強調する、イラスト・
/// 漫画の演出で定番の効果）。1画素あたり中心からの距離計算のみの単純な
/// 1パス処理で、既存のフィルターと同等以下の軽い負荷。
/// noise：粒状ノイズ（フィルム・紙のような質感を付加する）。演出フィルター
/// （EffectFilterType.noise）と同じFilterEngine.applyNoiseを描画フィルター
/// としても使えるようにしたもの。
/// retroAnime：暖色寄りのカラーグレーディング・彩度低下・粒状ノイズを
/// 組み合わせた、昔のセルアニメ・VHS録画のような質感。
/// crt：色収差・周辺減光・走査線を組み合わせたブラウン管ディスプレイ風の質感。
enum FilterKind {
  gaussianBlur, lensBlur, animeStyle, outline, toneCurve, levels, sharpen, unsharpMask, vignette, noise,
  retroAnime, crt,
}

/// トーンカーブのプリセット形状（仕様書20：トーンカーブ）。
/// 本格的な自由曲線編集の代わりに、よく使う形状をプリセットとして提供する。
enum ToneCurvePreset { linear, brighten, darken, highContrast, lowContrast, invert }

/// フィルター定義＋現在のパラメータ値。
///
/// [strength]の意味は種別によって異なる（FilterEngineの各メソッドの引数に
/// そのまま渡される）：
/// - gaussianBlur / lensBlur：ぼかし半径（px、1〜20）
/// - animeStyle：現状FilterEngine内では未使用（将来の強さ調整用に保持）
/// - sharpen：シャープ化の強さ（0〜100%）
/// - unsharpMask：ぼかし半径（px、1〜20。gaussianBlurと同じ意味）
///
/// [colorLevels]はanimeStyleのみで使用する。
/// [edgeStrength]はanimeStyle（Sobelエッジ強度（0〜255程度）へ掛ける係数、
/// 0.0〜1.0程度の小さい値を想定）とunsharpMask（アンシャープマスクの
/// かかり具合。0.0〜3.0程度、既定1.0）の両方で使用する。
/// [outlineColor]・[outlineWidth]はoutlineのみで使用する。outlineColorは
/// ARGB32形式のint値（他のパラメータと同様プリミティブ型のみで構成し、
/// compute()でのisolate越え受け渡しでも安全なようにしている。dart:ui.Colorへの
/// 変換はUI層（filter_panel.dart）・FilterEngine側でその都度行う）。
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
  // 縁取り（outlineのみ使用）
  final int outlineColor;
  final double outlineWidth;

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
    this.outlineColor = 0xFF000000,
    this.outlineWidth = 6,
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
    int? outlineColor,
    double? outlineWidth,
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
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
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
        'outlineColor': outlineColor,
        'outlineWidth': outlineWidth,
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
        outlineColor: j['outlineColor'] as int? ?? 0xFF000000,
        outlineWidth: (j['outlineWidth'] as num?)?.toDouble() ?? 6,
      );
}
