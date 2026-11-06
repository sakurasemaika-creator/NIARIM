/// ウォーターマークの種別（画像選択 / 文字入力）。
enum WatermarkAssetType { image, text }

/// 登録済みウォーターマーク（プレミアム限定）。
/// 設定画面の「ウォーターマーク」カテゴリで複数登録・管理する。
/// [type]がimageの場合は[fileName]（アプリのwatermarksディレクトリ内の
/// ファイル名）を、textの場合は[text]/[textColor]を使用する。
class WatermarkAsset {
  final String id;
  final String name;
  final WatermarkAssetType type;
  final String? fileName;
  final String? text;
  final int? textColor; // ARGB int（type==textの場合のみ使用）
  // フォント（type==textの場合のみ使用。組み込みフォントは'Roboto'等の
  // 固定値、追加フォントはFontService.familyNameOf()の値）。
  final String? fontFamily;
  // ドロップシャドウ・縁取りの既定設定。設定画面で事前に調整でき、実際に
  // タイムラインへ配置する際のラスタライズ時に適用される
  // （_reRasterizeWatermark参照）。
  final bool shadowEnabled;
  final int shadowColor;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final double shadowBlur;
  final bool outlineEnabled;
  final int outlineColor;
  final double outlineWidth;

  const WatermarkAsset({
    required this.id,
    required this.name,
    this.type = WatermarkAssetType.image,
    this.fileName,
    this.text,
    this.textColor,
    this.fontFamily,
    this.shadowEnabled = false,
    this.shadowColor = 0x99000000,
    this.shadowOffsetX = 4,
    this.shadowOffsetY = 4,
    this.shadowBlur = 6,
    this.outlineEnabled = false,
    this.outlineColor = 0xFFFFFFFF,
    this.outlineWidth = 3,
  });

  WatermarkAsset copyWith({
    String? name,
    String? text,
    int? textColor,
    String? fontFamily,
    bool? shadowEnabled,
    int? shadowColor,
    double? shadowOffsetX,
    double? shadowOffsetY,
    double? shadowBlur,
    bool? outlineEnabled,
    int? outlineColor,
    double? outlineWidth,
  }) {
    return WatermarkAsset(
      id: id,
      name: name ?? this.name,
      type: type,
      fileName: fileName,
      text: text ?? this.text,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      shadowEnabled: shadowEnabled ?? this.shadowEnabled,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      outlineEnabled: outlineEnabled ?? this.outlineEnabled,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'fileName': fileName,
    'text': text,
    'textColor': textColor,
    'fontFamily': fontFamily,
    'shadowEnabled': shadowEnabled,
    'shadowColor': shadowColor,
    'shadowOffsetX': shadowOffsetX,
    'shadowOffsetY': shadowOffsetY,
    'shadowBlur': shadowBlur,
    'outlineEnabled': outlineEnabled,
    'outlineColor': outlineColor,
    'outlineWidth': outlineWidth,
  };

  factory WatermarkAsset.fromJson(Map<String, dynamic> json) => WatermarkAsset(
    id: json['id'] as String,
    name: json['name'] as String,
    type:
        WatermarkAssetType.values.asNameMap()[json['type'] as String?] ??
        WatermarkAssetType.image,
    fileName: json['fileName'] as String?,
    text: json['text'] as String?,
    textColor: json['textColor'] as int?,
    fontFamily: json['fontFamily'] as String?,
    shadowEnabled: json['shadowEnabled'] as bool? ?? false,
    shadowColor: json['shadowColor'] as int? ?? 0x99000000,
    shadowOffsetX: (json['shadowOffsetX'] as num?)?.toDouble() ?? 4,
    shadowOffsetY: (json['shadowOffsetY'] as num?)?.toDouble() ?? 4,
    shadowBlur: (json['shadowBlur'] as num?)?.toDouble() ?? 6,
    outlineEnabled: json['outlineEnabled'] as bool? ?? false,
    outlineColor: json['outlineColor'] as int? ?? 0xFFFFFFFF,
    outlineWidth: (json['outlineWidth'] as num?)?.toDouble() ?? 3,
  );
}
