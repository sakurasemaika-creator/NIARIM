import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

import 'helpers/home_app_harness.dart';

/// フォルダの中で検索を開いても、入力が空でフォルダの中身を出している間は
/// パンくず（「⌂ > フォルダ名」）を残す。以前は検索を開いただけで消え、
/// フォルダの中身が出ているのに今いる場所が分からなくなった。探す言葉を
/// 入れると全体から探すので、そのときは出さない（今までどおり）。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));

  Finder crumbs() => find.byTooltip(ja.projectListFolderRootOption);
  Finder folderCrumb(String name) =>
      find.widgetWithText(TextButton, name).hitTestable();

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('homeSearchButton')));
    await tester.pumpAndSettle();
  }

  for (final byTag in [false, true]) {
    testWidgets('the breadcrumb stays while an empty search shows the folder '
        '(${byTag ? 'tag' : 'name'} search)', (tester) async {
      final home = HomeAppHarness.prepare(tester);
      await home.open(
        seed: (service) async {
          final folder = await service.createFolder('Storyboards');
          await HomeAppHarness.work(service, 'Inside', folderId: folder.id);
          await HomeAppHarness.work(service, 'Outside');
        },
      );
      await tester.tap(HomeAppHarness.inProjects(find.text('Storyboards')));
      await tester.pumpAndSettle();
      expect(crumbs(), findsOneWidget);
      expect(folderCrumb('Storyboards'), findsOneWidget);

      await openSearch(tester);
      if (byTag) {
        await tester.tap(find.byKey(const Key('homeSearchTagToggle')));
        await tester.pumpAndSettle();
      }
      // 入力が空：フォルダの中身のまま、パンくずも残る。
      expect(HomeAppHarness.inProjects(find.text('Inside')), findsOneWidget);
      expect(HomeAppHarness.inProjects(find.text('Outside')), findsNothing);
      expect(crumbs(), findsOneWidget);
      expect(folderCrumb('Storyboards'), findsOneWidget);
      // 空白だけ・タグの印だけでも、まだ全体からは探していない。
      await tester.enterText(
        find.byKey(const Key('homeSearchInput')),
        byTag ? '#' : '  ',
      );
      await tester.pumpAndSettle();
      expect(HomeAppHarness.inProjects(find.text('Inside')), findsOneWidget);
      expect(crumbs(), findsOneWidget);

      // 言葉を入れると全体から探すので、パンくずは出さない。
      await tester.enterText(
        find.byKey(const Key('homeSearchInput')),
        byTag ? '#x' : 'side',
      );
      await tester.pumpAndSettle();
      expect(crumbs(), findsNothing);
      // 消して空に戻すと、またフォルダの中身とパンくず。
      await tester.enterText(find.byKey(const Key('homeSearchInput')), '');
      await tester.pumpAndSettle();
      expect(HomeAppHarness.inProjects(find.text('Inside')), findsOneWidget);
      expect(crumbs(), findsOneWidget);
      // パンくずの「⌂」で一番上へ戻れる（検索は開いたまま）。
      await tester.tap(crumbs());
      await tester.pumpAndSettle();
      expect(HomeAppHarness.inProjects(find.text('Outside')), findsOneWidget);
      expect(crumbs(), findsNothing);
      expect(find.byKey(const Key('homeSearchInput')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
