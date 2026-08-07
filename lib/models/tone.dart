/// トーン（規則パターン描画）モデル
class Tone {
  final String id;
  final String name;
  final String? texturePath; // アセットまたはファイルパス
  final bool isFavorite;
  final String? folderId;

  const Tone({
    required this.id,
    required this.name,
    this.texturePath,
    this.isFavorite = false,
    this.folderId,
  });

  Tone copyWith({
    String? id,
    String? name,
    String? texturePath,
    bool? isFavorite,
    String? folderId,
  }) {
    return Tone(
      id: id ?? this.id,
      name: name ?? this.name,
      texturePath: texturePath ?? this.texturePath,
      isFavorite: isFavorite ?? this.isFavorite,
      folderId: folderId ?? this.folderId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'texturePath': texturePath,
        'isFavorite': isFavorite,
        'folderId': folderId,
      };

  factory Tone.fromJson(Map<String, dynamic> j) => Tone(
        id: j['id'] as String,
        name: j['name'] as String,
        texturePath: j['texturePath'] as String?,
        isFavorite: j['isFavorite'] as bool? ?? false,
        folderId: j['folderId'] as String?,
      );
}
