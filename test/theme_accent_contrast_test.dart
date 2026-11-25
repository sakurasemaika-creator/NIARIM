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
        id: ThemeService.customCurrentId,
        accentColor: const Color(0x20777777),
        selectionColor: const Color(0x80FFFFFF),
      ),
      AppThemePreset.defaultDark.copyWith(
        id: ThemeService.customCurrentId,
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

  // 誤りの色（入力欄の誤りの状態）はテーマの警告色。利用者が選んでいない
  // 警告色（古い保存・引き継ぎ・書き出したテーマ）は、そのテーマの背景から
  // 読める赤に決まる。利用者が選んだ警告色・ほかの色は自動で差し替えない。
  test(
    'semantic error foreground stays readable on customized surfaces',
    () async {
      for (final background in [
        const Color(0xFFAA2B35), // red surface hides default Material error
        const Color(0xFFFFE47A), // pale yellow theme
        const Color(0xFF17161C), // dark theme
      ]) {
        final preset = AppThemePreset.defaultLight.copyWith(
          id: ThemeService.customCurrentId,
          accentColor: const Color(0xFFFFE47A),
          panelBgColor: background,
          menuBgColor: background,
          textColor: Colors.white,
        );
        // 警告色より前の版の保存（警告色を持たない）。
        final saved = preset.toJson()..remove('warningColor');
        SharedPreferences.setMockInitialValues({
          'theme_current_json': jsonEncode(saved),
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
          service.current.toJson()..remove('warningColor'),
          saved,
          reason: 'Contrast protection must not change saved user colors',
        );
        service.dispose();

        // 利用者が選んだ警告色は読みにくくてもそのまま（救済ボタンの判定に
        // 任せる）。
        final chosen = preset.copyWith(warningColor: const Color(0xFF8E24AA));
        final own = ThemeService()..previewCurrent(chosen);
        expect(own.themeData.colorScheme.error, const Color(0xFF8E24AA));
        own.dispose();
      }
    },
  );
}
