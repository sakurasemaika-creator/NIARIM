import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

Future<bool> runProjectTrashAction(
  BuildContext context,
  Future<void> Function() apply,
) async {
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  try {
    await apply();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Text(AppLocalizations.of(context)!.homeTrashOperationFailed),
          ),
        ),
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
  final _errorAnchor = GlobalKey();

  Future<void> _apply() async {
    if (_working) return;
    setState(() {
      _working = true;
      _failed = false;
    });
    try {
      await widget.onApply();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _failed = true;
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
                    l10n.homeTrashOperationFailed,
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
