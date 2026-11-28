import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../engine/niapro_serializer.dart';
import '../l10n/app_localizations.dart';
import '../screens/save_tree/widgets/save_display_name.dart'
    show formatSaveTime;
import '../services/autosave_service.dart';
import '../services/project_service.dart';
import 'keep_together_text.dart' show messageText;
import 'typing_dialog_inset.dart' show dialogInsetPadding;

enum _RecoveredChoice { cancel, chooseData, keep }

/// What the first screen that opens a work (its details, the canvas or the
/// timeline) does after it is shown:
///
/// - The work file was damaged or missing at start-up, so the work was
///   restored from its newest automatic save: a dialog says so, and offers
///   to cancel (back to the screen the work was opened from), to choose
///   another save to load, or to go on with what was restored.
/// - The app closed before the work file got the last changes, and an
///   automatic save from that launch is newer and different: the work opens
///   with it at once, without asking or telling (the newest content is what
///   anyone expects to see), and the work's last-saved time becomes the
///   automatic save's. Undo goes back to the work file. Usually this has
///   already happened after start-up ([ProjectService.settleNewerAutosaves]).
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
  // A work listed before its tiles were checked is checked (and restored
  // when damaged) as its picture is read.
  projects.readTilesNow(projectId);
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
            key: const ValueKey('autosaveRecoveredCancel'),
            onPressed: () =>
                Navigator.pop(dialogContext, _RecoveredChoice.cancel),
            child: Text(l10n.commonCancel),
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
      case _RecoveredChoice.cancel:
        // Back to where the work was opened from (the list, or the work's
        // details for the canvas). Opened with nothing behind it, the list.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
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
  final project = projects.projects.where((p) => p.id == projectId).firstOrNull;
  if (project == null) return;
  final tiles = projects.tileManagerOf(projectId);
  final content = NiaproSerializer.contentSignature(
    project,
    projects.scenesOf(projectId),
  );
  final newer = await autosaves.newerThanWorkFile(projects, projectId);
  if (newer == null || !context.mounted) return;
  // Reading and comparing the automatic save takes a moment: a work already
  // changed meanwhile (the canvas was opened and drawn on) is not replaced.
  final now = projects.projects.where((p) => p.id == projectId).firstOrNull;
  if (now == null ||
      !identical(projects.tileManagerOf(projectId), tiles) ||
      tiles.hasDirtyTiles ||
      NiaproSerializer.contentSignature(now, projects.scenesOf(projectId)) !=
          content) {
    return;
  }
  projects.useSavedVersion(projectId, newer.data, savedAt: newer.savedAt);
  onRestored?.call();
}
