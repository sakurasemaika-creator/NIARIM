import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/custom_automation.dart';
import '../services/custom_automation_service.dart';

/// Converts Flutter's final reorder index back to the pre-removal index contract
/// used by [CustomAutomationService.reorderDraftStep].
int customAutomationDraftPreRemovalIndex(int oldIndex, int finalIndex) =>
    finalIndex > oldIndex ? finalIndex + 1 : finalIndex;

class CustomAutomationDraftSheet extends StatelessWidget {
  final CustomAutomationSurface surface;
  final VoidCallback onResumeRecording;

  const CustomAutomationDraftSheet({
    super.key,
    required this.surface,
    required this.onResumeRecording,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CustomAutomationService>();
    final draft = service.draft;
    if (draft == null) return const SizedBox.shrink();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            ListTile(
              title: Text(draft.name),
              subtitle: Text(l10n.customAutomationReviewHint),
            ),
            const Divider(height: 1),
            Expanded(
              child: draft.steps.isEmpty
                  ? Center(child: Text(l10n.customAutomationNoRecordedSteps))
                  : ReorderableListView.builder(
                      itemCount: draft.steps.length,
                      onReorderItem: (oldIndex, newIndex) {
                        // The service keeps the original pre-removal index
                        // contract; Flutter now supplies the final index.
                        service.reorderDraftStep(
                          oldIndex,
                          customAutomationDraftPreRemovalIndex(
                            oldIndex,
                            newIndex,
                          ),
                        );
                      },
                      itemBuilder: (context, index) {
                        final step = draft.steps[index];
                        return ListTile(
                          key: ValueKey(step.id),
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          title: Text(step.label),
                          subtitle: Text(
                            step.surface == CustomAutomationSurface.canvas
                                ? l10n.customAutomationCanvasStep
                                : l10n.customAutomationTimelineStep,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: l10n.commonDelete,
                                onPressed: () => service.removeDraftStep(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        service.resumeRecording(surface);
                        onResumeRecording();
                      },
                      icon: const Icon(Icons.fiber_manual_record),
                      label: Text(l10n.customAutomationBackToRecording),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: draft.steps.isEmpty
                          ? null
                          : () async {
                              final saved = await service.saveDraft();
                              if (saved != null && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(l10n.commonSave),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
