import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../utils/line_break.dart';

/// 値の中で途中で行を変えない数のかたまり：解像度（「1280×720」）、日付
/// （「2026/11/10」「2026. 11. 10.」）、時刻（「19:29」「下午7:29」
/// 「오후 7:29」「7:29 PM」。午前・午後の語は`DateFormat.jm`が書くもの）、
/// 小数（「1.4KB」）、倍率（「(2.0×)」）、数とすぐ後の単位（「120」「25分」
/// 「1小时」「0시간」）。すぐ外の括弧も含める（「(2.0倍)」を「(2.0」と
/// 「倍)」に分けない）。
final RegExp _numberChunk = RegExp(
  r'[(（]?'
  r'(?:(?:上午|下午|午前|午後|오전|오후)[ \u00A0\u202F]?)?'
  r'\d+(?:[.,:/×][ \u00A0\u202F]?\d+)*\.?'
  r'(?:[ \u00A0\u202F]?(?:AM|PM|am|pm))?'
  r'(?:×|[A-Za-z]{1,3}|\p{Script=Han}{1,3}|\p{Script=Hiragana}{1,3}'
  r'|[\p{Script=Katakana}ー]{1,3}|\p{Script=Hangul}{1,3})?'
  r'[)）]?',
  unicode: true,
);

/// 字の間で折り返せる字（漢字・かな・ハングル）。
final RegExp _cjk = RegExp(
  r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uAC00-\uD7A3]',
);

/// 項目名と値を1行に並べる、情報のカードの行（「書き出しサイズ　1280×720」）。
///
/// 値の中の数のかたまり（解像度「W×H」、数と単位、大きさ、日付・時刻）は
/// 途中で折り返さない。項目名を1行で置き、残りの幅に値のどのかたまりも
/// 入るなら横に並べ（値はかたまりの間・日付と時刻の間で折り返す）、入らなければ
/// 値を項目名の下の行へ回す（行の終わりにそろえる）。項目名は下の行へ回すと
/// きだけ、行の幅で折り返す。
///
/// 以前は項目名と値を行の幅の半分ずつの列に並べていたので、字の広い書体
/// （中国語の本文のNoto Serif SC）・大きな文字では値の列が数より狭くなり、
/// 「1280×7 / 20」「2026/11/ / 10 19:29」と数の途中で切れた（項目名も
/// 「Dernier enregistre / ment」と語の途中で切れた）。
///
/// 値が1行に入るときはそのままの文で描き、折り返すときだけかたまりの字の間に
/// 語結合子を挟む（[keepPartsTogether]。読み上げは元の文）。
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.keep = const [],
    this.gap = 8,
  });

  /// 項目名。
  final String label;

  /// 値。
  final String value;

  /// 項目名の書式（[DefaultTextStyle]に重ねる）。
  final TextStyle? labelStyle;

  /// 値の書式（[DefaultTextStyle]に重ねる）。
  final TextStyle? valueStyle;

  /// 値の中で、数のかたまりのほかに途中で折らない部分（日付・時刻の書き方
  /// 〔`DateFormat.yMd`・`jm`〕など）。
  final List<String> keep;

  /// 横に並べるときの項目名と値の間。
  final double gap;

  /// [value]の中の途中で折らない部分の範囲（重なるものはまとめる）。
  List<(int, int)> _ranges() {
    final ranges = <(int, int)>[
      for (final m in _numberChunk.allMatches(value)) (m.start, m.end),
      for (final part in keep)
        if (part.isNotEmpty && value.contains(part))
          (value.indexOf(part), value.indexOf(part) + part.length),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final (start, end) in ranges) {
      if (merged.isNotEmpty && start < merged.last.$2) {
        merged.last = (merged.last.$1, math.max(merged.last.$2, end));
      } else {
        merged.add((start, end));
      }
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final base = DefaultTextStyle.of(context).style;
      var labelFull = base.merge(labelStyle);
      var valueFull = base.merge(valueStyle);
      if (MediaQuery.boldTextOf(context)) {
        const bold = TextStyle(fontWeight: FontWeight.bold);
        labelFull = labelFull.merge(bold);
        valueFull = valueFull.merge(bold);
      }
      final painter = TextPainter(
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
        locale: Localizations.maybeLocaleOf(context),
      );
      double widthOf(String text, TextStyle style) {
        painter
          ..text = TextSpan(text: text, style: style)
          ..layout();
        return painter.width;
      }

      final width = constraints.maxWidth;
      // かたまりは字の間に語結合子を挟んだ文で測る（語結合子にも字の間隔が
      // 付く）。1行に入らないかたまりはつながない（字の間で折るしかない）。
      final shown = StringBuffer();
      var widest = 0.0;
      var at = 0;
      for (final (start, end) in _ranges()) {
        final part = value.substring(start, end);
        final kept = keepPartsTogether(part, [part]);
        final keptWidth = widthOf(kept, valueFull);
        final fits = !width.isFinite || keptWidth <= width;
        shown
          ..write(value.substring(at, start))
          ..write(fits ? kept : part);
        if (fits) widest = math.max(widest, keptWidth);
        at = end;
      }
      shown.write(value.substring(at));
      // 空白で区切られた欧文の語も途中で折らない（漢字・かなの語は字の間で
      // 折れる）。
      for (final word in value.split(RegExp(r'\s'))) {
        if (word.isEmpty || _cjk.hasMatch(word)) continue;
        widest = math.max(widest, widthOf(word, valueFull));
      }
      final labelWidth = widthOf(label, labelFull);
      final beside = !width.isFinite || labelWidth + gap + widest <= width;
      final oneLine =
          !width.isFinite ||
          widthOf(value, valueFull) <=
              (beside ? width - gap - labelWidth : width);
      painter.dispose();
      final labelText = Text(label, style: labelStyle);
      final valueText = Text(
        oneLine ? value : shown.toString(),
        semanticsLabel: oneLine ? null : value,
        style: valueStyle,
        textAlign: TextAlign.end,
      );
      if (beside) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            labelText,
            SizedBox(width: gap),
            Expanded(child: valueText),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [labelText, valueText],
      );
    },
  );
}
