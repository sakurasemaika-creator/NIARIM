import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/app_error_reporter.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/responsive.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/grouped_sheet.dart';
import '../../widgets/icon_notice.dart';
import '../../widgets/keep_together_text.dart';
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

  /// 記録を消す。消した記録は知らせの「元に戻す」で戻せる（押し間違いで
  /// 不具合の手がかりを失わない）。
  void _clear(AppLocalizations l10n) {
    final cleared = List<String>.of(AppErrorReporter.recentErrors);
    setState(AppErrorReporter.recentErrors.clear);
    if (cleared.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.errorLogCleared),
        persist: false,
        action: SnackBarAction(
          label: l10n.homeUndoAction,
          onPressed: () {
            if (!mounted) return;
            setState(() {
              // 消した後に記録されたエラーは新しい順の先頭に残す。
              final log = AppErrorReporter.recentErrors..addAll(cleared);
              if (log.length > AppErrorReporter.maxRecent) {
                log.removeRange(AppErrorReporter.maxRecent, log.length);
              }
            });
          },
        ),
      ),
    );
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
        : GroupedSheet(
            key: const Key('errorLogUnreadableSavedItems'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: IconNotice(
                  l10n.savedListUnreadableNotice(unreadable),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
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
                  // 操作（コピー・消す）を先に置き、大きな文字でもスクロール
                  // せずに押せるようにする。
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const Key('errorLogCopyAll'),
                        onPressed: () => _copyAll(l10n),
                        icon: const Icon(Icons.copy_all_outlined),
                        label: Text(l10n.errorLogCopyAll),
                      ),
                      OutlinedButton.icon(
                        key: const Key('errorLogClear'),
                        onPressed: () => _clear(l10n),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: Text(l10n.errorLogClear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 記録は1枚の面に新しい順に並べ、細い線で分ける。
                  if (errors.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: messageText(
                        l10n.errorLogHint,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  // 説明（新しい順に20件まで・伏せてある情報）は記録の面の下。
                  // 記録の前に置くと、大きな文字では説明だけで画面が埋まった。
                  if (errors.isNotEmpty)
                    GroupedSheet(
                      footer: l10n.errorLogHint,
                      children: [
                        for (final error in errors)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              error,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
