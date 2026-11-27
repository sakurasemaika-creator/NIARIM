import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/project_service.dart' show ProjectFolder;
import '../../../utils/app_error_reporter.dart';
import '../../../utils/folder_tree.dart';
import '../../../widgets/scrollable_sheet_body.dart';
import 'folder_save_feedback.dart';

class WorkFolderMoveSheet extends StatefulWidget {
  const WorkFolderMoveSheet({
    super.key,
    required this.folders,
    required this.onMove,
    required this.filename,
    this.onCreate,
    this.onEdit,
    this.rootLabel,
    this.depths,
    this.markCurrent = false,
    this.currentFolderId,
  });

  /// [currentFolderId]（nullは一番上）の行に今の場所の印を付ける。押しても
  /// 動かさずに閉じる。
  final bool markCurrent;
  final String? currentFolderId;

  final List<ProjectFolder> folders;
  final Future<void> Function(String? folderId) onMove;
  final String filename;
  final VoidCallback? onCreate;
  final void Function(ProjectFolder folder)? onEdit;
  final String? rootLabel;

  /// フォルダごとの階層の深さ（`folderTree`の並び）。渡すと中のフォルダほど
  /// 字下げする（平らに並べると、別の親の同じ名前のフォルダを見分けられない）。
  final Map<String, int>? depths;

  @override
  State<WorkFolderMoveSheet> createState() => _WorkFolderMoveSheetState();
}

class _WorkFolderMoveSheetState extends State<WorkFolderMoveSheet> {
  final _errorKey = GlobalKey();
  bool _saving = false;
  Object? _error;
  String? _selectedFolder;

  bool _isCurrent(String? folderId) =>
      widget.markCurrent && folderId == widget.currentFolderId;

  Future<void> _move(String? folderId) async {
    if (_saving) return;
    if (_isCurrent(folderId)) {
      closeFolderRoute(context);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final folderName = widget.folders
        .where((folder) => folder.id == folderId)
        .firstOrNull
        ?.name;
    setState(() {
      _saving = true;
      _error = null;
      _selectedFolder = folderId;
    });
    try {
      await widget.onMove(folderId);
      if (mounted) closeFolderRoute(context);
      // 移した先を知らせる（以前はシートが閉じるだけで、移ったのか分からなかった）。
      messenger?.showSnackBar(
        SnackBar(
          persist: false,
          content: Text(
            folderName == null
                ? l10n.folderMovedOutSnackbar
                : l10n.folderMovedIntoSnackbar(folderName),
          ),
        ),
      );
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
        // 今の場所は印だけで示す（行を差し色で塗りつぶさない）。
        : _isCurrent(folderId)
        ? Semantics(selected: true, child: const Icon(Icons.check))
        : Icon(icon);
    return Semantics(
      namesRoute: true,
      explicitChildNodes: true,
      // 1つの文にする（言語によって語順・助詞が違う。DISC137）。
      label: l10n.folderMoveSheetSemanticsLabel(widget.filename),
      child: ScrollableSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 題（以前は題が無く、何のシートか分からなかった）。
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.folderMoveToTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ),
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
              title: Text(widget.rootLabel ?? l10n.folderNone),
              onTap: _saving ? null : () => _move(null),
            ),
            for (final folder in widget.folders)
              ListTile(
                minTileHeight: 48,
                contentPadding: widget.depths == null
                    ? null
                    : folderTreeTilePadding(widget.depths![folder.id] ?? 0),
                leading: leading(folder.id, Icons.folder_outlined),
                title: Text(folder.name),
                trailing: widget.onEdit == null
                    ? null
                    : IconButton(
                        tooltip: l10n.projectListEditFolderTooltip,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: _saving
                            ? null
                            : () => widget.onEdit!(folder),
                      ),
                onTap: _saving ? null : () => _move(folder.id),
              ),
            if (widget.onCreate != null)
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text(l10n.projectListCreateFolderAction),
                onTap: _saving
                    ? null
                    : () {
                        closeFolderRoute(context);
                        widget.onCreate!();
                      },
              ),
          ],
        ),
      ),
    );
  }
}
