import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';

/// ホームの、ゴミ箱へ移すか確かめるダイアログの「移す」ボタンは、見出しと
/// 同じ「ゴミ箱へ移動」（仏語「Mettre à la corbeille」）。以前はどの確認でも
/// ボタンが`commonMove`（「移動」、仏語「Déplacer」）で、見出しは「ゴミ箱へ」
/// なのにボタンはフォルダへの移動と同じ言葉だった（DISC136）。
///
/// ホームの確認をすべて本物の画面から開く：プロジェクトのタブの選択中の
/// バー・フォルダのメニュー・ゴミ箱のタブへの貼り付け、作品一覧のファイル・
/// フォルダのメニューと選択中のバー、共有の受け取った作品・フォルダの
/// メニュー・作成した共有ファイルのメニューと選択中のバー。どれも320px・
/// 文字2倍で、ボタンの文字が欠けず（はみ出さず、語の途中で折れず）、
/// ボタンが画面とダイアログの中に収まること。7言語。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  const screen = Size(320, 720);

  /// 描いた文（語結合子を除き、改行しない空白を普通の空白にした文）。
  String shownText(ParagraphLines lines) =>
      lines.visible.replaceAll('\u00a0', ' ');

  /// 途中で行を変えてはいけない語。空白で区切る言語（韓国語も）は空白の
  /// 間の語、日本語・中国語は「ゴミ箱へ移動」の名詞と動詞。
  List<String> unitsOf(String language, String text) => switch (language) {
    'ja' => ['ゴミ箱', '移動'],
    'zh' => ['回收站'],
    'zh_Hant' => ['垃圾桶'],
    _ => [for (final m in RegExp(r'\S+').allMatches(text)) m[0]!],
  };

  /// [paragraph]の中で、行の途中で切れている[units]の語。
  List<String> splitUnits(RenderParagraph paragraph, List<String> units) {
    final lines = ParagraphLines(paragraph);
    final text = shownText(lines);
    final split = <String>[];
    var from = 0;
    for (final unit in units) {
      final at = text.indexOf(unit, from);
      if (at < 0) continue;
      from = at + unit.length;
      if (lines.breaksWithin(at, at + unit.length).isNotEmpty) split.add(unit);
    }
    return split;
  }

  for (final language in languages) {
    testWidgets('every trash confirm on Home says the trash verb and the '
        'label fits at 320px and text 2.0 ($language)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        size: screen,
        textScale: 2,
        realFonts: true,
        exports: ['clip_1.gif', 'clip_2.gif', 'clip_3.gif'],
      );
      final l10n = home.l10n;
      final verb = l10n.homeMoveToTrash;
      // 確かめた確認と、その問題（無ければ空）。
      final problems = <String, List<String>>{};

      /// いま開いている確認の、ボタンの文字・見出し・収まり方を確かめる。
      void check(String where, Finder dialog, Finder confirm) {
        final found = <String>[];
        expect(dialog, findsOneWidget, reason: '$where: no question');
        expect(confirm, findsOneWidget, reason: '$where: no confirm button');
        final labelFinder = find
            .descendant(of: confirm, matching: find.byType(RichText))
            .first;
        final label = tester.renderObject<RenderParagraph>(labelFinder);
        final labelLines = ParagraphLines(label);
        final text = shownText(labelLines);
        // 見出しは、ダイアログの中で最初に描かれている文。
        final title = tester.renderObject<RenderParagraph>(
          find.descendant(of: dialog, matching: find.byType(RichText)).first,
        );
        final titleLines = ParagraphLines(title);
        final titleText = shownText(titleLines);
        if (text != verb) found.add('button 「$text」, expected 「$verb」');
        if (titleText != text) {
          found.add('title 「$titleText」 vs button 「$text」');
        }
        // 収まり方：文字は行数の上限を超えず、ボタンの中に、ボタンは
        // ダイアログと画面の中に。語の途中で行を変えない（見出しも）。
        if (label.didExceedMaxLines) found.add('label is cut');
        final labelBox = tester.getRect(labelFinder);
        final buttonBox = tester.getRect(confirm);
        final dialogBox = tester.getRect(
          find.descendant(of: dialog, matching: find.byType(Material)).first,
        );
        bool inside(Rect inner, Rect outer) =>
            inner.left >= outer.left - 0.5 &&
            inner.right <= outer.right + 0.5 &&
            inner.top >= outer.top - 0.5 &&
            inner.bottom <= outer.bottom + 0.5;
        if (!inside(labelBox, buttonBox)) {
          found.add('label $labelBox outside the button $buttonBox');
        }
        if (!inside(buttonBox, dialogBox)) {
          found.add('button $buttonBox outside the dialog $dialogBox');
        }
        if (!inside(buttonBox, Offset.zero & screen)) {
          found.add('button $buttonBox off the screen');
        }
        for (final unit in splitUnits(label, unitsOf(language, verb))) {
          found.add('button: 「$unit」 is split over lines');
        }
        for (final unit in splitUnits(title, unitsOf(language, verb))) {
          found.add('title: 「$unit」 is split over lines');
        }
        debugPrint(
          '$language $where: 「${labelLines.lines.join(' / ')}」 '
          '(${labelBox.width.toStringAsFixed(1)} of '
          '${buttonBox.width.toStringAsFixed(1)}px), '
          'title 「${titleLines.lines.join(' / ')}」',
        );
        problems[where] = found;
      }

      Future<void> cancel() async {
        final button = find.byKey(const Key('trash-dialog-cancel'));
        if (button.evaluate().isNotEmpty) {
          await tester.tap(button);
        } else {
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(l10n.commonCancel),
            ),
          );
        }
        await home.settle();
        expect(find.byType(AlertDialog), findsNothing);
      }

      Future<void> checkTrashDialog(String where) async {
        await home.waitFor(
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
          reason: '$where: no confirmation',
        );
        await home.settle();
        check(
          where,
          find.byType(AlertDialog),
          find.byKey(const Key('trash-dialog-confirm')),
        );
        await cancel();
      }

      /// [of]（カード・フォルダの行）の中のメニューを開いて[label]を選ぶ。
      Future<void> chooseInMenu(Finder menu, String label) async {
        await tester.ensureVisible(menu);
        await home.settle();
        await tester.tap(menu);
        await home.settle();
        await tester.tap(find.text(label).last);
        await home.settle();
      }

      Future<void> deselectAll() async {
        await tester.tap(find.byTooltip(l10n.homeSelectionAllDeselect));
        await home.settle();
      }

      // プロジェクトのタブ。
      await home.addWork('apple');
      final box = await home.addFolder('box');
      await home.addWork('pear', folderId: box.id);
      // 選んだときのバー。
      await home.select(['apple']);
      await tester.tap(find.byTooltip(verb));
      await checkTrashDialog('projects: selection bar');
      await deselectAll();
      // フォルダのメニュー（右クリック）。
      await tester.ensureVisible(home.card('box').first);
      await home.settle();
      await tester.tap(home.card('box').first, buttons: kSecondaryMouseButton);
      await home.settle();
      await tester.tap(find.text(verb).last);
      await checkTrashDialog('projects: folder menu');
      // ゴミ箱のタブへの貼り付け。
      await home.copy(['apple']);
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      check(
        'trash: paste',
        find.byKey(const Key('homePasteToTrashDialog')),
        find.byKey(const Key('homePasteTrashConfirmButton')),
      );
      await cancel();
      await tester.tap(home.clearButton);
      await home.settle();

      // 作品一覧のタブ。
      final folders = tester
          .element(find.byType(HomeScreen))
          .read<WorkFolderService>();
      final clips = (await tester.runAsync(() async {
        final folder = await folders.createFolder('Clips');
        await folders.moveFileToFolder('clip_3.gif', folder.id);
        return folder;
      }))!;
      await home.showTab(1);
      await chooseInMenu(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('clip_1.gif'),
                matching: find.byType(ExportedWorkCard),
              )
              .first,
          matching: find.byType(PopupMenuButton<String>),
        ),
        verb,
      );
      await checkTrashDialog('works: file menu');
      await chooseInMenu(
        find.descendant(
          of: find.byKey(ValueKey('collectionFolder_${clips.id}')),
          matching: find.byIcon(Icons.more_vert),
        ),
        verb,
      );
      await checkTrashDialog('works: folder menu');
      await tester.ensureVisible(find.text('clip_1.gif').first);
      await home.settle();
      await tester.longPress(find.text('clip_1.gif').first);
      await home.settle();
      await tester.tap(find.byTooltip(verb));
      await checkTrashDialog('works: selection bar');
      await deselectAll();

      // 共有のタブ：受け取ったもの。
      final inbox = (await tester.runAsync(
        () => home.projects.createSharedFolder('Inbox'),
      ))!;
      final gift = await home.addReceived('gift');
      await home.addReceived('parcel', sharedFolderId: inbox.id);
      await home.showTab(2);
      await chooseInMenu(
        find.byKey(ValueKey('receivedShareMenu_${gift.id}')),
        l10n.projectDetailTrashMenuItem,
      );
      await checkTrashDialog('shared: received work menu');
      await chooseInMenu(
        find.descendant(
          of: find.byKey(ValueKey('collectionFolder_${inbox.id}')),
          matching: find.byIcon(Icons.more_vert),
        ),
        verb,
      );
      await checkTrashDialog('shared: received folder menu');
      await tester.ensureVisible(find.text('gift').first);
      await home.settle();
      await tester.longPress(find.text('gift').first);
      await home.settle();
      await tester.tap(find.byTooltip(verb));
      await checkTrashDialog('shared: selection bar');
      await deselectAll();
      // 作成した共有ファイル。
      final share = File(
        '${home.dir.path}/niarim/shared/outgoing/mine_share.niashare',
      )..createSync(recursive: true);
      share.writeAsBytesSync(List.filled(64, 1));
      await tester.runAsync(() => home.projects.refreshOutgoingShares());
      await home.settleIo(2);
      await tester.ensureVisible(find.byKey(const Key('sharedOutgoingFilter')));
      await home.settle();
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await home.settleIo(2);
      await chooseInMenu(
        find.byKey(ValueKey('outgoingShareMenu_${share.path}')),
        l10n.projectDetailTrashMenuItem,
      );
      await checkTrashDialog('shared: created share menu');

      expect(problems, hasLength(10));
      expect(
        {
          for (final MapEntry(:key, :value) in problems.entries)
            if (value.isNotEmpty) key: value,
        },
        isEmpty,
        reason: 'a trash confirm does not say the trash verb or does not fit',
      );
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
