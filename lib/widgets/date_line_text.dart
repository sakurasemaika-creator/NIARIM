import 'package:flutter/widgets.dart';

import '../utils/line_break.dart';

/// 数と、続く日本語・中国語の単位（「1秒」等。空白で区切られた1語）。
final RegExp _numberWithUnit = RegExp(
  r'^[0-9]+(?:[.,][0-9]+)?[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF]+$',
);

/// 日時の行の、日付・時刻に添える日本語・中国語の語（「更新」「创建」等。
/// 空白で区切られ、数を含まない語）。[DateLineText.keep]へ渡すと、行の幅に
/// 入るときは字の途中で折り返さない（「创 / 建」と1字だけ次の行へ落ちた）。
/// 作品・フォルダの名前を含む行には使わないこと。
List<String> dateLabelWords(String line) => [
  for (final word in line.split(RegExp(r'\s+')))
    if (_cjkLetter.hasMatch(word) && !_digit.hasMatch(word)) word,
];

final RegExp _cjkLetter = RegExp(r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF]');
final RegExp _digit = RegExp(r'[0-9]');

/// 日時（[when]を日付`yMd`と時刻`jm`の書き方で含む文）を、日付・時刻・
/// [keep]（数と単位「10秒」など）と韓国語の語、数と日本語・中国語の単位
/// （「1秒」）の途中で折り返さずに描く[Text]（詳細表示の行の2行目など）。
///
/// 狭い行・大きな文字で、「2026. 11. 13. 오 / 후 6:19」のように午後（오후）の
/// 途中で切れていた。日本語・中国語の単位は数との間でも折り返せるので、中国語の
/// 本文の書体（字の広いNoto Serif SC）では「12fps · 1 / 秒」と切れた。この行の
/// 幅に入る日付・時刻・語だけをかたまりにし（数と単位は、途中で行が変わる
/// ときだけ）、入らないものは今までどおり中の空白・字の間で折り返す（行に
/// 入らないかたまりは「13 / .」のように字の途中で切れるため）。読み上げは元の文。
class DateLineText extends StatelessWidget {
  const DateLineText(
    this.data, {
    super.key,
    required this.when,
    required this.localeName,
    this.keep = const [],
  });

  /// 描く文（改行を含んでよい）。
  final String data;

  /// [data]に含まれる日時。
  final DateTime when;

  /// [data]の日時を書いた言語（`AppLocalizations.localeName`）。
  final String localeName;

  /// 日時のほかに、行の途中で切らない部分（数と単位など。行の幅に入るときだけ
  /// かたまりにする）。作品・フォルダの名前は入れない（名前の中の「第1話」等を
  /// かたまりにしない）。
  final List<String> keep;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var style = DefaultTextStyle.of(context).style;
      if (MediaQuery.boldTextOf(context)) {
        style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
      }
      final painter = TextPainter(
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
        locale: Localizations.maybeLocaleOf(context),
      );
      bool fits(String part) {
        painter
          ..text = TextSpan(text: part, style: style)
          ..layout();
        return painter.width <= constraints.maxWidth;
      }

      // [keep]（「12fps · 10秒」の「10秒」）も行の途中で切らない（ja
      // 360pxで「10 / 秒」と切れていた）。
      var shown = keepPartsTogether(
        keepDateTimeTogether(data, when, localeName, fits: fits),
        keep,
        fits: fits,
      );
      // 数と単位（「1秒」）は、この幅で並べたときに途中で行が変わるものだけを
      // かたまりにする（行に収まっている文は変えない）。かたまりにすると後ろの
      // 行も変わるので、途中で行が変わるものが無くなるまで繰り返す。
      for (var round = 0; round < 8; round++) {
        painter
          ..text = TextSpan(text: shown, style: style)
          ..layout(maxWidth: constraints.maxWidth);
        final starts = [
          for (final line in painter.computeLineMetrics().skip(1))
            painter
                .getPositionForOffset(
                  Offset(0, line.baseline - line.ascent + line.height / 2),
                )
                .offset,
        ];
        Match? broken;
        for (final match in RegExp(r'\S+').allMatches(shown)) {
          final word = match[0]!;
          if (!_numberWithUnit.hasMatch(word)) continue;
          if (starts.any((at) => match.start < at && at < match.end) &&
              fits(keepPartsTogether(word, [word]))) {
            broken = match;
            break;
          }
        }
        if (broken == null) break;
        shown = shown.replaceRange(
          broken.start,
          broken.end,
          keepPartsTogether(broken[0]!, [broken[0]!]),
        );
      }
      painter.dispose();
      return Text(shown, semanticsLabel: data);
    },
  );
}
