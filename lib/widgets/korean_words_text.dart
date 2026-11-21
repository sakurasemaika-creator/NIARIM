import 'package:flutter/widgets.dart';

import '../utils/line_break.dart';
import 'collection_tile_layout.dart' show copyMarkLineText;

/// 韓国語の語（空白で区切った単位）を途中で折り返さない[Text]。作品・
/// フォルダの名前のように長さの決まっていない文に使う。
///
/// Flutterはハングルのどの字の間でも行を変えるので、詳細表示の名前が
/// 「애니메이션 연 / 습」のように語の途中で切れた。この行の幅に入る語だけを
/// 語結合子でつなぎ（[keepKoreanWordsTogetherWhere]）、入らない長い語は今までどおり
/// 字の間で折り返す。読み上げと文での検索には元の文を渡す。ハングルの無い
/// 文は普通の[Text]。
class KoreanWordsText extends StatelessWidget {
  const KoreanWordsText(
    this.data, {
    super.key,
    this.style,
    this.breakAtFileSeparators = false,
    this.copyMarks = const [],
    this.keepJapaneseLineStarts = false,
  });

  /// 描く文。
  final String data;

  /// [Text.style]と同じ。
  final TextStyle? style;

  /// ファイル名として、区切りの記号（「_」「.」「-」）の前で行を変えて
  /// よいようにするか（[breakableAtFileSeparators]）。ハングルの無い名前だけ。
  final bool breakAtFileSeparators;

  /// [data]の中の、行の途中で切らない複製の名前の印と拡張子（「(コピー 2)」
  /// 「（副本）.png」。`copyMarkParts`）。行の1行に入らない印は、印の字の間で
  /// だけ折り返す（[copyMarkLineText]。番号は印から離さず、拡張子の中では
  /// 切らない）。印の中は[breakAtFileSeparators]でも折り返さない。
  final List<String> copyMarks;

  /// 長音（ー）・小書きの仮名（ッ・ョ等）を行の頭にしない
  /// （[keepJapaneseLineStartsAttached]。作品・フォルダ・ファイルの名前）。
  /// 読み上げと文での検索は元の文のまま。
  final bool keepJapaneseLineStarts;

  @override
  Widget build(BuildContext context) {
    if (!containsHangul(data) && copyMarks.isEmpty) {
      final separated = breakAtFileSeparators
          ? breakableAtFileSeparators(data)
          : data;
      // 名前の長音・小書きの仮名は行の頭に来ない（「ファーストショ / ット」）。
      final shown = keepJapaneseLineStarts
          ? keepJapaneseLineStartsAttached(separated)
          : separated;
      if (shown == data) return Text(data, style: style);
      return Text.rich(
        TextSpan(text: shown, semanticsLabel: data),
        style: style,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        var drawn = DefaultTextStyle.of(context).style.merge(style);
        if (MediaQuery.boldTextOf(context)) {
          drawn = drawn.merge(const TextStyle(fontWeight: FontWeight.bold));
        }
        final painter = TextPainter(
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          locale: Localizations.maybeLocaleOf(context),
        );
        bool fits(String word) {
          painter
            ..text = TextSpan(text: word, style: drawn)
            ..layout();
          return painter.width <= constraints.maxWidth;
        }

        // 印は、途中で折り返せない部分がどれも行に入るかで形を選ぶ。
        bool markFits(String mark) {
          painter
            ..text = TextSpan(text: mark, style: drawn)
            ..layout();
          return painter.minIntrinsicWidth <= constraints.maxWidth;
        }

        String words(String text) {
          final kept = keepKoreanWordsTogetherWhere(
            breakAtFileSeparators ? breakableAtFileSeparators(text) : text,
            fits,
          );
          return keepJapaneseLineStarts
              ? keepJapaneseLineStartsAttached(kept)
              : kept;
        }

        final shown = StringBuffer();
        var start = 0;
        while (start < data.length) {
          var at = -1;
          var mark = '';
          for (final candidate in copyMarks) {
            if (candidate.isEmpty) continue;
            final index = data.indexOf(candidate, start);
            if (index >= 0 &&
                (at < 0 ||
                    index < at ||
                    (index == at && candidate.length > mark.length))) {
              at = index;
              mark = candidate;
            }
          }
          if (at < 0) {
            shown.write(words(data.substring(start)));
            break;
          }
          shown
            ..write(words(data.substring(start, at)))
            ..write(copyMarkLineText(mark, markFits));
          start = at + mark.length;
        }
        painter.dispose();
        return Text.rich(
          TextSpan(text: shown.toString(), semanticsLabel: data),
          style: style,
        );
      },
    );
  }
}
