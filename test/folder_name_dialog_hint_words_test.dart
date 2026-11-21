import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';

import 'helpers/home_matrix_harness.dart';
import 'helpers/paragraph_lines.dart';

/// 新しいフォルダの名前のダイアログの説明（projectListFolderHint）は、語の
/// 途中で行を変えない（韓国語は語を空白で区切って書き、折り返しも空白の所で
/// 行う）。7言語×幅320・360×文字1倍・2倍で、ダイアログの中のどの文も、
/// 1行に入る語を途中で折らず、欄の幅からはみ出さない。
///
/// 以前は説明を普通の[Text]で描き、Flutterはハングルのどの字の間でも行を
/// 変えるので、幅320で「정리하 / 는」と切れた（DISC217）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/folder-name-dialog-hint'));
  setUpAll(run.prepare);

  final wordChar = RegExp("[A-Za-z0-9À-ÖØ-öø-ɏ'’가-힣ᄀ-ᇿ㄰-㆏]");

  /// [p]の中で、1行に入る語が途中で折れている所。
  List<String> splitWords(RenderParagraph p) {
    final text = p.text.toPlainText(includeSemanticsLabels: false);
    final out = <String>[];
    if (text.length < 2) return out;
    final lines = ParagraphLines(p);
    final v = lines.visible;
    for (var i = 1; i < v.length; i++) {
      final a = lines.lineOf(i - 1);
      final b = lines.lineOf(i);
      if (a == null || b == null || a == b) continue;
      if (!wordChar.hasMatch(v[i - 1]) || !wordChar.hasMatch(v[i])) continue;
      var start = i - 1;
      while (start > 0 && wordChar.hasMatch(v[start - 1])) {
        start--;
      }
      var end = i + 1;
      while (end < v.length && wordChar.hasMatch(v[end])) {
        end++;
      }
      var width = 0.0;
      for (final box in p.getBoxesForSelection(
        lines.sourceSelection(start, end),
      )) {
        width += box.right - box.left;
      }
      if (width > p.size.width + 0.5) continue;
      out.add('"${v.substring(start, end)}" in "${lines.lines.join(' / ')}"');
    }
    for (final c in lines.charsOutsideWidth()) {
      out.add('outside the width: $c');
    }
    return out;
  }

  for (final language in kHomeMatrixLanguages) {
    testWidgets('new folder name dialog ($language): the hint keeps words '
        'whole at 320/360 x text 1/2', (tester) async {
      final m = HomeMatrix(tester, language, run);
      await m.begin();
      final problems = <String>[];
      var sawHint = 0;
      try {
        await m.start();
        for (final width in const [320, 360]) {
          for (final scale in const [1.0, 2.0]) {
            await m.resize(Size(width.toDouble(), kHomeMatrixPhoneHeight));
            await m.setTextScale(scale);
            final home = tester.element(find.byType(HomeScreen));
            showCreateFolderNameDialog(home, (_) async {});
            await m.frames(8);
            final dialog = find.byType(AlertDialog);
            expect(dialog, findsOneWidget);
            final hint = m.l10n.projectListFolderHint;
            for (final e
                in find
                    .descendant(of: dialog, matching: find.byType(RichText))
                    .evaluate()) {
              final p = e.renderObject! as RenderParagraph;
              final drawn = p.text
                  .toPlainText(includeSemanticsLabels: false)
                  .replaceAll(RegExp('[⁠​]'), '');
              if (drawn == hint) sawHint++;
              for (final split in splitWords(p)) {
                problems.add('$language ${width}px x$scale: $split');
              }
            }
            await m.capture('hint_${language}_${width}_x$scale');
            await tester.tapAt(const Offset(4, 4));
            await m.frames(8);
            expect(find.byType(AlertDialog), findsNothing);
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      // 4つの組み合わせで説明が出た（ほかの部品で描いていても字は同じ）。
      expect(sawHint, 4);
      expect(problems, isEmpty, reason: problems.join('\n'));
      expect(tester.takeException(), isNull);
    });
  }
}
