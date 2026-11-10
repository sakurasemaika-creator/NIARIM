import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/export_share_service.dart';
import '../services/font_service.dart';
import '../services/material_service.dart';
import '../services/project_service.dart';
import '../screens/home/widgets/project_list_widget.dart'
    show buildFontShareBundle, runNiashareFlow;
import '../utils/app_error_reporter.dart';
import 'export_share_feedback.dart';

/// Share the exact saved .niashare bytes, without rebuilding the project.
/// Missing external files are reported rather than silently recreating them.
///
/// 保存したファイルが無くなっていること、共有できない端末、共有の失敗は別の
/// ことなので、別の文で知らせる（OSの例外の文は出さない）。同じファイルの
/// 共有シートが開いている間の二度目は何もしない（失敗の知らせを2つ積まない）。
Future<void> shareSavedNiashare(BuildContext context, String path) {
  // 共有の後は画面が無くなっていることがあるので、先に取っておく。
  final handles = ExportShareHandles.of(context);
  return ExportShareService.runExclusive('saved-niashare:$path', () async {
    final file = File(path);
    if (!await file.exists()) {
      AppErrorReporter.record(
        const FileSystemException('Saved share file is missing'),
        StackTrace.current,
      );
      handles.tell(handles.l10n.communityErrorNotFound);
      return;
    }
    await handles.share(file);
  });
}

/// A deliberate fresh export creates a permanent snapshot and registers it
/// in the "Created" section; the OS share sheet uses that same saved file.
///
/// 作品ごとに一度に1つだけ走り、始めた画面が途中で無くなっても最後まで
/// 行う（`runNiashareFlow`）。進行中かどうかは
/// `ExportShareService.isRunning(niashareKey(project.id))`で分かる。
Future<void> createAndShareProjectNiashare(
  BuildContext context,
  ProjectService service,
  Project project,
) {
  final materialService = context.read<MaterialService>();
  final fontService = context.read<FontService>();
  return runNiashareFlow(
    context,
    project,
    build: (options) async {
      final materials = await materialService.buildShareBundle(
        project.id,
        options.materialTypes,
      );
      final fontBundle = options.includeFonts
          ? await buildFontShareBundle(service, fontService, project.id)
          : (files: <String, Uint8List>{}, manifest: null);
      return service.createOutgoingShare(
        project: project,
        materialFiles: materials.files.isEmpty ? null : materials.files,
        materialsManifest: materials.manifest,
        fontFiles: fontBundle.files.isEmpty ? null : fontBundle.files,
        fontsManifest: fontBundle.manifest,
      );
    },
  );
}
