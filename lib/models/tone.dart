import 'asset_tags.dart';

/// トーン（規則パターン描画）モデル
class Tone {
  final String id;
  final String name;
  /// Original procedural pattern key; allows safe user renaming of a copy.
  final String? patternName;
  final String? texturePath; // アセットまたはファイルパス
  final bool isFavorite;
  final String? folderId;
  // 分類用の自由入力タグ。お気に入り・フォルダとは別軸で、1つの素材へ
  // 複数の観点（用途・雰囲気・案件名など）を付けて絞り込めるようにする。
  // 一覧画面の検索欄は「キーワード検索」と「タグ検索」を切り替えられる。
  final List<String> tags;

  const Tone({
    required this.id,
    required this.name,
    this.patternName,
    this.texturePath,
    this.isFavorite = false,
    this.folderId,
    this.tags = const [],
  });

  Tone copyWith({
    String? id,
    String? name,
    String? patternName,
    String? texturePath,
    bool? isFavorite,
    String? folderId,
    List<String>? tags,
  }) {
    return Tone(
      id: id ?? this.id,
      name: name ?? this.name,
      patternName: patternName ?? this.patternName,
      texturePath: texturePath ?? this.texturePath,
      isFavorite: isFavorite ?? this.isFavorite,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'patternName': patternName,
    'texturePath': texturePath,
    'isFavorite': isFavorite,
    'folderId': folderId,
    'tags': tags,
  };

  factory Tone.fromJson(Map<String, dynamic> j) => Tone(
    id: j['id'] as String,
    name: j['name'] as String,
    patternName: j['patternName'] as String?,
    texturePath: j['texturePath'] as String?,
    isFavorite: j['isFavorite'] as bool? ?? false,
    folderId: j['folderId'] as String?,
    tags: parseTags(j['tags']),
  );
}
