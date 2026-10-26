import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/utils/color_contrast.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectExactForegrounds(ThemeService service) {
    final preset = service.current;
    final scheme = service.themeData.colorScheme;
    expect(scheme.onPrimary, preset.buttonTextColor);
    expect(scheme.onSecondary, preset.selectionTextColor);
    expect(scheme.onPrimaryContainer, preset.textColor);
    expect(scheme.onSecondaryContainer, preset.textColor);
    expect(
      service.themeData.listTileTheme.selectedColor,
      preset.selectionTextColor,
    );
    expect(scheme.onSurface, preset.textColor);
    expect(service.themeData.appBarTheme.foregroundColor, preset.menuTextColor);
  }

  test(
    'all built-in themes use their expressly chosen foreground colors',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.presets.length, 28);
      for (final preset in service.presets) {
        service.applyPreset(preset.id);
        expectExactForegrounds(service);
        expect(service.current.toJson(), preset.toJson());
      }
    },
  );

  test('extreme accents never overwrite chosen text and icon colors', () async {
    for (final preset in [
      AppThemePreset.defaultLight.copyWith(
        accentColor: const Color(0x20777777),
        selectionColor: const Color(0x80FFFFFF),
      ),
      AppThemePreset.defaultDark.copyWith(
        accentColor: Colors.white,
        selectionColor: Colors.black,
      ),
    ]) {
      SharedPreferences.setMockInitialValues({
        'theme_current_json': jsonEncode(preset.toJson()),
      });
      final service = ThemeService();
      await service.init();
      expectExactForegrounds(service);
      expect(service.current.toJson(), preset.toJson());
      final preferences = await SharedPreferences.getInstance();
      expect(
        jsonDecode(preferences.getString('theme_current_json')!),
        preset.toJson(),
      );
      service.dispose();
    }
  });

  test(
    'semantic error foreground stays readable on customized surfaces',
    () async {
      for (final background in [
        const Color(0xFFAA2B35), // red surface hides default Material error
        const Color(0xFFFFE47A), // pale yellow theme
        const Color(0xFF17161C), // dark theme
      ]) {
        final preset = AppThemePreset.defaultLight.copyWith(
          accentColor: const Color(0xFFFFE47A),
          panelBgColor: background,
          menuBgColor: background,
          textColor: Colors.white,
        );
        SharedPreferences.setMockInitialValues({
          'theme_current_json': jsonEncode(preset.toJson()),
        });
        final service = ThemeService();
        await service.init();
        final scheme = service.themeData.colorScheme;
        expect(
          contrastRatio(scheme.error, background),
          greaterThanOrEqualTo(4.5),
          reason: 'Error text must remain legible on the actual theme panel',
        );
        expect(
          scheme.primary,
          preset.accentColor,
          reason: 'Do not rewrite the selected accent to fix errors',
        );
        expect(
          service.current.toJson(),
          preset.toJson(),
          reason: 'Contrast protection must not change saved user colors',
        );
        service.dispose();
      }
    },
  );
}
