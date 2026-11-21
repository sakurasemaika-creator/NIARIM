import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/utils/duplicate_name.dart'
    show copyMarkSplit, copyNameIn;
import 'package:niarim/utils/line_break.dart' show keepPartsTogether;

import 'helpers/copy_mark_breaks.dart';
import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';

/// 複製の名前の番号が印から離れて折り返さない（DISC123）：「Bravo (copy」/
/// 「2)」、「(コピー」/「2)」、「clip_4（副」/「本）.png」と折れていた。保存
/// する名前は変えず、描くときだけ印（と拡張子）を1つのかたまりにする。
/// ホームのカード（2行の名前）・詳細表示の行・ゴミ箱の行・作品一覧の
/// ファイル・確かめるダイアログで、7言語・幅320/360/412px・文字1.0/1.3/2.0。
/// 印が行に入らないときに折り返す順（拡張子の前→番号の前→印の語の中で
/// 両側に2字以上）と、長音・小書きの仮名を行の頭にしないことも見る
/// （[copyMarkBreakProblems]・[japaneseLineStartProblems]）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  const latin = 'Bravo Charlie Delta Echo Foxtrot';
  const cjk = '作品のテスト用にとても長い名前を付けました';
  const hangul = '애니메이션 만들기 연습 장면 테스트';
  // 長音・小書きの仮名を含む名前（行の頭に来ない）。
  const kanaHead = 'ファーストショットのチェック・カット';

  String poolFor(String language) => switch (language) {
    'ja' || 'zh' || 'zh_Hant' => cjk,
    'ko' => hangul,
    _ => latin,
  };

  /// [language]で作る複製の名前と、その印（印の前の名前の長さを変えて、
  /// 折り返す所を色々にする）。
  Map<String, String> copyNames(AppLocalizations l10n, String language) {
    final pool = poolFor(language).characters.toList();
    return {
      for (var length = 2; length <= 14; length += 2)
        for (final base in [pool.take(length).join().trim()])
          copyNameIn(l10n, base, 2): copyNameIn(
            l10n,
            base,
            2,
          ).substring(base.length).trim(),
    };
  }

  /// 書き出したファイルの複製の名前（拡張子の前に印）と、印と拡張子。
  Map<String, String> copyFiles(AppLocalizations l10n) {
    final mark = l10n.projectDuplicateName('\u0000').split('\u0000').last;
    return {
      for (var i = 1; i <= 6; i++)
        'clip_${'x' * i}$mark.png': '${mark.trim()}.png',
    };
  }

  /// 印（と拡張子）が途中で折れている所。印が1行に入らないほど幅が狭い
  /// 所は数えない。1行に入るかは、描くときと同じく印を1つのかたまり
  /// （字の間に語結合子）にした幅で見る（語結合子にも字の間隔が付くので、
  /// 素の印より少し広い。作品一覧の行の見張りと同じ測り方）。
  List<String> splitMarks(
    WidgetTester tester,
    Set<String> marks,
    String where,
  ) {
    final problems = <String>[];
    for (final element
        in find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      if (!paragraph.attached || paragraph.size.isEmpty) continue;
      final lines = ParagraphLines(paragraph);
      final text = lines.visible.replaceAll(' ', ' ');
      for (final mark in marks) {
        var at = text.indexOf(mark);
        while (at >= 0) {
          final painter = TextPainter(
            text: TextSpan(
              text: keepPartsTogether(mark, [mark]),
              style: (paragraph.text is TextSpan)
                  ? (paragraph.text as TextSpan).style
                  : null,
            ),
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
            locale: paragraph.locale,
          )..layout();
          final fits = painter.width <= paragraph.constraints.maxWidth;
          painter.dispose();
          if (fits && lines.breaksWithin(at, at + mark.length).isNotEmpty) {
            problems.add('$where 「$mark」: ${lines.lines.join(' / ')}');
          }
          at = text.indexOf(mark, at + 1);
        }
        // 印の中で折り返すときの順（拡張子の前→番号の前→語の中で2字以上）。
        if (text.contains(mark)) {
          problems.addAll(
            copyMarkBreakProblems(paragraph, mark, where: '$where 「$mark」'),
          );
        }
      }
      // 名前の長音・小書きの仮名は行の頭に来ない。
      if (text.contains(kanaHead)) {
        problems.addAll(
          japaneseLineStartProblems(
            paragraph,
          ).map((problem) => '$where $problem'),
        );
      }
    }
    return problems;
  }

  Future<void> checkAtScales(
    HomeClipboardHarness home,
    Set<String> marks,
    String where,
    List<String> problems,
  ) async {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        home.tester.view.physicalSize = Size(width, 2400);
        home.tester.platformDispatcher.textScaleFactorTestValue = scale;
        await home.settle();
        final at = '$where ${width}px x$scale';
        problems.addAll(splitMarks(home.tester, marks, at));
        expect(home.tester.takeException(), isNull, reason: at);
      }
    }
    home.tester.view.physicalSize = const Size(360, 2400);
    home.tester.platformDispatcher.textScaleFactorTestValue = 1;
    await home.settle();
  }

  for (final language in languages) {
    testWidgets('copy marks stay whole on Home ($language, 320–412px)', (
      tester,
    ) async {
      final problems = <String>[];
      for (final mode in ['small', 'detail']) {
        final home = await HomeClipboardHarness.open(
          tester,
          language: language,
          realFonts: true,
          size: const Size(360, 2400),
          prefs: {'home.projectViewMode.v1': mode},
        );
        final l10n = home.l10n;
        final named = copyNames(l10n, language);
        final names = named.keys.toList();
        final marks = named.values.toSet();
        for (final name in names) {
          await home.addWork(name);
        }
        final kana = copyNameIn(l10n, kanaHead, 2);
        await home.addWork(kana);
        marks.add(kana.substring(kanaHead.length).trim());
        final folder = await home.addFolder(names[3]);
        await home.settleIo(2);
        await checkAtScales(home, marks, '$language $mode projects', problems);
        // 保存した名前・読み上げ・文での検索は元の名前のまま。
        expect(home.projects.projects.map((p) => p.name).toSet(), {
          ...names,
          kana,
        });
        for (final name in names) {
          expect(home.card(name), findsWidgets, reason: name);
        }
        if (mode == 'detail') {
          // ゴミ箱の行。
          await tester.runAsync(() async {
            for (final project in home.projects.projects.toList()) {
              await home.projects.deleteProject(project.id);
            }
            await home.projects.moveFolderToTrash(folder.id);
          });
          await home.settleIo(2);
          await home.showTab(3);
          await checkAtScales(home, marks, '$language trash', problems);
          // 元に戻す確かめのダイアログ（ゴミ箱の作品を貼り付けて戻す前の
          // 確かめは名前を引いて出す）。完全削除の確かめは対象の名前を出す。
          await tester.tap(
            find.byKey(
              ValueKey(
                'trash-delete-${home.projects.trash.firstWhere((p) => p.name == names.last).id}',
              ),
            ),
          );
          await home.settle();
          await checkAtScales(home, marks, '$language delete dialog', problems);
          await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
          await home.settle();
        }
        await home.close();
      }
      // 作品一覧のファイル（拡張子の前に印）。
      final probe = lookupAppLocalizations(
        Locale.fromSubtags(
          languageCode: language.split('_').first,
          scriptCode: language == 'zh_Hant' ? 'Hant' : null,
        ),
      );
      final files = copyFiles(probe);
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        realFonts: true,
        size: const Size(360, 2400),
        exports: files.keys.toList(),
      );
      await home.showTab(1);
      final fileMarks = files.values.toSet();
      await checkAtScales(home, fileMarks, '$language works', problems);
      expect(find.byType(HomeScreen), findsOneWidget);
      await home.close();
      debugPrint('$language: ${problems.length} split marks');
      expect(problems, isEmpty);
    });
  }

  // ゴミ箱のフォルダの行は、中の作品の名前を3行目に並べる。そこでも印を
  // 途中で折らない（名前の行・1行目だけを直し、3行目は「(コ / ピー 12)」と
  // 折れたままだった）。幅300〜440px・文字1.0/1.3/2.0。
  for (final language in languages) {
    testWidgets('copy marks stay whole in a Trash folder row that lists its '
        'works ($language)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        realFonts: true,
        size: const Size(360, 900),
      );
      final l10n = home.l10n;
      final box = await home.addFolder('box');
      final named = {
        for (final (base, number) in [
          ('Bravo Charlie Delta', 2),
          ('Echo Foxtrot Golf', 3),
          ('Hotel India', 12),
          ('Juliett Kilo Lima', 4),
        ])
          copyNameIn(l10n, base, number): copyNameIn(
            l10n,
            base,
            number,
          ).substring(base.length).trim(),
      };
      for (final name in named.keys) {
        await home.addWork(name, folderId: box.id);
      }
      await tester.runAsync(() => home.projects.moveFolderToTrash(box.id));
      await home.settleIo(2);
      await home.showTab(3);
      final row = find.byKey(ValueKey('trashedFolder_${box.id}'));
      expect(row, findsOneWidget);
      final problems = <String>[];
      var listed = 0;
      for (final scale in [1.0, 1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (var width = 300.0; width <= 440; width += 10) {
          tester.view.physicalSize = Size(width, 900);
          await home.settle();
          final text = [
            for (final element
                in find
                    .descendant(of: row, matching: find.byType(RichText))
                    .evaluate())
              (element.renderObject! as RenderParagraph).text.toPlainText(),
          ].join('\n').replaceAll('\u2060', '').replaceAll('\u00a0', ' ');
          for (final name in named.keys) {
            if (text.contains(name.replaceAll('\u00a0', ' '))) listed++;
          }
          problems.addAll(
            splitMarks(tester, named.values.toSet(), '$width x$scale'),
          );
          expect(tester.takeException(), isNull, reason: '$width x$scale');
        }
      }
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      // 3行目に作品の名前（元の名前のまま）が出ている。
      expect(listed, greaterThan(0), reason: 'the row does not list the works');
      expect(
        home.projects.trash.map((p) => p.name).toSet(),
        named.keys.toSet(),
      );
      debugPrint('$language Trash folder row: ${problems.length} split marks');
      for (final problem in problems.take(4)) {
        debugPrint('  $problem');
      }
      expect(problems, isEmpty);
      await home.close();
    });
  }

  // 作品一覧のタブの詳細表示（行）の名前。印と拡張子をかたまりにした
  // 「(コピー 12).gif」が名前の欄に入らないと、かたまりの途中のどこかで
  // 切れた（「(コピー 12).gi / f」「(사본 12).mp / 4」）。英語は番号の前で
  // 切れた（「(copy / 12).mp4」）。入らないときは、閉じ括弧と拡張子の間→
  // 印の語と番号の間→印の語の中（両側に2字以上）の順にだけ折り返す
  // （[copyMarkBreakProblems]。以前は先に印の語の中で折り返し、文字2倍・
  // 360pxで「Hotel (c / op / y).mp4」「Hotel (c / opi / e).mp4」と1字ずつに
  // 切れた）。拡張子の中では折り返さない。長音・小書きの仮名は行の頭に
  // 来ない（「(コピ / ー 2)」）。7言語×幅320〜440px×文字1.0/1.3/2.0。
  for (final language in languages) {
    testWidgets('Works list rows break a copy mark only where the order '
        'allows ($language)', (tester) async {
      final l10n = lookupAppLocalizations(
        Locale.fromSubtags(
          languageCode: language.split('_').first,
          scriptCode: language == 'zh_Hant' ? 'Hant' : null,
        ),
      );
      final names = [
        '${copyNameIn(l10n, 'clip_4', 12)}.gif',
        '${copyNameIn(l10n, 'Hotel', 12)}.mp4',
        '${copyNameIn(l10n, 'Hotel', 1)}.webm',
        '${copyNameIn(l10n, 'Hotel', 1)}.mp4',
        '${copyNameIn(l10n, 'Hotel', 2)}.mp4',
        '${copyNameIn(l10n, kanaHead, 2)}.mp4',
      ];
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        realFonts: true,
        size: const Size(360, 2400),
        exports: names,
        prefs: {'home.worksViewMode.v1': 'detail'},
      );
      await home.showTab(1);
      final problems = <String>[];
      var narrow = 0;
      var checked = 0;
      for (final scale in [1.0, 1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final width in [320.0, 340.0, 360.0, 380.0, 412.0, 440.0]) {
          tester.view.physicalSize = Size(width, 2400);
          await home.settle();
          // 動画のサムネイルを作る仕組み（ffmpeg）は、テストの環境に無い。
          final error = tester.takeException();
          if (error is! MissingPluginException) {
            expect(error, isNull, reason: '$width x$scale');
          }
          for (final name in names) {
            final paragraphs = find.descendant(
              of: find.descendant(
                of: find.byType(ExportedWorkCard),
                matching: find.byKey(const Key('exportedWorkTitle')),
              ),
              matching: find.byType(RichText),
            );
            final paragraph = paragraphs
                .evaluate()
                .map((e) => e.renderObject! as RenderParagraph)
                .where(
                  (p) =>
                      p.text
                          .toPlainText()
                          .replaceAll('\u2060', '')
                          .replaceAll('\u200b', '')
                          .replaceAll('\u00a0', ' ') ==
                      name,
                )
                .firstOrNull;
            if (paragraph == null) {
              problems.add('$width x$scale: no row for $name');
              continue;
            }
            checked++;
            final lines = ParagraphLines(paragraph);
            final shown = lines.visible
                .replaceAll('\u200b', '')
                .replaceAll('\u00a0', ' ');
            final where =
                '$width x$scale 「$name」 '
                'w=${paragraph.constraints.maxWidth.toStringAsFixed(0)}';
            final mark = copyMarkSplit(name)!.tail.trim();
            if (!shown.contains(mark)) {
              problems.add(
                '$where — 「$mark」 is not whole: '
                '${lines.lines.join(' / ').replaceAll('\u200b', '')}',
              );
              continue;
            }
            if (lines.lines.length > 1) narrow++;
            problems
              ..addAll(copyMarkBreakProblems(paragraph, mark, where: where))
              ..addAll(
                japaneseLineStartProblems(
                  paragraph,
                ).map((problem) => '$where — $problem'),
              );
          }
        }
      }
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      debugPrint(
        '$language Works rows: $checked checked ($narrow on more than one '
        'line), ${problems.length} problems',
      );
      for (final problem in problems.take(6)) {
        debugPrint('  $problem');
      }
      expect(checked, greaterThan(0));
      expect(problems, isEmpty);
      await home.close();
    });
  }
}
