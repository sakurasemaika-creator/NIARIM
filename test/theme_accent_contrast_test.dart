import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectReadable(ThemeService service) {
    final scheme = service.themeData.colorScheme;
    for (final pair in [
      (scheme.primary, scheme.onPrimary),
      (scheme.secondary, scheme.onSecondary),
    ]) {
      expect(pair.$1.a, 1);
      expect(pair.$2.a, 1);
      expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    }
  }

  test(
    'all built-in accents retain readable foregrounds on actual colors',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.presets.length, 28);
      for (final preset in service.presets) {
        service.applyPreset(preset.id);
        expectReadable(service);
        expect(service.current.toJson(), preset.toJson());
      }
    },
  );

  test(
    'transparent and opposite accents compose without changing saved colors',
    () async {
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
        expectReadable(service);
        expect(service.current.toJson(), preset.toJson());
        final preferences = await SharedPreferences.getInstance();
        expect(
          jsonDecode(preferences.getString('theme_current_json')!),
          preset.toJson(),
        );
        service.dispose();
      }
    },
  );
}
