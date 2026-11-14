import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 文の中の[keep]に挙げた部分（数と単位など）を、行の途中で切らずに1つの
/// かたまりとして描く[Text]。
///
/// 日本語・中国語・韓国語は字と字の間のどこでも行を変えてよいので、
/// 「確定価格（交換準備中） · 55000コイン」が「…55000コイ」「ン」のように
/// 単位の途中で切れる。[keep]の部分は字と字の間に幅の無いWORD JOINER
/// （U+2060。前後で行を変えてはいけない字）を挟み、中の空白を改行しない
/// 空白にして描き、行に入りきらなければその前で行を変える。
///
/// かたまりが前後の離せない字（後ろの閉じ括弧・読点、前の開き括弧・数の前の
/// 通貨の記号や符号）と合わせて欄の1行に入らないときは、つながずに普通の
/// [Text]と同じに折る。つなぐと、かたまりが次の行へ送られたうえで字の途中で
/// 折れ、「未使用素材を一 / 括削除 / （全プロジェク / ト）」と普通のTextより
/// 行が増えた。どれをつなぐかは欄の幅で決まるので、並べるとき（と、内側の
/// 大きさを尋ねられたとき）に決める。内側の最小の幅は、かたまりをすべて
/// つないだ文で答える（ActionBesideOrBelow 等が「この幅より狭いと語や
/// かたまりの途中で折れる」と読むため）。
///
/// 行に入りきらない語の途中で折れて、閉じ括弧・読点だけが行の頭に来るとき
/// （普通のTextでも「(todos los proyectos / )」となる）は、その前の1字と
/// 一緒に次の行へ送る（「proyecto / s)」）。
///
/// かたまりの外側の行分けは普通の[Text]と同じ（閉じ括弧・読点の前、開き
/// 括弧の後では行を変えない）。かたまりを埋め込んだ部品（WidgetSpan）で
/// 並べると、段落は部品の前後のどこでも行を変えてよいと見なし、
/// 「作品広場の投 / 稿枠（1日 / 1作品→3作品 / ）」と閉じ括弧だけの行や、
/// 「30日 / 、達成しました」と読点で始まる行ができた。
///
/// [keep]に挙げなくても、数とそのすぐ後に空白なしで続く単位の字（漢字・
/// ひらがな・カタカナ・ハングルのうち同じ種類の字を3字まで。「10件」
/// 「1コイン」「0시간」「4金幣」「1作品」）は数と1つのかたまりにする
/// （数と単位の間で行を変えない）。空白を挟む言語の数と単位
/// （「20 minutes」）は[keep]に挙げる。
///
/// [Text]を継承するのは、[data]を文全体のまま持たせ、文としての扱い
/// （文全体を読み上げる・文全体で探す）を普通の[Text]と同じにするため。
class KeepTogetherText extends Text {
  const KeepTogetherText(
    super.data, {
    required this.keep,
    super.key,
    super.style,
    super.textAlign,
  });

  /// [data]の中で、途中で行を変えない部分。現れる所はすべて対象（ただし、
  /// 数で始まる部分が別の数の途中から現れる所〔「15分」の中の「5分」〕は
  /// 除く）。
  final List<String> keep;

  /// この部品が、つなぎ方と大きさを決めるために自分で文を並べた回数
  /// （[TextPainter.layout]を呼んだ回数。中の段落〔[RichText]〕が描くために
  /// 並べる分は含まない）。デバッグ版でだけ数える。一覧を並べ直す手間が
  /// 増えていないかをテストで確かめるためのもの。
  @visibleForTesting
  static int debugLayoutCount = 0;

  /// 数と、そのすぐ後に続く同じ種類の字（3字まで）。数の途中からは始めない。
  static final _numberWithUnit = RegExp(
    r'(?<!\d)\d+(?:[.,]\d+)*'
    r'(?:\p{Script=Han}{1,3}|\p{Script=Hiragana}{1,3}'
    r'|[\p{Script=Katakana}ー]{1,3}|\p{Script=Hangul}{1,3})',
    unicode: true,
  );

  static bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

  /// [text]の[from]より後で最初に現れる、途中で切らない部分の位置と中身
  /// （同じ位置なら長い方）。無ければ位置は-1。
  (int, String) _nextKept(String text, int from) {
    var at = -1;
    var part = '';
    void consider(int index, String candidate) {
      if (at < 0 ||
          index < at ||
          (index == at && candidate.length > part.length)) {
        at = index;
        part = candidate;
      }
    }

    for (final candidate in keep) {
      if (candidate.isEmpty) continue;
      final number = _isDigit(candidate.codeUnitAt(0));
      var index = text.indexOf(candidate, from);
      while (index > 0 && number && _isDigit(text.codeUnitAt(index - 1))) {
        index = text.indexOf(candidate, index + 1);
      }
      if (index >= 0) consider(index, candidate);
    }
    final unit = _numberWithUnit.allMatches(text, from).firstOrNull;
    if (unit != null) consider(unit.start, unit.group(0)!);
    return (at, part);
  }

  /// [text]の中の、途中で切らない部分の位置（始まりと終わり）。つないでも
  /// 何も変わらない部分（空白の無い1字）は除く。
  ///
  /// 部分は字（書記素）の境目まで広げる。数と単位の決まりや[keep]は字の
  /// 中の符号の位置で終わることがある（分けて書いた濁点「か＋゛」・異体字
  /// セレクター・字母に分けたハングル・半角カナの濁点）。
  List<(int, int)> _keptRanges(String text) {
    final boundaries = <int>[0];
    for (final char in text.characters) {
      boundaries.add(boundaries.last + char.length);
    }
    final ranges = <(int, int)>[];
    var start = 0;
    while (start < text.length) {
      final (at, part) = _nextKept(text, start);
      if (at < 0) break;
      final begin = boundaries.lastWhere((b) => b <= at);
      final end = boundaries.firstWhere((b) => b >= at + part.length);
      if (text.substring(begin, end).characters.length > 1 ||
          part.contains(' ')) {
        ranges.add((begin, end));
      }
      start = end;
    }
    return ranges;
  }

  @override
  Widget build(BuildContext context) {
    final text = data!;
    final ranges = _keptRanges(text);
    final tails = _KeptParts.closingTails(text);
    if (ranges.isEmpty && tails.isEmpty) return super.build(context);
    final defaultStyle = DefaultTextStyle.of(context);
    var effectiveStyle = style == null || style!.inherit
        ? defaultStyle.style.merge(style)
        : style!;
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final parts = _KeptParts(
      text: text,
      ranges: ranges,
      tails: tails,
      style: effectiveStyle,
      textAlign: textAlign ?? defaultStyle.textAlign ?? TextAlign.start,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: defaultStyle.softWrap,
      overflow: effectiveStyle.overflow ?? defaultStyle.overflow,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: defaultStyle.maxLines,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      textWidthBasis: defaultStyle.textWidthBasis,
      textHeightBehavior:
          defaultStyle.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
    );
    return Semantics(
      textDirection: textDirection,
      // 文全体を、行を変えないための字を除いた元の文のまま読み上げる。
      label: semanticsLabel ?? text,
      child: ExcludeSemantics(
        child: _KeepTogetherLayout(
          parts: parts,
          builder: (context, span) => RichText(
            textAlign: parts.textAlign,
            textDirection: parts.textDirection,
            locale: parts.locale,
            softWrap: parts.softWrap,
            overflow: parts.overflow,
            textScaler: parts.textScaler,
            maxLines: parts.maxLines,
            textWidthBasis: parts.textWidthBasis,
            textHeightBehavior: parts.textHeightBehavior,
            text: span,
          ),
        ),
      ),
    );
  }
}

/// 数とそのすぐ後の単位を行の途中で切らずに[text]を描く（確認の文の
/// 「プロジェクト2件」「2 items」「2 elementos」）。漢字・かな・ハングルの
/// 単位は[KeepTogetherText]がもともとつなぐので、空白を挟む言語の「数＋次の
/// 語」だけを足す。数の無い文は普通の[Text]。
Widget countText(String text, {Key? key, TextStyle? style}) {
  final parts = [for (final m in _spacedCount.allMatches(text)) m[0]!];
  if (!text.contains(RegExp(r'\d'))) return Text(text, key: key, style: style);
  return KeepTogetherText(text, key: key, keep: parts, style: style);
}

/// 数と、空白を1つ挟んで続く語（「2 items」「1 élément」）。
final RegExp _spacedCount = RegExp(
  r"(?<!\d)\d+(?:[.,]\d+)*[  ]\p{L}[\p{L}\p{M}'’-]*",
  unicode: true,
);

/// [text]の中の、数とそのすぐ後に空白なしで続く単位（漢字・かな・ハングル。
/// 「10秒」「10초」「2件」）。[KeepTogetherText]が自分でつなぐのと同じもの。
/// [Text]のまま行の途中で切らずに描くところ（`keepPartsTogether`）で使う。
List<String> numberUnitParts(String text) => [
  for (final match in KeepTogetherText._numberWithUnit.allMatches(text))
    match[0]!,
];

/// 文と、その中の途中で切らない部分・閉じ括弧。欄の幅ごとに、どの部分を
/// つなぐか・どの閉じ括弧を前の字と一緒に送るかを、段落
/// （[RenderParagraph]）と同じ設定の[TextPainter]で並べて決める。
class _KeptParts {
  _KeptParts({
    required this.text,
    required this.ranges,
    required this.tails,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    required this.softWrap,
    required this.overflow,
    required this.textScaler,
    required this.maxLines,
    required this.locale,
    required this.textWidthBasis,
    required this.textHeightBehavior,
  });

  final String text;

  /// [text]の中の、途中で切らない部分（始まりと終わり）。前から順。
  final List<(int, int)> ranges;

  /// [text]の中の、語のすぐ後の閉じ括弧・読点（[closingTails]）の位置と、
  /// その前の1字の始まり。
  final List<(int, int)> tails;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final bool softWrap;
  final TextOverflow overflow;
  final TextScaler textScaler;
  final int? maxLines;
  final Locale? locale;
  final TextWidthBasis textWidthBasis;
  final ui.TextHeightBehavior? textHeightBehavior;

  /// 前後で行を変えてはいけない、幅の無い字（WORD JOINER）。
  static const _wordJoiner = '\u2060';

  /// 後ろで行を変えてよい、幅の無い字（ZERO WIDTH SPACE）。
  static const _zeroWidthSpace = '\u200b';

  /// [_wordJoiner]・[_zeroWidthSpace]に付ける書式。字の間隔（letterSpacing）
  /// は字ごとに足されるので、これらにも足すと、その所だけ字の間が広がる
  /// （Material 3の本文の0.25pxで、「55000コイン」が1.75px広がった）。
  static const _joinerStyle = TextStyle(letterSpacing: 0);

  /// 改行しない空白。段落は普通の空白の後ではいつでも行を変えるので
  /// （[_wordJoiner]を挟んでも変える）、途中で切らない部分の空白はこれにする。
  static const _noBreakSpace = '\u00a0';

  /// 前で行を変えない字（閉じ括弧・読点・句点等）。
  static const _closing = '）)］]｝}〕〉》」』】〙〗〟、。，,．.：:；;！!？?';

  /// 後ろで行を変えない字（開き括弧）。
  static const _opening = '（(［[｛{〔〈《「『【〘〖〝';

  static final _space = RegExp(r'\s');

  /// 数の前に付けて、後ろの数と離さない記号（通貨の記号・正負の符号・番号の
  /// 記号。行分けの決まりで、後ろの数との間では行を変えない字）。全角の
  /// ＋・～・＝や絵文字は後ろで行を変えてよいので含めない（含めると、記号の
  /// 後で行が変わっただけで「行をまたいだ」と見て、1行に入るかたまりを
  /// 分けた）。
  static final _prefix = RegExp(
    '[\$+\\\\\u00a3\u00a4\u00a5\u00b1\u2116\u2212\u2213'
    '\u20a0-\u20cf\ufe69\uff04\uffe1\uffe5\uffe6]',
  );

  /// [text]の中の、語のすぐ後の閉じ括弧・読点の位置と、その前の1字の
  /// 始まり。前の字が空白・括弧・読点のもの、その前が開き括弧のもの
  /// （「(s)」）は除く（前の字の前で行を変えると、別の字が行の頭・終わりに
  /// 来る）。
  static List<(int, int)> closingTails(String text) {
    final tails = <(int, int)>[];
    final starts = <int>[];
    final chars = <String>[];
    var offset = 0;
    for (final char in text.characters) {
      starts.add(offset);
      chars.add(char);
      offset += char.length;
    }
    for (var i = 1; i < chars.length; i++) {
      if (!_closing.contains(chars[i])) continue;
      final before = chars[i - 1];
      if (_space.hasMatch(before) ||
          _closing.contains(before) ||
          _opening.contains(before) ||
          (i >= 2 && _opening.contains(chars[i - 2]))) {
        continue;
      }
      tails.add((starts[i], starts[i - 1]));
    }
    return tails;
  }

  bool sameAs(_KeptParts other) =>
      identical(this, other) ||
      (text == other.text &&
          listEquals(ranges, other.ranges) &&
          listEquals(tails, other.tails) &&
          style == other.style &&
          textAlign == other.textAlign &&
          textDirection == other.textDirection &&
          softWrap == other.softWrap &&
          overflow == other.overflow &&
          textScaler == other.textScaler &&
          maxLines == other.maxLines &&
          locale == other.locale &&
          textWidthBasis == other.textWidthBasis &&
          textHeightBehavior == other.textHeightBehavior);

  final _variants = <String, _KeptVariant>{};

  /// 欄の幅ごとに決めたつなぎ方（新しく使った順。古いものから捨てる）。
  final _choices = <double, (List<bool>, List<bool>)>{};
  static const _choicesKept = 16;

  /// すべての部分をつなぎ、どの閉じ括弧も送らない文のつなぎ方。
  late final (List<bool>, List<bool>) _allJoined = (
    List<bool>.filled(ranges.length, true),
    List<bool>.filled(tails.length, false),
  );

  /// すべての部分をつないだ文の、最も狭い幅と1行に並べた幅。
  (double, double)? _joinedWidths;

  /// 並べて測るための[TextPainter]（[dispose]で捨てる）。段落の形を作り直さ
  /// ないよう使い回す。
  TextPainter? _measurer;

  TextPainter get _painter => _measurer ??= TextPainter(
    textAlign: textAlign,
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: maxLines,
    ellipsis: overflow == TextOverflow.ellipsis ? '\u2026' : null,
    locale: locale,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
  );

  void _layout(
    TextPainter painter,
    InlineSpan span, {
    double minWidth = 0.0,
    double maxWidth = double.infinity,
  }) {
    assert(() {
      KeepTogetherText.debugLayoutCount++;
      return true;
    }());
    painter
      ..text = span
      ..layout(minWidth: minWidth, maxWidth: maxWidth);
  }

  /// 書体が変わったとき：並べた結果から決めたものを捨てる。
  void forgetLayouts() {
    _choices.clear();
    _joinedWidths = null;
    _measurer?.markNeedsLayout();
  }

  void dispose() {
    _measurer?.dispose();
    _measurer = null;
  }

  /// [joined]の部分だけをつなぎ（部分の字と字の間に[_wordJoiner]、部分の
  /// 中の空白は[_noBreakSpace]）、[sent]の閉じ括弧の前の1字の前に
  /// [_zeroWidthSpace]を置いた文。
  _KeptVariant _variant(List<bool> joined, List<bool> sent) =>
      _variants.putIfAbsent('${joined.map((j) => j ? 1 : 0).join()}/'
          '${sent.map((s) => s ? 1 : 0).join()}', () {
        final breakBefore = <int>{
          for (var i = 0; i < tails.length; i++)
            if (sent[i]) tails[i].$2,
        };
        final pieces = <InlineSpan>[];
        final run = StringBuffer();
        // 元の文の位置（字の中の符号の位置と文の終わりも）の、描く文の中の
        // 位置。
        final at = <int, int>{};
        var offset = 0;
        void flush() {
          if (run.isEmpty) return;
          pieces.add(TextSpan(text: run.toString()));
          offset += run.length;
          run.clear();
        }

        void insert(String char) {
          flush();
          pieces.add(TextSpan(text: char, style: _joinerStyle));
          offset += char.length;
        }

        var source = 0;
        var range = 0;
        for (final char in text.characters) {
          while (range < ranges.length && ranges[range].$2 <= source) {
            range++;
          }
          final inPart =
              range < ranges.length &&
              joined[range] &&
              ranges[range].$1 <= source;
          if (inPart && ranges[range].$1 < source) {
            insert(_wordJoiner);
          } else if (breakBefore.contains(source)) {
            insert(_zeroWidthSpace);
          }
          final position = offset + run.length;
          for (var k = 0; k < char.length; k++) {
            at[source + k] = position + k;
          }
          run.write(inPart && char == ' ' ? _noBreakSpace : char);
          source += char.length;
        }
        at[source] = offset + run.length;
        flush();
        return _KeptVariant(TextSpan(style: style, children: pieces), at);
      });

  /// 段落が行を折る幅（[RenderParagraph]と同じく、折らない設定なら無限）。
  double _wrapWidth(double maxWidth) =>
      softWrap || overflow == TextOverflow.ellipsis
      ? maxWidth
      : double.infinity;

  /// [ranges]の[index]番目の部分を、前後の離せない字（前の開き括弧・数の前の
  /// 記号〔[_prefix]〕、後ろの閉じ括弧・読点）まで広げた範囲。
  (int, int) _attached(int index) {
    var (start, end) = ranges[index];
    while (start > 0) {
      final before = _charBefore(start);
      if (!_opening.contains(before) && !_prefix.hasMatch(before)) break;
      start -= before.length;
    }
    while (end < text.length) {
      final after = _charAt(end);
      if (!_closing.contains(after)) break;
      end += after.length;
    }
    return (start, end);
  }

  String _charAt(int index) => text.substring(index).characters.first;

  String _charBefore(int index) => text.substring(0, index).characters.last;

  /// 幅[maxWidth]の欄でつなぐ部分と、前の字と一緒に送る閉じ括弧。
  ///
  /// まず全部の部分をつないで並べ、前後の離せない字と合わせて行をまたいだ
  /// （1行に入らず字の途中で折れた）部分をつながずに並べ直す。それでも
  /// 語の途中で折れて閉じ括弧が行の頭に来たら、その前の1字の前でも行を
  /// 変えてよいことにする。すべてつないだ文が1行に入る欄では、どれも行を
  /// またがないので並べずに決める（一覧の行の多くはこれ）。
  (List<bool>, List<bool>) _choose(double maxWidth) {
    final width = _wrapWidth(maxWidth);
    if (!width.isFinite || _joinedIntrinsicWidths.$2 <= width) {
      return _allJoined;
    }
    final known = _choices.remove(width);
    if (known != null) return _choices[width] = known;
    final joined = List<bool>.of(_allJoined.$1);
    final sent = List<bool>.of(_allJoined.$2);
    final painter = _painter;
    for (var round = 0; round <= ranges.length + tails.length; round++) {
      final variant = _variant(joined, sent);
      _layout(painter, variant.span, maxWidth: width);
      var changed = false;
      for (var i = 0; i < ranges.length; i++) {
        if (!joined[i]) continue;
        final (start, end) = _attached(i);
        if (_crossesLines(painter, variant.at[start]!, variant.at[end]!)) {
          joined[i] = false;
          changed = true;
        }
      }
      if (changed) continue;
      for (var i = 0; i < tails.length; i++) {
        if (sent[i]) continue;
        final (closing, before) = tails[i];
        // つないだ部分の中の閉じ括弧は、部分ごと送る（上で決めた）。
        var inPart = false;
        for (var r = 0; r < ranges.length; r++) {
          if (joined[r] && ranges[r].$1 <= before && closing < ranges[r].$2) {
            inPart = true;
          }
        }
        if (inPart) continue;
        final end = closing + _charAt(closing).length;
        if (_crossesLines(painter, variant.at[before]!, variant.at[end]!)) {
          sent[i] = true;
          changed = true;
        }
      }
      if (!changed) break;
    }
    if (_choices.length >= _choicesKept) _choices.remove(_choices.keys.first);
    return _choices[width] = (joined, sent);
  }

  /// [painter]の[start]〜[end]の字が、2行以上にまたがっているか。
  static bool _crossesLines(TextPainter painter, int start, int end) {
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    if (boxes.length < 2) return false;
    final top = boxes.first.top;
    return boxes.any((box) => (box.top - top).abs() > 0.5);
  }

  /// 幅[maxWidth]の欄で描く文。
  InlineSpan spanFor(double maxWidth) {
    final (joined, sent) = _choose(maxWidth);
    return _variant(joined, sent).span;
  }

  /// 段落と同じ大きさの計算を、幅[maxWidth]の欄で描く文で行う。
  T _measure<T>(
    double minWidth,
    double maxWidth,
    T Function(TextPainter painter) read,
  ) {
    final span = spanFor(maxWidth);
    final painter = _painter;
    _layout(painter, span, minWidth: minWidth, maxWidth: _wrapWidth(maxWidth));
    return read(painter);
  }

  /// すべての部分をつないだ文の、最も狭い幅と1行に並べた幅（1回並べて
  /// 覚えておく）。
  (double, double) get _joinedIntrinsicWidths => _joinedWidths ??= () {
    final painter = _painter;
    final (joined, sent) = _allJoined;
    _layout(painter, _variant(joined, sent).span);
    return (painter.minIntrinsicWidth, painter.maxIntrinsicWidth);
  }();

  /// 最も狭い幅。すべての部分をつないだ文の幅（DISC130 より前と同じ答え）。
  /// つないだ部分は1語として数えるので、尋ねる親（ActionBesideOrBelow）は
  /// 部分が入らない幅を「語の途中で折れる幅」と見て、文の横に操作を置かない。
  /// これより狭い欄に置かれても、入らない部分はつながずに折るので、字は欄の
  /// 外へ出ない。
  double get minIntrinsicWidth => _joinedIntrinsicWidths.$1;

  /// 1行に並べた幅（1行に並べるときは、どの部分もつなぐ）。
  double get maxIntrinsicWidth => _joinedIntrinsicWidths.$2;

  double heightFor(double width) =>
      _measure(width, width, (painter) => painter.height);

  Size sizeFor(BoxConstraints constraints) => constraints.constrain(
    _measure(
      constraints.minWidth,
      constraints.maxWidth,
      (painter) => painter.size,
    ),
  );

  double baselineFor(BoxConstraints constraints) => _measure(
    constraints.minWidth,
    constraints.maxWidth,
    (painter) =>
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
  );
}

/// 描く文と、元の文の位置（字の中の符号の位置と文の終わりも）の、描く文の
/// 中の位置。
class _KeptVariant {
  const _KeptVariant(this.span, this.at);

  final InlineSpan span;
  final Map<int, int> at;
}

/// 欄の幅を受け取ってから、つなぐ部分を決めた[RichText]を作る。どの文を描く
/// かは描画の側（[_RenderKeepTogether]）が欄の幅で決めて[builder]へ渡すので、
/// 決め直した結果（書体が変わったとき等）が変わったときだけ作り直す。内側の
/// 大きさを尋ねる親（ダイアログのボタンの段・[IntrinsicWidth]・表）にも、
/// 並べたときと同じ大きさを答える（[LayoutBuilder]は答えられない）。
class _KeepTogetherLayout extends AbstractLayoutBuilder<InlineSpan> {
  const _KeepTogetherLayout({required this.parts, required this.builder});

  final _KeptParts parts;

  @override
  final Widget Function(BuildContext context, InlineSpan span) builder;

  @override
  bool updateShouldRebuild(_KeepTogetherLayout oldWidget) =>
      !parts.sameAs(oldWidget.parts);

  @override
  _RenderKeepTogether createRenderObject(BuildContext context) =>
      _RenderKeepTogether(parts);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderKeepTogether renderObject,
  ) {
    renderObject.parts = parts;
  }
}

class _RenderKeepTogether extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<InlineSpan, RenderBox>,
        RelayoutWhenSystemFontsChangeMixin {
  _RenderKeepTogether(this._parts);

  /// 同じ文・書式の間は同じものを使い続ける（決めたつなぎ方・測った幅・
  /// 測るための[TextPainter]を、作り直された部品の間で使い回す）。
  _KeptParts _parts;
  set parts(_KeptParts value) {
    if (value.sameAs(_parts)) return;
    _parts.dispose();
    _parts = value;
    markNeedsLayout();
  }

  @override
  InlineSpan get layoutInfo => _parts.spanFor(constraints.maxWidth);

  @override
  void systemFontsDidChange() {
    _parts.forgetLayouts();
    super.systemFontsDidChange();
  }

  @override
  void dispose() {
    _parts.dispose();
    super.dispose();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _parts.minIntrinsicWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => _parts.maxIntrinsicWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _parts.heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _parts.heightFor(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _parts.sizeFor(constraints);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _parts.baselineFor(constraints);

  @override
  void performLayout() {
    runLayoutCallback();
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(child.size);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child?.getDistanceToActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child?.hitTest(result, position: position) ?? false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset);
  }
}
