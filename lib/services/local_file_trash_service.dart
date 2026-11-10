import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Locally owned files are moved to a recoverable archive instead of being
/// permanently deleted from the Works or outgoing .niashare library.
enum LocalTrashKind { outgoingShare, exportedWork }

class LocalTrashedFile {
  const LocalTrashedFile({
    required this.id,
    required this.kind,
    required this.originalPath,
    required this.archivedPath,
    required this.deletedAt,
  });

  final String id;
  final LocalTrashKind kind;
  final String originalPath;
  final String archivedPath;
  final DateTime deletedAt;

  String get fileName => Uri.file(originalPath).pathSegments.last;

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'originalPath': originalPath,
    'deletedAt': deletedAt.toIso8601String(),
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
        final meta = jsonDecode(await File('${entity.path}/meta.json').readAsString());
        if (meta is! Map<String, dynamic>) continue;
        final kindName = meta['kind'];
        final kind = LocalTrashKind.values.where((v) => v.name == kindName).firstOrNull;
        final id = meta['id'];
        final original = meta['originalPath'];
        final deletedAt = DateTime.tryParse(meta['deletedAt'] as String? ?? '');
        if (kind == null || id is! String || original is! String ||
            deletedAt == null || id != entity.uri.pathSegments
                .where((part) => part.isNotEmpty).last) {
          continue;
        }
        final archive = '${entity.path}/data';
        if (!await File(archive).exists()) continue;
        entries.add(LocalTrashedFile(
          id: id, kind: kind, originalPath: original,
          archivedPath: archive, deletedAt: deletedAt,
        ));
      } catch (_) {
        // Corrupt metadata does not prevent other entries from being restored.
      }
    }
    entries.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return entries;
  }

  static Future<LocalTrashedFile> move(File source, LocalTrashKind kind) async {
    if (!await source.exists()) throw FileSystemException('File missing', source.path);
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
      id: '$seed', kind: kind, originalPath: source.absolute.path,
      archivedPath: '${directory.path}/data', deletedAt: DateTime.now(),
    );
    try {
      await File('${directory.path}/meta.json').writeAsString(
        jsonEncode(entry.toJson()), flush: true,
      );
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
        try { await directory.delete(recursive: true); } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> restore(LocalTrashedFile entry) async {
    final archived = File(entry.archivedPath);
    if (!await archived.exists()) throw FileSystemException('Trash entry missing', entry.archivedPath);
    final original = File(entry.originalPath);
    if (await original.exists()) {
      throw FileSystemException('Restore destination already exists', original.path);
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

  static Future<void> deleteForever(LocalTrashedFile entry) async {
    final archive = File(entry.archivedPath);
    if (await archive.exists()) {
      await archive.parent.delete(recursive: true);
    }
    changes.value++;
  }
}
