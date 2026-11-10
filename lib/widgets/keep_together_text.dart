import 'package:flutter/widgets.dart';

/// 文の中の[keep]に挙げた部分（数と単位など）を、行の途中で切らずに1つの
/// かたまりとして描く[Text]。
///
/// 日本語・中国語・韓国語は字と字の間のどこでも行を変えてよいので、
/// 「確定価格（交換準備中） · 55000コイン」が「…55000コイ」「ン」のように
/// 単位の途中で切れる。[keep]の部分は折り返さない1つの字のように並べ、
/// 行に入りきらなければ、その前で行を変える。
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

  /// [data]の中で、途中で行を変えない部分。現れる所はすべて対象。
  final List<String> keep;

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
      // 次に現れる、途中で切らない部分（同じ位置なら長い方）。
      var at = -1;
      var part = '';
      for (final candidate in keep) {
        if (candidate.isEmpty) continue;
        final index = text.indexOf(candidate, start);
        if (index < 0) continue;
        if (at < 0 ||
            index < at ||
            (index == at && candidate.length > part.length)) {
          at = index;
          part = candidate;
        }
      }
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
