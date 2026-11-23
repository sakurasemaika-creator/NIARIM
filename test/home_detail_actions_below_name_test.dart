import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

/// 詳細表示の作品の行は、狭い画面（幅360以下）・大きな文字（1.5倍以上）では
/// 星・︙を名前の横ではなく日時の下へ回し、名前の欄を広く取る（フォルダの
/// 行と同じ）。以前は作品の行だけ横に置いたままで、320px・文字2倍で名前の
/// 欄が約120pxになり、「Scene1 / 0」「Broken thumbn / ail」と語・数の途中で
/// 折れ、長い英文は1語ずつの行になった。
void main() {
  const names = [
    'Scene10',
    'Broken thumbnail',
    'A walk in the park on a sunny afternoon',
  ];

  Future<void> seed(ProjectService service) async {
    for (final name in names) {
      await HomeAppHarness.work(service, name);
    }
  }

  bool isSpace(String char) => char.trim().isEmpty;

  /// [paragraph]の中で、行に入るのに途中で行を変えた語。
  List<String> wordsSplit(RenderParagraph paragraph) {
    final lines = ParagraphLines(paragraph);
    final text = lines.visible;
    final problems = <String>[];
    for (final at in lines.breaksWithin(0, text.length)) {
      if (isSpace(text[at - 1]) || isSpace(text[at])) continue;
      var start = at;
      while (start > 0 && !isSpace(text[start - 1])) {
        start--;
      }
      var end = at;
      while (end < text.length && !isSpace(text[end])) {
        end++;
      }
      var width = 0.0;
      for (final box in paragraph.getBoxesForSelection(
        lines.sourceSelection(start, end),
      )) {
        width += box.right - box.left;
      }
      if (width <= paragraph.size.width + 0.5) {
        problems.add(
          '「${text.substring(start, end)}」の途中: ${lines.lines.join(' / ')}',
        );
      }
    }
    return problems;
  }

  Finder rowOf(String name) => HomeAppHarness.inProjects(
    find.ancestor(of: find.text(name), matching: find.byType(ListTile)).first,
  );

  RenderParagraph titleOf(WidgetTester tester, Finder row) {
    final title = tester.widget<ListTile>(row).title!;
    return tester.renderObject<RenderParagraph>(
      find
          .descendant(
            of: find.byWidget(title),
            matching: find.byType(RichText),
            matchRoot: true,
          )
          .first,
    );
  }

  testWidgets('narrow large-text detail rows put the star and menu below the '
      'name, so names break only between words', (tester) async {
    await loadAppFonts(tester);
    final home = HomeAppHarness.prepare(
      tester,
      language: 'en',
      preferences: {'home.projectViewMode.v1': 'detail'},
    );
    await home.open(size: const Size(320, 2400), seed: seed);
    for (final (size, scale, below) in [
      // Tall windows keep every row on screen (only the width counts).
      (const Size(320, 2400), 2.0, true),
      (const Size(360, 2400), 2.0, true),
      (const Size(360, 2400), 1.5, true),
      (const Size(360, 2400), 1.0, false),
      (const Size(412, 2400), 2.0, false),
      (const Size(1280, 2400), 1.0, false),
    ]) {
      await home.resize(size, textScale: scale);
      final why = '${size.width.toInt()} x$scale';
      expect(tester.takeException(), isNull, reason: why);
      for (final name in names) {
        final row = rowOf(name);
        final tile = tester.widget<ListTile>(row);
        expect(tile.trailing == null, below, reason: '$why $name');
        final subtitle = find.byWidget(tile.subtitle!);
        final menuBelow = find.descendant(
          of: subtitle,
          matching: find.byIcon(Icons.more_vert),
        );
        expect(menuBelow, below ? findsOneWidget : findsNothing);
        if (below) {
          expect(
            wordsSplit(titleOf(tester, row)),
            isEmpty,
            reason: '$why $name',
          );
          // The star and menu sit at the end of the row, under the date.
          final rowRect = tester.getRect(row);
          expect(
            tester.getRect(menuBelow).right,
            greaterThan(rowRect.right - 64),
            reason: '$why $name',
          );
        }
      }
    }
    await home.close();
  });
}
