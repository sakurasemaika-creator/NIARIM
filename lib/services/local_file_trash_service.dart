import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_error_reporter.dart';
import 'export_storage.dart';
import 'storage_info_service.dart';
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
    'folderName': ?folderName,
    if (isFolder) 'fileNames': fileNames,
  };
}

/// A directory per item means large videos do not enter preferences or RAM.
/// Metadata is written AFTER the copy is complete and BEFORE deleting the
/// source; an interrupted copy preserves the source and lists nothing.
/// A folder left without metadata (the app stopped during a move, a restore or
/// a permanent delete) is removed at start-up by [sweepExpired].
/// Restore never overwrites an existing file.
abstract final class LocalFileTrashService {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static final Set<String> _movingPaths = {};

  /// Tells listeners that the Trash changed. [exports] is true when exported
  /// works moved into or out of the exports directory: the cached list of
  /// exported files is then dropped, so a Works list built later (the Works
  /// tab after a restore from the Trash tab, a works folder) reads the files
  /// again. A Works tab that was not on screen used to show the list from
  /// before the restore until the app restarted: a restored folder looked
  /// empty and a restored file was missing.
  static void _changed({bool exports = false}) {
    if (exports) ExportStorage.invalidate();
    StorageInfoService().invalidate();
    changes.value++;
  }

  static Future<Directory> _root() async =>
      _rootIn(await getApplicationDocumentsDirectory());

  static Directory _rootIn(Directory documents) =>
      Directory('${documents.path}/niarim/trash/files');

  /// Whether the Trash held file items when it was last read in this process
  /// ([list], [listedSize], the start-up clean-up) or an item was moved in
  /// since; null when not known yet. Removing an item does not change it (it
  /// may stay true until the next read). The storage screen uses it to keep
  /// room for the Trash bar before its scan arrives (the rows below moved
  /// down when the bar came).
  static bool? get hasItems => _hasItems;
  static bool? _hasItems;

  /// The Trash items, newest first.
  ///
  /// The records (meta.json) are read in a background isolate with
  /// synchronous reads. Read on this isolate with asynchronous reads, every
  /// record cost several round trips to the I/O workers (open, length, read,
  /// close, and the check of the copy), and reading them side by side did not
  /// help: 4,000 items kept the Trash tab loading for about 35 seconds (150
  /// under load). The folder itself is still listed here. The items, their
  /// order and the items skipped (unreadable record, copy not finished) are
  /// the same as reading the records one by one.
  static Future<List<LocalTrashedFile>> list() async {
    final folders = await _itemFolders();
    if (folders.isEmpty) {
      _hasItems = false;
      return [];
    }
    final entries = await Isolate.run(
      () => _readItems(folders),
      debugName: 'Trash list',
    );
    _hasItems = entries.isNotEmpty;
    entries.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return entries;
  }

  /// The folders directly in the Trash folder (each item has one), listed on
  /// this isolate. Empty when there is no Trash folder yet. [documents] is
  /// the documents folder when the caller already has it.
  static Future<List<String>> _itemFolders([Directory? documents]) async {
    final root = documents == null ? await _root() : _rootIn(documents);
    if (!await root.exists()) return const [];
    return [
      await for (final entity in root.list(followLinks: false))
        if (entity is Directory) entity.path,
    ];
  }

  /// The bytes used by the items [list] shows (each item's copy and record),
  /// and the first error met while measuring them (that part is not counted).
  /// The storage screen counts them in its Trash category. A folder [list]
  /// does not show (a move still copying, an unreadable record) is not part
  /// of the Trash the person sees and cannot be emptied from it, so it is not
  /// counted: emptying the Trash brings the Trash to 0. Measured in a
  /// background isolate like [list]; throws when the Trash folder cannot be
  /// read, like [list]. [documents] is the documents folder when the caller
  /// already has it.
  static Future<({int bytes, Object? error})> listedSize({
    Directory? documents,
  }) async {
    final folders = await _itemFolders(documents);
    if (folders.isEmpty) {
      _hasItems = false;
      return (bytes: 0, error: null);
    }
    final size = await Isolate.run(
      () => _measureItems(folders),
      debugName: 'Trash size',
    );
    _hasItems = size.items > 0;
    return (bytes: size.bytes, error: size.error);
  }

  static ({int items, int bytes, Object? error}) _measureItems(
    List<String> folders,
  ) {
    var items = 0;
    var bytes = 0;
    Object? error;
    for (final folder in folders) {
      if (_readItem(folder) == null) continue;
      items++;
      try {
        for (final entity in Directory(
          folder,
        ).listSync(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          try {
            bytes += entity.lengthSync();
          } on PathNotFoundException {
            // Removed meanwhile (a restore or a permanent delete).
          } catch (failure) {
            error ??= failure;
          }
        }
      } on PathNotFoundException {
        // Removed meanwhile.
      } catch (failure) {
        error ??= failure;
      }
    }
    return (items: items, bytes: bytes, error: error);
  }

  /// The Trash items of [folders], in the order of [folders].
  static List<LocalTrashedFile> _readItems(List<String> folders) => [
    for (final folder in folders) ?_readItem(folder),
  ];

  /// The Trash item in [folder], or null when its record cannot be read or
  /// its copy is not complete.
  static LocalTrashedFile? _readItem(String folder) {
    try {
      final meta = jsonDecode(File('$folder/meta.json').readAsStringSync());
      if (meta is! Map<String, dynamic>) return null;
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
              Directory(
                folder,
              ).uri.pathSegments.where((part) => part.isNotEmpty).last) {
        return null;
      }
      final archive = '$folder/data';
      final isFolder = kind == LocalTrashKind.exportedWorkFolder;
      if (isFolder
          ? !Directory(archive).existsSync()
          : !File(archive).existsSync()) {
        return null;
      }
      final names = (meta['fileNames'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      if (isFolder &&
          (meta['folderName'] is! String ||
              names.any((name) => !_safeFileName(name)))) {
        return null;
      }
      return LocalTrashedFile(
        id: id,
        kind: kind,
        originalPath: original,
        archivedPath: archive,
        deletedAt: deletedAt,
        folderName: meta['folderName'] as String?,
        fileNames: names,
      );
    } catch (_) {
      // Corrupt metadata does not prevent other entries from being restored.
      return null;
    }
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
    final path = source.absolute.uri.normalizePath().toFilePath();
    if (!_movingPaths.add(path)) {
      throw FileSystemException('File is already being moved', path);
    }
    try {
      return await _moveFile(source, kind);
    } finally {
      _movingPaths.remove(path);
    }
  }

  static Future<LocalTrashedFile> _moveFile(
    File source,
    LocalTrashKind kind,
  ) async {
    if (!await source.exists()) {
      throw FileSystemException('File missing', source.path);
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
      kind: kind,
      originalPath: source.absolute.path,
      archivedPath: '${directory.path}/data',
      deletedAt: DateTime.now(),
    );
    var recorded = false;
    try {
      final saved = await source.copy(entry.archivedPath);
      if (await saved.length() != await source.length()) {
        throw FileSystemException('Incomplete archive copy', source.path);
      }
      await _keepModifiedTime(source, saved);
      // The record makes the item appear in [list]: write it only once the
      // copy is complete, in one step. Written before the copy, a list read
      // during the copy showed a half-copied file, and a failed or killed
      // copy showed a broken item beside the untouched source.
      await _replaceMeta(File('${directory.path}/meta.json'), entry.toJson());
      _hasItems = true;
      recorded = true;
      await source.delete();
      _changed(exports: kind == LocalTrashKind.exportedWork);
      return entry;
    } catch (_) {
      // If source removal failed it remains intact; do not display partial
      // trash entries. A recorded archive is never deleted without its source.
      // A copy without its record is removed even when the source is gone:
      // the source can vanish outside the app during the copy (another app,
      // the same file moved twice), and nothing lists an unrecorded copy, so
      // it could never be restored or deleted and only used storage.
      if (!recorded || await source.exists()) {
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
    if (!await archived.exists()) {
      throw FileSystemException('Trash entry missing', entry.archivedPath);
    }
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
    await _keepModifiedTime(archived, copy);
    await archived.parent.delete(recursive: true);
    _changed(exports: entry.kind == LocalTrashKind.exportedWork);
  }

  /// Archive all actual export files before removing any source.
  static Future<LocalTrashedFile> moveWorkFolder({
    required String folderName,
    required List<File> files,
  }) async {
    final sources = files.map((f) => File(f.absolute.path)).toList();
    // Claim the files like [move]. A file moved on its own while its works
    // folder was being moved (or the reverse) was copied by both; the move
    // that removed the file second could not, kept its recorded copy because
    // the file was gone, and the Trash showed the file twice.
    final paths = {
      for (final file in sources)
        file.absolute.uri.normalizePath().toFilePath(),
    };
    final busy = paths.where(_movingPaths.contains).firstOrNull;
    if (busy != null) {
      throw FileSystemException('File is already being moved', busy);
    }
    _movingPaths.addAll(paths);
    try {
      return await _moveWorkFolder(folderName, sources);
    } finally {
      _movingPaths.removeAll(paths);
    }
  }

  static Future<LocalTrashedFile> _moveWorkFolder(
    String folderName,
    List<File> sources,
  ) async {
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
        await _keepModifiedTime(source, copy);
      }
      // Commit the manifest only after all bytes have been verified.
      // A crash during staging must not expose an incomplete Trash item.
      await _replaceMeta(File('${directory.path}/meta.json'), entry.toJson());
      _hasItems = true;
      for (final source in sources) {
        await source.delete();
        removedAny = true;
      }
      _changed(exports: sources.isNotEmpty);
      return entry;
    } catch (_) {
      // Once a source has been removed, retain all archived bytes.
      if (!removedAny) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {}
      } else {
        _changed(exports: true);
      }
      rethrow;
    }
  }

  /// Give [copy] the modification time of [source]. Copying a file stamps
  /// the copy with the current time, so a file moved to the Trash and back
  /// showed the restore time in the Works list and jumped to the top of the
  /// "last modified" order. The archive keeps the original time, and a
  /// restore gives it back. A file system that cannot set the time leaves the
  /// copy's own time: the file itself is intact.
  static Future<void> _keepModifiedTime(File source, File copy) async {
    try {
      await copy.setLastModified(await source.lastModified());
    } on FileSystemException catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
  }

  /// Compare large files in bounded memory. A source deletion interrupted
  /// after archiving may leave some original files already present; only
  /// byte-identical files are safe to reuse during recovery.
  static Future<bool> _sameFileContents(File a, File b) async {
    if (!await a.exists() ||
        !await b.exists() ||
        await a.length() != await b.length()) {
      return false;
    }
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

  static int _stagingSeed = 0;

  /// Replace the record of a listed Trash item in one step. Rewriting
  /// meta.json in place empties it first, so a [list] that read it during the
  /// write skipped the item: a works folder being restored vanished from the
  /// Trash for a moment (and a restore killed during the write lost the item
  /// for good, its files left unlisted). The new record is finished beside it
  /// and renamed over it, so a reader sees either the old or the new record.
  static Future<void> _replaceMeta(File meta, Map<String, dynamic> json) async {
    final staging = File(
      '${meta.path}.${DateTime.now().microsecondsSinceEpoch}-'
      '${_stagingSeed++}.tmp',
    );
    try {
      await staging.writeAsString(jsonEncode(json), flush: true);
      await staging.rename(meta.path);
    } catch (_) {
      try {
        if (await staging.exists()) await staging.delete();
      } catch (_) {
        // The leftover is removed with its Trash item.
      }
      rethrow;
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
      await _replaceMeta(metaFile, meta);
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
      // An interrupted earlier restore may have left the copy with the time
      // of that copy, so the time is applied to a reused file as well.
      await _keepModifiedTime(source, destination);
      if (restored.add(name)) {
        meta['restoredFiles'] = restored.toList();
        await _replaceMeta(metaFile, meta);
      }
      await workFolders.moveFileToFolder(name, folderId);
    }
    await archive.parent.delete(recursive: true);
    _changed(exports: entry.fileNames.isNotEmpty);
  }

  /// Apply the configured retention period to exported works and saved
  /// outgoing archives, including complete exported-work folders. Native
  /// projects are swept separately by ProjectService.
  ///
  /// Called at start-up, it first removes the folders that have no record
  /// ([_removeUnrecorded]), whatever the retention period.
  static Future<void> sweepExpired(int days) async {
    await _removeUnrecorded();
    if (days <= 0) return;
    final List<LocalTrashedFile> entries;
    try {
      entries = await list();
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      return;
    }
    final now = DateTime.now();
    for (final entry in entries) {
      if (now.difference(entry.deletedAt).inDays < days) continue;
      try {
        await deleteUnlessRestoring(entry);
      } catch (_) {
        // A locked or unreadable entry stays available for retry. Cleanup
        // must never prevent app startup or delete an incomplete recovery.
      }
    }
  }

  /// Bulk cleanup leaves a partially restored folder available for retry.
  static Future<bool> deleteUnlessRestoring(LocalTrashedFile entry) async {
    if (entry.isFolder) {
      final metadata = File(
        '${Directory(entry.archivedPath).parent.path}/meta.json',
      );
      final decoded = jsonDecode(await metadata.readAsString());
      if (decoded is Map && decoded['restoreFolderId'] != null) return false;
    }
    await deleteForever(entry);
    return true;
  }

  /// How long a Trash folder without a record must have been left untouched
  /// before [_removeUnrecorded] removes it. A move writes the record only once
  /// its copy is complete, so the folder of a move that is still running (in
  /// another window of the app) has no record either: its name (the time the
  /// move started) or the file being copied is newer than this.
  static const _unrecordedGrace = Duration(hours: 1);

  /// The folder names [move] and [moveWorkFolder] create (a time in
  /// microseconds). Anything else in the Trash folder is left alone.
  static final _itemFolderName = RegExp(r'^[0-9]+$');

  /// Remove the Trash folders that have no record. A move, a restore or a
  /// permanent delete stopped half way (the app was closed, the device turned
  /// off) leaves such a folder: [list] never shows it, so it could not be
  /// restored or deleted, and the half-copied file kept using storage.
  /// A folder with a record is kept even when the record cannot be read, and
  /// links are not followed. Errors are recorded and never stop start-up.
  static Future<void> _removeUnrecorded() async {
    var removed = false;
    try {
      final root = await _root();
      if (!await root.exists()) {
        _hasItems = false;
        return;
      }
      final cutoff = DateTime.now().subtract(_unrecordedGrace);
      // Whether a folder with a record (an item [list] may show) is left.
      var recorded = false;
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = entity.uri.pathSegments.where((p) => p.isNotEmpty).last;
        final seed = _itemFolderName.hasMatch(name) ? int.tryParse(name) : null;
        if (seed == null) continue;
        try {
          final meta = await FileSystemEntity.type(
            '${entity.path}/meta.json',
            followLinks: false,
          );
          if (meta != FileSystemEntityType.notFound) {
            recorded = true;
            continue;
          }
          if (!await _untouchedSince(entity, seed, cutoff)) continue;
          await entity.delete(recursive: true);
          removed = true;
        } on PathNotFoundException {
          // Removed meanwhile (a permanent delete finishing).
        } catch (error, stackTrace) {
          // Not known: counted as left (the screen keeps room for the bar).
          recorded = true;
          AppErrorReporter.record(error, stackTrace);
        }
      }
      _hasItems = recorded;
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    } finally {
      if (removed) StorageInfoService().invalidate();
    }
  }

  /// Whether nothing in [folder] has been written since [cutoff]: neither the
  /// folder itself (its name is the time its move started) nor a file in it.
  static Future<bool> _untouchedSince(
    Directory folder,
    int seed,
    DateTime cutoff,
  ) async {
    if (DateTime.fromMicrosecondsSinceEpoch(seed).isAfter(cutoff)) {
      return false;
    }
    await for (final entity in folder.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && (await entity.stat()).modified.isAfter(cutoff)) {
        return false;
      }
    }
    return true;
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
    _changed();
  }
}
