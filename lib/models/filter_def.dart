/// 描画フィルターの種別（仕様書18：初期実装フィルター）。
/// 実際のピクセル処理はlib/engine/filter_engine.dartのFilterEngineが行う。
/// toneCurve・levelsはプレミアム限定（仕様書01・13・20）。
/// outline：選択レイヤーの描画内容（不透明部分）の周囲を指定色・指定px幅で
/// 縁取る。
/// sharpen：3x3カーネルによるシャープ化。unsharpMask：ぼかしとの差分を
/// 使った強めのシャープ化（アンシャープマスク）。いずれも小さな畳み込み
/// カーネル・既存のガウスぼかし1回分程度の負荷しかなく、低スペック端末
/// でも軽く動作する。
/// vignette：周辺減光（画面の四隅を暗くして中央を強調する、イラスト・
/// 漫画の演出で定番の効果）。1画素あたり中心からの距離計算のみの単純な
/// 1パス処理で、既存のフィルターと同等以下の軽い負荷。
/// noise：粒状ノイズ（フィルム・紙のような質感を付加する）。演出フィルター
/// （EffectFilterType.noise）と同じFilterEngine.applyNoiseを描画フィルター
/// としても使えるようにしたもの。
/// retroAnime：暖色寄りのカラーグレーディング・彩度低下・粒状ノイズを
/// 組み合わせた、昔のセルアニメ・VHS録画のような質感。
/// crt：色収差・周辺減光・走査線を組み合わせたブラウン管ディスプレイ風の質感。
/// fisheye：魚眼レンズ風の湾曲（[strength]が大きいほど中心が膨らみ、
/// 周辺が圧縮される）。chromaticAberration：色収差（[strength]が大きいほど
/// RGBチャンネルの水平方向のずれが大きくなる）。
/// lensDistortion（眼鏡断層フィルター）：選択レイヤー（LayerType.selection）で
/// 塗った範囲（連結成分ごと、複数可＝両目分を同時に等）だけを対象に、
/// 度数の強い眼鏡レンズの光学屈折を模した局所的な放射状ワープをかける。
/// [strength]は-100〜100（0で無効。負で凹レンズ風に縮小、正で凸レンズ風に
/// 拡大）。中心点は各連結成分の重心を自動で使うが、[lensCenterOffsetX]・
/// [lensCenterOffsetY]（px、既定0）でその重心から手動でずらせる
/// （瞳の位置とレンズ中心を厳密に一致させたい場合の微調整用。全連結成分へ
/// 同じオフセットを適用する簡略実装）。選択レイヤーが存在しない・
/// マスクが空の場合、このフィルターは何も行わない（`FilterEngine`
/// 参照）。
/// monochrome（単色化）：輝度に応じて指定した1色（[monochromeColor]、既定は
/// 白＝従来通りのグレースケール）を掛け合わせる。単なる白黒化ではなく、
/// セピア調・任意の単色トーンなど好きな色で単色化できる。
/// threshold（二値化）：輝度が[thresholdValue]以上の画素を白、未満を黒へ
/// 分ける。色調調整・単色化・「明度で透過」と組み合わせると線画抽出に使える
/// （仕様書28）。
enum FilterKind {
  gaussianBlur, lensBlur, animeStyle, outline, toneCurve, levels, sharpen, unsharpMask, vignette, noise,
  retroAnime, crt, monochrome, colorAdjust, threshold, fisheye, chromaticAberration, lensDistortion,
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
  // 周辺減光の減光先の色（vignetteのみ使用。既定は黒＝従来通りの暗くする
  // だけの見た目）。ARGB32形式のintで、他パラメータ同様プリミティブ型のみ
  // で構成する。
  final int vignetteColor;
  // 色調調整（colorAdjustのみ使用）：彩度・明度・コントラスト、
  // いずれも-100〜100（0が変化なし）。
  final double caSaturation;
  final double caBrightness;
  final double caContrast;
  // 単色化の色（monochromeのみ使用）。既定は白＝輝度そのまま（従来の
  // グレースケール仕様と完全互換）。ARGB32形式のint。
  final int monochromeColor;
  // 二値化の閾値（thresholdのみ使用）。0〜255、既定128。
  final double thresholdValue;
  // 眼鏡断層フィルターの中心点手動オフセット（lensDistortionのみ使用）。
  // 各連結成分の自動重心からのpx単位のずれ、既定0（自動重心そのまま）。
  final double lensCenterOffsetX;
  final double lensCenterOffsetY;

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
    this.vignetteColor = 0xFF000000,
    this.caSaturation = 0,
    this.caBrightness = 0,
    this.caContrast = 0,
    this.monochromeColor = 0xFFFFFFFF,
    this.thresholdValue = 128,
    this.lensCenterOffsetX = 0,
    this.lensCenterOffsetY = 0,
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
    int? vignetteColor,
    double? caSaturation,
    double? caBrightness,
    double? caContrast,
    int? monochromeColor,
    double? thresholdValue,
    double? lensCenterOffsetX,
    double? lensCenterOffsetY,
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
      vignetteColor: vignetteColor ?? this.vignetteColor,
      caSaturation: caSaturation ?? this.caSaturation,
      caBrightness: caBrightness ?? this.caBrightness,
      caContrast: caContrast ?? this.caContrast,
      monochromeColor: monochromeColor ?? this.monochromeColor,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      lensCenterOffsetX: lensCenterOffsetX ?? this.lensCenterOffsetX,
      lensCenterOffsetY: lensCenterOffsetY ?? this.lensCenterOffsetY,
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
        'vignetteColor': vignetteColor,
        'caSaturation': caSaturation,
        'caBrightness': caBrightness,
        'caContrast': caContrast,
        'monochromeColor': monochromeColor,
        'thresholdValue': thresholdValue,
        'lensCenterOffsetX': lensCenterOffsetX,
        'lensCenterOffsetY': lensCenterOffsetY,
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
        caSaturation: (j['caSaturation'] as num?)?.toDouble() ?? 0,
        caBrightness: (j['caBrightness'] as num?)?.toDouble() ?? 0,
        caContrast: (j['caContrast'] as num?)?.toDouble() ?? 0,
        toneCurvePreset: ToneCurvePreset.values.firstWhere(
            (e) => e.name == j['toneCurvePreset'],
            orElse: () => ToneCurvePreset.linear),
        outlineColor: j['outlineColor'] as int? ?? 0xFF000000,
        outlineWidth: (j['outlineWidth'] as num?)?.toDouble() ?? 6,
        vignetteColor: j['vignetteColor'] as int? ?? 0xFF000000,
        monochromeColor: j['monochromeColor'] as int? ?? 0xFFFFFFFF,
        thresholdValue: (j['thresholdValue'] as num?)?.toDouble() ?? 128,
        lensCenterOffsetX: (j['lensCenterOffsetX'] as num?)?.toDouble() ?? 0,
        lensCenterOffsetY: (j['lensCenterOffsetY'] as num?)?.toDouble() ?? 0,
      );
}
