import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/project_service.dart' show ProjectFolder;
import '../../../utils/app_error_reporter.dart';
import '../../../widgets/scrollable_sheet_body.dart';
import 'folder_save_feedback.dart';

class WorkFolderMoveSheet extends StatefulWidget {
  const WorkFolderMoveSheet({
    super.key,
    required this.folders,
    required this.onMove,
    required this.filename,
  });

  final List<ProjectFolder> folders;
  final Future<void> Function(String? folderId) onMove;
  final String filename;

  @override
  State<WorkFolderMoveSheet> createState() => _WorkFolderMoveSheetState();
}

class _WorkFolderMoveSheetState extends State<WorkFolderMoveSheet> {
  final _errorKey = GlobalKey();
  bool _saving = false;
  Object? _error;
  String? _selectedFolder;

  Future<void> _move(String? folderId) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _selectedFolder = folderId;
    });
    try {
      await widget.onMove(folderId);
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
    final foreground =
        theme.popupMenuTheme.textStyle?.color ?? theme.colorScheme.onSurface;
    Widget leading(String? folderId, IconData icon) =>
        _saving && _selectedFolder == folderId
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              semanticsLabel: l10n.folderMoveToTitle,
            ),
          )
        : Icon(icon);
    return Semantics(
      namesRoute: true,
      explicitChildNodes: true,
      label: '${l10n.folderMoveToTitle}: ${widget.filename}',
      child: ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  key: _errorKey,
                  liveRegion: true,
                  child: Text(
                    folderSaveFailureText(l10n, _error!),
                    style: TextStyle(color: foreground),
                  ),
                ),
              ),
            ListTile(
              minTileHeight: 48,
              leading: leading(null, Icons.folder_off_outlined),
              title: Text(l10n.folderNone),
              onTap: _saving ? null : () => _move(null),
            ),
            for (final folder in widget.folders)
              ListTile(
                minTileHeight: 48,
                leading: leading(folder.id, Icons.folder_outlined),
                title: Text(folder.name),
                onTap: _saving ? null : () => _move(folder.id),
              ),
          ],
        ),
      ),
    );
  }
}
