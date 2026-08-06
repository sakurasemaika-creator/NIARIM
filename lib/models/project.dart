// キャンバス背景表示設定（仕様書27）
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
  final bool isFavorite;
  final String? thumbnailPath;
  final int sizeBytes;
  // 書き出しサイズ（仕様書26）
  final int exportWidth;
  final int exportHeight;
  // 描画領域設定（仕様書26）
  // drawingAreaScale == 1.0 の場合は描画領域 = 書き出し領域（OFF相当）
  final double drawingAreaScale;

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
    this.isFavorite = false,
    this.thumbnailPath,
    this.sizeBytes = 0,
    this.exportWidth = 1920,
    this.exportHeight = 1080,
    this.drawingAreaScale = 1.0,
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
    bool? isFavorite,
    Object? thumbnailPath = _projectSentinel,
    int? sizeBytes,
    int? exportWidth,
    int? exportHeight,
    double? drawingAreaScale,
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
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailPath: thumbnailPath == _projectSentinel ? this.thumbnailPath : thumbnailPath as String?,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      exportWidth: exportWidth ?? this.exportWidth,
      exportHeight: exportHeight ?? this.exportHeight,
      drawingAreaScale: drawingAreaScale ?? this.drawingAreaScale,
    );
  }

  int get totalFrames => fps * durationSeconds;
}
