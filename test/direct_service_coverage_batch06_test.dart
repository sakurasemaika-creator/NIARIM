import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'built-ins apply preview commit save favorite reorder delete and persistence work',
    () async {
      final service = ThemeService();
      await service.init();
      expect(service.presets.length, greaterThan(20));
      expect(service.current.id, 'default_light');

      service.applyPreset('default_dark');
      await Future<void>.delayed(Duration.zero);
      expect(service.current.id, 'default_dark');
      expect(service.themeData.brightness, Brightness.dark);

      final preview = service.current.copyWith(
        name: 'Preview Dark',
        accentColor: const Color(0xFF123456),
        textColor: const Color(0xFFF0F0F0),
      );
      service.previewCurrent(preview);
      expect(service.current.name, 'Preview Dark');
      expect(service.current.accentColor, const Color(0xFF123456));
      service.commitCurrent();
      await Future<void>.delayed(Duration.zero);
      expect(
        service.presets.firstWhere((p) => p.id == 'default_dark').name,
        'Preview Dark',
      );

      const custom = AppThemePreset(
        id: 'direct_theme',
        name: 'Direct Theme',
        accentColor: Color(0xFF00AACC),
        textColor: Color(0xFF202020),
        buttonTextColor: Color(0xFFFFFFFF),
        menuTextColor: Color(0xFF202020),
        selectionTextColor: Color(0xFF17161C),
        panelBgColor: Color(0xFFFAFAFA),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFF44BBCC),
        updateMarkColor: Color(0xFFFF9900),
      );
      service.savePreset(custom);
      await Future<void>.delayed(Duration.zero);
      expect(service.presets.any((p) => p.id == custom.id), isTrue);

      service.applyPreset(custom.id);
      await Future<void>.delayed(Duration.zero);
      expect(service.current.id, custom.id);
      final lightTheme = service.themeData;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.colorScheme.primary, custom.accentColor);
      expect(lightTheme.scaffoldBackgroundColor, custom.panelBgColor);
      expect(lightTheme.colorScheme.onSurface, custom.textColor);
      expect(lightTheme.appBarTheme.backgroundColor, custom.menuBgColor);
      expect(lightTheme.listTileTheme.titleTextStyle?.fontFamily, 'Kuramubon');
      expect(lightTheme.textTheme.bodyMedium?.fontFamily, 'HakkouMincho');

      service.toggleFavorite(custom.id);
      await Future<void>.delayed(Duration.zero);
      expect(
        service.presets.firstWhere((p) => p.id == custom.id).isFavorite,
        isTrue,
      );

      final oldIndex = service.presets.indexWhere((p) => p.id == custom.id);
      service.reorder(oldIndex, 0);
      await Future<void>.delayed(Duration.zero);
      expect(service.presets.first.id, custom.id);

      final restored = ThemeService();
      await restored.init();
      expect(restored.current.id, custom.id);
      expect(restored.presets.first.id, custom.id);
      expect(restored.presets.first.isFavorite, isTrue);
      expect(
        restored.presets.firstWhere((p) => p.id == 'default_dark').name,
        'Preview Dark',
      );

      restored.deletePreset(custom.id);
      await Future<void>.delayed(Duration.zero);
      expect(restored.presets.any((p) => p.id == custom.id), isFalse);
    },
  );

  test(
    'saved valid custom preset is merged with missing built-ins and remains selected',
    () async {
      const custom = AppThemePreset(
        id: 'only_custom',
        name: 'Only',
        accentColor: Color(0xFF0000FF),
        textColor: Color(0xFF000080),
        buttonTextColor: Color(0xFFFFFFFF),
        menuTextColor: Color(0xFF000080),
        selectionTextColor: Color(0xFF000000),
        panelBgColor: Color(0xFFFFFFFF),
        menuBgColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFF00FF00),
        updateMarkColor: Color(0xFFFF0000),
      );
      SharedPreferences.setMockInitialValues({
        'theme_presets': [jsonEncode(custom.toJson())],
      });

      final service = ThemeService();
      await service.init();
      expect(service.presets.first.id, 'only_custom');
      expect(
        service.presets.any((p) => p.id == 'default_light'),
        isTrue,
        reason: 'built-in presets are merged into a saved custom list',
      );
      expect(
        service.current.id,
        'only_custom',
        reason: 'the first valid custom theme is selected when no current JSON is stored',
      );

      service.applyPreset('missing-id');
      expect(
        service.current.id,
        'only_custom',
        reason: 'unknown apply id keeps the current preset',
      );
    },
  );
}
