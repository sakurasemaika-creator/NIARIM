import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset_tags.dart';
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isFavorite': isFavorite,
  };

  factory StampFolder.fromJson(Map<String, dynamic> j) => StampFolder(
    id: j['id'] as String,
    name: j['name'] as String,
    isFavorite: j['isFavorite'] as bool? ?? false,
  );
}

/// スタンプ管理サービス。SharedPreferencesへ永続化する
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
    const Stamp(id: 'Stamp0001', name: '三角形', tags: [AssetTagKeys.shape]),
    const Stamp(id: 'Stamp0002', name: '五角形', tags: [AssetTagKeys.shape]),
    const Stamp(id: 'Stamp0003', name: '六角形', tags: [AssetTagKeys.shape]),
    const Stamp(
      id: 'Stamp0004',
      name: '星',
      tags: [AssetTagKeys.decoration, AssetTagKeys.effect],
    ),
    const Stamp(id: 'Stamp0005', name: 'ハート', tags: [AssetTagKeys.decoration]),
    const Stamp(
      id: 'Stamp0006',
      name: '吹き出し',
      tags: [AssetTagKeys.symbol, AssetTagKeys.manga],
    ),
    const Stamp(id: 'Stamp0007', name: '矢印', tags: [AssetTagKeys.symbol]),
    // ── ここから下は定番図形の追加分。既製品の素材は使わず、
    // procedural_texture.dartの_shapePathForName()が数式から生成する。
    const Stamp(id: 'Stamp0008', name: '円', tags: [AssetTagKeys.shape]),
    const Stamp(id: 'Stamp0009', name: '四角形', tags: [AssetTagKeys.shape]),
    const Stamp(id: 'Stamp0010', name: '丸角四角', tags: [AssetTagKeys.shape]),
    const Stamp(id: 'Stamp0011', name: '菱形', tags: [AssetTagKeys.shape]),
    const Stamp(id: 'Stamp0012', name: '八角形', tags: [AssetTagKeys.shape]),
    const Stamp(id: 'Stamp0013', name: 'ドーナツ', tags: [AssetTagKeys.shape]),
    const Stamp(
      id: 'Stamp0014',
      name: '十字',
      tags: [AssetTagKeys.shape, AssetTagKeys.symbol],
    ),
    const Stamp(
      id: 'Stamp0015',
      name: '四芒星',
      tags: [AssetTagKeys.decoration, AssetTagKeys.effect],
    ),
    const Stamp(
      id: 'Stamp0016',
      name: '六芒星',
      tags: [AssetTagKeys.decoration, AssetTagKeys.effect],
    ),
    const Stamp(
      id: 'Stamp0017',
      name: '八芒星',
      tags: [AssetTagKeys.decoration, AssetTagKeys.effect],
    ),
    const Stamp(
      id: 'Stamp0018',
      name: 'キラキラ',
      tags: [AssetTagKeys.decoration, AssetTagKeys.effect],
    ),
    const Stamp(
      id: 'Stamp0019',
      name: '三日月',
      tags: [AssetTagKeys.background, AssetTagKeys.decoration],
    ),
    const Stamp(
      id: 'Stamp0020',
      name: '雲',
      tags: [AssetTagKeys.background, AssetTagKeys.decoration],
    ),
    const Stamp(
      id: 'Stamp0021',
      name: '稲妻',
      tags: [AssetTagKeys.effect, AssetTagKeys.decoration],
    ),
    const Stamp(id: 'Stamp0022', name: '花', tags: [AssetTagKeys.decoration]),
    const Stamp(id: 'Stamp0023', name: 'チェックマーク', tags: [AssetTagKeys.symbol]),
    const Stamp(id: 'Stamp0024', name: '両矢印', tags: [AssetTagKeys.symbol]),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    _stamps.clear();
    if (raw == null) {
      _stamps.addAll(_defaultStamps());
      await _persist();
    } else {
      _stamps.addAll(
        raw.map((s) => Stamp.fromJson(jsonDecode(s) as Map<String, dynamic>)),
      );
      // 既存ユーザーにも、後から追加した組み込みスタンプを反映する
      // （同じIDが既にあれば追加しない）。BrushService・ToneServiceは
      // 以前から同じマージをしていたが、StampServiceだけ抜けており、
      // プリセットを増やしても新規インストール時にしか出てこなかった。
      final existingIds = _stamps.map((e) => e.id).toSet();
      final missing = _defaultStamps().where(
        (e) => !existingIds.contains(e.id),
      );
      var changed = false;
      if (missing.isNotEmpty) {
        _stamps.addAll(missing);
        changed = true;
      }
      // 既定タグを日本語リテラルで保存していた版からの移行。
      for (int i = 0; i < _stamps.length; i++) {
        final migrated = migrateLegacyTags(_stamps[i].tags);
        if (!identical(migrated, _stamps[i].tags)) {
          _stamps[i] = _stamps[i].copyWith(tags: migrated);
          changed = true;
        }
      }
      // 組み込み素材へ後から既定タグを付けたので、保存済みデータにも
      // 反映する。**利用者が自分で付けたタグは絶対に上書きしない**ため、
      // タグが1件も無いものだけを対象にする。
      final defaultTags = {
        for (final e in _defaultStamps())
          if (e.tags.isNotEmpty) e.id: e.tags,
      };
      for (int i = 0; i < _stamps.length; i++) {
        final tags = defaultTags[_stamps[i].id];
        if (tags != null && _stamps[i].tags.isEmpty) {
          _stamps[i] = _stamps[i].copyWith(tags: tags);
          changed = true;
        }
      }
      if (changed) await _persist();
    }
    final foldersRaw = prefs.getStringList(_foldersKey);
    _folders.clear();
    if (foldersRaw != null) {
      _folders.addAll(
        foldersRaw.map(
          (s) => StampFolder.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
    }
    _currentStamp = _stamps.firstOrNull;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _stamps.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _foldersKey,
      _folders.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  void selectStamp(String id) {
    _currentStamp = _stamps.firstWhere((s) => s.id == id);
    notifyListeners();
  }

  /// スタンプへ分類用タグを設定する（既存のタグ列を置き換える）。
  ///
  /// お気に入りと同様、**組み込みスタンプにも付けられる**。編集・削除は
  /// できなくても「どう分類したいか」は利用者の都合であり、そこを縛ると
  /// タグ機能がほとんど使えなくなるため（`updateXxx`のような
  /// `isBuiltIn`ガードは意図的に置いていない）。
  void setTags(String id, List<String> tags) {
    final idx = _stamps.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _stamps[idx] = _stamps[idx].copyWith(tags: normalizeTags(tags));
    notifyListeners();
    _persist();
  }

  /// 登録されている全タグを、使われている件数の多い順（同数なら名前順）で
  /// 返す。タグ検索の候補チップに使う。表記ゆれで別タグ扱いにならないよう、
  /// 大文字小文字を無視して数え、代表表記は最初に見つかったものを使う。
  List<String> allTags() {
    final count = <String, int>{};
    final display = <String, String>{};
    for (final e in _stamps) {
      for (final tag in e.tags) {
        final key = tag.toLowerCase();
        count[key] = (count[key] ?? 0) + 1;
        display.putIfAbsent(key, () => tag);
      }
    }
    final keys = count.keys.toList()
      ..sort((a, b) {
        final c = count[b]!.compareTo(count[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final k in keys) display[k]!];
  }

  void toggleFavorite(String id) {
    final idx = _stamps.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      _stamps[idx] = _stamps[idx].copyWith(
        isFavorite: !_stamps[idx].isFavorite,
      );
      notifyListeners();
      _persist();
    }
  }

  // プリインストールされている初期実装スタンプ（_defaultStamps()の7件）は
  // 編集・削除の対象外とする（複製したものは別IDになるため、複製後の
  // 編集・削除は可能）。
  static final Set<String> _builtInIds = _defaultStamps()
      .map((s) => s.id)
      .toSet();

  bool isBuiltIn(String id) => _builtInIds.contains(id);

  void addStamp(Stamp stamp) {
    _stamps.add(stamp);
    notifyListeners();
    _persist();
  }

  /// [id]のスタンプを削除する。プリインストール、またはお気に入り登録中の
  /// 場合は削除せずfalseを返す（呼び出し元でその旨のポップアップを表示する）。
  bool deleteStamp(String id) {
    if (isBuiltIn(id)) return false;
    final idx = _stamps.indexWhere((s) => s.id == id);
    if (idx < 0) return false;
    if (_stamps[idx].isFavorite) return false;
    _stamps.removeAt(idx);
    notifyListeners();
    _persist();
    return true;
  }

  void updateStamp(Stamp stamp) {
    if (isBuiltIn(stamp.id)) return;
    final idx = _stamps.indexWhere((s) => s.id == stamp.id);
    if (idx >= 0) {
      _stamps[idx] = stamp;
      notifyListeners();
      _persist();
    }
  }

  /// スタンプ一覧の表示順をドラッグで並べ替える（ブラシと同じ操作方法）。
  void reorderStamp(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final stamp = _stamps.removeAt(oldIndex);
    _stamps.insert(newIndex, stamp);
    notifyListeners();
    _persist();
  }

  /// [id]のスタンプを複製する（名前の末尾に「のコピー」を付けて追加）。
  /// プリインストールのスタンプも複製自体は可能（複製後の新しいIDは
  /// プリインストール扱いにならない）。
  void duplicateStamp(String id) {
    final stamp = _stamps.firstWhere((s) => s.id == id);
    final newId = 'Stamp${DateTime.now().millisecondsSinceEpoch}';
    _stamps.add(
      stamp.copyWith(id: newId, name: '${stamp.name} (コピー)', isFavorite: false),
    );
    notifyListeners();
    _persist();
  }

  // ─── フォルダ管理 ─────────────────────────────────────────

  Future<StampFolder> createFolder(String name) async {
    final folder = StampFolder(
      id: 'StampFolder${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
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
    _folders[idx] = _folders[idx].copyWith(
      isFavorite: !_folders[idx].isFavorite,
    );
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

  // ─── 自作スタンプ（画像からの新規作成） ─────────────────────────

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

  // ─── 読み込み・書き出し（個別ファイル単位） ───────────────────

  static const _bundleDataFile = 'data.json';

  Future<File> exportStamp(String id) async {
    final stamp = _stamps.firstWhere((s) => s.id == id);
    final base = await getApplicationDocumentsDirectory();
    final safeName = stamp.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${base.path}/$safeName.niastamp';
    final encoder = ZipFileEncoder();
    encoder.create(filePath);
    encoder.addArchiveFile(
      ArchiveFile(_bundleDataFile, 0, utf8.encode(jsonEncode(stamp.toJson()))),
    );
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
    final json = jsonDecode(
      utf8.decode(dataFile.content as List<int>),
    ) as Map<String, dynamic>;
    final imported = Stamp.fromJson(json);
    final id = 'Stamp${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = archive.files
        .where((f) => f.name.startsWith('image.'))
        .firstOrNull;
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
      opacity: imported.opacity,
      pixelMode: imported.pixelMode,
    );
    addStamp(stamp);
    return stamp;
  }
}
