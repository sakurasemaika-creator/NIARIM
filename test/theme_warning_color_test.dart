import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/signal_colors.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:niarim/utils/warning_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テーマ・外観の「警告色」（取り消せない操作と、作品が失われうる失敗だけに
/// 使う色）。組み込みの28のテーマは決め方（[defaultWarningColorFor]）で
/// 決めた値を定数として持ち、どのテーマの背景の上でも読め、差し色・更新
/// マーク色（注意色）と見分けられる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<AppThemePreset>> builtIns() async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.init();
    return service.presets;
  }

  test('every built-in theme writes its warning colour down', () async {
    final presets = await builtIns();
    expect(presets, hasLength(28));
    for (final preset in presets) {
      expect(preset.toJson()['warningColor'], isA<int>(), reason: preset.id);
    }
  });

  test('each built-in warning colour is the one the rule gives', () async {
    for (final preset in await builtIns()) {
      expect(
        preset.warningColor,
        defaultWarningColorFor(preset),
        reason:
            '${preset.id}: recompute with defaultWarningColorFor and write '
            'the value into the preset',
      );
    }
  });

  test('each built-in warning colour reads on both backgrounds and stays '
      'apart from the accent and the update mark', () async {
    for (final preset in await builtIns()) {
      final warning = preset.warningColor;
      final onWarning = readableInkOn(warning, themeInksOf(preset));
      expect(
        apcaContrast(warning, preset.panelBgColor).abs(),
        greaterThanOrEqualTo(kWarningMinLc),
        reason: '${preset.id}: warning on the panel',
      );
      expect(
        apcaContrast(warning, preset.menuBgColor).abs(),
        greaterThanOrEqualTo(kWarningMinLc),
        reason: '${preset.id}: warning on the menu',
      );
      expect(
        apcaContrast(onWarning, warning).abs(),
        greaterThanOrEqualTo(kWarningMinLc),
        reason: '${preset.id}: text on a warning button',
      );
      // 小さな知らせの文にも足りる比（WCAG 2のAA）。
      for (final (ink, ground, where) in [
        (warning, preset.panelBgColor, 'warning on the panel'),
        (warning, preset.menuBgColor, 'warning on the menu'),
        (onWarning, warning, 'text on a warning button'),
      ]) {
        expect(
          contrastRatio(ink, ground),
          greaterThanOrEqualTo(kWarningMinContrastRatio),
          reason: '${preset.id}: $where',
        );
      }
      expect(
        cielabDeltaE(warning, preset.accentColor),
        greaterThanOrEqualTo(kWarningMinDeltaE),
        reason: '${preset.id}: warning against the accent',
      );
      expect(
        cielabDeltaE(warning, preset.updateMarkColor),
        greaterThanOrEqualTo(kWarningMinDeltaE),
        reason: '${preset.id}: warning against the caution colour',
      );
      // 赤（OKLCHの色相29°）の色。
      expect(warning.r, greaterThan(warning.g), reason: preset.id);
      expect(warning.r, greaterThan(warning.b), reason: preset.id);
    }
  });

  test(
    'the text on a warning button is one of the theme’s own colours',
    () async {
      for (final preset in await builtIns()) {
        final service = ThemeService();
        addTearDown(service.dispose);
        service.previewCurrent(preset);
        final theme = service.themeData;
        final signals = theme.extension<SignalColors>()!;
        expect(signals.warning, preset.warningColor, reason: preset.id);
        expect(signals.caution, preset.updateMarkColor, reason: preset.id);
        expect(themeInksOf(preset), contains(signals.onWarning));
        expect(themeInksOf(preset), contains(signals.onCaution));
        // Materialの誤りの状態（入力欄）も警告色。
        expect(theme.colorScheme.error, signals.warning, reason: preset.id);
        expect(theme.colorScheme.onError, signals.onWarning, reason: preset.id);
        // 数の印（通知）は更新の印なので注意色。
        expect(theme.badgeTheme.backgroundColor, signals.caution);
      }
    },
  );

  test('a theme saved before the warning colour gets the rule’s colour, and '
      'keeps it', () async {
    for (final preset in await builtIns()) {
      final old = preset.toJson()..remove('warningColor');
      final restored = AppThemePreset.fromJson(
        jsonDecode(jsonEncode(old)) as Map<String, dynamic>,
      );
      expect(restored.warningColor, preset.warningColor, reason: preset.id);
      // 保存し直すと決めた色を書く（後でほかの色を変えても動かない）。
      expect(restored.toJson()['warningColor'], preset.warningColor.toARGB32());
      final edited = restored.copyWith(accentColor: const Color(0xFFE53935));
      expect(edited.warningColor, preset.warningColor, reason: preset.id);
    }
  });

  test('the user’s warning colour is kept through JSON and copies', () {
    final mine = AppThemePreset.defaultLight.copyWith(
      id: 'mine',
      warningColor: const Color(0xFF8E24AA),
    );
    final restored = AppThemePreset.fromJson(
      jsonDecode(jsonEncode(mine.toJson())) as Map<String, dynamic>,
    );
    expect(restored.warningColor, const Color(0xFF8E24AA));
    expect(
      restored.copyWith(panelBgColor: const Color(0xFF222222)).warningColor,
      const Color(0xFF8E24AA),
    );
  });

  test('a mid-grey background that no lightness can serve still gets the '
      'closest red', () {
    final grey = AppThemePreset.defaultLight.copyWith(
      id: 'grey',
      panelBgColor: const Color(0xFF808080),
      menuBgColor: const Color(0xFF808080),
    );
    final warning = defaultWarningColorFor(grey);
    expect(warning.a, 1);
    expect(warning.r, greaterThan(warning.g));
  });

  test('changing another colour in the editor re-derives a warning colour '
      'the user did not choose, and keeps one they chose', () {
    final light = AppThemePreset.defaultLight;
    expect(warningFollowsRule(light), isTrue);
    final darkPanel = light.copyWith(
      panelBgColor: const Color(0xFF17161C),
      menuBgColor: const Color(0xFF201F27),
    );
    // copyWith keeps the colour; the editor re-derives it while it follows
    // the rule, so the warning stays readable on the new background.
    expect(darkPanel.warningColor, light.warningColor);
    final rederived = defaultWarningColorFor(darkPanel);
    expect(rederived, AppThemePreset.defaultDark.warningColor);
    final own = light.copyWith(warningColor: const Color(0xFF8E24AA));
    expect(warningFollowsRule(own), isFalse);
  });

  test('an unreadable warning colour shows the rescue button', () {
    for (final preset in [
      AppThemePreset.defaultLight,
      AppThemePreset.defaultDark,
    ]) {
      expect(isThemeAtLockoutRisk(preset), isFalse, reason: preset.id);
      expect(
        isThemeAtLockoutRisk(
          preset.copyWith(warningColor: preset.panelBgColor),
        ),
        isTrue,
        reason: '${preset.id}: warning equal to the panel',
      );
      expect(
        isThemeAtLockoutRisk(preset.copyWith(warningColor: preset.menuBgColor)),
        isTrue,
        reason: '${preset.id}: warning equal to the menu',
      );
    }
  });
}
