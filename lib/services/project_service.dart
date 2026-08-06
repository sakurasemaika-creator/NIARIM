import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../engine/mirapro_serializer.dart';
import '../engine/tile_manager.dart';
import '../models/layer.dart';
import '../models/project.dart';
import '../models/scene.dart';
import '../models/text_object.dart';
import '../engine/undo_manager.dart';

class ProjectFolder {
  final String id;
  final String name;
  ProjectFolder({required this.id, required this.name});
}

class ProjectService extends ChangeNotifier {
  final List<Project> _projects = [];
  final List<Project> _trash = [];
  final List<Project> _shared = [];
  final List<ProjectFolder> _folders = [];
  TrashAutoDeletionDays _trashAutoDeletion = TrashAutoDeletionDays.off;

  // プロジェクトIDをキーにシーンリストを管理
  final Map<String, List<Scene>> _scenes = {};
  // 削除済みレイヤーの一時保持（Undo用）
  final Map<String, Layer> _removedLayers = {};
  // レイヤーIDカウンター（プロジェクトIDをキー）
  final Map<String, int> _layerIdCounters = {};

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
  TrashAutoDeletionDays get trashAutoDeletion => _trashAutoDeletion;

  void setTrashAutoDeletion(TrashAutoDeletionDays days) {
    _trashAutoDeletion = days;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      final basePath = await MiraproSerializer.projectsBasePath();
      final baseDir = Directory(basePath);
      if (!baseDir.existsSync()) return;
      for (final dir in baseDir.listSync().whereType<Directory>()) {
        final projectId = dir.path.split(RegExp(r'[\\/]')).last;
        final miraproFile = File('${dir.path}/$projectId.mirapro');
        if (!miraproFile.existsSync()) continue;
        try {
          final data = await MiraproSerializer.load(miraproFile.path);
          _projects.add(data.project);
          _scenes[data.project.id] = data.scenes;
          final tm = TileManager(
            canvasWidth: data.project.drawingWidth,
            canvasHeight: data.project.drawingHeight,
          );
          tm.importAll(data.tileData);
          _tileManagers[data.project.id] = tm;
          _layerIdCounters[data.project.id] = _maxLayerCounter(data.scenes);
        } catch (_) {
          // 破損ファイルはスキップ
        }
      }
      notifyListeners();
    } catch (_) {
      // ストレージアクセス失敗時は空状態で起動
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

  List<Layer> layersOf(String projectId, String sceneId, int frameIndex) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null || frameIndex >= scene.frames.length) return [];
    return List.unmodifiable(scene.frames[frameIndex].layers);
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

  /// レイヤーを削除し、Undoスタックに積む
  void removeLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
  }) {
    final layers = layersOf(projectId, sceneId, frameIndex);
    final removedIndex = layers.indexWhere((l) => l.id == layerId);
    if (removedIndex < 0) return;
    _removedLayers[layerId] = layers[removedIndex];
    _removeLayerById(projectId, sceneId, frameIndex, layerId);

    _undoManager?.push(LayerRemoveUndoAction(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layerId: layerId,
      removedIndex: removedIndex,
      doAdd: _insertLayerById,
      doRemove: _removeLayerById,
    ));
  }

  /// レイヤーを更新する（表示切替・ロック等）
  void updateLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required Layer layer,
  }) {
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (frameIndex >= scene.frames.length) return;
    final frame = scene.frames[frameIndex];
    final layerIdx = frame.layers.indexWhere((l) => l.id == layer.id);
    if (layerIdx < 0) return;
    final newLayers = List<Layer>.from(frame.layers)..[layerIdx] = layer;
    _applyFrameUpdate(projectId, sceneIdx, frameIndex, newLayers);
  }

  /// レイヤーを並び替える
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
    final newLayers = List<Layer>.from(frame.layers);
    final layer = newLayers.removeAt(oldIndex);
    newLayers.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, layer);
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
    final newFrames = List<Frame>.from(scene.frames)..removeAt(frameIndex);
    final reindexed = newFrames
        .asMap()
        .entries
        .map((e) => e.value.copyWith(index: e.key))
        .toList();
    scenes[sceneIdx] = scene.copyWith(frames: reindexed);
    notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> restoreProject(String id) async {
    final idx = _trash.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      final project = _trash.removeAt(idx);
      _projects.add(project);
      notifyListeners();
    }
  }

  Future<void> permanentDelete(String id) async {
    _trash.removeWhere((p) => p.id == id);
    notifyListeners();
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
    notifyListeners();
    return folder;
  }

  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((f) => f.id == folderId);
    for (int i = 0; i < _projects.length; i++) {
      if (_projects[i].folderId == folderId) {
        _projects[i] = _projects[i].copyWith(folderId: null);
      }
    }
    notifyListeners();
  }
}

enum TrashAutoDeletionDays { off, days30, days60, days90 }
