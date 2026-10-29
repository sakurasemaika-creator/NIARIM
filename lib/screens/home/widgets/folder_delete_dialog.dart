import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/app_error_reporter.dart';
import 'folder_save_feedback.dart';

class FolderDeleteDialog extends StatefulWidget {
  const FolderDeleteDialog({
    super.key,
    required this.folderName,
    required this.onDelete,
    this.body,
  });

  final String folderName;
  final String? body;
  final Future<void> Function() onDelete;

  @override
  State<FolderDeleteDialog> createState() => _FolderDeleteDialogState();
}

class _FolderDeleteDialogState extends State<FolderDeleteDialog> {
  final _errorKey = GlobalKey();
  bool _saving = false;
  Object? _error;

  Future<void> _delete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) closeFolderRoute(context);
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _errorKey.currentContext;
        if (mounted && target != null) Scrollable.ensureVisible(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.all(16),
        title: Text(l10n.projectListDeleteFolderConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.body ??
                  l10n.homeDeleteFolderKeepContents(widget.folderName),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                key: _errorKey,
                liveRegion: true,
                child: Text(folderSaveFailureText(l10n, _error!)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => closeFolderRoute(context),
            child: Text(l10n.commonCancel),
          ),
          FolderSaveButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: _delete,
            label: l10n.commonDelete,
            saving: _saving,
          ),
        ],
      ),
    );
  }
}
