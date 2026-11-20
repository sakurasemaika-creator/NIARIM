import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/autosave_service.dart';
import '../../../services/project_service.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/responsive.dart';
import 'save_display_name.dart';
import 'save_restore_dialog.dart';

class SaveSourcePicker extends StatelessWidget {
  const SaveSourcePicker({
    super.key,
    required this.showAutosaves,
    required this.onChanged,
  });

  final bool showAutosaves;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text(l10n.saveDataManualTab),
            selected: !showAutosaves,
            onSelected: (_) => onChanged(false),
          ),
          ChoiceChip(
            label: Text(l10n.helpAutoSaveTitle),
            selected: showAutosaves,
            onSelected: (_) => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class AutosaveList extends StatefulWidget {
  const AutosaveList({super.key, required this.projectId});

  final String projectId;

  @override
  State<AutosaveList> createState() => _AutosaveListState();
}

class _AutosaveListState extends State<AutosaveList> {
  bool _loading = false;
  final _previews = <AutosaveSlot, Future<Uint8List?>>{};
  Future<void> _previewQueue = Future<void>.value();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<AutosaveService>();
    final slots = service.slotsForProject(widget.projectId).toList();
    _previews.removeWhere((slot, _) => !slots.contains(slot));
    if (slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.saveDataAutosavesEmpty, textAlign: TextAlign.center),
        ),
      );
    }
    return desktopCentered(
      context,
      ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        children: [
          for (final slot in slots)
            MenuCard(
              key: ValueKey(slot),
              child: ListTile(
                enabled: !_loading,
                leading: FutureBuilder<Uint8List?>(
                  future: _previews.putIfAbsent(
                    slot,
                    () => _queuePreview(service, slot),
                  ),
                  builder: (context, preview) => SavedThumbnail(
                    bytes: preview.data,
                    width: 58,
                    height: 46,
                  ),
                ),
                title: Text(_displayTime(slot, l10n)),
                subtitle: Text(l10n.saveTreeRestoreAction),
                onTap: () => _read(service, slot),
              ),
            ),
        ],
      ),
    );
  }

  Future<Uint8List?> _queuePreview(AutosaveService service, AutosaveSlot slot) {
    final result = _previewQueue.then((_) async {
      if (!mounted || !_previews.containsKey(slot)) return null;
      return savedThumbnail(await service.readSlot(slot));
    });
    _previewQueue = result.then((_) {});
    return result;
  }

  Future<void> _read(AutosaveService service, AutosaveSlot slot) async {
    if (_loading) return;
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context)!;
    final time = _displayTime(slot, l10n);
    try {
      final data = await confirmSavedVersion(
        context,
        projectId: slot.projectId,
        name: l10n.saveTreeNodeDatedName(time),
        read: () => service.readSlot(slot),
      );
      if (data == null || !mounted) return;
      final projects = context.read<ProjectService>();
      final loaded = projects.projects.any((p) => p.id == slot.projectId);
      if (loaded) projects.useSavedVersion(slot.projectId, data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loaded
                ? l10n.saveTreeRestoredSnackbar(
                    l10n.saveTreeNodeDatedName(time),
                  )
                : l10n.saveTreeLoadFailedSnackbar,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayTime(AutosaveSlot slot, AppLocalizations l10n) =>
      formatSaveTime(slot.savedAt, l10n.localeName, withSeconds: true);
}
