import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/save_node.dart';
import '../../../services/save_tree_service.dart';

/// Edits only the snapshot's display name. Never overwrites the saved frame,
/// time, thumbnail, slot, tree parent, or .niapro file.
class SaveRenameButton extends StatelessWidget {
  const SaveRenameButton({
    super.key,
    required this.node,
    required this.fallbackName,
  });

  final SaveNode node;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      key: Key('saveRename_${node.id}'),
      tooltip: l10n.commonRename,
      icon: const Icon(Icons.edit_outlined, size: 17),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: () async {
        final controller = TextEditingController(
          text: node.comment ?? fallbackName,
        );
        try {
          final name = await showDialog<String>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.commonRename),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(labelText: l10n.saveTreeCommentLabel),
                onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text),
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          );
          if (name == null || name.trim().isEmpty || !context.mounted) return;
          final ok = await context.read<SaveTreeService>().renameSave(
            node.projectId,
            node.id,
            name,
          );
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)),
            );
          }
        } finally {
          // Do not dispose while the dialog closing animation still builds.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.dispose();
          });
        }
      },
    );
  }
}
