import 'package:flutter/widgets.dart';

/// 文の中の[keep]に挙げた部分（数と単位など）を、行の途中で切らずに1つの
/// かたまりとして描く[Text]。
///
/// 日本語・中国語・韓国語は字と字の間のどこでも行を変えてよいので、
/// 「確定価格（交換準備中） · 55000コイン」が「…55000コイ」「ン」のように
/// 単位の途中で切れる。[keep]の部分は字と字の間に幅の無いWORD JOINER
/// （U+2060。前後で行を変えてはいけない字）を挟み、中の空白を改行しない
/// 空白にして描き、行に入りきらなければその前で行を変える（欄そのものより
/// 広いかたまりは、欄の外へはみ出させずに字の間で折る）。
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

  /// 前後で行を変えてはいけない、幅の無い字（WORD JOINER）。
  static const _wordJoiner = '\u2060';

  /// [_wordJoiner]に付ける書式。字の間隔（letterSpacing）は字ごとに足される
  /// ので、[_wordJoiner]にも足すと、かたまりの字の間だけ広がる（Material 3の
  /// 本文の0.25pxで、「55000コイン」が1.75px広がった）。
  static const _joinerStyle = TextStyle(letterSpacing: 0);

  /// 改行しない空白。段落は普通の空白の後ではいつでも行を変えるので
  /// （[_wordJoiner]を挟んでも変える）、途中で切らない部分の空白はこれにする。
  static const _noBreakSpace = '\u00a0';

  /// [text]の途中で切らない部分の字（書記素）と字の間に[_wordJoiner]を
  /// 挟み、部分の中の空白を[_noBreakSpace]にした文。無ければnull。
  List<InlineSpan>? _joined(String text) {
    final pieces = <InlineSpan>[];
    final run = StringBuffer();
    var changed = false;
    void flush() {
      if (run.isEmpty) return;
      pieces.add(TextSpan(text: run.toString()));
      run.clear();
    }

    var start = 0;
    while (start < text.length) {
      final (at, part) = _nextKept(text, start);
      if (at < 0) {
        run.write(text.substring(start));
        break;
      }
      run.write(text.substring(start, at));
      var first = true;
      for (final char in part.characters) {
        if (!first) {
          flush();
          pieces.add(const TextSpan(text: _wordJoiner, style: _joinerStyle));
          changed = true;
        }
        if (char == ' ') {
          run.write(_noBreakSpace);
          changed = true;
        } else {
          run.write(char);
        }
        first = false;
      }
      start = at + part.length;
    }
    flush();
    return changed ? pieces : null;
  }

  @override
  Widget build(BuildContext context) {
    final text = data!;
    final joined = _joined(text);
    if (joined == null) return super.build(context);
    final defaultStyle = DefaultTextStyle.of(context);
    var effectiveStyle = style == null || style!.inherit
        ? defaultStyle.style.merge(style)
        : style!;
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    return Semantics(
      textDirection: textDirection,
      // 文全体を、行を変えないための字を除いた元の文のまま読み上げる。
      label: semanticsLabel ?? text,
      child: ExcludeSemantics(
        child: RichText(
          textAlign: textAlign ?? defaultStyle.textAlign ?? TextAlign.start,
          textDirection: textDirection,
          locale: locale,
          softWrap: defaultStyle.softWrap,
          overflow: effectiveStyle.overflow ?? defaultStyle.overflow,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: defaultStyle.maxLines,
          textWidthBasis: defaultStyle.textWidthBasis,
          textHeightBehavior:
              defaultStyle.textHeightBehavior ??
              DefaultTextHeightBehavior.maybeOf(context),
          text: TextSpan(style: effectiveStyle, children: joined),
        ),
      ),
    );
  }
}
