import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/pump_real_async.dart';

/// 表示サイズ（大・中・小・詳細）のメニューは、今の表示にチェックが付き
/// （読み上げでも選択中）、ボタンを覆わないよう下に開く。プロジェクト・
/// 作品一覧・共有のタブはそれぞれの表示サイズに印を付ける。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));
  const menuKey = Key('homeCollectionViewModeMenu');

  Finder item(String label) => find
      .descendant(
        of: find.byWidgetPredicate((w) => w is PopupMenuItem),
        matching: find.text(label),
      )
      .last;

  // 開いたメニューで、チェックが付いている項目の名前。
  List<String> checked(WidgetTester tester) => [
    for (final label in [
      ja.homeViewModeLarge,
      ja.homeViewModeMedium,
      ja.homeViewModeSmall,
      ja.homeViewModeDetail,
    ])
      if (find
          .descendant(
            of: find.ancestor(
              of: item(label),
              matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
            ),
            matching: find.byIcon(Icons.check),
          )
          .evaluate()
          .isNotEmpty)
        label,
  ];

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(menuKey));
    await tester.pumpAndSettle();
  }

  testWidgets('the size menu marks the current size and opens below', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final home = HomeAppHarness.prepare(tester);
    await home.open(
      size: const Size(390, 844),
      seed: (service) => HomeAppHarness.work(service, 'apple'),
    );
    // 表示サイズを選んでいないスマホの幅は小。
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewModeSmall]);
    expect(
      tester.getSemantics(item(ja.homeViewModeSmall)),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    final button = tester.getRect(find.byKey(menuKey));
    expect(
      tester.getRect(item(ja.homeViewModeLarge)).top,
      greaterThanOrEqualTo(button.bottom - 1),
    );
    await tester.tap(item(ja.homeViewModeDetail));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewModeDetail]);
    await tester.tap(item(ja.homeViewModeDetail));
    await tester.pumpAndSettle();

    // 作品一覧のタブは作品一覧の表示サイズ（選んでいないので小）。作品一覧は
    // 書き出したファイルを本物の読み込みで探すので、実時間も進める。
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewModeSmall]);
    await tester.tap(item(ja.homeViewModeLarge));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewModeLarge]);
    await tester.tap(item(ja.homeViewModeLarge));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
    await home.close();
  });
}
