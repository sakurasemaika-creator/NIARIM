import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/pump_real_async.dart';

/// 表示のメニューは、表示形式（タイル・詳細）と大きさ（大・中・小）の2つに
/// 分かれ、今の表示形式と大きさにチェックが付き（読み上げでも選択中）、
/// ボタンを覆わないよう下に開く。プロジェクト・作品一覧・共有のタブは
/// それぞれの表示に印を付ける。詳細でも大・中・小を選べ、行の絵の大きさが
/// 変わる。
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
      ja.homeViewLayoutTiles,
      ja.homeViewModeDetail,
      ja.homeViewModeLarge,
      ja.homeViewModeMedium,
      ja.homeViewModeSmall,
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
    // 表示サイズを選んでいないスマホの幅はタイルの小。
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewLayoutTiles, ja.homeViewModeSmall]);
    expect(
      tester.getSemantics(item(ja.homeViewModeSmall)),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    // 2つの見出し（表示形式・サイズ）は選べない見出し。
    expect(find.text(ja.homeViewLayoutHeading), findsOneWidget);
    expect(find.text(ja.homeViewSizeHeading), findsOneWidget);
    final button = tester.getRect(find.byKey(menuKey));
    expect(
      tester.getRect(find.text(ja.homeViewLayoutHeading)).top,
      greaterThanOrEqualTo(button.bottom - 1),
    );
    // 詳細にすると詳細の中から始まる。
    await tester.tap(item(ja.homeViewModeDetail));
    await tester.pumpAndSettle();
    double thumb() => tester
        .getSize(
          find
              .descendant(
                of: find.byType(ListTile).first,
                matching: find.byType(ClipRRect),
              )
              .first,
        )
        .height;
    final medium = thumb();
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewModeDetail, ja.homeViewModeMedium]);
    // 詳細のまま大にすると、行（絵）が大きくなる。
    await tester.tap(item(ja.homeViewModeLarge));
    await tester.pumpAndSettle();
    expect(thumb(), greaterThan(medium));
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewModeDetail, ja.homeViewModeLarge]);
    // タイルへ戻すと、画面の幅で決まる大きさ（スマホは小）から始まる。
    await tester.tap(item(ja.homeViewLayoutTiles));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewLayoutTiles, ja.homeViewModeSmall]);
    await tester.tap(item(ja.homeViewModeSmall));
    await tester.pumpAndSettle();

    // 作品一覧のタブは作品一覧の表示サイズ（選んでいないので小）。作品一覧は
    // 書き出したファイルを本物の読み込みで探すので、実時間も進める。
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewLayoutTiles, ja.homeViewModeSmall]);
    await tester.tap(item(ja.homeViewModeLarge));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(checked(tester), [ja.homeViewLayoutTiles, ja.homeViewModeLarge]);
    await tester.tap(item(ja.homeViewModeLarge));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
    await home.close();
  });
}
