import 'dart:ui';

/// UIテーマプリセットモデル（仕様書24）
class AppThemePreset {
  final String id;
  final String name;
  final BaseTheme baseTheme;
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
    required this.baseTheme,
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
    BaseTheme? baseTheme,
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
      baseTheme: baseTheme ?? this.baseTheme,
      accentColor: accentColor ?? this.accentColor,
      textColor: textColor ?? this.textColor,
      panelBgColor: panelBgColor ?? this.panelBgColor,
      menuBgColor: menuBgColor ?? this.menuBgColor,
      selectionColor: selectionColor ?? this.selectionColor,
      updateMarkColor: updateMarkColor ?? this.updateMarkColor,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // 既定テーマ：珊瑚ピンクを差し色にしたポップなフラットデザイン
  // （Material標準色をそのまま使わず、暖色寄りの配色でオリジナリティを出す）。
  static const defaultDark = AppThemePreset(
    id: 'default_dark',
    name: 'ポップ（ダーク）',
    baseTheme: BaseTheme.dark,
    accentColor: Color(0xFFFF5C7A),
    textColor: Color(0xFFF5F1F0),
    panelBgColor: Color(0xFF17161C),
    menuBgColor: Color(0xFF201F27),
    selectionColor: Color(0xFFFF5C7A),
    updateMarkColor: Color(0xFFFFB020),
  );

  static const defaultLight = AppThemePreset(
    id: 'default_light',
    name: 'ポップ（ライト）',
    baseTheme: BaseTheme.light,
    accentColor: Color(0xFFFF5C7A),
    textColor: Color(0xFF2B2730),
    panelBgColor: Color(0xFFFAF7F5),
    menuBgColor: Color(0xFFFFFFFF),
    selectionColor: Color(0xFFFF5C7A),
    updateMarkColor: Color(0xFFFFB020),
  );
}

enum BaseTheme { light, dark, system }
