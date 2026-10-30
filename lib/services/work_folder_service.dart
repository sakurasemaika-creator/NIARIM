import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'project_service.dart' show ProjectFolder;
import '../utils/tolerant_preferences.dart';
import '../utils/folder_persistence.dart';

/// A rejected save, including whether an earlier write could not be rolled back.
class WorkFolderSaveException extends FolderSaveException {
  const WorkFolderSaveException({required super.partiallySaved, super.cause});

  @override
  String toString() =>
      'WorkFolderSaveException(partiallySaved: $partiallySaved)';
}

/// ホーム画面「作品一覧」タブ（書き出し済み動画・GIFファイル）のフォルダ
/// 整理機能。作品一覧のファイルはプロジェクトのようなDBエントリではなく
/// ディスク上の実ファイルのため、ファイル名（ExportEngineが生成する
/// 一意なタイムスタンプ付きファイル名）をキーにフォルダ所属を
/// SharedPreferencesへ保存する。ネストはサポートしない（常にルート直下の
/// 1階層のみ。共有タブのフォルダと同じ設計判断）。
class WorkFolderService extends ChangeNotifier {
  final List<ProjectFolder> _folders = [];
  // ファイル名 → フォルダID
  final Map<String, String> _fileFolder = {};
  Future<void>? _pending;
  bool _disposed = false;

  List<ProjectFolder> get folders => List.unmodifiable(_folders);

  String? folderIdOf(String fileName) => _fileFolder[fileName];

  static const _foldersPrefsKey = 'work_folders';
  static const _fileFolderPrefsKey = 'work_file_folder_map';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawFolders = prefs.readString(_foldersPrefsKey);
      if (rawFolders != null) {
        final list = jsonDecode(rawFolders) as List<dynamic>;
        _folders
          ..clear()
          ..addAll(
            list.map((e) => ProjectFolder.fromJson(e as Map<String, dynamic>)),
          );
      }
      final rawMap = prefs.readString(_fileFolderPrefsKey);
      if (rawMap != null) {
        final map = jsonDecode(rawMap) as Map<String, dynamic>;
        _fileFolder
          ..clear()
          ..addAll(map.map((k, v) => MapEntry(k, v as String)));
      }
    } catch (_) {
      // 読み込み失敗時は空状態として続行
    }
    _notify();
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (_disposed) return Future.error(StateError('Work folders disposed'));
    final result = _pending == null
        ? Future<T>.sync(operation)
        : _pending!.then((_) => operation());
    // A rejected operation must not prevent the next attempt from running.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Future<void> _write(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) async {
    // Preserve even malformed legacy value types when restoring a failed write.
    final accepted = switch (value) {
      null => await prefs.remove(key),
      String value => await prefs.setString(key, value),
      bool value => await prefs.setBool(key, value),
      int value => await prefs.setInt(key, value),
      double value => await prefs.setDouble(key, value),
      List<Object?> value when value.every((item) => item is String) =>
        await prefs.setStringList(key, value.cast<String>()),
      _ => throw StateError('Unsupported preference value'),
    };
    if (!accepted) throw StateError('Work folder preference write rejected');
  }

  static bool _sameValue(Object? a, Object? b) =>
      a is List<Object?> && b is List<Object?> ? listEquals(a, b) : a == b;

  Future<void> _save(Map<String, String> values) async {
    late final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error) {
      throw WorkFolderSaveException(partiallySaved: false, cause: error);
    }
    final before = {for (final key in values.keys) key: prefs.get(key)};
    final durable = Map<String, Object?>.from(before);
    final attempted = <String>[];
    try {
      for (final entry in values.entries) {
        if (_sameValue(before[entry.key], entry.value)) continue;
        attempted.add(entry.key);
        await _write(prefs, entry.key, entry.value);
        durable[entry.key] = entry.value;
      }
    } catch (error) {
      for (final key in attempted.reversed) {
        try {
          await _write(prefs, key, before[key]);
          durable[key] = before[key];
        } catch (_) {
          // Keep the last acknowledged durable value if rollback also fails.
        }
      }
      for (final key in attempted) {
        if (_sameValue(prefs.get(key), durable[key])) continue;
        try {
          // SharedPreferences changes its cache before awaiting the store.
          // Restore that cache to the last acknowledged persisted value too.
          await _write(prefs, key, durable[key]);
        } catch (_) {
          // The cache is updated before this rejected persistence attempt.
        }
      }
      final partial = values.keys.any(
        (key) => !_sameValue(before[key], durable[key]),
      );
      if (partial) {
        if (durable.containsKey(_foldersPrefsKey)) {
          final raw = durable[_foldersPrefsKey];
          _folders
            ..clear()
            ..addAll(
              raw is String
                  ? (jsonDecode(raw) as List<dynamic>).map(
                      (value) =>
                          ProjectFolder.fromJson(value as Map<String, dynamic>),
                    )
                  : <ProjectFolder>[],
            );
        }
        if (durable.containsKey(_fileFolderPrefsKey)) {
          final raw = durable[_fileFolderPrefsKey];
          _fileFolder
            ..clear()
            ..addAll(
              raw is String
                  ? (jsonDecode(raw) as Map<String, dynamic>).map(
                      (key, value) => MapEntry(key, value as String),
                    )
                  : <String, String>{},
            );
        }
        _notify();
      }
      throw WorkFolderSaveException(partiallySaved: partial, cause: error);
    }
  }

  Future<ProjectFolder> createFolder(String name) => _enqueue(() async {
    final folder = ProjectFolder(
      id: 'work_folder_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    final next = [..._folders, folder];
    await _save({
      _foldersPrefsKey: jsonEncode(next.map((f) => f.toJson()).toList()),
    });
    _folders.add(folder);
    _notify();
    return folder;
  });

  Future<void> renameFolder(String folderId, String name) => _enqueue(() async {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx < 0 || _folders[idx].name == name) return;
    final next = [..._folders];
    next[idx] = next[idx].copyWith(name: name);
    await _save({
      _foldersPrefsKey: jsonEncode(next.map((f) => f.toJson()).toList()),
    });
    _folders[idx] = next[idx];
    _notify();
  });

  /// フォルダ削除時、直下のファイルはルートへ戻す。
  Future<void> deleteFolder(String folderId) => _enqueue(() async {
    if (!_folders.any((f) => f.id == folderId)) return;
    final folders = _folders.where((f) => f.id != folderId).toList();
    final files = Map<String, String>.from(_fileFolder)
      ..removeWhere((_, value) => value == folderId);
    await _save({
      // Remove associations first so partial persistence cannot hide files in
      // a folder that has already been deleted from the saved folder list.
      if (!mapEquals(files, _fileFolder))
        _fileFolderPrefsKey: jsonEncode(files),
      _foldersPrefsKey: jsonEncode(folders.map((f) => f.toJson()).toList()),
    });
    _folders
      ..clear()
      ..addAll(folders);
    _fileFolder
      ..clear()
      ..addAll(files);
    _notify();
  });

  Future<void> moveFileToFolder(String fileName, String? folderId) =>
      _enqueue(() async {
        if (_fileFolder[fileName] == folderId) return;
        final next = Map<String, String>.from(_fileFolder);
        if (folderId == null) {
          next.remove(fileName);
        } else {
          next[fileName] = folderId;
        }
        await _save({_fileFolderPrefsKey: jsonEncode(next)});
        _fileFolder
          ..clear()
          ..addAll(next);
        _notify();
      });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
