import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_toast_messenger.dart';

/// 押せない切り取り・コピーを押したときの知らせの印（続けて押しても
/// 積み重ならないよう、前の同じ知らせだけを取り下げる）。
class _UnavailableActionKey extends UniqueKey {}

/// Keep the same actions reachable when translated or enlarged labels no
/// longer fit. Width decisions use the actual button and count text styles.
class HomeSelectionToolbar extends StatelessWidget {
  const HomeSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onDeselectAll,
    this.onCut,
    this.onCopy,
    this.onTrash,
    this.primaryActionLabel,
    this.primaryActionIcon = Icons.delete,
    this.cutUnavailableReason,
    this.copyUnavailableReason,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback? onCut;
  final VoidCallback? onCopy;
  final VoidCallback? onTrash;
  final String? primaryActionLabel;
  final IconData primaryActionIcon;

  /// 切り取り・コピーが押せない（[onCut]・[onCopy]がnull）理由。あれば、
  /// 押せない見た目のまま、長押し・ホバーの吹き出しと読み上げで理由を伝え、
  /// 押したら理由を知らせる（説明なしに押せないと、なぜ押せないか分からな
  /// かった）。
  final String? cutUnavailableReason;
  final String? copyUnavailableReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final buttonText =
        (theme.textButtonTheme.style?.textStyle?.resolve({}) ??
                theme.textTheme.labelLarge!)
            .copyWith(color: foreground);
    final countText = theme.textTheme.bodyMedium!.copyWith(color: foreground);
    final countLabel = l10n.homeSelectionCount(selectedCount);
    double widthOf(String label, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    Widget iconButton(
      String label,
      IconData icon,
      VoidCallback? action, {
      Color? color,
      String? unavailable,
    }) {
      final ink = color ?? foreground;
      if (action == null && unavailable != null) {
        void explain() {
          final messenger = ScaffoldMessenger.of(context);
          if (messenger is AppToastMessengerState) {
            messenger.withdrawSnackBars(
              (snackBar) => snackBar.key is _UnavailableActionKey,
            );
          }
          messenger.showSnackBar(
            SnackBar(key: _UnavailableActionKey(), content: Text(unavailable)),
          );
        }

        // 押せない見た目（押せないボタンと同じ薄さ）のまま、理由を吹き出し・
        // 読み上げで伝え、押したら知らせる。読み上げ（TalkBack・スイッチ
        // 操作）で押したときも同じ知らせを出す（中のボタンの読み上げを
        // 外すので、押す操作はここに付ける。付けないと「ボタン」と読むのに
        // 押しても何も起きなかった）。
        return SizedBox.square(
          dimension: 48,
          child: Semantics(
            label: label,
            hint: unavailable,
            button: true,
            onTap: explain,
            excludeSemantics: true,
            child: IconButton(
              tooltip: unavailable,
              icon: Icon(icon),
              onPressed: explain,
              style: IconButton.styleFrom(
                foregroundColor: ink.withValues(alpha: 0.38),
                minimumSize: const Size(48, 48),
                visualDensity: VisualDensity.standard,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        );
      }
      return SizedBox.square(
        dimension: 48,
        child: IconButton(
          tooltip: label,
          icon: Icon(icon),
          onPressed: action,
          style: IconButton.styleFrom(
            foregroundColor: ink,
            disabledForegroundColor: ink.withValues(alpha: 0.38),
            minimumSize: const Size(48, 48),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    Widget textButton(String label, VoidCallback action) => Tooltip(
      message: label,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(48, 48),
          foregroundColor: foreground,
          textStyle: buttonText,
          visualDensity: VisualDensity.standard,
        ),
        onPressed: action,
        child: Text(label, maxLines: 1),
      ),
    );

    final widest = [
      widthOf(l10n.homeSelectionAllSelect, buttonText) + 8,
      widthOf(l10n.homeSelectionAllDeselect, buttonText) + 8,
      widthOf(countLabel, countText),
    ].fold<double>(48, (largest, width) => width > largest ? width : largest);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < widest * 3 + 48 * 3 + 2;
          final actions = [
            iconButton(
              l10n.commonCut,
              Icons.content_cut,
              onCut,
              unavailable: cutUnavailableReason,
            ),
            iconButton(
              l10n.commonCopy,
              Icons.content_copy,
              onCopy,
              unavailable: copyUnavailableReason,
            ),
            iconButton(
              primaryActionLabel ?? l10n.homeMoveToTrash,
              primaryActionIcon,
              onTrash,
              color: theme.colorScheme.primary,
            ),
          ];
          if (compact) {
            final scopeControls = <Widget>[
              iconButton(
                l10n.homeSelectionAllSelect,
                Icons.select_all,
                onSelectAll,
              ),
              iconButton(
                l10n.homeSelectionAllDeselect,
                Icons.deselect,
                onDeselectAll,
              ),
              Expanded(
                child: Tooltip(
                  message: countLabel,
                  child: Semantics(
                    label: countLabel,
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: 48,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$selectedCount',
                            key: const Key('home-selection-count'),
                            style: countText,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ];
            if (constraints.maxWidth < 48 * 6) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: scopeControls),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: actions,
                  ),
                ],
              );
            }
            return Row(children: [...scopeControls, ...actions]);
          }
          return Row(
            children: [
              Expanded(
                child: textButton(l10n.homeSelectionAllSelect, onSelectAll),
              ),
              Expanded(
                child: textButton(l10n.homeSelectionAllDeselect, onDeselectAll),
              ),
              Expanded(
                child: Text(
                  countLabel,
                  key: const Key('home-selection-count'),
                  style: countText,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
              ...actions,
            ],
          );
        },
      ),
    );
  }
}

/// Copy/cut status and actions use the same visual style and 48px action
/// height as [HomeSelectionToolbar].
class HomeClipboardToolbar extends StatelessWidget {
  const HomeClipboardToolbar({
    super.key,
    required this.itemCount,
    required this.isCut,
    required this.onPaste,
    required this.onClear,
    this.isPasting = false,
    this.pasteUnavailableStatus,
  });

  final int itemCount;
  final bool isCut;
  final bool isPasting;
  final VoidCallback? onPaste;
  final String? pasteUnavailableStatus;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final status = isCut
        ? l10n.homeClipboardCutStatus(itemCount)
        : l10n.homeClipboardCopiedStatus(itemCount);
    final clearLabel = l10n.homeClipboardClear;
    final style = TextButton.styleFrom(
      foregroundColor: foreground,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.standard,
    );
    return Container(
      key: const Key('homeClipboardToolbar'),
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              pasteUnavailableStatus ?? status,
              key: const Key('homeClipboardStatusLabel'),
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              maxLines: pasteUnavailableStatus == null ? 1 : null,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            key: const Key('homeClearClipboardButton'),
            onPressed: isPasting ? null : onClear,
            icon: const Icon(Icons.clear_all, size: 20),
            label: Text(clearLabel, maxLines: 1),
            style: style,
          ),
          if (onPaste != null)
            TextButton.icon(
              key: const Key('homeCrossTabPasteButton'),
              onPressed: isPasting ? null : onPaste,
              icon: const Icon(Icons.content_paste, size: 20),
              label: Text(l10n.commonPaste, maxLines: 1),
              style: style,
            ),
        ],
      ),
    );
  }
}
