import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../engine/niapro_serializer.dart';
import '../engine/tile_manager.dart';
import '../models/project.dart';
import '../models/scene.dart';
import '../utils/app_error_reporter.dart';

/// An immutable .niashare snapshot, independent of its source project.
class SavedOutgoingShare {
  const SavedOutgoingShare({
    required this.path,
    required this.name,
    required this.updatedAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime updatedAt;
  final int sizeBytes;
}

/// Exported shares are kept outside source-project folders, so deleting or
/// editing the source project never silently changes a stored share.
abstract final class OutgoingShareLibrary {
  static Future<Directory> _root() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/niarim/shared/outgoing');
  }

  static Future<File> save({
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
    Map<String, Uint8List>? materialFiles,
    String? materialsManifest,
    Map<String, Uint8List>? fontFiles,
    String? fontsManifest,
    Directory? libraryRoot,
  }) async {
    final root = libraryRoot ?? await _root();
    await root.create(recursive: true);
    // Each explicit export is a distinct frozen snapshot, including exports
    // with different bundled-material options.
    var suffix = DateTime.now().microsecondsSinceEpoch;
    var directory = Directory('${root.path}/$suffix');
    while (await directory.exists()) {
      suffix++;
      directory = Directory('${root.path}/$suffix');
    }
    await directory.create(recursive: true);
    try {
      return await NiaproSerializer.saveShare(
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        outputDir: directory.path,
        materialFiles: materialFiles,
        materialsManifest: materialsManifest,
        fontFiles: fontFiles,
        fontsManifest: fontsManifest,
      );
    } catch (_) {
      try {
        if (await directory.exists()) await directory.delete(recursive: true);
      } catch (_) {
        // Preserve the original export error.
      }
      rethrow;
    }
  }

  /// Include pre-existing .niashare files in source-project folders without
  /// moving or deleting those legacy files.
  static Future<List<SavedOutgoingShare>> list({
    Directory? libraryRoot,
    Directory? legacyProjectsRoot,
  }) async {
    final root = libraryRoot ?? await _root();
    final projects =
        legacyProjectsRoot ??
        Directory(await NiaproSerializer.projectsBasePath());
    final files = <File>[];

    void collect(Directory directory) {
      if (!directory.existsSync()) return;
      try {
        for (final entry in directory.listSync(followLinks: false)) {
          if (entry is File && entry.path.toLowerCase().endsWith('.niashare')) {
            files.add(entry);
          } else if (entry is Directory) {
            try {
              files.addAll(
                entry
                    .listSync(followLinks: false)
                    .whereType<File>()
                    .where(
                      (file) => file.path.toLowerCase().endsWith('.niashare'),
                    ),
              );
            } on FileSystemException catch (error, stackTrace) {
              // A single unreadable directory must not hide other exports.
              AppErrorReporter.record(error, stackTrace);
            }
          }
        }
      } on FileSystemException catch (error, stackTrace) {
        // Missing or unreadable paths are not an empty project library.
        AppErrorReporter.record(error, stackTrace);
      }
    }

    collect(root);
    collect(projects);
    final uniquePaths = <String>{};
    final result = <SavedOutgoingShare>[];
    for (final file in files) {
      if (!uniquePaths.add(file.absolute.path)) continue;
      try {
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) continue;
        final filename = file.uri.pathSegments.last;
        final hasExtension = filename.toLowerCase().endsWith('.niashare');
        result.add(
          SavedOutgoingShare(
            path: file.path,
            name: hasExtension
                ? filename.substring(0, filename.length - '.niashare'.length)
                : filename,
            updatedAt: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      } on FileSystemException {
        // Files removed externally are simply absent at the next refresh.
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }
}
