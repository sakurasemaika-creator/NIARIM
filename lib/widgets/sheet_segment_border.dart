import 'package:flutter/material.dart';

/// 1枚の面（シート）を、一覧の行ごとに分けて描くための形。
///
/// 行を1つずつ作る一覧（`ListView.builder`）では、まとまり全体を1つの
/// 部品で包めない。そこで各行が自分の分の面を描き、先頭の行は上の角の
/// 丸みと上の縁、最後の行は下の角の丸みと下の縁を受け持ち、行と行の間には
/// 字の始まり（[dividerIndent]）から細い線を引く。並べると、影の無い
/// 1枚の面に行が細い線で区切られて載っているように見える（行ごとに
/// 浮かせたカードを隙間で並べると、どの行も同じ重さの箱になり、
/// まとまりが読めなかった）。
class SheetSegmentBorder extends ShapeBorder {
  const SheetSegmentBorder({
    required this.first,
    required this.last,
    required this.side,
    this.radius = 16,
    this.dividerIndent = 16,
  });

  /// まとまりの先頭の行（上の縁と角の丸みを描く）。
  final bool first;

  /// まとまりの最後の行（下の縁と角の丸みを描く。そうでなければ行の下に
  /// 区切りの線を引く）。
  final bool last;

  /// 縁と区切りの線。
  final BorderSide side;

  final double radius;

  /// 区切りの線の始まり（行の左の端から。右から左へ書く言語では右から）。
  final double dividerIndent;

  RRect _shape(Rect rect) {
    final r = Radius.circular(radius);
    return RRect.fromRectAndCorners(
      rect,
      topLeft: first ? r : Radius.zero,
      topRight: first ? r : Radius.zero,
      bottomLeft: last ? r : Radius.zero,
      bottomRight: last ? r : Radius.zero,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_shape(rect));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final paint = side.toPaint()..style = PaintingStyle.stroke;
    final half = side.width / 2;
    final edge = rect.deflate(half);
    if (first && last) {
      canvas.drawRRect(_shape(edge), paint);
      return;
    }
    // 左右の縁は行の上下の端まで引き、隣の行の縁とつなげる。先頭の行は上の
    // 縁と上の角、最後の行は下の縁と下の角も描く（上下の縁を隣の行と
    // 二重に描かない）。
    final r = radius.clamp(0.0, edge.shortestSide / 2);
    final path = Path();
    final top = first ? edge.top : rect.top;
    final bottom = last ? edge.bottom : rect.bottom;
    // 左の縁（下から上へ）。
    path.moveTo(edge.left, last ? bottom - r : bottom);
    if (last) {
      path.moveTo(edge.right, bottom - r);
      path.arcToPoint(
        Offset(edge.right - r, bottom),
        radius: Radius.circular(r),
      );
      path.lineTo(edge.left + r, bottom);
      path.arcToPoint(
        Offset(edge.left, bottom - r),
        radius: Radius.circular(r),
      );
    }
    path.lineTo(edge.left, first ? top + r : top);
    if (first) {
      path.arcToPoint(Offset(edge.left + r, top), radius: Radius.circular(r));
      path.lineTo(edge.right - r, top);
      path.arcToPoint(Offset(edge.right, top + r), radius: Radius.circular(r));
    } else {
      path.moveTo(edge.right, top);
    }
    path.lineTo(edge.right, last ? bottom - r : bottom);
    canvas.drawPath(path, paint);
    if (!last) {
      final y = rect.bottom - half;
      final rtl = textDirection == TextDirection.rtl;
      canvas.drawLine(
        Offset(rtl ? edge.left : rect.left + dividerIndent, y),
        Offset(rtl ? rect.right - dividerIndent : edge.right, y),
        paint,
      );
    }
  }

  @override
  ShapeBorder scale(double t) => SheetSegmentBorder(
    first: first,
    last: last,
    side: side.scale(t),
    radius: radius * t,
    dividerIndent: dividerIndent * t,
  );

  @override
  bool operator ==(Object other) =>
      other is SheetSegmentBorder &&
      other.first == first &&
      other.last == last &&
      other.side == side &&
      other.radius == radius &&
      other.dividerIndent == dividerIndent;

  @override
  int get hashCode => Object.hash(first, last, side, radius, dividerIndent);
}
