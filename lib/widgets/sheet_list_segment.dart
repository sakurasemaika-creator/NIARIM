import 'package:flutter/material.dart';

import 'grouped_sheet.dart';
import 'menu_surface.dart';

/// 長さの決まらない一覧（`SliverList.builder`・`ListView.builder`）の1行を、
/// [GroupedSheet]と同じ1枚の面の一部として描く。
///
/// [GroupedSheet]は行を全部まとめて作るので、作品・フォントのように数が
/// 増える一覧では画面の外の行まで作ることになる。この部品は行ごとに、面の
/// 色・左右の細い枠・最初の行の上の枠と角・最後の行の下の枠と角・行の間の
/// 線だけを描くので、並べると1枚の面に見え、一覧は見えている行だけを作れる。
class SheetListSegment extends StatelessWidget {
  const SheetListSegment({
    super.key,
    required this.first,
    required this.last,
    required this.child,
    this.dividerIndent = GroupedSheet.rowInset,
  });

  /// 面の最初の行（上の枠と角を描く）。
  final bool first;

  /// 面の最後の行（下の枠と角を描く）。
  final bool last;
  final Widget child;

  /// 前の行との間の線の書き始め（行の文字の始まり）。
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sheetColor = theme.cardTheme.color ?? scheme.surface;
    final rule =
        theme.dividerTheme.color ?? scheme.outlineVariant.withValues(alpha: .6);
    const r = Radius.circular(GroupedSheet.radius);
    final radius = BorderRadius.vertical(
      top: first ? r : Radius.zero,
      bottom: last ? r : Radius.zero,
    );
    return MenuSurface(
      child: CustomPaint(
        foregroundPainter: _SegmentEdgePainter(
          first: first,
          last: last,
          color: rule,
        ),
        child: Material(
          color: sheetColor,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!first)
                Divider(height: 1, thickness: 1, indent: dividerIndent),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 面の縁の一部（左右と、最初・最後の行なら上・下と角）。隣の行と継ぎ目なく
/// つながるよう、続く側は1px外まで延ばしてから自分の範囲で切る。
class _SegmentEdgePainter extends CustomPainter {
  const _SegmentEdgePainter({
    required this.first,
    required this.last,
    required this.color,
  });

  final bool first;
  final bool last;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const r = Radius.circular(GroupedSheet.radius - 0.5);
    final rect = Rect.fromLTRB(
      0.5,
      first ? 0.5 : -1,
      size.width - 0.5,
      last ? size.height - 0.5 : size.height + 1,
    );
    final outline = RRect.fromRectAndCorners(
      rect,
      topLeft: first ? r : Radius.zero,
      topRight: first ? r : Radius.zero,
      bottomLeft: last ? r : Radius.zero,
      bottomRight: last ? r : Radius.zero,
    );
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..drawRRect(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_SegmentEdgePainter old) =>
      old.first != first || old.last != last || old.color != color;
}
