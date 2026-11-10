import 'dart:io';

import 'package:path_provider/path_provider.dart';

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
