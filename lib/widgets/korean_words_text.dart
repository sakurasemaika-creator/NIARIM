import 'package:flutter/widgets.dart';

import '../utils/line_break.dart';

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
  });

  /// 描く文。
  final String data;

  /// [Text.style]と同じ。
  final TextStyle? style;

  /// ファイル名として、区切りの記号（「_」「.」「-」）の前で行を変えて
  /// よいようにするか（[breakableAtFileSeparators]）。ハングルの無い名前だけ。
  final bool breakAtFileSeparators;

  @override
  Widget build(BuildContext context) {
    if (!containsHangul(data)) {
      final shown = breakAtFileSeparators
          ? breakableAtFileSeparators(data)
          : data;
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
        final shown = keepKoreanWordsTogetherWhere(data, (word) {
          painter
            ..text = TextSpan(text: word, style: drawn)
            ..layout();
          return painter.width <= constraints.maxWidth;
        });
        painter.dispose();
        return Text.rich(
          TextSpan(text: shown, semanticsLabel: data),
          style: style,
        );
      },
    );
  }
}
