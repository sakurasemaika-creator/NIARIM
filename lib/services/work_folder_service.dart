import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'project_service.dart' show ProjectFolder;

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

  List<ProjectFolder> get folders => List.unmodifiable(_folders);

  String? folderIdOf(String fileName) => _fileFolder[fileName];

  static const _foldersPrefsKey = 'work_folders';
  static const _fileFolderPrefsKey = 'work_file_folder_map';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawFolders = prefs.getString(_foldersPrefsKey);
      if (rawFolders != null) {
        final list = jsonDecode(rawFolders) as List<dynamic>;
        _folders
          ..clear()
          ..addAll(
            list.map((e) => ProjectFolder.fromJson(e as Map<String, dynamic>)),
          );
      }
      final rawMap = prefs.getString(_fileFolderPrefsKey);
      if (rawMap != null) {
        final map = jsonDecode(rawMap) as Map<String, dynamic>;
        _fileFolder
          ..clear()
          ..addAll(map.map((k, v) => MapEntry(k, v as String)));
      }
    } catch (_) {
      // 読み込み失敗時は空状態として続行
    }
    notifyListeners();
  }

  Future<void> _persistFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _foldersPrefsKey,
        jsonEncode(_folders.map((f) => f.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _persistFileFolderMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fileFolderPrefsKey, jsonEncode(_fileFolder));
    } catch (_) {}
  }

  Future<ProjectFolder> createFolder(String name) async {
    final folder = ProjectFolder(
      id: 'work_folder_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    _folders.add(folder);
    await _persistFolders();
    notifyListeners();
    return folder;
  }

  Future<void> renameFolder(String folderId, String name) async {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(name: name);
    await _persistFolders();
    notifyListeners();
  }

  /// フォルダ削除時、直下のファイルはルートへ戻す。
  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((f) => f.id == folderId);
    _fileFolder.removeWhere((_, v) => v == folderId);
    await _persistFolders();
    await _persistFileFolderMap();
    notifyListeners();
  }

  Future<void> moveFileToFolder(String fileName, String? folderId) async {
    if (folderId == null) {
      _fileFolder.remove(fileName);
    } else {
      _fileFolder[fileName] = folderId;
    }
    await _persistFileFolderMap();
    notifyListeners();
  }
}
