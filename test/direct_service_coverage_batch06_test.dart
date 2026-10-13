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
    'saved subset is merged with missing built-ins and invalid current id falls back',
    () async {
      SharedPreferences.setMockInitialValues({
        'theme_presets': [
          '{"id":"only_custom","name":"Only","accentColor":4278190335,'
              '"textColor":4278190080,"panelBgColor":4294967295,'
              '"menuBgColor":4294967295,"selectionColor":4278255360,'
              '"updateMarkColor":4294901760,"isFavorite":false}',
        ],
        'theme_current_id': 'does-not-exist',
      });

      final service = ThemeService();
      await service.init();
      expect(service.presets.first.id, 'only_custom');
      expect(
        service.presets.any((p) => p.id == 'default_light'),
        isTrue,
        reason: 'new/missing built-ins are merged into old saved lists',
      );
      expect(
        service.current.id,
        'only_custom',
        reason: 'unknown saved current id falls back to first saved preset',
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
