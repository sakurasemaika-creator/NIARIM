import 'dart:ui';

/// UIテーマプリセットモデル
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

  static const defaultDark = AppThemePreset(
    id: 'default_dark',
    name: 'Default Dark',
    baseTheme: BaseTheme.dark,
    accentColor: Color(0xFF6750A4),
    textColor: Color(0xFFFFFFFF),
    panelBgColor: Color(0xFF1E1E2E),
    menuBgColor: Color(0xFF2A2A3E),
    selectionColor: Color(0xFF6750A4),
    updateMarkColor: Color(0xFFFF9800),
  );

  static const defaultLight = AppThemePreset(
    id: 'default_light',
    name: 'Default Light',
    baseTheme: BaseTheme.light,
    accentColor: Color(0xFF6750A4),
    textColor: Color(0xFF000000),
    panelBgColor: Color(0xFFF5F5F5),
    menuBgColor: Color(0xFFFFFFFF),
    selectionColor: Color(0xFF6750A4),
    updateMarkColor: Color(0xFFFF9800),
  );
}

enum BaseTheme { light, dark, system }
