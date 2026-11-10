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
    show showMaterialIncludeDialog, buildFontShareBundle, niashareKey;
import '../utils/app_error_reporter.dart';
import 'export_share_feedback.dart';

/// Share the exact saved .niashare bytes, without rebuilding the project.
/// Missing external files are reported rather than silently recreating them.
///
/// 保存したファイルが無くなっていること、共有できない端末、共有の失敗は別の
/// ことなので、別の文で知らせる（OSの例外の文は出さない）。同じファイルの
/// 共有シートが開いている間の二度目は何もしない（失敗の知らせを2つ積まない）。
Future<void> shareSavedNiashare(BuildContext context, String path) =>
    ExportShareService.runExclusive('saved-niashare:$path', () async {
      final file = File(path);
      // 1回の確認なので同期で見る（待つと、その間に画面が無くなりうる）。
      if (!file.existsSync()) {
        AppErrorReporter.record(
          const FileSystemException('Saved share file is missing'),
          StackTrace.current,
        );
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.communityErrorNotFound),
          ),
        );
        return;
      }
      await shareExportedFileWithNotice(context, file);
    });

/// A deliberate fresh export creates a permanent snapshot and registers it
/// in the "Created" section; the OS share sheet uses that same saved file.
///
/// 同じ作品の作成・共有が終わるまで二度目は始めない（ホームの一覧のメニューの
/// 共有とも同じ名前で止め合う）。作成の失敗と、共有できない端末・共有の失敗は
/// 別のことなので、別の文で知らせる。[onBuilding]は同梱の確認を終えて作成を
/// 始めるときに呼ぶ（呼び出し側が進行中の印を出す）。
Future<void> createAndShareProjectNiashare(
  BuildContext context,
  ProjectService service,
  Project project, {
  VoidCallback? onBuilding,
}) => ExportShareService.runExclusive(niashareKey(project.id), () async {
  final options = await showMaterialIncludeDialog(context);
  if (options == null || !context.mounted) return;
  onBuilding?.call();
  final l10n = AppLocalizations.of(context)!;
  final materialService = context.read<MaterialService>();
  final fontService = context.read<FontService>();
  final File file;
  try {
    final materials = await materialService.buildShareBundle(
      project.id,
      options.materialTypes,
    );
    final fontBundle = options.includeFonts
        ? await buildFontShareBundle(service, fontService, project.id)
        : (files: <String, Uint8List>{}, manifest: null);
    file = await service.createOutgoingShare(
      project: project,
      materialFiles: materials.files.isEmpty ? null : materials.files,
      materialsManifest: materials.manifest,
      fontFiles: fontBundle.files.isEmpty ? null : fontBundle.files,
      fontsManifest: fontBundle.manifest,
    );
  } catch (error, stackTrace) {
    AppErrorReporter.record(error, stackTrace);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.projectDetailNiashareFailedSnackbar('$error')),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  await shareSavedNiashare(context, file.path);
});
