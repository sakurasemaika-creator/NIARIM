import 'package:flutter/material.dart';

/// ポップアップメニューの項目名の前にアイコンを付ける（「ゴミ箱へ移動」の
/// ように取り消しにくい操作）。
///
/// 項目名は項目の書式（メニューの文字色・押せないときは薄く）のまま書き、
/// アイコンも同じメニューの文字色で描く（押せないときは項目が薄くする）。
/// 危ない操作は色ではなくアイコンと文で伝える：以前は`colorScheme.error`で
/// 書いていたが、これは差し色から作られる色でテーマ・外観で選ぶ色ではなく、
/// メニューを暗くしたテーマでは暗いメニューに暗い赤で書かれて読めなかった。
class MenuActionLabel extends StatelessWidget {
  const MenuActionLabel({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // メニューの項目のアイコンは画面の本文の色を受け継ぐので、メニューの
        // 文字色（ポップアップメニューのテーマ）を渡す。
        Icon(icon, size: 20, color: PopupMenuTheme.of(context).iconColor),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}
