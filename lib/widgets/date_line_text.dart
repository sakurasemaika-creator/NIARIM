import 'package:flutter/widgets.dart';

import '../utils/line_break.dart';

/// 日時（[when]を日付`yMd`と時刻`jm`の書き方で含む文）を、日付・時刻・
/// [keep]（数と単位「10秒」など）と韓国語の語の途中で折り返さずに描く
/// [Text]（詳細表示の行の2行目など）。
///
/// 狭い行・大きな文字で、「2026. 11. 13. 오 / 후 6:19」のように午後（오후）の
/// 途中で切れていた。この行の幅に入る日付・時刻・語だけをかたまりにし、
/// 入らないものは今までどおり中の空白・字の間で折り返す（行に入らない
/// かたまりは「13 / .」のように字の途中で切れるため）。読み上げは元の文。
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
      final shown = keepPartsTogether(
        keepDateTimeTogether(data, when, localeName, fits: fits),
        keep,
        fits: fits,
      );
      painter.dispose();
      return Text(shown, semanticsLabel: data);
    },
  );
}
