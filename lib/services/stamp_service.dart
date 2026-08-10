import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stamp.dart';

class StampFolder {
  final String id;
  final String name;
  final bool isFavorite;
  StampFolder({required this.id, required this.name, this.isFavorite = false});

  StampFolder copyWith({String? name, bool? isFavorite}) => StampFolder(
        id: id,
        name: name ?? this.name,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isFavorite': isFavorite};

  factory StampFolder.fromJson(Map<String, dynamic> j) => StampFolder(
        id: j['id'] as String,
        name: j['name'] as String,
        isFavorite: j['isFavorite'] as bool? ?? false,
      );
}

/// スタンプ管理サービス（仕様書17・21）。SharedPreferencesへ永続化する
/// （端末単位。プロジェクトファイルには含めない）。従来はインメモリのみで、
/// お気に入り・追加・削除・編集のすべてがアプリ再起動のたびに失われていた
/// （Task#83で修正）。自作スタンプ・フォルダ管理・読み込み/書き出しは
/// Task#84で追加した。スタンプ画像はアプリ全体の`Stamps/`フォルダへ
/// コピーして保存する。
class StampService extends ChangeNotifier {
  static const _prefsKey = 'stamps';
  static const _foldersKey = 'stamp_folders';

  final List<Stamp> _stamps = [];
  final List<StampFolder> _folders = [];
  Stamp? _currentStamp;

  List<Stamp> get stamps => List.unmodifiable(_stamps);
  List<StampFolder> get folders => List.unmodifiable(_folders);
  Stamp? get currentStamp => _currentStamp;

  static List<Stamp> _defaultStamps() => [
        const Stamp(id: 'Stamp0001', name: '三角形'),
        const Stamp(id: 'Stamp0002', name: '五角形'),
        const Stamp(id: 'Stamp0003', name: '六角形'),
        const Stamp(id: 'Stamp0004', name: '星'),
        const Stamp(id: 'Stamp0005', name: 'ハート'),
        const Stamp(id: 'Stamp0006', name: '吹き出し'),
        const Stamp(id: 'Stamp0007', name: '矢印'),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _stamps.clear();
    if (raw == null) {
      _stamps.addAll(_defaultStamps());
      await _persist();
    } else {
      _stamps.addAll(raw.map((s) => Stamp.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    final foldersRaw = prefs.getStringList(_foldersKey);
    _folders.clear();
    if (foldersRaw != null) {
      _folders.addAll(
          foldersRaw.map((s) => StampFolder.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    _currentStamp = _stamps.firstOrNull;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _stamps.map((s) => jsonEncode(s.toJson())).toList());
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, _folders.map((f) => jsonEncode(f.toJson())).toList());
  }

  void selectStamp(String id) {
    _currentStamp = _stamps.firstWhere((s) => s.id == id);
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = _stamps.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      _stamps[idx] = _stamps[idx].copyWith(isFavorite: !_stamps[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  void addStamp(Stamp stamp) {
    _stamps.add(stamp);
    notifyListeners();
    _persist();
  }

  void deleteStamp(String id) {
    _stamps.removeWhere((s) => s.id == id);
    notifyListeners();
    _persist();
  }

  void updateStamp(Stamp stamp) {
    final idx = _stamps.indexWhere((s) => s.id == stamp.id);
    if (idx >= 0) {
      _stamps[idx] = stamp;
      notifyListeners();
      _persist();
    }
  }

  // ─── フォルダ管理（仕様書17） ─────────────────────────────────────────

  Future<StampFolder> createFolder(String name) async {
    final folder =
        StampFolder(id: 'StampFolder${DateTime.now().millisecondsSinceEpoch}', name: name);
    _folders.add(folder);
    notifyListeners();
    await _persistFolders();
    return folder;
  }

  void renameFolder(String id, String name) {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(name: name);
    notifyListeners();
    _persistFolders();
  }

  void toggleFolderFavorite(String id) {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(isFavorite: !_folders[idx].isFavorite);
    notifyListeners();
    _persistFolders();
  }

  void reorderFolder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final folder = _folders.removeAt(oldIndex);
    _folders.insert(newIndex, folder);
    notifyListeners();
    _persistFolders();
  }

  void deleteFolder(String id) {
    _folders.removeWhere((f) => f.id == id);
    for (int i = 0; i < _stamps.length; i++) {
      if (_stamps[i].folderId == id) {
        _stamps[i] = _stamps[i].copyWith(folderId: null);
      }
    }
    notifyListeners();
    _persistFolders();
    _persist();
  }

  void moveToFolder(String stampId, String? folderId) {
    final idx = _stamps.indexWhere((s) => s.id == stampId);
    if (idx < 0) return;
    _stamps[idx] = _stamps[idx].copyWith(folderId: folderId);
    notifyListeners();
    _persist();
  }

  // ─── 自作スタンプ（画像からの新規作成、仕様書17） ─────────────────────────

  Future<Directory> _stampsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/Stamps');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Stamp> createStampFromImage(String sourcePath, {String? name}) async {
    final id = 'Stamp${DateTime.now().millisecondsSinceEpoch}';
    final ext = sourcePath.split('.').last;
    final dir = await _stampsDir();
    final destPath = '${dir.path}/$id.$ext';
    await File(sourcePath).copy(destPath);
    final stamp = Stamp(
      id: id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : '自作スタンプ',
      imagePath: destPath,
    );
    addStamp(stamp);
    return stamp;
  }

  // ─── 読み込み・書き出し（仕様書17：個別ファイル単位） ───────────────────

  static const _bundleDataFile = 'data.json';

  Future<File> exportStamp(String id) async {
    final stamp = _stamps.firstWhere((s) => s.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = stamp.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${base.path}/$safeName.niastamp';
    final encoder = ZipFileEncoder();
    encoder.create(filePath);
    encoder.addArchiveFile(
        ArchiveFile(_bundleDataFile, 0, utf8.encode(jsonEncode(stamp.toJson()))));
    final imagePath = stamp.imagePath;
    if (imagePath != null && File(imagePath).existsSync()) {
      final bytes = await File(imagePath).readAsBytes();
      final ext = imagePath.split('.').last;
      encoder.addArchiveFile(ArchiveFile('image.$ext', bytes.length, bytes));
    }
    encoder.close();
    return File(filePath);
  }

  Future<Stamp> importStampFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dataFile = archive.findFile(_bundleDataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final json = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
    final imported = Stamp.fromJson(json);
    final id = 'Stamp${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = archive.files.where((f) => f.name.startsWith('image.')).firstOrNull;
    String? newImagePath;
    if (imageFile != null) {
      final ext = imageFile.name.split('.').last;
      final dir = await _stampsDir();
      newImagePath = '${dir.path}/$id.$ext';
      await File(newImagePath).writeAsBytes(imageFile.content as List<int>);
    }
    // imagePathは元端末のパスをそのまま引き継げないため、copyWith（??で
    // nullを無視する実装）を使わず、常にnewImagePath（なければ未設定）で
    // 明示的に上書きする。
    final stamp = Stamp(
      id: id,
      name: imported.name,
      imagePath: newImagePath,
      isFavorite: imported.isFavorite,
      rotation: imported.rotation,
      density: imported.density,
      scatter: imported.scatter,
    );
    addStamp(stamp);
    return stamp;
  }
}
