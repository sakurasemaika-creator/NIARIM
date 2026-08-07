import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/layer_compositor.dart';
import '../engine/layer_range_resolver.dart';
import '../engine/mirapro_serializer.dart';
import '../engine/tile_manager.dart';
import '../models/camera_keyframe.dart';
import '../models/effect_filter_instance.dart';
import '../models/layer.dart';
import '../models/project.dart';
import '../models/scene.dart';
import '../models/text_object.dart';
import '../engine/undo_manager.dart';

class ProjectFolder {
  final String id;
  final String name;
  final int? color; // ARGB。nullの場合はデフォルトのフォルダアイコン色を使う
  ProjectFolder({required this.id, required this.name, this.color});

  ProjectFolder copyWith({String? name, Object? color = _folderSentinel}) => ProjectFolder(
        id: id,
        name: name ?? this.name,
        color: identical(color, _folderSentinel) ? this.color : color as int?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory ProjectFolder.fromJson(Map<String, dynamic> json) => ProjectFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as int?,
      );
}

const _folderSentinel = Object();

class ProjectService extends ChangeNotifier {
  final List<Project> _projects = [];
  final List<Project> _trash = [];
  final List<Project> _shared = [];
  final List<ProjectFolder> _folders = [];
  // ゴミ箱へ移動した日時（projectId -> deletedAt）。自動削除設定（設定画面の
  // 日数）に基づく期限切れ判定に使用する。SharedPreferencesへ永続化することで
  // アプリ再起動後もゴミ箱の状態（どのプロジェクトが削除済みか）を維持する。
  final Map<String, DateTime> _trashDeletedAt = {};

  // プロジェクトIDをキーにシーンリストを管理
  final Map<String, List<Scene>> _scenes = {};
  // 削除済みレイヤーの一時保持（Undo用）
  final Map<String, Layer> _removedLayers = {};
  // レイヤーIDカウンター（プロジェクトIDをキー）
  final Map<String, int> _layerIdCounters = {};

  // 表示範囲を持つレイヤー（共通・タイムライン素材・ウォーターマーク）の
  // 「ホーム位置」（実際にピクセルデータ・Layerオブジェクトが物理的に存在する
  // シーン・フレーム）を保持するインデックス。projectId -> layerId -> 位置。
  // これらのレイヤーは他のフレームからは layersOf() で動的に合成表示される
  // （同一データを複数フレームへ複製せず、メモリを節約するため）。
  final Map<String, Map<String, ({String sceneId, int frameIndex})>> _layerHomes = {};

  // TileManager をプロジェクトIDごとに保持
  final Map<String, TileManager> _tileManagers = {};

  TileManager tileManagerOf(String projectId) {
    return _tileManagers.putIfAbsent(projectId, () {
      final p = _projects.where((p) => p.id == projectId).firstOrNull;
      return TileManager(
        canvasWidth: p?.drawingWidth ?? 1920,
        canvasHeight: p?.drawingHeight ?? 1080,
      );
    });
  }

  UndoManager? _undoManager;

  void setUndoManager(UndoManager undoManager) {
    _undoManager = undoManager;
  }

  List<Project> get projects => List.unmodifiable(_projects);
  List<Project> get trash => List.unmodifiable(_trash);
  List<Project> get shared => List.unmodifiable(_shared);
  List<ProjectFolder> get folders => List.unmodifiable(_folders);
  List<Project> get favorites => _projects.where((p) => p.isFavorite).toList();

  /// プロジェクトがゴミ箱へ移動された日時（ゴミ箱一覧の削除日時表示用）
  DateTime? deletedAtOf(String projectId) => _trashDeletedAt[projectId];

  Future<void> init() async {
    try {
      await _loadTrashState();
      await _loadFolders();
      final basePath = await MiraproSerializer.projectsBasePath();
      final baseDir = Directory(basePath);
      if (!baseDir.existsSync()) return;
      for (final dir in baseDir.listSync().whereType<Directory>()) {
        final projectId = dir.path.split(RegExp(r'[\\/]')).last;
        final miraproFile = File('${dir.path}/$projectId.mirapro');
        if (!miraproFile.existsSync()) continue;
        try {
          final data = await MiraproSerializer.load(miraproFile.path);
          if (_trashDeletedAt.containsKey(projectId)) {
            // ゴミ箱内のプロジェクト：一覧には出さず、シーンデータもメモリに
            // 載せない（deleteProject()直後と同じ状態を再現する）
            _trash.add(data.project);
          } else {
            _projects.add(data.project);
            _applyLoadedProjectData(data);
          }
        } catch (_) {
          // 破損ファイルはスキップ
        }
      }
      notifyListeners();
    } catch (_) {
      // ストレージアクセス失敗時は空状態で起動
    }
  }

  // ─── ゴミ箱の状態永続化（仕様書06・19：ゴミ箱・自動削除設定） ───────────
  // 従来はゴミ箱への移動が純粋にメモリ上の状態でしかなく、アプリを再起動する
  // と全プロジェクトディレクトリを無条件に読み込み直すため削除が取り消された
  // ように見えるバグがあった。ゴミ箱移動日時をSharedPreferencesへ保存し、
  // 起動時にどのプロジェクトがゴミ箱内かを復元することで解消する。

  static const _trashPrefsKey = 'trashed_projects';

  Future<void> _loadTrashState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_trashPrefsKey) ?? [];
      for (final entry in raw) {
        final sep = entry.indexOf('|');
        if (sep < 0) continue;
        final id = entry.substring(0, sep);
        final dt = DateTime.tryParse(entry.substring(sep + 1));
        if (dt != null) _trashDeletedAt[id] = dt;
      }
    } catch (_) {
      // 読み込み失敗時はゴミ箱状態なしとして続行
    }
  }

  Future<void> _persistTrashState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _trashDeletedAt.entries
          .map((e) => '${e.key}|${e.value.toIso8601String()}')
          .toList();
      await prefs.setStringList(_trashPrefsKey, list);
    } catch (_) {
      // 保存失敗時も続行（次回操作時に再試行される）
    }
  }

  /// ゴミ箱の自動削除設定（設定画面で選んだ日数）に従い、保持期限を過ぎた
  /// プロジェクトを完全削除する。days<=0（OFF）の場合は何もしない。
  Future<void> sweepExpiredTrash(int days) async {
    if (days <= 0) return;
    final now = DateTime.now();
    final expired = _trash.where((p) {
      final deletedAt = _trashDeletedAt[p.id];
      if (deletedAt == null) return false;
      return now.difference(deletedAt).inDays >= days;
    }).map((p) => p.id).toList();
    for (final id in expired) {
      await permanentDelete(id);
    }
  }

  /// ディスクから読み込んだプロジェクトデータをメモリ上のマップへ反映する。
  /// init()（起動時の全件読み込み）とrestoreProject()（ゴミ箱からの復元時の
  /// 再読み込み）で共通利用する。
  void _applyLoadedProjectData(MiraproData data) {
    final projectId = data.project.id;
    _scenes[projectId] = data.scenes;
    _layerHomes[projectId] = buildLayerHomeIndex(data.scenes);
    final tm = TileManager(
      canvasWidth: data.project.drawingWidth,
      canvasHeight: data.project.drawingHeight,
    );
    tm.importAll(data.tileData);
    _tileManagers[projectId] = tm;
    _layerIdCounters[projectId] = _maxLayerCounter(data.scenes);
  }

  /// projectIdの.miraproファイルをディスクから再読み込みする。
  /// ファイルが存在しない・読み込みに失敗した場合は何もしない（呼び出し元で
  /// _scenesが空のままになるが、これは元々ファイルが存在しない異常系であり
  /// これ以上復元しようがないため）。
  Future<void> _reloadProjectDataFromDisk(String projectId) async {
    try {
      final basePath = await MiraproSerializer.projectsBasePath();
      final miraproFile = File('$basePath/$projectId/$projectId.mirapro');
      if (!miraproFile.existsSync()) return;
      final data = await MiraproSerializer.load(miraproFile.path);
      _applyLoadedProjectData(data);
    } catch (_) {
      // 読み込み失敗時は何もしない
    }
  }

  int _maxLayerCounter(List<Scene> scenes) {
    int max = 1;
    for (final scene in scenes) {
      for (final frame in scene.frames) {
        for (final layer in frame.layers) {
          final num = int.tryParse(layer.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (num >= max) max = num + 1;
        }
      }
    }
    return max;
  }

  // ─── Scene/Frame/Layer アクセサ ───────────────────────────────────────

  List<Scene> scenesOf(String projectId) =>
      List.unmodifiable(_scenes[projectId] ?? []);

  Scene? sceneOf(String projectId, String sceneId) =>
      (_scenes[projectId] ?? []).where((s) => s.id == sceneId).firstOrNull;

  // ─── シーンCRUD（仕様書05：Scene0001形式で内部管理） ───────────────────

  int _nextSceneIndex(String projectId) {
    final scenes = _scenes[projectId] ?? [];
    int max = 0;
    for (final s in scenes) {
      final num = int.tryParse(s.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (num > max) max = num;
    }
    return max + 1;
  }

  /// シーンを末尾に追加する。通常レイヤー1枚・1フレームで初期化する。
  Scene addScene(String projectId) {
    final scenes = _scenes.putIfAbsent(projectId, () => []);
    final n = _nextSceneIndex(projectId);
    final sceneId = 'Scene${n.toString().padLeft(4, '0')}';
    final layer = Layer(
      id: _nextLayerId(projectId),
      name: 'レイヤー1',
      type: LayerType.normal,
    );
    final scene = Scene(
      id: sceneId,
      index: scenes.length,
      frames: [Frame(index: 0, layers: [layer])],
    );
    scenes.add(scene);
    notifyListeners();
    return scene;
  }

  /// シーンを削除する（最低1シーンは残す。仕様書05）。描画タイルも破棄する。
  void removeScene(String projectId, String sceneId) => removeScenes(projectId, [sceneId]);

  /// 複数シーンを一括削除する（最低1シーンは残す）。
  void removeScenes(String projectId, List<String> sceneIds) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idsToRemove = sceneIds.toSet();
    final remaining = scenes.where((s) => !idsToRemove.contains(s.id)).toList();
    if (remaining.isEmpty) return; // 全シーン削除は不可
    final tm = _tileManagers[projectId];
    for (final id in idsToRemove) {
      tm?.removeSceneTiles(id);
    }
    final reindexed = remaining
        .asMap()
        .entries
        .map((e) => e.value.copyWith(index: e.key))
        .toList();
    _scenes[projectId] = reindexed;
    _layerHomes[projectId]?.removeWhere((_, home) => idsToRemove.contains(home.sceneId));
    notifyListeners();
  }

  /// シーン名を変更する（仕様書05：シーン名変更ダイアログ）。
  void renameScene(String projectId, String sceneId, String newName) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    scenes[idx] = scenes[idx].copyWith(name: newName);
    notifyListeners();
  }

  /// シーンを指定した順序（IDのリスト）へ並び替える（仕様書05：カーソル固定方式）。
  /// sceneIdはそのまま・indexのみ新しい並び順に合わせて振り直す。
  void reorderScenesByIds(String projectId, List<String> orderedSceneIds) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final byId = {for (final s in scenes) s.id: s};
    final reordered = <Scene>[];
    for (final id in orderedSceneIds) {
      final s = byId.remove(id);
      if (s != null) reordered.add(s);
    }
    // 万一渡されなかったシーンがあれば末尾へ残す（データ消失防止）
    reordered.addAll(byId.values);
    final reindexed = reordered
        .asMap()
        .entries
        .map((e) => e.value.copyWith(index: e.key))
        .toList();
    _scenes[projectId] = reindexed;
    notifyListeners();
  }

  /// 指定フレームで実際に表示すべきレイヤー一覧を返す。このフレームに物理的に
  /// 存在するレイヤー（先頭側）に加え、他のフレームがホーム位置となっている
  /// 表示範囲レイヤー（共通・タイムライン素材・ウォーターマーク）のうち、
  /// 表示範囲がこのフレームを含むものを末尾へ動的に合成する（仕様書05・16：
  /// 表示範囲内のフレームのみレイヤーパレット・キャンバスへ表示）。
  List<Layer> layersOf(String projectId, String sceneId, int frameIndex) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null || frameIndex >= scene.frames.length) return [];
    final ownLayers = scene.frames[frameIndex].layers;
    final homes = _layerHomes[projectId];
    if (homes == null || homes.isEmpty) return List.unmodifiable(ownLayers);
    return List.unmodifiable(resolveFrameLayers(
        _scenes[projectId] ?? const [], homes, sceneId, frameIndex, ownLayers));
  }

  /// レイヤーIDから、表示範囲レイヤーの「ホーム位置」（実データが存在する
  /// シーン・フレーム）を取得する。範囲レイヤーでない場合はnull。
  LayerHome? homeOf(String projectId, String layerId) => _layerHomes[projectId]?[layerId];

  /// プロジェクト全体の表示範囲レイヤーのホーム位置インデックスを返す
  /// （プレビュー・書き出しでの合成キー解決用）。
  Map<String, LayerHome> layerHomesOf(String projectId) =>
      Map.unmodifiable(_layerHomes[projectId] ?? const {});

  /// レイヤーのTileManager合成キーを解決する。表示範囲レイヤーは、実際に
  /// 表示中のフレームに関わらず常にホーム位置のタイルバッファを参照する
  /// （複数フレームでの共有表示・共有編集を実現するため）。
  String tileKeyFor(String projectId, String sceneId, int frameIndex, String layerId) =>
      resolveTileKey(_layerHomes[projectId] ?? const {}, sceneId, frameIndex, layerId);

  void _registerHomeIfNeeded(
      String projectId, String sceneId, int frameIndex, Layer layer) {
    if (!isRangeLayerType(layer.type)) return;
    (_layerHomes[projectId] ??= {})[layer.id] = (sceneId: sceneId, frameIndex: frameIndex);
  }

  // ─── レイヤーID生成 ───────────────────────────────────────────────────

  String _nextLayerId(String projectId) {
    final count = (_layerIdCounters[projectId] ?? 1);
    _layerIdCounters[projectId] = count + 1;
    return 'Layer${count.toString().padLeft(4, '0')}';
  }

  // ─── レイヤー追加（内部・Undo/Redo から呼ばれる） ─────────────────────

  void _insertLayerById(
      String projectId, String sceneId, int frameIndex, String layerId) {
    final layer = _removedLayers[layerId];
    if (layer == null) return;
    _applyLayerInsert(projectId, sceneId, frameIndex, layer, 0);
    _registerHomeIfNeeded(projectId, sceneId, frameIndex, layer);
  }

  void _removeLayerById(
      String projectId, String sceneId, int frameIndex, String layerId) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (frameIndex >= scene.frames.length) return;
    final frame = scene.frames[frameIndex];
    final layerIdx = frame.layers.indexWhere((l) => l.id == layerId);
    if (layerIdx < 0) return;
    final removed = frame.layers[layerIdx];
    _removedLayers[layerId] = removed;
    final newLayers = List<Layer>.from(frame.layers)..removeAt(layerIdx);
    _applyFrameUpdate(projectId, sceneIdx, frameIndex, newLayers);
    _layerHomes[projectId]?.remove(layerId);
  }

  void _applyLayerInsert(String projectId, String sceneId, int frameIndex,
      Layer layer, int insertIndex) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (frameIndex >= scene.frames.length) return;
    final frame = scene.frames[frameIndex];
    final newLayers = List<Layer>.from(frame.layers)
      ..insert(insertIndex, layer);
    _applyFrameUpdate(projectId, sceneIdx, frameIndex, newLayers);
  }

  void _applyFrameUpdate(
      String projectId, int sceneIdx, int frameIndex, List<Layer> newLayers) {
    final scenes = _scenes[projectId]!;
    final scene = scenes[sceneIdx];
    final newFrames = List<Frame>.from(scene.frames);
    newFrames[frameIndex] = scene.frames[frameIndex].copyWith(layers: newLayers);
    scenes[sceneIdx] = scene.copyWith(frames: newFrames);
    notifyListeners();
  }

  // ─── 公開 Layer API ───────────────────────────────────────────────────

  /// テキストレイヤーを追加し、Undoスタックに積む
  Layer addTextLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String text,
    required Offset position,
  }) {
    final layerId = _nextLayerId(projectId);
    // テキストレイヤー名：テキスト1 / テキスト2 / テキスト3 …（仕様書15）
    final existingTextCount = layersOf(projectId, sceneId, frameIndex)
        .where((l) => l.type == LayerType.text)
        .length;
    final textObject = TextObject(
      id: layerId,
      text: text,
      position: position,
    );
    final layer = Layer(
      id: layerId,
      name: 'テキスト${existingTextCount + 1}',
      type: LayerType.text,
      textObject: textObject,
    );
    _applyLayerInsert(projectId, sceneId, frameIndex, layer, 0);

    _undoManager?.push(LayerAddUndoAction(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layerId: layerId,
      insertIndex: 0,
      doAdd: _insertLayerById,
      doRemove: _removeLayerById,
    ));
    return layer;
  }

  /// 通常レイヤーを追加し、Undoスタックに積む
  Layer addLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required LayerType type,
    required String name,
  }) {
    final layerId = _nextLayerId(projectId);
    final layer = Layer(id: layerId, name: name, type: type);
    _applyLayerInsert(projectId, sceneId, frameIndex, layer, 0);
    _registerHomeIfNeeded(projectId, sceneId, frameIndex, layer);

    _undoManager?.push(LayerAddUndoAction(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layerId: layerId,
      insertIndex: 0,
      doAdd: _insertLayerById,
      doRemove: _removeLayerById,
    ));
    return layer;
  }

  /// レイヤーを削除し、Undoスタックに積む。表示範囲レイヤー（現在フレームに
  /// 他フレームから合成表示されているもの）の場合は、実データのあるホーム
  /// 位置を対象に削除する。
  void removeLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
  }) {
    final home = _layerHomes[projectId]?[layerId] ??
        (sceneId: sceneId, frameIndex: frameIndex);
    final layers = layersOf(projectId, home.sceneId, home.frameIndex);
    final removedIndex = layers.indexWhere((l) => l.id == layerId);
    if (removedIndex < 0) return;
    _removedLayers[layerId] = layers[removedIndex];
    _removeLayerById(projectId, home.sceneId, home.frameIndex, layerId);

    _undoManager?.push(LayerRemoveUndoAction(
      projectId: projectId,
      sceneId: home.sceneId,
      frameIndex: home.frameIndex,
      layerId: layerId,
      removedIndex: removedIndex,
      doAdd: _insertLayerById,
      doRemove: _removeLayerById,
    ));
  }

  /// レイヤーを更新する（表示切替・ロック等）。表示範囲レイヤーは実データの
  /// あるホーム位置へ書き戻す（他フレームから合成表示中に編集した場合も
  /// 正しく反映されるようにするため）。
  void updateLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required Layer layer,
  }) {
    final home = _layerHomes[projectId]?[layer.id] ??
        (sceneId: sceneId, frameIndex: frameIndex);
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == home.sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (home.frameIndex >= scene.frames.length) return;
    final frame = scene.frames[home.frameIndex];
    final layerIdx = frame.layers.indexWhere((l) => l.id == layer.id);
    if (layerIdx < 0) return;
    final newLayers = List<Layer>.from(frame.layers)..[layerIdx] = layer;
    _applyFrameUpdate(projectId, sceneIdx, home.frameIndex, newLayers);
  }

  /// レイヤーを並び替える。[oldIndex]が現在フレームに物理的に存在しない
  /// レイヤー（他フレームがホームの表示範囲レイヤー）を指す場合は、この
  /// フレームでの並び替え対象外として何もしない（表示リストの末尾に
  /// 追加される合成レイヤーのため、フレームローカルな並び替えは対象外）。
  void reorderLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required int oldIndex,
    required int newIndex,
  }) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (frameIndex >= scene.frames.length) return;
    final frame = scene.frames[frameIndex];
    if (oldIndex < 0 || oldIndex >= frame.layers.length) return;
    final newLayers = List<Layer>.from(frame.layers);
    final layer = newLayers.removeAt(oldIndex);
    final target = (newIndex > oldIndex ? newIndex - 1 : newIndex).clamp(0, newLayers.length);
    newLayers.insert(target, layer);
    _applyFrameUpdate(projectId, sceneIdx, frameIndex, newLayers);
  }

  /// .mirashare を複製して通常プロジェクトとして追加する（仕様書06：共有フロー）。
  /// 新規プロジェクトIDを採番し、共有元ファイル自体は変更しない。
  Future<Project> importSharedProject(MiraproData data) async {
    final newId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final project = data.project.copyWith(
      id: newId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _projects.add(project);
    _scenes[newId] = data.scenes;
    _layerHomes[newId] = buildLayerHomeIndex(data.scenes);
    final tm = TileManager(
      canvasWidth: project.drawingWidth,
      canvasHeight: project.drawingHeight,
    );
    tm.importAll(data.tileData);
    _tileManagers[newId] = tm;
    _layerIdCounters[newId] = _maxLayerCounter(data.scenes);
    _saveAsync(newId);
    notifyListeners();
    return project;
  }

  /// 自動保存データを既存プロジェクトへ復元する（クラッシュ復元専用、仕様書06・09）。
  /// プロジェクトIDは維持したまま、シーン・タイルの内容のみ自動保存時点へ戻す。
  void restoreFromAutosave(String projectId, MiraproData data) {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx < 0) return;
    _projects[idx] = data.project.copyWith(id: projectId, updatedAt: DateTime.now());
    _scenes[projectId] = data.scenes;
    _layerHomes[projectId] = buildLayerHomeIndex(data.scenes);
    final tm = _tileManagers.putIfAbsent(
        projectId,
        () => TileManager(
            canvasWidth: data.project.drawingWidth, canvasHeight: data.project.drawingHeight));
    tm.importAll(data.tileData);
    _layerIdCounters[projectId] = _maxLayerCounter(data.scenes);
    notifyListeners();
  }

  // ─── 自動塗り連携 ─────────────────────────────────────────────────────

  /// 自動塗り用線画レイヤーの直下にある自動塗りレイヤーへ更新マークを立てる。
  /// 線画レイヤーへ描画があった際に呼び出す（仕様書16：needsAutofillUpdate自動セット）。
  void markLineartDirty(
      String projectId, String sceneId, int frameIndex, String lineartLayerId) {
    final layers = layersOf(projectId, sceneId, frameIndex);
    final idx = layers.indexWhere((l) => l.id == lineartLayerId);
    if (idx < 0 || layers[idx].type != LayerType.autoFillLineart) return;
    if (idx + 1 < layers.length && layers[idx + 1].type == LayerType.autoFill) {
      final target = layers[idx + 1];
      if (!target.needsAutofillUpdate) {
        updateLayer(
          projectId: projectId,
          sceneId: sceneId,
          frameIndex: frameIndex,
          layer: target.copyWith(needsAutofillUpdate: true),
        );
      }
    }
  }

  /// 自動塗りプリセットのパーツ色・名前が変更／削除された際、当該パーツIDを参照する
  /// 全プロジェクト・全フレームの自動塗りレイヤーへ更新マークを伝播する（仕様書04）。
  void markAutofillUpdateForPartId(String partId) {
    bool changed = false;
    for (final entry in _scenes.entries) {
      final scenes = entry.value;
      for (int si = 0; si < scenes.length; si++) {
        final scene = scenes[si];
        for (int fi = 0; fi < scene.frames.length; fi++) {
          final layers = scene.frames[fi].layers;
          for (int li = 0; li < layers.length; li++) {
            final lineart = layers[li];
            if (lineart.type != LayerType.autoFillLineart || lineart.partId != partId) continue;
            if (li + 1 >= layers.length || layers[li + 1].type != LayerType.autoFill) continue;
            final autofillLayer = layers[li + 1];
            if (autofillLayer.needsAutofillUpdate) continue;
            final newLayers = List<Layer>.from(layers);
            newLayers[li + 1] = autofillLayer.copyWith(needsAutofillUpdate: true);
            final newFrames = List<Frame>.from(scene.frames);
            newFrames[fi] = scene.frames[fi].copyWith(layers: newLayers);
            scenes[si] = scene.copyWith(frames: newFrames);
            changed = true;
          }
        }
      }
    }
    if (changed) notifyListeners();
  }

  /// 自動塗り用線画レイヤーへプリセットのパーツを割り当てる。表示名はパーツ名に連動し、
  /// 直下に自動塗りレイヤーが存在する場合はそちらの表示名・パーツIDも一括更新する（仕様書04）。
  void assignAutofillPart({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String lineartLayerId,
    required String partId,
    required String partName,
  }) {
    final layers = layersOf(projectId, sceneId, frameIndex);
    final idx = layers.indexWhere((l) => l.id == lineartLayerId);
    if (idx < 0 || layers[idx].type != LayerType.autoFillLineart) return;
    updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layer: layers[idx].copyWith(partId: partId, name: '$partName（線画）'),
    );
    if (idx + 1 < layers.length && layers[idx + 1].type == LayerType.autoFill) {
      updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layer: layers[idx + 1].copyWith(partId: partId, name: '$partName（自動塗り）'),
      );
    }
  }

  /// 書き出し前の未更新警告用：指定プロジェクトの全シーン・全フレームに
  /// needsAutofillUpdate==true の自動塗りレイヤーが存在するかを判定する（仕様書04・06）。
  bool hasOutdatedAutofillLayers(String projectId) {
    final scenes = _scenes[projectId];
    if (scenes == null) return false;
    for (final scene in scenes) {
      for (final frame in scene.frames) {
        if (frame.layers.any((l) => l.type == LayerType.autoFill && l.needsAutofillUpdate)) {
          return true;
        }
      }
    }
    return false;
  }

  // ─── Frame API ────────────────────────────────────────────────────────

  int frameCount(String projectId, String sceneId) =>
      sceneOf(projectId, sceneId)?.frames.length ?? 0;

  /// フレームの保持セル数を変更する
  void setFrameHold(String projectId, String sceneId, int frameIndex, int hold) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (frameIndex >= scene.frames.length) return;
    final newFrames = List<Frame>.from(scene.frames);
    newFrames[frameIndex] = scene.frames[frameIndex].copyWith(hold: hold.clamp(1, 99));
    scenes[sceneIdx] = scene.copyWith(frames: newFrames);
    notifyListeners();
  }

  int frameHold(String projectId, String sceneId, int frameIndex) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null || frameIndex >= scene.frames.length) return 1;
    return scene.frames[frameIndex].hold;
  }

  /// フレームを末尾に追加する
  void addFrame(String projectId, String sceneId) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    // 直前フレームの通常レイヤー構成を引き継ぐ（描画データは空）
    final prevLayers = scene.frames.isNotEmpty
        ? scene.frames.last.layers
            .where((l) => l.type == LayerType.normal)
            .map((l) => Layer(id: l.id, name: l.name, type: l.type))
            .toList()
        : [Layer(id: _nextLayerId(projectId), name: 'レイヤー1', type: LayerType.normal)];
    final newFrame = Frame(index: scene.frames.length, layers: prevLayers);
    final newFrames = List<Frame>.from(scene.frames)..add(newFrame);
    scenes[sceneIdx] = scene.copyWith(frames: newFrames);
    notifyListeners();
  }

  /// フレームを削除する（最低1フレームは残す）
  void removeFrame(String projectId, String sceneId, int frameIndex) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (scene.frames.length <= 1) return;
    if (frameIndex < 0 || frameIndex >= scene.frames.length) return;

    // 削除位置より後ろのフレームはindexが1つずつ前へ詰まる。描画データは
    // frameLayerKey(sceneId, frameIndex, layerId)でTileManagerに保存されて
    // いるため、indexの変更に合わせてタイルデータも付け替える（先頭側から
    // 順に処理することで、まだ移動していない位置への上書きを避ける）。
    final tm = _tileManagers[projectId];
    if (tm != null) {
      for (int i = frameIndex + 1; i < scene.frames.length; i++) {
        for (final layer in scene.frames[i].layers) {
          tm.renameKey(
            frameLayerKey(sceneId, i, layer.id),
            frameLayerKey(sceneId, i - 1, layer.id),
          );
        }
      }
    }

    final newFrames = List<Frame>.from(scene.frames)..removeAt(frameIndex);
    final reindexed = newFrames
        .asMap()
        .entries
        .map((e) => e.value.copyWith(index: e.key))
        .toList();
    scenes[sceneIdx] = scene.copyWith(frames: reindexed);

    // 表示範囲レイヤーのホーム位置インデックスも合わせて更新する。
    // 削除されたフレーム自体がホームだったレイヤーは実データごと消滅するため
    // インデックスから除去し、それより後ろのフレームがホームだったレイヤーは
    // インデックスを1つ前へ詰める。
    final homes = _layerHomes[projectId];
    if (homes != null) {
      final toRemove = <String>[];
      final toShift = <String>[];
      homes.forEach((layerId, home) {
        if (home.sceneId != sceneId) return;
        if (home.frameIndex == frameIndex) {
          toRemove.add(layerId);
        } else if (home.frameIndex > frameIndex) {
          toShift.add(layerId);
        }
      });
      for (final id in toRemove) {
        homes.remove(id);
      }
      for (final id in toShift) {
        final h = homes[id]!;
        homes[id] = (sceneId: h.sceneId, frameIndex: h.frameIndex - 1);
      }
    }
    notifyListeners();
  }

  // ─── カメラキーフレーム（仕様書05：XY移動・拡大・回転） ─────────────────

  List<CameraKeyframe> cameraKeyframesOf(String projectId, String sceneId) =>
      List.unmodifiable(sceneOf(projectId, sceneId)?.cameraKeyframes ?? const []);

  void _updateSceneCameraKeyframes(
      String projectId, String sceneId, List<CameraKeyframe> keyframes) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    final sorted = List<CameraKeyframe>.from(keyframes)
      ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    scenes[idx] = scenes[idx].copyWith(cameraKeyframes: sorted);
    notifyListeners();
  }

  /// キーフレームを追加する。同じframeIndexが既にあれば置き換える。
  void addCameraKeyframe(String projectId, String sceneId, CameraKeyframe kf) {
    final current = cameraKeyframesOf(projectId, sceneId);
    final without = current.where((k) => k.frameIndex != kf.frameIndex).toList();
    _updateSceneCameraKeyframes(projectId, sceneId, [...without, kf]);
  }

  /// 既存キーフレーム（[oldFrameIndex]で特定）を[newKf]で置き換える。
  /// newKf.frameIndexが他のキーフレームと重複する場合はその既存分を消す。
  void updateCameraKeyframe(
      String projectId, String sceneId, int oldFrameIndex, CameraKeyframe newKf) {
    final current = cameraKeyframesOf(projectId, sceneId);
    final without =
        current.where((k) => k.frameIndex != oldFrameIndex && k.frameIndex != newKf.frameIndex).toList();
    _updateSceneCameraKeyframes(projectId, sceneId, [...without, newKf]);
  }

  void removeCameraKeyframe(String projectId, String sceneId, int frameIndex) {
    final current = cameraKeyframesOf(projectId, sceneId);
    _updateSceneCameraKeyframes(
        projectId, sceneId, current.where((k) => k.frameIndex != frameIndex).toList());
  }

  // ─── 演出フィルター（仕様書18：タイムライン非破壊編集） ─────────────────

  List<EffectFilterInstance> effectFiltersOf(String projectId, String sceneId) =>
      List.unmodifiable(sceneOf(projectId, sceneId)?.effectFilters ?? const []);

  void _updateSceneEffectFilters(
      String projectId, String sceneId, List<EffectFilterInstance> filters) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    scenes[idx] = scenes[idx].copyWith(effectFilters: filters);
    notifyListeners();
  }

  void addEffectFilter(String projectId, String sceneId, EffectFilterInstance filter) {
    _updateSceneEffectFilters(
        projectId, sceneId, [...effectFiltersOf(projectId, sceneId), filter]);
  }

  void updateEffectFilter(String projectId, String sceneId, EffectFilterInstance filter) {
    final updated = effectFiltersOf(projectId, sceneId)
        .map((f) => f.id == filter.id ? filter : f)
        .toList();
    _updateSceneEffectFilters(projectId, sceneId, updated);
  }

  void removeEffectFilter(String projectId, String sceneId, String filterId) {
    _updateSceneEffectFilters(projectId, sceneId,
        effectFiltersOf(projectId, sceneId).where((f) => f.id != filterId).toList());
  }

  // ─── レイヤー結合 ─────────────────────────────────────────────────────

  /// 結合可能なレイヤー種別（仕様書16）。共通レイヤー・フォルダ・
  /// タイムライン素材（画像/動画/ウォーターマーク）・テキストは結合不可。
  static const _mergeableLayerTypes = {
    LayerType.normal,
    LayerType.autoFillLineart,
    LayerType.autoFill,
  };

  /// 選択したレイヤー群を1枚の通常レイヤーへ結合する（仕様書16）。
  /// - 自動塗り用線画・自動塗りレイヤーが含まれる場合は結合後に通常レイヤーへ
  ///   変換される（パーツID・更新マークは破棄）。
  /// - ブレンドモード・不透明度・クリッピングは一番下（配列末尾側＝背面）の
  ///   レイヤーの設定を引き継ぐ。
  /// - タイル内容は選択レイヤーを表示順で合成した結果になる。
  /// 2枚未満、または結合不可の種別が含まれる場合は何もしない。
  Future<void> mergeLayers({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required List<String> layerIds,
  }) async {
    if (layerIds.length < 2) return;
    final layers = layersOf(projectId, sceneId, frameIndex);
    final indices = <int>[];
    for (final id in layerIds) {
      final idx = layers.indexWhere((l) => l.id == id);
      if (idx < 0) return;
      indices.add(idx);
    }
    if (indices.any((i) => !_mergeableLayerTypes.contains(layers[i].type))) return;

    indices.sort();
    final bottomIndex = indices.last;
    final bottomLayer = layers[bottomIndex];
    final selectedLayers = indices.map((i) => layers[i]).toList();

    final tm = _tileManagers[projectId];
    if (tm != null) {
      final mergedImage = await LayerCompositor.composite(
        tm,
        selectedLayers,
        (l) => frameLayerKey(sceneId, frameIndex, l.id),
        tm.canvasWidth,
        tm.canvasHeight,
      );
      final byteData = await mergedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      mergedImage.dispose();
      if (byteData != null) {
        tm.replaceLayerPixels(
            frameLayerKey(sceneId, frameIndex, bottomLayer.id), byteData.buffer.asUint8List());
      }
      for (final layer in selectedLayers) {
        if (layer.id == bottomLayer.id) continue;
        tm.removeLayer(frameLayerKey(sceneId, frameIndex, layer.id));
      }
    }

    // 合成が非同期で完了するまでの間に他の変更が入っている可能性があるため、
    // 反映直前に最新のレイヤーリストを取得し直す。
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (frameIndex >= scene.frames.length) return;
    final latestLayers = List<Layer>.from(scene.frames[frameIndex].layers);
    final removeIds =
        selectedLayers.map((l) => l.id).where((id) => id != bottomLayer.id).toSet();
    latestLayers.removeWhere((l) => removeIds.contains(l.id));
    final insertAt = latestLayers.indexWhere((l) => l.id == bottomLayer.id);
    if (insertAt < 0) return;
    latestLayers[insertAt] = bottomLayer.copyWith(
      type: LayerType.normal,
      partId: null,
      needsAutofillUpdate: false,
    );
    _applyFrameUpdate(projectId, sceneIdx, frameIndex, latestLayers);
  }

  // ─── Project CRUD ─────────────────────────────────────────────────────

  Future<Project> createProject({
    required String name,
    required int fps,
    required int durationSeconds,
    required int backgroundColor,
    int exportWidth = 1920,
    int exportHeight = 1080,
    double drawingAreaScale = 1.0,
  }) async {
    final projectId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final project = Project(
      id: projectId,
      name: name,
      fps: fps,
      durationSeconds: durationSeconds,
      backgroundColor: backgroundColor,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      totalWorkSeconds: 0,
      exportWidth: exportWidth,
      exportHeight: exportHeight,
      drawingAreaScale: drawingAreaScale.clamp(1.0, 10.0),
    );
    _projects.add(project);

    // 初期シーン・フレーム・レイヤーを生成（仕様書07：Scene0001/Frame0/Layer0001）
    _layerIdCounters[projectId] = 1;
    final initialLayerId = _nextLayerId(projectId); // → 'Layer0001'、以降は2から採番
    final initialLayer = Layer(
      id: initialLayerId,
      name: 'レイヤー1',
      type: LayerType.normal,
    );
    final initialFrame = Frame(index: 0, layers: [initialLayer]);
    final totalFrames = fps * durationSeconds;
    final frames = List.generate(
      totalFrames,
      (i) => i == 0 ? initialFrame : Frame(index: i, layers: [initialLayer]),
    );
    _scenes[projectId] = [
      Scene(id: 'Scene0001', index: 0, frames: frames),
    ];

    // TileManager 初期化
    _tileManagers[projectId] = TileManager(
      canvasWidth: project.drawingWidth,
      canvasHeight: project.drawingHeight,
    );

    // 初回保存
    _saveAsync(projectId);

    notifyListeners();
    return project;
  }

  /// 非同期保存（エラーはサイレントに無視）
  void _saveAsync(String projectId) {
    final project = _projects.where((p) => p.id == projectId).firstOrNull;
    final scenes = _scenes[projectId];
    final tm = _tileManagers[projectId];
    if (project == null || scenes == null || tm == null) return;
    MiraproSerializer.save(
      project: project,
      scenes: scenes,
      tileManager: tm,
    ).catchError((_) => File(''));
  }

  /// 明示的保存（タイムライン・セーブツリーから呼び出す）
  Future<void> saveProject(String projectId) async {
    final project = _projects.where((p) => p.id == projectId).firstOrNull;
    final scenes = _scenes[projectId];
    final tm = _tileManagers[projectId];
    if (project == null || scenes == null || tm == null) return;
    await MiraproSerializer.save(
      project: project,
      scenes: scenes,
      tileManager: tm,
    );
  }

  Future<void> deleteProject(String id) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      final project = _projects.removeAt(idx);
      _trash.add(project);
      _scenes.remove(id);
      _layerIdCounters.remove(id);
      _layerHomes.remove(id);
      _trashDeletedAt[id] = DateTime.now();
      await _persistTrashState();
      notifyListeners();
    }
  }

  Future<void> restoreProject(String id) async {
    final idx = _trash.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      final project = _trash.removeAt(idx);
      _projects.add(project);
      _trashDeletedAt.remove(id);
      await _persistTrashState();
      // deleteProject()でメモリ上のシーン・レイヤーホーム索引・タイルマネージャ・
      // レイヤーIDカウンターを破棄しているため、ディスク上の.miraproファイルから
      // 再読み込みして復元する（ファイル自体はdeleteProject()時に削除していない）。
      if (!_scenes.containsKey(id)) {
        await _reloadProjectDataFromDisk(id);
      }
      notifyListeners();
    }
  }

  Future<void> permanentDelete(String id) async {
    final idx = _trash.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _trash.removeAt(idx);
      _trashDeletedAt.remove(id);
      await _persistTrashState();
      // ディスク上のプロジェクトフォルダ（.mirapro・自動保存・セーブツリー等）を
      // 完全に削除する（仕様書06・19：完全削除は元に戻せない）。
      try {
        final basePath = await MiraproSerializer.projectsBasePath();
        final dir = Directory('$basePath/$id');
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {
        // 削除に失敗してもアプリ側の状態は既に消去済みのため続行する
      }
      notifyListeners();
    }
  }

  Future<void> renameProject(String id, String newName) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _projects[idx] = _projects[idx].copyWith(name: newName);
      notifyListeners();
    }
  }

  Future<void> duplicateProject(String id) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      final original = _projects[idx];
      final newId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
      final copy = original.copyWith(
        id: newId,
        name: '${original.name} (コピー)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _projects.add(copy);

      // シーンリストは複製先専用の新しいListにする（Scene/Frame/Layerはimmutableなため
      // 中身の値オブジェクト自体は共有してよいが、外側のListを共有すると片方への
      // 変更（scenes[i] = ...）がもう片方にも波及してしまうため独立させる）。
      if (_scenes.containsKey(id)) {
        _scenes[newId] = List<Scene>.from(_scenes[id]!);
        _layerHomes[newId] = buildLayerHomeIndex(_scenes[newId]!);
      }

      // レイヤーIDカウンターも引き継がないと、複製後に新規追加したレイヤーのIDが
      // 複製元から引き継いだ既存レイヤーIDと衝突する。
      if (_layerIdCounters.containsKey(id)) {
        _layerIdCounters[newId] = _layerIdCounters[id]!;
      }

      // 描画データ（タイル）も複製先IDへコピーする。TileManager.importAllは
      // ピクセルバッファをUint8List.fromListで複製するため、複製元・複製先は
      // 完全に独立したバッファになる。
      final sourceTm = _tileManagers[id];
      final newTm = TileManager(
        canvasWidth: copy.drawingWidth,
        canvasHeight: copy.drawingHeight,
      );
      if (sourceTm != null) {
        newTm.importAll(sourceTm.exportAll());
      }
      _tileManagers[newId] = newTm;

      // 複製結果をディスクへ保存する（保存しないと再起動後に消えてしまう）。
      _saveAsync(newId);

      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _projects[idx] = _projects[idx].copyWith(isFavorite: !_projects[idx].isFavorite);
      notifyListeners();
    }
  }

  Future<void> moveToFolder(String projectId, String? folderId) async {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx >= 0) {
      _projects[idx] = _projects[idx].copyWith(folderId: folderId);
      notifyListeners();
    }
  }

  Future<ProjectFolder> createFolder(String name) async {
    final folder = ProjectFolder(
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
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

  /// フォルダの色を変更する（仕様書02・19：フォルダ管理・色変更対応）。
  /// colorにnullを渡すとデフォルト色（未設定）へ戻す。
  Future<void> setFolderColor(String folderId, int? color) async {
    final idx = _folders.indexWhere((f) => f.id == folderId);
    if (idx < 0) return;
    _folders[idx] = _folders[idx].copyWith(color: color);
    await _persistFolders();
    notifyListeners();
  }

  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((f) => f.id == folderId);
    for (int i = 0; i < _projects.length; i++) {
      if (_projects[i].folderId == folderId) {
        _projects[i] = _projects[i].copyWith(folderId: null);
      }
    }
    await _persistFolders();
    notifyListeners();
  }

  // ─── フォルダの永続化 ─────────────────────────────────────────────────
  // 従来は_foldersが純粋なメモリ上のリストのみで管理されており、アプリを
  // 再起動するとフォルダ（名前・色）がすべて消え、フォルダに割り当てていた
  // プロジェクトも見た目上「フォルダなし」になってしまうバグがあった。
  // SharedPreferencesへJSON形式で保存することで解消する。

  static const _foldersPrefsKey = 'project_folders';

  Future<void> _loadFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_foldersPrefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _folders
        ..clear()
        ..addAll(list.map((e) => ProjectFolder.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      // 読み込み失敗時はフォルダなしとして続行
    }
  }

  Future<void> _persistFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_foldersPrefsKey, jsonEncode(_folders.map((f) => f.toJson()).toList()));
    } catch (_) {
      // 保存失敗時も続行（次回操作時に再試行される）
    }
  }
}
