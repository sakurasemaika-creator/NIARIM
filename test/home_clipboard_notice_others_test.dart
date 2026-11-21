import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';

import 'helpers/home_clipboard_harness.dart';

// コピー・切り取り・貼り付けの知らせは、ホーム自身の前の知らせだけを
// 入れ替え、他の機能の知らせ（ゴミ箱へ移した知らせとその「元に戻す」、
// 保存の失敗の知らせ等）は消さない（DISC092）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const frame = Duration(milliseconds: 16);

  void setTalkBack(WidgetTester tester, bool on) {
    if (!on) return;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<void> trashFromMenu(HomeClipboardHarness home, String name) async {
    await home.tester.tap(home.card(name), buttons: kSecondaryMouseButton);
    await home.settle();
    await home.tester.tap(find.text(home.l10n.projectDetailTrashMenuItem));
    final moved = home.l10n.homeMovedToTrashSnackbar(1);
    await home.waitFor(() => home.snackText() == moved);
    await home.settle();
  }

  /// 知らせが全部消えるまで1フレームずつ描き、出た知らせを出た順に返す。
  Future<List<String?>> watchUntilGone(
    WidgetTester tester,
    HomeClipboardHarness home, {
    Duration limit = const Duration(seconds: 20),
  }) async {
    final seen = <String?>[home.snackText()];
    var elapsed = Duration.zero;
    while (find.byType(SnackBar).evaluate().isNotEmpty && elapsed < limit) {
      await tester.pump(frame);
      elapsed += frame;
      final text = home.snackText();
      if (seen.last != text) seen.add(text);
    }
    return seen;
  }

  for (final talkBack in [false, true]) {
    for (final cut in [false, true]) {
      final kind = cut ? 'cut' : 'copy';
      testWidgets('a $kind leaves the moved-to-Trash notice and its Undo '
          '(TalkBack ${talkBack ? 'on' : 'off'})', (tester) async {
        setTalkBack(tester, talkBack);
        final home = await HomeClipboardHarness.open(tester);
        await home.addWork('apple');
        await home.addWork('banana');
        await trashFromMenu(home, 'banana');
        final moved = home.l10n.homeMovedToTrashSnackbar(1);
        if (cut) {
          await home.cut(['apple']);
        } else {
          await home.copy(['apple']);
        }
        await home.settle();
        expect(
          home.snackText(),
          moved,
          reason: 'the $kind took away the moved-to-Trash notice',
        );
        // 残った「元に戻す」は効く。
        await tester.tap(find.text(home.l10n.homeUndoAction).first);
        await home.waitFor(() => home.projects.projects.length == 2);
        expect(home.projects.trash, isEmpty);
        // コピー・切り取りの知らせは、その後で出る。
        final seen = await watchUntilGone(tester, home);
        debugPrint('notices after Undo: $seen');
        expect(
          seen,
          contains(
            cut
                ? home.l10n.homeCutSnackbar(1)
                : home.l10n.homeCopiedSnackbar(1),
          ),
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }

  // お気に入り等の保存に失敗した知らせが順番を待っているときに切り取っても、
  // 失敗の知らせを黙って下げない（失敗が伝わらなくなる）。
  for (final cut in [false, true]) {
    final kind = cut ? 'cut' : 'copy';
    testWidgets(
      'a $kind leaves the notice on screen and a waiting failure notice',
      (tester) async {
        final home = await HomeClipboardHarness.open(tester);
        await home.addWork('apple');
        final messenger = ScaffoldMessenger.of(
          tester.element(find.byType(HomeScreen)),
        );
        messenger.showSnackBar(const SnackBar(content: Text('first notice')));
        showProjectActionFailure(messenger, home.l10n, StateError('save'));
        await home.settle();
        expect(home.snackText(), 'first notice');
        if (cut) {
          await home.cut(['apple']);
        } else {
          await home.copy(['apple']);
        }
        expect(
          home.snackText(),
          'first notice',
          reason: 'the $kind took away the notice on screen',
        );
        final seen = await watchUntilGone(tester, home);
        debugPrint('notices after the $kind: $seen');
        expect(seen, contains(home.l10n.homeTrashOperationFailed));
        expect(
          seen,
          contains(
            cut
                ? home.l10n.homeCutSnackbar(1)
                : home.l10n.homeCopiedSnackbar(1),
          ),
        );
        expect(tester.takeException(), isNull);
        await home.close();
      },
    );
  }

  // ホーム自身の前の知らせは、待たせずに入れ替える（以前と同じ）。
  testWidgets('a second copy replaces the first copy notice at once', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    await home.addWork('banana');
    await home.copy(['apple', 'banana']);
    expect(home.snackText(), home.l10n.homeCopiedSnackbar(2));
    await home.select(['apple']);
    await tester.tap(find.byTooltip(home.l10n.commonCopy));
    var elapsed = Duration.zero;
    while (home.snackText() != home.l10n.homeCopiedSnackbar(1) &&
        elapsed < const Duration(seconds: 6)) {
      await tester.pump(frame);
      elapsed += frame;
    }
    debugPrint(
      'the second copy notice came ${elapsed.inMilliseconds} ms later',
    );
    expect(elapsed, lessThanOrEqualTo(const Duration(milliseconds: 700)));
    final seen = await watchUntilGone(tester, home);
    expect(seen, isNot(contains(home.l10n.homeCopiedSnackbar(2))));
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // Escで切り取りをやめると、順番を待っている切り取りの知らせだけを下げる。
  testWidgets('Esc on a cut whose notice waits behind others closes only it', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    final messenger = ScaffoldMessenger.of(
      tester.element(find.byType(HomeScreen)),
    );
    messenger
      ..showSnackBar(const SnackBar(content: Text('first notice')))
      ..showSnackBar(const SnackBar(content: Text('waiting notice')));
    await home.settle();
    await home.cut(['apple']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await home.settle();
    expect(home.pasteButton, findsNothing);
    final seen = await watchUntilGone(tester, home);
    debugPrint('notices after Esc: $seen');
    expect(seen.whereType<String>(), ['first notice', 'waiting notice']);
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
