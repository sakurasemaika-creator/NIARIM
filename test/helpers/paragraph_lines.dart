import 'package:flutter/rendering.dart';

/// 字と字の間で行を変えさせない、幅の無い字（WORD JOINER）。
const wordJoiner = '\u2060';

/// 行の頭に来てはいけない字（閉じ括弧・句読点・行の頭に置かない記号）。
/// 普通の[Text]は、これらの前では行を変えない。
///
/// 長音（ー）と小書きの仮名（ッ・ョ等）は含めない。Flutterの行分けは
/// 普通の[Text]でもこれらの前で行を変える（「カスタムオートアクシ / ョン」）。
const lineStartForbidden = '）)］]｝}〕〉》」』】〙〗〟、。，,．.：:；;！!？?・々ゝゞヽヾ';

/// 行の終わりに来てはいけない字（開き括弧）。普通の[Text]は、これらの後
/// では行を変えない。
const lineEndForbidden = '（(［[｛{〔〈《「『【〘〖〝';

/// 描かれた[RenderParagraph]の文と、字ごとの行。
///
/// 文の中の[wordJoiner]（幅が無く、何も描かれない）を除いた文（[visible]）で
/// 調べる。埋め込んだ部品（U+FFFC）はそのまま1字として残す。
class ParagraphLines {
  ParagraphLines(this.paragraph) {
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final visible = StringBuffer();
    double? previousTop;
    double? previousBottom;
    var current = 0;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      // サロゲートの2つ目は1つ目と同じ字。
      if (unit >= 0xDC00 && unit <= 0xDFFF && i > 0) continue;
      final length = unit >= 0xD800 && unit <= 0xDBFF ? 2 : 1;
      final char = text.substring(i, i + length);
      if (char == wordJoiner) continue;
      int? line;
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + length),
      );
      if (boxes.isNotEmpty && char != '\n') {
        final box = boxes.first;
        // 前の字の箱の上下の真ん中より下から始まる字は、次の行。
        if (previousTop != null &&
            box.top > previousTop + (previousBottom! - previousTop) / 2) {
          current++;
        }
        previousTop = box.top;
        previousBottom = box.bottom;
        line = current;
      }
      for (var k = 0; k < length; k++) {
        _source.add(i + k);
        _line.add(line);
      }
      visible.write(char);
    }
    this.visible = visible.toString();
  }

  final RenderParagraph paragraph;

  /// [wordJoiner]を除いた、描かれた文。
  late final String visible;

  final _source = <int>[];
  final _line = <int?>[];

  /// [visible]の[index]番目の字が、描いた段落の文の何番目か。
  int sourceIndex(int index) => _source[index];

  /// [visible]の[index]番目の字の行（箱の無い字〔改行〕はnull）。
  int? lineOf(int index) => _line[index];

  /// [visible]の[start]〜[end]の範囲を、描いた段落の文の範囲にする。
  TextSelection sourceSelection(int start, int end) => TextSelection(
    baseOffset: _source[start],
    extentOffset: _source[end - 1] + 1,
  );

  /// [visible]の[start]〜[end]の中で行が変わる所（[visible]の位置）。
  List<int> breaksWithin(int start, int end) {
    final breaks = <int>[];
    int? previous;
    for (var i = start; i < end; i++) {
      final line = _line[i];
      if (line == null) continue;
      if (previous != null && line != previous) breaks.add(i);
      previous = line;
    }
    return breaks;
  }

  /// 行ごとの文（改行の字を挟まずに折り返した所で分ける）。
  List<String> get lines {
    final result = <StringBuffer>[];
    int? previous;
    for (var i = 0; i < visible.length; i++) {
      final line = _line[i];
      if (line == null) continue;
      if (line != previous) result.add(StringBuffer());
      result.last.write(visible[i]);
      previous = line;
    }
    return [for (final line in result) line.toString()];
  }

  /// 段落の幅の外へはみ出している字（はみ出した分は切れて見えない）。行の
  /// 終わりの空白は数えない（段落は行の終わりの空白を幅の外へ出す）。
  List<String> charsOutsideWidth() {
    final width = paragraph.size.width;
    final outside = <String>[];
    for (var i = 0; i < visible.length; i++) {
      if (_line[i] == null || visible[i].trim().isEmpty) continue;
      // サロゲートの2つ目は1つ目と同じ字。
      final unit = visible.codeUnitAt(i);
      if (unit >= 0xDC00 && unit <= 0xDFFF) continue;
      for (final box in paragraph.getBoxesForSelection(
        sourceSelection(i, i + 1),
      )) {
        if (box.left < -0.5 || box.right > width + 0.5) {
          outside.add(
            '「${visible[i]}」 ${box.left.toStringAsFixed(1)}〜'
            '${box.right.toStringAsFixed(1)}（幅${width.toStringAsFixed(1)}）: '
            '${lines.join(' / ')}',
          );
        }
      }
    }
    return outside;
  }

  /// 折り返した所（改行の字で変えた所は除く）で、行の頭が[lineStartForbidden]
  /// の字・行の終わりが[lineEndForbidden]の字になっている所。
  List<String> lineEdgeViolations() {
    final problems = <String>[];
    String show() => lines.join(' / ');
    int? previousLine;
    var previousChar = '';
    var hardBreak = false;
    for (var i = 0; i < visible.length; i++) {
      final char = visible[i];
      if (char == '\n') {
        hardBreak = true;
        continue;
      }
      final line = _line[i];
      if (line == null || char.trim().isEmpty) continue;
      if (previousLine != null && line != previousLine && !hardBreak) {
        if (lineStartForbidden.contains(char)) {
          problems.add('行の頭が「$char」: ${show()}');
        }
        if (lineEndForbidden.contains(previousChar)) {
          problems.add('行の終わりが「$previousChar」: ${show()}');
        }
      }
      previousLine = line;
      previousChar = char;
      hardBreak = false;
    }
    return problems;
  }
}
