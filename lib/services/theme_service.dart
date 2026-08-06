import 'package:flutter/material.dart';
import '../models/app_theme_preset.dart';

class ThemeService extends ChangeNotifier {
  final List<AppThemePreset> _presets = [];
  AppThemePreset _current = AppThemePreset.defaultDark;

  List<AppThemePreset> get presets => List.unmodifiable(_presets);
  AppThemePreset get current => _current;

  ThemeData get themeData => _buildTheme(_current);

  /// OSのbrightnessを外部から注入する（BaseTheme.system対応用）
  Brightness systemBrightness = Brightness.dark;

  void updateSystemBrightness(Brightness brightness) {
    if (systemBrightness != brightness) {
      systemBrightness = brightness;
      notifyListeners();
    }
  }

  Future<void> init() async {
    _presets.addAll([
      AppThemePreset.defaultDark,
      AppThemePreset.defaultLight,
      const AppThemePreset(
        id: 'blue',
        name: 'Blue',
        baseTheme: BaseTheme.dark,
        accentColor: Color(0xFF2196F3),
        textColor: Color(0xFFFFFFFF),
        panelBgColor: Color(0xFF0D1B2A),
        menuBgColor: Color(0xFF1B2A3B),
        selectionColor: Color(0xFF2196F3),
        updateMarkColor: Color(0xFFFF9800),
      ),
      const AppThemePreset(
        id: 'green',
        name: 'Green',
        baseTheme: BaseTheme.dark,
        accentColor: Color(0xFF4CAF50),
        textColor: Color(0xFFFFFFFF),
        panelBgColor: Color(0xFF0D1F0D),
        menuBgColor: Color(0xFF1B2E1B),
        selectionColor: Color(0xFF4CAF50),
        updateMarkColor: Color(0xFFFF9800),
      ),
      const AppThemePreset(
        id: 'purple',
        name: 'Purple',
        baseTheme: BaseTheme.dark,
        accentColor: Color(0xFF9C27B0),
        textColor: Color(0xFFFFFFFF),
        panelBgColor: Color(0xFF1A0D1F),
        menuBgColor: Color(0xFF2A1B2E),
        selectionColor: Color(0xFF9C27B0),
        updateMarkColor: Color(0xFFFF9800),
      ),
    ]);
  }

  void applyPreset(String id) {
    final preset = _presets.firstWhere((p) => p.id == id, orElse: () => _current);
    _current = preset;
    notifyListeners();
  }

  void savePreset(AppThemePreset preset) {
    final idx = _presets.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      _presets[idx] = preset;
    } else {
      _presets.add(preset);
    }
    notifyListeners();
  }

  void deletePreset(String id) {
    _presets.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _presets[idx] = _presets[idx].copyWith(isFavorite: !_presets[idx].isFavorite);
      notifyListeners();
    }
  }

  ThemeData _buildTheme(AppThemePreset preset) {
    final brightness = switch (preset.baseTheme) {
      BaseTheme.light => Brightness.light,
      BaseTheme.dark => Brightness.dark,
      // system: OSのbrightnessを参照。updateSystemBrightness()で外部から注入すること
      BaseTheme.system => systemBrightness,
    };
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: preset.accentColor,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: preset.panelBgColor,
      appBarTheme: AppBarTheme(
        backgroundColor: preset.menuBgColor,
        foregroundColor: preset.textColor,
        elevation: 0,
      ),
    );
  }
}
