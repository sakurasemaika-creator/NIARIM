import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Historical original (left-hand column) 28-preset theme palette.
/// This is deliberately a fixed snapshot, not a fixture generated at test
/// runtime from ThemeService: changing the built-in palette into the proposed
/// redesigned right-hand column must fail this regression check.
/// Field order: accent, normal text, button text, menu text, selected text,
/// panel background, menu background, selection surface, update mark.
const _originalColors = <String, List<int>>{
  'default_light': [
    0xFFFF5C7A,
    0xFF2B2730,
    0xFFFFFFFF,
    0xFF2B2730,
    0xFFFFFFFF,
    0xFFFAF7F5,
    0xFFFFFFFF,
    0xFFFF5C7A,
    0xFFFFB020,
  ],
  'default_dark': [
    0xFFFF5C7A,
    0xFFF5F1F0,
    0xFFFFFFFF,
    0xFFF5F1F0,
    0xFFFFFFFF,
    0xFF17161C,
    0xFF201F27,
    0xFFFF5C7A,
    0xFFFFB020,
  ],
  'orange_light': [
    0xFFFF8A3D,
    0xFF2E2013,
    0xFF17161C,
    0xFF2E2013,
    0xFF17161C,
    0xFFFFF6EE,
    0xFFFFFFFF,
    0xFFFF8A3D,
    0xFFFFB020,
  ],
  'orange_dark': [
    0xFFFF8A3D,
    0xFFFAF0E6,
    0xFF17161C,
    0xFFFAF0E6,
    0xFF17161C,
    0xFF1F160E,
    0xFF2A1D12,
    0xFFFF8A3D,
    0xFFFFB020,
  ],
  'yellow_light': [
    0xFFF2B90F,
    0xFF2E2A12,
    0xFF17161C,
    0xFF2E2A12,
    0xFF17161C,
    0xFFFFFBEA,
    0xFFFFFFFF,
    0xFFF2B90F,
    0xFFFFB020,
  ],
  'yellow_dark': [
    0xFFF2B90F,
    0xFFFAF6E6,
    0xFF17161C,
    0xFFFAF6E6,
    0xFF17161C,
    0xFF1E1B0C,
    0xFF292410,
    0xFFF2B90F,
    0xFFFFB020,
  ],
  'green_light': [
    0xFF3DDC97,
    0xFF16291F,
    0xFF17161C,
    0xFF16291F,
    0xFF17161C,
    0xFFF1FBF6,
    0xFFFFFFFF,
    0xFF3DDC97,
    0xFFFFB020,
  ],
  'green_dark': [
    0xFF3DDC97,
    0xFFF1FAF5,
    0xFF17161C,
    0xFFF1FAF5,
    0xFF17161C,
    0xFF101A15,
    0xFF17251D,
    0xFF3DDC97,
    0xFFFFB020,
  ],
  'blue_light': [
    0xFF3AA6FF,
    0xFF16232E,
    0xFFFFFFFF,
    0xFF16232E,
    0xFFFFFFFF,
    0xFFF1F7FC,
    0xFFFFFFFF,
    0xFF3AA6FF,
    0xFFFFB020,
  ],
  'blue_dark': [
    0xFF3AA6FF,
    0xFFF2F6FA,
    0xFFFFFFFF,
    0xFFF2F6FA,
    0xFFFFFFFF,
    0xFF11181F,
    0xFF182430,
    0xFF3AA6FF,
    0xFFFFB020,
  ],
  'indigo_light': [
    0xFF5C6BFF,
    0xFF1E2033,
    0xFFFFFFFF,
    0xFF1E2033,
    0xFFFFFFFF,
    0xFFF3F3FC,
    0xFFFFFFFF,
    0xFF5C6BFF,
    0xFFFFB020,
  ],
  'indigo_dark': [
    0xFF5C6BFF,
    0xFFF0F1FA,
    0xFFFFFFFF,
    0xFFF0F1FA,
    0xFFFFFFFF,
    0xFF14151F,
    0xFF1C1E2D,
    0xFF5C6BFF,
    0xFFFFB020,
  ],
  'purple_light': [
    0xFFB15CFF,
    0xFF2B2033,
    0xFFFFFFFF,
    0xFF2B2033,
    0xFFFFFFFF,
    0xFFF8F1FC,
    0xFFFFFFFF,
    0xFFB15CFF,
    0xFFFFB020,
  ],
  'purple_dark': [
    0xFFB15CFF,
    0xFFF6F1FA,
    0xFFFFFFFF,
    0xFFF6F1FA,
    0xFFFFFFFF,
    0xFF19141F,
    0xFF241C2D,
    0xFFB15CFF,
    0xFFFFB020,
  ],
  'pink_light': [
    0xFFFF7EB3,
    0xFF33202A,
    0xFF17161C,
    0xFF33202A,
    0xFF17161C,
    0xFFFFF1F6,
    0xFFFFFFFF,
    0xFFFF7EB3,
    0xFFFFB020,
  ],
  'pink_dark': [
    0xFFFF7EB3,
    0xFFFAEEF3,
    0xFF17161C,
    0xFFFAEEF3,
    0xFF17161C,
    0xFF1F1418,
    0xFF2B1B22,
    0xFFFF7EB3,
    0xFFFFB020,
  ],
  'light_purple_light': [
    0xFFB39DDB,
    0xFF272233,
    0xFF17161C,
    0xFF272233,
    0xFF17161C,
    0xFFF6F2FC,
    0xFFFFFFFF,
    0xFFB39DDB,
    0xFFFFB020,
  ],
  'light_purple_dark': [
    0xFFB39DDB,
    0xFFF2EFF9,
    0xFF17161C,
    0xFFF2EFF9,
    0xFF17161C,
    0xFF19171F,
    0xFF211E2C,
    0xFFB39DDB,
    0xFFFFB020,
  ],
  'light_blue_light': [
    0xFF90CAF9,
    0xFF1D2733,
    0xFF17161C,
    0xFF1D2733,
    0xFF17161C,
    0xFFF0F8FE,
    0xFFFFFFFF,
    0xFF90CAF9,
    0xFFFFB020,
  ],
  'light_blue_dark': [
    0xFF90CAF9,
    0xFFEDF5FB,
    0xFF17161C,
    0xFFEDF5FB,
    0xFF17161C,
    0xFF141A1F,
    0xFF1C2530,
    0xFF90CAF9,
    0xFFFFB020,
  ],
  'emerald_light': [
    0xFF10B981,
    0xFF13291F,
    0xFFFFFFFF,
    0xFF13291F,
    0xFFFFFFFF,
    0xFFECFAF4,
    0xFFFFFFFF,
    0xFF10B981,
    0xFFFFB020,
  ],
  'emerald_dark': [
    0xFF10B981,
    0xFFE9FAF3,
    0xFFFFFFFF,
    0xFFE9FAF3,
    0xFFFFFFFF,
    0xFF0D1815,
    0xFF13221D,
    0xFF10B981,
    0xFFFFB020,
  ],
  'dusty_pink_light': [
    0xFFD8A0A6,
    0xFF2E2325,
    0xFF17161C,
    0xFF2E2325,
    0xFF17161C,
    0xFFFAF2F2,
    0xFFFFFFFF,
    0xFFD8A0A6,
    0xFFFFB020,
  ],
  'dusty_pink_dark': [
    0xFFD8A0A6,
    0xFFF5ECED,
    0xFF17161C,
    0xFFF5ECED,
    0xFF17161C,
    0xFF1C1516,
    0xFF261C1E,
    0xFFD8A0A6,
    0xFFFFB020,
  ],
  'dusty_blue_light': [
    0xFF8DA9C4,
    0xFF212B33,
    0xFF17161C,
    0xFF212B33,
    0xFF17161C,
    0xFFF1F5F9,
    0xFFFFFFFF,
    0xFF8DA9C4,
    0xFFFFB020,
  ],
  'dusty_blue_dark': [
    0xFF8DA9C4,
    0xFFEDF1F5,
    0xFF17161C,
    0xFFEDF1F5,
    0xFF17161C,
    0xFF151A1E,
    0xFF1C232B,
    0xFF8DA9C4,
    0xFFFFB020,
  ],
  'dusty_green_light': [
    0xFF8FB89D,
    0xFF20281F,
    0xFF17161C,
    0xFF20281F,
    0xFF17161C,
    0xFFF2F8F3,
    0xFFFFFFFF,
    0xFF8FB89D,
    0xFFFFB020,
  ],
  'dusty_green_dark': [
    0xFF8FB89D,
    0xFFEEF4EF,
    0xFF17161C,
    0xFFEEF4EF,
    0xFF17161C,
    0xFF151A16,
    0xFF1D251F,
    0xFF8FB89D,
    0xFFFFB020,
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 28 built-in presets retain the original pre-review colors', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.init();
    expect(service.presets.length, 28);
    expect(
      service.presets.map((p) => p.id).toSet(),
      _originalColors.keys.toSet(),
    );
    for (final preset in service.presets) {
      final actual = <int>[
        preset.accentColor.toARGB32(),
        preset.textColor.toARGB32(),
        preset.buttonTextColor.toARGB32(),
        preset.menuTextColor.toARGB32(),
        preset.selectionTextColor.toARGB32(),
        preset.panelBgColor.toARGB32(),
        preset.menuBgColor.toARGB32(),
        preset.selectionColor.toARGB32(),
        preset.updateMarkColor.toARGB32(),
      ];
      expect(
        actual,
        _originalColors[preset.id],
        reason:
            '${preset.id} must use the left-hand original palette, not the revised one',
      );
    }
    // The original palette uses a shared amber update mark; neither the
    // selection foreground nor the normal text color should be silently
    // transformed or derived from the button fill.
    for (final preset in service.presets) {
      expect(preset.updateMarkColor, const Color(0xFFFFB020));
      service.previewCurrent(preset);
      final scheme = service.themeData.colorScheme;
      expect(scheme.primary, preset.accentColor);
      expect(scheme.onPrimary, preset.buttonTextColor);
      expect(scheme.onSurface, preset.textColor);
      expect(
        service.themeData.appBarTheme.foregroundColor,
        preset.menuTextColor,
      );
    }
  });
}
