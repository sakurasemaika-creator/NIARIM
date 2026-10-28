import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 28 stock palettes retain the original left-column colors', () async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    addTearDown(theme.dispose);
    await theme.init();

    expect(theme.presets, hasLength(28));
    expect(theme.presets.map((p) => p.id).toSet(), hasLength(28));
    for (final preset in theme.presets) {
      expect(preset.selectionColor, preset.accentColor,
          reason: '${preset.id}: original selection is the accent');
      expect(preset.menuTextColor, preset.textColor,
          reason: '${preset.id}: original menu text is the body text color');
      expect(preset.updateMarkColor, const Color(0xFFFFB020),
          reason: '${preset.id}: original update mark is amber');
    }

    final palettes = {for (final p in theme.presets) p.id: p};
    expect(palettes['default_light']!.accentColor, const Color(0xFFFF5C7A));
    expect(palettes['default_dark']!.buttonTextColor, Colors.white);
    expect(palettes['orange_light']!.accentColor, const Color(0xFFFF8A3D));
    expect(palettes['orange_light']!.buttonTextColor,
        const Color(0xFF17161C));
    expect(palettes['yellow_light']!.accentColor, const Color(0xFFF2B90F));
    expect(palettes['blue_dark']!.buttonTextColor, Colors.white);
    expect(palettes['green_dark']!.panelBgColor, const Color(0xFF101A15));
  });

  test('restore once replaces stored built-in revision but preserves custom',
      () async {
    const customId = 'personal_warm_theme';
    const purple = Color(0xFF6C2BAB);
    final proposedPink = AppThemePreset.defaultLight.copyWith(
      accentColor: const Color(0xFFBB2255),
      buttonTextColor: Colors.black,
      selectionColor: const Color(0xFFDDCCDD),
      updateMarkColor: const Color(0xFF00CCCC),
      isFavorite: true,
    );
    final originalOrange = AppThemePreset.defaultLight.copyWith(
      id: 'orange_dark',
      name: 'オレンジ（ダーク）',
      accentColor: const Color(0xFFDD7744),
      updateMarkColor: const Color(0xFF00CCCC),
    );
    final custom = AppThemePreset.defaultLight.copyWith(
      id: customId,
      accentColor: purple,
      menuTextColor: const Color(0xFFAA22BB),
      buttonTextColor: const Color(0xFF22FFAA),
    );
    final adoptedCurrent = custom.copyWith(id: ThemeService.customCurrentId);

    SharedPreferences.setMockInitialValues({
      'theme_presets': [
        jsonEncode(proposedPink.toJson()),
        jsonEncode(custom.toJson()),
        jsonEncode(originalOrange.toJson()),
      ],
      'theme_current_json': jsonEncode(adoptedCurrent.toJson()),
    });
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    final palettes = {for (final p in theme.presets) p.id: p};
    expect(theme.presets.map((p) => p.id).take(3),
        ['default_light', customId, 'orange_dark'],
        reason: 'Rollback cannot reorder a saved theme list');
    expect(theme.presets, hasLength(28 + 1));
    expect(palettes['default_light']!.accentColor, const Color(0xFFFF5C7A));
    expect(palettes['default_light']!.updateMarkColor,
        const Color(0xFFFFB020));
    expect(palettes['default_light']!.isFavorite, isTrue);
    expect(palettes['orange_dark']!.accentColor, const Color(0xFFFF8A3D));
    expect(palettes[customId]!.toJson(), custom.toJson());
    expect(theme.current.toJson(), adoptedCurrent.toJson(),
        reason: 'A customized current theme is not a built-in palette');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('theme_original_builtin_palette_restored_v1'), isTrue);
    final restarted = ThemeService();
    await restarted.init();
    addTearDown(restarted.dispose);
    expect(restarted.presets.first.accentColor, const Color(0xFFFF5C7A));
    expect(restarted.current.toJson(), adoptedCurrent.toJson());

    // After one-time rollback, subsequent explicit edits of a built-in
    // should continue to persist: this is not a perpetual forced reset.
    final chosen = restarted.presets.first.copyWith(
      accentColor: const Color(0xFF2266BB),
    );
    restarted.savePreset(chosen);
    await Future<void>.delayed(Duration.zero);
    final again = ThemeService();
    await again.init();
    addTearDown(again.dispose);
    expect(again.presets.first.accentColor, const Color(0xFF2266BB));
  });

  test('active built-in follows the original palette during one-time rollback',
      () async {
    final proposed = AppThemePreset.defaultDark.copyWith(
      buttonTextColor: Colors.black,
      updateMarkColor: const Color(0xFF00CCCC),
    );
    SharedPreferences.setMockInitialValues({
      'theme_presets': [jsonEncode(proposed.toJson())],
      'theme_current_json': jsonEncode(proposed.toJson()),
    });
    final theme = ThemeService();
    await theme.init();
    addTearDown(theme.dispose);
    expect(theme.current.id, 'default_dark');
    expect(theme.current.buttonTextColor, Colors.white);
    expect(theme.current.updateMarkColor, const Color(0xFFFFB020));
  });
}
