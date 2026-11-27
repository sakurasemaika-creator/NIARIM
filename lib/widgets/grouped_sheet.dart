import 'package:flutter/material.dart';

import '../config/font_fallback.dart';
import 'keep_together_text.dart';
import 'menu_surface.dart';

/// 意味のまとまった行を1枚の面（シート）に載せる。
///
/// 画面の用紙（パネルの背景色）の上に、メニューの背景色の面を1枚だけ置き、
/// 行どうしは字の始まりから引いた細い線で分ける。行ごとに影のついたカードを
/// 浮かせて隙間で分ける作りにしない（どの行も同じ重さの箱になり、まとまりが
/// 読めない）。影は付けない（浮かぶのはダイアログ・メニュー・知らせ・浮かぶ
/// ボタンだけ）。
///
/// [title]は面の上に置くまとまりの名前（見出しとして読み上げる）、[footer]は
/// 面の下に置く補足。面の中はメニューの面のテーマ（[MenuSurface]）で描くので、
/// 本文とメニューの文字色を分けたテーマでも、行の文字はメニューの文字色になる。
class GroupedSheet extends StatelessWidget {
  const GroupedSheet({
    super.key,
    this.title,
    this.footer,
    required this.children,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;

  /// 面の角の丸み。
  static const double radius = 16;

  /// 行の左右の余白（まとまりの名前・補足もこの位置から書き始める）。
  static const double rowInset = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sheetColor = theme.cardTheme.color ?? scheme.surface;
    final rule =
        theme.dividerTheme.color ?? scheme.outlineVariant.withValues(alpha: .6);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        final next = children[i];
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: next is SheetRow ? next.textStart : rowInset,
          ),
        );
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              rowInset,
              0,
              rowInset,
              8,
            ),
            child: Semantics(
              header: true,
              child: messageText(
                title!,
                keepLineStarts: true,
                style: localizedHeadingStyle(
                  context,
                  TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        MenuSurface(
          child: Material(
            color: sheetColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: rule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              rowInset,
              8,
              rowInset,
              0,
            ),
            child: messageText(
              footer!,
              keepLineStarts: true,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// [GroupedSheet]の1行：先頭の印・名前・補足・末尾（値・スイッチ・矢印）。
///
/// 先頭の印は差し色の下地に載せず、補助の文字色で描く（差し色は押せる主な
/// 操作・選んでいる状態・リンクのためにとっておく）。押せる行で[trailing]が
/// 無ければ、行の先へ進むことを表す矢印を末尾に出す。
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron,
    this.enabled = true,
  });

  final IconData? icon;

  /// [icon]の代わりに置く部品（Font Awesomeの印など）。24pxの枠に収める。
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 末尾の矢印。省略すると「押せて、[trailing]が無い」ときだけ出す。
  final bool? showChevron;

  /// 偽なら押せない行として薄く描く（Materialの使えない部品と同じ38%）。
  /// 矢印は残し、押せるようになれば先へ進む行だと分かるようにする。
  final bool enabled;

  static const double _iconBox = 24;
  static const double _iconGap = 16;

  bool get _hasLeading => icon != null || leading != null;

  /// 行の名前が書き始まる位置（区切りの線をここから引く）。
  double get textStart =>
      GroupedSheet.rowInset + (_hasLeading ? _iconBox + _iconGap : 0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chevron = showChevron ?? (onTap != null && trailing == null);
    final tap = enabled ? onTap : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
        // 狭い幅・大きな文字では印を外して名前の幅を取る（名前が語の途中で
        // 折れるより、印が無い方が読める）。
        final showLeading =
            _hasLeading && constraints.maxWidth / textScale >= 232;
        final row = InkWell(
          onTap: tap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: subtitle == null ? 56 : 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GroupedSheet.rowInset,
                vertical: 12,
              ),
              child: Row(
                children: [
                  if (showLeading) ...[
                    SizedBox.square(
                      dimension: _iconBox,
                      child: Center(
                        child: IconTheme.merge(
                          data: IconThemeData(
                            size: 22,
                            color: scheme.onSurfaceVariant,
                          ),
                          child: leading ?? Icon(icon),
                        ),
                      ),
                    ),
                    const SizedBox(width: _iconGap),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        messageText(
                          title,
                          keepLineStarts: true,
                          keepLastPhrase: true,
                          style: localizedHeadingStyle(
                            context,
                            const TextStyle(fontSize: 15, height: 1.3),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          messageText(
                            subtitle!,
                            keepLineStarts: true,
                            keepLastPhrase: true,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                  if (chevron) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
        if (enabled) return row;
        return Semantics(
          enabled: false,
          child: Opacity(opacity: 0.38, child: row),
        );
      },
    );
  }
}
