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
  ) onExecute;
  final VoidCallback onRecordingStarted;

  const CustomAutomationManagerSheet({
    super.key,
    required this.surface,
    required this.onExecute,
    required this.onRecordingStarted,
  });

  Future<void> _startNew(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationNewTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.customAutomationNameLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(dialogContext, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(l10n.customAutomationStartRecording),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    context.read<CustomAutomationService>().beginDraft(name: name, surface: surface);
    Navigator.pop(context);
    onRecordingStarted();
  }

  Future<void> _confirmExecute(
    BuildContext context,
    CustomAutomation automation,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    var scope = CustomAutomationExecutionScope.currentFrame;
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
                RadioListTile<CustomAutomationExecutionScope>(
                  value: CustomAutomationExecutionScope.currentFrame,
                  groupValue: scope,
                  onChanged: (value) => setState(() => scope = value!),
                  title: Text(l10n.customAutomationCurrentFrame),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<CustomAutomationExecutionScope>(
                  value: CustomAutomationExecutionScope.allFrames,
                  groupValue: scope,
                  onChanged: (value) => setState(() => scope = value!),
                  title: Text(l10n.customAutomationAllFrames),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.commonNo),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.commonYes),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && context.mounted) {
      Navigator.pop(context);
      await onExecute(automation, scope);
    }
  }

  Future<void> _rename(BuildContext context, CustomAutomation item) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: item.name);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationRenameTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
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
    if (bytes == null && file.path != null) {
      bytes = await file.xFile.readAsBytes();
    }
    if (bytes == null || !context.mounted) return;
    try {
      await context.read<CustomAutomationService>().importJson(utf8.decode(bytes));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<CustomAutomationService>();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(l10n.customAutomationAdd),
              onTap: () => _startNew(context),
              trailing: IconButton(
                tooltip: l10n.customAutomationImport,
                icon: const Icon(Icons.file_open_outlined),
                onPressed: () => _import(context),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: service.items.isEmpty
                  ? Center(child: Text(l10n.customAutomationEmpty))
                  : ReorderableListView.builder(
                      itemCount: service.items.length,
                      onReorder: (_, __) {},
                      buildDefaultDragHandles: false,
                      itemBuilder: (context, index) {
                        final item = service.items[index];
                        return ListTile(
                          key: ValueKey(item.id),
                          onTap: () => _confirmExecute(context, item),
                          title: Row(
                            children: [
                              Expanded(child: Text(item.name)),
                              IconButton(
                                tooltip: l10n.customAutomationRenameTitle,
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _rename(context, item),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            l10n.customAutomationStepCount(item.steps.length),
                          ),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: l10n.customAutomationExport,
                                icon: const Icon(Icons.ios_share, size: 18),
                                onPressed: () => _export(context, item),
                              ),
                              IconButton(
                                tooltip: l10n.customAutomationRerecord,
                                icon: const Icon(Icons.fiber_manual_record, size: 18),
                                onPressed: () => _rerecord(context, item),
                              ),
                              IconButton(
                                tooltip: l10n.commonDelete,
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => _delete(context, item),
                              ),
                            ],
                          ),
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
