// ホームの「貼り付けたものをゴミ箱へ移す」「ゴミ箱から戻す」確認の文が、
// 韓国語の語（空白で区切った単位）の途中で行を変えない（DISC188）。
//
// ほかのゴミ箱へ移す・削除する確認の文はDISC171で`messageText`にしたが、
// ホームのこの2つの確認の問い（とお気に入りを残す断り書き）は普通の`Text`の
// ままで、韓国語・320px・文字2倍で「다음 작품과 폴더를 휴지통 / 으로 …」と
// 語の途中で切れた。1行に入る語は途中で折らず（入らない長い語だけは字の間で
// 折る）、読み上げは元の文のまま。本物のホーム（起動処理とNiarimApp）で
// 2つの確認を開き、7言語×320/360/412px×文字1.0/1.3/2.0で、語の途中の
// 折り返し・はみ出しが無いことを見張る。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';

import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

const _height = 740.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 開いている確認[dialog]を、幅と文字の大きさを変えながら調べる。
  Future<List<String>> sweep(
    HomeClipboardHarness home,
    Finder dialog,
    String where,
  ) async {
    final tester = home.tester;
    final problems = <String>[];
    final errors = <String>[];
    final onError = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    try {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.view.physicalSize = Size(width, _height);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final at = '$where ${width.toInt()}px x$scale';
          expect(dialog, findsOneWidget, reason: at);
          for (final paragraph in textParagraphsIn(dialog)) {
            for (final broken in wordsBrokenThatFit(paragraph)) {
              problems.add('$at: $broken');
            }
          }
          for (final error in errors) {
            problems.add('$at: $error');
          }
          errors.clear();
        }
      }
    } finally {
      FlutterError.onError = onError;
    }
    tester.view.physicalSize = const Size(360, _height);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return problems;
  }

  Future<void> cancel(HomeClipboardHarness home, Finder dialog) async {
    await home.tester.tap(
      find.descendant(of: dialog, matching: find.text(home.l10n.commonCancel)),
    );
    await home.settle();
    expect(dialog, findsNothing);
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final language = tag.replaceAll('-', '_');
    final korean = locale.languageCode == 'ko';

    testWidgets('the paste-to-trash and restore questions break only between '
        'words ($tag)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        size: const Size(360, _height),
        realFonts: true,
      );
      final l10n = home.l10n;
      final moved = korean ? '애니메이션 연습' : 'Storyboard practice';
      final kept = korean ? '즐겨찾기 작품' : 'Favorite storyboard';
      final work = await home.addWork(moved);
      final favorite = await home.addWork(kept);
      await tester.runAsync(() => home.projects.setFavorite(favorite.id, true));
      await home.settleIo(2);
      final problems = <String>[];

      // ゴミ箱のタブへ貼り付ける確認（お気に入りは移さずに残す断り書きも）。
      await home.copy([moved, kept]);
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      final paste = find.byKey(const Key('homePasteToTrashDialog'));
      expect(paste, findsOneWidget);
      expect(
        find.descendant(
          of: paste,
          matching: find.text(l10n.homePasteToTrashKeepsFavorites),
        ),
        findsOneWidget,
      );
      problems.addAll(await sweep(home, paste, 'paste to trash'));
      await cancel(home, paste);

      // ゴミ箱のカードの「復元」で戻す確認。
      await tester.runAsync(() => home.projects.deleteProject(work.id));
      await home.settleIo(3);
      await home.showTab(0);
      await home.showTab(3);
      final restoreButton = find.byKey(ValueKey('trash-restore-${work.id}'));
      await tester.ensureVisible(restoreButton);
      await home.settle();
      await tester.tap(restoreButton);
      await home.settle();
      final restore = find.byKey(const Key('homeTrashRestoreConfirmation'));
      expect(restore, findsOneWidget);
      problems.addAll(await sweep(home, restore, 'restore'));
      await cancel(home, restore);

      for (final problem in problems.take(12)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  // 韓国語の確認の問いは、描く文では語をつなぐが、読み上げは元の文のまま。
  testWidgets('a Korean question is read as the plain sentence', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final home = await HomeClipboardHarness.open(
      tester,
      language: 'ko',
      size: const Size(320, _height),
      textScale: 2,
      realFonts: true,
    );
    final l10n = home.l10n;
    final work = await home.addWork('애니메이션 연습');
    await tester.runAsync(() => home.projects.deleteProject(work.id));
    await home.settleIo(3);
    await home.showTab(3);
    final restoreButton = find.byKey(ValueKey('trash-restore-${work.id}'));
    await tester.ensureVisible(restoreButton);
    await home.settle();
    await tester.tap(restoreButton);
    await home.settle();
    final restore = find.byKey(const Key('homeTrashRestoreConfirmation'));
    final question = l10n.homeRestoreFromTrashQuestion;
    final body = textParagraphsIn(
      restore,
    ).firstWhere((p) => ParagraphLines(p).visible == question);
    expect(ParagraphLines(body).lines.length, greaterThan(1));
    expect(wordsBrokenThatFit(body), isEmpty);
    expect(find.bySemanticsLabel(question), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(wordJoiner)),
      findsNothing,
      reason: 'a screen reader would read the word joiners',
    );
    await cancel(home, restore);
    await home.close();
    handle.dispose();
  });
}
