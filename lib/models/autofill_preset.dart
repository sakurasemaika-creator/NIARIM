class AutofillPreset {
  final String id;
  final String name;
  final String? thumbnailPath;
  final List<AutofillPart> parts;
  final bool isFavorite;

  const AutofillPreset({
    required this.id,
    required this.name,
    this.thumbnailPath,
    this.parts = const [],
    this.isFavorite = false,
  });

  AutofillPreset copyWith({
    String? id,
    String? name,
    String? thumbnailPath,
    List<AutofillPart>? parts,
    bool? isFavorite,
  }) {
    return AutofillPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      parts: parts ?? this.parts,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class AutofillPart {
  final String id;
  final String name;
  // ARGB int値（例: 0xFFFF0000 = 赤）
  final int color;

  const AutofillPart({
    required this.id,
    required this.name,
    required this.color,
  });
}
