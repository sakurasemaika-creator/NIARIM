import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/save_node.dart';
import '../../../services/save_tree_service.dart';

/// Shared memo editor for empty slots, saved slots, and tree nodes.
/// Editing this text must never rewrite a saved archive or its thumbnail.
Future<String?> _showMemoEditor(BuildContext context, String initial) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initial);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.saveTreeCommentLabel),
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
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  } finally {
    // Avoid disposing while a closing dialog still needs a final frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }
}

/// Slot name is independent of whether an archive exists. The same pencil
/// therefore remains tappable before save, after overwrite, and after delete.
class SaveSlotMemoButton extends StatelessWidget {
  const SaveSlotMemoButton({
    super.key,
    required this.projectId,
    required this.slotIndex,
    required this.initialMemo,
  });

  final String projectId;
  final int slotIndex;
  final String initialMemo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      key: Key('saveSlotMemo_${projectId}_${slotIndex}'),
      tooltip: l10n.saveTreeCommentLabel,
      icon: const Icon(Icons.edit_outlined, size: 17),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: () async {
        final memo = await _showMemoEditor(context, initialMemo);
        if (memo == null || !context.mounted) return;
        await context.read<SaveTreeService>().setSlotMemo(
          projectId,
          slotIndex,
          memo,
        );
      },
    );
  }
}

/// Tree nodes keep individually named historical snapshots. They do not
/// inherit the independent memo behavior of the fixed save slots.
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
      tooltip: l10n.saveTreeCommentLabel,
      icon: const Icon(Icons.edit_outlined, size: 17),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: () async {
        final memo = await _showMemoEditor(context, node.comment ?? fallbackName);
        if (memo == null || !context.mounted) return;
        // Empty means "clear" only for slots. An archived tree snapshot must
        // retain a readable title until the storage service supports null.
        if (memo.trim().isEmpty) return;
        final ok = await context.read<SaveTreeService>().renameSave(
          node.projectId,
          node.id,
          memo,
        );
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)),
          );
        }
      },
    );
  }
}
