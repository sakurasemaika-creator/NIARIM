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
    var draftName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationNewTitle),
        content: TextField(
          autofocus: true,
          onChanged: (value) => draftName = value,
          decoration: InputDecoration(
            labelText: l10n.customAutomationNameLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(dialogContext, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final value = draftName.trim();
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
    var draftName = item.name;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationRenameTitle),
        content: TextFormField(
          initialValue: item.name,
          autofocus: true,
          onChanged: (value) => draftName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, draftName.trim()),
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
    final l10n = AppLocalizations.of(context)!;
    final data = context.read<CustomAutomationService>().exportJson(item);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n.customAutomationExportTitle,
      fileName: '${item.name}.json',
      bytes: Uint8List.fromList(utf8.encode(data)),
    );
    if (path != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.customAutomationExported)),
      );
    }
  }

  Future<void> _import(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    try {
      await context.read<CustomAutomationService>().importJson(
        utf8.decode(bytes),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customAutomationImported)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customAutomationImportFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CustomAutomationService>();
    final items = service.itemsForSurface(surface);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.fiber_manual_record),
            title: Text(l10n.customAutomationNewTitle),
            onTap: () => _startNew(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l10n.customAutomationImportTitle),
            onTap: () => _import(context),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    l10n.customAutomationStepCount(item.steps.length),
                  ),
                  onTap: () => _confirmExecute(context, item),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          _rename(context, item);
                        case 'export':
                          _export(context, item);
                        case 'delete':
                          _delete(context, item);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(l10n.customAutomationRenameTitle),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Text(l10n.customAutomationExportTitle),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.commonDelete),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
