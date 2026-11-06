class MaterialAsset {
  final String id;
  final String originalFileName;
  final MaterialType type;
  final int sizeBytes;
  final DateTime addedAt;
  final int? width;
  final int? height;
  final Duration? duration;

  const MaterialAsset({
    required this.id,
    required this.originalFileName,
    required this.type,
    required this.sizeBytes,
    required this.addedAt,
    this.width,
    this.height,
    this.duration,
  });

  String get extension => originalFileName.split('.').last.toLowerCase();
  String get storageName => '$id.$extension';
}

enum MaterialType { image, audio, video }
