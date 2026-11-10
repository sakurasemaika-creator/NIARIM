import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../services/export_share_service.dart';
import '../services/font_service.dart';
import '../services/material_service.dart';
import '../services/project_service.dart';
import '../screens/home/widgets/project_list_widget.dart'
    show showMaterialIncludeDialog, buildFontShareBundle;

/// Share the exact saved .niashare bytes, without rebuilding the project.
/// Missing external files are reported rather than silently recreating them.
Future<void> shareSavedNiashare(BuildContext context, String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('Saved share file is missing');
    }
    await ExportShareService.share(file);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!
              .projectDetailNiashareFailedSnackbar('$error'),
        ),
      ),
    );
  }
}

/// A deliberate fresh export creates a permanent snapshot and registers it
/// in the "Created" section; the OS share sheet uses that same saved file.
Future<void> createAndShareProjectNiashare(
  BuildContext context,
  ProjectService service,
  Project project,
) async {
  final options = await showMaterialIncludeDialog(context);
  if (options == null || !context.mounted) return;
  final materialService = context.read<MaterialService>();
  final fontService = context.read<FontService>();
  try {
    final materials = await materialService.buildShareBundle(
      project.id,
      options.materialTypes,
    );
    final fontBundle = options.includeFonts
        ? await buildFontShareBundle(service, fontService, project.id)
        : (files: <String, Uint8List>{}, manifest: null);
    final file = await service.createOutgoingShare(
      project: project,
      materialFiles: materials.files.isEmpty ? null : materials.files,
      materialsManifest: materials.manifest,
      fontFiles: fontBundle.files.isEmpty ? null : fontBundle.files,
      fontsManifest: fontBundle.manifest,
    );
    if (!context.mounted) return;
    await shareSavedNiashare(context, file.path);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!
              .projectDetailNiashareFailedSnackbar('$error'),
        ),
      ),
    );
  }
}
