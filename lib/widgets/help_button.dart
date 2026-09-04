import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';

/// どの画面からでもヘルプページ（検索・アコーディオンで機能の使い方を
/// 確認できる画面）を開けるようにする「？」アイコン。各画面のAppBarへ
/// 追加して使う。
///
/// [topic]を指定すると、ヘルプ画面の該当項目（`_HelpEntry.title`と一致する
/// もの）が自動展開された状態で開く。未指定の場合は従来通り全項目一覧を
/// 表示する（各画面のトピック紐付けは順次対応中）。
class HelpButton extends StatelessWidget {
  final String? topic;
  const HelpButton({super.key, this.topic});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.help_outline),
      tooltip: l10n.layerPanelHelpTooltip,
      onPressed: () => context.push(
        topic == null ? '/help' : '/help?topic=${Uri.encodeComponent(topic!)}',
      ),
    );
  }
}
