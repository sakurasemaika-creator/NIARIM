// ヘルプの「活用Tips」の一覧で、各Tipの題を語の途中で折らず、長音符・
// 小さいかな・閉じ括弧で行を始めない（DISC225）。
//
// 題は普通の`Text`だったので、Flutterがハングルのどの字の間でも行を変え
// （韓国語「자동 채색 설정은 부 / 위별로 등록해두기」）、長音符・小さいかなの
// 前でも行を変えていた（日本語「自動塗り設定はパ / ーツごとに登録しておく」）。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0で、一覧のすべての題（74件）について、
// 行に入る語を途中で折らないこと（韓国語の語・欧文の語）、長音符・小さいかな・
// 閉じ括弧・句読点で始まる行が無いこと、題を省略しないこと、はみ出さないことを
// 見る。1語が行より広い（どう並べても入らない）語は、決まりが所有者の判断待ち
// （DISC155）なので数えずに出しておく（仏語320px・文字2倍の
// 「automatisations」）。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/tips/tips_screen.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart' show textParagraphsIn;

/// 行の頭に来てはいけない字：長音符・小さいかな（日本語の行頭禁則。普通の
/// `Text`はこれらの前でも行を変える）と、閉じ括弧・句読点。
const _noLineStart = 'ーぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ$lineStartForbidden';

/// 描いた文から、幅の無い字（語結合子・幅の無い空白）を除き、改行しない
/// 空白を普通の空白にしたもの。
String _plain(String text) => text
    .replaceAll('⁠', '')
    .replaceAll('​', '')
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ');

/// 段落[lines]の中で、空白の後でなく行が変わり、次の行が[_noLineStart]の字で
/// 始まる所。
List<String> _badLineStarts(ParagraphLines lines) {
  final out = <String>[];
  final text = lines.visible;
  int? previousLine;
  var previousChar = '';
  for (var i = 0; i < text.length; i++) {
    final line = lines.lineOf(i);
    final char = text[i];
    if (line == null) continue;
    if (previousLine != null &&
        line != previousLine &&
        previousChar.trim().isNotEmpty &&
        _noLineStart.contains(char)) {
      out.add('a line starts with「$char」: ${lines.lines.join(' / ')}');
    }
    previousLine = line;
    previousChar = char;
  }
  return out;
}

final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F]');

/// 語を空白で区切る言語の1つの語の字（`wordsBrokenThatFit`と同じ）。
final RegExp _latinRun = RegExp(
  r"[\p{Script=Latin}\p{Nd}\p{M}’']+",
  unicode: true,
);

/// 折り返せる空白（改行しない空白〔U+00A0・U+2007・U+202F〕を除く）・幅の
/// 無い空白で区切ったかたまり。
final RegExp _token = RegExp(
  r'[^ \t\n\r\u1680\u2000-\u2006\u2008-\u200B\u205F\u3000]+',
);

/// 語の前後に付いて、語と一緒に行を移る記号（引用符・括弧・句読点・改行
/// しない空白〔仏語の「« Transparence »」〕）。
final RegExp _attached = RegExp(
  r'[\u00A0\u2007\u202F]|[^\s\u200B\p{L}\p{Nd}\p{M}]',
  unicode: true,
);

/// 段落[p]の中で、語（韓国語の語・欧文の語）の途中で行が変わっている所を、
/// 語が付いている記号ごと行に入るもの（[fits]）と入らないもの（[tooWide]、
/// DISC155）に分ける。`wordsBrokenThatFit`は語の字だけの幅で比べるので、
/// 開き引用符の付いた語（「“Transparency」）が行より広くて折れているのを
/// 入る語として数える。
({List<String> fits, List<String> tooWide}) _brokenWords(RenderParagraph p) {
  final lines = ParagraphLines(p);
  final text = lines.visible;
  final limit = p.constraints.maxWidth;
  final fits = <String>[];
  final tooWide = <String>[];
  double widthOf(int start, int end) => p
      .getBoxesForSelection(lines.sourceSelection(start, end))
      .fold<double>(0, (sum, box) => sum + box.right - box.left);
  void check(int start, int end, int unitStart, int unitEnd) {
    if (lines.breaksWithin(start, end).isEmpty) return;
    final width = widthOf(unitStart, unitEnd);
    final entry =
        '「${text.substring(unitStart, unitEnd)}」'
        '（${width.toStringAsFixed(0)}px、入る幅${limit.toStringAsFixed(0)}px）: '
        '${lines.lines.join(' / ')}';
    (width > limit + 0.5 ? tooWide : fits).add(entry);
  }

  for (final token in _token.allMatches(text)) {
    if (_hangul.hasMatch(token[0]!)) {
      check(token.start, token.end, token.start, token.end);
      continue;
    }
    for (final run in _latinRun.allMatches(token[0]!)) {
      var unitStart = token.start + run.start;
      var unitEnd = token.start + run.end;
      while (unitStart > token.start &&
          _attached.hasMatch(text[unitStart - 1])) {
        unitStart--;
      }
      while (unitEnd < token.end && _attached.hasMatch(text[unitEnd])) {
        unitEnd++;
      }
      check(token.start + run.start, token.start + run.end, unitStart, unitEnd);
    }
  }
  return (fits: fits, tooWide: tooWide);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET2_SHOTS'];
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);
    final titles = {
      for (final (title, _) in allTipEntries(l10n)) _plain(title),
    };
    // 撮る題（直した所が見える題）。
    final shotTitle = _plain(l10n.tipsAutofillPresetTitle);

    testWidgets('tip titles keep words and line starts ($tag)', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      final rootKey = GlobalKey();
      final problems = <String>[];
      final tooWide = <String>{};
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: locale,
              theme: ThemeService().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TipsScreen(),
            ),
          ),
        );
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 740);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpAndSettle();
            final at = '${width.toInt()}px x$scale';
            final list = find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first;
            final position = tester.state<ScrollableState>(list).position;
            // 一覧の上端へ戻す（一覧は、上の方の行を並べ直すと位置を直すので、
            // 0に着くまで繰り返す）。
            for (var i = 0; i < 20 && position.pixels > 0; i++) {
              position.jumpTo(0);
              await tester.pump();
            }
            final seen = <String>{};
            var shot = false;
            double? shotAt;
            while (true) {
              for (final paragraph in textParagraphsIn(find.byType(ListView))) {
                final shown = _plain(
                  paragraph.text.toPlainText(includeSemanticsLabels: false),
                );
                if (!titles.contains(shown) || !seen.add(shown)) continue;
                // 題は最後まで出す（省略しない・はみ出さない）。
                if (paragraph.didExceedMaxLines) {
                  problems.add('$at「$shown」is cut short');
                }
                final lines = ParagraphLines(paragraph);
                for (final char in lines.charsOutsideWidth()) {
                  problems.add('$at「$shown」runs past its line: $char');
                }
                final broken = _brokenWords(paragraph);
                for (final word in broken.fits) {
                  problems.add('$at「$shown」: $word');
                }
                for (final word in broken.tooWide) {
                  tooWide.add('$at「$shown」: $word');
                }
                for (final start in _badLineStarts(lines)) {
                  problems.add('$at「$shown」: $start');
                }
                if (shots != null &&
                    !shot &&
                    shown == shotTitle &&
                    scale == 2.0 &&
                    width != 412) {
                  shot = true;
                  shotAt = tester
                      .getRect(
                        find.byWidgetPredicate(
                          (w) => w is RichText && w.text == paragraph.text,
                        ),
                      )
                      .top;
                }
              }
              // 撮る題を画面の上の方へ出して撮り、その位置から続けて見る。
              if (shotAt != null) {
                position.jumpTo(
                  (position.pixels + shotAt - 200).clamp(
                    0,
                    position.maxScrollExtent,
                  ),
                );
                shotAt = null;
                await tester.pump();
                await tester.runAsync(() async {
                  final boundary =
                      rootKey.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: 1);
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    '$shots/DISC225-${tag}_${width.toInt()}_x2.png',
                  ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                  image.dispose();
                });
                continue;
              }
              if (position.pixels >= position.maxScrollExtent) break;
              position.jumpTo(
                (position.pixels + position.viewportDimension * 0.6).clamp(
                  0,
                  position.maxScrollExtent,
                ),
              );
              await tester.pump();
            }
            final missing = titles.difference(seen);
            if (missing.isNotEmpty) {
              problems.add(
                '$at: ${missing.length} titles were not checked: '
                '${missing.take(3).join(' | ')}',
              );
            }
            for (final error in errors) {
              problems.add('$at: ${error.split('\n').first}');
            }
            errors.clear();
          }
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final word in tooWide) {
        debugPrint('$tag wider than the line (DISC155): $word');
      }
      for (final problem in problems.take(20)) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
