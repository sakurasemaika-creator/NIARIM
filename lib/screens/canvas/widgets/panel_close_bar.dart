import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// ツール詳細設定ポップアップ（ブラシ・カラーピッカー・フィルター・
/// レイヤー・オニオンスキン・早替えツール・定規・スタンプ・トーンの
/// 各パネル）共通の閉じるボタン。設定内容を先に読み進められるよう、
/// タイトル行やパネル最上部には置かず、各パネルの内容末尾・中央に配置する。
class PanelCenterCloseBar extends StatelessWidget {
  final VoidCallback onClose;
  const PanelCenterCloseBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      // タップ領域は28×28では小さく押しづらかったため44×44へ広げる
      // （Materialの推奨48dpにはやや届かないが、内容末尾を太らせすぎず、
      // 指で確実に押せる大きさとして44を採る）。
      child: IconButton(
        icon: const Icon(Icons.close, size: 22),
        tooltip: l10n.commonClose,
        onPressed: onClose,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
