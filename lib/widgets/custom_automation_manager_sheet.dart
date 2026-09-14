import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/custom_automation.dart';
import '../services/custom_automation_service.dart';

class CustomAutomationManagerSheet extends StatelessWidget {
  final CustomAutomationSurface surface;
  final Future<void> Function(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
    List<int>? targetFrames,
  )
  onExecute;
  final VoidCallback onRecordingStarted;
  final int? recordingStartFrame;
  final int? frameCount;

  const CustomAutomationManagerSheet({
    super.key,
    required this.surface,
    required this.onExecute,
    required this.onRecordingStarted,
    this.recordingStartFrame,
    this.frameCount,
  });

  Future<void> _startNew(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    var nameValue = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationNewTitle),
        content: TextFormField(
          initialValue: nameValue,
          autofocus: true,
          onChanged: (value) => nameValue = value,
          decoration: InputDecoration(
            labelText: l10n.customAutomationNameLabel,
            border: const OutlineInputBorder(),
          ),
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty)
              Navigator.pop(dialogContext, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final value = nameValue.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(l10n.customAutomationStartRecording),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    context.read<CustomAutomationService>().beginDraft(
      name: name,
      surface: surface,
      recordingStartFrame: recordingStartFrame,
    );
    Navigator.pop(context);
    onRecordingStarted();
  }

  Future<void> _confirmExecute(
    BuildContext context,
    CustomAutomation automation,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    var scope = CustomAutomationExecutionScope.currentFrame;
    var fromText = '1';
    var toText = '${frameCount ?? 1}';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.customAutomationRunConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(automation.name),
              if (automation.supportsFrameScopeChoice) ...[
                const SizedBox(height: 12),
                RadioGroup<CustomAutomationExecutionScope>(
                  groupValue: scope,
                  onChanged: (value) {
                    if (value != null) setState(() => scope = value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<CustomAutomationExecutionScope>(
                        value: CustomAutomationExecutionScope.currentFrame,
                        title: Text(l10n.customAutomationCurrentFrame),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<CustomAutomationExecutionScope>(
                        value: CustomAutomationExecutionScope.allFrames,
                        title: Text(l10n.customAutomationAllFrames),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<CustomAutomationExecutionScope>(
                        value: CustomAutomationExecutionScope.specifiedFrames,
                        title: Text(l10n.customAutomationSpecifiedFrames),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (scope ==
                          CustomAutomationExecutionScope.specifiedFrames)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: fromText,
                                  onChanged: (value) => fromText = value,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l10n.customAutomationFrameFrom,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('–'),
                              ),
                              Expanded(
                                child: TextFormField(
                                  initialValue: toText,
                                  onChanged: (value) => toText = value,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: l10n.customAutomationFrameTo,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.customAutomationNo),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.customAutomationYes),
            ),
          ],
        ),
      ),
    );
    List<int>? targetFrames;
    if (accepted == true &&
        scope == CustomAutomationExecutionScope.specifiedFrames) {
      final from = int.tryParse(fromText.trim());
      final to = int.tryParse(toText.trim());
      final maxFrame = frameCount ?? 0;
      final valid =
          from != null &&
          to != null &&
          from >= 1 &&
          to >= from &&
          maxFrame > 0 &&
          to <= maxFrame;
      if (!valid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.customAutomationFrameRangeInvalid)),
          );
        }
        return;
      }
      targetFrames = List<int>.generate(
        to - from + 1,
        (index) => from - 1 + index,
      );
    }
    if (accepted == true && context.mounted) {
      Navigator.pop(context);
      await onExecute(automation, scope, targetFrames);
    }
  }

  Future<void> _rename(BuildContext context, CustomAutomation item) async {
    final l10n = AppLocalizations.of(context)!;
    var nameValue = item.name;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationRenameTitle),
        content: TextFormField(
          initialValue: nameValue,
          autofocus: true,
          onChanged: (value) => nameValue = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameValue.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty && context.mounted) {
      await context.read<CustomAutomationService>().rename(item.id, value);
    }
  }

  Future<void> _delete(BuildContext context, CustomAutomation item) async {
    final l10n = AppLocalizations.of(context)!;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationDeleteTitle),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      await context.read<CustomAutomationService>().delete(item.id);
    }
  }

  Future<void> _export(BuildContext context, CustomAutomation item) async {
    final service = context.read<CustomAutomationService>();
    final bytes = Uint8List.fromList(utf8.encode(service.exportJson(item.id)));
    await FilePicker.platform.saveFile(
      dialogTitle: item.name,
      fileName: '${item.name}.niarim-action.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
  }

  Future<void> _import(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;
    final file = result.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null)
      bytes = await file.xFile.readAsBytes();
    if (bytes == null || !context.mounted) return;
    try {
      await context.read<CustomAutomationService>().importJson(
        utf8.decode(bytes),
      );
    } on FormatException {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.customAutomationImportInvalid)),
      );
    }
  }

  void _rerecord(BuildContext context, CustomAutomation item) {
    final service = context.read<CustomAutomationService>();
    service.editExisting(item.id);
    service.resumeRecording(surface);
    Navigator.pop(context);
    onRecordingStarted();
  }

  Future<void> _showItemManager(
    BuildContext context,
    CustomAutomation item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<CustomAutomationService>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.name),
              subtitle: Text(l10n.customAutomationStepCount(item.steps.length)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(l10n.customAutomationRunAction),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmExecute(context, item);
              },
            ),
            ListTile(
              leading: Icon(
                service.isFavorite(item.id) ? Icons.star : Icons.star_border,
              ),
              title: Text(
                service.isFavorite(item.id)
                    ? l10n.customAutomationUnfavoriteAction
                    : l10n.customAutomationFavoriteAction,
              ),
              onTap: () async {
                await service.toggleFavorite(item.id);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.customAutomationRenameTitle),
              onTap: () {
                Navigator.pop(sheetContext);
                _rename(context, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.customAutomationExport),
              onTap: () {
                Navigator.pop(sheetContext);
                _export(context, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fiber_manual_record),
              title: Text(l10n.customAutomationRerecord),
              onTap: () {
                Navigator.pop(sheetContext);
                _rerecord(context, item);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.commonDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _delete(context, item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CustomAutomationService>();
    final visibleItems = service.visibleItems;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(l10n.customAutomationAdd),
              onTap: () => _startNew(context),
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    key: const ValueKey('custom-automation-favorites-only'),
                    tooltip: service.favoritesOnly ? 'すべて表示' : 'お気に入りのみ',
                    icon: Icon(
                      service.favoritesOnly ? Icons.star : Icons.star_border,
                    ),
                    onPressed: () =>
                        service.setFavoritesOnly(!service.favoritesOnly),
                  ),
                  IconButton(
                    tooltip: l10n.customAutomationImport,
                    icon: const Icon(Icons.file_open_outlined),
                    onPressed: () => _import(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visibleItems.isEmpty
                  ? Center(child: Text(l10n.customAutomationEmpty))
                  : ListView.builder(
                      itemCount: visibleItems.length,
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        final favorite = service.isFavorite(item.id);
                        return ListTile(
                          key: ValueKey(item.id),
                          onTap: () => _showItemManager(context, item),
                          title: Text(item.name),
                          subtitle: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l10n.customAutomationStepCount(
                                  item.steps.length,
                                ),
                              ),
                              if (favorite) const Icon(Icons.star, size: 16),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomAutomationDraftEditorSheet extends StatelessWidget {
  final CustomAutomationSurface surface;
  final VoidCallback onResumeRecording;
  final VoidCallback onSaved;

  const CustomAutomationDraftEditorSheet({
    super.key,
    required this.surface,
    required this.onResumeRecording,
    required this.onSaved,
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
              subtitle: Text(
                l10n.customAutomationStepCount(draft.steps.length),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: draft.steps.length,
                onReorderItem: service.reorderDraftStep,
                buildDefaultDragHandles: false,
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
                      step.command,
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle, size: 20),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
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
                        service.resumeRecording(surface);
                        Navigator.pop(context);
                        onResumeRecording();
                      },
                      icon: const Icon(Icons.fiber_manual_record),
                      label: Text(l10n.customAutomationReturnToRecording),
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
                                onSaved();
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

class CustomAutomationRecordingStopButton extends StatefulWidget {
  final VoidCallback onStop;

  const CustomAutomationRecordingStopButton({super.key, required this.onStop});

  @override
  State<CustomAutomationRecordingStopButton> createState() =>
      _CustomAutomationRecordingStopButtonState();
}

class _CustomAutomationRecordingStopButtonState
    extends State<CustomAutomationRecordingStopButton> {
  Offset offset = const Offset(16, 80);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                final size = MediaQuery.sizeOf(context);
                setState(() {
                  offset = Offset(
                    (offset.dx + details.delta.dx).clamp(0, size.width - 160),
                    (offset.dy + details.delta.dy).clamp(0, size.height - 56),
                  );
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.drag_indicator, size: 20),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onStop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.customAutomationStopRecording),
            ),
          ],
        ),
      ),
    );
  }
}
