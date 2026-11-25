import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../config/signal_colors.dart';
import '../../../engine/niapro_serializer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/app_error_reporter.dart';
import '../../../widgets/keep_together_text.dart';
import '../../../widgets/typing_dialog_inset.dart';
import 'save_thumbnail_capture.dart';

Future<Uint8List?> savedThumbnail(NiaproData? data) async {
  if (data == null || !data.hasEditableFrames) return null;
  try {
    return await captureSavedThumbnail(data);
  } catch (error, stack) {
    AppErrorReporter.record(error, stack);
    return null;
  }
}

class SavedThumbnail extends StatelessWidget {
  const SavedThumbnail({
    super.key,
    required this.bytes,
    required this.height,
    this.width,
  });

  final Uint8List? bytes;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Icons.image_outlined,
      color: scheme.onSurfaceVariant,
    );
    final png = bytes;
    return Container(
      width: width ?? double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: png == null
          ? Center(child: placeholder)
          : Image.memory(
              png,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stack) =>
                  Center(child: placeholder),
            ),
    );
  }
}

/// The dialog previews and returns one archive. A newer save arriving while
/// it is open cannot replace the version the user reviewed.
Future<NiaproData?> confirmSavedVersion(
  BuildContext context, {
  required String projectId,
  required Future<NiaproData?> Function() read,
  required String name,
  String? time,
  String? slotLabel,
}) {
  final l10n = AppLocalizations.of(context)!;
  final version = read().then((data) async {
    if (data == null ||
        data.project.id != projectId ||
        !data.hasEditableFrames) {
      return null;
    }
    return (data: data, preview: await savedThumbnail(data));
  });
  return showDialog<NiaproData>(
    context: context,
    builder: (dialogContext) => FutureBuilder(
      future: version,
      builder: (context, snapshot) {
        final save = snapshot.data;
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          scrollable: true,
          insetPadding: dialogInsetPadding(dialogContext),
          title: Text(l10n.saveTreeRestoreAction),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (slotLabel != null)
                      KeepTogetherText(
                        slotLabel,
                        keep: [slotLabel],
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    if (name != slotLabel)
                      messageText(
                        name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    if (time != null) messageText(time),
                    const SizedBox(height: 10),
                    SavedThumbnail(
                      key: const ValueKey('saveRestorePreview'),
                      bytes: save?.preview,
                      height: 124,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              messageText(
                snapshot.connectionState == ConnectionState.done && save == null
                    ? l10n.saveTreeLoadFailedSnackbar
                    : l10n.saveTreeProjectDetailResumeBody,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.commonCancel),
            ),
            // 今の作業は上書きされて戻せないので、取り消せない操作の塗り（警告色）。
            FilledButton(
              style: warningFilledButtonStyle(dialogContext),
              onPressed: save == null
                  ? null
                  : () => Navigator.pop(dialogContext, save.data),
              child: Text(l10n.saveTreeRestoreAction),
            ),
          ],
        );
      },
    ),
  );
}
