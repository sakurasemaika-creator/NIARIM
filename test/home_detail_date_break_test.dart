import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

/// 詳細表示の行の日時（作品の最終保存・フォルダを作った日時・受け取った
/// 共有の日時）は、狭い画面・大きな文字で折り返しても、行に入る語・日付・
/// 時刻の途中では行を変えない（行より広い語・日付は、途中で変えるしかない）。
/// 行の頭にコロン・読点を出さない。
///
/// 以前は、韓国語の「2026. 11. 13. 오후 6:19 수정」が「…오 / 후 6:19」と
/// 午後（오후）の途中で切れ、スペイン語の「Actualizado: 13/11/2026」は
/// 「Actualizado:」が行に入らず「Actualizado / : 13/11/2026」とコロンだけが
/// 次の行の頭に出た。
void main() {
  const workName = 'Cut1';
  const folderName = 'Ep1';

  Future<void> seed(ProjectService service) async {
    await service.createFolder(folderName);
    await HomeAppHarness.work(service, workName);
  }

  // 改行しない空白を普通の空白にした文。
  String plain(String text) => text.replaceAll('⁠', '').replaceAll(' ', ' ');

  bool isSpace(String char) => char.trim().isEmpty;

  // 段落[paragraph]で、行に入るのに途中で行を変えた語・日付・時刻
  // （日時は[when]を言語[localeName]の`yMd`・`jm`で書いたもの）。
  List<String> badBreaks(
    RenderParagraph paragraph,
    DateTime when,
    String localeName,
  ) {
    final lines = ParagraphLines(paragraph);
    final text = lines.visible;
    final normal = plain(text);
    final source = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final style = (paragraph.text as TextSpan).style;
    double widthOf(int start, int end) {
      final range = lines.sourceSelection(start, end);
      final painter = TextPainter(
        text: TextSpan(
          text: source.substring(range.start, range.end),
          style: style,
        ),
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        locale: paragraph.locale,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final tokens = [
      for (final part in [
        intl.DateFormat.yMd(localeName).format(when),
        intl.DateFormat.jm(localeName).format(when),
      ])
        if (normal.indexOf(plain(part)) case final start when start >= 0)
          (start, start + plain(part).length),
    ];
    final problems = <String>[];
    for (final at in lines.breaksWithin(0, text.length)) {
      if (text[at - 1] == '\n') continue;
      // 行を変えた所を含む日付・時刻、無ければ語（空白で区切られた所）。
      var unit = tokens.where((t) => t.$1 < at && at < t.$2).firstOrNull;
      if (unit == null) {
        if (isSpace(text[at - 1]) || isSpace(text[at])) continue;
        var start = at;
        while (start > 0 && !isSpace(text[start - 1])) {
          start--;
        }
        var end = at;
        while (end < text.length && !isSpace(text[end])) {
          end++;
        }
        unit = (start, end);
      }
      if (widthOf(unit.$1, unit.$2) <= paragraph.constraints.maxWidth) {
        problems.add(
          '「${text.substring(unit.$1, unit.$2)}」の途中: '
          '${lines.lines.join(' / ')}',
        );
      }
    }
    // 行の頭に読点・コロン等、行の終わりに開き括弧が来ない。
    return [...problems, ...lines.lineEdgeViolations()];
  }

  RenderParagraph subtitleOf(WidgetTester tester, Finder tile) {
    final subtitle = tester.widget<ListTile>(tile).subtitle!;
    return tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byWidget(subtitle),
        matching: find.byType(RichText),
      ),
    );
  }

  Finder rowOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ListTile)).first;

  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('detail date lines break only between words in $language', (
      tester,
    ) async {
      await loadAppFonts(tester);
      final home = HomeAppHarness.prepare(
        tester,
        language: language,
        preferences: {'home.projectViewMode.v1': 'detail'},
      );
      final service = await home.open(size: const Size(320, 800), seed: seed);
      final localeName = AppLocalizations.of(
        tester.element(find.byType(ProjectListWidget)),
      )!.localeName;
      final work = service.projects.firstWhere((p) => p.name == workName);
      final folder = service.folders.firstWhere((f) => f.name == folderName);
      for (final width in [320.0, 360.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 800), textScale: scale);
          final why = '$language $width x$scale';
          expect(tester.takeException(), isNull, reason: why);
          final workRow = HomeAppHarness.inProjects(rowOf(workName));
          expect(
            badBreaks(subtitleOf(tester, workRow), work.updatedAt, localeName),
            isEmpty,
            reason: '$why work',
          );
          final folderRow = HomeAppHarness.inProjects(rowOf(folderName));
          expect(
            badBreaks(
              subtitleOf(tester, folderRow),
              folder.createdAt,
              localeName,
            ),
            isEmpty,
            reason: '$why folder',
          );
        }
      }
      await home.close();
    });
  }

  // 共有の「受け取ったもの」の詳細表示の行も同じ。
  for (final language in ['ko', 'es']) {
    testWidgets('received shares break only between words in $language', (
      tester,
    ) async {
      await loadAppFonts(tester);
      const sharedName = 'Shared1';
      final home = HomeAppHarness.prepare(
        tester,
        language: language,
        preferences: {'home.sharedViewMode.v1': 'detail'},
      );
      final service = await home.open(
        size: const Size(320, 800),
        seed: (service) async {
          final original = await HomeAppHarness.work(service, sharedName);
          await service.saveProject(original.id);
          final base = await NiaproSerializer.projectsBasePath();
          final data = await NiaproSerializer.load(
            '$base/${original.id}/${original.id}.niapro',
          );
          await service.importSharedProject(data);
          await service.deleteProject(original.id);
        },
      );
      await tester.tap(find.byIcon(Icons.share_outlined).first);
      await home.settle();
      final shared = service.shared.single;
      for (final width in [320.0, 360.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 800), textScale: scale);
          final why = '$language $width x$scale';
          expect(tester.takeException(), isNull, reason: why);
          final row = rowOf(sharedName);
          final localeName = AppLocalizations.of(
            tester.element(row),
          )!.localeName;
          expect(
            badBreaks(subtitleOf(tester, row), shared.updatedAt, localeName),
            isEmpty,
            reason: why,
          );
        }
      }
      await home.close();
    });
  }
}
