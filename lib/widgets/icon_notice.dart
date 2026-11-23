import 'package:flutter/material.dart';

import 'keep_together_text.dart';

/// その場に出す知らせ（読み込めなかった・足りない・重なっている等）の1行。
///
/// 文字とアイコンはその面の文字色（[DefaultTextStyle]、無ければ面の上の
/// 文字色）で描き、色ではなく先頭の印と文で知らせる。以前は
/// `colorScheme.error`の赤い字だけで知らせていたが、これは差し色から作られる
/// 色でテーマ・外観で選ぶ色ではなく、暗い面では暗い赤で読めず、色の
/// 見分けにくい人には知らせだと分からなかった。
class IconNotice extends StatelessWidget {
  const IconNotice(
    this.message, {
    super.key,
    this.icon = Icons.error_outline,
    this.fontSize,
    this.liveRegion = false,
  });

  final String message;
  final IconData icon;
  final double? fontSize;

  /// 出たときに読み上げへも伝える（操作の結果として現れる知らせ）。
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final color =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    final size = fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    return Semantics(
      liveRegion: liveRegion,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon,
              size: MediaQuery.textScalerOf(context).scale(size + 2),
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: messageText(
              message,
              style: TextStyle(color: color, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}
