import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../screens/save_tree/widgets/save_display_name.dart'
    show formatSaveTime;
import '../services/autosave_service.dart';
import '../services/project_service.dart';
import 'keep_together_text.dart' show messageText;
import 'typing_dialog_inset.dart' show dialogInsetPadding;

enum _RecoveredChoice { backToList, chooseData, keep }

/// What the first screen that opens a work (its details, the canvas or the
/// timeline) does after it is shown:
///
/// - The work file was damaged or missing at start-up, so the work was
///   restored from its newest automatic save: a dialog says so, and offers
///   to go back to the project list, to choose another save to load, or to
///   go on with what was restored.
/// - The app closed before the work file got the last changes, and an
///   automatic save from that launch is newer and different: the work opens
///   with it at once, without asking, and a notice says so. Undo goes back
///   to the work file.
///
/// [saveEntry] is how the save screen opened from the dialog loads a save
/// (`entry` of `/save-tree/:id`). [onRestored] runs after the newer automatic
/// save was put in place.
Future<void> settleOpenedWork(
  BuildContext context,
  String projectId, {
  required String saveEntry,
  VoidCallback? onRestored,
}) async {
  final projects = context.read<ProjectService>();
  final l10n = AppLocalizations.of(context)!;
  final recoveredAt = projects.takeAutosaveRecovery(projectId);
  if (recoveredAt != null) {
    final choice = await showDialog<_RecoveredChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        insetPadding: dialogInsetPadding(dialogContext),
        title: Text(l10n.projectAutosaveRecoveredTitle),
        content: messageText(
          l10n.projectAutosaveRecovered(
            formatSaveTime(recoveredAt, l10n.localeName),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('autosaveRecoveredBackToList'),
            onPressed: () =>
                Navigator.pop(dialogContext, _RecoveredChoice.backToList),
            child: Text(l10n.autosaveRecoveryBackToList),
          ),
          TextButton(
            key: const ValueKey('autosaveRecoveredChooseData'),
            onPressed: () =>
                Navigator.pop(dialogContext, _RecoveredChoice.chooseData),
            child: Text(l10n.autosaveRecoveryChooseData),
          ),
          FilledButton(
            key: const ValueKey('autosaveRecoveredContinue'),
            onPressed: () =>
                Navigator.pop(dialogContext, _RecoveredChoice.keep),
            child: Text(l10n.projectAutosaveRecoveredContinue),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case _RecoveredChoice.backToList:
        // Leaving the work for the list ends this flow: nothing to go back to.
        context.go('/home');
      case _RecoveredChoice.chooseData:
        context.push('/save-tree/$projectId?entry=$saveEntry&source=autosave');
      case _RecoveredChoice.keep || null:
        break;
    }
    return;
  }
  // Screens built without the app's providers (some tests) have none.
  final autosaves = context.read<AutosaveService?>();
  if (autosaves == null) return;
  final newer = await autosaves.newerThanWorkFile(projects, projectId);
  if (newer == null || !context.mounted) return;
  projects.useSavedVersion(projectId, newer.data);
  onRestored?.call();
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      key: const ValueKey('autosaveNewerOpenedNotice'),
      content: Text(
        l10n.autosaveNewerOpenedNotice(
          formatSaveTime(newer.savedAt, l10n.localeName),
        ),
      ),
      duration: const Duration(seconds: 5),
    ),
  );
}
