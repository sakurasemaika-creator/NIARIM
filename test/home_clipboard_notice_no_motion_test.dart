import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';

import 'helpers/home_clipboard_harness.dart';

// 読み上げ（TalkBack）・「動きを減らす」を使っているとき、役目を終えた
// コピー・切り取りの知らせを閉じても、貼り付けの結果や他の機能の知らせを
// 閉じない（DISC093・DISC092）。この設定では、入れ替えで取り下げた知らせは
// その場で取り除かれる。取り除いた知らせのScaffoldFeatureController.closeは、
// 次に出た別の知らせを閉じる（デバッグでは「_snackBars.first == controller」の
// アサーションで落ちる）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const frame = Duration(milliseconds: 16);

  const modes = {
    'TalkBack': FakeAccessibilityFeatures(accessibleNavigation: true),
    'reduce motion': FakeAccessibilityFeatures(disableAnimations: true),
  };

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

  for (final mode in modes.entries) {
    testWidgets('${mode.key}: pasting a cut keeps the paste result on screen', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = mode.value;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final home = await HomeClipboardHarness.open(tester);
      await home.addWork('apple');
      await home.addFolder('box');
      await home.cut(['apple']);
      expect(home.snackText(), home.l10n.homeCutSnackbar(1));
      await tester.tap(home.card('box'));
      await home.settleIo(3);
      await home.paste();
      final pasted = home.l10n.homePastedSnackbar(1);
      expect(home.pasteButton, findsNothing);
      expect(
        home.snackText(),
        pasted,
        reason: 'the paste result was closed with the cut notice',
      );
      // 結果は時間まで出ている（切り取りの知らせを閉じたつもりで、結果を
      // 閉じていない）。
      await tester.pump(const Duration(seconds: 2));
      expect(home.snackText(), pasted);
      final seen = await watchUntilGone(tester, home);
      debugPrint('${mode.key}: notices after the paste: $seen');
      expect(seen, [pasted, null]);
      expect(tester.takeException(), isNull);
      await home.close();
    });

    testWidgets('${mode.key}: pasting a copy into the Trash keeps the notice '
        'that waited behind the copy notice', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = mode.value;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final home = await HomeClipboardHarness.open(tester);
      await home.addWork('apple');
      await home.addWork('banana');
      await home.copy(['apple']);
      // 他の機能の知らせが、コピーの知らせの後ろで待つ。
      ScaffoldMessenger.of(
        tester.element(find.byType(HomeScreen)),
      ).showSnackBar(const SnackBar(content: Text('other feature notice')));
      await home.settle();
      expect(home.snackText(), home.l10n.homeCopiedSnackbar(1));
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
      await home.waitFor(() => home.projects.trash.length == 1);
      final pasted = home.l10n.homePastedSnackbar(1);
      final seen = await watchUntilGone(tester, home);
      debugPrint('${mode.key}: notices after pasting into the Trash: $seen');
      // 待っていた知らせが出切ってから、貼り付けの結果が出る（どちらも
      // 閉じられない）。
      expect(seen.where((t) => t != null), ['other feature notice', pasted]);
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  testWidgets('TalkBack: the waiting notice is shown for its whole time', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    await home.addWork('banana');
    await home.copy(['apple']);
    ScaffoldMessenger.of(tester.element(find.byType(HomeScreen))).showSnackBar(
      const SnackBar(
        content: Text('other feature notice'),
        duration: Duration(seconds: 3),
      ),
    );
    await home.settle();
    await home.showTab(3);
    await tester.tap(home.pasteButton);
    await home.settle();
    await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
    await home.waitFor(() => home.projects.trash.length == 1);
    // 待っていた知らせは、貼り付けの後も（3秒の途中で）出ている。
    expect(home.snackText(), 'other feature notice');
    await tester.pump(const Duration(milliseconds: 1500));
    expect(home.snackText(), 'other feature notice');
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
