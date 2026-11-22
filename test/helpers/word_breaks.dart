import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'paragraph_lines.dart';

final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F]');

/// 語を空白で区切る言語の、1つの語の字（ラテン文字・数字・字に付く符号・
/// 語の中のアポストロフィ）の続き。
final RegExp _latinRun = RegExp(
  r"[\p{Script=Latin}\p{Nd}\p{M}’']+",
  unicode: true,
);

/// 空白（改行しない空白も）・幅の無い空白で区切ったかたまり。
final RegExp _token = RegExp(r'[^\s\u200B]+');

/// 描かれた段落[p]の中で、語が途中で行を変えている所（無ければ空）。
///
/// 語は、ハングルを含むかたまり（韓国語の語。空白で区切った単位のまま、
/// 付いている記号・数・助詞も含めて）と、ラテン文字・数字の続き（英語・
/// フランス語・スペイン語の語。日本語・中国語の文の中の欧文の語も）。
/// 日本語・中国語の字の間の折り返しは数えない（どこで行を変えてもよい）。
///
/// 語の幅が[fitWidth]（省けば段落の欄の幅）より広いとき（どう並べても1行に
/// 入らないとき）は数えない。入らない語は、途中で折るしかない。
List<String> wordsBrokenThatFit(RenderParagraph p, {double? fitWidth}) {
  final lines = ParagraphLines(p);
  final text = lines.visible;
  final limit = fitWidth ?? p.constraints.maxWidth;
  final out = <String>[];
  void check(int start, int end) {
    if (lines.breaksWithin(start, end).isEmpty) return;
    final width = p
        .getBoxesForSelection(lines.sourceSelection(start, end))
        .fold<double>(0, (sum, box) => sum + box.right - box.left);
    if (width > limit + 0.5) return;
    out.add(
      '「${text.substring(start, end)}」（${width.toStringAsFixed(0)}px、'
      '入る幅${limit.toStringAsFixed(0)}px）: ${lines.lines.join(' / ')}',
    );
  }

  for (final token in _token.allMatches(text)) {
    if (_hangul.hasMatch(token[0]!)) {
      check(token.start, token.end);
      continue;
    }
    for (final run in _latinRun.allMatches(token[0]!)) {
      check(token.start + run.start, token.start + run.end);
    }
  }
  return out;
}

/// [scope]の中の文の段落（アイコンの字を除く）。
Iterable<RenderParagraph> textParagraphsIn(Finder scope) sync* {
  for (final element
      in find
          .descendant(of: scope, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.attached) continue;
    if (paragraph.text.style?.fontFamily == 'MaterialIcons') continue;
    yield paragraph;
  }
}

/// 描かれた段落[p]の中で、[fitWidth]（省けば段落の欄の幅）より広いために
/// 途中で行を変えている語（どう並べても1行に入らない語）。
///
/// [wordsBrokenThatFit]はこの語を数えない。アプリの文の1語が行より広いときは
/// 短い訳に替える（所有者の判断、2026-11-22、DISC155）ので、アプリの文を
/// 見るテストはこの語も失敗として数える（利用者の名前は字の間で折る、DISC145）。
List<String> wordsWiderThanLine(RenderParagraph p, {double? fitWidth}) {
  final lines = ParagraphLines(p);
  final text = lines.visible;
  final limit = fitWidth ?? p.constraints.maxWidth;
  final out = <String>[];
  void check(int start, int end) {
    if (lines.breaksWithin(start, end).isEmpty) return;
    final width = p
        .getBoxesForSelection(lines.sourceSelection(start, end))
        .fold<double>(0, (sum, box) => sum + box.right - box.left);
    if (width <= limit + 0.5) return;
    out.add(
      '「${text.substring(start, end)}」（${width.toStringAsFixed(0)}px、'
      '入る幅${limit.toStringAsFixed(0)}px）',
    );
  }

  for (final token in _token.allMatches(text)) {
    if (_hangul.hasMatch(token[0]!)) {
      check(token.start, token.end);
      continue;
    }
    for (final run in _latinRun.allMatches(token[0]!)) {
      check(token.start + run.start, token.start + run.end);
    }
  }
  return out;
}

/// 折り返せる空白（改行しない空白〔U+00A0・U+2007・U+202F〕を除く）・幅の
/// 無い空白で区切ったかたまり。
final RegExp _breakableToken = RegExp(r'[^ \t\n\r  -  -​ 　]+');

/// 語の前後に付いて、語と一緒に行を移る記号（引用符・括弧・句読点・改行
/// しない空白〔仏語の「« Transparence »」〕）。
final RegExp _attachedMark = RegExp(
  r'[   ]|[^\s​\p{L}\p{Nd}\p{M}]',
  unicode: true,
);

/// 描かれた段落[p]の中で、語（韓国語の語・欧文の語）の途中で行が変わって
/// いる所を、語が付いている記号（引用符・括弧・句読点・改行しない空白）ごと
/// [fitWidth]（省けば段落の欄の幅）に入るもの（`fits`）と入らないもの
/// （`tooWide`。どう並べても途中で折れる。DISC155）に分ける。
///
/// [wordsBrokenThatFit]は語の字だけの幅で比べるので、括弧の付いた語
/// （「(Chronologie)」）・開き引用符の付いた語（「“Transparency」）が行より
/// 広くて折れているのを、入る語として数える。
({List<String> fits, List<String> tooWide}) brokenWordUnits(
  RenderParagraph p, {
  double? fitWidth,
}) {
  final lines = ParagraphLines(p);
  final text = lines.visible;
  final limit = fitWidth ?? p.constraints.maxWidth;
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

  for (final token in _breakableToken.allMatches(text)) {
    if (_hangul.hasMatch(token[0]!)) {
      check(token.start, token.end, token.start, token.end);
      continue;
    }
    for (final run in _latinRun.allMatches(token[0]!)) {
      var unitStart = token.start + run.start;
      var unitEnd = token.start + run.end;
      while (unitStart > token.start &&
          _attachedMark.hasMatch(text[unitStart - 1])) {
        unitStart--;
      }
      while (unitEnd < token.end && _attachedMark.hasMatch(text[unitEnd])) {
        unitEnd++;
      }
      check(token.start + run.start, token.start + run.end, unitStart, unitEnd);
    }
  }
  return (fits: fits, tooWide: tooWide);
}
