/// 登録済みウォーターマーク画像（プレミアム限定、仕様書08・13）。
/// 設定画面の「ウォーターマーク」カテゴリで複数登録・管理する。
class WatermarkAsset {
  final String id;
  final String name;
  final String fileName; // アプリのwatermarksディレクトリ内のファイル名

  const WatermarkAsset({
    required this.id,
    required this.name,
    required this.fileName,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'fileName': fileName};

  factory WatermarkAsset.fromJson(Map<String, dynamic> json) => WatermarkAsset(
        id: json['id'] as String,
        name: json['name'] as String,
        fileName: json['fileName'] as String,
      );
}
