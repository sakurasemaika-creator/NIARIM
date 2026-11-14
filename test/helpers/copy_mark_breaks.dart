import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:niarim/utils/duplicate_name.dart' show copyMarkSplit;
import 'package:niarim/utils/line_break.dart' show keepPartsTogether;

import 'paragraph_lines.dart';

/// 行の頭に置かない字（長音・小書きの仮名）。前の字と同じ行に残す。
const japaneseNoLineStart = 'ーぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ';

/// 描いた段落[paragraph]の、行の頭が長音・小書きの仮名になっている所。
List<String> japaneseLineStartProblems(RenderParagraph paragraph) {
  final lines = ParagraphLines(paragraph).lines;
  return [
    for (var i = 1; i < lines.length; i++)
      if (lines[i].trimLeft().isNotEmpty &&
          japaneseNoLineStart.contains(lines[i].trimLeft()[0]))
        '「${lines[i].trimLeft()[0]}」 starts a line: ${lines.join(' / ')}',
  ];
}

/// 複製の印と拡張子のかたまり[mark]（「(copy 2).mp4」「（副本）.png」）を
/// 描いた段落[paragraph]で、行を変えた所が決まりどおりか。
///
/// 行を変えてよい所は、次の順にだけ（前の段階でかたまりが行に入るときは
/// 次の段階で行を変えない）：
/// 1. かたまりのまま（印・番号・拡張子が1行。名前と印の間では行を変えてよい）
/// 2. 閉じ括弧と拡張子の間（「(copy 2) / .mp4」）
/// 3. 印の語と番号の間（「(copy / 2).mp4」）
/// 4. 印の語の中。ただし両側に2字以上残す（「(c / opy」「(cop / y」にしない）。
///    長音・小書きの仮名の前では行を変えない。
/// 5. それでも印の部分が1行に入らないほど狭いときだけ、印の語の中のどこでも
///    （長音・小書きの仮名の前を除く。閉じ括弧だけを次の行へ落とさない）。
///
/// 印の後ろを「…」にした・印の一部だけを描いたときは、段階の順は調べず、
/// 行を変えた所の形だけを調べる。
///
/// 2行までの段落（カードの名前）は、読み上げの文（元の名前）の印の前の
/// 部分を[cardHead]として、カードの名前として調べる：前の段階で印の部分が行に入っても、名前の頭を1字と「…」まで
/// 縮めて2行に入らないときは、次の段階へ進めてよい（「Hotel (copy / 2).mp4」。
/// 「… (copy 2) / .mp4」と名前を全部落とさない）。名前を1字も出さないのは、
/// どの段階でも頭の1字が入らないときだけ。
List<String> copyMarkBreakProblems(
  RenderParagraph paragraph,
  String mark, {
  required String where,
}) {
  final lines = ParagraphLines(paragraph);
  final cardHead = paragraph.maxLines == 2
      ? copyMarkSplit(paragraph.text.toPlainText())?.head
      : null;
  // 描くために入れた字（幅の無い空白）を除き、改行しない空白を普通の空白に
  // する。[positions]は除いた後の文の位置から[lines.visible]の位置へ。
  final positions = <int>[];
  final shown = StringBuffer();
  for (var i = 0; i < lines.visible.length; i++) {
    final char = lines.visible[i];
    if (char == '\u200b') continue;
    positions.add(i);
    shown.write(char == '\u00a0' ? ' ' : char);
  }
  final text = shown.toString();
  final close = mark.lastIndexOf(RegExp('[)）]'));
  var at = text.lastIndexOf(mark);
  var drawn = mark;
  final complete = at >= 0;
  if (!complete && close > 0) {
    // 拡張子を「…」にしたときは、閉じ括弧までを調べる。
    drawn = mark.substring(0, close + 1);
    at = text.lastIndexOf(drawn);
  }
  if (at < 0) return const [];
  // 行の頭の字（幅の無い空白は飛ばす）の、印の中の位置。
  int markOffset(int visible) {
    while (visible < lines.visible.length &&
        lines.visible[visible] == '\u200b') {
      visible++;
    }
    return positions.indexOf(visible) - at;
  }

  final breaks = [
    for (final visible in lines.breaksWithin(
      positions[at],
      positions[at + drawn.length - 1] + 1,
    ))
      markOffset(visible),
  ];
  if (breaks.isEmpty) return const [];
  final letter = RegExp(r'^\p{L}$', unicode: true);
  final digit = RegExp(r'^\d$');
  // 印の語（開き括弧の後の字の並び）と番号の位置。
  var wordStart = -1;
  var wordEnd = -1;
  var numberStart = -1;
  for (var i = 0; i < (close < 0 ? mark.length : close); i++) {
    if (letter.hasMatch(mark[i])) {
      if (wordStart < 0) wordStart = i;
      if (numberStart < 0) wordEnd = i + 1;
    } else if (digit.hasMatch(mark[i]) && numberStart < 0 && wordStart >= 0) {
      numberStart = i;
    }
  }
  final hasExtension = close >= 0 && close + 1 < mark.length;
  final style = paragraph.text is TextSpan
      ? (paragraph.text as TextSpan).style
      : null;
  bool fits(String part) {
    part = part.trim();
    if (part.isEmpty) return true;
    final painter = TextPainter(
      text: TextSpan(text: keepPartsTogether(part, [part]), style: style),
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
    )..layout();
    final fits = painter.width <= paragraph.constraints.maxWidth;
    painter.dispose();
    return fits;
  }

  final wholeFits = fits(mark);
  final beforeExtensionFits = !hasExtension
      ? wholeFits
      : fits(mark.substring(0, close + 1)) && fits(mark.substring(close + 1));
  final beforeNumberFits = numberStart < 0
      ? beforeExtensionFits
      : fits(mark.substring(0, numberStart)) &&
            fits(mark.substring(numberStart, close + 1)) &&
            (!hasExtension || fits(mark.substring(close + 1)));
  // 印の語の中で両側に2字以上残して折り返しても、どの部分も1行に入るか
  // （入らないほど狭いときだけ、語の中のどこで折り返してもよい）。
  bool insideWordFits() {
    final cuts = <int>{
      if (hasExtension) close + 1,
      if (numberStart >= 0) numberStart,
      for (var k = wordStart + 2; k <= wordEnd - 2; k++)
        if (!japaneseNoLineStart.contains(mark[k])) k,
    }.toList()..sort();
    var from = 0;
    for (final cut in [...cuts, mark.length]) {
      if (!fits(mark.substring(from, cut))) return false;
      from = cut;
    }
    return true;
  }

  // 段階[level]（0：かたまりのまま、1：拡張子の前、2：番号の前、3：語の中で
  // 両側に2字以上、4：語の中のどこでも）まで折り返せるようにした印。
  String markAt(int level) {
    final out = StringBuffer();
    for (var i = 0; i < mark.length; i++) {
      final char = mark[i];
      if (char == ' ') {
        final beforeNumber = i + 1 < mark.length && digit.hasMatch(mark[i + 1]);
        out.write(beforeNumber && level >= 2 ? ' ' : '\u00a0');
        continue;
      }
      if (i > 0 && mark[i - 1] != ' ') {
        var breaks = false;
        if (hasExtension && i == close + 1) {
          breaks = level >= 1;
        } else if (hasExtension && i > close + 1) {
          breaks = false;
        } else if (i == numberStart) {
          breaks = level >= 2;
        } else if (i > wordStart &&
            i < wordEnd &&
            !japaneseNoLineStart.contains(char)) {
          breaks =
              level >= 4 ||
              (level == 3 && i - wordStart >= 2 && wordEnd - i >= 2);
        }
        out.write(breaks ? '\u200b' : '\u2060');
      }
      out.write(char);
    }
    return out.toString();
  }

  bool piecesFit(int level) {
    final painter = TextPainter(
      text: TextSpan(text: markAt(level), style: style),
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
    )..layout();
    final fits = painter.minIntrinsicWidth <= paragraph.constraints.maxWidth;
    painter.dispose();
    return fits;
  }

  bool fitsTwoLines(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 2,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
    )..layout(maxWidth: paragraph.constraints.maxWidth);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }

  // カードで、段階[level]なら名前の頭を1字（と「…」）残して2行に入るか。
  bool keepsHeadAt(int level) {
    final head = cardHead!.characters;
    final shortest = head.length > 1 ? '${head.first}…' : head.first;
    final drawnMark = markAt(level);
    return piecesFit(level) &&
        (fitsTwoLines('$shortest $drawnMark') ||
            fitsTwoLines('$shortest$drawnMark'));
  }

  final problems = <String>[];
  final shownLines = lines.lines
      .map((line) => line.replaceAll('\u200b', '').replaceAll('\u00a0', ' '))
      .join(' / ');
  if (cardHead != null && cardHead.isNotEmpty && complete) {
    // 使った段階（行を変えた所のうち最も後の段階）。
    var used = 0;
    for (final k in breaks) {
      if (hasExtension && k == close + 1) {
        used = used < 1 ? 1 : used;
      } else if (k == numberStart) {
        used = used < 2 ? 2 : used;
      } else if (k > wordStart && k < wordEnd) {
        final level = k - wordStart < 2 || wordEnd - k < 2 ? 4 : 3;
        used = used < level ? level : used;
      }
    }
    final head = text.substring(0, at).trim();
    final keepsHead = head.isNotEmpty && head != '…';
    final earlier = [
      for (var level = 0; level < (keepsHead ? used : 5); level++)
        if (keepsHead || level <= 3 || !insideWordFits()) level,
    ].where(keepsHeadAt).firstOrNull;
    if (earlier != null) {
      problems.add(
        keepsHead
            ? '$where — breaks at step $used although step $earlier keeps a '
                  'letter of the name: $shownLines'
            : '$where — drops the name although step $earlier keeps a letter '
                  'of it: $shownLines',
      );
    }
  }
  for (final k in breaks) {
    final card = cardHead != null;
    if (hasExtension && k == close + 1) {
      if (!card && complete && wholeFits) {
        problems.add(
          '$where — breaks before the extension although 「$mark」 fits: '
          '$shownLines',
        );
      }
    } else if (k == numberStart) {
      if (!card && complete && beforeExtensionFits) {
        problems.add(
          '$where — breaks before the number although '
          '「${mark.substring(0, close + 1)}」 fits: $shownLines',
        );
      }
    } else if (k > wordStart && k < wordEnd) {
      if (japaneseNoLineStart.contains(mark[k])) {
        problems.add('$where — 「${mark[k]}」 starts a line: $shownLines');
      } else if ((k - wordStart < 2 || wordEnd - k < 2) && insideWordFits()) {
        problems.add(
          '$where — leaves one letter of 「${mark.substring(wordStart, wordEnd)}」 '
          'alone: $shownLines',
        );
      } else if (!card && complete && beforeNumberFits) {
        problems.add(
          '$where — breaks inside 「${mark.substring(wordStart, wordEnd)}」 '
          'although the mark and the number fit apart: $shownLines',
        );
      }
    } else {
      problems.add(
        '$where — breaks the mark at 「${mark.substring(0, k)} / '
        '${mark.substring(k)}」: $shownLines',
      );
    }
  }
  return problems;
}
