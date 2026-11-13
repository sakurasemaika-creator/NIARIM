import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'work_folder_service.dart';

/// Locally owned files are moved to a recoverable archive instead of being
/// permanently deleted from the Works or outgoing .niashare library.
enum LocalTrashKind { outgoingShare, exportedWork, exportedWorkFolder }

class LocalTrashedFile {
  const LocalTrashedFile({
    required this.id,
    required this.kind,
    required this.originalPath,
    required this.archivedPath,
    required this.deletedAt,
    this.folderName,
    this.fileNames = const [],
  });

  final String id;
  final LocalTrashKind kind;
  final String originalPath;
  final String archivedPath;
  final DateTime deletedAt;
  final String? folderName;
  final List<String> fileNames;
  bool get isFolder => kind == LocalTrashKind.exportedWorkFolder;

  String get fileName => folderName ?? Uri.file(originalPath).pathSegments.last;

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'originalPath': originalPath,
    'deletedAt': deletedAt.toIso8601String(),
    if (folderName != null) 'folderName': folderName!,
    if (isFolder) 'fileNames': fileNames,
  };
}

/// A directory per item means large videos do not enter preferences or RAM.
/// Metadata is written BEFORE deleting the source; an interrupted copy
/// preserves the source. Restore never overwrites an existing file.
abstract final class LocalFileTrashService {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static Future<Directory> _root() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/niarim/trash/files');
  }

  static Future<List<LocalTrashedFile>> list() async {
    final root = await _root();
    if (!await root.exists()) return const [];
    final entries = <LocalTrashedFile>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      try {
        final meta = jsonDecode(
          await File('${entity.path}/meta.json').readAsString(),
        );
        if (meta is! Map<String, dynamic>) continue;
        final kindName = meta['kind'];
        final kind = LocalTrashKind.values
            .where((v) => v.name == kindName)
            .firstOrNull;
        final id = meta['id'];
        final original = meta['originalPath'];
        final deletedAt = DateTime.tryParse(meta['deletedAt'] as String? ?? '');
        if (kind == null ||
            id is! String ||
            original is! String ||
            deletedAt == null ||
            id !=
                entity.uri.pathSegments.where((part) => part.isNotEmpty).last) {
          continue;
        }
        final archive = '${entity.path}/data';
        final isFolder = kind == LocalTrashKind.exportedWorkFolder;
        if (isFolder
            ? !await Directory(archive).exists()
            : !await File(archive).exists())
          continue;
        final names = (meta['fileNames'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
        if (isFolder &&
            (meta['folderName'] is! String ||
                names.any((name) => !_safeFileName(name))))
          continue;
        entries.add(
          LocalTrashedFile(
            id: id,
            kind: kind,
            originalPath: original,
            archivedPath: archive,
            deletedAt: deletedAt,
            folderName: meta['folderName'] as String?,
            fileNames: names,
          ),
        );
      } catch (_) {
        // Corrupt metadata does not prevent other entries from being restored.
      }
    }
    entries.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return entries;
  }

  static bool _safeFileName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains('\\');

  static Future<LocalTrashedFile> move(File source, LocalTrashKind kind) async {
    if (kind == LocalTrashKind.exportedWorkFolder) {
      throw ArgumentError('Use moveWorkFolder for a folder');
    }
    if (!await source.exists())
      throw FileSystemException('File missing', source.path);
    final root = await _root();
    await root.create(recursive: true);
    var seed = DateTime.now().microsecondsSinceEpoch;
    var directory = Directory('${root.path}/$seed');
    while (await directory.exists()) {
      seed++;
      directory = Directory('${root.path}/$seed');
    }
    await directory.create(recursive: true);
    final entry = LocalTrashedFile(
      id: '$seed',
      kind: kind,
      originalPath: source.absolute.path,
      archivedPath: '${directory.path}/data',
      deletedAt: DateTime.now(),
    );
    try {
      await File('${directory.path}/meta.json')
          .writeAsString(jsonEncode(entry.toJson()), flush: true);
      final saved = await source.copy(entry.archivedPath);
      if (await saved.length() != await source.length()) {
        throw FileSystemException('Incomplete archive copy', source.path);
      }
      await source.delete();
      changes.value++;
      return entry;
    } catch (_) {
      // If source removal failed it remains intact; do not display partial
      // trash entries. A complete archive is never deleted without its source.
      if (await source.exists()) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> restore(LocalTrashedFile entry) async {
    if (entry.isFolder) throw ArgumentError('Use restoreWorkFolder');
    final archived = File(entry.archivedPath);
    if (!await archived.exists())
      throw FileSystemException('Trash entry missing', entry.archivedPath);
    final original = File(entry.originalPath);
    if (await original.exists()) {
      throw FileSystemException(
        'Restore destination already exists',
        original.path,
      );
    }
    await original.parent.create(recursive: true);
    final copy = await archived.copy(original.path);
    if (await copy.length() != await archived.length()) {
      await copy.delete();
      throw FileSystemException('Incomplete restored copy', original.path);
    }
    await archived.parent.delete(recursive: true);
    changes.value++;
  }

  /// Archive all actual export files before removing any source.
  static Future<LocalTrashedFile> moveWorkFolder({
    required String folderName,
    required List<File> files,
  }) async {
    final sources = files.map((f) => File(f.absolute.path)).toList();
    final names = <String>[];
    for (final file in sources) {
      if (!await file.exists()) {
        throw FileSystemException('Export missing', file.path);
      }
      final name = file.uri.pathSegments.last;
      if (!_safeFileName(name) ||
          names.contains(name) ||
          file.parent.path != sources.first.parent.path) {
        throw FileSystemException('Invalid folder export', file.path);
      }
      names.add(name);
    }
    final root = await _root();
    await root.create(recursive: true);
    var seed = DateTime.now().microsecondsSinceEpoch;
    var directory = Directory('${root.path}/$seed');
    while (await directory.exists()) {
      seed++;
      directory = Directory('${root.path}/$seed');
    }
    await directory.create(recursive: true);
    final entry = LocalTrashedFile(
      id: '$seed',
      kind: LocalTrashKind.exportedWorkFolder,
      originalPath: sources.isEmpty ? '' : sources.first.parent.path,
      archivedPath: '${directory.path}/data',
      deletedAt: DateTime.now(),
      folderName: folderName,
      fileNames: names,
    );
    var removedAny = false;
    try {
      final archive = Directory(entry.archivedPath);
      await archive.create();
      for (final source in sources) {
        final copy = await source.copy(
          '${archive.path}/${source.uri.pathSegments.last}',
        );
        if (await copy.length() != await source.length()) {
          throw FileSystemException('Incomplete folder archive', source.path);
        }
      }
      // Commit the manifest only after all bytes have been verified.
      // A crash during staging must not expose an incomplete Trash item.
      await File('${directory.path}/meta.json')
          .writeAsString(jsonEncode(entry.toJson()), flush: true);
      for (final source in sources) {
        await source.delete();
        removedAny = true;
      }
      changes.value++;
      return entry;
    } catch (_) {
      // Once a source has been removed, retain all archived bytes.
      if (!removedAny) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {}
      } else {
        changes.value++;
      }
      rethrow;
    }
  }

  /// Compare large files in bounded memory. A source deletion interrupted
  /// after archiving may leave some original files already present; only
  /// byte-identical files are safe to reuse during recovery.
  static Future<bool> _sameFileContents(File a, File b) async {
    if (!await a.exists() ||
        !await b.exists() ||
        await a.length() != await b.length())
      return false;
    final left = await a.open();
    final right = await b.open();
    try {
      while (true) {
        final one = await left.read(65536);
        final two = await right.read(65536);
        if (!listEquals(one, two)) return false;
        if (one.isEmpty) return true;
      }
    } finally {
      await left.close();
      await right.close();
    }
  }

  /// Resumes an interrupted restore without overwriting unrelated files.
  /// A verified copy is checkpointed before updating its folder membership.
  static Future<void> restoreWorkFolder(
    LocalTrashedFile entry,
    WorkFolderService workFolders,
  ) async {
    if (!entry.isFolder) throw ArgumentError('Not an export folder');
    final archive = Directory(entry.archivedPath);
    if (!await archive.exists()) {
      throw FileSystemException('Archived folder missing', archive.path);
    }
    final metaFile = File('${archive.parent.path}/meta.json');
    final meta =
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    final restored = (meta['restoredFiles'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet();
    final savedId = meta['restoreFolderId'] as String?;
    final known = workFolders.folders.any((f) => f.id == savedId);
    for (final name in entry.fileNames) {
      if (!_safeFileName(name) ||
          !await File('${archive.path}/$name').exists()) {
        throw FileSystemException('Archived file missing', name);
      }
      if (entry.originalPath.isEmpty) {
        throw FileSystemException('Export directory missing', name);
      }
      final destination = File('${entry.originalPath}/$name');
      if (await destination.exists() &&
          !await _sameFileContents(
            File('${archive.path}/$name'),
            destination,
          )) {
        throw FileSystemException(
          'Different file already exists on restore',
          name,
        );
      }
    }
    final folderId = known
        ? savedId!
        : (await workFolders.createFolder(
            entry.folderName ?? 'Restored folder',
          )).id;
    if (!known) {
      meta['restoreFolderId'] = folderId;
      await metaFile.writeAsString(jsonEncode(meta), flush: true);
    }
    for (final name in entry.fileNames) {
      final source = File('${archive.path}/$name');
      final destination = File('${entry.originalPath}/$name');
      if (!await destination.exists()) {
        await destination.parent.create(recursive: true);
        final copy = await source.copy(destination.path);
        if (await copy.length() != await source.length()) {
          await copy.delete();
          throw FileSystemException('Incomplete restored file', name);
        }
      } else if (!await _sameFileContents(source, destination)) {
        throw FileSystemException(
          'Restored file changed during recovery',
          name,
        );
      }
      if (restored.add(name)) {
        meta['restoredFiles'] = restored.toList();
        await metaFile.writeAsString(jsonEncode(meta), flush: true);
      }
      await workFolders.moveFileToFolder(name, folderId);
    }
    await archive.parent.delete(recursive: true);
    changes.value++;
  }

  /// Apply the configured retention period to exported works and saved
  /// outgoing archives, including complete exported-work folders. Native
  /// projects are swept separately by ProjectService.
  static Future<void> sweepExpired(int days) async {
    if (days <= 0) return;
    final now = DateTime.now();
    for (final entry in await list()) {
      if (now.difference(entry.deletedAt).inDays < days) continue;
      try {
        if (entry.isFolder) {
          final metadata = File(
            '${Directory(entry.archivedPath).parent.path}/meta.json',
          );
          final decoded = jsonDecode(await metadata.readAsString());
          if (decoded is Map && decoded['restoreFolderId'] != null) {
            // A partially restored directory may still be the only safe copy
            // of some files. Do not expire it until restore completes.
            continue;
          }
        }
        await deleteForever(entry);
      } catch (_) {
        // A locked or unreadable entry stays available for retry. Cleanup
        // must never prevent app startup or delete an incomplete recovery.
      }
    }
  }

  static Future<void> deleteForever(LocalTrashedFile entry) async {
    if (entry.isFolder) {
      final directory = Directory(entry.archivedPath);
      if (await directory.parent.exists()) {
        await directory.parent.delete(recursive: true);
      }
    } else {
      final archive = File(entry.archivedPath);
      if (await archive.exists()) {
        await archive.parent.delete(recursive: true);
      }
    }
    changes.value++;
  }
}
