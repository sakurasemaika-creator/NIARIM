import 'package:flutter/widgets.dart';

/// 文の中の[keep]に挙げた部分（数と単位など）を、行の途中で切らずに1つの
/// かたまりとして描く[Text]。
///
/// 日本語・中国語・韓国語は字と字の間のどこでも行を変えてよいので、
/// 「確定価格（交換準備中） · 55000コイン」が「…55000コイ」「ン」のように
/// 単位の途中で切れる。[keep]の部分は折り返さない1つの字のように並べ、
/// 行に入りきらなければ、その前で行を変える。
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

  @override
  Widget build(BuildContext context) {
    final text = data!;
    final defaultStyle = DefaultTextStyle.of(context);
    var effectiveStyle = style == null || style!.inherit
        ? defaultStyle.style.merge(style)
        : style!;
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final locale = Localizations.maybeLocaleOf(context);
    final pieces = <InlineSpan>[];
    var kept = false;
    var start = 0;
    while (start < text.length) {
      final (at, part) = _nextKept(text, start);
      if (at < 0) {
        pieces.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (at > start) pieces.add(TextSpan(text: text.substring(start, at)));
      pieces.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          // 埋め込んだ部品は文字の大きさの倍率ぶん拡大して並べられるので、
          // 中の文字には倍率を掛けない（掛けると二重に大きくなる）。
          child: RichText(
            text: TextSpan(text: part, style: effectiveStyle),
            softWrap: false,
            textScaler: TextScaler.noScaling,
            locale: locale,
          ),
        ),
      );
      kept = true;
      start = at + part.length;
    }
    if (!kept) return super.build(context);
    // 段落そのものには行の高さ（height）を付けず、文字にだけ付ける。
    // 段落に付けると、かたまりだけが載った行の上に余白が足され、その行だけ
    // 字が数px下がった（文字の行の高さ・位置は文字に付けた高さで決まる）。
    final paragraph = TextStyle(
      inherit: false,
      fontFamily: effectiveStyle.fontFamily,
      fontFamilyFallback: effectiveStyle.fontFamilyFallback,
      fontSize: effectiveStyle.fontSize,
      fontWeight: effectiveStyle.fontWeight,
      fontStyle: effectiveStyle.fontStyle,
      textBaseline: effectiveStyle.textBaseline,
      leadingDistribution: effectiveStyle.leadingDistribution,
      locale: effectiveStyle.locale,
    );
    return Semantics(
      textDirection: textDirection,
      // 文全体を1つの文として読み上げる。
      label: semanticsLabel ?? text,
      child: ExcludeSemantics(
        child: RichText(
          textAlign: textAlign ?? defaultStyle.textAlign ?? TextAlign.start,
          textDirection: textDirection,
          softWrap: defaultStyle.softWrap,
          overflow: effectiveStyle.overflow ?? defaultStyle.overflow,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: defaultStyle.maxLines,
          locale: locale,
          textWidthBasis: defaultStyle.textWidthBasis,
          textHeightBehavior:
              defaultStyle.textHeightBehavior ??
              DefaultTextHeightBehavior.maybeOf(context),
          text: TextSpan(
            style: paragraph,
            children: [TextSpan(style: effectiveStyle, children: pieces)],
          ),
        ),
      ),
    );
  }
}
