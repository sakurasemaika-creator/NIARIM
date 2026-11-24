// テーマ一覧のカードを押して配色を取り込んだとき、
// （1）取り込んだテーマの行に「使用中」の印が付き、
// （2）知らせの「元に戻す」で押す前の配色（編集していたテーマならその編集の
// 状態ごと）へ戻ることを見張る。1回押すだけで自分で作った配色が置き換わり、
// 戻す手段が無かった。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'package:niarim/services/palette_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('adopting a theme marks it in use and can be undone', (
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

    final before = service.current;
    expect(service.isEditingPreset, isTrue);
    final target = service.presets.firstWhere(
      (p) => p.id != before.id && p.accentColor != before.accentColor,
    );
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(target.name),
      120,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(target.name));
    await tester.pump(const Duration(milliseconds: 400));
    // 知らせが下から出きるまで待つ。
    await tester.pump(const Duration(milliseconds: 800));

    expect(service.current.accentColor, target.accentColor);
    expect(service.isEditingPreset, isFalse);
    expect(
      find.descendant(
        of: find.byKey(ValueKey(target.id)),
        matching: find.byKey(const Key('themePresetInUse')),
      ),
      findsOneWidget,
      reason: '取り込んだテーマの行に「使用中」が付くこと',
    );
    expect(
      find.byKey(const Key('themePresetEditingCheck')),
      findsNothing,
      reason: '取り込みは編集ではないので鉛筆の印は付かない',
    );

    final undo = find.widgetWithText(SnackBarAction, l10n.homeUndoAction);
    expect(undo, findsOneWidget);
    await tester.tap(undo);
    await tester.pump(const Duration(milliseconds: 400));

    expect(service.current.accentColor, before.accentColor);
    expect(service.current.panelBgColor, before.panelBgColor);
    expect(service.current.id, before.id);
    expect(service.isEditingPreset, isTrue, reason: '編集していた状態ごと戻ること');
    await tester.pumpAndSettle();
  });
}
