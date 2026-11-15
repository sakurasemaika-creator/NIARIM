import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/project/project_detail_screen.dart';
import 'package:niarim/widgets/menu_action_label.dart';

import 'helpers/home_clipboard_harness.dart';

/// ホームで同じ操作は、どのメニュー・ボタンでも同じ言葉と同じ色で出す。
/// ゴミ箱へ移す：作品のメニューは英語「Move to trash」・簡体字「移到回收站」・
/// 繁体字「移到垃圾桶」、フォルダのメニュー・選んだときのバー・確認の見出しは
/// 「Move to Trash」「移至回收站」「移至垃圾桶」と、言語によって2通りあった。
/// 完全に削除する：ゴミ箱のカードのボタンは「完全削除」なのに、確かめる
/// ダイアログのボタンは「削除」だった。メニューの「ゴミ箱へ移動」の色は、
/// どのメニューでも作品のカードのメニューと同じ（メニューの文字色と印の
/// アイコン。危険の色〔colorScheme.error〕は暗いメニューで読めなかった）。7言語。
/// ゴミ箱へ移すか確かめる文も、どの確認でも同じ言葉：ゴミ箱のタブへ貼り
/// 付けるときの確認だけが「ゴミ箱に捨てますか？」（韓国語「옮기시겠습니까」、
/// 英語は「the Trash」）で、見出しの「ゴミ箱へ移動」・ほかの確認の「ゴミ箱へ
/// 移動しますか？」と違った。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  String plain(Text text) =>
      (text.data ?? text.textSpan?.toPlainText() ?? '').replaceAll('⁠', '');

  /// いま開いているメニューの、最後の項目（どのメニューも「ゴミ箱へ移動」が
  /// 最後）の文字と、描いた色（項目名は MenuActionLabel で印のアイコンを
  /// 付け、色はメニューの項目の書式で決まる）。
  (String, Color?) lastMenuItem(WidgetTester tester) {
    final items = find.byWidgetPredicate((w) => w is PopupMenuItem<String>);
    final item = tester.widget<PopupMenuItem<String>>(items.last);
    final label = switch (item.child) {
      final MenuActionLabel m => m.label,
      final child => plain(child! as Text),
    };
    final painted = tester
        .renderObject<RenderParagraph>(
          find.descendant(of: items.last, matching: find.byType(RichText)).last,
        )
        .text
        .style
        ?.color;
    return (label.replaceAll('⁠', ''), painted);
  }

  /// [language]で、ゴミ箱へ移すか確かめる文が使う言葉（作品・フォルダを
  /// ゴミ箱へ移す確認〔homeMoveToTrashConfirm・projectListTrashFolderConfirmTitle〕
  /// と同じ動詞・言い方）。
  bool asksToMoveToTrash(String language, String text) => switch (language) {
    'ja' => text.endsWith('ゴミ箱へ移動しますか？'),
    'en' => RegExp(r'^Move .+ to the trash\?$').hasMatch(text),
    'es' => text.startsWith('¿Mover ') && text.contains('a la papelera'),
    'fr' =>
      text.startsWith('Mettre ') &&
          text.contains('à la corbeille') &&
          text.endsWith('\u202f?'),
    'ko' => text.endsWith('휴지통으로 이동하시겠습니까?'),
    'zh' => text.endsWith('移至回收站吗？'),
    'zh_Hant' => text.endsWith('移至垃圾桶嗎？'),
    _ => false,
  };

  Future<void> closeMenu(HomeClipboardHarness home) async {
    await home.tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await home.settle();
  }

  for (final language in languages) {
    testWidgets('one wording and one colour per action ($language)', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        exports: ['clip_1.gif'],
      );
      final l10n = home.l10n;
      final apple = await home.addWork('apple');
      await home.addFolder('box');
      final labels = <String, String>{};
      final colours = <String, Color?>{};
      void record(String where) {
        final (label, colour) = lastMenuItem(tester);
        labels[where] = label;
        colours[where] = colour;
      }

      // 作品のカードのメニュー（右クリック）。
      await tester.tap(
        home.card('apple').first,
        buttons: kSecondaryMouseButton,
      );
      await home.settle();
      record('work menu');
      await closeMenu(home);
      // フォルダのカードのメニュー。
      await tester.tap(home.card('box').first, buttons: kSecondaryMouseButton);
      await home.settle();
      record('folder menu');
      await closeMenu(home);
      // 選んだときのバー。
      await tester.longPress(home.card('apple').first);
      await home.settle();
      labels['selection bar'] = l10n.homeMoveToTrash;
      expect(find.byTooltip(l10n.homeMoveToTrash), findsOneWidget);
      await tester.tap(find.byTooltip(l10n.homeSelectionAllDeselect));
      await home.settle();
      // 書き出したファイルのメニュー（作品一覧）。
      await home.showTab(1);
      await tester.tap(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('clip_1.gif'),
                matching: find.byType(ExportedWorkCard),
              )
              .first,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await home.settle();
      record('file menu');
      await closeMenu(home);
      // プロジェクト詳細のメニュー。
      await home.showTab(0);
      await tester.tap(home.card('apple').first);
      await home.waitFor(
        () => find.byType(ProjectDetailScreen).evaluate().isNotEmpty,
        reason: 'Project Detail did not open',
      );
      await home.settleIo(2);
      await tester.tap(
        find
            .descendant(
              of: find.byType(AppBar).last,
              matching: find.byIcon(Icons.more_vert),
            )
            .last,
      );
      await home.settle();
      record('detail menu');
      await closeMenu(home);
      debugPrint('$language trash labels: $labels');
      expect(
        labels.values.toSet(),
        hasLength(1),
        reason: 'the same action has more than one name: $labels',
      );
      expect(
        colours.values.toSet(),
        hasLength(1),
        reason: 'the trash item has more than one colour: $colours',
      );
      // 完全に削除する：ゴミ箱のカードのボタンと確かめるボタン。
      appRouter.pop();
      await home.settleIo(3);
      await tester.runAsync(() => home.projects.deleteProject(apple.id));
      await home.settleIo(2);
      await home.showTab(3);
      final delete = find.byKey(ValueKey('trash-delete-${apple.id}'));
      final cardLabel = plain(
        tester.widget<Text>(
          find.descendant(of: delete, matching: find.byType(Text)),
        ),
      );
      await tester.tap(delete);
      await home.settle();
      final confirmLabel = plain(
        tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('trash-dialog-confirm')),
            matching: find.byType(Text),
          ),
        ),
      );
      debugPrint('$language delete for good: $cardLabel / $confirmLabel');
      expect(confirmLabel, cardLabel);
      await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
      await home.settle();
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  for (final language in languages) {
    testWidgets('one wording for the trash questions ($language)', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(tester, language: language);
      final l10n = home.l10n;
      await home.addWork('apple');
      await home.addFolder('box');
      final questions = <String, String>{};
      // 選んだ作品を選択中のバーの「ゴミ箱へ移動」で移すときの確認。
      await home.select(['apple']);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await home.settle();
      questions['work'] = l10n.homeMoveToTrashConfirm(1);
      expect(
        [
          for (final text in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byWidgetPredicate((widget) => widget is Text),
            ),
          ))
            plain(text),
        ],
        contains(questions['work']),
        reason: 'the work question is not shown',
      );
      await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
      await home.settle();
      // ゴミ箱のタブへ貼り付けるときの確認（見出しは「ゴミ箱へ移動」）。
      await tester.tap(find.byTooltip(l10n.homeSelectionAllDeselect));
      await home.settle();
      await home.copy(['apple', 'box']);
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      final dialog = find.byKey(const Key('homePasteToTrashDialog'));
      expect(dialog, findsOneWidget);
      final texts = [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: dialog,
            matching: find.byWidgetPredicate((widget) => widget is Text),
          ),
        ))
          plain(text),
      ];
      expect(texts.first, l10n.homeMoveToTrash);
      expect(texts, contains(l10n.homePasteToTrashQuestion));
      questions['paste'] = l10n.homePasteToTrashQuestion;
      questions['folder'] = l10n.projectListTrashFolderConfirmTitle;
      await tester.tap(
        find.descendant(of: dialog, matching: find.text(l10n.commonCancel)),
      );
      await home.settle();
      debugPrint('$language trash questions: $questions');
      expect(
        {
          for (final MapEntry(:key, :value) in questions.entries)
            if (!asksToMoveToTrash(language, value)) key: value,
        },
        isEmpty,
        reason: 'a trash question uses other words',
      );
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
