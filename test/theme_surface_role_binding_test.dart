import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'selection surfaces follow selection color independently of accent',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.init();
      addTearDown(service.dispose);
      final base = AppThemePreset.defaultLight.copyWith(
        accentColor: const Color(0xFF9C4AB5),
        selectionColor: const Color(0xFFD65F31),
      );
      service.previewCurrent(base);
      final initial = service.themeData.colorScheme;
      service.previewCurrent(
        base.copyWith(accentColor: const Color(0xFF226B91)),
      );
      expect(
        service.themeData.colorScheme.secondaryContainer,
        initial.secondaryContainer,
        reason: 'Changing accent must not recolor a selection surface',
      );
      service.previewCurrent(
        base.copyWith(selectionColor: const Color(0xFF347953)),
      );
      final changed = service.themeData.colorScheme;
      expect(changed.secondaryContainer, isNot(initial.secondaryContainer));
      expect(changed.primaryContainer, initial.primaryContainer);
      expect(changed.onSecondaryContainer, base.textColor);
    },
  );

  test('tooltip follows the explicit menu background and foreground', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    addTearDown(service.dispose);
    final preset = AppThemePreset.defaultLight.copyWith(
      textColor: const Color(0xFF16593A),
      menuBgColor: const Color(0xFFFFE5B7),
      menuTextColor: const Color(0xFF17325A),
    );
    service.previewCurrent(preset);
    expect(
      (service.themeData.tooltipTheme.decoration! as BoxDecoration).color,
      preset.menuBgColor,
    );
    expect(
      service.themeData.tooltipTheme.textStyle!.color,
      preset.menuTextColor,
    );
    expect(service.current.toJson(), preset.toJson());
  });
}
