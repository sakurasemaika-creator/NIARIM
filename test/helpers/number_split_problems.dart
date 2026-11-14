import 'package:flutter/rendering.dart';

/// 途中で行を変えてはいけない数のかたまり：解像度（「1280×720」）、日付
/// （「2026/11/10」「10/11/2026」「2026. 11. 10.」）、時刻（「19:29」
/// 「下午7:29」「오후 7:29」「7:29 PM」）、小数（「1.4KB」）、倍率（「2.0×」）、
/// 数とすぐ後の単位（「120」「1秒」「25分」「1小时」「12fps」「0시간」）。
final RegExp numberChunk = RegExp(
  r'(?:(?:上午|下午|中午|凌晨|早上|晚上|午前|午後|오전|오후)[ \u00a0\u202f]?)?'
  r'\d+(?:[.,:/×][ \u00a0\u202f]?\d+)*\.?'
  r'(?:[ \u00a0\u202f]?(?:AM|PM|a\.\sm\.|p\.\sm\.))?'
  r'(?:[×]|[A-Za-z]{1,3}|\p{Script=Han}{1,3}|\p{Script=Hiragana}{1,3}'
  r'|[\p{Script=Katakana}ー]{1,3}|\p{Script=Hangul}{1,3})?',
  unicode: true,
);

/// 行を変えない印（語結合子・幅の無い空白）。描いた文から除いて比べる。
const String _invisible = '\u2060\u200b';

/// 描かれた段落[p]の中で、[numberChunk]（と[extra]に挙げた文）の途中で
/// 行が変わっている所。無ければ空。
List<String> numberSplitProblems(
  RenderParagraph p, {
  Iterable<String> extra = const [],
}) {
  final shown = p.text.toPlainText(includePlaceholders: false);
  // 描いた文の位置→語結合子を除いた文の位置。
  final plain = StringBuffer();
  final plainAt = <int>[];
  for (var i = 0; i < shown.length; i++) {
    plainAt.add(plain.length);
    if (!_invisible.contains(shown[i])) plain.write(shown[i]);
  }
  plainAt.add(plain.length);
  final text = plain.toString();
  final painter = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    textAlign: p.textAlign,
    locale: p.locale,
    maxLines: p.maxLines,
    strutStyle: p.strutStyle,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  )..layout(maxWidth: p.softWrap ? p.constraints.maxWidth : double.infinity);
  final starts = <int>[
    for (final line in painter.computeLineMetrics().skip(1))
      plainAt[painter
          .getPositionForOffset(
            Offset(0, line.baseline - line.ascent + line.height / 2),
          )
          .offset
          .clamp(0, shown.length)],
  ];
  painter.dispose();
  if (starts.isEmpty) return const [];
  final ranges = <(int, int)>[
    for (final m in numberChunk.allMatches(text)) (m.start, m.end),
    for (final part in extra)
      if (part.isNotEmpty)
        for (
          var at = text.indexOf(part);
          at >= 0;
          at = text.indexOf(part, at + 1)
        )
          (at, at + part.length),
  ];
  final out = <String>[];
  for (final (start, end) in ranges) {
    // かたまりの前後の空白は数えない（「2026. 11. 10. 」の後ろ）。
    final chunk = text.substring(start, end).trimRight();
    final stop = start + chunk.length;
    for (final at in starts) {
      if (start < at && at < stop) {
        out.add(
          '«${text.replaceAll('\n', ' ')}»の「$chunk」が'
          '「${text.substring(start, at)} / ${text.substring(at, stop)}」と折れる',
        );
        break;
      }
    }
  }
  return out;
}
