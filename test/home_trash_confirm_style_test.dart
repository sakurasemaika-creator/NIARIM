import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/widgets/project_trash_dialog.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';

/// ゴミ箱へ移す・完全に削除する確認は、どこから開いても同じ形（DISC124の
/// （2）の残り）：対象の名前を出し、「移動」は差し色（危険の赤にしない）、
/// 移せなかったときは中に理由を出して開いたまま。作品一覧・共有のフォルダの
/// 確認（︙のシート・右クリック）は名前の無い古い形で、ボタンが赤だった。
/// 選んで移す確認（作品一覧・共有）・書き出したファイルの完全削除の確認も
/// 名前が無かった。
///
/// あわせて（3）の残り：確認の文の数と単位（「プロジェクト2件」「2 items」）を
/// 行の途中で切らない（ja 360px・文字2倍で「…プロジェクト2 / 件も一緒に
/// 移動します。」と切れていた）。7言語・幅300〜440px・文字1.0/1.3/2.0。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  String plain(Text text) =>
      text.semanticsLabel ?? text.data ?? text.textSpan?.toPlainText() ?? '';

  List<String> textsIn(WidgetTester tester, Finder scope) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: scope,
        matching: find.byWidgetPredicate((widget) => widget is Text),
      ),
    ))
      plain(text).replaceAll(wordJoiner, ''),
  ];

  /// 開いている確認が、ほかの確認と同じ形か（名前・差し色の「移動」）。
  void expectLikeTheOthers(
    WidgetTester tester,
    String name,
    String where,
    List<String> problems,
  ) {
    final dialog = find.byType(AlertDialog);
    if (dialog.evaluate().isEmpty) {
      problems.add('$where: no question');
      return;
    }
    final texts = textsIn(tester, dialog);
    debugPrint('$where: $texts');
    if (!texts.contains(name)) problems.add('$where: the name is not shown');
    final scheme = Theme.of(tester.element(dialog)).colorScheme;
    final confirm = tester.widget<FilledButton>(
      find.descendant(of: dialog, matching: find.byType(FilledButton)).last,
    );
    final fill = confirm.style?.backgroundColor?.resolve({});
    if (fill != scheme.primary) {
      problems.add(
        '$where: the button is ${fill == scheme.error ? 'red (error)' : '$fill'}',
      );
    }
    if (find.byType(ProjectTrashDialog).evaluate().isEmpty) {
      problems.add('$where: not the shared trash question');
    }
  }

  Future<void> cancel(HomeClipboardHarness home) async {
    final l10n = home.l10n;
    await home.tester.tap(find.text(l10n.commonCancel).last);
    await home.settle();
  }

  testWidgets('a works folder and a received folder ask like the others, '
      'from the ︙ sheet and from a right click', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_1.gif', 'clip_2.gif'],
    );
    final l10n = home.l10n;
    final folders = tester
        .element(find.byType(HomeScreen))
        .read<WorkFolderService>();
    final clips = (await tester.runAsync(() async {
      final folder = await folders.createFolder('Clips');
      await folders.moveFileToFolder('clip_1.gif', folder.id);
      return folder;
    }))!;
    final inbox = (await tester.runAsync(
      () => home.projects.createSharedFolder('Inbox'),
    ))!;
    await home.addReceived('gift', sharedFolderId: inbox.id);
    final problems = <String>[];
    for (final (tab, name, id) in [
      (1, 'Clips', clips.id),
      (2, 'Inbox', inbox.id),
    ]) {
      await home.showTab(tab);
      final card = find.byKey(ValueKey('collectionFolder_$id'));
      expect(card, findsOneWidget, reason: name);
      // ︙のシート。
      await tester.tap(
        find.descendant(of: card, matching: find.byIcon(Icons.more_vert)),
      );
      await home.settle();
      await tester.tap(find.text(l10n.homeMoveToTrash).last);
      await home.settle();
      expectLikeTheOthers(tester, name, '$name sheet', problems);
      await cancel(home);
      // 右クリック。
      await tester.tap(
        find.descendant(of: card, matching: find.text(name)).first,
        buttons: kSecondaryMouseButton,
      );
      await home.settle();
      await tester.tap(find.text(l10n.homeMoveToTrash).last);
      await home.settle();
      expectLikeTheOthers(tester, name, '$name right click', problems);
      await cancel(home);
    }
    // 移すと、フォルダは一覧から消える（作品一覧のフォルダ）。
    await home.showTab(1);
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('collectionFolder_${clips.id}')),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await home.settle();
    await tester.tap(find.text(l10n.homeMoveToTrash).last);
    await home.settle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await home.waitFor(
      () => folders.folders.isEmpty,
      reason: 'the works folder was not moved',
    );
    await home.settleIo(2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
    expect(problems, isEmpty);
  });

  testWidgets('moving a selection on the works tab and deleting a file for '
      'good name what they act on', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_1.gif', 'clip_2.gif'],
    );
    final l10n = home.l10n;
    await home.showTab(1);
    final problems = <String>[];
    await tester.longPress(find.text('clip_1.gif').first);
    await home.settle();
    await tester.tap(find.text('clip_2.gif').first);
    await home.settle();
    await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
    await home.settle();
    for (final name in ['clip_1.gif', 'clip_2.gif']) {
      expectLikeTheOthers(tester, name, 'selection', problems);
    }
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await home.waitFor(
      () => find.text('clip_1.gif').evaluate().isEmpty,
      reason: 'the selection was not moved',
    );
    await home.settleIo(2);
    // ゴミ箱で、書き出したファイルを完全に削除する確認。
    await home.showTab(3);
    final delete = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'trash-delete-local-',
          ),
    );
    await home.waitFor(
      () => delete.evaluate().length == 2,
      reason: 'the Trash does not list the two files',
    );
    await tester.tap(delete.first);
    await home.settle();
    final dialog = find.byType(AlertDialog);
    final texts = textsIn(tester, dialog);
    debugPrint('delete for good: $texts');
    if (!texts.any((t) => t == 'clip_1.gif' || t == 'clip_2.gif')) {
      problems.add('delete for good: the file is not named');
    }
    if (find.byType(ProjectTrashDialog).evaluate().isEmpty) {
      problems.add('delete for good: not the shared question');
    }
    await cancel(home);
    expect(tester.takeException(), isNull);
    await home.close();
    expect(problems, isEmpty);
  });

  /// [scope]の中の段落で、数とそのすぐ後の単位の間で行が変わっている所。
  /// 漢字・かな・ハングルの言語は空白なしで続く字（「2件」「10秒」「2개」）、
  /// 空白を挟む言語は次の語（「2 items」）。CJKの数の後の空白（「7:43 更新」）
  /// は語の区切りなので数えない。
  List<String> splitCounts(
    WidgetTester tester,
    Finder scope,
    String where,
    String language,
  ) {
    final spaced = const ['en', 'es', 'fr'].contains(language);
    final problems = <String>[];
    for (final element
        in find
            .descendant(
              of: scope,
              matching: find.byType(RichText),
              matchRoot: true,
            )
            .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      if (!paragraph.attached || paragraph.size.isEmpty) continue;
      final lines = ParagraphLines(paragraph);
      final text = lines.visible;
      for (final match in RegExp(
        spaced
            ? r'(?<!\d)\d+(?:[.,]\d+)*[ \u00a0]\p{L}'
            : r'(?<!\d)\d+(?:[.,]\d+)*\p{L}',
        unicode: true,
      ).allMatches(text)) {
        // 数の最後の字から単位の最初の字まで。
        if (lines.breaksWithin(match.start, match.end).isNotEmpty) {
          problems.add('$where 「${match[0]}」: ${lines.lines.join(' / ')}');
        }
      }
    }
    return problems;
  }

  // 詳細表示の行の2行目（「12fps · 10秒」）も、数と単位の間で折り返さない
  // （ja 360pxで「…12fps · 10 / 秒」と切れていた。ゴミ箱の行は（3）で直した）。
  for (final language in languages) {
    testWidgets('the detail view keeps numbers with their units ($language)', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        realFonts: true,
        size: const Size(360, 900),
        prefs: {'home.projectViewMode.v1': 'detail'},
      );
      await tester.runAsync(() async {
        final project = await home.projects.createProject(
          name: 'Storyboard for the opening scene',
          fps: 12,
          durationSeconds: 10,
          backgroundColor: 0xFFFFFFFF,
        );
        await home.projects.saveProject(project.id);
      });
      await home.settleIo(2);
      final problems = <String>[];
      var checked = 0;
      for (final scale in [1.0, 1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (var width = 300.0; width <= 440; width += 10) {
          tester.view.physicalSize = Size(width, 900);
          await home.settle();
          final rows = find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                RegExp(r'\d+(?:fps|ips)').hasMatch(
                  w.text
                      .toPlainText(includeSemanticsLabels: false)
                      .replaceAll(wordJoiner, ''),
                ),
          );
          checked += rows.evaluate().length;
          problems.addAll(
            splitCounts(tester, rows, '${width}px x$scale', language),
          );
          expect(tester.takeException(), isNull);
        }
      }
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      debugPrint('$language: $checked rows checked, ${problems.length} split');
      for (final problem in problems.take(4)) {
        debugPrint('  $problem');
      }
      expect(checked, greaterThan(0));
      expect(problems, isEmpty);
      await home.close();
    });
  }

  for (final language in languages) {
    testWidgets('trash questions keep numbers with their units ($language)', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        realFonts: true,
        size: const Size(360, 900),
      );
      final l10n = home.l10n;
      // 作品2件とフォルダ1つが入ったフォルダ。
      final box = await home.addFolder('Storyboards');
      final inner = await home.addFolder('Inner', parentId: box.id);
      await home.addWork('Hotel', folderId: box.id);
      await home.addWork('Echo', folderId: inner.id);
      await home.addWork('Lima');
      await home.addWork('Kilo');
      final problems = <String>[];
      var checked = 0;
      Future<void> sweep(String where) async {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (var width = 300.0; width <= 440; width += 20) {
            tester.view.physicalSize = Size(width, 900);
            await home.settle();
            final dialog = find.byType(AlertDialog);
            expect(dialog, findsOneWidget, reason: where);
            checked++;
            problems.addAll(
              splitCounts(
                tester,
                dialog,
                '$where ${width}px x$scale',
                language,
              ),
            );
            expect(tester.takeException(), isNull);
          }
        }
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        tester.view.physicalSize = const Size(360, 900);
        await home.settle();
      }

      // フォルダのメニューから。
      await home.chooseFromCardMenu('Storyboards', l10n.homeMoveToTrash);
      await home.settle();
      await sweep('folder menu');
      await cancel(home);
      // 選んで移す（作品2件）。
      await home.select(['Lima', 'Kilo']);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await home.settle();
      await sweep('selection');
      await cancel(home);
      debugPrint(
        '$language: $checked layouts checked, ${problems.length} split',
      );
      for (final problem in problems.take(6)) {
        debugPrint('  $problem');
      }
      expect(problems, isEmpty);
      await home.close();
    });
  }
}
