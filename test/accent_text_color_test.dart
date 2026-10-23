import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/config/accent_text_theme.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
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
      final json = AppThemePreset.defaultLight.toJson();
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

  testWidgets('the theme settings list it next to the accent and save it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final tempDir = Directory.systemTemp.createTempSync('niarim_accent_text_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(
        providers: providers!,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ThemeSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final service = tester
        .element(find.byType(ThemeSettingsScreen))
        .read<ThemeService>();
    final l10n = lookupAppLocalizations(const Locale('ja'));

    final tile = find.byKey(const Key('themeAccentTextColorTile'));
    expect(tile, findsOneWidget);
    expect(find.text(l10n.themeColorAccentText), findsOneWidget);
    // 差し色のすぐ下に並ぶ。
    expect(
      tester.getTopLeft(tile).dy,
      greaterThan(tester.getTopLeft(find.text(l10n.themeColorAccent)).dy),
    );
    expect(
      tester.getTopLeft(tile).dy,
      lessThan(tester.getTopLeft(find.text(l10n.themeColorText)).dy),
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();
    service.previewCurrent(service.current.copyWith(accentTextColor: darkRed));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    expect(service.current.accentTextColor, darkRed);
    // 差し色はそのまま。
    expect(
      service.current.accentColor,
      AppThemePreset.defaultLight.accentColor,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      AppThemePreset.fromJson(
        jsonDecode(prefs.getString('theme_current_json')!)
            as Map<String, dynamic>,
      ).accentTextColor,
      darkRed,
    );
  });
}
