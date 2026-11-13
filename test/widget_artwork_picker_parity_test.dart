import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/widget_artwork_picker_screen.dart';

import 'helpers/home_app_harness.dart';

/// 設定の「ホーム画面ウィジェット」の作品を選ぶ一覧は、ホームと同じ
/// 表示サイズのメニュー（説明・今の表示の印）と、絞り込みで空のときの
/// 表示（検索をやめる・すべて表示）を持つ。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));

  Finder inPicker(Finder finder) => find.descendant(
    of: find.byType(WidgetArtworkPickerScreen),
    matching: finder,
  );

  Finder item(String label) => find
      .descendant(
        of: find.byWidgetPredicate((w) => w is PopupMenuItem),
        matching: find.text(label),
      )
      .last;

  bool isChecked(String label) => find
      .descendant(
        of: find.ancestor(
          of: item(label),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
        matching: find.byIcon(Icons.check),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('the artwork picker has the home size menu and empty states', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(seed: (service) => HomeAppHarness.work(service, 'apple'));
    appRouter.push('/settings/widget/artwork');
    await tester.pumpAndSettle();

    final menu = inPicker(find.byTooltip(ja.homeViewModeTooltip));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(isChecked(ja.homeViewModeMedium), isTrue);
    expect(isChecked(ja.homeViewModeDetail), isFalse);
    await tester.tap(item(ja.homeViewModeDetail));
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(isChecked(ja.homeViewModeDetail), isTrue);
    await tester.tap(item(ja.homeViewModeDetail));
    await tester.pumpAndSettle();

    // 検索に当たらないときは「検索をやめる」。
    await tester.tap(inPicker(find.byIcon(Icons.search)));
    await tester.pumpAndSettle();
    await tester.enterText(inPicker(find.byType(TextField)), 'zzz');
    await tester.pumpAndSettle();
    expect(
      inPicker(find.text(ja.projectListNoMatchTitle('zzz'))),
      findsOneWidget,
    );
    await tester.tap(inPicker(find.text(ja.projectListClearSearch)));
    await tester.pumpAndSettle();
    expect(inPicker(find.byType(TextField)), findsNothing);
    expect(inPicker(find.text('apple')), findsOneWidget);

    // お気に入りが無いときは「すべて表示」。カードにメニューが無いので、
    // メニューを指す説明は出さない。
    await tester.tap(
      inPicker(find.widgetWithText(FilterChip, ja.homeFavoritesOnly)),
    );
    await tester.pumpAndSettle();
    expect(inPicker(find.text(ja.projectListNoFavoritesTitle)), findsOneWidget);
    expect(inPicker(find.text(ja.projectListNoFavoritesHint)), findsNothing);
    await tester.tap(inPicker(find.text(ja.projectListShowAll)));
    await tester.pumpAndSettle();
    expect(inPicker(find.text('apple')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
