import 'package:flutter/material.dart';

/// アプリバーの題（画面名）。その幅に入るときはそのまま出し、入らないときは
/// 出さない（省略記号で「プロジ…」と切らない）。出さないときも、読み上げの
/// 見出しの名前は元の画面名のまま。
///
/// 所有者の判断4（2026-11-11）：「画面名が入らないときは画面名は書かなくて
/// いいです。書かなくても実際の画面を見たり操作したりしていれば今自分が
/// どこにいるのかわからないことはないと思います。」
///
/// アプリバーの`title`に置く（題の文字の書式・文字の大きさはアプリバーが
/// 決めたものをそのまま使って測る）。
class FitOrHideTitle extends StatelessWidget {
  const FitOrHideTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: DefaultTextStyle.of(context).style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        if (fits) return Text(text);
        // 題の場所は空けたまま、読み上げでは画面名を読み、マウスを重ねれば
        // 画面名を出す。
        return Tooltip(
          message: text,
          excludeFromSemantics: true,
          child: Semantics(
            label: text,
            child: SizedBox(
              width: constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
              height: kToolbarHeight / 2,
            ),
          ),
        );
      },
    );
  }
}

/// アプリバーのデータの題（作品名・作者名・プリセット名など）。画面名と違い
/// 隠さず、入らないときは1行で「…」にする（所有者の判断4の決まり）。そのとき
/// だけ、題を押す・長押しする・マウスを重ねると全部の名前を吹き出しで出す
/// （以前は作品詳細の題が「Bouncing B…」のまま、全部の名前を見る所が無かった）。
/// 読み上げは元から全部の名前を読む。
///
/// アプリバーの`title`に置く（[FitOrHideTitle]と同じく、アプリバーが決めた
/// 書式で測る）。
class DataTitle extends StatelessWidget {
  const DataTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: DefaultTextStyle.of(context).style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 1,
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        if (fits) return title;
        return Tooltip(
          key: const Key('dataTitleFullName'),
          message: text,
          triggerMode: TooltipTriggerMode.tap,
          excludeFromSemantics: true,
          child: title,
        );
      },
    );
  }
}
