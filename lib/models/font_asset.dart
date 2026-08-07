/// ユーザー追加フォント（仕様書15・21：フォント管理）。
/// アプリ全体のFonts/フォルダで管理し、プロジェクトとは独立する。
class FontAsset {
  final String id;
  final String displayName;
  final String fileName; // 実ファイル名（拡張子込み。Fonts/フォルダ内）
  final int sizeBytes;
  final DateTime addedAt;

  const FontAsset({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.sizeBytes,
    required this.addedAt,
  });

  String get extension => fileName.split('.').last.toUpperCase();

  FontAsset copyWith({String? displayName}) => FontAsset(
        id: id,
        displayName: displayName ?? this.displayName,
        fileName: fileName,
        sizeBytes: sizeBytes,
        addedAt: addedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
      };

  factory FontAsset.fromJson(Map<String, dynamic> j) => FontAsset(
        id: j['id'] as String,
        displayName: j['displayName'] as String,
        fileName: j['fileName'] as String,
        sizeBytes: j['sizeBytes'] as int,
        addedAt: DateTime.parse(j['addedAt'] as String),
      );
}
