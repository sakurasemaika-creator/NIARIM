import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/sheet_list_segment.dart';

/// ゴミ箱の一覧の行（1枚の面の一部として描く[SheetListSegment]）のうち、
/// [inside]を含む行。
Finder trashRowOf(Finder inside) =>
    find.ancestor(of: inside, matching: find.byType(SheetListSegment)).first;

/// [inside]を含むゴミ箱の行の中身の矩形。2行目からは行の上の端に行の間の
/// 線（1px）があるので、それを除いた所（名前・ボタンの並ぶ所）を返す。
Rect trashRowRect(WidgetTester tester, Finder inside) {
  final row = trashRowOf(inside);
  final rect = tester.getRect(row);
  final line = find.descendant(of: row, matching: find.byType(Divider));
  if (line.evaluate().isEmpty) return rect;
  return Rect.fromLTRB(
    rect.left,
    tester.getRect(line.first).bottom,
    rect.right,
    rect.bottom,
  );
}
