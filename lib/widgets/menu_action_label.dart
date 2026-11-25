import 'package:flutter/material.dart';

import '../config/signal_colors.dart';

/// ポップアップメニューの項目名の前にアイコンを付ける（「ゴミ箱へ移動」・
/// 「削除」のように取り消しにくい操作）。
///
/// ふつうは項目の書式（メニューの文字色・押せないときは薄く）のまま書き、
/// アイコンも同じメニューの文字色で描く。取り消せない操作（[destructive]：
/// 削除・完全削除・空にする）だけは、アイコンと項目名を警告色で書く
/// （[SignalColors.warning]。テーマ・外観で選ぶ色で、組み込みのテーマでは
/// メニューの背景の上で読める）。ゴミ箱へ移す（戻せる）項目は警告色に
/// しない。どちらも色だけでなくアイコンと文で伝える。
class MenuActionLabel extends StatelessWidget {
  const MenuActionLabel({
    super.key,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;

  /// 取り消せない操作の項目か（警告色で書く）。
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    // メニューの項目のアイコンは画面の本文の色を受け継ぐので、メニューの
    // 文字色（ポップアップメニューのテーマ）を渡す。押せない項目は、項目が
    // アイコンを薄くし（IconTheme.opacity）、文字は項目の書式の薄さを写す。
    final warning = destructive ? SignalColors.of(context).warning : null;
    final itemInk = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: warning ?? PopupMenuTheme.of(context).iconColor,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: warning == null
                ? null
                : TextStyle(
                    color: warning.withValues(
                      alpha: warning.a * (itemInk?.a ?? 1),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
