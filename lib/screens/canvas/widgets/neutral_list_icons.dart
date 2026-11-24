import 'package:flutter/material.dart';

/// キャンバスのシート・メニュー・パネルの行の先頭の印を、補助の文字色
/// （`onSurfaceVariant`）で描く。
///
/// アプリの一覧の行の印は既定で差し色（アクセントの文字・アイコン色）だが、
/// 設定/編集メニューや道具の長押しのシートでは全部の行の印が差し色になり、
/// 選んでいる行・主な操作と見分けがつかなかった（面の色の決まり：差し色は
/// 選んでいる状態・主な操作・リンクだけ）。選んでいる行は[ListTile]の
/// `selectedColor`のまま。
class NeutralListIcons extends StatelessWidget {
  const NeutralListIcons({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListTileTheme.merge(
    iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
    child: child,
  );
}
