import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

import 'helpers/home_clipboard_harness.dart';

/// 作品一覧・共有・ゴミ箱のタブで、検索・絞り込み（お気に入りだけ・ゴミ箱の
/// 種類）に当たるものが無いとき、「まだありません」「ゴミ箱は空です」とは
/// 言わず、当たるものが無いと言って絞り込みを外すボタン（「検索をやめる」
/// 「すべて表示」）を出す（プロジェクトのタブと同じ）。以前は3つのタブとも
/// 空のときの文だけを出し、外す道が無かった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> search(HomeClipboardHarness home, String query) async {
    final tester = home.tester;
    if (find.byKey(const Key('homeSearchInput')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('homeSearchButton')));
      await home.settle();
    }
    await tester.enterText(find.byKey(const Key('homeSearchInput')), query);
    await home.settleIo(2);
  }

  Future<void> tapButton(HomeClipboardHarness home, String label) async {
    final button = find.widgetWithText(OutlinedButton, label);
    expect(button, findsOneWidget, reason: 'no "$label" button');
    await home.tester.ensureVisible(button);
    await home.settle();
    await home.tester.tap(button);
    await home.settleIo(2);
  }

  void expectNoEmptyLibraryText(AppLocalizations l10n) {
    for (final text in [
      l10n.homeWorksEmpty,
      l10n.homeWorksEmptyHint,
      l10n.homeSharedEmpty,
      l10n.sharedArchiveEmpty,
      l10n.homeTrashEmpty,
    ]) {
      expect(find.text(text), findsNothing, reason: text);
    }
  }

  testWidgets('Works: a search without hits offers to clear it', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_apple.gif'],
    );
    final l10n = home.l10n;
    await home.showTab(1);
    expect(find.text('clip_apple.gif'), findsWidgets);
    await search(home, 'zzz');
    expect(find.text(l10n.projectListNoMatchTitle('zzz')), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    await tapButton(home, l10n.projectListClearSearch);
    expect(find.byKey(const Key('homeSearchInput')), findsNothing);
    expect(find.text('clip_apple.gif'), findsWidgets);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('Works: favourites-only without favourites offers show all', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_apple.gif'],
    );
    final l10n = home.l10n;
    await home.showTab(1);
    await tester.tap(find.byKey(const Key('worksFavoritesOnlyFilter')));
    await home.settleIo(2);
    expect(find.text(l10n.projectListNoFavoritesTitle), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    await tapButton(home, l10n.projectListShowAll);
    expect(find.text('clip_apple.gif'), findsWidgets);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('Shared (received): search and favourites say nothing matches', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final l10n = home.l10n;
    await home.addReceived('apple');
    await home.showTab(2);
    expect(find.text('apple'), findsWidgets);
    await search(home, 'zzz');
    expect(find.text(l10n.projectListNoMatchTitle('zzz')), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    await tapButton(home, l10n.projectListClearSearch);
    expect(find.byKey(const Key('homeSearchInput')), findsNothing);
    expect(find.text('apple'), findsWidgets);

    await tester.tap(find.byKey(const Key('sharedFavoritesOnlyFilter')));
    await home.settleIo(2);
    expect(find.text(l10n.projectListNoFavoritesTitle), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    await tapButton(home, l10n.projectListShowAll);
    expect(find.text('apple'), findsWidgets);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('Shared (created): search and favourites say nothing matches', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final l10n = home.l10n;
    final dir = Directory('${home.dir.path}/niarim/shared/outgoing')
      ..createSync(recursive: true);
    File('${dir.path}/mine.niashare').writeAsBytesSync(List.filled(64, 1));
    await tester.runAsync(() => home.projects.refreshOutgoingShares());
    await home.settleIo(2);
    await home.showTab(2);
    await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
    await home.settleIo(2);
    expect(find.textContaining('mine'), findsWidgets);
    await search(home, 'zzz');
    expect(find.text(l10n.projectListNoMatchTitle('zzz')), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    await tapButton(home, l10n.projectListClearSearch);
    expect(find.byKey(const Key('homeSearchInput')), findsNothing);
    expect(find.textContaining('mine'), findsWidgets);

    await tester.tap(find.byKey(const Key('sharedFavoritesOnlyFilter')));
    await home.settleIo(2);
    expect(find.text(l10n.projectListNoFavoritesTitle), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    await tapButton(home, l10n.projectListShowAll);
    expect(find.textContaining('mine'), findsWidgets);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('Trash: search and type filters say nothing matches', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final l10n = home.l10n;
    final apple = await home.addWork('apple');
    await tester.runAsync(() => home.projects.deleteProject(apple.id));
    await home.settleIo(2);
    await home.showTab(3);
    expect(find.text('apple'), findsWidgets);
    await search(home, 'zzz');
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.text(l10n.homeTrashNoMatchTitle('zzz')), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    await tapButton(home, l10n.projectListClearSearch);
    expect(find.byKey(const Key('homeSearchInput')), findsNothing);
    expect(find.text('apple'), findsWidgets);

    // 作成したプロジェクトの種類を外すと、選んだ種類に当たるものが無い。
    // 「検索をやめる」を押すために一覧を送ったので、種類のチップは一覧の
    // 上の方にある（タブの列の下に隠れている）。送り戻してから押す。
    final createdKind = find.byKey(const ValueKey('trashKind_createdProject'));
    await tester.ensureVisible(createdKind);
    await home.settle();
    await tester.tap(createdKind);
    await home.settleIo(2);
    expect(find.text(l10n.homeTrashNoKindTitle), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    // 検索には当たるが、種類で隠れているとき。
    await search(home, 'apple');
    expect(find.text(l10n.homeTrashNoKindMatchTitle('apple')), findsOneWidget);
    expectNoEmptyLibraryText(l10n);
    // 何にも当たらない言葉は、種類ではなく検索の文。
    await search(home, 'zzz');
    expect(find.text(l10n.homeTrashNoMatchTitle('zzz')), findsOneWidget);
    await search(home, 'apple');
    await tapButton(home, l10n.projectListShowAll);
    expect(find.text('apple'), findsWidgets);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a truly empty tab still says it is empty', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final l10n = home.l10n;
    await home.showTab(1);
    expect(find.text(l10n.homeWorksEmpty), findsOneWidget);
    await home.showTab(2);
    expect(find.text(l10n.homeSharedEmpty), findsOneWidget);
    await home.showTab(3);
    expect(find.text(l10n.homeTrashEmpty), findsOneWidget);
    await home.close();
  });
}
