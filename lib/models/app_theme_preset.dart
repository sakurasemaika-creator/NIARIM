import 'dart:ui';

/// UIテーマプリセットモデル。
///
/// 明暗（Brightness）はプリセット自身の背景色（panelBgColor）の明るさから
/// 自動的に、かつ常に矛盾なく決まる（`ThemeService._buildTheme()`参照）。
class AppThemePreset {
  final String id;
  final String name;
  final Color accentColor;
  final Color textColor;
  final Color panelBgColor;
  final Color menuBgColor;
  final Color selectionColor;
  final Color updateMarkColor;
  final bool isFavorite;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.accentColor,
    required this.textColor,
    required this.panelBgColor,
    required this.menuBgColor,
    required this.selectionColor,
    required this.updateMarkColor,
    this.isFavorite = false,
  });

  AppThemePreset copyWith({
    String? id,
    String? name,
    Color? accentColor,
    Color? textColor,
    Color? panelBgColor,
    Color? menuBgColor,
    Color? selectionColor,
    Color? updateMarkColor,
    bool? isFavorite,
  }) {
    return AppThemePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      accentColor: accentColor ?? this.accentColor,
      textColor: textColor ?? this.textColor,
      panelBgColor: panelBgColor ?? this.panelBgColor,
      menuBgColor: menuBgColor ?? this.menuBgColor,
      selectionColor: selectionColor ?? this.selectionColor,
      updateMarkColor: updateMarkColor ?? this.updateMarkColor,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // 既定テーマ：珊瑚ピンク（虹7色の「赤」に相当）を差し色にしたポップな
  // フラットデザイン（Material標準色をそのまま使わず、暖色寄りの配色で
  // オリジナリティを出す）。defaultDarkは「常にダーク」を選びたい場合の
  // 独立した選択肢として残す。
  static const defaultDark = AppThemePreset(
    id: 'default_dark',
    // 何色を指すか伝わる名前にするため、実際の差し色（珊瑚ピンク・虹7色で
    // いう「赤」）が分かる名前にしている。
    name: 'レッド（ダーク）',
    accentColor: Color(0xFFFF5C7A),
    textColor: Color(0xFFF5F1F0),
    panelBgColor: Color(0xFF17161C),
    menuBgColor: Color(0xFF201F27),
    selectionColor: Color(0xFFFF5C7A),
    updateMarkColor: Color(0xFFFFB020),
  );

  static const defaultLight = AppThemePreset(
    id: 'default_light',
    name: 'レッド（ライト）',
    accentColor: Color(0xFFFF5C7A),
    textColor: Color(0xFF2B2730),
    panelBgColor: Color(0xFFFAF7F5),
    menuBgColor: Color(0xFFFFFFFF),
    selectionColor: Color(0xFFFF5C7A),
    updateMarkColor: Color(0xFFFFB020),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'accentColor': accentColor.toARGB32(),
    'textColor': textColor.toARGB32(),
    'panelBgColor': panelBgColor.toARGB32(),
    'menuBgColor': menuBgColor.toARGB32(),
    'selectionColor': selectionColor.toARGB32(),
    'updateMarkColor': updateMarkColor.toARGB32(),
    'isFavorite': isFavorite,
  };

  factory AppThemePreset.fromJson(Map<String, dynamic> json) => AppThemePreset(
    id: json['id'] as String,
    name: json['name'] as String,
    // 'baseTheme'キーは廃止済みだが、旧バージョンで保存されたデータ
    // （プリセット・.niatra引き継ぎファイル等）に含まれている場合が
    // あるため、存在しても単に無視する（読み込みエラーにしない）。
    accentColor: Color(json['accentColor'] as int),
    textColor: Color(json['textColor'] as int),
    panelBgColor: Color(json['panelBgColor'] as int),
    menuBgColor: Color(json['menuBgColor'] as int),
    selectionColor: Color(json['selectionColor'] as int),
    updateMarkColor: Color(json['updateMarkColor'] as int),
    isFavorite: json['isFavorite'] as bool? ?? false,
  );
}
