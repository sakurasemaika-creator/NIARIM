import 'package:flutter/material.dart';

import 'menu_surface.dart';

/// テーマのカード（下地はメニューの背景色、`cardTheme`）に中身を載せる。
///
/// カードの中身はダイアログ・シートと同じメニューの面のテーマ
/// （[MenuSurface]）で描く。素の[Card]のままだと中の文字・アイコン・タブ・
/// 入力欄が本文の文字色で書かれ、メニューを暗く・本文の文字を暗くした
/// テーマ（本文とメニューの文字色を別々に選んだ自作テーマ）で読めなかった。
/// 組み込みのテーマは本文とメニューの文字色が同じなので見た目は変わらない。
///
/// 下地の色を自分で決めるカード（`color:`を渡すもの）は素の[Card]を使う
/// （中身の色もそのカードが決める）。
class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    this.margin,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.shape,
    this.clipBehavior,
    this.child,
  });

  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child;
    return Card(
      margin: margin,
      elevation: elevation,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      shape: shape,
      clipBehavior: clipBehavior,
      child: content == null ? null : MenuSurface(child: content),
    );
  }
}
