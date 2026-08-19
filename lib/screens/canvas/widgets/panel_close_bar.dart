import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// ツール詳細設定ポップアップ（ブラシ・カラーピッカー・フィルター・
/// レイヤー・オニオンスキン・早替えツール・定規・スタンプ・トーンの
/// 各パネル）共通の閉じるボタン。全パネルで「ポップアップ中央の×ボタンで
/// 閉じる」という操作方法に統一するため、各パネルのタイトル行の右端では
/// なく、パネル最上部の中央に配置する。
class PanelCenterCloseBar extends StatelessWidget {
  final VoidCallback onClose;
  const PanelCenterCloseBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: l10n.commonClose,
        onPressed: onClose,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      ),
    );
  }
}
