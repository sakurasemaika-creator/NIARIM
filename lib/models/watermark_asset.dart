/// ウォーターマークの種別（仕様書01・13：「設定項目：画像選択 / 文字入力 / …」）。
enum WatermarkAssetType { image, text }

/// 登録済みウォーターマーク（プレミアム限定、仕様書08・13）。
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
  // フォント（type==textの場合のみ使用。ユーザー指示によりフォントも
  // 自由に選べるようにした。組み込みフォントは'Roboto'等の固定値、
  // 追加フォントはFontService.familyNameOf()の値）。
  final String? fontFamily;

  const WatermarkAsset({
    required this.id,
    required this.name,
    this.type = WatermarkAssetType.image,
    this.fileName,
    this.text,
    this.textColor,
    this.fontFamily,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'fileName': fileName,
        'text': text,
        'textColor': textColor,
        'fontFamily': fontFamily,
      };

  factory WatermarkAsset.fromJson(Map<String, dynamic> json) => WatermarkAsset(
        id: json['id'] as String,
        name: json['name'] as String,
        type: WatermarkAssetType.values.asNameMap()[json['type'] as String?] ?? WatermarkAssetType.image,
        fileName: json['fileName'] as String?,
        text: json['text'] as String?,
        textColor: json['textColor'] as int?,
        fontFamily: json['fontFamily'] as String?,
      );
}
