// ショートカット設定の「既定のショートカットに戻す」（P2-13）。
//
// 既定のキー（取り消し・コピー・再生など）を消したり変えたりした後で、最初の
// 割り当てへ戻す手段が無かった（消した既定のキーは、自分で同じキーを足し直す
// しかなかった）。確かめてから、足した・変えた・消したキーをまとめて最初の
// キーへ戻し、知らせの「元に戻す」で戻す前のキーへ戻せることを見張る。
// 全部消して空になった一覧からも戻せる。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/screens/settings/shortcut_settings_screen.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_toast_messenger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<String> jsonOf(Iterable<ShortcutBinding> bindings) => [
    for (final b in bindings) jsonEncode(b.toJson()),
  ];

  final mine = ShortcutBinding(
    id: 'mine',
    label: 'Mine',
    keyId: LogicalKeyboardKey.keyB.keyId,
    alt: true,
    command: ShortcutCommand.toggleLayerPanel,
  );

  test('a new installation starts with the default keys', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ShortcutService();
    await service.init();
    expect(jsonOf(service.bindings), jsonOf(ShortcutService.defaultBindings));
    expect(service.hasDefaultBindings, isTrue);
  });

  test('restoring the defaults replaces added, changed and removed keys, '
      'is saved, and can be undone', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ShortcutService();
    await service.init();
    final undo = service.bindings.first;
    service.removeBinding(undo.id);
    final copy = service.bindings.firstWhere(
      (b) => b.command == ShortcutCommand.copy,
    );
    service.updateBinding(
      ShortcutBinding.fromJson({
        ...copy.toJson(),
        'keyId': LogicalKeyboardKey.keyQ.keyId,
      }),
    );
    service.addBinding(mine);
    expect(service.hasDefaultBindings, isFalse);
    final edited = jsonOf(service.bindings);

    final before = service.resetToDefaults();
    expect(jsonOf(before), edited);
    expect(jsonOf(service.bindings), jsonOf(ShortcutService.defaultBindings));
    expect(service.hasDefaultBindings, isTrue);
    await Future<void>.delayed(Duration.zero);
    final reread = ShortcutService();
    await reread.init();
    expect(jsonOf(reread.bindings), jsonOf(ShortcutService.defaultBindings));

    service.restoreBindings(before);
    expect(jsonOf(service.bindings), edited);
    await Future<void>.delayed(Duration.zero);
    final again = ShortcutService();
    await again.init();
    expect(jsonOf(again.bindings), edited);
  });

  Future<ShortcutService> pumpScreen(
    WidgetTester tester,
    void Function(ShortcutService service) edit,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = ShortcutService();
    await tester.runAsync(service.init);
    edit(service);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    final settings = SettingsService();
    await tester.runAsync(settings.init);
    const locale = Locale('ja');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShortcutService>.value(value: service),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
        ],
        child: MaterialApp(
          locale: locale,
          theme: ThemeService().themeDataFor(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AppToastMessenger(child: child!),
          home: const ShortcutSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  final l10n = lookupAppLocalizations(const Locale('ja'));
  final button = find.byKey(const ValueKey('shortcutResetToDefaults'));

  testWidgets('the button cannot be pressed while the keys are the defaults', (
    tester,
  ) async {
    await pumpScreen(tester, (_) {});
    await tester.scrollUntilVisible(button, 200);
    expect(
      tester.widget<ButtonStyleButton>(button).onPressed,
      isNull,
      reason: 'nothing to restore',
    );
  });

  testWidgets('confirm, restore, and undo from the notice', (tester) async {
    final service = await pumpScreen(tester, (service) {
      service.removeBinding(service.bindings.first.id);
      service.addBinding(mine);
    });
    final edited = jsonOf(service.bindings);
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(l10n.shortcutResetConfirmTitle), findsOneWidget);
    expect(find.text(l10n.shortcutResetConfirmBody), findsOneWidget);

    // キャンセルでは何も変わらない。
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(jsonOf(service.bindings), edited);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcutResetConfirm')));
    await tester.pumpAndSettle();
    expect(jsonOf(service.bindings), jsonOf(ShortcutService.defaultBindings));
    expect(find.text(l10n.shortcutResetDone), findsOneWidget);

    await tester.tap(find.widgetWithText(SnackBarAction, l10n.homeUndoAction));
    await tester.pumpAndSettle();
    expect(jsonOf(service.bindings), edited);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('an empty list can go back to the default keys', (tester) async {
    final service = await pumpScreen(tester, (service) {
      for (final b in [...service.bindings]) {
        service.removeBinding(b.id);
      }
    });
    expect(find.text(l10n.shortcutEmpty), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcutResetConfirm')));
    await tester.pumpAndSettle();
    expect(jsonOf(service.bindings), jsonOf(ShortcutService.defaultBindings));
    expect(find.text(l10n.shortcutEmpty), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
