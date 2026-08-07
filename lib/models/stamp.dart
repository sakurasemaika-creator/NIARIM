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

  const Stamp({
    required this.id,
    required this.name,
    this.imagePath,
    this.isFavorite = false,
    this.folderId,
    this.rotation = false,
    this.density = 1.0,
    this.scatter = 0.0,
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
      );
}
