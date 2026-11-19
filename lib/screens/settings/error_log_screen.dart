import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/responsive.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/menu_card.dart';
import '../../utils/saved_list_reader.dart';

/// 設定の「エラーの記録」。アプリを閉じるまでに起きたエラー
/// （[AppErrorReporter.recentErrors]）を新しい順に見せ、不具合を知らせる
/// ときにまとめてコピーできるようにする。記録はメールアドレスやログインの
/// 情報を伏せたもので、端末には保存しない。
class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  Future<void> _copyAll(AppLocalizations l10n) async {
    await Clipboard.setData(
      ClipboardData(text: AppErrorReporter.recentErrors.join('\n\n')),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.errorLogCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final errors = List<String>.of(AppErrorReporter.recentErrors);
    // 保存の中の読めない項目（元のデータは一覧に残し、起動のたびに読み直す）。
    final unreadable = SavedListCarryOver.total;
    final unreadableNotice = unreadable == 0
        ? null
        : MenuCard(
            key: const Key('errorLogUnreadableSavedItems'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.inventory_2_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.savedListUnreadableNotice(unreadable)),
                  ),
                ],
              ),
            ),
          );
    return Scaffold(
      appBar: AppBar(title: FitOrHideTitle(l10n.settingsErrorLogTitle)),
      body: desktopCentered(
        context,
        errors.isEmpty && unreadableNotice == null
            ? EmptyStatePlaceholder(
                icon: Icons.check_circle_outline,
                title: l10n.errorLogEmpty,
                hint: l10n.errorLogHint,
              )
            : ListView(
                key: const Key('errorLogList'),
                padding: const EdgeInsets.all(16),
                children: [
                  if (unreadableNotice != null) ...[
                    unreadableNotice,
                    const SizedBox(height: 12),
                  ],
                  Text(
                    l10n.errorLogHint,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const Key('errorLogCopyAll'),
                        onPressed: () => _copyAll(l10n),
                        icon: const Icon(Icons.copy_all_outlined),
                        label: Text(l10n.errorLogCopyAll),
                      ),
                      OutlinedButton.icon(
                        key: const Key('errorLogClear'),
                        onPressed: () =>
                            setState(AppErrorReporter.recentErrors.clear),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: Text(l10n.errorLogClear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final error in errors)
                    MenuCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          error,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
