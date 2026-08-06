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
}
