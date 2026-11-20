import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/autosave_service.dart';
import '../../../services/project_service.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/responsive.dart';
import '../../../widgets/typing_dialog_inset.dart';
import 'save_display_name.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<AutosaveService>();
    final slots = service.slotsForProject(widget.projectId).toList();
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
              child: ListTile(
                enabled: !_loading,
                leading: const Icon(Icons.history),
                title: Text(_displayTime(slot, l10n)),
                subtitle: Text(l10n.saveTreeRestoreAction),
                onTap: () => _read(service, slot),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _read(AutosaveService service, AutosaveSlot slot) async {
    if (_loading) return;
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context)!;
    final time = _displayTime(slot, l10n);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          insetPadding: dialogInsetPadding(dialogContext),
          title: Text(l10n.saveTreeNodeDatedName(time)),
          content: Text(l10n.saveTreeProjectDetailResumeBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.saveTreeRestoreAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final data = await service.readSlot(slot);
      if (!mounted) return;
      final projects = context.read<ProjectService>();
      final loaded =
          data != null && projects.projects.any((p) => p.id == slot.projectId);
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
