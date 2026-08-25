// キャンバス背景表示設定
// 書き出し結果には影響しない・キャンバス表示のみ
enum CanvasBackground {
  white,        // 白背景
  transparent,  // 透過（グレー・白の市松模様）
}

const Object _projectSentinel = Object();

class Project {
  final String id;
  final String name;
  final int fps;
  final int durationSeconds;
  final int backgroundColor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalWorkSeconds;
  final String? folderId;
  // 共有タブ内でのフォルダ整理用（プロジェクト一覧タブの folderId とは
  // 独立した、共有タブ専用のフォルダ階層。仕様：ホーム画面「共有」タブへの
  // フォルダ新規追加機能）。
  final String? sharedFolderId;
  // .niashareの受信・インポートで追加されたプロジェクトかどうか。
  // ホーム画面「共有」タブ（プロジェクト一覧タブとは別枠の一覧）の
  // 絞り込み条件として使う。
  final bool isSharedImport;
  final bool isFavorite;
  final String? thumbnailPath;
  final int sizeBytes;
  // タグ（詳細情報画面のタグ機能）
  final List<String> tags;
  // 書き出しサイズ
  final int exportWidth;
  final int exportHeight;
  // 描画領域設定
  // drawingAreaScale == 1.0 の場合は描画領域 = 書き出し領域（OFF相当）
  final double drawingAreaScale;
  // このプロジェクトで使用する自動塗りプリセットのID一覧。自動塗り
  // プリセットは増えていくため、プロジェクトごとに使うものだけを選んで
  // パーツ割り当てダイアログで大量スクロールしなくて済むようにするための
  // 項目。nullの場合は「すべてのプリセットを使用する」という従来通りの
  // 挙動（既存プロジェクトとの後方互換のためのデフォルト）。
  final List<String>? enabledAutofillPresetIds;

  const Project({
    required this.id,
    required this.name,
    required this.fps,
    required this.durationSeconds,
    required this.backgroundColor,
    required this.createdAt,
    required this.updatedAt,
    required this.totalWorkSeconds,
    this.folderId,
    this.sharedFolderId,
    this.isSharedImport = false,
    this.isFavorite = false,
    this.thumbnailPath,
    this.sizeBytes = 0,
    this.tags = const [],
    this.exportWidth = 1920,
    this.exportHeight = 1080,
    this.drawingAreaScale = 1.0,
    this.enabledAutofillPresetIds,
  });

  // 描画領域サイズ（書き出しサイズ × 倍率）
  int get drawingWidth => (exportWidth * drawingAreaScale).round();
  int get drawingHeight => (exportHeight * drawingAreaScale).round();

  // 描画領域が書き出し領域より広いか（赤枠表示判定用）
  bool get hasExtendedDrawingArea => drawingAreaScale > 1.0;

  Project copyWith({
    String? id,
    String? name,
    int? fps,
    int? durationSeconds,
    int? backgroundColor,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalWorkSeconds,
    Object? folderId = _projectSentinel,
    Object? sharedFolderId = _projectSentinel,
    bool? isSharedImport,
    bool? isFavorite,
    Object? thumbnailPath = _projectSentinel,
    int? sizeBytes,
    List<String>? tags,
    int? exportWidth,
    int? exportHeight,
    double? drawingAreaScale,
    Object? enabledAutofillPresetIds = _projectSentinel,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      fps: fps ?? this.fps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalWorkSeconds: totalWorkSeconds ?? this.totalWorkSeconds,
      folderId: folderId == _projectSentinel ? this.folderId : folderId as String?,
      sharedFolderId: sharedFolderId == _projectSentinel ? this.sharedFolderId : sharedFolderId as String?,
      isSharedImport: isSharedImport ?? this.isSharedImport,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailPath: thumbnailPath == _projectSentinel ? this.thumbnailPath : thumbnailPath as String?,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      tags: tags ?? this.tags,
      exportWidth: exportWidth ?? this.exportWidth,
      exportHeight: exportHeight ?? this.exportHeight,
      drawingAreaScale: drawingAreaScale ?? this.drawingAreaScale,
      enabledAutofillPresetIds: enabledAutofillPresetIds == _projectSentinel
          ? this.enabledAutofillPresetIds
          : enabledAutofillPresetIds as List<String>?,
    );
  }

  int get totalFrames => fps * durationSeconds;
}
