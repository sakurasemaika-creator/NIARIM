import 'package:flutter/material.dart';

/// スクロールする一覧の行の背景（[ListTile]の選択色・`tileColor`・押したときの
/// 波紋・マウスやペンを重ねたときの色）を、一覧の範囲で切り抜く透明な面。
///
/// [ListTile]・[InkWell]は背景を一番近い[Material]へ描き、[Material]は自分の
/// 大きさでしか切り抜かない。パネルの面（スマホのカード・PC/DeXのドックの面）は
/// 一覧より大きいので、そのままだとスクロールで一覧の外へ出た行の背景が、一覧の
/// 上のタブ・ボタンや下の余白の上に描かれる。スクロールする部品をこれで包むと、
/// 背景は一覧と同じ大きさで切り抜かれる。
///
/// 行ごとに包まないこと：行の大きさで切り抜くと、背景の形のぼかしに切り抜きの
/// ぼかしが重なり、小数の位置にある行の上下の縁が薄く描かれる。
///
/// 透明で当たり判定も取らず、文字の書式も外側のものを引き継ぐ。
class ListInkClip extends StatelessWidget {
  const ListInkClip({super.key, required this.child});

  /// スクロールする部品（一覧）。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      textStyle: DefaultTextStyle.of(context).style,
      child: child,
    );
  }
}

/// スクロールする部品を[ListInkClip]で包む。
extension ListInkClipping on Widget {
  Widget clipListInk() => ListInkClip(child: this);
}
