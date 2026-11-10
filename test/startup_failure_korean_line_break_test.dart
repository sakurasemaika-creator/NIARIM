import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/startup_failure_app.dart';

import 'helpers/load_app_fonts.dart';

/// 起動に失敗した画面を韓国語で出したとき、文が語の途中で折り返さないこと。
///
/// 表示言語を選んでいない韓国語の端末では、設定を読んだ後の失敗もこの画面が
/// 韓国語で出る。以前は「다시 시도／해 주세요」「개발자에／게」「없습니／다」の
/// ように語の途中で行が変わっていた（起動画面と初回の案内は語の途中で
/// 折り返さないようにしてある）。
void main() {
  /// 空白を挟まない2つの字の間で行が変わっている所（語の途中の折り返し）。
  List<String> midWordBreaks(RenderParagraph paragraph) {
    final text = paragraph.text.toPlainText();
    final breaks = <String>[];
    int? previous;
    double? previousTop;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      // 語結合子は字形を持たない。
      if (char == '\u2060') continue;
      if (char.trim().isEmpty) {
        previous = null;
        continue;
      }
      // 字ごとの書体（ハングル・英字・句読点）で字の箱の高さが違うので、
      // 行の高さいっぱいの箱で比べる。
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      if (boxes.isEmpty) continue;
      final top = boxes.first.top;
      if (previous != null && (top - previousTop!).abs() > 1) {
        final start = text.lastIndexOf(' ', previous) + 1;
        final end = text.indexOf(' ', i);
        breaks.add(
          '${text.substring(start, previous + 1)} / '
                  '${text.substring(i, end < 0 ? text.length : end)}'
              .replaceAll('\u2060', ''),
        );
      }
      previous = i;
      previousTop = top;
    }
    return breaks;
  }

  for (final (width, height, scale) in const [
    (390.0, 844.0, 1.0),
    (320.0, 568.0, 1.0),
    (320.0, 568.0, 2.0),
    (640.0, 360.0, 1.0),
  ]) {
    testWidgets('Korean is not broken mid-word at '
        '${width.toInt()}x${height.toInt()} x$scale', (tester) async {
      await loadAppFonts(tester);
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        StartupFailureApp(
          details: 'step: performance\nerror: Bad state: boom',
          languageCode: 'ko',
          onRetry: () async {},
        ),
      );
      await tester.pumpAndSettle();

      final hangul = RegExp(r'[가-힣]');
      var checked = 0;
      final broken = <String>[];
      for (final element in find.byType(RichText).evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        if (!hangul.hasMatch(paragraph.text.toPlainText())) continue;
        checked++;
        broken.addAll(midWordBreaks(paragraph));
      }
      // 見出し・本文・2つのボタン・詳細の見出し。
      expect(checked, 5);
      expect(broken, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
