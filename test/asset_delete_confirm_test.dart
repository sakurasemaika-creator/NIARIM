// トーン・スタンプの「削除」は、ブラシと同じく確かめてから消す（消したものは
// 戻せない）。確かめの「削除」は取り消せない操作の警告色の塗りのボタン。
//
// 実際に使ってみたとき（2026-11-27）、トーンとスタンプはメニューの「削除」で
// すぐに消え、元に戻せなかった（ブラシだけ確かめがあり、その「削除」も普通の
// 文字のボタンだった）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/widgets/docked_panel_scope.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('ja'));

  Future<BuildContext> pump(WidgetTester tester, Widget panel) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    late BuildContext context;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (themeContext) => MaterialApp(
            theme: themeContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (inner) {
                  context = inner;
                  return DockedPanelScope(child: panel);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return context;
  }

  /// Opens the menu of the row named [name] and chooses 「削除」.
  Future<void> chooseDelete(WidgetTester tester, String name) async {
    // A new item is at the end of the list.
    await tester.scrollUntilVisible(
      find.text(name),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text(name),
      matching: find.byType(InkWell),
    );
    final menu = find.descendant(
      of: row.first,
      matching: find.byIcon(Icons.more_vert),
    );
    await tester.ensureVisible(menu.first);
    await tester.tap(menu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete).last);
    await tester.pumpAndSettle();
  }

  Future<void> expectAskedThenDeleted(
    WidgetTester tester,
    String name,
    bool Function() exists,
  ) async {
    await chooseDelete(tester, name);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(exists(), isTrue, reason: 'not deleted before it is confirmed');
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(exists(), isTrue, reason: 'Cancel keeps it');

    await chooseDelete(tester, name);
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, l10n.commonDelete),
    );
    expect(confirm, findsOneWidget, reason: 'the warning filled button');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(exists(), isFalse);
    expect(tester.takeException(), isNull);
  }

  testWidgets('deleting a tone asks first', (tester) async {
    final context = await pump(tester, TonePanel(onClose: () {}));
    final tones = context.read<ToneService>();
    tones.duplicateTone(tones.tones.first.id, name: '消すトーン');
    await tester.pump(const Duration(milliseconds: 200));
    final id = tones.tones.singleWhere((t) => t.name == '消すトーン').id;
    await expectAskedThenDeleted(
      tester,
      '消すトーン',
      () => tones.tones.any((t) => t.id == id),
    );
  });

  testWidgets('deleting a stamp asks first', (tester) async {
    final context = await pump(tester, StampPanel(onClose: () {}));
    final stamps = context.read<StampService>();
    stamps.duplicateStamp(stamps.stamps.first.id, name: '消すスタンプ');
    await tester.pump(const Duration(milliseconds: 200));
    final id = stamps.stamps.singleWhere((s) => s.name == '消すスタンプ').id;
    await expectAskedThenDeleted(
      tester,
      '消すスタンプ',
      () => stamps.stamps.any((s) => s.id == id),
    );
  });
}
