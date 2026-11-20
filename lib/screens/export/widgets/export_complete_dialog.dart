import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/export_share_feedback.dart';

enum ExportDestination { works, projects, canvas }

class ExportCompleteDialog extends StatefulWidget {
  const ExportCompleteDialog({
    super.key,
    required this.file,
    required this.frames,
  });

  final File file;
  final int frames;

  @override
  State<ExportCompleteDialog> createState() => _ExportCompleteDialogState();
}

class _ExportCompleteDialogState extends State<ExportCompleteDialog> {
  final _noticeKey = GlobalKey();
  bool _sharing = false;
  Object? _error;

  Future<void> _share(BuildContext origin) async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _error = null;
    });
    final error = await shareExportedFileCatching(origin, widget.file);
    if (!mounted) return;
    setState(() {
      _sharing = false;
      _error = error;
    });
    if (error != null) revealExportShareNotice(_noticeKey);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.exportCompleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.exportCompleteFramesBody(widget.frames)),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.movie_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      widget.file.uri.pathSegments.last,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(l10n.exportSaveLocationHint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Builder(
            builder: (origin) => FilledButton.tonalIcon(
              onPressed: _sharing ? null : () => _share(origin),
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n.commonShare),
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 8),
            ExportShareNotice(
              key: _noticeKey,
              message: exportShareFailureText(l10n, error),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
            ),
            onPressed: () => Navigator.pop(context, ExportDestination.works),
            icon: const Icon(Icons.video_library_outlined),
            label: Text(l10n.exportOpenWorks),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () =>
                    Navigator.pop(context, ExportDestination.projects),
                child: Text(l10n.exportBackToProjectsButton),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () =>
                    Navigator.pop(context, ExportDestination.canvas),
                child: Text(l10n.exportBackToCanvasButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
