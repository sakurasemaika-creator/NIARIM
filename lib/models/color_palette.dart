/// ユーザーが任意の色を登録できるパレット。
/// 複数パレットを作成・切替でき、色の追加・削除・並び替えができる。
class ColorPalette {
  final String id;
  final String name;
  final List<int> colors; // ARGB int値のリスト（並び順を保持）
  final bool isFavorite;

  const ColorPalette({
    required this.id,
    required this.name,
    this.colors = const [],
    this.isFavorite = false,
  });

  ColorPalette copyWith({
    String? name,
    List<int>? colors,
    bool? isFavorite,
  }) =>
      ColorPalette(
        id: id,
        name: name ?? this.name,
        colors: colors ?? this.colors,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colors': colors,
        'isFavorite': isFavorite,
      };

  factory ColorPalette.fromJson(Map<String, dynamic> json) => ColorPalette(
        id: json['id'] as String,
        name: json['name'] as String,
        colors: (json['colors'] as List<dynamic>? ?? const [])
            .map((e) => e as int)
            .toList(),
        isFavorite: json['isFavorite'] as bool? ?? false,
      );
}
