/// ユーザー追加フォント。
/// アプリ全体のFonts/フォルダで管理し、プロジェクトとは独立する。
class FontAsset {
  final String id;
  final String displayName;
  final String fileName; // 実ファイル名（拡張子込み。Fonts/フォルダ内）
  final int sizeBytes;
  final DateTime addedAt;
  final bool isFavorite;
  final String? licenseNotice;
  // ピクセルモード：ONの場合、このフォントで
  // ラスタライズするテキストはアンチエイリアスを行わず、輪郭をくっきり
  // 二値化する（ドットフォント・ビットマップ由来フォントをにじませずに
  // 表示するための設定）。ブラシのdotPenModeと同じ考え方だが、こちらは
  // ストロークごとではなくフォント単位の固定プロパティとして持つ
  // （フォント一覧画面でON/OFFし、以後そのフォントを使う全テキストへ
  // 自動的に適用される）。
  final bool pixelMode;

  const FontAsset({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.sizeBytes,
    required this.addedAt,
    this.isFavorite = false,
    this.pixelMode = false,
    this.licenseNotice,
  });

  String get extension => fileName.split('.').last.toUpperCase();

  FontAsset copyWith({
    String? displayName,
    bool? isFavorite,
    bool? pixelMode,
    String? licenseNotice,
  }) => FontAsset(
    id: id,
    displayName: displayName ?? this.displayName,
    fileName: fileName,
    sizeBytes: sizeBytes,
    addedAt: addedAt,
    isFavorite: isFavorite ?? this.isFavorite,
    pixelMode: pixelMode ?? this.pixelMode,
    licenseNotice: licenseNotice ?? this.licenseNotice,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'fileName': fileName,
    'sizeBytes': sizeBytes,
    'addedAt': addedAt.toIso8601String(),
    'isFavorite': isFavorite,
    'pixelMode': pixelMode,
    if (licenseNotice != null) 'licenseNotice': licenseNotice,
  };

  factory FontAsset.fromJson(Map<String, dynamic> j) => FontAsset(
    id: j['id'] as String,
    displayName: j['displayName'] as String,
    fileName: j['fileName'] as String,
    sizeBytes: j['sizeBytes'] as int,
    addedAt: DateTime.parse(j['addedAt'] as String),
    isFavorite: j['isFavorite'] as bool? ?? false,
    pixelMode: j['pixelMode'] as bool? ?? false,
    licenseNotice: j['licenseNotice'] is String
        ? j['licenseNotice'] as String
        : null,
  );
}
