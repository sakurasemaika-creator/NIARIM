import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme_preset.dart';

class ThemeService extends ChangeNotifier {
  static const _prefsPresetsKey = 'theme_presets';
  static const _prefsCurrentIdKey = 'theme_current_id';

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

  static const List<AppThemePreset> _builtInPresets = [
    AppThemePreset.defaultDark,
    AppThemePreset.defaultLight,
    AppThemePreset(
      id: 'sky',
      name: 'スカイ',
      baseTheme: BaseTheme.dark,
      accentColor: Color(0xFF3AA6FF),
      textColor: Color(0xFFF2F6FA),
      panelBgColor: Color(0xFF11181F),
      menuBgColor: Color(0xFF182430),
      selectionColor: Color(0xFF3AA6FF),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'mint',
      name: 'ミント',
      baseTheme: BaseTheme.dark,
      accentColor: Color(0xFF3DDC97),
      textColor: Color(0xFFF1FAF5),
      panelBgColor: Color(0xFF101A15),
      menuBgColor: Color(0xFF17251D),
      selectionColor: Color(0xFF3DDC97),
      updateMarkColor: Color(0xFFFFB020),
    ),
    AppThemePreset(
      id: 'orchid',
      name: 'オーキッド',
      baseTheme: BaseTheme.dark,
      accentColor: Color(0xFFB15CFF),
      textColor: Color(0xFFF6F1FA),
      panelBgColor: Color(0xFF19141F),
      menuBgColor: Color(0xFF241C2D),
      selectionColor: Color(0xFFB15CFF),
      updateMarkColor: Color(0xFFFFB020),
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsPresetsKey);
    if (raw == null || raw.isEmpty) {
      _presets.addAll(_builtInPresets);
    } else {
      _presets.addAll(raw.map((s) => AppThemePreset.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    final currentId = prefs.getString(_prefsCurrentIdKey);
    if (currentId != null) {
      _current = _presets.firstWhere((p) => p.id == currentId, orElse: () => _presets.first);
    } else if (_presets.isNotEmpty) {
      _current = _presets.first;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsPresetsKey, _presets.map((p) => jsonEncode(p.toJson())).toList());
    await prefs.setString(_prefsCurrentIdKey, _current.id);
  }

  void applyPreset(String id) {
    final preset = _presets.firstWhere((p) => p.id == id, orElse: () => _current);
    _current = preset;
    notifyListeners();
    _persist();
  }

  void savePreset(AppThemePreset preset) {
    final idx = _presets.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      _presets[idx] = preset;
    } else {
      _presets.add(preset);
    }
    if (_current.id == preset.id) _current = preset;
    notifyListeners();
    _persist();
  }

  void deletePreset(String id) {
    _presets.removeWhere((p) => p.id == id);
    notifyListeners();
    _persist();
  }

  /// テーマプリセットの並び替え（仕様書24：「並び替え | ドラッグで順序変更」）。
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _presets.removeAt(oldIndex);
    _presets.insert(newIndex, item);
    notifyListeners();
    _persist();
  }

  void toggleFavorite(String id) {
    final idx = _presets.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _presets[idx] = _presets[idx].copyWith(isFavorite: !_presets[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  /// ポップなフラットデザインのThemeDataを構築する（仕様書24）。
  /// Material標準の角丸・階調をそのまま使わず、フラット・大きめタップ領域・
  /// 丸みの強い形状で統一し、スマホでの誤タップを減らす。
  ThemeData _buildTheme(AppThemePreset preset) {
    final brightness = switch (preset.baseTheme) {
      BaseTheme.light => Brightness.light,
      BaseTheme.dark => Brightness.dark,
      // system: OSのbrightnessを参照。updateSystemBrightness()で外部から注入すること
      BaseTheme.system => systemBrightness,
    };
    final scheme = ColorScheme.fromSeed(
      seedColor: preset.accentColor,
      brightness: brightness,
    ).copyWith(primary: preset.accentColor, secondary: preset.selectionColor);
    // 角丸を大きめにし、Google Material標準の角丸14pxよりも柔らかい印象にする
    // （LINE・メルカリ等、日本の人気アプリに共通するポップで丸みの強い形状）。
    const radius = 18.0;
    const minTapSize = Size(48, 48);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: preset.panelBgColor,
      // InkSparkle（Material Youの光るリップル）は「いかにも最新Android技術デモ」
      // 感が強く、GPU負荷も高いため、低スペック端末を考慮しつつ落ち着いた
      // タップフィードバックのInkRippleへ変更する。
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: preset.menuBgColor,
        foregroundColor: preset.textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: preset.textColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: preset.menuBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minTapSize),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: preset.menuBgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: preset.menuBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: preset.menuBgColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: preset.menuBgColor,
        contentTextStyle: TextStyle(color: preset.textColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: preset.menuBgColor,
        // 完全な丸み（ピル型）：日本のアプリでよく使われる柔らかいタグ・
        // フィルターチップの形状。
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? scheme.primary.withValues(alpha: 0.5) : null,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        // 完全な円形：角丸四角より親しみやすく、LINE等の日本製アプリで
        // 定番のFAB形状。
        shape: const CircleBorder(),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: preset.textColor.withValues(alpha: 0.6),
      ),
      dividerTheme: DividerThemeData(color: preset.textColor.withValues(alpha: 0.08)),
    );
  }
}
