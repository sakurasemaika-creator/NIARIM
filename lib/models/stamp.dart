/// スタンプモデル。色情報をスタンプ画像自体が保持する。
class Stamp {
  final String id;
  final String name;
  final String? imagePath;
  final bool isFavorite;
  final String? folderId;
  final bool rotation;
  final double density;
  final double scatter;
  // スタンプ全体の不透明度（1〜100%）。画像自身のalphaへ乗算して描画する。
  // 旧データにはこのキーが存在しないため、fromJsonでは100を既定値にする。
  final int opacity;
  // ピクセルモード：ONの場合、このスタンプの
  // テクスチャをドット絵風（モザイク低解像度化＋色数削減）に加工してから
  // 描画する（procedural_texture.dartのgenerateBuiltInStampTexture参照）。
  final bool pixelMode;

  const Stamp({
    required this.id,
    required this.name,
    this.imagePath,
    this.isFavorite = false,
    this.folderId,
    this.rotation = false,
    this.density = 1.0,
    this.scatter = 0.0,
    this.opacity = 100,
    this.pixelMode = false,
  });

  Stamp copyWith({
    String? id,
    String? name,
    String? imagePath,
    bool? isFavorite,
    String? folderId,
    bool? rotation,
    double? density,
    double? scatter,
    int? opacity,
    bool? pixelMode,
  }) {
    return Stamp(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      isFavorite: isFavorite ?? this.isFavorite,
      folderId: folderId ?? this.folderId,
      rotation: rotation ?? this.rotation,
      density: density ?? this.density,
      scatter: scatter ?? this.scatter,
      opacity: opacity ?? this.opacity,
      pixelMode: pixelMode ?? this.pixelMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'isFavorite': isFavorite,
        'folderId': folderId,
        'rotation': rotation,
        'density': density,
        'scatter': scatter,
        'opacity': opacity,
        'pixelMode': pixelMode,
      };

  factory Stamp.fromJson(Map<String, dynamic> j) => Stamp(
        id: j['id'] as String,
        name: j['name'] as String,
        imagePath: j['imagePath'] as String?,
        isFavorite: j['isFavorite'] as bool? ?? false,
        folderId: j['folderId'] as String?,
        rotation: j['rotation'] as bool? ?? false,
        density: (j['density'] as num?)?.toDouble() ?? 1.0,
        scatter: (j['scatter'] as num?)?.toDouble() ?? 0.0,
        opacity: (j['opacity'] as num?)?.round().clamp(1, 100) ?? 100,
        pixelMode: j['pixelMode'] as bool? ?? false,
      );
}
