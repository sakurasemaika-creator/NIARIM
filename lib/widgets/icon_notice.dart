import 'package:flutter/material.dart';

import '../config/signal_colors.dart';
import 'keep_together_text.dart';

/// [IconNotice]の重さ。
enum NoticeSeverity {
  /// ふつうの知らせ・説明（その面の文字色だけ）。
  info,

  /// 何も失われないが気をつけてほしい（読み込めない・つながらない〔やり
  /// 直せる〕・上限に近い・足りない等）。印だけ注意色（更新マーク色）。
  caution,

  /// 作品が保存できない・失われうる失敗。印と文を警告色で書く。
  warning,
}

/// その場に出す知らせ（読み込めなかった・足りない・重なっている等）の1行。
///
/// 色だけで知らせず、いつも先頭の印と文で知らせる。ふつうの知らせは
/// その面の文字色（[DefaultTextStyle]、無ければ面の上の文字色）で書き、
/// 気をつけてほしい知らせ（[IconNotice.caution]）は印だけを注意色、作品が
/// 失われうる失敗（[IconNotice.warning]）は印と文を警告色にする
/// （[SignalColors]。どちらもテーマ・外観で選ぶ色）。以前は`colorScheme.error`の
/// 赤い字だけで知らせていたが、テーマで選ぶ色ではなく、暗い面では暗い赤で
/// 読めず、色の見分けにくい人には知らせだと分からなかった。
class IconNotice extends StatelessWidget {
  const IconNotice(
    this.message, {
    super.key,
    this.icon = Icons.error_outline,
    this.fontSize,
    this.liveRegion = false,
  }) : severity = NoticeSeverity.info;

  /// 何も失われないが気をつけてほしい知らせ（印だけ注意色）。
  const IconNotice.caution(
    this.message, {
    super.key,
    this.icon = Icons.warning_amber_rounded,
    this.fontSize,
    this.liveRegion = false,
  }) : severity = NoticeSeverity.caution;

  /// 作品が保存できない・失われうる失敗の知らせ（印と文を警告色）。
  const IconNotice.warning(
    this.message, {
    super.key,
    this.icon = Icons.error_outline,
    this.fontSize,
    this.liveRegion = false,
  }) : severity = NoticeSeverity.warning;

  final String message;
  final IconData icon;
  final double? fontSize;
  final NoticeSeverity severity;

  /// 出たときに読み上げへも伝える（操作の結果として現れる知らせ）。
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final surfaceInk =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;
    final signals = SignalColors.of(context);
    final (iconColor, textColor) = switch (severity) {
      NoticeSeverity.info => (surfaceInk, surfaceInk),
      NoticeSeverity.caution => (signals.caution, surfaceInk),
      NoticeSeverity.warning => (signals.warning, signals.warning),
    };
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
              color: iconColor,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: messageText(
              message,
              style: TextStyle(color: textColor, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}
