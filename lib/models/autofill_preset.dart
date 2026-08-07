import 'autofill_gradient.dart';

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
  // ARGB int値（例: 0xFFFF0000 = 赤）。gradientが設定されている場合は
  // グラデーションが優先され、colorは使用されない（仕様書20：塗り色設定）。
  final int color;
  final AutofillGradient? gradient;

  const AutofillPart({
    required this.id,
    required this.name,
    required this.color,
    this.gradient,
  });

  AutofillPart copyWith({
    String? id,
    String? name,
    int? color,
    Object? gradient = _sentinel,
  }) {
    return AutofillPart(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      gradient: identical(gradient, _sentinel) ? this.gradient : gradient as AutofillGradient?,
    );
  }
}

const Object _sentinel = Object();
