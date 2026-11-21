import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/app_error_reporter.dart';

/// 保存・初期化でNIARIMが所有する領域と、以前の共有保存先を分ける。
abstract final class ExportStorage {
  static int _generation = 0;

  static int get generation => _generation;

  static void invalidate() => _generation++;

  static Directory managedDirectoryIn(Directory documents) =>
      Directory('${documents.path}/niarim/exports');

  static Future<Directory> createManagedDirectory() async {
    final directory = managedDirectoryIn(
      await getApplicationDocumentsDirectory(),
    );
    await directory.create(recursive: true);
    return directory;
  }

  static const imageStagingPrefix = '.export-';

  /// Call during startup, before this process can start a new export.
  static Future<void> cleanInterruptedImageExports() async {
    var changed = false;
    try {
      final directory = managedDirectoryIn(
        await getApplicationDocumentsDirectory(),
      );
      if (!await directory.exists()) return;
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! Directory) continue;
        final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (!name.startsWith(imageStagingPrefix)) continue;
        try {
          await entry.delete(recursive: true);
          changed = true;
        } on FileSystemException catch (error, stack) {
          AppErrorReporter.record(error, stack);
        }
      }
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    } finally {
      if (changed) invalidate();
    }
  }

  /// 以前のファイルを移動・削除せず、新旧両方の保存先を読み取る。
  static Future<List<File>> listFiles() async {
    final documents = await getApplicationDocumentsDirectory();
    final managed = managedDirectoryIn(documents);
    await managed.create(recursive: true);
    final files = <File>[];
    for (final directory in [managed, Directory('${documents.path}/exports')]) {
      if (!await directory.exists()) continue;
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! File) continue;
        final path = entry.path.toLowerCase();
        if ([
          '.mp4',
          '.webm',
          '.avi',
          '.gif',
          '.png',
          '.jpg',
          '.jpeg',
        ].any(path.endsWith)) {
          files.add(entry);
        }
      }
    }
    return files;
  }
}
