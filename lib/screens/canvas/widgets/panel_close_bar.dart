import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// ツール詳細設定ポップアップ（ブラシ・カラーピッカー・フィルター・
/// レイヤー・オニオンスキン・早替えツール・定規・スタンプ・トーンの
/// 各パネル）共通の閉じるボタン。
///
/// 見た目はパネル上部右端の小さい×に統一する。アイコン自体は小さくても
/// タップ領域は44×44を維持し、モバイルのフローティング表示では
/// CanvasScreen側の透明バリアによる「パネル外タップで閉じる」操作も併用する。
class PanelCenterCloseBar extends StatelessWidget {
  final VoidCallback onClose;
  const PanelCenterCloseBar({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: l10n.commonClose,
        onPressed: onClose,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}
