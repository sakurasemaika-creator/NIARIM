import 'package:flutter/rendering.dart';

/// 語を空白で区切るラテン文字。
final RegExp _latin = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿœŒ]');

/// 語を空白で区切るラテン文字とハングル。
final RegExp _latinOrHangul = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿœŒ가-힯]');

/// 描かれた段落[p]が、語の途中で折り返す・「…」で切れる・箱からはみ出す
/// ときの理由（無ければ空）。
///
/// - ラテン文字の語は、どの書体でも途中で折らない。見出しの書体
///   （くらむぼん：題・ボタン・タブ・項目名）は韓国語の語も途中で折らない
///   （本文の韓国語は字の間で折り返してよい）。描かれる行（maxLinesまで）の
///   間の折り返しだけを見る。
/// - [data]が偽なら、`maxLines`を超えて切れている・箱より高い／広い
///   （はみ出した分が描かれない）ものも数える。
List<String> textFitProblems(RenderParagraph p, {bool data = false}) {
  final text = p.text.toPlainText(includeSemanticsLabels: false);
  final heading = p.text.style?.fontFamily == 'Kuramubon';
  final wordLetter = heading ? _latinOrHangul : _latin;
  final out = <String>[];
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    textAlign: p.textAlign,
    locale: p.locale,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  );
  final placeholders = <PlaceholderDimensions>[];
  p.visitChildren((child) {
    final box = child as RenderBox;
    final span = (box.parentData! as TextParentData).span!;
    placeholders.add(
      PlaceholderDimensions(
        size: box.size,
        alignment: span.alignment,
        baseline: span.baseline,
        baselineOffset: span.baseline == null
            ? null
            : box.getDistanceToBaseline(span.baseline!, onlyReal: true),
      ),
    );
  });
  painter
    ..setPlaceholderDimensions(placeholders)
    ..layout(maxWidth: p.softWrap ? p.constraints.maxWidth : double.infinity);
  final lines = painter.computeLineMetrics();
  final shown = p.maxLines == null
      ? lines.length
      : lines.length.clamp(0, p.maxLines!);
  for (var i = 0; i < shown - 1; i++) {
    final end = painter
        .getLineBoundary(
          painter.getPositionForOffset(
            Offset(0, lines[i].baseline - lines[i].ascent + 1),
          ),
        )
        .end;
    String around(int from, int step) {
      for (var k = from; k >= 0 && k < text.length; k += step) {
        if (text[k] != '⁠') return text[k];
      }
      return '';
    }

    if (wordLetter.hasMatch(around(end - 1, -1)) &&
        wordLetter.hasMatch(around(end, 1))) {
      out.add('語の途中で折り返す');
      break;
    }
  }
  if (!data) {
    if (p.didExceedMaxLines) {
      out.add('切れている（${p.maxLines}行）');
    } else if (painter.height > p.size.height + 0.5) {
      out.add('箱より高い（${painter.height.round()}>${p.size.height.round()}）');
    } else if (painter.width > p.size.width + 0.5) {
      out.add('箱より広い（${painter.width.round()}>${p.size.width.round()}）');
    }
  }
  painter.dispose();
  return out;
}
