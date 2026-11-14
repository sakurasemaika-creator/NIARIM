import 'package:flutter/material.dart';

/// [FitOrIconTabBar]の1つのタブ。
class FitOrIconTab {
  const FitOrIconTab({required this.icon, required this.label, this.wrap});

  /// 名前が入らない幅で出すアイコン。
  final IconData icon;

  /// タブの名前（入らない幅では吹き出しと読み上げに出す）。
  final String label;

  /// タブを包む部品（初回の説明の吹き出し等）。
  final Widget Function(Widget tab)? wrap;
}

/// 名前が全部入る幅では名前を、1つでも入らない幅ではどのタブもアイコンだけを
/// 出すタブの並び（ホームのタブと同じ形）。
///
/// 文字は縮めず、省略記号で切らない（所有者の判断3）。アイコンだけのときの
/// 名前は、長押し（タッチ）・ホバー（マウス）の吹き出しと読み上げで伝える。
/// どちらにするかは端末の種類ではなく、測った幅で決める。
class FitOrIconTabBar extends StatelessWidget implements PreferredSizeWidget {
  const FitOrIconTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.labelStyle,
  });

  final List<FitOrIconTab> tabs;
  final TabController? controller;

  /// [TabBar.labelStyle]。名前を測るときも同じ書式を使う。
  final TextStyle? labelStyle;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  /// 幅[width]に名前が全部入るか（タブは同じ幅に分け、左右の余白を除く）。
  bool _namesFit(BuildContext context, double width) {
    final theme = Theme.of(context);
    // TabBarの文字は、既定の書式（Material 3はtitleSmall）にlabelStyleを
    // 重ねたもの。
    final style = DefaultTextStyle.of(context).style
        .merge(theme.textTheme.titleSmall)
        .merge(labelStyle ?? TabBarTheme.of(context).labelStyle);
    final cell = width / tabs.length - kTabLabelPadding.horizontal;
    for (final tab in tabs) {
      final painter = TextPainter(
        text: TextSpan(text: tab.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      final fits = painter.width <= cell;
      painter.dispose();
      if (!fits) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final names = _namesFit(context, box.maxWidth);
        return TabBar(
          controller: controller,
          labelStyle: labelStyle,
          tabs: [
            for (final tab in tabs)
              (tab.wrap ?? (t) => t)(
                Tab(
                  child: Semantics(
                    label: tab.label,
                    child: Tooltip(
                      message: tab.label,
                      excludeFromSemantics: true,
                      child: ExcludeSemantics(
                        child: names
                            ? Text(tab.label, maxLines: 1, softWrap: false)
                            : Icon(tab.icon, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
