import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/project_service.dart' show ProjectFolder;
import '../../../utils/app_error_reporter.dart';
import 'folder_save_feedback.dart';

class ProjectFolderEditDialog extends StatefulWidget {
  const ProjectFolderEditDialog({
    super.key,
    required this.folder,
    required this.onSave,
  });
  final ProjectFolder folder;
  final Future<void> Function(String name, int? color) onSave;

  @override
  State<ProjectFolderEditDialog> createState() =>
      _ProjectFolderEditDialogState();
}

class _ProjectFolderEditDialogState extends State<ProjectFolderEditDialog> {
  late final _name = TextEditingController(text: widget.folder.name);
  late int? _color = widget.folder.color;
  final _errorKey = GlobalKey();
  bool _saving = false;
  Object? _error;
  // These swatches are folder content colors, not UI foreground/backgrounds.
  static const _colors = [
    null,
    0xFFFF5C7A,
    0xFFFFB020,
    0xFFFFE066,
    0xFF3DDC97,
    0xFF3AA6FF,
    0xFFB15CFF,
    0xFF9E9E9E,
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_name.text.trim(), _color);
      if (mounted) closeFolderRoute(context);
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
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
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.all(16),
        title: Text(l10n.projectListEditFolderTooltip),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              onChanged: (_) => setState(() {}),
              // Enterでも保存する（空白だけの名前では何もしない）。
              onEditingComplete: () {},
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l10n.folderNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.projectListFolderColorLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final color in _colors)
                  Semantics(
                    selected: _color == color,
                    child: IconButton(
                      tooltip: color == null
                          ? l10n.folderNone
                          : '${l10n.projectListFolderColorLabel}: #${color.toRadixString(16).substring(2).toUpperCase()}',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _color = color),
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color == null ? null : Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == color
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: _color == color ? 3 : 1,
                          ),
                        ),
                        child: color == null
                            ? Icon(
                                Icons.block,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              )
                            : _color == color
                            ? Padding(
                                padding: const EdgeInsets.all(5),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
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
            label: l10n.commonSave,
            saving: _saving,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}
