import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/procedural_texture.dart';
import '../models/asset_tags.dart';
import '../models/stamp.dart';
import '../utils/built_in_preset_order.dart';
import '../utils/creative_image_source.dart';
import '../utils/duplicate_name.dart';
import '../utils/saved_list_reader.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/transfer_merge.dart';

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

  /// このサービスが持つ保存のキー。引き継ぎ（.niatra）の「端末保存データ」
  /// では扱わない（「素材」の項目が[mergeTransferred]で一覧と突き合わせて
  /// 取り込む。理由は[BrushService.savedPreferenceKeys]と同じ）。
  static const Set<String> savedPreferenceKeys = {_prefsKey, _foldersKey};

  /// フォルダの保存の中の、この版では読めなかった項目。一覧には出さないが、
  /// フォルダを保存し直すときに末尾へ残す（自作のフォルダを消さない）。
  final List<String> _unreadableFolderEntries = [];

  final List<Stamp> _stamps = [];
  final List<StampFolder> _folders = [];
  Stamp? _currentStamp;

  List<Stamp> get stamps => List.unmodifiable(_stamps);
  List<StampFolder> get folders => List.unmodifiable(_folders);
  Stamp? get currentStamp => _currentStamp;

  static const _presetOrder = [
    // Geometric shapes.
    'Stamp0001',
    'Stamp0009',
    'Stamp0010',
    'Stamp0011',
    'Stamp0002',
    'Stamp0003',
    'Stamp0012',
    'Stamp0008',
    'Stamp0013',
    // Comic and annotation symbols.
    'Stamp0006',
    'Stamp0007',
    'Stamp0024',
    'Stamp0023',
    // Decorative and lighting shapes.
    'Stamp0004',
    'Stamp0015',
    'Stamp0018',
    'Stamp0005',
    'Stamp0022',
    'Stamp0021',
    // Scenery.
    'Stamp0020',
    'Stamp0025',
    'Stamp0027',
    'Stamp0026',
    'Stamp0028',
  ];
  static const _retiredBuiltInIds = {
    'Stamp0014',
    'Stamp0016',
    'Stamp0017',
    'Stamp0019',
  };
  static const _groupedPresetsKey = 'stamp_grouped_presets_v1';

  static bool _usesRetiredBuiltIn(Stamp stamp) =>
      _retiredBuiltInIds.contains(stamp.id) ||
      _retiredBuiltInIds.any(
        (id) => stamp.imagePath == 'assets/stamps/$id.png',
      );

  static List<Stamp> _defaultStamps() {
    final definitions = {
      for (final stamp in _stampDefinitions) stamp.id: stamp,
    };
    return [for (final id in _presetOrder) definitions[id]!];
  }

  static final _stampDefinitions = [
    for (final stamp in _originalStamps)
      stamp.copyWith(imagePath: 'assets/stamps/${stamp.id}.png'),
    for (final (id, sourceId, name) in const [
      ('Stamp0027', 'Stamp0025', '葉っぱ（ベタ塗り）'),
      ('Stamp0028', 'Stamp0026', '草（ベタ塗り）'),
    ])
      _originalStamps
          .firstWhere((stamp) => stamp.id == sourceId)
          .copyWith(
            id: id,
            name: name,
            imagePath: 'assets/stamps/$sourceId.png',
            flatFill: true,
            opacity: 100,
          ),
  ];

  static const _originalStamps = <Stamp>[
    Stamp(id: 'Stamp0001', name: '三角形', tags: [AssetTagKeys.shape]),
    Stamp(id: 'Stamp0002', name: '五角形', tags: [AssetTagKeys.shape]),
    Stamp(id: 'Stamp0003', name: '六角形', tags: [AssetTagKeys.shape]),
    Stamp(
      id: 'Stamp0004',
      name: '星',
      tags: [AssetTagKeys.decoration, AssetTagKeys.effect],
    ),
    Stamp(id: 'Stamp0005', name: 'ハート', tags: [AssetTagKeys.decoration]),
    Stamp(
      id: 'Stamp0006',
      name: '吹き出し',
      tags: [AssetTagKeys.symbol, AssetTagKeys.manga],
    ),
    Stamp(id: 'Stamp0007', name: '矢印', tags: [AssetTagKeys.symbol]),
    // ── ここから下は定番図形の追加分。既製品の素材は使わず、
    // procedural_texture.dartの_shapePathForName()が数式から生成する。
    Stamp(id: 'Stamp0008', name: '円', tags: [AssetTagKeys.shape]),
    Stamp(id: 'Stamp0009', name: '四角形', tags: [AssetTagKeys.shape]),
    Stamp(id: 'Stamp0010', name: '丸角四角', tags: [AssetTagKeys.shape]),
    Stamp(id: 'Stamp0011', name: '菱形', tags: [AssetTagKeys.shape]),
    Stamp(id: 'Stamp0012', name: '八角形', tags: [AssetTagKeys.shape]),
    Stamp(id: 'Stamp0013', name: 'ドーナツ', tags: [AssetTagKeys.shape]),
    Stamp(
      id: 'Stamp0015',
      name: '四芒星',
      tags: [AssetTagKeys.decoration, AssetTagKeys.effect],
    ),
    Stamp(
      id: 'Stamp0018',
      name: 'キラキラ',
      tags: [AssetTagKeys.decoration, AssetTagKeys.effect],
    ),
    Stamp(
      id: 'Stamp0020',
      name: '雲',
      tags: [AssetTagKeys.background, AssetTagKeys.decoration],
    ),
    Stamp(
      id: 'Stamp0021',
      name: '稲妻',
      tags: [AssetTagKeys.effect, AssetTagKeys.decoration],
    ),
    Stamp(id: 'Stamp0022', name: '花', tags: [AssetTagKeys.decoration]),
    Stamp(id: 'Stamp0023', name: 'チェックマーク', tags: [AssetTagKeys.symbol]),
    Stamp(id: 'Stamp0024', name: '両矢印', tags: [AssetTagKeys.symbol]),
    // 背景をストローク1本で埋めるための連続スタンプ。単発の葉アイコンではなく、
    // 内部テクスチャ自体が複数の葉・色を持つ小さな植生クラスター。
    Stamp(
      id: 'Stamp0025',
      name: '葉っぱ',
      rotation: true,
      density: 2.3,
      scatter: 0.22,
      opacity: 94,
      tags: [
        AssetTagKeys.background,
        AssetTagKeys.texture,
        AssetTagKeys.decoration,
      ],
    ),
    Stamp(
      id: 'Stamp0026',
      name: '草',
      rotation: false,
      density: 2.8,
      scatter: 0.18,
      opacity: 96,
      tags: [AssetTagKeys.background, AssetTagKeys.texture],
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.readStringList(_prefsKey);
    // A missing marker belongs to an older install. Keep an unrecognized
    // stored value and avoid reordering that user's presets on startup.
    final grouped =
        prefs.readBool(_groupedPresetsKey) ??
        prefs.containsKey(_groupedPresetsKey);
    _stamps.clear();
    if (raw == null) {
      _stamps.addAll(_defaultStamps());
      // 読めない型の値が入っているときは、既定の内容で動かすだけで
      // 保存は書き換えない。
      if (!prefs.containsKey(_prefsKey)) {
        await _persist();
        if (!grouped) await prefs.setBool(_groupedPresetsKey, true);
      }
    } else {
      var intact = true;
      _stamps.addAll(
        readSavedJsonList(
          listKey: _prefsKey,
          raw,
          Stamp.fromJson,
          onSkipped: () => intact = false,
        ),
      );
      // 既存ユーザーにも、後から追加した組み込みスタンプを反映する
      // （同じIDが既にあれば追加しない）。BrushService・ToneServiceは
      // 以前から同じマージをしていたが、StampServiceだけ抜けており、
      // プリセットを増やしても新規インストール時にしか出てこなかった。
      final savedCount = _stamps.length;
      _stamps.removeWhere(_usesRetiredBuiltIn);
      final existingIds = _stamps.map((e) => e.id).toSet();
      final missing = _defaultStamps().where(
        (e) => !existingIds.contains(e.id),
      );
      var changed = _stamps.length != savedCount;
      if (missing.isNotEmpty) {
        for (final stamp in missing) {
          final source = switch (stamp.id) {
            'Stamp0027' => 'Stamp0025',
            'Stamp0028' => 'Stamp0026',
            _ => null,
          };
          final index = _stamps.indexWhere(
            (item) => item.id == source && item.folderId == null,
          );
          _stamps.insert(index < 0 ? _stamps.length : index + 1, stamp);
        }
        changed = true;
      }
      final stock = {for (final stamp in _defaultStamps()) stamp.id: stamp};
      for (var i = 0; i < _stamps.length; i++) {
        final saved = _stamps[i];
        final definition = stock[saved.id];
        if (definition != null) {
          final current = definition.copyWith(
            isFavorite: saved.isFavorite,
            folderId: saved.folderId,
            tags: saved.tags,
          );
          if (jsonEncode(current.toJson()) != jsonEncode(saved.toJson())) {
            _stamps[i] = current;
            changed = true;
          }
          continue;
        }
        final existing = saved.imagePath;
        final originalName = copySourceName(saved.name) ?? saved.name;
        final bundledPath = stock.values
            .where((item) => item.name == originalName)
            .firstOrNull
            ?.imagePath;
        final path = existing == null
            ? bundledPath ?? await _bakeLegacyImage(saved)
            : await migrateCreativeImage(existing);
        if (path != null && path != existing) {
          _stamps[i] = saved.copyWith(imagePath: path);
          changed = true;
        }
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
      // 読めない項目があった保存は、起動では書き換えない（後の版でなら
      // 読めるかもしれない自作の内容を、起動しただけで消さない。その一覧を
      // 次に変えたときに、読めた分だけで保存し直される）。
      if (!grouped) {
        if (groupUnfiledBuiltIns(
          _stamps,
          _presetOrder,
          idOf: (preset) => preset.id,
          folderOf: (preset) => preset.folderId,
        )) {
          changed = true;
        }
      }
      if (changed && intact) await _persist();
      if (intact && !grouped) {
        await prefs.setBool(_groupedPresetsKey, true);
      }
    }
    final foldersRaw = prefs.readStringList(_foldersKey);
    _folders.clear();
    _unreadableFolderEntries.clear();
    if (foldersRaw != null) {
      _folders.addAll(
        readSavedJsonList(
          foldersRaw,
          StampFolder.fromJson,
          unreadable: _unreadableFolderEntries,
        ),
      );
    }
    _currentStamp = _stamps.firstOrNull;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setSavedJsonList(
      _prefsKey,
      _stamps.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<void> _persistFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, [
      for (final folder in _folders) jsonEncode(folder.toJson()),
      ..._unreadableFolderEntries,
    ]);
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

  /// 引き継ぎ（.niatra）で受け取ったスタンプとフォルダを、この端末の一覧へ
  /// 合わせて保存する。この端末の内容は黙って失わない（決まりは
  /// [mergeTransferredItems]）：組み込みは足さず、中身はこの版のまま、
  /// お気に入り・タグ・フォルダだけを合わせる。自作は、同じIDで中身が違えば
  /// この端末の方を残し、受け取った方を「名前 (コピー)」として足す。
  /// フォルダは無いものだけ足し、行き先のフォルダが無い項目はフォルダなし。
  /// 画像を受け取れなかった項目は、同じIDの項目がこの端末で使っている画像が
  /// あればそれを使う。画像は置いた場所ではなく中身で比べる。同じ中身が既に
  /// あって足さなかった項目のお気に入り・タグ・フォルダは、その項目へ
  /// 合わせる。変えた一覧だけを保存する。
  Future<void> mergeTransferred(
    List<Stamp> incoming, {
    required TransferCopyNames copyNames,
    List<StampFolder> folders = const [],
  }) async {
    var foldersChanged = false;
    for (final folder in folders) {
      if (_folders.any((f) => f.id == folder.id)) continue;
      _folders.add(folder);
      foldersChanged = true;
    }
    final folderIds = {for (final f in _folders) f.id};
    final resolved = <Stamp>[
      for (final item in incoming)
        if (!_usesRetiredBuiltIn(item))
          Stamp.fromJson({
            ...item.toJson(),
            if (!folderIds.contains(item.folderId)) 'folderId': null,
            if (!_fileExists(item.imagePath))
              'imagePath': _workingLocalImage(item.id) ?? item.imagePath,
          }),
    ];
    // 画像は置いた場所ではなく中身で比べる。
    final images = await TransferImageDigests.read([
      for (final e in [..._stamps, ...resolved]) e.imagePath,
    ]);
    // 前の読み込みでもう1台の版を足した複製（名前を変えていても見つける）。
    final copies = await TransferCopyRecord.read(TransferCopyRecord.stamps);
    final listChanged = mergeTransferredItems(
      _stamps,
      resolved,
      TransferMergeRules<Stamp>(
        idOf: (e) => e.id,
        nameOf: (e) => e.name,
        contentOf: (e) => e.toJson()
          ..remove('id')
          ..remove('name')
          ..remove('isFavorite')
          ..remove('tags')
          ..remove('folderId')
          ..['imagePath'] = images.of(e.imagePath),
        organizationOf: (e) =>
            (favorite: e.isFavorite, tags: e.tags, folderId: e.folderId),
        withOrganization: (e, o) => Stamp.fromJson({
          ...e.toJson(),
          'isFavorite': o.favorite,
          'tags': o.tags,
          'folderId': o.folderId,
        }),
        asCopy: (e, id, name) =>
            Stamp.fromJson({...e.toJson(), 'id': id, 'name': name}),
        newId: (attempt) =>
            'Stamp${DateTime.now().microsecondsSinceEpoch}_$attempt',
        copyNames: copyNames,
        shippedOf: (id) =>
            _defaultStamps().where((e) => e.id == id).firstOrNull,
        organizationOnly: isBuiltIn,
      ),
      copies: copies,
    );
    await copies.save();
    if (!listChanged && !foldersChanged) return;
    final current = _currentStamp;
    _currentStamp =
        _stamps.where((e) => e.id == current?.id).firstOrNull ??
        _stamps.firstOrNull;
    notifyListeners();
    if (foldersChanged) await _persistFolders();
    if (listChanged) await _persist();
  }

  /// 同じIDの項目がこの端末で使っている画像（ファイルがあるときだけ）。
  String? _workingLocalImage(String id) {
    final path = _stamps.where((e) => e.id == id).firstOrNull?.imagePath;
    return _fileExists(path) ? path : null;
  }

  static bool _fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      return path.startsWith('assets/') || File(path).existsSync();
    } on UnsupportedError {
      return false;
    } on FileSystemException {
      return false;
    }
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

  /// [id]のスタンプを複製して一覧の最後に足す。名前は[name]（画面が
  /// 「名前 (コピー 2)」のように言語と番号を付けて渡す）。省略すると日本語の
  /// 形で、複製の複製も元の名前に番号を付ける（[fallbackCopyName]）。
  /// プリインストールのスタンプも複製自体は可能（複製後の新しいIDは
  /// プリインストール扱いにならない）。
  void duplicateStamp(String id, {String? name}) {
    final stamp = _stamps.firstWhere((s) => s.id == id);
    final newId = 'Stamp${DateTime.now().millisecondsSinceEpoch}';
    _stamps.add(
      stamp.copyWith(
        id: newId,
        name:
            name ??
            fallbackCopyName(stamp.name, [for (final s in _stamps) s.name]),
        isFavorite: false,
      ),
    );
    notifyListeners();
    _persist();
  }

  // ─── フォルダ管理 ─────────────────────────────────────────

  Future<StampFolder> createFolder(String name) async {
    final folder = StampFolder(
      id: 'StampFolder${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    _folders.add(folder);
    notifyListeners();
    await _persistFolders();
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    final idx = _folders.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(name: name);
    notifyListeners();
    await _persistFolders();
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

  Future<void> deleteFolder(String id) async {
    _folders.removeWhere((f) => f.id == id);
    for (int i = 0; i < _stamps.length; i++) {
      if (_stamps[i].folderId == id) {
        _stamps[i] = _stamps[i].copyWith(clearFolder: true);
      }
    }
    final current = _currentStamp;
    if (current != null && current.folderId == id) {
      _currentStamp = current.copyWith(clearFolder: true);
    }
    notifyListeners();
    // Persist the members first. If interrupted, an existing folder can
    // still be opened and deleted again.
    await _persist();
    await _persistFolders();
  }

  void moveToFolder(String stampId, String? folderId) {
    final idx = _stamps.indexWhere((s) => s.id == stampId);
    if (idx < 0) return;
    _stamps[idx] = _stamps[idx].copyWith(
      folderId: folderId,
      clearFolder: folderId == null,
    );
    final current = _currentStamp;
    if (current != null && current.id == stampId) {
      _currentStamp = current.copyWith(
        folderId: folderId,
        clearFolder: folderId == null,
      );
    }
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

  Future<String?> _bakeLegacyImage(Stamp asset) async {
    try {
      final directory = await _stampsDir();
      const size = 128;
      final rgba = await generateBuiltInStampTexture(
        asset.copyWith(pixelMode: false, opacity: 100),
        size: size,
      );
      // The stamp renderer returns premultiplied color; PNG uses straight RGB.
      for (var i = 0; i < rgba.length; i += 4) {
        final alpha = rgba[i + 3];
        if (alpha == 0 || alpha == 255) continue;
        for (var channel = 0; channel < 3; channel++) {
          rgba[i + channel] = (rgba[i + channel] * 255 / alpha).round().clamp(
            0,
            255,
          );
        }
      }
      final png = creativePngFromRgba(rgba, size, size);
      final digest = sha256.convert(png);
      final file = File('${directory.path}/legacy_$digest.png');
      if (!await file.exists()) await file.writeAsBytes(png, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<Stamp> createStampFromImage(String sourcePath, {String? name}) async {
    final id = 'Stamp${DateTime.now().millisecondsSinceEpoch}';
    final dir = await _stampsDir();
    final destPath = '${dir.path}/$id.png';
    await copyCreativeImageAsPng(sourcePath, destPath);
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
    final bytes = imagePath == null
        ? null
        : await readCreativeImageSource(imagePath);
    if (imagePath != null && bytes != null) {
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
    final json =
        jsonDecode(utf8.decode(dataFile.content as List<int>))
            as Map<String, dynamic>;
    final imported = Stamp.fromJson(json);
    if (_usesRetiredBuiltIn(imported)) {
      throw const FormatException('This bundled stamp has been retired.');
    }
    final id = 'Stamp${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = archive.files
        .where((f) => f.name.startsWith('image.'))
        .firstOrNull;
    String? newImagePath;
    if (imageFile != null) {
      final ext = imageFile.name.split('.').last;
      final dir = await _stampsDir();
      newImagePath = await restoreCreativeImage(
        imageFile.content as List<int>,
        '${dir.path}/$id',
        ext,
      );
    }
    newImagePath ??= await _bakeLegacyImage(imported);
    // imagePathは元端末のパスをそのまま引き継げないため、copyWith（??で
    // nullを無視する実装）を使わず、常にnewImagePath（なければ未設定）で
    // 明示的に上書きする。
    final stamp = Stamp(
      id: id,
      name: imported.name,
      imagePath: newImagePath,
      isFavorite: imported.isFavorite,
      tags: imported.tags,
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
