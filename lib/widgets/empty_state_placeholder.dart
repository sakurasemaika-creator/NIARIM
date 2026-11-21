import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/font_fallback.dart';
import '../config/accent_text_theme.dart';
import '../utils/line_break.dart';

/// Centers an empty state in the space after its header. When the contents
/// need more room, the outer scroll view can scroll through the full height.
class EmptyStateSliver extends StatelessWidget {
  const EmptyStateSliver({
    super.key,
    required this.builder,
    this.clearance = 0,
  });

  final Widget Function(Size availableSize) builder;
  final double clearance;

  @override
  Widget build(BuildContext context) => SliverFillRemaining(
    // Let the viewport calculate the true remaining height after all preceding
    // slivers (including overlap and scroll offset). Keep the remaining area
    // scrollable as well: at large text scales the empty-state copy can be
    // taller than the viewport even after its badge has been reduced. Without
    // an inner scroll viewport, hasScrollBody:false lays that child out as a
    // non-scrollable box and clips/overflows the last lines.
    hasScrollBody: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = math.max(
          0.0,
          constraints.maxHeight - clearance,
        );
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(bottom: clearance),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: builder(Size(constraints.maxWidth, availableHeight)),
            ),
          ),
        );
      },
    ),
  );
}

/// 一覧画面が空のときに表示する共通プレースホルダー。円形の色付き
/// アイコンバッジ・くらむぼんの太字タイトル・淡色の補足文という構成を、
/// プロジェクト一覧・共有一覧・ゴミ箱一覧・作品一覧・素材一覧など
/// すべての一覧画面で統一するために切り出している。
class EmptyStatePlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;

  /// 次にできること（絞り込みを外す等）のボタン。
  final Widget? action;

  /// Whether this widget supplies its own scroll viewport. A sizing sliver
  /// can own scrolling instead by setting this to false.
  final bool scrollable;

  /// 画面の下に浮かぶ丸いボタン（ホームの「一番上へ」・＋）の分、中身の下を
  /// 空けるか。空けた所はスクロールする中身の一部なので、見える所は狭く
  /// ならず、中身は空けた所より上で真ん中にそろう（低い画面・大きな文字では
  /// スクロールして浮かぶボタンの上へ出せる）。
  final bool clearFloatingButtons;

  /// 自分でスクロールしない（[scrollable]が偽の）ときに、丸い印を選ぶ大きさ
  /// （外の一覧の残りの幅と高さ）。渡すと、自分でスクロールするときと同じく
  /// 入る大きさの印にする（低い画面・大きな文字で、案内が浮かぶボタンの下へ
  /// 押し出されない）。
  final Size? fitIn;

  const EmptyStatePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    this.scrollable = true,
    this.clearFloatingButtons = false,
    this.fitIn,
  });

  /// 浮かぶボタンの分（ボタン56・下の余白16・間16）と、ボタンが上に浮く
  /// 画面の下の帯（ジェスチャーの帯・ボタンの帯）の高さ。
  double _floatingButtonsClearance(BuildContext context) =>
      clearFloatingButtons ? 88 + MediaQuery.paddingOf(context).bottom : 0;

  static const double _maxTextWidth = 432;

  /// 中央にそろえた文。韓国語は語（空白で区切った単位）の途中で折り返さない
  /// （「프로젝트가 없습니／다」と切れていた）。描く文にだけ語結合子を入れ、
  /// 読み上げと文での検索には元の文を渡す。ハングルの無い文は普通の[Text]。
  static Widget _centredText(String text, TextStyle style) {
    final shown = keepKoreanWordsTogether(text);
    if (shown == text) {
      return Text(text, textAlign: TextAlign.center, style: style);
    }
    return Text.rich(
      TextSpan(text: shown, semanticsLabel: text),
      textAlign: TextAlign.center,
      style: style,
    );
  }

  /// 低い画面（横向きのスマホ・小さな窓、大きな文字）か。画面の高さを文字の
  /// 倍率で割った高さで見る。低い画面では丸い印を小さくし、上下の余白を
  /// 詰める（88pxの印と24pxの余白のままだと、印が見える高さを取り、見出し・
  /// 案内が画面の下の端や浮かぶボタンの所で切れた）。部品の大きさではなく
  /// 画面の大きさで決めるので、中身の高さを測らせる一覧
  /// （[scrollable]が偽）の中でも使える。
  static bool _short(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return MediaQuery.sizeOf(context).height / (scale < 1 ? 1 : scale) < 480;
  }

  TextStyle _titleStyle(BuildContext context, ColorScheme scheme) =>
      localizedHeadingStyle(
        context,
        TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      );

  TextStyle _hintStyle(ColorScheme scheme) =>
      TextStyle(color: scheme.onSurfaceVariant, fontSize: 14);

  /// 丸い印の大きさ（0なら印を出さない）ごとの、上下の余白と印の下の間。
  static EdgeInsets _padding(double badge) => badge >= 88
      ? const EdgeInsets.all(24)
      : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);

  static double _badgeGap(double badge) =>
      badge >= 88 ? 16 : (badge > 0 ? 8 : 0);

  /// 自分でスクロールする（高さの分かる）ときに、高さ[maxHeight]・幅
  /// [maxWidth]に入る一番大きな丸い印（88・56・無し）。文の高さは描くときと
  /// 同じ書式・文字の倍率で測る。どれも入らなければ印を出さない（文が
  /// スクロールせずに見える所を広く取る）。
  double _badgeThatFits(
    BuildContext context,
    double maxWidth,
    double maxHeight,
    ColorScheme scheme,
  ) {
    final texts = _textsHeight(context, maxWidth, scheme);
    for (final badge in const [88.0, 56.0]) {
      if (_padding(badge).vertical + badge + _badgeGap(badge) + texts <=
          maxHeight) {
        return badge;
      }
    }
    return 0;
  }

  /// 印を出さなくても、見出し・案内・操作のボタンが高さ[maxHeight]に入らない
  /// か。入らないときは、操作のボタンを見出しのすぐ下（案内の上）に置く
  /// （案内の後に置くと、大きな文字で「検索をやめる」が画面の下・浮かぶ
  /// ボタンの下へ押し出され、スクロールしないと押せなかった）。
  bool _actionFirst(
    BuildContext context,
    double maxWidth,
    double maxHeight,
    ColorScheme scheme,
  ) =>
      action != null &&
      hint != null &&
      _padding(0).vertical + _textsHeight(context, maxWidth, scheme) >
          maxHeight;

  /// 見出し・案内・操作のボタンを並べた高さ（幅[maxWidth]、印は除く）。
  double _textsHeight(
    BuildContext context,
    double maxWidth,
    ColorScheme scheme,
  ) {
    final base = DefaultTextStyle.of(context).style;
    final painter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    double heightOf(String text, TextStyle style) {
      painter
        ..text = TextSpan(
          text: keepKoreanWordsTogether(text),
          style: base.merge(style),
        )
        ..layout(maxWidth: math.min(_maxTextWidth, math.max(0, maxWidth - 48)));
      return painter.height;
    }

    final texts =
        heightOf(title, _titleStyle(context, scheme)) +
        (hint == null ? 0 : 8 + heightOf(hint!, _hintStyle(scheme))) +
        // 操作のボタン（高さ48の押せる所）の分。大きな文字（1.5倍より上）
        // では、ボタンの名前が2行に折れることがある（仏語の「Effacer la
        // recherche」）ので2行分と見る。
        (action == null
            ? 0
            : 16 +
                  MediaQuery.textScalerOf(context).scale(20) *
                      (MediaQuery.textScalerOf(context).scale(1) > 1.5
                          ? 2
                          : 1) +
                  28);
    painter.dispose();
    return texts;
  }

  Widget _content(
    BuildContext context,
    ColorScheme scheme,
    double badge, {
    bool actionFirst = false,
  }) => Padding(
    padding: _padding(badge),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (badge > 0)
          Container(
            width: badge,
            height: badge,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: badge * 40 / 88,
              color: AccentTextTheme.of(context),
            ),
          ),
        SizedBox(height: _badgeGap(badge)),
        Semantics(
          header: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxTextWidth),
            child: _centredText(title, _titleStyle(context, scheme)),
          ),
        ),
        if (actionFirst && action != null) ...[
          const SizedBox(height: 16),
          action!,
        ],
        if (hint != null) ...[
          SizedBox(height: actionFirst ? 16 : 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxTextWidth),
            child: _centredText(hint!, _hintStyle(scheme)),
          ),
        ],
        if (!actionFirst && action != null) ...[
          const SizedBox(height: 16),
          action!,
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenBadge = _short(context) ? 56.0 : 88.0;
    final clearance = _floatingButtonsClearance(context);
    if (!scrollable) {
      var badge = screenBadge;
      var actionFirst = false;
      if (fitIn case final size?) {
        final fits = _badgeThatFits(
          context,
          size.width,
          size.height - clearance,
          scheme,
        );
        if (fits < badge) badge = fits;
        actionFirst = _actionFirst(
          context,
          size.width,
          size.height - clearance,
          scheme,
        );
      }
      return Padding(
        padding: EdgeInsets.only(bottom: clearance),
        child: _content(context, scheme, badge, actionFirst: actionFirst),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 高さが分かるときは、入る大きさの印にする（画面の高さで決めた
        // 大きさより大きくはしない）。
        var badge = screenBadge;
        var actionFirst = false;
        if (constraints.hasBoundedHeight && constraints.hasBoundedWidth) {
          final fits = _badgeThatFits(
            context,
            constraints.maxWidth,
            constraints.maxHeight - clearance,
            scheme,
          );
          if (fits < badge) badge = fits;
          actionFirst = _actionFirst(
            context,
            constraints.maxWidth,
            constraints.maxHeight - clearance,
            scheme,
          );
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            // 幅も使える分いっぱいに取る。Scaffoldのbodyは幅を「最大まで」
            // としか渡さないので、取らないと中身の幅に縮んで左へ寄る。
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
              minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: clearance),
              child: _content(context, scheme, badge, actionFirst: actionFirst),
            ),
          ),
        );
      },
    );
  }
}
