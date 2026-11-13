import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/project_service.dart'
    show FavoriteProjectDeleteException, TrashedFolderUnreadException;
import 'app_toast_messenger.dart';

// 読めていない作品があって断られたときは、読み込めていないことを伝える
// （「保存先を確認して、もう一度」では、何度やり直しても同じ）。
String _failureText(AppLocalizations l10n, Object? failure) =>
    failure is FavoriteProjectDeleteException
    ? l10n.commonFavoriteDeleteBlocked
    : failure is TrashedFolderUnreadException
    ? l10n.homeProjectsLoadFailed
    : l10n.homeTrashOperationFailed;

/// [showProjectActionFailure]が出した失敗の知らせの印（閉じるときに、他の
/// 機能の知らせと見分ける）。知らせごとに別のキーになる。
class _ProjectActionFailureKey extends UniqueKey {}

/// 素の[ScaffoldMessenger]（アプリの外・部品だけのテスト）で、出し先ごとに
/// 覚えておくこと。アプリの出し先（[AppToastMessengerState]）は、知らせを
/// 自分の待ち行列から取り下げるので、何も覚えない。
class _PlainMessengerFailures {
  /// 作品の操作を始めた回数。順番を待っている間にこれが変わった失敗の
  /// 知らせは、出た所で閉じる（closeは出ている知らせにしか使えない）。
  int round = 0;

  /// いま出ている失敗の知らせ。
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? visible;
}

final Expando<_PlainMessengerFailures> _plainFailures =
    Expando<_PlainMessengerFailures>('projectActionFailures');

/// 作品の操作（ゴミ箱へ移す・戻す・お気に入り等）を保存できなかったことを
/// [messenger]のSnackBarで知らせる。次の作品の操作（[runProjectAction]）が
/// 始まると、この知らせは閉じる（順番を待っている間なら出さない）。
void showProjectActionFailure(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  Object? failure,
) {
  final plain = messenger is AppToastMessengerState
      ? null
      : _plainFailures[messenger] ??= _PlainMessengerFailures();
  final round = plain?.round;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
  // 閉じた、または閉じ始めた（二度閉じると、次に出た別の知らせを閉じる）。
  var closing = false;
  controller = messenger.showSnackBar(
    SnackBar(
      key: _ProjectActionFailureKey(),
      content: Semantics(
        liveRegion: true,
        child: Text(_failureText(l10n, failure)),
      ),
      onVisible: plain == null
          ? null
          : () {
              if (closing) return;
              if (plain.round == round) {
                plain.visible = controller;
              } else {
                closing = true;
                controller?.close();
              }
            },
    ),
  );
  if (plain != null) {
    controller.closed.whenComplete(() {
      closing = true;
      if (identical(plain.visible, controller)) plain.visible = null;
    });
  }
}

/// 前の作品の操作の失敗の知らせを閉じる（やり直したのに前の失敗が出た
/// ままにならないように）。閉じるのは[showProjectActionFailure]が出した
/// ものだけ。出ている知らせを種類を見ずに隠すと、ゴミ箱へ移した知らせの
/// 「元に戻す」・コピーの知らせ等の他の機能の知らせまで消える。
void _closeFailureNotices(ScaffoldMessengerState messenger) {
  if (messenger is AppToastMessengerState) {
    // 出ているものは薄くして閉じ、順番を待っているものは出さずに下げる
    // （出た所で閉じると、成功した後で前の失敗が一度出て読み上げられる）。
    messenger.withdrawSnackBars(
      (snackBar) => snackBar.key is _ProjectActionFailureKey,
    );
    return;
  }
  final plain = _plainFailures[messenger];
  if (plain == null) return;
  plain.round++;
  final visible = plain.visible;
  plain.visible = null;
  visible?.close();
}

/// [messenger]について、このファイルが覚えている失敗の知らせの数（閉じた・
/// 下げられた知らせを覚えたまま残していないかの確かめ用）。
@visibleForTesting
int debugProjectActionFailuresTracked(ScaffoldMessengerState messenger) =>
    _plainFailures[messenger]?.visible == null ? 0 : 1;

Future<bool> runProjectTrashAction(
  BuildContext context,
  Future<void> Function() apply,
) => runProjectAction(context, apply);

/// Shared feedback for acknowledged project changes, including favorites.
Future<bool> runProjectAction(
  BuildContext context,
  Future<void> Function() apply,
) async {
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) _closeFailureNotices(messenger);
  try {
    await apply();
    return true;
  } catch (error) {
    if (context.mounted) {
      showProjectActionFailure(
        ScaffoldMessenger.of(context),
        AppLocalizations.of(context)!,
        error,
      );
    }
    return false;
  }
}

/// Wait for acknowledged work, retain the identified targets on failure, and
/// prevent another submission or dismissal while the operation is running.
class ProjectTrashDialog extends StatefulWidget {
  const ProjectTrashDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.itemNames,
    required this.onApply,
    this.pendingItemNames,
    this.pendingMessage,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final List<String> itemNames;
  final Future<void> Function() onApply;
  final List<String> Function()? pendingItemNames;
  final String Function()? pendingMessage;

  @override
  State<ProjectTrashDialog> createState() => _ProjectTrashDialogState();
}

class _ProjectTrashDialogState extends State<ProjectTrashDialog> {
  bool _working = false;
  bool _failed = false;
  Object? _failure;
  final _errorAnchor = GlobalKey();

  Future<void> _apply() async {
    if (_working) return;
    setState(() {
      _working = true;
      _failed = false;
      _failure = null;
    });
    try {
      await widget.onApply();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _working = false;
          _failed = true;
          _failure = error;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_failed) return;
          final errorContext = _errorAnchor.currentContext;
          if (errorContext != null) {
            Scrollable.ensureVisible(errorContext, alignment: 0);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final names = widget.pendingItemNames?.call() ?? widget.itemNames;
    return PopScope(
      canPop: !_working,
      child: AlertDialog(
        scrollable: true,
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < names.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  names[i],
                  key: ValueKey('trash-dialog-target-$i'),
                  softWrap: true,
                ),
              ),
            Text(widget.pendingMessage?.call() ?? widget.message),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  key: _errorAnchor,
                  liveRegion: true,
                  child: Text(
                    _failureText(l10n, _failure),
                    key: const Key('trash-dialog-error'),
                    style: TextStyle(color: scheme.onSurface),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('trash-dialog-cancel'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              visualDensity: VisualDensity.standard,
            ),
            onPressed: _working ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('trash-dialog-confirm'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              visualDensity: VisualDensity.standard,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            onPressed: _working ? null : _apply,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_working)
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurface,
                    ),
                  ),
                Text(_working ? l10n.homeTrashWorking : widget.confirmLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
