import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/screens/project/project_detail_screen.dart';

import 'helpers/home_clipboard_harness.dart';

/// ホームまわりの小さな食い違い（DISC124の（8）（9））を本物のアプリで
/// 確かめる。
/// （8）プロジェクト詳細から複製しても何も出なかった。複製したら、できた
///     複製の名前を知らせる（ホームの作品のメニューの「複製」も同じ知らせ）。
/// （9）作品一覧のタブで2つ以上選ぶと、切り取り・コピーが説明なしに押せ
///     なかった。押せない理由を吹き出し・読み上げで伝え、押したら知らせる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 書き換えた後にだけある文（直す前のアプリでは呼べない）。
  String duplicated(AppLocalizations l10n, String name) =>
      (l10n as dynamic).projectDuplicatedSnackbar(name) as String;
  String oneAtATime(AppLocalizations l10n) =>
      (l10n as dynamic).homeSelectionOneAtATime as String;

  testWidgets('(8) duplicating from Project Detail says the copy\'s name', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    await tester.tap(home.card('apple'));
    await home.waitFor(
      () => find.byType(ProjectDetailScreen).evaluate().isNotEmpty,
      reason: 'Project Detail did not open',
    );
    await home.settleIo(2);
    final l10n = home.l10n;
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await home.settle();
    await tester.tap(find.text(l10n.themeDuplicateAction).last);
    await home.waitFor(() => home.projects.projects.length == 2);
    final copy = home.projects.projects.firstWhere((p) => p.name != 'apple');
    await home.waitFor(() => home.snackText() != null);
    expect(home.snackText(), duplicated(l10n, copy.name));
    expect(find.byType(ProjectDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('(8) the Home card menu duplicate says the same', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('apple');
    final l10n = home.l10n;
    await home.chooseFromCardMenu('apple', l10n.themeDuplicateAction);
    await home.waitFor(() => home.projects.projects.length == 2);
    final copy = home.projects.projects.firstWhere((p) => p.name != 'apple');
    await home.waitFor(() => home.snackText() != null);
    expect(home.snackText(), duplicated(l10n, copy.name));
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('(9) with two exported works selected, cut and copy explain '
      'why they cannot be pressed', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['first.gif', 'second.gif'],
    );
    await home.showTab(1);
    await tester.longPress(find.text('first.gif').first);
    await home.settle();
    await tester.tap(find.text('second.gif').first);
    await home.settle();
    final l10n = home.l10n;
    final reason = oneAtATime(l10n);
    // 吹き出し（長押し・ホバー）は理由。
    final explained = find.byTooltip(reason);
    expect(explained, findsNWidgets(2), reason: 'cut and copy say nothing');
    // 読み上げは操作の名前と理由。
    final handle = tester.ensureSemantics();
    for (final label in [l10n.commonCut, l10n.commonCopy]) {
      expect(
        find.bySemanticsLabel(label),
        findsWidgets,
        reason: '$label is not named for screen readers',
      );
    }
    final hints = <String>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (data.hint.isNotEmpty) hints.add('${data.label}: ${data.hint}');
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.getSemantics(find.byType(Scaffold).first));
    expect(hints, contains('${l10n.commonCut}: $reason'));
    expect(hints, contains('${l10n.commonCopy}: $reason'));
    handle.dispose();
    // 押すと理由を知らせ、何も切り取らない・コピーしない。
    await tester.tap(explained.first);
    await home.settle();
    expect(home.snackText(), reason);
    expect(home.pasteButton, findsNothing);
    // 1つだけ選べば押せる。
    await tester.tap(find.text('second.gif').first);
    await home.settle();
    expect(find.byTooltip(reason), findsNothing);
    expect(find.byTooltip(l10n.commonCopy), findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // 読み上げ（TalkBack・スイッチ操作）で押しても、指・キーボードで押した
  // ときと同じ理由を知らせる。以前は読み上げの部品に押す操作が無く、
  // 「ボタン」と読むのに押しても何も起きなかった。
  testWidgets('(9) a screen reader\'s press on cut and copy also explains', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['first.gif', 'second.gif'],
    );
    await home.showTab(1);
    await tester.longPress(find.text('first.gif').first);
    await home.settle();
    await tester.tap(find.text('second.gif').first);
    await home.settle();
    final l10n = home.l10n;
    final reason = oneAtATime(l10n);
    final handle = tester.ensureSemantics();
    for (final label in [l10n.commonCut, l10n.commonCopy]) {
      final node = find.semantics.byPredicate(
        (node) =>
            node.getSemanticsData().label == label &&
            node.getSemanticsData().hint == reason,
        describeMatch: (_) => '$label with the reason',
      );
      expect(node, findsOne);
      final data = node.evaluate().single.getSemanticsData();
      debugPrint(
        '$label: tap=${data.hasAction(SemanticsAction.tap)} '
        'button=${data.flagsCollection.isButton} '
        'enabled=${data.flagsCollection.isEnabled}',
      );
      expect(
        data.hasAction(SemanticsAction.tap),
        isTrue,
        reason: '$label cannot be pressed by a screen reader',
      );
      tester.semantics.tap(node);
      await home.settle();
      expect(home.snackText(), reason, reason: '$label said nothing');
      // 何も切り取らない・コピーしない。
      expect(home.pasteButton, findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await home.settle();
    }
    handle.dispose();
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // ゴミ箱のタブでは切り取りはいつも押せない（ゴミ箱からは切り取らない）。
  // 以前は説明なしに押せないだけだった。1つ選んでも切り取りは理由を
  // 出し（戻すときは「復元」）、2つ以上選ぶとコピーも理由を出す（ほかの
  // タブの「切り取り・コピーは1件ずつ」は、ゴミ箱では切り取りの所が違う）。
  testWidgets('(9) on the Trash tab, cut explains why it never works, and '
      'copy explains with two selected', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final apple = await home.addWork('apple');
    final pear = await home.addWork('pear');
    await tester.runAsync(() async {
      await home.projects.deleteProject(apple.id);
      await home.projects.deleteProject(pear.id);
    });
    await home.settleIo(2);
    await home.showTab(3);
    final l10n = home.l10n;
    await tester.longPress(find.text('apple').first);
    await home.settle();
    // 押せない切り取りの吹き出し（長押し・ホバー）が、操作の名前だけでなく
    // 押せない理由になっている。
    final tooltips = [
      for (final tooltip in tester.widgetList<Tooltip>(
        find.descendant(
          of: find.byType(HomeSelectionToolbar),
          matching: find.byType(Tooltip),
        ),
      ))
        tooltip.message,
    ];
    debugPrint('Trash selection bar tooltips: $tooltips');
    expect(
      tooltips,
      isNot(contains(l10n.commonCut)),
      reason: 'cut is unavailable in the Trash without a reason',
    );
    final cutReason =
        (l10n as dynamic).homeTrashCutUnavailable(l10n.commonRestore) as String;
    final copyReason = (l10n as dynamic).homeTrashCopyOneAtATime as String;
    // 1つだけ：切り取りは理由、コピーは押せる。
    expect(
      find.byTooltip(cutReason),
      findsOneWidget,
      reason: 'cut says nothing in the Trash',
    );
    expect(find.byTooltip(l10n.commonCopy), findsOneWidget);
    await tester.tap(find.byTooltip(cutReason));
    await home.settle();
    expect(home.snackText(), cutReason);
    expect(home.pasteButton, findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await home.settle();
    // 2つ：コピーも理由（ゴミ箱の言い方）。
    await tester.tap(find.text('pear').first);
    await home.settle();
    expect(find.byTooltip(cutReason), findsOneWidget);
    expect(
      find.byTooltip(copyReason),
      findsOneWidget,
      reason: 'copy does not explain in the Trash',
    );
    await tester.tap(find.byTooltip(copyReason));
    await home.settle();
    expect(home.snackText(), copyReason);
    expect(home.pasteButton, findsNothing);
    // 読み上げでも、名前と理由。
    final handle = tester.ensureSemantics();
    for (final (label, reason) in [
      (l10n.commonCut, cutReason),
      (l10n.commonCopy, copyReason),
    ]) {
      expect(
        find.semantics.byPredicate(
          (node) =>
              node.getSemanticsData().label == label &&
              node.getSemanticsData().hint == reason,
          describeMatch: (_) => '$label with the reason',
        ),
        findsOne,
      );
    }
    handle.dispose();
    expect(home.projects.trash, hasLength(2));
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
