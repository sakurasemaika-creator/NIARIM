import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

/// 韓国語の名前は、カードの2行の名前でも語の途中で折り返さない（韓国語は
/// 語を空白で区切って書き、折り返しも空白の所で行う）。Flutterはハングルの
/// どの字の間でも折り返すので、「애니메이션 만들기 연습」が「애니메이션 만들 /
/// 기 연습」のように語の途中で切れていた。1行に入らない長い語だけは、
/// 途中で折り返してよい（折り返さないと名前の帯からはみ出す）。
void main() {
  const names = ['애니메이션 만들기 연습', '첫번째 프로젝트 장면', '표정 연습', '고양이 산책'];

  Future<void> seed(ProjectService service) async {
    for (final name in names) {
      await HomeAppHarness.work(service, name);
    }
  }

  Finder caption(String name) => HomeAppHarness.inProjects(
    find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.style?.fontFamily == 'Kuramubon' &&
          (w.semanticsLabel ?? w.data) == name,
    ),
  );

  // 語の途中で折り返した所（その語が1行に入るのに）。
  List<String> brokenWords(WidgetTester tester, String name) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: caption(name), matching: find.byType(RichText)),
    );
    final lines = ParagraphLines(paragraph);
    final text = lines.visible;
    final style = (paragraph.text as TextSpan).style;
    final problems = <String>[];
    for (final at in lines.breaksWithin(0, text.length)) {
      if (text[at - 1].trim().isEmpty || text[at].trim().isEmpty) continue;
      var start = at;
      while (start > 0 && text[start - 1].trim().isNotEmpty) {
        start--;
      }
      var end = at;
      while (end < text.length && text[end].trim().isNotEmpty) {
        end++;
      }
      final word = text.substring(start, end);
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        locale: paragraph.locale,
      )..layout();
      final fits = painter.width <= paragraph.constraints.maxWidth;
      painter.dispose();
      if (fits) problems.add('「$word」: ${lines.lines.join(' / ')}');
    }
    return problems;
  }

  for (final language in ['ko', 'ja', 'en', 'es', 'fr', 'zh', 'zh_Hant']) {
    testWidgets('Korean names break between words in $language', (
      tester,
    ) async {
      await loadAppFonts(tester);
      final home = HomeAppHarness.prepare(
        tester,
        language: language,
        preferences: {'home.projectViewMode.v1': 'small'},
      );
      await home.open(size: const Size(320, 2400), seed: seed);
      for (final width in [320.0, 360.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 2400), textScale: scale);
          final why = '$language $width x$scale';
          expect(tester.takeException(), isNull, reason: why);
          for (final name in names) {
            expect(brokenWords(tester, name), isEmpty, reason: '$why $name');
            // 読み上げは名前のまま（語結合子を挟まない）。
            expect(
              tester.widget<Text>(caption(name)).semanticsLabel,
              name,
              reason: why,
            );
          }
        }
      }
      await home.close();
    });
  }
}
