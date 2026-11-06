import 'package:flutter/material.dart';

/// `showModalBottomSheet`の中身を**必ずスクロールできる**形にするラッパー。
///
/// `showModalBottomSheet`は既定で画面高の**9/16**（360x760の端末で約427dp）
/// までしか高さを取らない。中身を`Column(mainAxisSize: min)`のまま置くと、
/// 項目が7〜8件を超えた時点で入りきらず`RenderFlex overflowed`になり、
/// **下の項目が縞模様で潰れて選べなくなる**。
///
/// 実際に踏んだ例：
/// - ジェスチャー設定の割り当てシート（選択肢9件、77pxオーバーフロー）
/// - クイックツールの「追加」シート（組み込みブラシ15件、**654px**
///   オーバーフロー。ブラシの大半が選べない状態だった）
///
/// 件数が固定の短いシートでも、あとから項目が増えたときに同じことが起きる
/// （組み込みブラシは実際に増やされた）。シートの中身はこれで包むこと。
class ScrollableSheetBody extends StatelessWidget {
  const ScrollableSheetBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SafeArea(child: SingleChildScrollView(child: child));
}
