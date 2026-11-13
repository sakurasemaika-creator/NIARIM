import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';

import 'helpers/home_clipboard_harness.dart';

// 役目を終えたコピー・切り取りの知らせを残さない（DISC093）。
// - 貼り付けでクリップボードが空になったら（ゴミ箱へ貼り付けた・切り取りを
//   貼り終えた）、中身を伝える知らせを閉じ、切り取りの印も消す（Escを
//   ホームが取らない）。
// - ホームを離れたら（上に別の画面を積む・履歴ごと置き換える）、
//   「貼り付けを押してください」という知らせを他の画面に残さない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const frame = Duration(milliseconds: 16);

  /// 知らせが全部消えるまで描き、出た知らせを出た順に返す。
  Future<List<String?>> watchUntilGone(
    WidgetTester tester,
    HomeClipboardHarness home,
  ) async {
    final seen = <String?>[home.snackText()];
    var elapsed = Duration.zero;
    while (find.byType(SnackBar).evaluate().isNotEmpty &&
        elapsed < const Duration(seconds: 20)) {
      await tester.pump(frame);
      elapsed += frame;
      final text = home.snackText();
      if (seen.last != text) seen.add(text);
    }
    return seen;
  }

  void showTwoNotices(WidgetTester tester) {
    ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
      ..showSnackBar(const SnackBar(content: Text('first notice')))
      ..showSnackBar(const SnackBar(content: Text('waiting notice')));
  }

  testWidgets('pasting into the Trash closes the copy notice that waited', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    await home.addWork('banana');
    showTwoNotices(tester);
    await home.settle();
    await home.copy(['apple']);
    final copied = home.l10n.homeCopiedSnackbar(1);
    await home.showTab(3);
    await tester.tap(home.pasteButton);
    await home.settle();
    await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
    await home.waitFor(() => home.projects.trash.length == 1);
    final seen = await watchUntilGone(tester, home);
    debugPrint('notices after pasting into the Trash: $seen');
    expect(home.pasteButton, findsNothing);
    expect(
      seen,
      isNot(contains(copied)),
      reason: 'the copy notice still told to press Paste',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });

  for (final cut in [false, true]) {
    final kind = cut ? 'cut' : 'copy';

    testWidgets('pushing another screen closes the $kind notice and keeps '
        'the $kind', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      await home.addWork('apple');
      if (cut) {
        await home.cut(['apple']);
      } else {
        await home.copy(['apple']);
      }
      final text = cut
          ? home.l10n.homeCutSnackbar(1)
          : home.l10n.homeCopiedSnackbar(1);
      expect(home.snackText(), text);
      appRouter.push('/help');
      await home.settle();
      await home.settle();
      final seen = await watchUntilGone(tester, home);
      debugPrint('notices on the help screen: $seen');
      // 閉じ始めるのは画面を積んだとき（薄くなって消えるまで400ms）。
      expect(find.byType(SnackBar), findsNothing);
      expect(
        seen.where((t) => t == text),
        isEmpty,
        reason: 'the $kind notice followed onto the help screen',
      );
      appRouter.pop();
      await home.settle();
      await home.settle();
      // 切り取り・コピーそのものは残る（戻れば貼り付けられる）。
      expect(home.pasteButton, findsOneWidget);
      expect(tester.takeException(), isNull);
      await home.close();
    });

    testWidgets('a $kind notice waiting behind others does not show after '
        'leaving Home', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      await home.addWork('apple');
      showTwoNotices(tester);
      await home.settle();
      if (cut) {
        await home.cut(['apple']);
      } else {
        await home.copy(['apple']);
      }
      final text = cut
          ? home.l10n.homeCutSnackbar(1)
          : home.l10n.homeCopiedSnackbar(1);
      appRouter.push('/help');
      final seen = await watchUntilGone(tester, home);
      debugPrint('notices after leaving Home: $seen');
      expect(seen, isNot(contains(text)));
      // 画面の切り替えの間は、知らせが一瞬どちらの画面にも描かれない。
      expect(seen.whereType<String>().toSet(), {
        'first notice',
        'waiting notice',
      });
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  testWidgets('leaving Home for the splash screen closes the copy notice', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    await home.copy(['apple']);
    final copied = home.l10n.homeCopiedSnackbar(1);
    expect(home.snackText(), copied);
    appRouter.go('/');
    // ホームが外れたら（画面の切り替えの後）閉じ始め、薄くなって消える。
    var elapsed = Duration.zero;
    while (find.text(copied).evaluate().isNotEmpty &&
        elapsed < const Duration(seconds: 6)) {
      await tester.pump(frame);
      elapsed += frame;
    }
    debugPrint(
      'the copy notice left ${elapsed.inMilliseconds} ms after leaving Home',
    );
    expect(
      elapsed,
      lessThanOrEqualTo(const Duration(milliseconds: 1500)),
      reason: 'the copy notice stayed on the splash screen',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // 開いたメニュー（ポップアップ）はホームを離れたことにならない。
  testWidgets('opening a card menu keeps the copy notice', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    await home.addWork('banana');
    await home.copy(['apple']);
    final copied = home.l10n.homeCopiedSnackbar(1);
    await tester.tap(home.card('banana'), buttons: kSecondaryMouseButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(home.snackText(), copied);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await home.settle();
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('after a cut is pasted, Home no longer takes Esc', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    await home.addFolder('box');
    // 何も選ばず、クリップボードも空のときは、ホームはEscを取らない。
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isFalse);
    await home.cut(['apple']);
    await tester.tap(home.card('box'));
    await home.settleIo(3);
    await home.paste();
    await home.waitFor(
      () =>
          home.projects.projects.single.folderId ==
          home.projects.folders.single.id,
    );
    expect(home.pasteButton, findsNothing);
    expect(
      await tester.sendKeyEvent(LogicalKeyboardKey.escape),
      isFalse,
      reason: 'Home still took Esc to cancel a cut that was already pasted',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
