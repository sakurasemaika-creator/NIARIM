import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/accent_text_theme.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/color_contrast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テーマ・外観の「アクセントの文字・アイコン色」：差し色で背景の上に直接
/// 描く文字・アイコンの色。差し色1色が塗りと背景の上の文字を兼ねていたため、
/// 明るい差し色を選ぶと選択中のタブ名や枠のボタンの文字が読めなかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const darkRed = Color(0xFF8A1538);
  final whiteAccent = AppThemePreset.defaultLight.copyWith(
    accentColor: Colors.white,
    selectionColor: Colors.black,
  );

  group('preset', () {
    test('saved themes without the colour follow the accent', () {
      final json = AppThemePreset.defaultLight
          .copyWith(accentTextColor: null)
          .toJson();
      expect(json.containsKey('accentTextColor'), isFalse);
      final restored = AppThemePreset.fromJson(json);
      expect(restored.accentTextColor, isNull);
      expect(restored.effectiveAccentTextColor, restored.accentColor);
      // 差し色を変えると、未指定の文字色も一緒に変わる。
      expect(
        restored.copyWith(accentColor: Colors.teal).effectiveAccentTextColor,
        Colors.teal,
      );
    });

    test('a chosen colour is saved, kept and can be cleared', () {
      final chosen = whiteAccent.copyWith(accentTextColor: darkRed);
      final restored = AppThemePreset.fromJson(chosen.toJson());
      expect(restored.accentTextColor, darkRed);
      expect(restored.effectiveAccentTextColor, darkRed);
      expect(
        restored.copyWith(textColor: Colors.black).accentTextColor,
        darkRed,
      );
      expect(restored.copyWith(accentTextColor: null).accentTextColor, isNull);
      // 型の違う値は未指定として読む。
      expect(
        AppThemePreset.fromJson({
          ...chosen.toJson(),
          'accentTextColor': 'red',
        }).accentTextColor,
        isNull,
      );
    });
  });

  test('text on the background uses it, fills keep the accent', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    addTearDown(service.dispose);
    await service.init();
    for (final preset in [
      AppThemePreset.defaultLight,
      whiteAccent,
      whiteAccent.copyWith(accentTextColor: darkRed),
    ]) {
      service.previewCurrent(preset);
      final theme = service.themeData;
      final text = preset.effectiveAccentTextColor;
      expect(theme.extension<AccentTextTheme>()!.color, text);
      expect(theme.tabBarTheme.labelColor, text);
      for (final style in [
        theme.textButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
      ]) {
        expect(style.foregroundColor!.resolve({}), text);
      }
      expect(theme.snackBarTheme.actionTextColor, text);
      // 塗り（下線・FAB）は差し色のまま。
      expect(theme.tabBarTheme.indicatorColor, preset.accentColor);
      expect(theme.colorScheme.primary, preset.accentColor);
    }
  });

  test('an unreadable choice shows the reset button on the splash', () {
    final base = AppThemePreset.defaultLight;
    expect(isThemeAtLockoutRisk(base), isFalse);
    expect(
      isThemeAtLockoutRisk(base.copyWith(accentTextColor: base.panelBgColor)),
      isTrue,
    );
    expect(
      isThemeAtLockoutRisk(base.copyWith(accentTextColor: base.menuBgColor)),
      isTrue,
    );
    expect(
      isThemeAtLockoutRisk(base.copyWith(accentTextColor: darkRed)),
      isFalse,
    );
  });

  testWidgets('six basic colors update linked colors and preserve overrides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    final palette = PaletteService();
    final settings = SettingsService();
    addTearDown(service.dispose);
    addTearDown(palette.dispose);
    addTearDown(settings.dispose);
    await service.init();
    await palette.init();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: service),
          ChangeNotifierProvider.value(value: palette),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ThemeSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('ja'));

    final scrollable = find.byType(Scrollable).first;
    Future<void> show(Finder tile, {double step = 140}) async {
      await tester.scrollUntilVisible(tile, step, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(tile.hitTestable(), findsOneWidget);
    }

    Future<void> tap(Finder tile, {double step = 140}) async {
      await show(tile, step: step);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    Future<void> enterHex(String hex) async {
      final field = find.descendant(
        of: find.byType(ColorPickerPanel),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, hex);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    Future<void> closePicker() async {
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    }

    Future<void> pick(String label, String hex, {double step = 140}) async {
      await tap(find.text(label), step: step);
      await enterHex(hex);
      await closePicker();
    }

    final basics = [
      l10n.themeColorAccent,
      l10n.themeColorText,
      l10n.themeColorButtonText,
      l10n.themeColorPanelBg,
      l10n.themeColorMenuBg,
      l10n.themeColorUpdateMark,
    ];
    final advanced = [
      l10n.themeColorAccentText,
      l10n.themeColorMenuText,
      l10n.themeColorSelection,
      l10n.themeColorSelectionText,
    ];
    for (final label in basics) {
      await show(find.text(label));
    }
    final disclosure = find.text(l10n.themeAdvancedColors);
    await show(disclosure);
    for (final label in advanced) {
      expect(find.text(label), findsNothing);
    }
    await tester.drag(scrollable, const Offset(0, 550));
    await tester.pumpAndSettle();

    await pick(l10n.themeColorAccent, '126047');
    expect(service.current.effectiveAccentTextColor, const Color(0xFF126047));
    expect(service.current.selectionColor, const Color(0xFF126047));
    await pick(l10n.themeColorText, '231830');
    expect(service.current.menuTextColor, const Color(0xFF231830));
    await pick(l10n.themeColorButtonText, 'FDEEDC');
    expect(service.current.selectionTextColor, const Color(0xFFFDEEDC));
    await pick(l10n.themeColorPanelBg, 'F8F6EC');
    expect(service.current.panelBgColor, const Color(0xFFF8F6EC));
    expect(
      service.current.menuBgColor,
      AppThemePreset.defaultLight.menuBgColor,
    );
    await pick(l10n.themeColorMenuBg, 'FFF5E4');
    expect(service.current.menuBgColor, const Color(0xFFFFF5E4));
    expect(service.current.panelBgColor, const Color(0xFFF8F6EC));
    await pick(l10n.themeColorUpdateMark, 'FA9C24');
    expect(service.current.updateMarkColor, const Color(0xFFFA9C24));

    await tap(disclosure);
    for (final label in advanced) {
      await show(find.text(label));
    }
    await pick(l10n.themeColorAccentText, '8A1538', step: -140);
    await pick(l10n.themeColorMenuText, '572E73');
    await pick(l10n.themeColorSelection, '8A1538');
    await pick(l10n.themeColorSelectionText, 'F6F6AA');
    await tap(disclosure, step: -140);

    await tap(find.text(l10n.themeColorAccent), step: -140);
    // Passing through the override during a live edit must not make it follow.
    await enterHex('8A1538');
    await enterHex('2E5173');
    await closePicker();
    await pick(l10n.themeColorText, '31312A');
    await pick(l10n.themeColorButtonText, 'ECFDF6');
    expect(service.current.accentColor, const Color(0xFF2E5173));
    expect(service.current.accentTextColor, darkRed);
    expect(service.current.selectionColor, darkRed);
    expect(service.current.menuTextColor, const Color(0xFF572E73));
    expect(service.current.selectionTextColor, const Color(0xFFF6F6AA));

    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString('theme_current_json')!),
      service.current.toJson(),
    );
  });
}
