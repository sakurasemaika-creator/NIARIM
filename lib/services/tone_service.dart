import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tone.dart';

class ToneFolder {
  final String id;
  final String name;
  final bool isFavorite;
  ToneFolder({required this.id, required this.name, this.isFavorite = false});

  ToneFolder copyWith({String? name, bool? isFavorite}) => ToneFolder(
        id: id,
        name: name ?? this.name,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isFavorite': isFavorite};

  factory ToneFolder.fromJson(Map<String, dynamic> j) => ToneFolder(
        id: j['id'] as String,
        name: j['name'] as String,
        isFavorite: j['isFavorite'] as bool? ?? false,
      );
}

/// トーン管理サービス（仕様書04・17・21・25）。SharedPreferencesへ永続化する
/// （端末単位。プロジェクトファイルには含めない）。従来はインメモリのみで、
/// お気に入り・追加・削除・編集のすべてがアプリ再起動のたびに失われていた
/// （Task#83で修正）。自作トーン・フォルダ管理・読み込み/書き出しは
/// Task#84で追加した。テクスチャ画像はアプリ全体の`Tones/`フォルダへ
/// コピーして保存する。
class ToneService extends ChangeNotifier {
  static const _prefsKey = 'tones';
  static const _foldersKey = 'tone_folders';

  final List<Tone> _tones = [];
  final List<ToneFolder> _folders = [];
  Tone? _currentTone;
  // バケツ塗りと投げ縄塗りはそれぞれ独立して最後に使用したトーンを保持
  Tone? _lastBucketTone;
  Tone? _lastLassoTone;
  // 投げ縄塗り：ベタ塗り／トーンの選択状態（仕様書25）
  bool _lassoUseTone = false;
  // バケツ塗り：ベタ塗り／トーンの選択状態（仕様書04・17）
  bool _bucketUseTone = false;

  List<Tone> get tones => List.unmodifiable(_tones);
  List<ToneFolder> get folders => List.unmodifiable(_folders);
  Tone? get currentTone => _currentTone;
  Tone? get lastBucketTone => _lastBucketTone;
  Tone? get lastLassoTone => _lastLassoTone;
  bool get lassoUseTone => _lassoUseTone;
  bool get bucketUseTone => _bucketUseTone;

  void setLassoUseTone(bool value) {
    _lassoUseTone = value;
    notifyListeners();
  }

  void setBucketUseTone(bool value) {
    _bucketUseTone = value;
    notifyListeners();
  }

  static List<Tone> _defaultTones() => [
        const Tone(id: 'Tone0001', name: '網点 10%'),
        const Tone(id: 'Tone0002', name: '網点 30%'),
        const Tone(id: 'Tone0003', name: '網点 50%'),
        const Tone(id: 'Tone0004', name: '網点 70%'),
        const Tone(id: 'Tone0005', name: 'ライン 細'),
        const Tone(id: 'Tone0006', name: 'ライン 太'),
        // ピクセルモード用トーン（1ピクセルごとに市松模様／格子柄／散らし
        // 配置になっているトーン）。procedural_texture.dartの
        // generateBuiltInToneTextureが名前に「市松」「格子」「散らし」を
        // 含むかで判定する。「散らし」は格子（縦横の線がつながって網目状）
        // とは逆に、1ピクセルずつ上下左右を1px空けて独立させたもの。
        // 「ドット」という表記は丸い水玉模様と誤認されるため使わず、
        // 四角い1ピクセル単位のパターンには「ピクセル」を使う
        // （brush.dartのpixelMode改称と同じ理由・同じ命名規則）。
        const Tone(id: 'Tone0007', name: 'ピクセル市松（1px）'),
        const Tone(id: 'Tone0008', name: 'ピクセル格子（1px）'),
        const Tone(id: 'Tone0009', name: 'ピクセル散らし（1px）'),
      ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _tones.clear();
    if (raw == null) {
      _tones.addAll(_defaultTones());
      await _persist();
    } else {
      _tones.addAll(raw.map((s) => Tone.fromJson(jsonDecode(s) as Map<String, dynamic>)));
      // 既存ユーザーにも新規追加した初期トーン（ピクセルモード2種）を
      // 反映する（既に同名IDのトーンが存在する場合は追加しない）。
      final existingIds = _tones.map((t) => t.id).toSet();
      final missing = _defaultTones().where((t) => !existingIds.contains(t.id));
      var changed = false;
      if (missing.isNotEmpty) {
        _tones.addAll(missing);
        changed = true;
      }
      // 「ドット○○（1px）」は「ピクセル○○（1px）」へ改称した（「ドット」が
      // 丸い水玉模様と誤認されるため）。旧名のまま残っている既存ユーザーの
      // トーンをIDで特定して更新する。
      final defaults = {for (final t in _defaultTones()) t.id: t};
      for (int i = 0; i < _tones.length; i++) {
        final fresh = defaults[_tones[i].id];
        if (fresh != null && _tones[i].name != fresh.name && _tones[i].name.contains('ドット')) {
          _tones[i] = _tones[i].copyWith(name: fresh.name);
          changed = true;
        }
      }
      if (changed) await _persist();
    }
    final foldersRaw = prefs.getStringList(_foldersKey);
    _folders.clear();
    if (foldersRaw != null) {
      _folders.addAll(
          foldersRaw.map((s) => ToneFolder.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    }
    _currentTone = _tones.firstOrNull;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _tones.map((t) => jsonEncode(t.toJson())).toList());
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, _folders.map((f) => jsonEncode(f.toJson())).toList());
  }

  void selectTone(String id) {
    _currentTone = _tones.firstWhere((t) => t.id == id);
    notifyListeners();
  }

  void setLastBucketTone(Tone tone) {
    _lastBucketTone = tone;
    notifyListeners();
  }

  void setLastLassoTone(Tone tone) {
    _lastLassoTone = tone;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = _tones.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _tones[idx] = _tones[idx].copyWith(isFavorite: !_tones[idx].isFavorite);
      notifyListeners();
      _persist();
    }
  }

  // プリインストールされている初期実装トーン（_defaultTones()の9件）は
  // 編集・削除の対象外とする（複製したものは別IDになるため、複製後の
  // 編集・削除は可能）。
  static final Set<String> _builtInIds = _defaultTones().map((t) => t.id).toSet();

  bool isBuiltIn(String id) => _builtInIds.contains(id);

  void addTone(Tone tone) {
    _tones.add(tone);
    notifyListeners();
    _persist();
  }

  /// [id]のトーンを削除する。プリインストール、またはお気に入り登録中の
  /// 場合は削除せずfalseを返す（呼び出し元でその旨のポップアップを表示する）。
  bool deleteTone(String id) {
    if (isBuiltIn(id)) return false;
    final idx = _tones.indexWhere((t) => t.id == id);
    if (idx < 0) return false;
    if (_tones[idx].isFavorite) return false;
    _tones.removeAt(idx);
    notifyListeners();
    _persist();
    return true;
  }

  void updateTone(Tone tone) {
    if (isBuiltIn(tone.id)) return;
    final idx = _tones.indexWhere((t) => t.id == tone.id);
    if (idx >= 0) {
      _tones[idx] = tone;
      notifyListeners();
      _persist();
    }
  }

  /// トーン一覧の表示順をドラッグで並べ替える（ブラシと同じ操作方法）。
  void reorderTone(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final tone = _tones.removeAt(oldIndex);
    _tones.insert(newIndex, tone);
    notifyListeners();
    _persist();
  }

  /// [id]のトーンを複製する（名前の末尾に「のコピー」を付けて追加）。
  /// プリインストールのトーンも複製自体は可能（複製後の新しいIDは
  /// プリインストール扱いにならない）。
  void duplicateTone(String id) {
    final tone = _tones.firstWhere((t) => t.id == id);
    final newId = 'Tone${DateTime.now().millisecondsSinceEpoch}';
    _tones.add(tone.copyWith(id: newId, name: '${tone.name} (コピー)', isFavorite: false));
    notifyListeners();
    _persist();
  }

  // ─── フォルダ管理（仕様書17） ─────────────────────────────────────────

  Future<ToneFolder> createFolder(String name) async {
    final folder = ToneFolder(id: 'ToneFolder${DateTime.now().millisecondsSinceEpoch}', name: name);
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
    for (int i = 0; i < _tones.length; i++) {
      if (_tones[i].folderId == id) {
        _tones[i] = _tones[i].copyWith(folderId: null);
      }
    }
    notifyListeners();
    _persistFolders();
    _persist();
  }

  void moveToFolder(String toneId, String? folderId) {
    final idx = _tones.indexWhere((t) => t.id == toneId);
    if (idx < 0) return;
    _tones[idx] = _tones[idx].copyWith(folderId: folderId);
    notifyListeners();
    _persist();
  }

  // ─── 自作トーン（画像からの新規作成、仕様書17） ──────────────────────────

  Future<Directory> _tonesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/Tones');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Tone> createToneFromImage(String sourcePath, {String? name}) async {
    final id = 'Tone${DateTime.now().millisecondsSinceEpoch}';
    final ext = sourcePath.split('.').last;
    final dir = await _tonesDir();
    final destPath = '${dir.path}/$id.$ext';
    await File(sourcePath).copy(destPath);
    final tone = Tone(
      id: id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : '自作トーン',
      texturePath: destPath,
    );
    addTone(tone);
    return tone;
  }

  // ─── 読み込み・書き出し（仕様書17：個別ファイル単位） ───────────────────

  static const _bundleDataFile = 'data.json';

  Future<File> exportTone(String id) async {
    final tone = _tones.firstWhere((t) => t.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = tone.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${base.path}/$safeName.niatone';
    final encoder = ZipFileEncoder();
    encoder.create(filePath);
    encoder.addArchiveFile(
        ArchiveFile(_bundleDataFile, 0, utf8.encode(jsonEncode(tone.toJson()))));
    final texturePath = tone.texturePath;
    if (texturePath != null && File(texturePath).existsSync()) {
      final bytes = await File(texturePath).readAsBytes();
      final ext = texturePath.split('.').last;
      encoder.addArchiveFile(ArchiveFile('image.$ext', bytes.length, bytes));
    }
    encoder.close();
    return File(filePath);
  }

  Future<Tone> importToneFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dataFile = archive.findFile(_bundleDataFile);
    if (dataFile == null) throw const FormatException('data.json not found');
    final json = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
    final imported = Tone.fromJson(json);
    final id = 'Tone${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = archive.files.where((f) => f.name.startsWith('image.')).firstOrNull;
    String? newTexturePath;
    if (imageFile != null) {
      final ext = imageFile.name.split('.').last;
      final dir = await _tonesDir();
      newTexturePath = '${dir.path}/$id.$ext';
      await File(newTexturePath).writeAsBytes(imageFile.content as List<int>);
    }
    // texturePathは元端末のパスをそのまま引き継げないため、copyWith（??で
    // nullを無視する実装）を使わず、常にnewTexturePath（nullなら未設定）で
    // 明示的に上書きする。
    final tone = Tone(
      id: id,
      name: imported.name,
      texturePath: newTexturePath,
      isFavorite: imported.isFavorite,
    );
    addTone(tone);
    return tone;
  }
}
