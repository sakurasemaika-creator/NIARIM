import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/utils/duplicate_name.dart'
    show copyMarkSplit, copyNameIn;
import 'package:niarim/utils/line_break.dart' show keepPartsTogether;

import 'helpers/copy_mark_breaks.dart';
import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';

/// カードの名前（2行まで）で、複製の印と番号が切れない（DISC123の残り）。
/// en・小・文字2倍の360pxで「Hotel (copy 2)」が「Hotel / (cop…」、320pxで
/// 「Hotel (copy)」が「Hotel / (co…」と、番号と印が「…」で切れていた（印が
/// 帯の1行に入らないとき、頭を縮める作りが諦めて元の名前に戻り、行の数の
/// 上限で切れた）。
///
/// 決まり：番号は決して失わない。印が1行に入るなら印は1つのかたまりのまま
/// 頭を縮める（1字＋「…」まで）。印そのものが1行に入らないときだけ、印の
/// 中で折り返す（日本語・中国語と同じ）。どの名前も2行に入り、「…」で
/// 切れない。7言語×幅320/360/412×小・中・大×文字1.0/1.3/2.0、本物の書体。
///
/// 印の中で折り返すときは、閉じ括弧と拡張子の間→印の語と番号の間→印の語の
/// 中（両側に2字以上）の順にだけ行を変える（[copyMarkBreakProblems]）。
/// 以前は先に印の語の中で折り返し、「Hotel (copi / e).mp4」「Hotel (cop /
/// y 2).mp4」と1字だけを残し、日本語は「(コピ / ー 2)」と長音が行の頭に
/// 来た。長音・小書きの仮名は名前のどこでも行の頭に来ない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  /// 段落の文から、描くために入れた字（語結合子・幅の無い空白）を除き、
  /// 改行しない空白を普通の空白にする。
  String plain(String text) =>
      text.replaceAll(wordJoiner, '').replaceAll('​', '').replaceAll(' ', ' ');

  for (final language in languages) {
    testWidgets('card names keep the whole copy mark and number ($language)', (
      tester,
    ) async {
      final problems = <String>[];
      var checked = 0;
      // 印が帯の1行に入らなかったカードの数（印の中で折り返す）。
      var narrow = 0;
      for (final mode in ['small', 'medium', 'large']) {
        final home = await HomeClipboardHarness.open(
          tester,
          language: language,
          realFonts: true,
          size: const Size(360, 3200),
          prefs: {'home.projectViewMode.v1': mode},
        );
        final l10n = home.l10n;
        final cjk = language.startsWith('zh') || language == 'ja';
        final longHead = cjk
            ? '作品のテスト用にとても長い名前'
            : language == 'ko'
            ? '애니메이션 만들기 연습 장면'
            : 'Bravo Charlie Delta Echo';
        final names = [
          copyNameIn(l10n, 'Hotel', 1),
          copyNameIn(l10n, 'Hotel', 2),
          copyNameIn(l10n, 'Hotel', 12),
          copyNameIn(l10n, longHead, 3),
          // 長音・小書きの仮名を行の頭にしない。
          copyNameIn(l10n, 'ファーストショット', 2),
          copyNameIn(l10n, 'H', 2),
        ];
        for (final name in names.take(names.length - 1)) {
          await home.addWork(name);
        }
        // フォルダのカードも同じ名前の帯。
        await home.addFolder(names.last);
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 3200);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await home.settle();
            expect(tester.takeException(), isNull);
            for (final name in names) {
              final caption = find.descendant(
                of: find.byType(ProjectListWidget),
                matching: find.byWidgetPredicate(
                  (widget) => widget is Text && widget.semanticsLabel == name,
                ),
              );
              final paragraphs = find.descendant(
                of: caption,
                matching: find.byType(RichText),
              );
              if (paragraphs.evaluate().isEmpty) {
                problems.add('$mode ${width}px x$scale: no card for $name');
                continue;
              }
              final paragraph =
                  paragraphs.evaluate().first.renderObject! as RenderParagraph;
              final lines = ParagraphLines(paragraph);
              final shown = plain(lines.visible);
              final where =
                  '$mode ${width}px x$scale 「$name」: '
                  '${lines.lines.map(plain).join(' / ')}';
              checked++;
              final mark = copyMarkSplit(name)!.tail.trim();
              // 「…」で切れていない（2行に入りきっている）。
              if (paragraph.didExceedMaxLines) {
                problems.add('$where — cut by the line limit');
                continue;
              }
              // 印と番号が全部描かれている。
              if (!shown.endsWith(mark)) {
                problems.add('$where — the mark 「$mark」 is not whole');
                continue;
              }
              // 印（描くときの、1つのかたまりにした形）が帯の1行に入るか。
              final markPainter = TextPainter(
                text: TextSpan(
                  text: keepPartsTogether(mark, [mark]),
                  style: (paragraph.text as TextSpan).style,
                ),
                textDirection: paragraph.textDirection,
                textScaler: paragraph.textScaler,
                locale: paragraph.locale,
              )..layout();
              final markFits =
                  markPainter.width <= paragraph.constraints.maxWidth;
              markPainter.dispose();
              // 印が1行に入るなら、頭は少なくとも1字残る（印が1行に入らない
              // ほど狭いときは、頭を「…」にして印を出すことがある）。
              if (markFits && !shown.startsWith(name.characters.first)) {
                problems.add('$where — no character of the name is left');
              }
              if (!markFits && narrow++ < 3) debugPrint('  narrow: $where');
              // 幅の無い空白を除いた文の位置から、段落の字の位置へ。
              final positions = <int>[
                for (var i = 0; i < lines.visible.length; i++)
                  if (lines.visible[i] != '​') i,
              ];
              final at = shown.lastIndexOf(mark);
              if (markFits &&
                  at >= 0 &&
                  lines
                      .breaksWithin(
                        positions[at],
                        positions[at + mark.length - 1] + 1,
                      )
                      .isNotEmpty) {
                problems.add('$where — the mark breaks although it fits');
              }
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
        await home.close();
      }
      debugPrint(
        '$language: $checked cards checked ($narrow with a mark wider than '
        'a line), ${problems.length} problems',
      );
      for (final problem in problems.take(8)) {
        debugPrint('  $problem');
      }
      expect(checked, greaterThan(0));
      expect(problems, isEmpty);
    });
  }

  // 作品一覧のタブの書き出したファイルのカード（拡張子の前に印）。印と
  // 拡張子を1つのかたまりにして判断5の上限の幅（97px）で測ると2行に入らず、
  // 頭を縮める作りが諦めて後ろで切ったので、384pxのカードでも「Hotel
  // (コピー…」と番号と拡張子が消えた。どのカードでも印・番号・拡張子は
  // 全部出す。7言語×小・中・大×幅320/360/412/1280×文字1.0/1.3/2.0。
  for (final language in languages) {
    testWidgets('file cards on the Works tab keep the whole copy mark, '
        'number and extension ($language)', (tester) async {
      final l10n = lookupAppLocalizations(
        Locale.fromSubtags(
          languageCode: language.split('_').first,
          scriptCode: language == 'zh_Hant' ? 'Hant' : null,
        ),
      );
      final cjk = language.startsWith('zh') || language == 'ja';
      final longHead = cjk
          ? '作品のテスト用にとても長い名前'
          : language == 'ko'
          ? '애니메이션 만들기 연습 장면'
          : 'Bravo Charlie Delta Echo';
      final names = [
        '${copyNameIn(l10n, 'Hotel', 12)}.mp4',
        '${copyNameIn(l10n, 'clip_4', 2)}.gif',
        '${copyNameIn(l10n, 'Hotel', 1)}.webm',
        '${copyNameIn(l10n, longHead, 3)}.mp4',
        '${copyNameIn(l10n, 'Hotel', 1)}.mp4',
        '${copyNameIn(l10n, 'Hotel', 2)}.mp4',
        '${copyNameIn(l10n, 'ファーストショット', 2)}.mp4',
      ];
      final problems = <String>[];
      var checked = 0;
      // 印と番号も2行に入らないほど狭いカード（調べない）。
      var tooNarrow = 0;
      for (final mode in ['small', 'medium', 'large']) {
        final home = await HomeClipboardHarness.open(
          tester,
          language: language,
          realFonts: true,
          size: const Size(360, 3200),
          exports: names,
          prefs: {'home.worksViewMode.v1': mode},
        );
        await home.showTab(1);
        for (final width in [320.0, 360.0, 412.0, 1280.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 3200);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await home.settle();
            // 動画のサムネイルを作る仕組み（ffmpeg）は、テストの環境に無い。
            final error = tester.takeException();
            if (error is! MissingPluginException) expect(error, isNull);
            for (final name in names) {
              final paragraphs = find.descendant(
                of: find.descendant(
                  of: find.byType(ExportedWorkCard),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is Text && widget.semanticsLabel == name,
                  ),
                ),
                matching: find.byType(RichText),
              );
              if (paragraphs.evaluate().isEmpty) {
                problems.add('$mode ${width}px x$scale: no card for $name');
                continue;
              }
              final paragraph =
                  paragraphs.evaluate().first.renderObject! as RenderParagraph;
              final lines = ParagraphLines(paragraph);
              final shown = plain(lines.visible);
              final where =
                  '$mode ${width}px x$scale 「$name」 '
                  'w=${paragraph.constraints.maxWidth.toStringAsFixed(0)}: '
                  '${lines.lines.map(plain).join(' / ')}';
              checked++;
              final mark = copyMarkSplit(name)!.tail.trim();
              // 印と拡張子が、印の字の間・拡張子の前・番号の前で折り返しても
              // 2行に入らないほど狭い（文字2倍の小さいカード）なら、全部は
              // 出せない。そのときも番号（閉じ括弧まで）は失わない（拡張子を
              // 「…」にする）。
              final close = mark.lastIndexOf(RegExp(r'[)）]')) + 1;
              final letter = RegExp(r'^\p{L}$', unicode: true);
              final looseMark = StringBuffer();
              String? previous;
              for (final char in mark.substring(0, close).characters) {
                if (previous != null &&
                    letter.hasMatch(previous) &&
                    letter.hasMatch(char)) {
                  looseMark.write('\u200b');
                }
                looseMark.write(char);
                previous = char;
              }
              bool fitsTwoLines(String text) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: text,
                    style: (paragraph.text as TextSpan).style,
                  ),
                  maxLines: 2,
                  textDirection: paragraph.textDirection,
                  textScaler: paragraph.textScaler,
                  locale: paragraph.locale,
                )..layout(maxWidth: paragraph.constraints.maxWidth);
                final fits = !painter.didExceedMaxLines;
                painter.dispose();
                return fits;
              }

              if (!fitsTwoLines('$looseMark\u200b${mark.substring(close)}')) {
                // 印（閉じ括弧まで）も2行に入らないほど狭いときは、何かを
                // 欠かすしかない（調べない）。
                if (!fitsTwoLines('$looseMark…')) {
                  tooNarrow++;
                  continue;
                }
                final drawn = plain(lines.lines.join());
                if (!drawn.contains(mark.substring(0, close))) {
                  problems.add(
                    '$where — 「${mark.substring(0, close)}」 is not drawn',
                  );
                }
                problems
                  ..addAll(copyMarkBreakProblems(paragraph, mark, where: where))
                  ..addAll(
                    japaneseLineStartProblems(
                      paragraph,
                    ).map((problem) => '$where — $problem'),
                  );
                continue;
              }
              if (paragraph.didExceedMaxLines) {
                problems.add('$where — cut by the line limit');
                continue;
              }
              if (!shown.endsWith(mark)) {
                problems.add('$where — 「$mark」 is not whole');
                continue;
              }
              final markPainter = TextPainter(
                text: TextSpan(
                  text: keepPartsTogether(mark, [mark]),
                  style: (paragraph.text as TextSpan).style,
                ),
                textDirection: paragraph.textDirection,
                textScaler: paragraph.textScaler,
                locale: paragraph.locale,
              )..layout();
              final markFits =
                  markPainter.width <= paragraph.constraints.maxWidth;
              markPainter.dispose();
              if (markFits && !shown.startsWith(name.characters.first)) {
                problems.add('$where — no character of the name is left');
              }
              final positions = <int>[
                for (var i = 0; i < lines.visible.length; i++)
                  if (lines.visible[i] != '\u200b') i,
              ];
              final at = shown.lastIndexOf(mark);
              if (markFits &&
                  lines
                      .breaksWithin(
                        positions[at],
                        positions[at + mark.length - 1] + 1,
                      )
                      .isNotEmpty) {
                problems.add('$where — the mark breaks although it fits');
              }
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
        await home.close();
      }
      debugPrint(
        '$language Works: $checked cards checked ($tooNarrow too narrow for '
        'the mark and number), ${problems.length} problems',
      );
      expect(tooNarrow, lessThan(checked ~/ 10));
      for (final problem in problems.take(8)) {
        debugPrint('  $problem');
      }
      expect(checked, greaterThan(0));
      expect(problems, isEmpty);
    });
  }
}
