import 'dart:async';

import 'creator_edit_session_reporter.dart';
import 'outgoing_share_library.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/layer_compositor.dart';
import '../engine/layer_range_resolver.dart';
import '../engine/niapro_serializer.dart';
import '../engine/timeline_stack.dart';
import '../engine/tile_manager.dart';
import '../models/audio_clip.dart';
import '../models/camera_keyframe.dart';
import '../models/layer_group.dart';
import '../models/timeline_marker.dart';
import '../models/effect_filter_instance.dart';
import '../models/layer.dart';
import '../models/project.dart';
import '../models/scene.dart';
import '../models/scene_stack.dart';
import '../models/text_object.dart';
import '../models/timeline_row_kind.dart';
import '../engine/undo_manager.dart';
import '../utils/app_error_reporter.dart';
import '../utils/duplicate_name.dart';
import '../utils/tolerant_preferences.dart';
import '../utils/folder_persistence.dart';
import '../utils/project_trash_guard.dart';
import 'autosave_service.dart';
import 'storage_info_service.dart';

/// Moving an active favorite to Trash requires removing its protection first.
class FavoriteProjectDeleteException implements Exception {
  const FavoriteProjectDeleteException();

  @override
  String toString() => 'A favorite project cannot be moved to Trash';
}

/// 読めていない作品があるので、フォルダの操作を断った：ゴミ箱のフォルダに
/// 保存先にあるのに読めていない作品が含まれるので完全に削除しなかった
/// （[ProjectService.trashedFolderHasUnreadWorks]）。
class TrashedFolderUnreadException implements Exception {
  const TrashedFolderUnreadException();

  @override
  String toString() => 'A trashed folder holds works that could not be read';
}

/// 複製の名前を付ける関数。複製元の[name]と、避ける名前の並び[taken]から
/// 複製の名前を返す（画面の言語の「(コピー)」と番号、
/// `lib/utils/duplicate_name.dart`の`numberedCopyName`）。
typedef CopyNamer = String Function(String name, Set<String> taken);

class ProjectFolder {
  final String id;
  final String name;
  final int? color; // ARGB。nullの場合はデフォルトのフォルダアイコン色を使う
  // フォルダは複数階層に対応する。nullはルート直下。
  final String? parentFolderId;
  // フォルダもお気に入り登録可能。
  final bool isFavorite;

  /// 'auto', 'none', 'item', or 'custom'. Kept in folder metadata.
  final String thumbnailMode;
  final String? thumbnailSourceId;
  final String? thumbnailImagePath;
  // 更新日時ソート時にプロジェクトと同じ基準で並べられるようにするための作成日時
  final DateTime createdAt;

  ProjectFolder({
    required this.id,
    required this.name,
    this.color,
    this.parentFolderId,
    this.isFavorite = false,
    this.thumbnailMode = 'auto',
    this.thumbnailSourceId,
    this.thumbnailImagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ProjectFolder copyWith({
    String? name,
    Object? color = _folderSentinel,
    Object? parentFolderId = _folderSentinel,
    bool? isFavorite,
    String? thumbnailMode,
    Object? thumbnailSourceId = _folderSentinel,
    Object? thumbnailImagePath = _folderSentinel,
  }) => ProjectFolder(
    id: id,
    name: name ?? this.name,
    color: identical(color, _folderSentinel) ? this.color : color as int?,
    parentFolderId: identical(parentFolderId, _folderSentinel)
        ? this.parentFolderId
        : parentFolderId as String?,
    isFavorite: isFavorite ?? this.isFavorite,
    thumbnailMode: thumbnailMode ?? this.thumbnailMode,
    thumbnailSourceId: identical(thumbnailSourceId, _folderSentinel)
        ? this.thumbnailSourceId
        : thumbnailSourceId as String?,
    thumbnailImagePath: identical(thumbnailImagePath, _folderSentinel)
        ? this.thumbnailImagePath
        : thumbnailImagePath as String?,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'parentFolderId': parentFolderId,
    'isFavorite': isFavorite,
    'thumbnailMode': thumbnailMode,
    'thumbnailSourceId': thumbnailSourceId,
    'thumbnailImagePath': thumbnailImagePath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ProjectFolder.fromJson(Map<String, dynamic> json) => ProjectFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as int?,
    parentFolderId: json['parentFolderId'] as String?,
    isFavorite: json['isFavorite'] as bool? ?? false,
    thumbnailMode: json['thumbnailMode'] as String? ?? 'auto',
    thumbnailSourceId: json['thumbnailSourceId'] as String?,
    thumbnailImagePath: json['thumbnailImagePath'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}

/// ゴミ箱へ移したフォルダ。中のフォルダ（下の階層を含む）と作品も一緒に
/// ゴミ箱へ移り、ゴミ箱の一覧にはこのフォルダ1件として出る。元に戻すと
/// 中身もすべて元の階層のまま戻る。
class TrashedFolder {
  final ProjectFolder folder;

  /// 共有・受信タブのフォルダはプロジェクト用フォルダとは別管理。
  final bool isShared;

  /// 中のフォルダ（下の階層を含む）。親子のつながりはそのまま持つ。
  final List<ProjectFolder> subfolders;

  /// フォルダと一緒にゴミ箱へ移した作品。
  final List<String> projectIds;
  final DateTime deletedAt;

  /// ゴミ箱へ移したときに保存先にあるのに読めていなかった作品（どの
  /// フォルダの作品かは読めるまで分からないので、そのとき読めていなかった
  /// 作品すべて）。読めたときに、このフォルダ（中のフォルダを含む）の作品
  /// だった作品だけを、この記録へ入れる。
  final List<String> unreadProjectIds;

  /// ゴミ箱へ移したときに保存先を一覧できなかった（読めていなかった作品が
  /// 分からない）。読めたときは、移した後に保存していない作品だけを入れる。
  final bool unreadUnlisted;

  const TrashedFolder({
    required this.folder,
    this.isShared = false,
    required this.subfolders,
    required this.projectIds,
    required this.deletedAt,
    this.unreadProjectIds = const [],
    this.unreadUnlisted = false,
  });

  TrashedFolder copyWith({
    List<String>? projectIds,
    List<String>? unreadProjectIds,
    bool? unreadUnlisted,
  }) => TrashedFolder(
    folder: folder,
    isShared: isShared,
    subfolders: subfolders,
    projectIds: projectIds ?? this.projectIds,
    deletedAt: deletedAt,
    unreadProjectIds: unreadProjectIds ?? this.unreadProjectIds,
    unreadUnlisted: unreadUnlisted ?? this.unreadUnlisted,
  );

  Map<String, dynamic> toJson() => {
    'folder': folder.toJson(),
    'isShared': isShared,
    'subfolders': [for (final f in subfolders) f.toJson()],
    'projectIds': projectIds,
    'deletedAt': deletedAt.toIso8601String(),
    if (unreadProjectIds.isNotEmpty) 'unreadProjectIds': unreadProjectIds,
    if (unreadUnlisted) 'unreadUnlisted': true,
  };

  factory TrashedFolder.fromJson(Map<String, dynamic> json) => TrashedFolder(
    folder: ProjectFolder.fromJson(json['folder'] as Map<String, dynamic>),
    isShared: json['isShared'] == true,
    subfolders: [
      for (final f in json['subfolders'] as List<dynamic>? ?? const [])
        ProjectFolder.fromJson(f as Map<String, dynamic>),
    ],
    projectIds: [
      for (final id in json['projectIds'] as List<dynamic>? ?? const [])
        id as String,
    ],
    deletedAt:
        DateTime.tryParse(json['deletedAt'] as String? ?? '') ?? DateTime.now(),
    unreadProjectIds: [
      for (final id in json['unreadProjectIds'] as List<dynamic>? ?? const [])
        id as String,
    ],
    unreadUnlisted: json['unreadUnlisted'] == true,
  );
}

const _folderSentinel = Object();

class ProjectService extends ChangeNotifier {
  ProjectService([this._autosaves]);

  final AutosaveService? _autosaves;
  final Set<String> _recoveredFromAutosave = {};
  final Set<String> _needsArchiveRewrite = {};

  /// Report the recovery once when the user first opens the restored work.
  bool takeAutosaveRecoveryNotice(String projectId) =>
      _recoveredFromAutosave.remove(projectId);

  final List<Project> _projects = [];
  final List<Project> _trash = [];
  final List<ProjectFolder> _folders = [];
  final List<TrashedFolder> _trashedFolders = [];
  // ID採番用カウンター。DateTime.now().millisecondsSinceEpoch単独だと、
  // 同一ミリ秒内に連続生成した場合にIDが衝突しうるため併用する。
  int _idCounter = 0;
  String _nextId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  // TileManagerの合成キャッシュ上限（低スペック端末対応）。
  // 端末性能判定（PerformanceService.qualityLevel）に応じてmain.dartから
  // configureTileCacheBudget()で絞り込む。未設定時は既定値16（従来通り）。
  // 見た目・機能には影響せず、低スペック端末でのメモリ使用量のみを抑える。
  int _tileCacheBudget = 16;

  /// 端末性能に応じてTileManagerの合成キャッシュ上限を設定する。
  /// 以後新規作成されるTileManagerへ適用される（既存インスタンスは対象外）。
  void configureTileCacheBudget(int maxEntries) {
    _tileCacheBudget = maxEntries;
  }

  // ゴミ箱へ移動した日時（projectId -> deletedAt）。自動削除設定（設定画面の
  // 日数）に基づく期限切れ判定に使用する。SharedPreferencesへ永続化することで
  // アプリ再起動後もゴミ箱の状態（どのプロジェクトが削除済みか）を維持する。
  final Map<String, DateTime> _trashDeletedAt = {};

  // プロジェクトIDをキーにシーンリストを管理
  final Map<String, List<Scene>> _scenes = {};
  // 削除済みレイヤーの一時保持（Undo用）
  final Map<String, Map<({String scene, int frame, String id}), Layer>>
  _removedLayers = {};
  // レイヤーIDカウンター（プロジェクトIDをキー）
  final Map<String, int> _layerIdCounters = {};

  // 表示範囲を持つレイヤー（共通・タイムライン素材・ウォーターマーク）の
  // 「ホーム位置」（実際にピクセルデータ・Layerオブジェクトが物理的に存在する
  // シーン・フレーム）を保持するインデックス。projectId -> layerId -> 位置。
  // これらのレイヤーは他のフレームからは layersOf() で動的に合成表示される
  // （同一データを複数フレームへ複製せず、メモリを節約するため）。
  final Map<String, Map<String, ({String sceneId, int frameIndex})>>
  _layerHomes = {};

  // TileManager をプロジェクトIDごとに保持
  final Map<String, TileManager> _tileManagers = {};

  /// Works listed without reading their picture tiles: the work's id and its
  /// file. Every tile of every work used to be read into memory at start-up
  /// (several hundred MB each for a long 1920×1080 work), so a phone with a
  /// few long works could run out of memory while starting. The tiles are
  /// read the first time the work's [TileManager] is used ([_tilesOf]).
  final Map<String, String> _tilesLeftInFile = {};

  /// Works whose tiles could not be read when they were opened. Their file is
  /// never written over (it still holds the picture).
  final Set<String> _unreadableTiles = {};

  /// Whether the picture of [projectId] could not be read from its file when
  /// it was opened; nothing may save over that file then.
  bool tilesUnreadable(String projectId) =>
      _unreadableTiles.contains(projectId);

  /// Whether the picture tiles of [projectId] are in memory (false while the
  /// work has not been opened since it was listed).
  @visibleForTesting
  bool tilesRead(String projectId) => !_tilesLeftInFile.containsKey(projectId);

  /// The work's [TileManager], with the tiles read from the file the first
  /// time (see [_tilesLeftInFile]).
  TileManager? _tilesOf(String projectId) {
    final path = _tilesLeftInFile.remove(projectId);
    final tiles = _tileManagers[projectId];
    if (path != null && tiles != null) {
      try {
        tiles.importAll(NiaproSerializer.loadTilesSync(path));
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
        _unreadableTiles.add(projectId);
      }
    }
    return tiles;
  }

  /// Forgets the tiles kept for [projectId] (the work is gone or its tiles
  /// are replaced).
  void _forgetTiles(String projectId) {
    _tilesLeftInFile.remove(projectId);
    _unreadableTiles.remove(projectId);
  }

  TileManager tileManagerOf(String projectId) {
    final listed = _tilesOf(projectId);
    if (listed != null) return listed;
    return _tileManagers.putIfAbsent(projectId, () {
      final p = _projects.where((p) => p.id == projectId).firstOrNull;
      return TileManager(
        canvasWidth: p?.drawingWidth ?? 1920,
        canvasHeight: p?.drawingHeight ?? 1080,
        compositeCacheMax: _tileCacheBudget,
      );
    });
  }

  UndoManager? _undoManager;

  void setUndoManager(UndoManager undoManager) {
    _undoManager = undoManager;
  }

  final Set<String> _recordingTimelineEdits = {};
  final Map<String, Map<String, bool>> _layerFolderExpansion = {};

  bool isLayerFolderExpanded(String projectId, Layer layer) =>
      _layerFolderExpansion[projectId]?[layer.id] ?? layer.isExpanded;

  void setLayerFolderExpanded(String projectId, Layer layer, bool expanded) {
    (_layerFolderExpansion[projectId] ??= {})[layer.id] = expanded;
  }

  /// A single editing command, including commands that call several model
  /// operations. Selection and panel settings live outside the project model.
  T editTimeline<T>(
    String projectId,
    String description,
    T Function() edit, {
    bool changesTiles = true,
  }) {
    final undo = _undoManager;
    if (undo == null || _recordingTimelineEdits.contains(projectId)) {
      return edit();
    }
    final manager = changesTiles ? tileManagerOf(projectId) : null;
    final beforeTiles = manager?.structuralSnapshot() ?? const {};
    final before = _captureTimeline(projectId);
    _recordingTimelineEdits.add(projectId);
    try {
      return edit();
    } finally {
      _recordingTimelineEdits.remove(projectId);
      _commitProjectEdit(
        undo,
        projectId,
        description,
        before,
        beforeTiles,
        manager,
      );
    }
  }

  /// A recipe has a single result even when intermediate layers are merged
  /// away. Only the state before and after that recipe belongs in history.
  Future<T> editProjectWithAutomation<T>(
    String projectId,
    String description,
    Future<T> Function() run,
  ) async {
    final undo = _undoManager;
    if (undo == null || _recordingTimelineEdits.contains(projectId)) {
      return run();
    }
    final manager = tileManagerOf(projectId);
    final beforeTiles = manager.structuralSnapshot();
    manager.protectHistoryTiles(beforeTiles);
    final before = _captureTimeline(projectId);
    _recordingTimelineEdits.add(projectId);
    try {
      return await run();
    } finally {
      _recordingTimelineEdits.remove(projectId);
      _commitProjectEdit(
        undo,
        projectId,
        description,
        before,
        beforeTiles,
        manager,
      );
    }
  }

  void _commitProjectEdit(
    UndoManager undo,
    String projectId,
    String description,
    _TimelineEditState before,
    Map<String, Map<String, Uint8List>> beforeTiles,
    TileManager? manager,
  ) {
    final after = _captureTimeline(projectId);
    final afterTiles = manager?.structuralSnapshot() ?? const {};
    final oldLayers = <String, Map<String, Uint8List>?>{};
    final newLayers = <String, Map<String, Uint8List>?>{};
    for (final key in {...beforeTiles.keys, ...afterTiles.keys}) {
      if (mapEquals(beforeTiles[key], afterTiles[key])) continue;
      oldLayers[key] = beforeTiles[key];
      newLayers[key] = afterTiles[key];
    }
    if (before.project == null ||
        identical(before.project, after.project) &&
            listEquals(before.scenes, after.scenes) &&
            oldLayers.isEmpty) {
      return;
    }
    manager?.protectHistoryTiles(oldLayers);
    manager?.protectHistoryTiles(newLayers);
    undo.push(
      ProjectEditUndoAction(
        description,
        () => _restoreTimeline(projectId, before, oldLayers),
        () => _restoreTimeline(projectId, after, newLayers),
        undoFrame: _changedHistoryFrame(after, before, oldLayers.keys),
        redoFrame: _changedHistoryFrame(before, after, newLayers.keys),
        retainedMaterialIds: _materialIdsIn(
          before.scenes,
        ).followedBy(_materialIdsIn(after.scenes)),
      ),
      projectId: projectId,
    );
  }

  HistoryFrame? _changedHistoryFrame(
    _TimelineEditState other,
    _TimelineEditState restored,
    Iterable<String> changedTileKeys,
  ) {
    final previousScenes = {for (final scene in other.scenes) scene.id: scene};
    for (final scene in restored.scenes) {
      final previous = previousScenes[scene.id];
      if (scene.frames.isEmpty || identical(scene, previous)) continue;
      for (var i = 0; i < scene.frames.length; i++) {
        if (previous == null ||
            i >= previous.frames.length ||
            !identical(scene.frames[i], previous.frames[i])) {
          return (sceneId: scene.id, frameIndex: i);
        }
      }
      if (scene.frames.length < previous!.frames.length) {
        return (sceneId: scene.id, frameIndex: scene.frames.length - 1);
      }
      if (!identical(scene.stack, previous.stack)) {
        return (sceneId: scene.id, frameIndex: 0);
      }
    }
    for (final tileKey in changedTileKeys) {
      final key = parseFrameLayerKey(tileKey);
      if (key == null) continue;
      final scene = restored.scenes
          .where((s) => s.id == key.sceneId)
          .firstOrNull;
      if (scene != null && key.frameIndex < scene.frames.length) {
        return (sceneId: key.sceneId, frameIndex: key.frameIndex);
      }
    }
    if (other.scenes.length != restored.scenes.length ||
        !listEquals(
          other.scenes.map((s) => s.id).toList(),
          restored.scenes.map((s) => s.id).toList(),
        )) {
      final scene = restored.scenes
          .where((s) => s.frames.isNotEmpty)
          .firstOrNull;
      if (scene != null) return (sceneId: scene.id, frameIndex: 0);
    }
    return null;
  }

  _TimelineEditState _captureTimeline(String projectId) {
    final project = _projects.where((p) => p.id == projectId).firstOrNull;
    return _TimelineEditState(
      scenesOf(projectId),
      Map.of(_layerHomes[projectId] ?? const {}),
      project,
    );
  }

  void _restoreTimeline(
    String projectId,
    _TimelineEditState state,
    Map<String, Map<String, Uint8List>?> tiles,
  ) {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index < 0) return;
    _scenes[projectId] = List.of(state.scenes);
    _layerHomes[projectId] = Map.of(state.homes);
    _tilesOf(projectId)?.restoreStructuralLayers(tiles);
    final snapshot = state.project;
    if (snapshot != null) {
      _projects[index] = _projects[index].copyWith(
        name: snapshot.name,
        fps: snapshot.fps,
        durationSeconds: snapshot.durationSeconds,
        hideEndCard: snapshot.hideEndCard,
        backgroundColor: snapshot.backgroundColor,
        exportWidth: snapshot.exportWidth,
        exportHeight: snapshot.exportHeight,
        drawingAreaScale: snapshot.drawingAreaScale,
        enabledAutofillPresetIds: snapshot.enabledAutofillPresetIds,
        tags: snapshot.tags,
      );
    }
    _syncDurationToFrameCount(projectId);
    _saveAsync(projectId);
    notifyListeners();
  }

  /// Groups a serialized automation's existing Undo actions without changing
  /// the pixel lifetime or the behavior of standalone layer operations.
  Future<T> runWithGroupedUndo<T>({
    required String description,
    required Future<T> Function() operation,
  }) async {
    final undo = _undoManager;
    if (undo == null) return operation();
    final outermost = _layersAddedInGroup == null;
    _layersAddedInGroup ??= <String>{};
    try {
      return await _runGroupedUndo(undo, description, operation);
    } finally {
      if (outermost) _layersAddedInGroup = null;
    }
  }

  /// Layers (as `projectId/layerId`) created while a grouped Undo is being
  /// recorded. Their whole existence is undone and redone by their add
  /// action, which keeps the pixels they ended with, so in-place changes to
  /// them are not recorded separately: replaying those partial tile
  /// snapshots on Redo would overwrite what later steps (a merge) left.
  Set<String>? _layersAddedInGroup;

  Future<T> _runGroupedUndo<T>(
    UndoManager undo,
    String description,
    Future<T> Function() operation,
  ) {
    return undo.runGrouped(
      description: description,
      operation: operation,
      shouldUndoAction: (action) {
        if (action is! LayerAddUndoAction) return true;
        // Merges may consume a layer added earlier in the same automation.
        // Its add action has no remaining inverse and must not enter Redo.
        return layersOf(
          action.projectId,
          action.sceneId,
          action.frameIndex,
        ).any((layer) => layer.id == action.layerId);
      },
    );
  }

  List<Project> get projects => List.unmodifiable(_projects);
  List<Project> get trash => List.unmodifiable(_trash);
  // 「共有」タブ：_projects内の.niashareインポート由来プロジェクトのみを
  // 絞り込んだビュー（独立リストではなく_projectsが唯一のデータソース。
  // こうすることでキャンバス・タイムライン・書き出し等の既存のID検索
  // （projects.where((p) => p.id == ...)）がそのまま共有プロジェクトにも
  // 効く）。
  List<Project> get shared =>
      List.unmodifiable(_projects.where((p) => p.isSharedImport));

  final List<SavedOutgoingShare> _outgoingShares = [];
  List<SavedOutgoingShare> get outgoingShares =>
      List.unmodifiable(_outgoingShares);

  static const _outgoingFavoritePrefsKey = 'niarim_outgoing_share_favorites';
  final Set<String> _outgoingFavoritePaths = {};
  bool isOutgoingShareFavorite(String path) =>
      _outgoingFavoritePaths.contains(path);

  Future<void> toggleOutgoingShareFavorite(String path) async {
    final wasFavorite = _outgoingFavoritePaths.contains(path);
    if (wasFavorite) {
      _outgoingFavoritePaths.remove(path);
    } else {
      _outgoingFavoritePaths.add(path);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = await prefs.setStringList(
        _outgoingFavoritePrefsKey,
        _outgoingFavoritePaths.toList()..sort(),
      );
      if (!persisted) {
        throw StateError('Could not save outgoing favorite state');
      }
    } catch (error, stackTrace) {
      if (wasFavorite) {
        _outgoingFavoritePaths.add(path);
      } else {
        _outgoingFavoritePaths.remove(path);
      }
      notifyListeners();
      AppErrorReporter.record(error, stackTrace);
      rethrow;
    }
  }

  /// 作成した共有ファイル[path]の名前を変えて[newPath]にする。お気に入りは
  /// ファイルの場所で覚えているので、新しい場所へ移して保存する（移さないと
  /// 名前を変えただけでお気に入りが外れ、保存した設定に古い場所が残った）。
  /// お気に入りを保存できなければ名前を元に戻して投げる。
  Future<void> renameOutgoingShare(String path, String newPath) async {
    await File(path).rename(newPath);
    if (_outgoingFavoritePaths.remove(path)) {
      _outgoingFavoritePaths.add(newPath);
      try {
        final prefs = await SharedPreferences.getInstance();
        final persisted = await prefs.setStringList(
          _outgoingFavoritePrefsKey,
          _outgoingFavoritePaths.toList()..sort(),
        );
        if (!persisted) {
          throw StateError('Could not save outgoing favorite state');
        }
      } catch (_) {
        _outgoingFavoritePaths
          ..remove(newPath)
          ..add(path);
        try {
          await File(newPath).rename(path);
        } catch (error, stackTrace) {
          AppErrorReporter.record(error, stackTrace);
        }
        await refreshOutgoingShares();
        rethrow;
      }
    }
    await refreshOutgoingShares();
  }

  /// 前回の[refreshOutgoingShares]で、作成した共有ファイルの置き場所（の
  /// どれか）を読めなかったか。読めなかったときは、一覧が空でも「まだ
  /// ありません」と言わず、読めなかったことを知らせる。
  bool get outgoingSharesLoadFailed => _outgoingSharesLoadFailed;
  bool _outgoingSharesLoadFailed = false;

  Future<void> refreshOutgoingShares() async {
    var unreadable = false;
    try {
      final current = await OutgoingShareLibrary.list(
        onUnreadable: () => unreadable = true,
      );
      _outgoingShares
        ..clear()
        ..addAll(current);
      _outgoingSharesLoadFailed = unreadable;
      notifyListeners();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      _outgoingSharesLoadFailed = true;
      notifyListeners();
    }
  }

  /// Make a reusable, immutable outgoing archive, rather than recreating a
  /// .niashare each time the OS share sheet is opened.
  Future<File> createOutgoingShare({
    required Project project,
    Map<String, Uint8List>? materialFiles,
    String? materialsManifest,
    String? fontsManifest,
  }) async {
    final archive = await OutgoingShareLibrary.save(
      project: project,
      scenes: scenesOf(project.id),
      tileManager: tileManagerOf(project.id),
      materialFiles: materialFiles,
      materialsManifest: materialsManifest,
      fontsManifest: fontsManifest,
    );
    StorageInfoService().invalidate();
    await refreshOutgoingShares();
    return archive;
  }

  List<ProjectFolder> get folders => List.unmodifiable(_folders);

  /// ゴミ箱へ移したフォルダ（中身ごと）。
  List<TrashedFolder> get trashedFolders => List.unmodifiable(_trashedFolders);

  /// フォルダと一緒にゴミ箱へ移した作品なら、そのフォルダ。
  TrashedFolder? trashedFolderOf(String projectId) => _trashedFolders
      .where((t) => t.projectIds.contains(projectId))
      .firstOrNull;

  /// ゴミ箱の作品のうち、フォルダと一緒に移したもの以外（ゴミ箱の一覧に
  /// 1件ずつ出す作品）。
  List<Project> get looseTrash =>
      List.unmodifiable(_trash.where((p) => trashedFolderOf(p.id) == null));
  List<Project> get favorites => _projects.where((p) => p.isFavorite).toList();

  /// プロジェクトがゴミ箱へ移動された日時（ゴミ箱一覧の削除日時表示用）
  DateTime? deletedAtOf(String projectId) => _trashDeletedAt[projectId];

  /// 保存先のプロジェクトを読み込めなかったか（保存先が開けない・一覧を
  /// 読めない・作品のフォルダや保存に入れない）。
  /// 自動保存からも復旧できない破損がある場合も真。
  bool get projectsLoadFailed => _projectsLoadFailed;
  bool _projectsLoadFailed = false;

  /// 保存先の中を一覧できなかった（どの作品があるかも分からない）か。
  /// [projectsLoadFailed]は、一覧できて一部の作品だけ読めなかったときも真。
  bool _projectsListingFailed = false;

  /// 保存先にあるのに読めていない作品（フォルダに入れない・保存を
  /// 開けない）。保存先を一覧できたときの分。
  final Set<String> _unreadProjectIds = {};

  /// 読めていない作品のうち、ゴミ箱の外にあるかもしれないものがあるか
  /// （保存先を一覧できなかったときは、どれが読めていないか分からないので
  /// 真）。フォルダをゴミ箱へ移すとき、そういう作品はそのフォルダの中の
  /// 作品かもしれない（読めたときにゴミ箱のフォルダへ入る）。読めていない
  /// 作品がゴミ箱の中の作品（1件ずつ移した作品・ゴミ箱のフォルダの作品）
  /// だけのときは、移すフォルダとは関係が無いので偽。
  bool get mayHoldUnreadWorksOutsideTrash =>
      _projectsListingFailed ||
      _unreadProjectIds.any((id) => !_trashDeletedAt.containsKey(id));

  Future<void> init() async {
    try {
      await _loadTrashState();
      await _loadFolders();
      await _loadSharedFolders();
      // Folder Trash pruning must see both source collections first.
      await _loadTrashedFolders();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
    await _loadProjectsFromDisk();
    try {
      final prefs = await SharedPreferences.getInstance();
      _outgoingFavoritePaths
        ..clear()
        ..addAll(prefs.readStringList(_outgoingFavoritePrefsKey) ?? const []);
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
    await refreshOutgoingShares();
  }

  /// プロジェクトを読み込めなかったとき（[projectsLoadFailed]）に、保存先を
  /// 読み直す。読み込み済み・ゴミ箱の作品は二重にしない。読み直しの途中で
  /// もう一度呼ばれたら、同じ読み直しを待つ（2つが並んで走ると、どちらも
  /// まだ読んでいない作品として同じ作品を一覧へ足した）。読めたら
  /// [onProjectsReloaded]も待つ。
  Future<void> retryLoadProjects() =>
      _retryingLoad ??= _retryLoad().whenComplete(() => _retryingLoad = null);
  Future<void>? _retryingLoad;

  /// [retryLoadProjects]で保存先を読めたときに呼ぶ処理。同じ保存先から読む
  /// もの（作品ごとの手動の保存の一覧）を、読み直した作品の分まで読む
  /// （起動時に読めなかった分は、ここで読まないと次に起動するまで出ない）。
  Future<void> Function()? onProjectsReloaded;

  Future<void> _retryLoad() async {
    final listed = await _loadProjectsFromDisk();
    final reload = onProjectsReloaded;
    // 入れない作品が残っていても（[projectsLoadFailed]のまま）、読めた
    // 作品の分は読む。
    if (!listed || reload == null) return;
    try {
      await reload();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
  }

  /// 保存先の作品を読み込む。保存先の中を一覧できたら（保存先が無い
  /// ときも）true。
  Future<bool> _loadProjectsFromDisk() async {
    var listed = false;
    try {
      final basePath = await NiaproSerializer.projectsBasePath();
      final baseDir = Directory(basePath);
      if (!baseDir.existsSync()) {
        // existsSyncは、上のフォルダ（書類フォルダ/niarim等）に入れない
        // ときもfalse。無いと分かったときだけ「作品が無い」とする
        // （入れないときはlistSyncが投げ、下のcatchで受ける）。
        try {
          baseDir.listSync();
        } on PathNotFoundException {
          _projectsLoadFailed = false;
          _projectsListingFailed = false;
          _unreadProjectIds.clear();
          notifyListeners();
          return true;
        }
      }
      final cleanup = await ProjectTrashGuard.pending(basePath);
      for (final guard in cleanup) {
        _trashDeletedAt.putIfAbsent(guard.project.id, () => guard.deletedAt);
      }
      final existingDirectories = <String>{};
      // 読み直し（[retryLoadProjects]）では、読み込み済み・ゴミ箱の作品を
      // 二重にしない。
      final known = {
        for (final p in [..._projects, ..._trash]) p.id,
      };
      final folders = baseDir.listSync().whereType<Directory>().toList();
      listed = true;
      // 入れない作品や復旧できなかった作品には知らせと「再試行」を残す。
      final unread = <String>{};
      final read = <(Project, NiaproData)>[];
      var hasUnrecoveredArchive = false;
      for (final dir in folders) {
        final projectId = dir.path.split(RegExp(r'[\\/]')).last;
        existingDirectories.add(projectId);
        if (known.contains(projectId)) continue;
        final niaproFile = File('${dir.path}/$projectId.niapro');
        NiaproData? data;
        int? sizeBytes;
        DateTime? recoveredAt;
        var damaged = false;
        try {
          // The pictures stay in the file until the work is opened.
          final loaded = await NiaproSerializer.load(
            niaproFile.path,
            withTiles: false,
          );
          if (loaded.project.id != projectId || !loaded.hasEditableFrames) {
            throw const FormatException(
              'Project archive ID or scene data is invalid',
            );
          }
          // 容量（Manifest「容量」）は実ファイルサイズから都度算出する
          // （保存済みの数値をそのまま信用すると、外部要因での差分等でズレうるため）。
          sizeBytes = niaproFile.lengthSync();
          data = loaded;
        } on PathNotFoundException {
          // 作業フォルダだけが残った場合も、有効な自動保存があれば復旧する。
        } on FileSystemException catch (error, stackTrace) {
          // 開けない・読めない（ファイルの権限が無い・入出力の失敗）。
          AppErrorReporter.record(error, stackTrace);
          unread.add(projectId);
        } catch (error, stackTrace) {
          AppErrorReporter.record(error, stackTrace);
          damaged = true;
        }
        if (data == null &&
            !unread.contains(projectId) &&
            !cleanup.any((guard) => guard.project.id == projectId)) {
          final backup = await _autosaves?.latestReadable(projectId);
          if (backup != null &&
              backup.data.project.id == projectId &&
              backup.data.hasEditableFrames) {
            data = backup.data;
            recoveredAt = backup.savedAt;
            sizeBytes = await _rewriteRecoveredArchive(data, recoveredAt);
            _recoveredFromAutosave.add(projectId);
          }
        }
        if (data == null) {
          if (damaged && !_trashDeletedAt.containsKey(projectId)) {
            hasUnrecoveredArchive = true;
          }
          continue;
        }
        final project = data.project.copyWith(
          sizeBytes: sizeBytes,
          updatedAt: recoveredAt,
        );
        if (_trashDeletedAt.containsKey(projectId)) {
          _trash.add(project);
        } else {
          read.add((project, data));
        }
      }
      // フォルダの列の中で決める：読んでいる間にフォルダがゴミ箱へ移ると、
      // フォルダがあると見て一覧へ出した作品が、移したフォルダの記録にも
      // 入らず、一番上に出た（次の起動ではゴミ箱へ入った）。読めていない
      // 作品の覚えも列の中で書き換え、後から移すフォルダが今の分を記録する。
      await _queueFolder(() async {
        _projectsLoadFailed = unread.isNotEmpty || hasUnrecoveredArchive;
        _projectsListingFailed = false;
        _unreadProjectIds
          ..clear()
          ..addAll(unread);
        final present = {
          for (final p in [..._projects, ..._trash]) p.id,
        };
        final lateMembers = <(Project, NiaproData)>[];
        for (final (project, data) in read) {
          if (!present.add(project.id)) continue;
          if (_joinsTrashedFolder(project)) {
            // ゴミ箱へ移したフォルダの中の作品で、移したときには読めて
            // いなかったもの。そのフォルダへ入れる。
            lateMembers.add((project, data));
          } else {
            _listLoadedProject(project, data);
          }
        }
        await _joinTrashedFolders(lateMembers, unread);
      });
      for (final guard in cleanup) {
        existingDirectories.add(guard.project.id);
        if (!_trash.any((p) => p.id == guard.project.id) &&
            !_projects.any((p) => p.id == guard.project.id)) {
          // Even if the archive was among the files removed before a failure,
          // keep the remaining directory identifiable and retryable in Trash.
          _trash.add(guard.project);
        }
      }
      final beforePrune = _trashDeletedAt.length;
      _trashDeletedAt.removeWhere((id, _) => !existingDirectories.contains(id));
      if (_trashDeletedAt.length != beforePrune) {
        try {
          await _persistTrashState(_trashDeletedAt);
        } catch (error, stackTrace) {
          // Content already gone: retry stale preference cleanup next time.
          AppErrorReporter.record(error, stackTrace);
        }
      }
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      // 保存先を開けないときは読み込めた分（無ければ空）で続け、ホームで
      // 読み込めなかったことを知らせて読み直せるようにする（黙って空に
      // すると、作品が消えたように見えた）。
      _projectsLoadFailed = true;
      _projectsListingFailed = true;
    }
    notifyListeners();
    return listed;
  }

  /// Rebuild the full archive without copying entries from the damaged one.
  Future<int?> _rewriteRecoveredArchive(
    NiaproData data,
    DateTime savedAt,
  ) async {
    final project = data.project;
    final tiles = TileManager(
      canvasWidth: project.drawingWidth,
      canvasHeight: project.drawingHeight,
      compositeCacheMax: _tileCacheBudget,
    );
    try {
      tiles.importAll(data.tileData);
      final file = await NiaproSerializer.save(
        project: project,
        scenes: data.scenes,
        tileManager: tiles,
        updatedAt: savedAt,
        rewrite: true,
      );
      return file.lengthSync();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      // The user can still open the recovered work if the storage is read-only.
      _needsArchiveRewrite.add(project.id);
      return null;
    } finally {
      tiles.dispose();
    }
  }

  // ─── ゴミ箱の状態永続化（ゴミ箱・自動削除設定） ─────────────────────────
  // ゴミ箱移動日時をSharedPreferencesへ保存し、起動時にどのプロジェクトが
  // ゴミ箱内かを復元する。

  static const _trashPrefsKey = 'trashed_projects';

  Future<void> _loadTrashState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.readStringList(_trashPrefsKey) ?? [];
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

  Future<void> _persistTrashState(Map<String, DateTime> next) async {
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.get(_trashPrefsKey);
    Future<bool> restoreCache() => switch (before) {
      null => prefs.remove(_trashPrefsKey),
      String v => prefs.setString(_trashPrefsKey, v),
      bool v => prefs.setBool(_trashPrefsKey, v),
      int v => prefs.setInt(_trashPrefsKey, v),
      double v => prefs.setDouble(_trashPrefsKey, v),
      List<Object?> v when v.every((item) => item is String) =>
        prefs.setStringList(_trashPrefsKey, v.cast<String>()),
      _ => throw StateError('Unsupported trash preference value'),
    };
    try {
      final list = next.entries
          .map((e) => '${e.key}|${e.value.toIso8601String()}')
          .toList();
      // Always write, including permanent-delete preflight of the same value.
      if (!await prefs.setStringList(_trashPrefsKey, list)) {
        throw StateError('Trash preference write rejected');
      }
    } catch (_) {
      try {
        await restoreCache();
      } catch (_) {
        // SharedPreferences restores its cache before the platform write.
      }
      rethrow;
    }
  }

  /// ゴミ箱の自動削除設定（設定画面で選んだ日数）に従い、保持期限を過ぎた
  /// プロジェクトを完全削除する。days<=0（OFF）の場合は何もしない。
  /// 保存先の中を一覧できなかったときも何もしない：ゴミ箱の作品を
  /// 読めていないので、フォルダの記録だけを消して中の作品を残す等、
  /// 読めていないものを書き換えてしまう（片付けは次に読めたときに行う）。
  /// 一覧できて一部の作品だけ読めなかったとき（[projectsLoadFailed]は真）は、
  /// 読めた作品はこれまでどおり片付け、読めていない作品を含むフォルダだけを
  /// 中の読めた作品ごと残す（開けない作品が1つあるだけで、関係のない
  /// 期限切れの作品がいつまでも消えなかった）。
  Future<void> sweepExpiredTrash(int days) async {
    if (days <= 0 || _projectsListingFailed) return;
    final now = DateTime.now();
    final heldBack = _trashedFolders
        .where(trashedFolderHasUnreadWorks)
        .toList();
    // フォルダは中の作品ごと消す。
    final expiredFolders = [
      for (final t in _trashedFolders)
        if (now.difference(t.deletedAt).inDays >= days && !heldBack.contains(t))
          t.folder.id,
    ];
    for (final id in expiredFolders) {
      try {
        await permanentDeleteTrashedFolder(id);
      } catch (_) {
        // 起動を止めない。フォルダの作品はゴミ箱に残り、後で消し直せる。
      }
    }
    final expired = _trash
        .where((p) {
          if (heldBack.any((t) => t.projectIds.contains(p.id))) return false;
          final deletedAt = _trashDeletedAt[p.id];
          if (deletedAt == null) return false;
          return now.difference(deletedAt).inDays >= days;
        })
        .map((p) => p.id)
        .toList();
    for (final id in expired) {
      try {
        await permanentDelete(id);
      } catch (_) {
        // Automatic cleanup must not prevent startup. The target remains in Trash
        // and the operation records its failure for a later/manual retry.
      }
    }
  }

  /// [project]が入っているフォルダが、ゴミ箱へ移したフォルダ（中の
  /// フォルダを含む）なら、その記録。フォルダが一覧に戻っていれば null。
  TrashedFolder? _trashedFolderHolding(Project project) {
    final shared = project.isSharedImport;
    final folderId = shared ? project.sharedFolderId : project.folderId;
    if (folderId == null) return null;
    if ((shared ? _sharedFolders : _folders).any((f) => f.id == folderId)) {
      return null;
    }
    return _trashedFolders
        .where(
          (t) =>
              t.isShared == shared &&
              (t.folder.id == folderId ||
                  t.subfolders.any((f) => f.id == folderId)),
        )
        .firstOrNull;
  }

  /// 読んだ作品が、ゴミ箱へ移したフォルダへ入る作品か：入っていたフォルダが
  /// ゴミ箱のフォルダの記録（中のフォルダを含む）にあり、フォルダを移した
  /// ときに読めていなかった作品。移したときに読めていた作品と、移した後に
  /// 保存した作品（引き継ぎ・受け取った作品を開き直したもの・その複製・
  /// 古い手動の保存を読み込んだもの）は、フォルダを指していても入れない
  /// （入れると、ゴミ箱で見たことの無い作品が、フォルダの期限で消えた）。
  bool _joinsTrashedFolder(Project project) {
    final record = _trashedFolderHolding(project);
    if (record == null) return false;
    if (record.unreadProjectIds.contains(project.id)) return true;
    // 一覧できなかったときは、どれが読めていなかったか分からない。作品の
    // 保存の日時（保存のたびに書く）で、移した後に保存していないものだけ。
    return record.unreadUnlisted &&
        !project.updatedAt.isAfter(record.deletedAt);
  }

  /// 読んだ作品を一覧へ出す。
  void _listLoadedProject(Project project, NiaproData data) {
    _projects.add(project);
    try {
      _applyLoadedProjectData(data);
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
  }

  /// フォルダをゴミ箱へ移したときに読めていなかった中の作品（[members]、
  /// 読めた作品とその中身）を、読めたときに、そのフォルダの記録とゴミ箱へ
  /// フォルダを移した日時のまま入れる（入れないと、フォルダの外＝
  /// プロジェクトの一番上に出て、フォルダごと戻しても戻らなかった）。
  /// フォルダの列の中で呼ぶ。お気に入りの作品はゴミ箱へ入れず（フォルダ
  /// ごとでもゴミ箱へ移さない決まり）、一番上へ出す。記録を保存できな
  /// ければ、これまでどおり一覧へ出す（次の起動でもう一度入れる）。
  /// あわせて、記録の「読めていなかった作品」を、まだ読めていない作品
  /// （[unread]）だけに絞る（保存先を一覧できたときに呼ぶ）。
  Future<void> _joinTrashedFolders(
    List<(Project, NiaproData)> members,
    Set<String> unread,
  ) async {
    final joining = <String, String>{};
    final records = [
      for (final t in _trashedFolders)
        t.unreadUnlisted || t.unreadProjectIds.isNotEmpty
            ? t.copyWith(
                unreadProjectIds: [
                  for (final id
                      in t.unreadUnlisted ? unread : t.unreadProjectIds)
                    if (unread.contains(id)) id,
                ],
                unreadUnlisted: false,
              )
            : t,
    ];
    var changed = false;
    for (var i = 0; i < records.length; i++) {
      final before = _trashedFolders[i];
      changed =
          changed ||
          before.unreadUnlisted != records[i].unreadUnlisted ||
          before.unreadProjectIds.length != records[i].unreadProjectIds.length;
    }
    final nextTrash = {..._trashDeletedAt};
    for (final (project, _) in members) {
      final record = _trashedFolderHolding(project);
      if (record == null || project.isFavorite) continue;
      final i = records.indexWhere((t) => t.folder.id == record.folder.id);
      final current = records[i];
      if (!current.projectIds.contains(project.id)) {
        records[i] = current.copyWith(
          projectIds: [...current.projectIds, project.id],
        );
      }
      nextTrash[project.id] = current.deletedAt;
      joining[project.id] = current.folder.id;
    }
    var joined = false;
    if (joining.isNotEmpty || changed) {
      try {
        await saveFolderPreference(
          _trashedFoldersPrefsKey,
          _encodeTrashedFolders(records),
        );
        try {
          if (joining.isNotEmpty) await _persistTrashState(nextTrash);
          joined = true;
        } catch (_) {
          try {
            await saveFolderPreference(
              _trashedFoldersPrefsKey,
              _encodeTrashedFolders(_trashedFolders),
            );
          } catch (_) {
            // 残った記録は、次の起動で作品を読んだときに合わせ直す。
          }
          rethrow;
        }
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
      }
    }
    if (joined) {
      _trashedFolders
        ..clear()
        ..addAll(records);
      _trashDeletedAt
        ..clear()
        ..addAll(nextTrash);
    }
    for (final (project, data) in members) {
      if (joined && joining.containsKey(project.id)) {
        _trash.add(project);
        continue;
      }
      // ゴミ箱のフォルダに入れないお気に入りの作品は、一番上へ出す
      // （消えたフォルダを指したままにしない）。作品の保存にも書く：書く
      // 処理は、一覧に出した作品を探して書くので、一覧へ出してから。
      final rerooted =
          project.isFavorite && _trashedFolderHolding(project) != null;
      final shared = project.isSharedImport;
      _listLoadedProject(
        !rerooted
            ? project
            : shared
            ? project.copyWith(sharedFolderId: null)
            : project.copyWith(folderId: null),
        data,
      );
      if (rerooted) {
        unawaited(
          _saveMembership(project.id, null, shared: shared).catchError(
            (Object error, StackTrace stackTrace) =>
                AppErrorReporter.record(error, stackTrace),
          ),
        );
      }
    }
  }

  /// ゴミ箱のフォルダの記録に、保存先にあるのに読めていない作品が
  /// 含まれるか（保存先を一覧できなかったときは、読み込んでいない作品を
  /// すべて読めていないものとして数える）。含むフォルダの記録を消すと、
  /// 中の作品は読めた後にフォルダではなくゴミ箱の1件ずつの行に出るので、
  /// 読めるまで、完全に削除する・期限で片付けることをしない（戻すことは
  /// できる。[restoreTrashedFolder]）。
  ///
  /// フォルダをゴミ箱へ移したときに読めていなかった作品（記録の
  /// [TrashedFolder.unreadProjectIds]・[TrashedFolder.unreadUnlisted]）が
  /// まだ読めていないときも同じ：読めたときにこのフォルダへ入るかもしれない
  /// （[_joinsTrashedFolder]）。消すと、読めた作品だけが完全に削除され、
  /// 後で読めた作品はフォルダの外（一番上）に1つだけ出た。
  bool trashedFolderHasUnreadWorks(TrashedFolder record) =>
      _unreadWorksOf(record).isNotEmpty || _mayGainUnreadWorks(record);

  /// [record]を移したときに読めていなかった作品が、読めたときにこのフォルダへ
  /// 入るかもしれないか（[trashedFolderHasUnreadWorks]の一部）。その間は、
  /// 記録の作品の件数（移したときに読めた作品だけ）が中身の数にならない。
  bool trashedFolderMayGainWorks(TrashedFolder record) =>
      _mayGainUnreadWorks(record);

  /// [record]を移したときに読めていなかった作品のうち、まだ読めていなくて、
  /// 読めたときにこのフォルダへ入りうるもの（1件ずつゴミ箱へ移した作品・
  /// 別のフォルダの記録へ入った作品は入らない）があるか。
  bool _mayGainUnreadWorks(TrashedFolder record) {
    bool joinable(String id) =>
        !record.projectIds.contains(id) && !_trashDeletedAt.containsKey(id);
    if (_projectsListingFailed) {
      if (record.unreadUnlisted) return true;
      final loaded = {
        for (final p in [..._projects, ..._trash]) p.id,
      };
      return record.unreadProjectIds.any(
        (id) => joinable(id) && !loaded.contains(id),
      );
    }
    // 一覧できなかったときの記録で、まだ読めていない作品のどれが入るかは
    // 読むまで分からない（読めた分の記録への書き込みに失敗して残った印）。
    if (record.unreadUnlisted) return _unreadProjectIds.any(joinable);
    return record.unreadProjectIds.any(
      (id) => joinable(id) && _unreadProjectIds.contains(id),
    );
  }

  /// [record]の作品のうち、読めていないもの（[trashedFolderHasUnreadWorks]）。
  List<String> _unreadWorksOf(TrashedFolder record) {
    if (!_projectsListingFailed) {
      return record.projectIds.where(_unreadProjectIds.contains).toList();
    }
    final loaded = {
      for (final p in [..._projects, ..._trash]) p.id,
    };
    return record.projectIds.where((id) => !loaded.contains(id)).toList();
  }

  /// ディスクから読み込んだプロジェクトデータをメモリ上のマップへ反映する。
  /// init()（起動時の全件読み込み）とrestoreProject()（ゴミ箱からの復元時の
  /// 再読み込み）で共通利用する。
  void _applyLoadedProjectData(NiaproData data) {
    final projectId = data.project.id;
    _scenes[projectId] = data.scenes;
    _layerHomes[projectId] = buildLayerHomeIndex(data.scenes);
    final tm = TileManager(
      canvasWidth: data.project.drawingWidth,
      canvasHeight: data.project.drawingHeight,
      compositeCacheMax: _tileCacheBudget,
    );
    tm.importAll(data.tileData);
    _tileManagers[projectId] = tm;
    _forgetTiles(projectId);
    final leftIn = data.tilesLeftIn;
    if (leftIn != null) _tilesLeftInFile[projectId] = leftIn;
    _layerIdCounters[projectId] = _maxLayerCounter(data.scenes);
  }

  int _maxLayerCounter(List<Scene> scenes) {
    int max = 1;
    for (final scene in scenes) {
      for (final frame in scene.frames) {
        for (final layer in frame.layers) {
          final num =
              int.tryParse(layer.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (num >= max) max = num + 1;
        }
      }
    }
    return max;
  }

  /// materialIdがプロジェクト内のどこかで参照されているか判定する。
  /// タイムライン画像・動画レイヤーのmaterialId、および各シーンの
  /// 音声クリップのmaterialIdを対象に走査する。
  bool isMaterialUsed(String projectId, String materialId) {
    if (_undoManager?.retainsMaterial(projectId, materialId) ?? false) {
      return true;
    }
    return _materialIdsIn(scenesOf(projectId)).contains(materialId);
  }

  Iterable<String> _materialIdsIn(Iterable<Scene> scenes) sync* {
    for (final scene in scenes) {
      for (final clip in scene.audioClips) {
        if (clip.materialId case final id?) yield id;
      }
      for (final frame in scene.frames) {
        for (final layer in frame.layers) {
          if (layer.materialId case final id?) yield id;
        }
      }
    }
  }

  // ─── 制作時間カウント（描画モード・タイムラインモードのみカウント、
  // 一定時間無操作でカウント停止・操作再開でカウント再開） ────────────────
  // 秒単位の細かい精度ではなく、一定間隔（tick）ごとに直近の操作有無を
  // 見て加算するかどうかを決める簡易実装。低スペック端末での負荷を
  // 抑えるためnotifyListeners()もtick間隔でのみ発生する。

  Timer? _workTimer;
  String? _trackedProjectId;
  Stopwatch? _workStopwatch;
  int _workLastActivityMs = 0;
  int _workLastSettledMs = 0;
  int _workFractionMs = 0;
  int _workSessionSeconds = 0;
  int _workTrackingLease = 0;
  bool _workPaused = false;

  CreatorEditSessionReporter? _creatorEditReporter;

  /// The optional pilot sends only bounded counters, never image or stroke
  /// data. Local work-time tracking works identically with no backend.
  void attachCreatorEditReporter(CreatorEditSessionReporter? reporter) {
    _creatorEditReporter = reporter;
  }

  static const _workTickInterval = Duration(seconds: 10);
  static const _workInactivityThreshold = Duration(minutes: 1);

  /// Each route receives a distinct lease. A canvas disposed AFTER the
  /// timeline opened must not stop the new route's counter.
  int beginWorkTracking(String projectId) {
    if (_trackedProjectId != null) endWorkTracking();
    final lease = ++_workTrackingLease;
    _trackedProjectId = projectId;
    _workStopwatch = Stopwatch()..start();
    _workLastActivityMs = 0;
    _workLastSettledMs = 0;
    _workSessionSeconds = 0;
    _workFractionMs = 0;
    _workPaused = false;
    _workTimer?.cancel();
    _workTimer = Timer.periodic(_workTickInterval, (_) => _settleWorkTime());
    _autosaves?.attach(this, projectId, undoManager: _undoManager);
    _creatorEditReporter?.begin(
      projectId: projectId,
      activeSeconds: () => currentWorkSessionSeconds,
    );
    return lease;
  }

  /// The rewarded candidate count uses confirmed content edits, not pointer
  /// taps or video/timeline scrubbing. Call only after a real change.
  void recordConfirmedEdit(String projectId) {
    if (projectId != _trackedProjectId || _workPaused) return;
    pingWorkActivity();
    _creatorEditReporter?.recordCommittedMutation(
      projectId,
      activeSeconds: () => currentWorkSessionSeconds,
    );
  }

  /// Ordinary UI activity keeps the existing local display counter active.
  /// It never counts as a confirmed mutation for coin eligibility.
  void pingWorkActivity() {
    final clock = _workStopwatch;
    if (clock == null || _workPaused) return;
    final now = clock.elapsedMilliseconds;
    if (now - _workLastActivityMs > _workInactivityThreshold.inMilliseconds) {
      _settleWorkTime();
      _workLastSettledMs = now; // do not count the idle gap retroactively
    }
    _workLastActivityMs = now;
    final id = _trackedProjectId;
    if (id != null) {
      _creatorEditReporter?.noteInteraction(
        projectId: id,
        activeSeconds: () => currentWorkSessionSeconds,
      );
    }
  }

  /// Supports sub-15-minute sessions. The 10-second timer limits UI rebuilds
  /// only; exit and app background settle *actual elapsed milliseconds*.
  int get currentWorkSessionSeconds {
    _settleWorkTime();
    return _workSessionSeconds;
  }

  void _settleWorkTime() {
    final id = _trackedProjectId;
    final clock = _workStopwatch;
    if (id == null || clock == null || _workPaused) return;
    final now = clock.elapsedMilliseconds;
    final activeEnd =
        now < _workLastActivityMs + _workInactivityThreshold.inMilliseconds
        ? now
        : _workLastActivityMs + _workInactivityThreshold.inMilliseconds;
    final delta = activeEnd - _workLastSettledMs;
    if (delta <= 0) return;
    _workLastSettledMs = activeEnd;
    final allMs = _workFractionMs + delta;
    final seconds = allMs ~/ 1000;
    _workFractionMs = allMs % 1000;
    if (seconds == 0) return;
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _workSessionSeconds += seconds;
    _projects[idx] = _projects[idx].copyWith(
      totalWorkSeconds: _projects[idx].totalWorkSeconds + seconds,
    );
    _notifyOutsideBuild();
  }

  /// 制作時間は画面を開く処理（initState・dispose）からも締められる
  /// （キャンバスからタイムラインへ移ると、タイムラインのinitStateが
  /// キャンバスの分を締める）。組み立ての最中に知らせると、聞いている
  /// 画面の作り直しが「組み立て中のsetState」の例外になるので、その時は
  /// フレームの後へ回す。
  void _notifyOutsideBuild() {
    SchedulerPhase? phase;
    try {
      phase = SchedulerBinding.instance.schedulerPhase;
    } catch (_) {
      phase = null; // バインディングの無い単体テスト
    }
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }
    notifyListeners();
  }

  /// Explicit user saves, NOT autosaves, trigger a separate lightweight
  /// editing-time checkpoint after the project has been saved successfully.
  /// A network failure never rolls back or blocks the local save.
  void onManualSaveCommitted(String projectId) {
    if (projectId != _trackedProjectId || _workPaused) return;
    _settleWorkTime();
    _creatorEditReporter?.manualSaveSucceeded(projectId);
  }

  /// For the desktop File > Save action. Internal saveProject() callers
  /// (autosave, navigation, folder updates) intentionally do not report.
  Future<void> saveProjectManually(String projectId) async {
    _settleWorkTime();
    await saveProject(projectId);
    await _checkpointAutosave(projectId);
    try {
      onManualSaveCommitted(projectId);
    } catch (error) {
      // The file is saved. Reporting time is independent and optional.
      debugPrint('Manual-save editing-time checkpoint skipped: $error');
    }
  }

  /// Android background time does not count. Keep the editor's tracking
  /// lease alive and reopen a short server session only upon resume.
  void pauseWorkTracking() {
    if (_trackedProjectId == null || _workPaused) return;
    _settleWorkTime();
    _workPaused = true;
    _workStopwatch?.stop();
    _workTimer?.cancel();
    _workTimer = null;
    _creatorEditReporter?.end();
    final id = _trackedProjectId;
    if (id != null) {
      _autosaves?.detach();
      unawaited(_checkpointAutosave(id));
      _saveAsync(id);
    }
  }

  void resumeWorkTracking() {
    if (_trackedProjectId == null || !_workPaused) return;
    _workPaused = false;
    _workStopwatch?.start();
    _workLastSettledMs = _workStopwatch!.elapsedMilliseconds;
    _workLastActivityMs = _workLastSettledMs;
    _autosaves?.attach(this, _trackedProjectId!, undoManager: _undoManager);
    _workTimer?.cancel();
    _workTimer = Timer.periodic(_workTickInterval, (_) => _settleWorkTime());
    _creatorEditReporter?.begin(
      projectId: _trackedProjectId!,
      activeSeconds: () => currentWorkSessionSeconds,
    );
  }

  /// Exit can occur after another route has already acquired the counter.
  void endWorkTracking({int? lease}) {
    if (lease != null && lease != _workTrackingLease) return;
    final id = _trackedProjectId;
    if (id == null) return;
    _settleWorkTime();
    _workTimer?.cancel();
    _workTimer = null;
    _workStopwatch?.stop();
    _workStopwatch = null;
    _trackedProjectId = null;
    _workPaused = false;
    _autosaves?.detach();
    unawaited(_checkpointAutosave(id));
    _creatorEditReporter?.end();
    // Persist even a 1-9 second session; no reliance on the next 10s tick.
    _saveAsync(id);
  }

  // ─── Scene/Frame/Layer アクセサ ───────────────────────────────────────

  List<Scene> scenesOf(String projectId) =>
      List.unmodifiable(_scenes[projectId] ?? []);

  /// プロジェクト内で実際に使用されているフォントのファミリー名一覧を取得する
  /// （プロジェクト共有時の「フォントを含める」判定・不足フォント検出に使用）。
  /// アプリ標準フォントも含まれるが、共有・不足検出側で
  /// ユーザー追加フォント（FontService管理分）のみへ絞り込んで扱う。
  Set<String> usedFontFamiliesOf(String projectId) {
    final result = <String>{};
    for (final scene in scenesOf(projectId)) {
      for (final frame in scene.frames) {
        for (final layer in frame.layers) {
          final family = layer.textObject?.fontFamily;
          if (family != null) result.add(family);
        }
      }
    }
    return result;
  }

  Scene? sceneOf(String projectId, String sceneId) =>
      (_scenes[projectId] ?? []).where((s) => s.id == sceneId).firstOrNull;

  // ─── シーンCRUD（Scene0001形式で内部管理） ───────────────────────────

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
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      return editTimeline(
        projectId,
        "addScene",
        () => addScene(projectId),
        changesTiles: false,
      );
    }
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
      frames: [
        Frame(index: 0, layers: [layer]),
      ],
    );
    scenes.add(scene);
    notifyListeners();
    return scene;
  }

  /// Duplicates a scene's frames, local material and editing metadata.
  /// Project-wide layers are still shared with the original scene.
  Scene? duplicateScene(String projectId, String sceneId, {String? name}) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      return editTimeline(
        projectId,
        "duplicateScene",
        () => duplicateScene(projectId, sceneId, name: name),
        changesTiles: true,
      );
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return null;
    final sourceIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sourceIdx < 0) return null;
    final source = scenes[sourceIdx];
    final n = _nextSceneIndex(projectId);
    final newSceneId = 'Scene${n.toString().padLeft(4, '0')}';
    final tm = _tilesOf(projectId);

    final idMap = <String, String>{};
    bool copiesLayer(Layer layer) =>
        layer.type != LayerType.selection &&
        (!isRangeLayerType(layer.type) ||
            (layer.rangeMode != LayerRangeMode.allFrames &&
                (layer.rangeMode != LayerRangeMode.sceneRange ||
                    (layer.rangeSceneId ?? sceneId) == sceneId)));
    final sceneLayers = <int, List<Layer>>{
      for (final frame in source.frames)
        frame.index: frame.layers.where(copiesLayer).toList(),
    };
    // A layer targeted at this scene can have data in another scene.
    final externalLayers = layersOf(projectId, sceneId, 0).where((layer) {
      final home = homeOf(projectId, layer.id);
      return home != null &&
          home.sceneId != sceneId &&
          layer.rangeMode == LayerRangeMode.sceneRange &&
          layer.rangeSceneId == sceneId;
    });
    sceneLayers[0]?.addAll(externalLayers);
    for (final layer in sceneLayers.values.expand((layers) => layers)) {
      idMap.putIfAbsent(layer.id, () => _nextLayerId(projectId));
    }

    final newFrames = <Frame>[
      for (final frame in source.frames)
        frame.copyWith(
          layers: [
            for (final layer in sceneLayers[frame.index]!)
              layer.copyWith(
                id: idMap[layer.id]!,
                parentFolderId: idMap[layer.parentFolderId],
                rangeSceneId: layer.rangeSceneId == sceneId
                    ? newSceneId
                    : layer.rangeSceneId,
              ),
          ],
        ),
    ];
    for (final frame in source.frames) {
      for (final layer in sceneLayers[frame.index]!) {
        tm?.copyLayer(
          tileKeyFor(projectId, sceneId, frame.index, layer.id),
          frameLayerKey(newSceneId, frame.index, idMap[layer.id]!),
        );
      }
    }

    final globallySharedIds = {
      for (final layer in layersOf(projectId, sceneId, 0))
        if (isRangeLayerType(layer.type) &&
            layer.rangeMode == LayerRangeMode.allFrames)
          layer.id,
    };
    final newScene = source.copyWith(
      id: newSceneId,
      index: sourceIdx + 1,
      name: name ?? source.name,
      frames: newFrames,
      groups: [
        for (final group in source.groups)
          group.copyWith(
            memberLayerIds: [
              for (final id in group.memberLayerIds)
                if (idMap[id] case final String copiedId)
                  copiedId
                else if (globallySharedIds.contains(id))
                  id,
            ],
          ),
      ],
    );
    for (final frame in newFrames) {
      for (final layer in frame.layers) {
        _registerHomeIfNeeded(projectId, newSceneId, frame.index, layer);
      }
    }
    scenes.insert(sourceIdx + 1, newScene);
    final reindexed = scenes
        .asMap()
        .entries
        .map((e) => e.value.copyWith(index: e.key))
        .toList();
    _scenes[projectId] = reindexed;
    notifyListeners();
    return newScene;
  }

  /// シーンを削除する（最低1シーンは残す）。描画タイルも破棄する。
  void removeScene(String projectId, String sceneId) =>
      removeScenes(projectId, [sceneId]);

  /// 複数シーンを一括削除する（最低1シーンは残す）。
  void removeScenes(String projectId, List<String> sceneIds) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "removeScenes",
        () => removeScenes(projectId, sceneIds),
        changesTiles: true,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idsToRemove = sceneIds.toSet();
    final remaining = scenes.where((s) => !idsToRemove.contains(s.id)).toList();
    if (remaining.isEmpty || remaining.length == scenes.length) return;
    final tm = _tilesOf(projectId);
    for (final id in idsToRemove) {
      tm?.removeSceneTiles(id);
    }
    final reindexed = remaining
        .asMap()
        .entries
        .map((e) => e.value.copyWith(index: e.key))
        .toList();
    _scenes[projectId] = reindexed;
    _layerHomes[projectId]?.removeWhere(
      (_, home) => idsToRemove.contains(home.sceneId),
    );
    notifyListeners();
  }

  /// シーン名を変更する（シーン名変更ダイアログ）。
  void renameScene(String projectId, String sceneId, String newName) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "renameScene",
        () => renameScene(projectId, sceneId, newName),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    if (scenes[idx].name == newName) return;
    scenes[idx] = scenes[idx].copyWith(name: newName);
    notifyListeners();
  }

  /// シーンを指定した順序（IDのリスト）へ並び替える（カーソル固定方式）。
  /// sceneIdはそのまま・indexのみ新しい並び順に合わせて振り直す。
  void reorderScenesByIds(String projectId, List<String> orderedSceneIds) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "reorderScenesByIds",
        () => reorderScenesByIds(projectId, orderedSceneIds),
        changesTiles: false,
      );
      return;
    }
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

  /// Data stored on a frame, including range layers whose home is currently
  /// outside their visible span. Use this for editing the stored layer.
  List<Layer> storedLayersOf(String projectId, String sceneId, int frameIndex) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null || frameIndex < 0 || frameIndex >= scene.frames.length) {
      return const [];
    }
    return List.unmodifiable(scene.frames[frameIndex].layers);
  }

  /// 指定フレームで実際に表示すべきレイヤー一覧を返す。このフレームに物理的に
  /// 存在するレイヤー（先頭側）に加え、他のフレームがホーム位置となっている
  /// 表示範囲レイヤー（共通・タイムライン素材・ウォーターマーク）のうち、
  /// 表示範囲がこのフレームを含むものを末尾へ動的に合成する（
  /// 表示範囲内のフレームのみレイヤーパレット・キャンバスへ表示）。
  List<Layer> layersOf(String projectId, String sceneId, int frameIndex) {
    final ownLayers = storedLayersOf(projectId, sceneId, frameIndex);
    final homes = _layerHomes[projectId] ?? const <String, LayerHome>{};
    return List.unmodifiable(
      resolveFrameLayers(
        _scenes[projectId] ?? const [],
        homes,
        sceneId,
        frameIndex,
        ownLayers,
      ),
    );
  }

  /// フレーム[frameIndex]のレイヤーを重ねる順（前面から）に並べたものと、
  /// まとめてマスクするレイヤーの組。タイムラインのプレビュー・書き出しは
  /// [applyFrameMask]をtrue、キャンバスの表示はfalse（描いている絵を隠さない）。
  StackedFrameLayers stackedLayersOf(
    String projectId,
    String sceneId,
    int frameIndex, {
    bool applyFrameMask = true,
  }) {
    final scene = sceneOf(projectId, sceneId);
    final layers = layersOf(projectId, sceneId, frameIndex);
    if (scene == null) {
      return (layers: layers, maskGroups: const <LayerMaskGroup>[]);
    }
    return stackFrameLayers(
      scene,
      frameIndex,
      layers,
      applyFrameMask: applyFrameMask,
    );
  }

  /// キャンバスに表示する順（前面から）のレイヤー。[layersOf]はレイヤー
  /// パレットの並び（並び替え・結合などの添字の基準）のまま。
  List<Layer> displayLayersOf(
    String projectId,
    String sceneId,
    int frameIndex,
  ) => stackedLayersOf(
    projectId,
    sceneId,
    frameIndex,
    applyFrameMask: false,
  ).layers;

  /// シーンの重なり順とフレーム（イラスト）のマスクを置き換える。
  void updateSceneStack(String projectId, String sceneId, SceneStack stack) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "updateSceneStack",
        () => updateSceneStack(projectId, sceneId, stack),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    scenes[idx] = scenes[idx].copyWith(stack: stack);
    _saveAsync(projectId);
    notifyListeners();
  }

  /// レイヤーIDから、表示範囲レイヤーの「ホーム位置」（実データが存在する
  /// シーン・フレーム）を取得する。範囲レイヤーでない場合はnull。
  LayerHome? homeOf(String projectId, String layerId) =>
      _layerHomes[projectId]?[layerId];

  /// プロジェクト全体の表示範囲レイヤーのホーム位置インデックスを返す
  /// （プレビュー・書き出しでの合成キー解決用）。
  Map<String, LayerHome> layerHomesOf(String projectId) =>
      Map.unmodifiable(_layerHomes[projectId] ?? const {});

  /// タイムライン共通レイヤートラックUI用：プロジェクト内の全共通レイヤーと
  /// ウォーターマークレイヤーのホーム位置（実データが物理的に存在する
  /// シーン・フレーム）を返す（共通レイヤーの表示範囲を
  /// タイムライン上で確認・変更する。ウォーターマークも同じ表示範囲の
  /// 仕組みを使うため同じトラックに乗せ、タップで角度・大きさ・不透明度・
  /// 表示範囲をまとめて編集できるようにする）。
  List<({Layer layer, LayerHome home})> commonLayersOf(String projectId) {
    final homes = _layerHomes[projectId];
    if (homes == null) return const [];
    final result = <({Layer layer, LayerHome home})>[];
    for (final entry in homes.entries) {
      final home = entry.value;
      final scene = sceneOf(projectId, home.sceneId);
      if (scene == null || home.frameIndex >= scene.frames.length) continue;
      final layer = scene.frames[home.frameIndex].layers
          .where((l) => l.id == entry.key)
          .firstOrNull;
      if (layer != null &&
          (layer.type == LayerType.common ||
              layer.type == LayerType.watermark)) {
        result.add((layer: layer, home: home));
      }
    }
    return result;
  }

  /// レイヤーのTileManager合成キーを解決する。表示範囲レイヤーは、実際に
  /// 表示中のフレームに関わらず常にホーム位置のタイルバッファを参照する
  /// （複数フレームでの共有表示・共有編集を実現するため）。
  String tileKeyFor(
    String projectId,
    String sceneId,
    int frameIndex,
    String layerId,
  ) => resolveTileKey(
    _layerHomes[projectId] ?? const {},
    sceneId,
    frameIndex,
    layerId,
  );

  void _registerHomeIfNeeded(
    String projectId,
    String sceneId,
    int frameIndex,
    Layer layer,
  ) {
    if (!isRangeLayerType(layer.type)) return;
    (_layerHomes[projectId] ??= {})[layer.id] = (
      sceneId: sceneId,
      frameIndex: frameIndex,
    );
  }

  // ─── レイヤーID生成 ───────────────────────────────────────────────────

  String _nextLayerId(String projectId) {
    final count = (_layerIdCounters[projectId] ?? 1);
    _layerIdCounters[projectId] = count + 1;
    return 'Layer${count.toString().padLeft(4, '0')}';
  }

  // ─── レイヤー追加（内部・Undo/Redo から呼ばれる） ─────────────────────

  void _insertLayerById(
    String projectId,
    String sceneId,
    int frameIndex,
    String layerId,
    int insertIndex,
  ) {
    final layer =
        _removedLayers[projectId]?[(
          scene: sceneId,
          frame: frameIndex,
          id: layerId,
        )];
    if (layer == null) return;
    _applyLayerInsert(projectId, sceneId, frameIndex, layer, insertIndex);
    _registerHomeIfNeeded(projectId, sceneId, frameIndex, layer);
  }

  void _removeLayerById(
    String projectId,
    String sceneId,
    int frameIndex,
    String layerId,
  ) {
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
    (_removedLayers[projectId] ??= {})[(
          scene: sceneId,
          frame: frameIndex,
          id: layerId,
        )] =
        removed;
    final newLayers = [
      for (final layer in frame.layers)
        if (layer.id != layerId)
          if (removed.type == LayerType.folder &&
              layer.parentFolderId == layerId)
            layer.copyWith(parentFolderId: removed.parentFolderId)
          else
            layer,
    ];
    _applyFrameUpdate(projectId, sceneIdx, frameIndex, newLayers);
    _layerHomes[projectId]?.remove(layerId);
  }

  void _applyLayerInsert(
    String projectId,
    String sceneId,
    int frameIndex,
    Layer layer,
    int insertIndex,
  ) {
    _layersAddedInGroup?.add('$projectId/${layer.id}');
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
    String projectId,
    int sceneIdx,
    int frameIndex,
    List<Layer> newLayers,
  ) {
    final scenes = _scenes[projectId]!;
    final scene = scenes[sceneIdx];
    final newFrames = List<Frame>.from(scene.frames);
    newFrames[frameIndex] = scene.frames[frameIndex].copyWith(
      layers: newLayers,
    );
    scenes[sceneIdx] = scene.copyWith(frames: newFrames);
    recordConfirmedEdit(projectId);
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
    // テキストレイヤー名：テキスト1 / テキスト2 / テキスト3 …
    final existingTextCount = layersOf(
      projectId,
      sceneId,
      frameIndex,
    ).where((l) => l.type == LayerType.text).length;
    final textObject = TextObject(id: layerId, text: text, position: position);
    final layer = Layer(
      id: layerId,
      name: 'テキスト${existingTextCount + 1}',
      type: LayerType.text,
      textObject: textObject,
    );
    _applyLayerInsert(projectId, sceneId, frameIndex, layer, 0);

    (_recordingTimelineEdits.contains(projectId) ? null : _undoManager)?.push(
      LayerAddUndoAction(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layerId: layerId,
        insertIndex: 0,
        doAdd: _insertLayerById,
        doRemove: _removeLayerById,
      ),
      projectId: projectId,
    );
    return layer;
  }

  /// 通常レイヤーを追加し、Undoスタックに積む。[id]を指定した場合はそのIDを
  /// そのまま使う（例：フィルターの複数フレーム一括適用で、各フレームに
  /// 同一IDの新規レイヤーを挿入し、1つの連続したレイヤートラックとして
  /// 扱えるようにする用途。省略時は従来通り自動採番する）。
  /// [insertIndex]を指定すると、初回追加とRedoを同じ位置へ挿入する。
  Layer addLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required LayerType type,
    required String name,
    String? id,
    int insertIndex = 0,
    String? parentFolderId,
  }) {
    final layerId = id ?? _nextLayerId(projectId);
    final scene = sceneOf(projectId, sceneId);
    final ownLayers =
        scene != null && frameIndex >= 0 && frameIndex < scene.frames.length
        ? scene.frames[frameIndex].layers
        : const <Layer>[];
    final folderIndex = parentFolderId == null || isRangeLayerType(type)
        ? -1
        : ownLayers.indexWhere(
            (layer) =>
                layer.id == parentFolderId && layer.type == LayerType.folder,
          );
    final layer = Layer(
      id: layerId,
      name: name,
      type: type,
      parentFolderId: folderIndex >= 0 ? parentFolderId : null,
    );
    final targetIndex = folderIndex >= 0
        ? folderIndex + 1
        : insertIndex.clamp(0, ownLayers.length);
    _applyLayerInsert(projectId, sceneId, frameIndex, layer, targetIndex);
    _registerHomeIfNeeded(projectId, sceneId, frameIndex, layer);

    (_recordingTimelineEdits.contains(projectId) ? null : _undoManager)?.push(
      LayerAddUndoAction(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layerId: layerId,
        insertIndex: targetIndex,
        doAdd: _insertLayerById,
        doRemove: _removeLayerById,
      ),
      projectId: projectId,
    );
    return layer;
  }

  /// コピー時に保持したレイヤーのメタデータと画素を、既存レイヤーを
  /// 上書きせず[insertIndex]へ新規IDで挿入する。フレームをまたぐ
  /// コピー＆ペースト用。テキストオブジェクトも新IDへ付け替える。
  Layer insertLayerSnapshot({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required Layer source,
    required int insertIndex,
    required String? parentFolderId,
    Uint8List? pixels,
  }) {
    final scenes = _scenes[projectId];
    if (scenes == null) throw StateError('Project is unavailable');
    final sceneIdx = scenes.indexWhere((scene) => scene.id == sceneId);
    if (sceneIdx < 0) throw StateError('Scene is unavailable');
    final scene = scenes[sceneIdx];
    if (frameIndex < 0 || frameIndex >= scene.frames.length) {
      throw StateError('Frame is unavailable');
    }
    final targetIndex = insertIndex.clamp(
      0,
      scene.frames[frameIndex].layers.length,
    );
    final newId = _nextLayerId(projectId);
    final copy = source.copyWith(
      id: newId,
      parentFolderId: parentFolderId,
      textObject: source.textObject?.copyWith(id: newId),
      keyframes: List.of(source.keyframes),
    );
    _applyLayerInsert(projectId, sceneId, frameIndex, copy, targetIndex);
    _registerHomeIfNeeded(projectId, sceneId, frameIndex, copy);
    if (pixels != null) {
      final targetKey = tileKeyFor(projectId, sceneId, frameIndex, newId);
      tileManagerOf(
        projectId,
      ).replaceLayerPixels(targetKey, Uint8List.fromList(pixels));
    }
    (_recordingTimelineEdits.contains(projectId) ? null : _undoManager)?.push(
      LayerAddUndoAction(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layerId: newId,
        insertIndex: targetIndex,
        materialId: copy.materialId,
        doAdd: _insertLayerById,
        doRemove: _removeLayerById,
      ),
      projectId: projectId,
    );
    return copy;
  }

  /// レイヤーを複製する（メタデータ・キーフレーム等の設定に加えて
  /// ピクセル内容もTileManager.copyLayerでコピーオンライト複製する）。
  /// 複製先は元レイヤーのすぐ上に挿入する。レイヤーのコピー＆ペースト
  /// （Ctrl+C/Ctrl+V）から使う。対象レイヤーが見つからない場合はnull。
  Layer? duplicateLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
    String? nameOverride,
  }) {
    final layers = layersOf(projectId, sceneId, frameIndex);
    final index = layers.indexWhere((l) => l.id == layerId);
    if (index < 0) return null;
    final source = layers[index];
    // TileManagerの実際のキーは「シーンID#フレーム番号#レイヤーID」の
    // 合成キー（表示範囲レイヤーはホーム位置基準）であり、レイヤーIDを
    // そのままキーにすることはできない。
    final sourceKey = tileKeyFor(projectId, sceneId, frameIndex, layerId);
    final newId = _nextLayerId(projectId);
    final copy = source.copyWith(id: newId, name: nameOverride ?? source.name);
    _applyLayerInsert(projectId, sceneId, frameIndex, copy, index);
    // 表示範囲レイヤー（common・timelineImage・timelineVideo・watermark）は
    // ホーム位置の登録も必要（addLayer/addTextLayerと同様）。
    _registerHomeIfNeeded(projectId, sceneId, frameIndex, copy);
    final targetKey = tileKeyFor(projectId, sceneId, frameIndex, newId);
    tileManagerOf(projectId).copyLayer(sourceKey, targetKey);

    (_recordingTimelineEdits.contains(projectId) ? null : _undoManager)?.push(
      LayerAddUndoAction(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layerId: newId,
        insertIndex: index,
        materialId: copy.materialId,
        doAdd: _insertLayerById,
        doRemove: _removeLayerById,
      ),
      projectId: projectId,
    );
    return copy;
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
    final home =
        _layerHomes[projectId]?[layerId] ??
        (sceneId: sceneId, frameIndex: frameIndex);
    final layers = storedLayersOf(projectId, home.sceneId, home.frameIndex);
    final removedIndex = layers.indexWhere((l) => l.id == layerId);
    if (removedIndex < 0) return;
    if (layers[removedIndex].type == LayerType.folder &&
        layers.any((layer) => layer.parentFolderId == layerId)) {
      editTimeline(
        projectId,
        'Remove layer folder',
        () =>
            _removeLayerById(projectId, home.sceneId, home.frameIndex, layerId),
        changesTiles: false,
      );
      return;
    }
    _removeLayerById(projectId, home.sceneId, home.frameIndex, layerId);

    (_recordingTimelineEdits.contains(projectId) ? null : _undoManager)?.push(
      LayerRemoveUndoAction(
        projectId: projectId,
        sceneId: home.sceneId,
        frameIndex: home.frameIndex,
        layerId: layerId,
        removedIndex: removedIndex,
        materialId: layers[removedIndex].materialId,
        doAdd: _insertLayerById,
        doRemove: _removeLayerById,
      ),
      projectId: projectId,
    );
  }

  /// レイヤーを更新する（表示切替・ロック等）。表示範囲レイヤーは実データの
  /// あるホーム位置へ書き戻す（他フレームから合成表示中に編集した場合も
  /// 正しく反映されるようにするため）。
  void updateLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required Layer layer,
    bool recordUndo = true,
  }) {
    if (recordUndo &&
        _layersAddedInGroup?.contains('$projectId/${layer.id}') != true &&
        !_recordingTimelineEdits.contains(projectId) &&
        _undoManager != null) {
      editTimeline(
        projectId,
        'Update layer',
        () => updateLayer(
          projectId: projectId,
          sceneId: sceneId,
          frameIndex: frameIndex,
          layer: layer,
          recordUndo: false,
        ),
        changesTiles: false,
      );
      return;
    }
    final home =
        _layerHomes[projectId]?[layer.id] ??
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

  /// Replaces a layer's pixels in one go (a filter applied in place) as a
  /// single Undo step. [updatedLayer] carries any change to the layer's own
  /// settings made with it (Prism switches the blend mode); Undo restores
  /// both.
  void replaceLayerPixels({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
    required Uint8List pixels,
    Layer? updatedLayer,
    Uint8List? selection,
  }) {
    final tm = tileManagerOf(projectId);
    if (selection != null &&
        selection.length != tm.canvasWidth * tm.canvasHeight) {
      return;
    }
    final key = tileKeyFor(projectId, sceneId, frameIndex, layerId);
    final home = homeOf(projectId, layerId);
    final layerBefore = storedLayersOf(
      projectId,
      home?.sceneId ?? sceneId,
      home?.frameIndex ?? frameIndex,
    ).where((layer) => layer.id == layerId).firstOrNull;
    // Never take over a recording someone else (a stroke, a selection
    // transform) has open on this tile manager.
    final record =
        _undoManager != null &&
        !_recordingTimelineEdits.contains(projectId) &&
        tm.recordingTouchedTiles == null &&
        !(_layersAddedInGroup?.contains('$projectId/$layerId') ?? false);
    if (record) tm.beginUndoRecording(key);
    tm.replaceLayerPixels(key, pixels, selection: selection);
    final snapshot = record
        ? tm.endUndoRecording()
        : (
            before: const <String, Uint8List?>{},
            after: const <String, Uint8List?>{},
          );
    final layerChanged =
        updatedLayer != null &&
        layerBefore != null &&
        !identical(updatedLayer, layerBefore);
    if (updatedLayer != null) {
      updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layer: updatedLayer,
        recordUndo: false,
      );
    }
    if (!record || (snapshot.before.isEmpty && !layerChanged)) return;
    _undoManager!.push(
      _LayerPixelsUndoAction(
        projects: this,
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layerKey: key,
        before: snapshot.before,
        after: snapshot.after,
        layerBefore: layerChanged ? layerBefore : null,
        layerAfter: layerChanged ? updatedLayer : null,
      ),
      projectId: projectId,
    );
    if (updatedLayer == null) {
      _notifyProjectPixelsChanged(projectId);
    }
  }

  void _notifyProjectPixelsChanged(String projectId) {
    _saveAsync(projectId);
    notifyListeners();
  }

  /// A stroke can be reversed after its canvas widget has been disposed.
  void refreshDrawingHistory(String projectId) {
    if (_projects.any((project) => project.id == projectId)) {
      _notifyProjectPixelsChanged(projectId);
    }
  }

  Future<void> applyBrightnessToAlpha({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
    required bool grayMode,
    Uint8List? selection,
  }) async {
    final manager = tileManagerOf(projectId);
    final key = tileKeyFor(projectId, sceneId, frameIndex, layerId);
    final pixels = await manager.brightnessToAlphaPixels(
      key,
      grayMode: grayMode,
    );
    if (pixels == null ||
        !identical(manager, tileManagerOf(projectId)) ||
        !layersOf(
          projectId,
          sceneId,
          frameIndex,
        ).any((layer) => layer.id == layerId)) {
      return;
    }
    replaceLayerPixels(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layerId: layerId,
      pixels: pixels,
      selection: selection,
    );
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
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "reorderLayer",
        () => reorderLayer(
          projectId: projectId,
          sceneId: sceneId,
          frameIndex: frameIndex,
          oldIndex: oldIndex,
          newIndex: newIndex,
        ),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (frameIndex >= scene.frames.length) return;
    final frame = scene.frames[frameIndex];
    if (oldIndex < 0 || oldIndex >= frame.layers.length) return;
    final branch = _layerBranch(frame.layers, frame.layers[oldIndex]);
    final moved = <Layer>[];
    final remaining = <Layer>[];
    var target = 0;
    for (var index = 0; index < frame.layers.length; index++) {
      final layer = frame.layers[index];
      if (branch.contains(layer.id)) {
        moved.add(layer);
      } else {
        if (index < newIndex) target++;
        remaining.add(layer);
      }
    }
    remaining.insertAll(target, moved);
    if (!listEquals(remaining, frame.layers)) {
      _applyFrameUpdate(projectId, sceneIdx, frameIndex, remaining);
    }
  }

  static Set<String> _layerBranch(List<Layer> layers, Layer source) {
    final subtree = <String>{source.id};
    if (source.type == LayerType.folder) {
      final children = <String?, List<String>>{};
      for (final layer in layers) {
        children.putIfAbsent(layer.parentFolderId, () => []).add(layer.id);
      }
      final pending = [source.id];
      while (pending.isNotEmpty) {
        final current = pending.removeLast();
        for (final child in children[current] ?? const <String>[]) {
          if (subtree.add(child)) pending.add(child);
        }
      }
    }
    return subtree;
  }

  /// Drag and drop changes the order among siblings, keeping folder contents
  /// together. Membership is changed through the explicit folder picker.
  void reorderLayerRelative({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
    required String siblingId,
    required bool after,
  }) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null || frameIndex < 0 || frameIndex >= scene.frames.length) {
      return;
    }
    final layers = scene.frames[frameIndex].layers;
    final from = layers.indexWhere((layer) => layer.id == layerId);
    final to = layers.indexWhere((layer) => layer.id == siblingId);
    if (from < 0 || to < 0 || from == to) return;
    if (layers[from].parentFolderId != layers[to].parentFolderId) return;
    var insertAt = to;
    if (after) {
      final targetBranch = _layerBranch(layers, layers[to]);
      insertAt =
          layers.lastIndexWhere((layer) => targetBranch.contains(layer.id)) + 1;
    }
    reorderLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      oldIndex: from,
      newIndex: insertAt,
    );
  }

  /// Move a frame-local layer (or folder subtree) and preserve its pixels.
  bool moveLayerToFolder({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
    required String? folderId,
  }) {
    final scenes = _scenes[projectId];
    if (scenes == null) return false;
    final sceneIndex = scenes.indexWhere((scene) => scene.id == sceneId);
    if (sceneIndex < 0) return false;
    final frames = scenes[sceneIndex].frames;
    if (frameIndex < 0 || frameIndex >= frames.length) return false;
    final layers = frames[frameIndex].layers;
    final byId = {for (final layer in layers) layer.id: layer};
    final source = byId[layerId];
    if (source == null ||
        isRangeLayerType(source.type) ||
        source.parentFolderId == folderId) {
      return false;
    }
    if (folderId != null && byId[folderId]?.type != LayerType.folder) {
      return false;
    }
    final subtree = _layerBranch(layers, source);
    if (subtree.contains(folderId)) return false;
    final next = layers.where((layer) => !subtree.contains(layer.id)).toList();
    final target = folderId == null
        ? 0
        : next.indexWhere((layer) => layer.id == folderId) + 1;
    next.insertAll(target, [
      source.copyWith(parentFolderId: folderId),
      for (final layer in layers)
        if (layer.id != layerId && subtree.contains(layer.id)) layer,
    ]);
    editTimeline(
      projectId,
      'Move layer to folder',
      () => _applyFrameUpdate(projectId, sceneIndex, frameIndex, next),
      changesTiles: false,
    );
    return true;
  }

  /// .niashare を複製して通常プロジェクトとして追加する（共有フロー）。
  /// 新規プロジェクトIDを採番し、共有元ファイル自体は変更しない。
  ///
  /// [isSharedImport]はホーム画面の「共有」タブへ振り分けるかどうかのフラグ。
  /// 他人から受け取った.niashareの取り込みではtrue（デフォルト）のままだが、
  /// .niatra（引き継ぎ）経由で自分自身の別端末プロジェクトを復元する場合は
  /// falseを渡し、通常プロジェクト一覧へそのまま追加する
  /// （NiatraSerializer.restoreProjects()が使用）。
  Future<Project> importSharedProject(
    NiaproData data, {
    bool isSharedImport = true,
  }) async {
    final newId = _nextId('proj');
    // 作成と最終保存は同じ1回の時刻（別々に読むと数マイクロ秒ずれる）。
    final now = DateTime.now();
    final project = data.project.copyWith(
      id: newId,
      createdAt: now,
      updatedAt: now,
      isSharedImport: isSharedImport,
    );
    final importedProject = project.copyWith(
      makingEnabled: isSharedImport ? false : project.makingEnabled,
    );
    _projects.add(importedProject);
    _scenes[newId] = data.scenes;
    _layerHomes[newId] = buildLayerHomeIndex(data.scenes);
    final tm = TileManager(
      canvasWidth: project.drawingWidth,
      canvasHeight: project.drawingHeight,
      compositeCacheMax: _tileCacheBudget,
    );
    tm.importAll(data.tileData);
    _tileManagers[newId] = tm;
    _layerIdCounters[newId] = _maxLayerCounter(data.scenes);
    // 同梱素材（共有時に選択した画像/動画/音声）をMaterials/へ復元する。
    await NiaproSerializer.restoreBundledMaterials(newId, data);
    _saveAsync(newId);
    notifyListeners();
    return importedProject;
  }

  /// Load the selected snapshot into the editable work, keeping its history.
  void useSavedVersion(String projectId, NiaproData data) {
    restoreFromAutosave(projectId, data);
    _saveAsync(projectId);
  }

  Future<void> _checkpointAutosave(String projectId) async {
    try {
      await _autosaves?.save(projectId, this, skipUnchanged: true);
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    }
  }

  /// 保存データを既存プロジェクトへ復元する。
  /// プロジェクトIDは維持したまま、シーン・タイルの内容のみ自動保存時点へ戻す。
  void restoreFromAutosave(String projectId, NiaproData data) {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx < 0) return;
    final tiles = tileManagerOf(projectId);
    if (tiles.canvasWidth != data.project.drawingWidth ||
        tiles.canvasHeight != data.project.drawingHeight) {
      final restoredTiles = TileManager(
        canvasWidth: data.project.drawingWidth,
        canvasHeight: data.project.drawingHeight,
        compositeCacheMax: _tileCacheBudget,
      )..importAll(data.tileData);
      final before = _captureTimeline(projectId);
      _tileManagers[projectId] = restoredTiles;
      _installAutosave(projectId, idx, data);
      final after = _captureTimeline(projectId);
      _undoManager?.push(
        ProjectEditUndoAction(
          'Restore saved project',
          () {
            tiles.markAllTilesDirty();
            _tileManagers[projectId] = tiles;
            _restoreTimeline(projectId, before, const {});
          },
          () {
            restoredTiles.markAllTilesDirty();
            _tileManagers[projectId] = restoredTiles;
            _restoreTimeline(projectId, after, const {});
          },
          retainedMaterialIds: _materialIdsIn(
            before.scenes,
          ).followedBy(_materialIdsIn(after.scenes)),
        ),
        projectId: projectId,
      );
      notifyListeners();
      return;
    }
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        'Restore saved project',
        () => restoreFromAutosave(projectId, data),
      );
      return;
    }
    _installAutosave(projectId, idx, data);
    tiles.importAll(data.tileData);
    notifyListeners();
  }

  void _installAutosave(String projectId, int idx, NiaproData data) {
    // The saved version brings the whole picture back: the work can be saved
    // again even if its file could not be read.
    _unreadableTiles.remove(projectId);
    final live = _projects[idx];
    _projects[idx] = data.project.copyWith(
      id: projectId,
      updatedAt: DateTime.now(),
      // 入っているフォルダ・お気に入り・タグは今の作品のまま（古い手動の
      // 保存を読み込むと、作品が前に入っていたフォルダ〔ゴミ箱へ移した・
      // 消したフォルダも〕へ戻り、お気に入り・タグも戻った）。
      folderId: live.folderId,
      sharedFolderId: live.sharedFolderId,
      name: live.name,
      totalWorkSeconds: math.max(
        live.totalWorkSeconds,
        data.project.totalWorkSeconds,
      ),
      sizeBytes: live.sizeBytes,
      isSharedImport: live.isSharedImport,
      thumbnailPath: live.thumbnailPath,
      thumbnailMode: live.thumbnailMode,
      thumbnailFrameSceneId: live.thumbnailFrameSceneId,
      thumbnailFrameIndex: live.thumbnailFrameIndex,
      thumbnailLastSceneId: live.thumbnailLastSceneId,
      thumbnailLastFrameIndex: live.thumbnailLastFrameIndex,
      isFavorite: live.isFavorite,
      tags: live.tags,
    );
    _scenes[projectId] = List.of(data.scenes);
    _layerHomes[projectId] = buildLayerHomeIndex(data.scenes);
    _layerIdCounters[projectId] = math.max(
      _layerIdCounters[projectId] ?? 1,
      _maxLayerCounter(data.scenes),
    );
  }

  // ─── 自動塗り連携 ─────────────────────────────────────────────────────

  /// 自動塗り用線画レイヤーの直下にある自動塗りレイヤーへ更新マークを立てる。
  /// 線画レイヤーへ描画があった際に呼び出す（needsAutofillUpdate自動セット）。
  void markLineartDirty(
    String projectId,
    String sceneId,
    int frameIndex,
    String lineartLayerId,
  ) {
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
          recordUndo: false,
        );
      }
    }
  }

  /// 自動塗りプリセットのパーツ色・名前が変更／削除された際、当該パーツIDを参照する
  /// 全プロジェクト・全フレームの自動塗りレイヤーへ更新マークを伝播する。
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
            if (lineart.type != LayerType.autoFillLineart ||
                lineart.partId != partId) {
              continue;
            }
            if (li + 1 >= layers.length ||
                layers[li + 1].type != LayerType.autoFill) {
              continue;
            }
            final autofillLayer = layers[li + 1];
            if (autofillLayer.needsAutofillUpdate) continue;
            final newLayers = List<Layer>.from(layers);
            newLayers[li + 1] = autofillLayer.copyWith(
              needsAutofillUpdate: true,
            );
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
  /// 直下に自動塗りレイヤーが存在する場合はそちらの表示名・パーツIDも一括更新する。
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
        layer: layers[idx + 1].copyWith(
          partId: partId,
          name: '$partName（自動塗り）',
        ),
      );
    }
  }

  /// 書き出し前の未更新警告用：指定プロジェクトの全シーン・全フレームに
  /// needsAutofillUpdate==true の自動塗りレイヤーが存在するかを判定する。
  bool hasOutdatedAutofillLayers(String projectId) {
    final scenes = _scenes[projectId];
    if (scenes == null) return false;
    for (final scene in scenes) {
      for (final frame in scene.frames) {
        if (frame.layers.any(
          (l) => l.type == LayerType.autoFill && l.needsAutofillUpdate,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  /// タイムライン❗マーク表示用：指定フレームにneedsAutofillUpdate==trueの
  /// 自動塗りレイヤーが存在するかを判定する（更新マークはレイヤー・
  /// タイムライン両方に表示）。
  bool frameHasOutdatedAutofillLayers(
    String projectId,
    String sceneId,
    int frameIndex,
  ) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null || frameIndex < 0 || frameIndex >= scene.frames.length) {
      return false;
    }
    return scene.frames[frameIndex].layers.any(
      (l) => l.type == LayerType.autoFill && l.needsAutofillUpdate,
    );
  }

  /// タイムライン❗マーク表示用：指定シーン内のいずれかのフレームに
  /// needsAutofillUpdate==trueの自動塗りレイヤーが存在するかを判定する。
  bool sceneHasOutdatedAutofillLayers(String projectId, String sceneId) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null) return false;
    for (final frame in scene.frames) {
      if (frame.layers.any(
        (l) => l.type == LayerType.autoFill && l.needsAutofillUpdate,
      )) {
        return true;
      }
    }
    return false;
  }

  // ─── Frame API ────────────────────────────────────────────────────────

  int frameCount(String projectId, String sceneId) =>
      sceneOf(projectId, sceneId)?.frames.length ?? 0;

  /// フレームの保持セル数を変更する
  void setFrameHold(
    String projectId,
    String sceneId,
    int frameIndex,
    int hold,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "setFrameHold",
        () => setFrameHold(projectId, sceneId, frameIndex, hold),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (frameIndex < 0 || frameIndex >= scene.frames.length) return;
    final value = hold.clamp(1, 99);
    if (scene.frames[frameIndex].hold == value) return;
    final newFrames = List<Frame>.from(scene.frames);
    newFrames[frameIndex] = scene.frames[frameIndex].copyWith(hold: value);
    scenes[sceneIdx] = scene.copyWith(frames: newFrames);
    notifyListeners();
  }

  int frameHold(String projectId, String sceneId, int frameIndex) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null || frameIndex >= scene.frames.length) return 1;
    return scene.frames[frameIndex].hold;
  }

  /// プロジェクト全シーンの実フレーム数を返す。長さ指定は大体の目安で
  /// あり、実際にタイムラインモードでフレームを追加・削除したらその分
  /// 長さが変わるようにするための集計。
  /// フレーム追加・複製・削除ボタンを押す前に、UI側で上限チェック
  /// （無料会員は90秒まで）に使う想定。
  int totalFrameCount(String projectId) {
    final scenes = _scenes[projectId];
    if (scenes == null) return 0;
    return scenes.fold<int>(0, (sum, s) => sum + s.frames.length);
  }

  /// [totalFrameCount]をfpsで割った、追加・削除後に実際になる長さ（秒）を返す。
  int projectedDurationSeconds(String projectId, {int frameDelta = 0}) {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx < 0) return 0;
    final fps = _projects[idx].fps.clamp(1, 999999);
    final frames = totalFrameCount(projectId) + frameDelta;
    return (frames / fps).ceil().clamp(0, 1 << 30);
  }

  /// フレームの追加・複製・削除のたびに呼び出し、プロジェクトの長さ
  /// （durationSeconds）を全シーンの実フレーム数から再計算して同期する。
  /// 新規プロジェクト作成画面の長さ指定はあくまで目安で、
  /// 実際の長さはタイムラインモードでのフレーム増減に連動させる。
  void _syncDurationToFrameCount(String projectId) {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx < 0) return;
    final newDuration = projectedDurationSeconds(projectId).clamp(1, 1 << 30);
    if (newDuration != _projects[idx].durationSeconds) {
      _projects[idx] = _projects[idx].copyWith(durationSeconds: newDuration);
    }
  }

  /// フレームを末尾に追加する
  void addFrame(String projectId, String sceneId) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "addFrame",
        () => addFrame(projectId, sceneId),
        changesTiles: false,
      );
      return;
    }
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
        : [
            Layer(
              id: _nextLayerId(projectId),
              name: 'レイヤー1',
              type: LayerType.normal,
            ),
          ];
    final newFrame = Frame(index: scene.frames.length, layers: prevLayers);
    final newFrames = List<Frame>.from(scene.frames)..add(newFrame);
    scenes[sceneIdx] = scene.copyWith(frames: newFrames);
    _syncDurationToFrameCount(projectId);
    notifyListeners();
  }

  /// フレームを複製し、指定位置の直後へ挿入する（フレームのコピー）。
  /// レイヤー構成・描画データ（タイル）の両方を複製する。表示範囲レイヤー
  /// （common・timelineImage・timelineVideo・watermark）はホームが別フレームに
  /// 存在する参照であり、フレーム単位の複製対象ではないため除外する。
  void duplicateFrame(String projectId, String sceneId, int frameIndex) {
    insertDuplicatedFrame(
      projectId: projectId,
      sourceSceneId: sceneId,
      sourceFrameIndex: frameIndex,
      targetSceneId: sceneId,
      insertAt: frameIndex + 1,
    );
  }

  /// [sourceSceneId]の[sourceFrameIndex]番目のフレームを、[targetSceneId]の
  /// [insertAt]位置へ複製して挿入する（シーンをまたいだフレームの
  /// コピー＆ペースト・複製に使う共通処理）。レイヤー構成・描画データ
  /// （タイル）の両方を複製する。表示範囲レイヤー（common・
  /// timelineImage・timelineVideo・watermark）はホームが別フレームに
  /// 存在する参照であり、フレーム単位の複製対象ではないため除外する。
  /// 切り取り元のフレームを削除する場合は [transferFrameAnchors] も指定する。
  void insertDuplicatedFrame({
    required String projectId,
    required String sourceSceneId,
    required int sourceFrameIndex,
    required String targetSceneId,
    required int insertAt,
    bool transferFrameAnchors = false,
  }) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "insertDuplicatedFrame",
        () => insertDuplicatedFrame(
          projectId: projectId,
          sourceSceneId: sourceSceneId,
          sourceFrameIndex: sourceFrameIndex,
          targetSceneId: targetSceneId,
          insertAt: insertAt,
          transferFrameAnchors: transferFrameAnchors,
        ),
        changesTiles: true,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sourceSceneIdx = scenes.indexWhere((s) => s.id == sourceSceneId);
    if (sourceSceneIdx < 0) return;
    final sourceScene = scenes[sourceSceneIdx];
    if (sourceFrameIndex < 0 || sourceFrameIndex >= sourceScene.frames.length) {
      return;
    }
    final source = sourceScene.frames[sourceFrameIndex];
    final targetSceneIdx = scenes.indexWhere((s) => s.id == targetSceneId);
    if (targetSceneIdx < 0) return;
    final targetScene = scenes[targetSceneIdx];
    final clampedInsertAt = insertAt.clamp(0, targetScene.frames.length);

    // 挿入位置以降のフレームはindexが1つずつ後ろへずれる。描画データは
    // frameLayerKey(sceneId, frameIndex, layerId)でTileManagerに保存されている
    // ため、後ろ側から順に付け替えることでまだ移動していない位置への
    // 上書きを避ける。
    final tm = _tilesOf(projectId);
    if (tm != null) {
      for (int i = targetScene.frames.length - 1; i >= clampedInsertAt; i--) {
        for (final layer in targetScene.frames[i].layers) {
          tm.renameKey(
            frameLayerKey(targetSceneId, i, layer.id),
            frameLayerKey(targetSceneId, i + 1, layer.id),
          );
        }
      }
    }

    // 複製対象レイヤー（表示範囲レイヤー・内部専用selectionレイヤーは除外）。
    // 新しいレイヤーIDを割り当て、Copy-on-Writeでタイルデータも複製する。
    final sourceLayers = source.layers
        .where(
          (l) => !isRangeLayerType(l.type) && l.type != LayerType.selection,
        )
        .toList();
    final idMap = {
      for (final layer in sourceLayers) layer.id: _nextLayerId(projectId),
    };
    final newLayers = [
      for (final layer in sourceLayers)
        layer.copyWith(
          id: idMap[layer.id]!,
          parentFolderId: idMap[layer.parentFolderId],
        ),
    ];

    if (tm != null) {
      final relocatedSourceIndex =
          sourceSceneId == targetSceneId && sourceFrameIndex >= clampedInsertAt
          ? sourceFrameIndex + 1
          : sourceFrameIndex;
      for (final layer in sourceLayers) {
        final newId = idMap[layer.id]!;
        tm.copyLayer(
          frameLayerKey(sourceSceneId, relocatedSourceIndex, layer.id),
          frameLayerKey(targetSceneId, clampedInsertAt, newId),
        );
      }
    }

    final newFrame = Frame(
      index: clampedInsertAt,
      layers: newLayers,
      hold: source.hold,
    );
    final newFrames = List<Frame>.from(targetScene.frames)
      ..insert(clampedInsertAt, newFrame);
    final reindexed = newFrames
        .asMap()
        .entries
        .map((e) => e.value.copyWith(index: e.key))
        .toList();
    var updatedScene = _remapFrameAnchors(
      targetScene,
      reindexed,
      (index) => index >= clampedInsertAt ? index + 1 : index,
    );
    if (transferFrameAnchors) {
      updatedScene = updatedScene.copyWith(
        markers: [
          ...updatedScene.markers,
          for (final marker in sourceScene.markers)
            if (marker.frameIndex == sourceFrameIndex)
              marker.copyWith(frameIndex: clampedInsertAt),
        ]..sort((a, b) => a.frameIndex.compareTo(b.frameIndex)),
        cameraKeyframes: [
          ...updatedScene.cameraKeyframes,
          for (final keyframe in sourceScene.cameraKeyframes)
            if (keyframe.frameIndex == sourceFrameIndex)
              keyframe.copyWith(frameIndex: clampedInsertAt),
        ]..sort((a, b) => a.frameIndex.compareTo(b.frameIndex)),
      );
    }
    scenes[targetSceneIdx] = updatedScene;

    // 表示範囲レイヤーのホーム位置インデックスも合わせて更新する（挿入位置
    // 以降がホームだったレイヤーは1つ後ろへ詰める）。
    final homes = _layerHomes[projectId];
    if (homes != null) {
      final toShift = <String>[];
      homes.forEach((layerId, home) {
        if (home.sceneId == targetSceneId &&
            home.frameIndex >= clampedInsertAt) {
          toShift.add(layerId);
        }
      });
      for (final id in toShift) {
        final h = homes[id]!;
        homes[id] = (sceneId: h.sceneId, frameIndex: h.frameIndex + 1);
      }
    }
    _syncDurationToFrameCount(projectId);
    notifyListeners();
  }

  /// フレームを削除する（最低1フレームは残す）
  void removeFrame(
    String projectId,
    String sceneId,
    int frameIndex, {
    bool recordUndo = true,
  }) {
    if (recordUndo &&
        !_recordingTimelineEdits.contains(projectId) &&
        _undoManager != null) {
      editTimeline(
        projectId,
        'Remove frame',
        () => removeFrame(projectId, sceneId, frameIndex, recordUndo: false),
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (scene.frames.length <= 1) return;
    if (frameIndex < 0 || frameIndex >= scene.frames.length) return;

    final newLength = scene.frames.length - 1;
    final tm = _tilesOf(projectId);
    final keptLayers = List.generate(newLength, (_) => <Layer>[]);
    final movedHomes = <({String oldKey, String newKey})>[];

    for (var oldIndex = 0; oldIndex < scene.frames.length; oldIndex++) {
      final deleted = oldIndex == frameIndex;
      final newIndex = oldIndex > frameIndex ? oldIndex - 1 : oldIndex;
      for (var layer in scene.frames[oldIndex].layers) {
        final oldKey = frameLayerKey(sceneId, oldIndex, layer.id);
        var target = newIndex;
        if (isRangeLayerType(layer.type)) {
          if (layer.rangeMode == LayerRangeMode.frameRange) {
            final start = (layer.rangeStart ?? 1) - 1;
            final end = (layer.rangeEnd ?? start + 1) - 1;
            final range = _shiftRangeAfterFrameRemoval(start, end, frameIndex);
            if (range == null) {
              tm?.removeLayer(oldKey);
              continue;
            }
            layer = layer.copyWith(
              rangeStart: range.start + 1,
              rangeEnd: range.end + 1,
            );
            if (deleted) target = range.start.clamp(0, newLength - 1);
          } else if (deleted) {
            target = frameIndex.clamp(0, newLength - 1);
          }
        } else if (deleted) {
          tm?.removeLayer(oldKey);
          continue;
        }

        keptLayers[target].add(layer);
        final newKey = frameLayerKey(sceneId, target, layer.id);
        if (oldKey != newKey) {
          if (deleted) {
            movedHomes.add((oldKey: oldKey, newKey: newKey));
          } else {
            tm?.renameKey(oldKey, newKey);
          }
        }
      }
    }
    for (final home in movedHomes) {
      tm?.renameKey(home.oldKey, home.newKey);
    }
    final reindexed = [
      for (var i = 0; i < newLength; i++)
        scene.frames[i < frameIndex ? i : i + 1].copyWith(
          index: i,
          layers: keptLayers[i],
        ),
    ];
    final effects = [
      for (final effect in scene.effectFilters)
        if (_shiftRangeAfterFrameRemoval(
              effect.startFrame,
              effect.endFrame,
              frameIndex,
            )
            case final range?)
          effect.copyWith(startFrame: range.start, endFrame: range.end),
    ];
    scenes[sceneIdx] = _remapFrameAnchors(scene, reindexed, (index) {
      if (index == frameIndex) return null;
      return index > frameIndex ? index - 1 : index;
    }).copyWith(effectFilters: effects);
    _layerHomes[projectId] = buildLayerHomeIndex(scenes);
    _syncDurationToFrameCount(projectId);
    notifyListeners();
  }

  ({int start, int end})? _shiftRangeAfterFrameRemoval(
    int start,
    int end,
    int removed,
  ) {
    if (start == removed && end == removed) return null;
    return (
      start: start > removed ? start - 1 : start,
      end: end >= removed ? end - 1 : end,
    );
  }

  /// シーンのフレーム数を[targetCount]へ一括で揃える（タイムラインの
  /// 「長さ変更」メニュー：秒数・フレーム数のどちらから指定しても、
  /// 呼び出し側でフレーム数へ換算してから渡す）。現在のフレーム数より
  /// 多ければ末尾に追加、少なければ末尾から削除する。既存の
  /// addFrame/removeFrameを内部的に繰り返し呼ぶことで、タイルデータの
  /// 付け替え・表示範囲レイヤーのホーム位置更新など既存の安全な処理を
  /// そのまま再利用する。
  /// [setSceneFrameCount]で[targetCount]へ短縮した場合に削除される末尾の
  /// フレーム範囲に、新規追加時の初期状態（通常レイヤー1枚のみ・描画データ
  /// なし）から変更が加えられているものが含まれるかを判定する。レイヤー
  /// 構成が既定と異なる（枚数が1枚でない、通常レイヤー以外の種別を含む）
  /// 場合、またはいずれかのレイヤーに実際の描画データ（タイル）が存在する
  /// 場合を「変更あり」とみなす。[targetCount]が現在のフレーム数以上
  /// （短縮ではない）場合は常にfalseを返す。
  bool sceneFrameShrinkHasContent(
    String projectId,
    String sceneId,
    int targetCount,
  ) {
    final scenes = _scenes[projectId];
    if (scenes == null) return false;
    final scene = scenes.where((s) => s.id == sceneId).firstOrNull;
    if (scene == null) return false;
    final currentCount = scene.frames.length;
    if (targetCount >= currentCount) return false;
    if (scene.markers.any((marker) => marker.frameIndex >= targetCount) ||
        scene.cameraKeyframes.any(
          (keyframe) => keyframe.frameIndex >= targetCount,
        )) {
      return true;
    }
    final tm = _tilesOf(projectId);
    final tiles = tm?.exportAll();
    for (int i = targetCount; i < currentCount; i++) {
      final frame = scene.frames[i];
      final normalLayers = frame.layers
          .where((l) => l.type == LayerType.normal)
          .toList();
      if (frame.layers.length != normalLayers.length ||
          normalLayers.length != 1) {
        return true;
      }
      if (tiles != null) {
        for (final layer in frame.layers) {
          final key = frameLayerKey(sceneId, i, layer.id);
          if (tiles[key]?.isNotEmpty ?? false) return true;
        }
      }
    }
    return false;
  }

  void setSceneFrameCount(String projectId, String sceneId, int targetCount) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "setSceneFrameCount",
        () => setSceneFrameCount(projectId, sceneId, targetCount),
        changesTiles: true,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final clamped = targetCount.clamp(1, 1 << 30);
    if (scenes[sceneIdx].frames.length == clamped) return;
    while (scenes[sceneIdx].frames.length < clamped) {
      addFrame(projectId, sceneId);
    }
    while (scenes[sceneIdx].frames.length > clamped) {
      removeFrame(
        projectId,
        sceneId,
        scenes[sceneIdx].frames.length - 1,
        recordUndo: false,
      );
    }
    _saveAsync(projectId);
  }

  Scene _remapFrameAnchors(
    Scene scene,
    List<Frame> frames,
    int? Function(int) newIndexFor,
  ) {
    int? newIndex(int oldIndex) {
      if (oldIndex < 0 || oldIndex >= scene.frames.length) return null;
      return newIndexFor(oldIndex);
    }

    return scene.copyWith(
      frames: frames,
      cameraKeyframes: [
        for (final keyframe in scene.cameraKeyframes)
          if (newIndex(keyframe.frameIndex) case final int index)
            keyframe.copyWith(frameIndex: index),
      ]..sort((a, b) => a.frameIndex.compareTo(b.frameIndex)),
      markers: [
        for (final marker in scene.markers)
          if (newIndex(marker.frameIndex) case final int index)
            marker.copyWith(frameIndex: index),
      ]..sort((a, b) => a.frameIndex.compareTo(b.frameIndex)),
    );
  }

  /// フレームをカーソル固定方式で並び替える（シーン移動と同じ操作体系を
  /// フレームにも適用）。[oldIndicesInNewOrder]は現在のフレームindexを新しい並び順
  /// で並べたリスト（全フレーム数と同じ長さの並び替え）。
  void reorderFrames(
    String projectId,
    String sceneId,
    List<int> oldIndicesInNewOrder,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "reorderFrames",
        () => reorderFrames(projectId, sceneId, oldIndicesInNewOrder),
        changesTiles: true,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final sceneIdx = scenes.indexWhere((s) => s.id == sceneId);
    if (sceneIdx < 0) return;
    final scene = scenes[sceneIdx];
    if (oldIndicesInNewOrder.length != scene.frames.length) return;
    final oldToNew = <int, int>{
      for (int newIdx = 0; newIdx < oldIndicesInNewOrder.length; newIdx++)
        oldIndicesInNewOrder[newIdx]: newIdx,
    };
    if (oldToNew.length != scene.frames.length ||
        oldToNew.keys.any(
          (index) => index < 0 || index >= scene.frames.length,
        )) {
      return;
    }

    final tm = _tilesOf(projectId);
    if (tm != null) {
      // 入れ替えでの衝突を避けるため、いったん一時キーへ退避してから最終位置へ
      // 付け替える。
      final tempToFinal = <String, String>{};
      for (int newIdx = 0; newIdx < oldIndicesInNewOrder.length; newIdx++) {
        final oldIdx = oldIndicesInNewOrder[newIdx];
        for (final layer in scene.frames[oldIdx].layers) {
          final oldKey = frameLayerKey(sceneId, oldIdx, layer.id);
          final tempKey = '__reorder_tmp__${oldIdx}_${layer.id}';
          tm.renameKey(oldKey, tempKey);
          tempToFinal[tempKey] = frameLayerKey(sceneId, newIdx, layer.id);
        }
      }
      tempToFinal.forEach(
        (tempKey, finalKey) => tm.renameKey(tempKey, finalKey),
      );
    }

    final newFrames = <Frame>[
      for (int newIdx = 0; newIdx < oldIndicesInNewOrder.length; newIdx++)
        scene.frames[oldIndicesInNewOrder[newIdx]].copyWith(index: newIdx),
    ];
    scenes[sceneIdx] = _remapFrameAnchors(scene, newFrames, (i) => oldToNew[i]);

    // 表示範囲レイヤーのホームインデックスも新しい並び順へ追従させる
    final homes = _layerHomes[projectId];
    if (homes != null) {
      final updates = <String, LayerHome>{};
      homes.forEach((layerId, home) {
        if (home.sceneId == sceneId && oldToNew.containsKey(home.frameIndex)) {
          updates[layerId] = (
            sceneId: sceneId,
            frameIndex: oldToNew[home.frameIndex]!,
          );
        }
      });
      updates.forEach((id, home) => homes[id] = home);
    }
    _saveAsync(projectId);
    notifyListeners();
  }

  // ─── カメラキーフレーム（XY移動・拡大・回転） ─────────────────

  List<CameraKeyframe> cameraKeyframesOf(String projectId, String sceneId) =>
      List.unmodifiable(
        sceneOf(projectId, sceneId)?.cameraKeyframes ?? const [],
      );

  void _updateSceneCameraKeyframes(
    String projectId,
    String sceneId,
    List<CameraKeyframe> keyframes,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "_updateSceneCameraKeyframes",
        () => _updateSceneCameraKeyframes(projectId, sceneId, keyframes),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    final sorted = List<CameraKeyframe>.from(keyframes)
      ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    scenes[idx] = scenes[idx].copyWith(cameraKeyframes: sorted);
    _saveAsync(projectId);
    notifyListeners();
  }

  /// キーフレームを追加する。同じframeIndexが既にあれば置き換える。
  void addCameraKeyframe(String projectId, String sceneId, CameraKeyframe kf) {
    final current = cameraKeyframesOf(projectId, sceneId);
    final without = current
        .where((k) => k.frameIndex != kf.frameIndex)
        .toList();
    _updateSceneCameraKeyframes(projectId, sceneId, [...without, kf]);
  }

  /// 既存キーフレーム（[oldFrameIndex]で特定）を[newKf]で置き換える。
  /// 移動先に別のキーフレームがある場合は変更せず false を返す。
  bool updateCameraKeyframe(
    String projectId,
    String sceneId,
    int oldFrameIndex,
    CameraKeyframe newKf,
  ) {
    final current = cameraKeyframesOf(projectId, sceneId);
    if (!current.any((keyframe) => keyframe.frameIndex == oldFrameIndex) ||
        (oldFrameIndex != newKf.frameIndex &&
            current.any(
              (keyframe) => keyframe.frameIndex == newKf.frameIndex,
            ))) {
      return false;
    }
    final without = current.where((k) => k.frameIndex != oldFrameIndex);
    _updateSceneCameraKeyframes(projectId, sceneId, [...without, newKf]);
    return true;
  }

  void removeCameraKeyframe(String projectId, String sceneId, int frameIndex) {
    final current = cameraKeyframesOf(projectId, sceneId);
    _updateSceneCameraKeyframes(
      projectId,
      sceneId,
      current.where((k) => k.frameIndex != frameIndex).toList(),
    );
  }

  // ─── レイヤーグループ（複数レイヤーを1つのキーフレームでまとめて動かす） ──

  List<LayerGroup> layerGroupsOf(String projectId, String sceneId) =>
      List.unmodifiable(sceneOf(projectId, sceneId)?.groups ?? const []);

  /// [layerId]が所属するグループを返す（無ければnull）。1レイヤーは
  /// 同時に1グループにのみ所属できる想定（新規グループ作成時に他グループ
  /// から自動的に外す）。
  LayerGroup? groupContainingLayer(
    String projectId,
    String sceneId,
    String layerId,
  ) {
    for (final g in layerGroupsOf(projectId, sceneId)) {
      if (g.memberLayerIds.contains(layerId)) return g;
    }
    return null;
  }

  void _updateSceneGroups(
    String projectId,
    String sceneId,
    List<LayerGroup> groups,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "_updateSceneGroups",
        () => _updateSceneGroups(projectId, sceneId, groups),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    scenes[idx] = scenes[idx].copyWith(groups: groups);
    _saveAsync(projectId);
    notifyListeners();
  }

  /// 新規グループを作成する。[memberLayerIds]が既存の他グループに属して
  /// いた場合はそちらから外す（1レイヤーは1グループのみに所属）。
  LayerGroup addLayerGroup(
    String projectId,
    String sceneId,
    String name,
    List<String> memberLayerIds,
  ) {
    final group = LayerGroup(
      id: 'group_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      memberLayerIds: memberLayerIds,
    );
    final cleaned = layerGroupsOf(projectId, sceneId)
        .map(
          (g) => g.copyWith(
            memberLayerIds: g.memberLayerIds
                .where((id) => !memberLayerIds.contains(id))
                .toList(),
          ),
        )
        .where((g) => g.memberLayerIds.isNotEmpty)
        .toList();
    _updateSceneGroups(projectId, sceneId, [...cleaned, group]);
    return group;
  }

  void updateLayerGroup(String projectId, String sceneId, LayerGroup group) {
    final current = layerGroupsOf(projectId, sceneId);
    final without = current.where((g) => g.id != group.id).toList();
    _updateSceneGroups(projectId, sceneId, [...without, group]);
  }

  void removeLayerGroup(String projectId, String sceneId, String groupId) {
    final current = layerGroupsOf(projectId, sceneId);
    _updateSceneGroups(
      projectId,
      sceneId,
      current.where((g) => g.id != groupId).toList(),
    );
  }

  // ─── タイムスタンプ（特定フレームへのワンタップ移動＋コメント） ──────────
  // シーンが範囲を単位にするのに対し、こちらは「瞬間」を指すためのもの。

  List<TimelineMarker> timelineMarkersOf(String projectId, String sceneId) =>
      List.unmodifiable(sceneOf(projectId, sceneId)?.markers ?? const []);

  void _updateSceneMarkers(
    String projectId,
    String sceneId,
    List<TimelineMarker> markers,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "_updateSceneMarkers",
        () => _updateSceneMarkers(projectId, sceneId, markers),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    final sorted = List<TimelineMarker>.from(markers)
      ..sort((a, b) => a.frameIndex.compareTo(b.frameIndex));
    scenes[idx] = scenes[idx].copyWith(markers: sorted);
    _saveAsync(projectId);
    notifyListeners();
  }

  TimelineMarker addTimelineMarker(
    String projectId,
    String sceneId,
    int frameIndex,
    String comment, {
    int? color,
  }) {
    final marker = TimelineMarker(
      id: 'marker_${DateTime.now().microsecondsSinceEpoch}',
      frameIndex: frameIndex,
      comment: comment,
      color: color,
    );
    _updateSceneMarkers(projectId, sceneId, [
      ...timelineMarkersOf(projectId, sceneId),
      marker,
    ]);
    return marker;
  }

  void updateTimelineMarker(
    String projectId,
    String sceneId,
    TimelineMarker marker,
  ) {
    final current = timelineMarkersOf(projectId, sceneId);
    final without = current.where((m) => m.id != marker.id).toList();
    _updateSceneMarkers(projectId, sceneId, [...without, marker]);
  }

  void removeTimelineMarker(String projectId, String sceneId, String markerId) {
    final current = timelineMarkersOf(projectId, sceneId);
    _updateSceneMarkers(
      projectId,
      sceneId,
      current.where((m) => m.id != markerId).toList(),
    );
  }

  // ─── 演出フィルター（タイムライン非破壊編集） ─────────────────

  List<EffectFilterInstance> effectFiltersOf(
    String projectId,
    String sceneId,
  ) =>
      List.unmodifiable(sceneOf(projectId, sceneId)?.effectFilters ?? const []);

  void _updateSceneEffectFilters(
    String projectId,
    String sceneId,
    List<EffectFilterInstance> filters,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "_updateSceneEffectFilters",
        () => _updateSceneEffectFilters(projectId, sceneId, filters),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    scenes[idx] = scenes[idx].copyWith(effectFilters: filters);
    _saveAsync(projectId);
    notifyListeners();
  }

  void addEffectFilter(
    String projectId,
    String sceneId,
    EffectFilterInstance filter,
  ) {
    _updateSceneEffectFilters(projectId, sceneId, [
      ...effectFiltersOf(projectId, sceneId),
      filter,
    ]);
  }

  void updateEffectFilter(
    String projectId,
    String sceneId,
    EffectFilterInstance filter,
  ) {
    final updated = effectFiltersOf(
      projectId,
      sceneId,
    ).map((f) => f.id == filter.id ? filter : f).toList();
    _updateSceneEffectFilters(projectId, sceneId, updated);
  }

  void removeEffectFilter(String projectId, String sceneId, String filterId) {
    _updateSceneEffectFilters(
      projectId,
      sceneId,
      effectFiltersOf(
        projectId,
        sceneId,
      ).where((f) => f.id != filterId).toList(),
    );
  }

  /// 演出フィルターの並び替え（「複数フィルターの適用順」は
  /// タイムライン上の並び順に従うため、並び替えが適用順そのものを変える）。
  void reorderEffectFilters(
    String projectId,
    String sceneId,
    int oldIndex,
    int newIndex,
  ) {
    final list = effectFiltersOf(projectId, sceneId).toList();
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _updateSceneEffectFilters(projectId, sceneId, list);
  }

  // ─── 音声トラック（タイムライン音声クリップ） ─────────────────
  // シーンに直接紐づく（音声は視覚的なピクセルを持たずレイヤーではないため）。

  List<AudioClip> audioClipsOf(String projectId, String sceneId) =>
      List.unmodifiable(sceneOf(projectId, sceneId)?.audioClips ?? const []);

  void _updateSceneAudioClips(
    String projectId,
    String sceneId,
    List<AudioClip> clips,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "_updateSceneAudioClips",
        () => _updateSceneAudioClips(projectId, sceneId, clips),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    scenes[idx] = scenes[idx].copyWith(audioClips: clips);
    _saveAsync(projectId);
    notifyListeners();
  }

  void addAudioClip(String projectId, String sceneId, AudioClip clip) {
    _updateSceneAudioClips(projectId, sceneId, [
      ...audioClipsOf(projectId, sceneId),
      clip,
    ]);
  }

  void updateAudioClip(String projectId, String sceneId, AudioClip clip) {
    final updated = audioClipsOf(
      projectId,
      sceneId,
    ).map((c) => c.id == clip.id ? clip : c).toList();
    _updateSceneAudioClips(projectId, sceneId, updated);
  }

  void removeAudioClip(String projectId, String sceneId, String clipId) {
    _updateSceneAudioClips(
      projectId,
      sceneId,
      audioClipsOf(projectId, sceneId).where((c) => c.id != clipId).toList(),
    );
  }

  // ─── 素材タイムライン行（画像・動画・音源） ────────────────────
  // タイムライン右側の＋マークは素材の追加ではなく行の追加、二列目以降は
  // －マークで行削除、行名はタップで変更可能。
  // 行数・行名はScene.imageRowNames/videoRowNames/audioRowNames（リスト長＝
  // 行数、要素は行名。nullなら既定表示）で管理する。

  List<String?> rowNamesOf(
    String projectId,
    String sceneId,
    TimelineRowKind type,
  ) {
    final scene = sceneOf(projectId, sceneId);
    if (scene == null) return const [null];
    final names = switch (type) {
      TimelineRowKind.image => scene.imageRowNames,
      TimelineRowKind.video => scene.videoRowNames,
      TimelineRowKind.audio => scene.audioRowNames,
      TimelineRowKind.text => scene.textRowNames,
    };
    return names.isEmpty ? const [null] : names;
  }

  Scene _applyRowNames(
    Scene scene,
    TimelineRowKind type,
    List<String?> names,
  ) => switch (type) {
    TimelineRowKind.image => scene.copyWith(imageRowNames: names),
    TimelineRowKind.video => scene.copyWith(videoRowNames: names),
    TimelineRowKind.audio => scene.copyWith(audioRowNames: names),
    TimelineRowKind.text => scene.copyWith(textRowNames: names),
  };

  /// scene直下のtimelineImage/timelineVideoレイヤー（ホームがこのシーンに
  /// あるもの）を列挙する。素材タイムライン行のクリップ有無判定に使う。
  List<Layer> _materialLayersInScene(
    String projectId,
    String sceneId,
    LayerType type,
  ) {
    final homes = _layerHomes[projectId];
    final scene = sceneOf(projectId, sceneId);
    if (homes == null || scene == null) return const [];
    final result = <Layer>[];
    for (final entry in homes.entries) {
      final home = entry.value;
      if (home.sceneId != sceneId || home.frameIndex >= scene.frames.length) {
        continue;
      }
      final layer = scene.frames[home.frameIndex].layers
          .where((l) => l.id == entry.key)
          .firstOrNull;
      if (layer != null && layer.type == type) result.add(layer);
    }
    return result;
  }

  void addTrackRow(String projectId, String sceneId, TimelineRowKind type) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "addTrackRow",
        () => addTrackRow(projectId, sceneId, type),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    final updated = [...rowNamesOf(projectId, sceneId, type), null];
    scenes[idx] = _applyRowNames(scenes[idx], type, updated);
    _saveAsync(projectId);
    notifyListeners();
  }

  /// [rowIndex]の行を削除する。先頭行（0）は削除不可。その行にクリップが
  /// 存在する場合も削除できず、falseを返す（呼び出し元で案内を表示する）。
  bool removeTrackRow(
    String projectId,
    String sceneId,
    TimelineRowKind type,
    int rowIndex,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      return editTimeline(
        projectId,
        "removeTrackRow",
        () => removeTrackRow(projectId, sceneId, type, rowIndex),
        changesTiles: true,
      );
    }
    final names = rowNamesOf(projectId, sceneId, type);
    if (rowIndex <= 0 || rowIndex >= names.length) return false;
    final layerType = type.layerType;
    final hasClips = layerType == null
        ? audioClipsOf(projectId, sceneId).any((c) => c.trackRow == rowIndex)
        : _materialLayersInScene(
            projectId,
            sceneId,
            layerType,
          ).any((l) => l.trackRow == rowIndex);
    if (hasClips) return false;

    final scenes = _scenes[projectId];
    if (scenes == null) return false;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return false;

    final updatedNames = List<String?>.of(names)..removeAt(rowIndex);
    var scene = _applyRowNames(scenes[idx], type, updatedNames);

    // rowIndexより後ろの行の割り当てを1つずつ詰める
    if (layerType == null) {
      final updatedClips = scene.audioClips
          .map(
            (c) => c.trackRow > rowIndex
                ? c.copyWith(trackRow: c.trackRow - 1)
                : c,
          )
          .toList();
      scene = scene.copyWith(audioClips: updatedClips);
    } else {
      final targetType = layerType;
      final newFrames = scene.frames.map((f) {
        final newLayers = f.layers.map((l) {
          if (l.type == targetType && l.trackRow > rowIndex) {
            return l.copyWith(trackRow: l.trackRow - 1);
          }
          return l;
        }).toList();
        return f.copyWith(layers: newLayers);
      }).toList();
      scene = scene.copyWith(frames: newFrames);
    }
    scene = scene.copyWith(
      stack: _stackWithoutRow(scene.stack, type, rowIndex),
    );

    scenes[idx] = scene;
    _saveAsync(projectId);
    notifyListeners();
    return true;
  }

  /// [stack] after row [rowIndex] of [type] was removed: the row leaves
  /// the order, and the rows after it move up one, as their materials do.
  SceneStack _stackWithoutRow(
    SceneStack stack,
    TimelineRowKind type,
    int rowIndex,
  ) {
    final kind = switch (type) {
      TimelineRowKind.text => StackTrackKind.text,
      TimelineRowKind.image => StackTrackKind.image,
      TimelineRowKind.video => StackTrackKind.video,
      TimelineRowKind.audio => null,
    };
    if (kind == null || stack.isEmpty) return stack;
    List<String> renumber(List<String> order) => [
      for (final key in order)
        if (parseStackTrackKey(key) case final t?
            when t.kind == kind && t.row >= rowIndex) ...[
          if (t.row > rowIndex) stackTrackKey(kind, t.row - 1),
        ] else
          key,
    ];
    return stack.copyWith(
      order: renumber(stack.order),
      ranges: [
        for (final r in stack.ranges) r.copyWith(order: renumber(r.order)),
      ],
    );
  }

  void renameTrackRow(
    String projectId,
    String sceneId,
    TimelineRowKind type,
    int rowIndex,
    String? name,
  ) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "renameTrackRow",
        () => renameTrackRow(projectId, sceneId, type, rowIndex, name),
        changesTiles: false,
      );
      return;
    }
    final scenes = _scenes[projectId];
    if (scenes == null) return;
    final idx = scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;
    final names = List<String?>.of(rowNamesOf(projectId, sceneId, type));
    if (rowIndex < 0 || rowIndex >= names.length) return;
    names[rowIndex] = (name == null || name.isEmpty) ? null : name;
    scenes[idx] = _applyRowNames(scenes[idx], type, names);
    _saveAsync(projectId);
    notifyListeners();
  }

  // ─── レイヤー結合 ─────────────────────────────────────────────────────

  /// 結合可能なレイヤー種別。共通レイヤー・フォルダ・
  /// タイムライン素材（画像/動画/ウォーターマーク）・テキストは結合不可。
  static const _mergeableLayerTypes = {
    LayerType.normal,
    LayerType.autoFillLineart,
    LayerType.autoFill,
  };

  /// 選択したレイヤー群を1枚の通常レイヤーへ結合する。
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
    if (indices.any((i) => !_mergeableLayerTypes.contains(layers[i].type))) {
      return;
    }

    indices.sort();
    final bottomIndex = indices.last;
    final bottomLayer = layers[bottomIndex];
    final selectedLayers = indices.map((i) => layers[i]).toList();

    final tm = _tilesOf(projectId);
    Uint8List? mergedPixels;
    if (tm != null) {
      final mergedImage = await LayerCompositor.composite(
        tm,
        selectedLayers,
        (layer) => frameLayerKey(sceneId, frameIndex, layer.id),
        tm.canvasWidth,
        tm.canvasHeight,
      );
      try {
        final data = await mergedImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (data == null) return;
        mergedPixels = Uint8List.sublistView(data);
      } finally {
        mergedImage.dispose();
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
    final current = scene.frames[frameIndex].layers;
    if (!selectedLayers.every(current.contains)) return;
    editTimeline(projectId, 'Merge layers', () {
      if (tm != null && mergedPixels != null) {
        tm.replaceLayerPixels(
          frameLayerKey(sceneId, frameIndex, bottomLayer.id),
          mergedPixels,
        );
        for (final layer in selectedLayers) {
          if (layer.id != bottomLayer.id) {
            tm.removeLayer(frameLayerKey(sceneId, frameIndex, layer.id));
          }
        }
      }
      final removeIds = selectedLayers
          .map((layer) => layer.id)
          .where((id) => id != bottomLayer.id)
          .toSet();
      final latestLayers = current
          .where((layer) => !removeIds.contains(layer.id))
          .toList();
      final insertAt = latestLayers.indexOf(bottomLayer);
      latestLayers[insertAt] = bottomLayer.copyWith(
        type: LayerType.normal,
        partId: null,
        needsAutofillUpdate: false,
      );
      _applyFrameUpdate(projectId, sceneIdx, frameIndex, latestLayers);
    });
  }

  /// 通常レイヤーを共通レイヤーへ変換する（共通レイヤー化ダイアログ
  /// 「現在レイヤーを共通化」）。既存のピクセルデータ・位置はそのまま、
  /// 変換した時点のフレームを新しいホーム位置として登録する。
  void convertLayerToCommon({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required Layer layer,
    required LayerRangeMode rangeMode,
    required int rangeStart,
    required int rangeEnd,
    String? rangeSceneId,
  }) {
    editTimeline(projectId, 'Convert layer to common', () {
      updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layer: layer.copyWith(
          type: LayerType.common,
          rangeMode: rangeMode,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          rangeSceneId: rangeSceneId,
        ),
      );
      (_layerHomes[projectId] ??= {})[layer.id] = (
        sceneId: sceneId,
        frameIndex: frameIndex,
      );
      notifyListeners();
    }, changesTiles: false);
  }

  /// 表示中の全レイヤーを1枚に統合し、新しい共通レイヤーとして追加する
  /// （共通レイヤー化ダイアログ「表示中レイヤーを複製して全統合して
  /// 共通化」）。元のレイヤーは変更しない。
  Future<void> addFlattenedCommonLayer({
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required LayerRangeMode rangeMode,
    required int rangeStart,
    required int rangeEnd,
    String? rangeSceneId,
  }) async {
    final tm = _tilesOf(projectId);
    if (tm == null) return;
    final layers = layersOf(projectId, sceneId, frameIndex);
    if (layers.isEmpty) return;
    final flattened = await LayerCompositor.composite(
      tm,
      layers,
      (l) => tileKeyFor(projectId, sceneId, frameIndex, l.id),
      tm.canvasWidth,
      tm.canvasHeight,
    );
    final byteData = await flattened.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    flattened.dispose();
    if (byteData == null) return;

    if (frameIndex >= frameCount(projectId, sceneId)) return;
    editTimeline(projectId, 'Add flattened common layer', () {
      final visible = layers.where((l) => l.parentFolderId == null).length;
      final created = addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        type: LayerType.common,
        name: '共通${visible + 1}',
      );
      tm.replaceLayerPixels(
        frameLayerKey(sceneId, frameIndex, created.id),
        byteData.buffer.asUint8List(),
      );
      updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layer: created.copyWith(
          rangeMode: rangeMode,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          rangeSceneId: rangeSceneId,
        ),
      );
    });
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
    List<String>? enabledAutofillPresetIds,
    bool makingEnabled = false,
  }) async {
    final projectId = _nextId('proj');
    // 作成と最終保存は同じ1回の時刻（別々に読むと数マイクロ秒ずれ、その値が
    // 初めての保存でファイルにも書かれた）。
    final now = DateTime.now();
    final project = Project(
      id: projectId,
      name: name,
      fps: fps,
      durationSeconds: durationSeconds,
      backgroundColor: backgroundColor,
      createdAt: now,
      updatedAt: now,
      totalWorkSeconds: 0,
      exportWidth: exportWidth,
      exportHeight: exportHeight,
      drawingAreaScale: drawingAreaScale.clamp(1.0, 10.0),
      enabledAutofillPresetIds: enabledAutofillPresetIds,
      makingEnabled: makingEnabled,
    );
    // 初期シーン・フレーム・レイヤーを生成（Scene0001/Frame0/Layer0001）
    final initialLayer = Layer(
      id: 'Layer0001',
      name: 'レイヤー1',
      localizedStarterName: true,
      type: LayerType.normal,
    );
    final initialFrame = Frame(index: 0, layers: [initialLayer]);
    final totalFrames = fps * durationSeconds;
    final frames = List.generate(
      totalFrames,
      (i) => i == 0 ? initialFrame : Frame(index: i, layers: [initialLayer]),
    );
    final scenes = [Scene(id: 'Scene0001', index: 0, frames: frames)];

    // TileManager 初期化
    final tileManager = TileManager(
      canvasWidth: project.drawingWidth,
      canvasHeight: project.drawingHeight,
      compositeCacheMax: _tileCacheBudget,
    );

    // 編集へ進める前に、再起動後も復元できる初回保存を完了する。
    final File saved;
    try {
      saved = await NiaproSerializer.save(
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        // 一覧に出す作品と同じ最終保存の日時をファイルへ書く。
        updatedAt: project.updatedAt,
      );
    } catch (_) {
      tileManager.dispose();
      rethrow;
    }
    final created = project.copyWith(sizeBytes: saved.lengthSync());

    _projects.add(created);
    _scenes[projectId] = scenes;
    _tileManagers[projectId] = tileManager;
    _layerIdCounters[projectId] = 2;

    notifyListeners();
    return created;
  }

  final Map<String, Future<void>> _projectSaves = {};
  final Map<String, int> _favoriteChanges = {};
  bool isFavoriteSaving(String id) => (_favoriteChanges[id] ?? 0) > 0;
  Future<void>? _folderOperations;
  bool _folderDisposed = false;

  Future<T> _queueProjectSave<T>(String id, Future<T> Function() write) {
    final previous = _projectSaves[id];
    final result = previous == null
        ? Future<T>.sync(write)
        : previous.then((_) => write());
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _projectSaves[id] = settled;
    return result.whenComplete(() {
      if (identical(_projectSaves[id], settled)) _projectSaves.remove(id);
    });
  }

  /// 並んでいる作品の保存・フォルダの処理がすべて終わるまで待つ（全データを
  /// 削除する前。削除の後に書き終わると、消した作品・フォルダが戻る）。
  Future<void> settleWrites() async {
    while (_projectSaves.isNotEmpty || _folderOperations != null) {
      await Future.wait([..._projectSaves.values, ?_folderOperations]);
    }
  }

  Future<T> _queueFolder<T>(Future<T> Function() write) {
    if (_folderDisposed) {
      return Future.error(StateError('Project folders disposed'));
    }
    final result = _folderOperations == null
        ? Future<T>.sync(write)
        : _folderOperations!.then((_) => write());
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _folderOperations = settled;
    // 何も並んでいなければ、次の処理はすぐに始める（作品の保存の列と
    // 同じ）。作品を読み込むたびにこの列を通るので、終わった処理へ
    // つなぎ続けない。
    settled.whenComplete(() {
      if (identical(_folderOperations, settled)) _folderOperations = null;
    });
    return result;
  }

  Future<void> _queueTrash(String id, Future<void> Function() operation) =>
      _queueFolder(
        () => _queueProjectSave(id, () async {
          try {
            await operation();
          } catch (error, stackTrace) {
            AppErrorReporter.record(error, stackTrace);
            rethrow;
          }
        }),
      );

  void _notifyFolders() {
    if (!_folderDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _folderDisposed = true;
    _workTimer?.cancel();
    super.dispose();
  }

  /// Read the current model when the queued save starts. A background save
  /// requested during a folder move must not overwrite its acknowledged result.
  void _saveAsync(String projectId, {bool keepUpdatedAt = false}) {
    _queueProjectSave(
      projectId,
      () => _writeProjectFile(projectId, keepUpdatedAt: keepUpdatedAt),
    ).catchError((Object _, StackTrace _) {});
  }

  Future<void> saveProject(String projectId) =>
      _queueProjectSave(projectId, () => _writeProjectFile(projectId));

  /// ゴミ箱へ移す前の保存（書き終わるまで待ち、読める作品だけをゴミ箱へ
  /// 移す）。ゴミ箱へ移すのは作品の変更ではないので、最終保存の日時
  /// （「更新日時」の並びに使う）は変えない。以前は移すたびに今の日時に
  /// なり、「元に戻す」で戻した作品が一覧の先頭へ動いた。
  Future<void> _saveBeforeTrash(String projectId) => _queueProjectSave(
    projectId,
    () => _writeProjectFile(projectId, keepUpdatedAt: true),
  );

  Future<void> _writeProjectFile(
    String projectId, {
    bool keepUpdatedAt = false,
  }) async {
    final project = _projects.where((p) => p.id == projectId).firstOrNull;
    final scenes = _scenes[projectId];
    final rewrite = _needsArchiveRewrite.contains(projectId);
    // A work not opened since it was listed keeps the tiles of its file.
    final keepStoredTiles = !rewrite && _tilesLeftInFile.containsKey(projectId);
    final tm = keepStoredTiles ? _tileManagers[projectId] : _tilesOf(projectId);
    if (project == null || scenes == null || tm == null) return;
    if (_unreadableTiles.contains(projectId)) {
      throw FileSystemException(
        'The picture of this work could not be read; its file is kept as is',
        projectId,
      );
    }
    // 最終保存の日時は1回だけ読み、ファイルと一覧の両方へ同じ値を書く
    // （別々に読むと数ミリ秒ずれ、ゴミ箱へ移す前の保存〔一覧の値を書く〕が
    // 作品を変えていないのにファイルを書き換えた）。
    final updatedAt = keepUpdatedAt ? project.updatedAt : DateTime.now();
    final saved = await NiaproSerializer.save(
      project: project,
      scenes: scenes,
      tileManager: tm,
      updatedAt: updatedAt,
      rewrite: rewrite,
      keepStoredTiles: keepStoredTiles,
    );
    _needsArchiveRewrite.remove(projectId);
    // 容量と最終保存の時刻は、ファイルに書いたものに合わせる。保存は
    // 描いている間にも走るので、通知はせず次に画面を作るときに使われる
    // 値だけを更新する。
    final size = saved.lengthSync();
    final i = _projects.indexWhere((p) => p.id == projectId);
    if (i >= 0) {
      _projects[i] = _projects[i].copyWith(
        sizeBytes: size,
        updatedAt: keepUpdatedAt ? null : updatedAt,
      );
    }
  }

  /// [saveProject]と同じ保存。保存できたかを返す（失敗しても例外にしない）。
  Future<bool> _saveReportingSuccess(String projectId) {
    if (!_projects.any((p) => p.id == projectId)) return Future.value(false);
    return saveProject(
      projectId,
    ).then((_) => true, onError: (Object _, StackTrace _) => false);
  }

  Future<void> _saveMembership(
    String id,
    String? folderId, {
    bool shared = false,
  }) => _queueProjectSave(id, () async {
    final project = [
      ..._projects,
      ..._trash,
    ].where((p) => p.id == id).firstOrNull;
    if (project == null) return;
    await NiaproSerializer.saveFolderMembership(
      projectId: id,
      folderId: folderId,
      shared: shared,
    );
    // Merge only membership into the latest model; do not discard edits that
    // arrived while I/O was pending, or resurrect a project moved to the trash.
    for (final list in [_projects, _trash]) {
      final i = list.indexWhere((p) => p.id == id);
      if (i >= 0) {
        list[i] = shared
            ? list[i].copyWith(sharedFolderId: folderId)
            : list[i].copyWith(folderId: folderId);
      }
    }
  });

  Future<void> deleteProject(String id) => _queueTrash(id, () async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      // Check inside both queues: a project may become a favorite while a
      // previous save or Trash operation is still awaiting acknowledgement.
      if (_projects[idx].isFavorite) {
        throw const FavoriteProjectDeleteException();
      }
      // Save the latest work before changing membership. The project save
      // queue is already held; enqueueing _saveBeforeTrash here would wait
      // for this operation itself. A refused move must never write a file.
      await _writeProjectFile(id, keepUpdatedAt: true);
      final next = {..._trashDeletedAt, id: DateTime.now()};
      await _persistTrashState(next);
      _moveProjectToTrash(_projects.indexWhere((p) => p.id == id));
      _trashDeletedAt
        ..clear()
        ..addAll(next);
      _notifyFolders();
    }
  });

  /// [index]の作品をゴミ箱へ移す（ゴミ箱の記録の保存と通知は呼び出し側）。
  void _moveProjectToTrash(int index) {
    final project = _projects.removeAt(index);
    final id = project.id;
    _trash.add(project);
    _scenes.remove(id);
    _layerFolderExpansion.remove(id);
    _layerIdCounters.remove(id);
    _layerHomes.remove(id);
    _tileManagers.remove(id)?.dispose();
    _forgetTiles(id);
  }

  Future<void> restoreProject(String id) =>
      _queueTrash(id, () => _restoreProjectNow(id));

  /// [restoreProject]の中身。フォルダの列に並ばないので、フォルダの処理
  /// （[restoreTrashedFolder]）の中からは作品の保存の列だけを通して呼ぶ。
  Future<void> _restoreProjectNow(String id) async {
    final idx = _trash.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      // ゴミ箱にある間にメモリ上で付け替えたサムネイル（複製元の完全削除）。
      final trashedEntry = _trash[idx];
      final basePath = await NiaproSerializer.projectsBasePath();
      ProjectTrashGuard.fileFor(basePath, id);
      final file = File('$basePath/$id/$id.niapro');
      late final NiaproData data;
      try {
        data = await NiaproSerializer.load(file.path);
        if (data.project.id != id) {
          throw const FormatException('Restored project ID does not match');
        }
      } catch (_) {
        try {
          // Preserve a named, retryable Trash row across restart even when the
          // unreadable archive cannot supply its own display metadata.
          await ProjectTrashGuard.write(
            basePath,
            _trash[idx],
            _trashDeletedAt[id] ?? DateTime.now(),
          );
        } catch (error, stackTrace) {
          AppErrorReporter.record(error, stackTrace);
        }
        rethrow;
      }
      // ゴミ箱にある間に入っていたフォルダが無くなっていれば（削除した・
      // ゴミ箱へ移した）一番上へ戻す（消えたフォルダを指したままだと一覧の
      // どこにも出ず、検索でしか見つからなかった）。作品の保存にも、ゴミ箱の
      // 記録を変える前に書く（後で書くと、書き終わる前にアプリが終わった
      // とき、次の起動でゴミ箱へ移したフォルダへ入った）。
      final saved = data.project;
      final leaveFolder =
          saved.folderId != null &&
          !_folders.any((f) => f.id == saved.folderId);
      final leaveSharedFolder =
          saved.isSharedImport &&
          saved.sharedFolderId != null &&
          !_sharedFolders.any((f) => f.id == saved.sharedFolderId);
      var project = saved.copyWith(sizeBytes: await file.length());
      if (leaveFolder) project = project.copyWith(folderId: null);
      if (leaveSharedFolder) project = project.copyWith(sharedFolderId: null);
      final homes = buildLayerHomeIndex(data.scenes);
      final counter = _maxLayerCounter(data.scenes);
      final tm = TileManager(
        canvasWidth: project.drawingWidth,
        canvasHeight: project.drawingHeight,
        compositeCacheMax: _tileCacheBudget,
      );
      var committed = false;
      try {
        tm.importAll(data.tileData);
        if (leaveFolder) {
          await NiaproSerializer.saveFolderMembership(
            projectId: id,
            folderId: null,
          );
        }
        if (leaveSharedFolder) {
          await NiaproSerializer.saveFolderMembership(
            projectId: id,
            folderId: null,
            shared: true,
          );
        }
        // A readable archive makes a previous partial-cleanup record unnecessary.
        // Remove it before changing preferences: a rejected write still leaves
        // the complete archive and its old Trash membership intact.
        await ProjectTrashGuard.remove(basePath, id);
        final next = {..._trashDeletedAt}..remove(id);
        await _persistTrashState(next);
        _trash.removeAt(idx);
        _projects.add(project);
        _trashDeletedAt
          ..clear()
          ..addAll(next);
        _scenes[id] = data.scenes;
        _layerHomes[id] = homes;
        _layerIdCounters[id] = counter;
        _tileManagers.remove(id)?.dispose();
        _tileManagers[id] = tm;
        _forgetTiles(id);
        committed = true;
        _notifyFolders();
      } finally {
        if (!committed) tm.dispose();
      }
      if (committed) {
        // ゴミ箱にある間のサムネイルの付け替えも合わせて保存する。
        final i = _projects.indexWhere((p) => p.id == id);
        if (i >= 0) {
          final restored = _projects[i];
          if (trashedEntry.thumbnailPath != null &&
              trashedEntry.thumbnailPath != restored.thumbnailPath) {
            _projects[i] = restored.copyWith(
              thumbnailPath: trashedEntry.thumbnailPath,
            );
            _saveAsync(id);
          }
        }
      }
    }
  }

  Future<void> permanentDelete(String id) =>
      _queueTrash(id, () => _permanentDeleteNow(id));

  /// [permanentDelete]の中身（フォルダの処理の中から呼ぶとき用。
  /// [_restoreProjectNow]と同じ）。
  Future<void> _permanentDeleteNow(String id) async {
    final idx = _trash.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      final project = _trash[idx];
      // A refused metadata write must stop before touching any content. Keep the
      // old Trash membership until filesystem deletion succeeds, so a failed
      // recursive delete never needs a fallible preference rollback.
      await _persistTrashState(_trashDeletedAt);
      final basePath = await NiaproSerializer.projectsBasePath();
      await ProjectTrashGuard.write(
        basePath,
        project,
        _trashDeletedAt[id] ?? DateTime.now(),
      );
      final dir = Directory('$basePath/$id');
      final type = await FileSystemEntity.type(dir.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await _keepSharedThumbnails(dir.path);
        try {
          await dir.delete(recursive: true);
        } finally {
          // 容量削減の画面が覚えている集計結果は、消す前のもの（途中で
          // 失敗しても、消せた分だけ大きさは変わっている）。
          StorageInfoService().invalidate();
        }
      } else if (type != FileSystemEntityType.notFound) {
        throw FileSystemException('Project path is not a directory', dir.path);
      }
      _trash.removeAt(idx);
      _trashDeletedAt.remove(id);
      _undoManager?.discardProject(id);
      _removedLayers.remove(id);
      _scenes.remove(id);
      _layerFolderExpansion.remove(id);
      _layerHomes.remove(id);
      _layerIdCounters.remove(id);
      _tileManagers.remove(id)?.dispose();
      _forgetTiles(id);
      try {
        await _persistTrashState(_trashDeletedAt);
      } catch (error, stackTrace) {
        // The requested content is already gone. A stale ID cannot resurrect a
        // missing directory; init() prunes and retries this metadata cleanup.
        AppErrorReporter.record(error, stackTrace);
      }
      try {
        await ProjectTrashGuard.remove(basePath, id);
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
      }
      _notifyFolders();
    }
  }

  /// 以前の版で複製した作品は、複製元のフォルダにあるサムネイルを指して
  /// いる。複製元を完全に削除する前に、そのファイルを使っている作品へ
  /// 写しておく（写さないと、複製の一覧の絵が消えた）。ゴミ箱の作品は
  /// メモリ上だけ付け替え、戻したときに保存する。
  Future<void> _keepSharedThumbnails(String dirPath) async {
    final prefix = '$dirPath${Platform.pathSeparator}';
    for (final list in [_projects, _trash]) {
      final sharing = [
        for (final p in list)
          if (p.thumbnailPath?.startsWith(prefix) ?? false) p,
      ];
      for (final project in sharing) {
        final copied = await NiaproSerializer.copyProjectFiles(
          fromProjectId: project.id,
          toProjectId: project.id,
          thumbnailPath: project.thumbnailPath,
          includeMaterials: false,
        );
        final i = list.indexWhere((p) => p.id == project.id);
        if (i < 0) continue;
        list[i] = list[i].copyWith(thumbnailPath: copied);
        _saveAsync(project.id);
      }
    }
  }

  Future<void> renameProject(String id, String newName) async {
    editTimeline(id, 'Rename project', () {
      final idx = _projects.indexWhere((p) => p.id == id);
      if (idx >= 0 && _projects[idx].name != newName) {
        _projects[idx] = _projects[idx].copyWith(name: newName);
        _saveAsync(id);
        notifyListeners();
      }
    }, changesTiles: false);
  }

  void setProjectEndCardHidden(String projectId, bool hidden) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "setProjectEndCardHidden",
        () => setProjectEndCardHidden(projectId, hidden),
        changesTiles: false,
      );
      return;
    }
    final index = _projects.indexWhere((project) => project.id == projectId);
    if (index < 0 || _projects[index].hideEndCard == hidden) return;
    _projects[index] = _projects[index].copyWith(hideEndCard: hidden);
    _saveAsync(projectId);
    notifyListeners();
  }

  /// プロジェクトの背景色を変更する（キャンバス設定メニューから）。
  void updateProjectBackgroundColor(String projectId, int color) {
    if (!_recordingTimelineEdits.contains(projectId) && _undoManager != null) {
      editTimeline(
        projectId,
        "updateProjectBackgroundColor",
        () => updateProjectBackgroundColor(projectId, color),
        changesTiles: false,
      );
      return;
    }
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx < 0 || _projects[idx].backgroundColor == color) return;
    _projects[idx] = _projects[idx].copyWith(backgroundColor: color);
    _saveAsync(projectId);
    notifyListeners();
  }

  /// [useTargetFolder]がtrueの場合、複製先のフォルダを[targetFolderId]
  /// （nullはルート直下）で明示的に上書きする。falseの場合（既定）は
  /// 複製元と同じフォルダのまま複製する。
  ///
  /// [name]は複製の名前。省略すると[namer]（画面の言語の「〇〇 (コピー)」と
  /// 番号）で、[namer]も省略すると日本語の「(コピー)」で付ける。番号は
  /// 同じ区分（共有から取り込んだ作品か）の作品の名前と重ならないように
  /// 付ける。[namer]は素材を写し終えて複製を一覧へ加える直前に呼ぶ。
  /// 複製したかどうかを返す（元の作品が見つからなければfalse）。
  Future<bool> duplicateProject(
    String id, {
    String? targetFolderId,
    bool useTargetFolder = false,
    String? targetSharedFolderId,
    bool useTargetSharedFolder = false,
    String? name,
    CopyNamer? namer,
  }) async {
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      final original = _projects[idx];
      final newId = _nextId('proj');

      // シーンリストは複製先専用の新しいListにする（Scene/Frame/Layerはimmutableなため
      // 中身の値オブジェクト自体は共有してよいが、外側のListを共有すると片方への
      // 変更（scenes[i] = ...）がもう片方にも波及してしまうため独立させる）。
      // 素材を写している間に複製元が編集・削除されても、押した時点の内容を
      // 複製するよう、ここで写し取っておく。
      final scenes = _scenes[id] == null
          ? null
          : List<Scene>.from(_scenes[id]!);
      // レイヤーIDカウンターも引き継がないと、複製後に新規追加したレイヤーのIDが
      // 複製元から引き継いだ既存レイヤーIDと衝突する。
      final layerIdCounter = _layerIdCounters[id];
      // 描画データ（タイル）も複製先IDへコピーする。TileManager.importAllは
      // ピクセルバッファをUint8List.fromListで複製するため、複製元・複製先は
      // 完全に独立したバッファになる。
      final sourceTm = _tilesOf(id);
      if (_unreadableTiles.contains(id)) {
        // An empty copy of a picture that could not be read is not a copy.
        throw FileSystemException(
          'The picture of this work could not be read',
          id,
        );
      }
      final newTm = TileManager(
        canvasWidth: original.drawingWidth,
        canvasHeight: original.drawingHeight,
        compositeCacheMax: _tileCacheBudget,
      );
      if (sourceTm != null) {
        newTm.importAll(sourceTm.exportAll());
      }

      // 素材（画像・動画・音声）とサムネイルのファイルを先に複製先へ写す
      // （写さないと、素材を使った作品の複製は素材が「不足」になった）。
      // 写し終えるまで複製を一覧に出さない：途中で開くと素材が無いと
      // 判断され、そこで足した素材が写している素材で上書きされた。
      // 写している途中でアプリが終わっても、保存データ（.niapro）の無い
      // フォルダは起動時に読み飛ばされる。
      final thumbnail = await NiaproSerializer.copyProjectFiles(
        fromProjectId: id,
        toProjectId: newId,
        thumbnailPath: original.thumbnailPath,
      );

      // Repeated paste must not create indistinguishable copies. 名前は
      // 写し終えて一覧へ加える直前の一覧で決める（押した時点で決めると、
      // 写している間にもう一度複製したとき同じ名前が2つできた）。
      final copyName =
          name ??
          (namer ?? _nextCopyName)(original.name, {
            for (final p in _projects)
              if (p.isSharedImport == original.isSharedImport) p.name,
          });
      // 作成と最終保存は同じ1回の時刻（最終保存は直後の保存の時刻になる）。
      final now = DateTime.now();
      final copy = original.copyWith(
        id: newId,
        name: copyName,
        createdAt: now,
        updatedAt: now,
        folderId: useTargetFolder ? targetFolderId : original.folderId,
        sharedFolderId: useTargetSharedFolder
            ? targetSharedFolderId
            : original.sharedFolderId,
        // 複製元と同じファイルを指したままだと、複製元の削除で一緒に消えた。
        thumbnailPath: thumbnail,
      );
      _projects.add(copy);
      if (scenes != null) {
        _scenes[newId] = scenes;
        _layerHomes[newId] = buildLayerHomeIndex(scenes);
      }
      if (layerIdCounter != null) {
        _layerIdCounters[newId] = layerIdCounter;
      }
      _tileManagers[newId] = newTm;

      // A paste must not report success before its project bytes are durable.
      // If saving fails, keep the failed copy out of the library rather than
      // exposing a project that would disappear after relaunch.
      try {
        await saveProject(newId);
      } catch (_) {
        _projects.removeWhere((p) => p.id == newId);
        _scenes.remove(newId);
        _layerHomes.remove(newId);
        _layerIdCounters.remove(newId);
        _tileManagers.remove(newId);
        rethrow;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// キャンバスサイズを変更する（タイムライン三点メニュー「キャンバス
  /// サイズ変更」）。[cropX]・[cropY]は現在の描画キャンバス座標系における
  /// 切り出し開始位置、[newWidth]・[newHeight]は新しい描画キャンバス
  /// サイズ（px）。全フレーム・全レイヤーのピクセルデータを、指定範囲を
  /// 切り出す形で新しいサイズのTileManagerへ移し替える（範囲外にはみ出す
  /// 部分は破棄し、元画像より広い範囲を指定した部分は透明で埋める）。
  /// exportWidth・exportHeightは、描画領域倍率（drawingAreaScale）を
  /// 保ったまま逆算して更新する。
  /// [angleDegrees]が0以外の場合、各レイヤーの合成画像を先に回転（外接矩形
  /// まで自動拡張、はみ出しなし）してから、[cropX]・[cropY]・[newWidth]・
  /// [newHeight]による切り出し／余白追加を行う。回転後の座標系では(0,0)は
  /// 回転後の外接矩形の左上を表す。
  Future<void> resizeCanvas(
    String projectId, {
    required int newWidth,
    required int newHeight,
    required int cropX,
    required int cropY,
    double angleDegrees = 0,
  }) async {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx < 0) return;
    final sourceTm = _tilesOf(projectId);
    if (sourceTm == null) return;

    final newTm = TileManager(
      canvasWidth: newWidth,
      canvasHeight: newHeight,
      compositeCacheMax: _tileCacheBudget,
    );

    final origWidth = sourceTm.canvasWidth;
    final origHeight = sourceTm.canvasHeight;
    for (final key in sourceTm.exportAll().keys.toList()) {
      final image = await sourceTm.compositeLayerToImage(key);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      image.dispose();
      if (byteData == null) continue;
      Uint8List oldBytes = byteData.buffer.asUint8List();
      int oldWidth = origWidth;
      int oldHeight = origHeight;
      if (angleDegrees != 0) {
        final rotated = img.copyRotate(
          img.Image.fromBytes(
            width: origWidth,
            height: origHeight,
            bytes: oldBytes.buffer,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          ),
          angle: angleDegrees,
          interpolation: img.Interpolation.cubic,
        );
        oldWidth = rotated.width;
        oldHeight = rotated.height;
        oldBytes = rotated.getBytes(order: img.ChannelOrder.rgba);
      }
      final newBytes = Uint8List(newWidth * newHeight * 4);
      for (int y = 0; y < newHeight; y++) {
        final srcY = y + cropY;
        if (srcY < 0 || srcY >= oldHeight) continue;
        for (int x = 0; x < newWidth; x++) {
          final srcX = x + cropX;
          if (srcX < 0 || srcX >= oldWidth) continue;
          final srcIdx = (srcY * oldWidth + srcX) * 4;
          final dstIdx = (y * newWidth + x) * 4;
          newBytes[dstIdx] = oldBytes[srcIdx];
          newBytes[dstIdx + 1] = oldBytes[srcIdx + 1];
          newBytes[dstIdx + 2] = oldBytes[srcIdx + 2];
          newBytes[dstIdx + 3] = oldBytes[srcIdx + 3];
        }
      }
      newTm.replaceLayerPixels(key, newBytes);
    }

    final current = _projects.where((p) => p.id == projectId).firstOrNull;
    if (current == null || !identical(_tileManagers[projectId], sourceTm)) {
      return;
    }
    final scale = current.drawingAreaScale <= 0
        ? 1.0
        : current.drawingAreaScale;
    final newExportWidth = (newWidth / scale).round().clamp(64, 1 << 30);
    final newExportHeight = (newHeight / scale).round().clamp(64, 1 << 30);

    // Cropping is explicitly destructive. Future watermark edits start
    // from the cropped raster and the resize history can restore its source.
    final originalScenes = _scenes[projectId];
    final resizedScenes = originalScenes?.map((scene) {
      if (!scene.frames.any(
        (frame) => frame.layers.any((layer) => layer.watermarkSource != null),
      )) {
        return scene;
      }
      return scene.copyWith(
        frames: [
          for (final frame in scene.frames)
            frame.copyWith(
              layers: [
                for (final layer in frame.layers)
                  if (layer.watermarkSource != null)
                    layer.copyWith(watermarkSource: null)
                  else
                    layer,
              ],
            ),
        ],
      );
    }).toList();
    _setResizedCanvas(
      projectId,
      newTm,
      newExportWidth,
      newExportHeight,
      resizedScenes,
    );
    // Pixel history actions retain their TileManager. Restore that exact
    // instance so operations on each side of the resize remain undoable.
    _undoManager?.push(
      ProjectEditUndoAction(
        'Resize canvas',
        () => _setResizedCanvas(
          projectId,
          sourceTm,
          current.exportWidth,
          current.exportHeight,
          originalScenes,
        ),
        () => _setResizedCanvas(
          projectId,
          newTm,
          newExportWidth,
          newExportHeight,
          resizedScenes,
        ),
      ),
      projectId: projectId,
    );
  }

  void _setResizedCanvas(
    String projectId,
    TileManager tiles,
    int exportWidth,
    int exportHeight,
    List<Scene>? scenes,
  ) {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index < 0) return;
    tiles.markAllTilesDirty();
    _tileManagers[projectId] = tiles;
    if (scenes != null) _scenes[projectId] = List.of(scenes);
    _projects[index] = _projects[index].copyWith(
      exportWidth: exportWidth,
      exportHeight: exportHeight,
    );
    _saveAsync(projectId);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) => _changeFavorite(id, null);

  /// Preserve the intent of a menu that may have opened before another save.
  Future<void> setFavorite(String id, bool value) => _changeFavorite(id, value);

  Future<void> _changeFavorite(String id, bool? requestedValue) {
    if (_folderDisposed) return Future.value();
    _favoriteChanges[id] = (_favoriteChanges[id] ?? 0) + 1;
    final change = _queueProjectSave(id, () async {
      final project = _projects.where((p) => p.id == id).firstOrNull;
      if (project == null) return;
      final value = requestedValue ?? !project.isFavorite;
      if (value == project.isFavorite) return;
      try {
        // お気に入りは作品の変更ではないので、保存の印だけを書き換え、最終
        // 保存の日時（「更新日時」の並び・詳細の「最終保存」）と作品の中身は
        // そのまま残す。以前は作品を保存し直し、起動し直すと最終保存が星を
        // 付けた時刻になって、一覧の並びで位置が変わった。
        await NiaproSerializer.saveFavorite(projectId: id, isFavorite: value);
      } on PathNotFoundException {
        // 保存のファイルが無い（アプリの外で消えた）ときは、作品を書き直して
        // 残す（最終保存の日時は前のまま）。
        final scenes = _scenes[id];
        final tileManager = _tilesOf(id);
        try {
          if (scenes == null ||
              tileManager == null ||
              _unreadableTiles.contains(id)) {
            throw StateError('Project content is unavailable for saving');
          }
          await NiaproSerializer.save(
            project: project.copyWith(isFavorite: value),
            scenes: scenes,
            tileManager: tileManager,
            updatedAt: project.updatedAt,
          );
        } catch (error, stackTrace) {
          AppErrorReporter.record(error, stackTrace);
          rethrow;
        }
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
        rethrow;
      }
      // Keep edits made while I/O was pending. Accepted queued operations still
      // need the committed flag after disposal; only notifications are stopped.
      final index = _projects.indexWhere((p) => p.id == id);
      if (index >= 0) {
        _projects[index] = _projects[index].copyWith(isFavorite: value);
      }
    });
    _notifyFolders();
    return change.whenComplete(() {
      final pending = _favoriteChanges[id] ?? 0;
      if (pending <= 1) {
        _favoriteChanges.remove(id);
      } else {
        _favoriteChanges[id] = pending - 1;
      }
      _notifyFolders();
    });
  }

  /// Save the per-project opt-in setting for optional making-history capture.
  Future<void> setMakingEnabled(String projectId, bool enabled) async {
    final index = _projects.indexWhere((project) => project.id == projectId);
    if (index < 0 || _projects[index].makingEnabled == enabled) return;
    _projects[index] = _projects[index].copyWith(makingEnabled: enabled);
    _saveAsync(projectId, keepUpdatedAt: true);
    notifyListeners();
  }

  Future<void> setEnabledAutofillPresetIds(
    String projectId,
    List<String>? ids,
  ) async {
    editTimeline(projectId, 'Choose project autofill presets', () {
      final idx = _projects.indexWhere((p) => p.id == projectId);
      if (idx < 0 || listEquals(_projects[idx].enabledAutofillPresetIds, ids)) {
        return;
      }
      _projects[idx] = _projects[idx].copyWith(
        enabledAutofillPresetIds: ids == null
            ? null
            : List<String>.unmodifiable(ids),
      );
      _saveAsync(projectId);
      notifyListeners();
    }, changesTiles: false);
  }

  Future<void> moveToFolder(String projectId, String? folderId) =>
      _queueFolder(() async {
        if (folderId != null && !_folders.any((f) => f.id == folderId)) {
          throw const FolderSaveException(partiallySaved: false);
        }
        try {
          await _saveMembership(projectId, folderId);
        } catch (error) {
          throw FolderSaveException(partiallySaved: false, cause: error);
        }
        _notifyFolders();
      });

  /// プロジェクトのタグ一覧を置き換える（詳細情報画面のタグ機能）。
  Future<void> setProjectTags(String projectId, List<String> tags) async {
    final project = _projects.where((p) => p.id == projectId).firstOrNull;
    if (project == null || listEquals(project.tags, tags)) return;
    final before = List<String>.unmodifiable(project.tags);
    final after = List<String>.unmodifiable(tags);
    _applyProjectTags(projectId, after);
    if (!_recordingTimelineEdits.contains(projectId)) {
      _undoManager?.push(
        ProjectEditUndoAction(
          'Edit project tags',
          () => _applyProjectTags(projectId, before),
          () => _applyProjectTags(projectId, after),
        ),
        projectId: projectId,
      );
    }
  }

  void _applyProjectTags(String projectId, List<String> tags) {
    final index = _projects.indexWhere((project) => project.id == projectId);
    if (index < 0) return;
    _projects[index] = _projects[index].copyWith(tags: tags);
    _saveAsync(projectId, keepUpdatedAt: true);
    notifyListeners();
  }

  /// プロジェクト一覧カード表示用のサムネイルを生成し、Project.thumbnailPathへ反映する
  /// （先頭シーン・先頭フレームを縮小合成してPNG化する。セーブノードの
  /// サムネイル生成（save_tree_screen.dart）と同じ方式）。
  /// 生成できない場合（シーン・フレームが存在しない等）は何もしない。
  Future<void> generateAndSaveThumbnail(
    String projectId, {
    String? sceneId,
    int? frameIndex,
    bool force = false,
  }) async {
    final idx = _projects.indexWhere((p) => p.id == projectId);

    if (idx < 0) return;
    final project = _projects[idx];
    if (!force && project.thumbnailMode != 'latest') return;
    final scenes = _scenes[projectId];
    final tm = _tilesOf(projectId);
    if (scenes == null || scenes.isEmpty || tm == null) return;
    final requestedScene = sceneId ?? project.thumbnailLastSceneId;
    final scene =
        scenes.where((s) => s.id == requestedScene).firstOrNull ?? scenes.first;
    if (scene.frames.isEmpty) return;
    final position =
        (frameIndex ??
                (requestedScene == scene.id
                    ? project.thumbnailLastFrameIndex
                    : null) ??
                0)
            .clamp(0, scene.frames.length - 1);
    final w = tm.canvasWidth;
    final h = tm.canvasHeight;
    if (w <= 0 || h <= 0) return;

    const thumbMax = 200;
    final scale = thumbMax / math.max(w, h);
    final tw = (w * scale).round().clamp(1, thumbMax);
    final th = (h * scale).round().clamp(1, thumbMax);

    final layers = layersOf(projectId, scene.id, position);
    final fullImage = await LayerCompositor.composite(
      tm,
      layers,
      (l) => tileKeyFor(projectId, scene.id, position, l.id),
      w,
      h,
      // 加算・スクリーン等のレイヤーは用紙（背景色）にも効くので、そのときは
      // 背景色を敷いてから合成する（キャンバスと同じ見え方にする）。
      paperColor: LayerCompositor.paperForBlendModes(
        layers,
        _projects[idx].backgroundColor,
      ),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // 補間して縮める（補間しないと細い線が点線になった）。
    canvas.drawImageRect(
      fullImage,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    fullImage.dispose();
    final picture = recorder.endRecording();
    final thumbImage = await picture.toImage(tw, th);
    picture.dispose();
    final byteData = await thumbImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    thumbImage.dispose();
    final pngBytes = byteData?.buffer.asUint8List();
    if (pngBytes == null) return;

    final path = await NiaproSerializer.saveProjectThumbnail(
      projectId,
      pngBytes,
    );
    final curIdx = _projects.indexWhere((p) => p.id == projectId);
    if (curIdx < 0) return;
    final previous = _projects[curIdx].thumbnailPath;
    // The most recently saved editing position becomes the default cover.
    // Explicitly chosen covers remain unchanged when leaving the canvas.
    _projects[curIdx] = _projects[curIdx].copyWith(
      thumbnailPath: path,
      thumbnailLastSceneId: !force && sceneId != null
          ? scene.id
          : _projects[curIdx].thumbnailLastSceneId,
      thumbnailLastFrameIndex: !force && frameIndex != null
          ? position
          : _projects[curIdx].thumbnailLastFrameIndex,
    );
    final saved = _saveReportingSuccess(projectId);
    notifyListeners();
    // 前のサムネイルは、新しいパスを保存し終えてから、ほかの作品（以前の
    // 版で複製した作品はサムネイルを共有している）が使っていなければ消す（保存の前に消すと、
    // 保存が終わる前にアプリを閉じたとき、保存済みのデータが消えたファイルを
    // 指したままになる）。
    if (await saved &&
        previous != null &&
        previous != path &&
        ![..._projects, ..._trash].any((p) => p.thumbnailPath == previous)) {
      try {
        await File(previous).delete();
      } on FileSystemException {
        // 既に無い。
      }
    }
  }

  /// Changes only the list cover, not artwork or timeline contents.
  /// A selected frame is rendered to a standalone PNG for fast home loading.
  Future<void> setProjectThumbnail(
    String projectId, {
    required String mode,
    String? sceneId,
    int? frameIndex,
    Uint8List? customBytes,
  }) async {
    if (!const {'latest', 'frame', 'custom', 'none'}.contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    final beforeIndex = _projects.indexWhere((p) => p.id == projectId);
    if (beforeIndex < 0) throw StateError('Project not found');
    final original = _projects[beforeIndex];
    String? nextPath = original.thumbnailPath;
    if (mode == 'frame') {
      final scene = scenesOf(
        projectId,
      ).where((s) => s.id == sceneId).firstOrNull;
      if (scene == null ||
          frameIndex == null ||
          frameIndex < 0 ||
          frameIndex >= scene.frames.length) {
        throw ArgumentError('A valid scene/frame is required');
      }
      await generateAndSaveThumbnail(
        projectId,
        sceneId: scene.id,
        frameIndex: frameIndex,
        force: true,
      );
      nextPath = _projects.firstWhere((p) => p.id == projectId).thumbnailPath;
      if (nextPath == null) throw StateError('Frame could not be rendered');
    } else if (mode == 'latest') {
      await generateAndSaveThumbnail(
        projectId,
        sceneId: original.thumbnailLastSceneId,
        frameIndex: original.thumbnailLastFrameIndex,
        force: true,
      );
      nextPath = _projects.firstWhere((p) => p.id == projectId).thumbnailPath;
    } else if (mode == 'custom') {
      if (customBytes == null || customBytes.isEmpty) {
        throw ArgumentError('Choose an image before applying');
      }
      nextPath = await NiaproSerializer.saveProjectThumbnail(
        projectId,
        customBytes,
      );
    } else {
      nextPath = null;
    }
    final currentIndex = _projects.indexWhere((p) => p.id == projectId);
    if (currentIndex < 0) throw StateError('Project was removed');
    final previous = _projects[currentIndex].thumbnailPath;
    _projects[currentIndex] = _projects[currentIndex].copyWith(
      thumbnailMode: mode,
      thumbnailPath: nextPath,
      thumbnailFrameSceneId: mode == 'frame' ? sceneId : null,
      thumbnailFrameIndex: mode == 'frame' ? frameIndex : null,
    );
    notifyListeners();
    if (!await _saveReportingSuccess(projectId)) {
      throw StateError('Could not persist thumbnail preference');
    }
    if (previous != null &&
        previous != nextPath &&
        ![..._projects, ..._trash].any((p) => p.thumbnailPath == previous)) {
      try {
        await File(previous).delete();
      } on FileSystemException {
        /* already removed */
      }
    }
  }

  /// 同じ階層（[parentFolderId]の直下）で使われていない名前。同じ名前の
  /// フォルダがあれば「名前 (2)」「名前 (3)」…と番号を付ける（ユーザー指定。
  /// 同じ名前が並ぶと、色でしか見分けられず、移動先の一覧やパンくずでも
  /// 区別できなかった）。[exceptId]のフォルダ自身は数えない（名前の変更）。
  String uniqueFolderName(
    String name, {
    required String? parentFolderId,
    String? exceptId,
  }) {
    final taken = {
      for (final f in _folders)
        if (f.parentFolderId == parentFolderId && f.id != exceptId) f.name,
    };
    if (!taken.contains(name)) return name;
    // 「名前 (3)」が使われていれば「名前 (4)」から探す（「名前 (3) (2)」に
    // しない）。
    final match = RegExp(r'^(.*) \((\d+)\)$').firstMatch(name);
    final base = match?.group(1) ?? name;
    for (
      var number = (int.tryParse(match?.group(2) ?? '') ?? 1) + 1;
      ;
      number++
    ) {
      final numbered = '$base ($number)';
      if (!taken.contains(numbered)) return numbered;
    }
  }

  Future<void> _commitFolders(
    List<ProjectFolder> next, {
    bool shared = false,
  }) async {
    await saveFolderPreference(
      shared ? _sharedFoldersPrefsKey : _foldersPrefsKey,
      jsonEncode(next.map((f) => f.toJson()).toList()),
    );
    final target = shared ? _sharedFolders : _folders;
    target
      ..clear()
      ..addAll(next);
    _notifyFolders();
  }

  /// 引き継ぎ（.niatra）で移した作品が入っていたフォルダを、もう1台と同じ
  /// IDで足す（同じIDのフォルダがあれば何もせずそれを返す）。[parentFolderId]
  /// （この端末に無ければ一番上）の下に、同じ階層で使われていない名前
  /// （[uniqueFolderName]）で置く。この端末のフォルダは変えない。保存に
  /// 失敗したら足さずに投げる。
  Future<ProjectFolder> addTransferredFolder(
    ProjectFolder folder, {
    String? parentFolderId,
  }) => _queueFolder(() async {
    final existing = _folders.where((f) => f.id == folder.id).firstOrNull;
    if (existing != null) return existing;
    final parent = _folders.any((f) => f.id == parentFolderId)
        ? parentFolderId
        : null;
    final added = ProjectFolder(
      id: folder.id,
      name: uniqueFolderName(folder.name, parentFolderId: parent),
      color: folder.color,
      parentFolderId: parent,
      isFavorite: folder.isFavorite,
      createdAt: folder.createdAt,
    );
    await _commitFolders([..._folders, added]);
    return added;
  });

  /// [id]のフォルダが（下の階層として含めて）ゴミ箱にあるか。
  bool isFolderInTrash(String id) => _trashedFolders.any(
    (t) => t.folder.id == id || t.subfolders.any((f) => f.id == id),
  );

  /// [parentFolderId]を指定すると、そのフォルダの子フォルダとして作成する
  /// （「フォルダは複数階層に対応」）。nullはルート直下。同じ階層に同じ名前の
  /// フォルダがあれば番号を付ける（[uniqueFolderName]）。
  Future<ProjectFolder> createFolder(String name, {String? parentFolderId}) =>
      _queueFolder(() async {
        if (parentFolderId != null &&
            !_folders.any((f) => f.id == parentFolderId)) {
          throw const FolderSaveException(partiallySaved: false);
        }
        final folder = ProjectFolder(
          id: _nextId('folder'),
          name: uniqueFolderName(name, parentFolderId: parentFolderId),
          parentFolderId: parentFolderId,
        );
        await _commitFolders([..._folders, folder]);
        return folder;
      });

  /// 名前を変えるときは、同じ階層に同じ名前のフォルダがあれば番号を付ける
  /// （[uniqueFolderName]）。
  Future<void> editFolder(
    String id, {
    String? name,
    Object? color = _folderSentinel,
  }) => _queueFolder(() async {
    final i = _folders.indexWhere((f) => f.id == id);
    if (i < 0) return;
    final next = [..._folders];
    next[i] = next[i].copyWith(
      name: name == null
          ? null
          : uniqueFolderName(
              name,
              parentFolderId: next[i].parentFolderId,
              exceptId: id,
            ),
      color: color,
    );
    await _commitFolders(next);
  });

  Future<void> renameFolder(String folderId, String name) =>
      editFolder(folderId, name: name);
  Future<void> setFolderColor(String folderId, int? color) =>
      editFolder(folderId, color: color);

  /// Preserve folder thumbnail preferences independently of project content.
  Future<void> setFolderThumbnail(
    String folderId, {
    required String mode,
    String? sourceId,
    String? imagePath,
    bool shared = false,
  }) => _queueFolder(() async {
    if (!const {'auto', 'none', 'item', 'custom'}.contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    final current = shared ? _sharedFolders : _folders;
    final i = current.indexWhere((folder) => folder.id == folderId);
    if (i < 0) return;
    final next = [...current];
    next[i] = next[i].copyWith(
      thumbnailMode: mode,
      thumbnailSourceId: sourceId,
      thumbnailImagePath: imagePath,
    );
    await _commitFolders(next, shared: shared);
  });

  Future<void> toggleSharedFolderFavorite(String folderId) =>
      _queueFolder(() async {
        final index = _sharedFolders.indexWhere((f) => f.id == folderId);
        if (index < 0) return;
        final next = [..._sharedFolders];
        next[index] = next[index].copyWith(isFavorite: !next[index].isFavorite);
        await _commitFolders(next, shared: true);
      });

  Future<void> toggleFolderFavorite(String folderId) => _queueFolder(() async {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i < 0) return;
    final next = [..._folders];
    next[i] = next[i].copyWith(isFavorite: !next[i].isFavorite);
    await _commitFolders(next);
  });

  Future<void> moveFolderTo(String folderId, String? newParentId) =>
      _queueFolder(() async {
        if (folderId == newParentId ||
            (newParentId != null &&
                _isDescendantFolder(newParentId, folderId))) {
          return;
        }
        if (newParentId != null && !_folders.any((f) => f.id == newParentId)) {
          throw const FolderSaveException(partiallySaved: false);
        }
        final i = _folders.indexWhere((f) => f.id == folderId);
        if (i < 0) return;
        final folder = _folders[i];
        if (folder.parentFolderId == newParentId) return;
        final next = [..._folders];
        next[i] = folder.copyWith(
          parentFolderId: newParentId,
          name: uniqueFolderName(folder.name, parentFolderId: newParentId),
        );
        await _commitFolders(next);
      });

  /// [candidateId]が[ancestorId]の子孫フォルダかどうかを判定する。
  bool isFolderDescendantOf(String candidateId, String? ancestorId) =>
      ancestorId != null && _isDescendantFolder(candidateId, ancestorId);

  bool _isDescendantFolder(String candidateId, String ancestorId) {
    String? current = candidateId;
    final visited = <String>{};
    while (current != null && visited.add(current)) {
      if (current == ancestorId) return true;
      current = _folders
          .where((f) => f.id == current)
          .firstOrNull
          ?.parentFolderId;
    }
    return false;
  }

  /// [folderId]と、その中のフォルダ（下の階層を含む）のID。
  Set<String> folderSubtreeIds(String folderId) {
    final ids = <String>{folderId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final f in _folders) {
        final parent = f.parentFolderId;
        if (parent != null && ids.contains(parent) && ids.add(f.id)) {
          grew = true;
        }
      }
    }
    return ids;
  }

  /// フォルダの中の作品とフォルダの数（下の階層を含む。フォルダ自身は
  /// 数えない）。
  ({int projects, int folders}) folderContentCounts(String folderId) {
    final ids = folderSubtreeIds(folderId);
    return (
      projects: _projects
          .where((p) => !p.isSharedImport && ids.contains(p.folderId))
          .length,
      folders: ids.length - 1,
    );
  }

  /// フォルダを中身（下の階層のフォルダ・作品）ごとゴミ箱へ移す。ゴミ箱から
  /// [restoreTrashedFolder]でまとめて元に戻せる。先にゴミ箱の記録を、次に
  /// フォルダの一覧を保存する。どちらかを保存できなければ何も変えずに
  /// [FolderSaveException]を投げる。記録するのは読めた作品だけで、読めて
  /// いない作品は、読めたとき（[retryLoadProjects]・次の起動）にフォルダの
  /// 中の作品ならこの記録へ入る（[_joinTrashedFolders]。そのため、読めて
  /// いない作品を記録に覚えておく）。
  Future<TrashedFolder?> moveFolderToTrash(
    String folderId, {
    bool shared = false,
  }) => _queueFolder(() async {
    final folders = shared ? _sharedFolders : _folders;
    final top = folders.where((f) => f.id == folderId).firstOrNull;
    if (top == null) return null;
    final ids = shared ? <String>{folderId} : folderSubtreeIds(folderId);
    final now = DateTime.now();
    final record = TrashedFolder(
      folder: top,
      isShared: shared,
      subfolders: [
        for (final f in folders)
          if (f.id != folderId && ids.contains(f.id)) f,
      ],
      projectIds: [
        for (final p in _projects)
          if (shared
              ? p.isSharedImport && p.sharedFolderId == folderId
              : !p.isSharedImport && ids.contains(p.folderId))
            p.id,
      ],
      deletedAt: now,
      // 読めていない作品は、読めたときに、このフォルダの作品ならこの記録へ
      // 入れる（[_joinTrashedFolders]）。
      unreadProjectIds: _projectsListingFailed
          ? const []
          : [..._unreadProjectIds],
      unreadUnlisted: _projectsListingFailed,
    );
    // お気に入りの作品は、保護を外すまでゴミ箱へ移さない（作品の一括の
    // 削除と同じ。フォルダごとでも迂回させない）。お気に入りのフォルダ
    // 自身も同じ（メニュー・選んで移すときは断っていたが、ゴミ箱への
    // 貼り付けはここを通って移していた）。下の階層のお気に入りのフォルダも
    // 中身として移さない（以前は一番上のフォルダしか見ていなかった）。
    if (folders.any((f) => ids.contains(f.id) && f.isFavorite) ||
        _projects.any(
          (p) => record.projectIds.contains(p.id) && p.isFavorite,
        )) {
      throw const FavoriteProjectDeleteException();
    }
    // Do not archive a folder until all of its projects are readable
    // on disk. This also waits for any queued autosaves to complete.
    for (final projectId in record.projectIds) {
      await _saveBeforeTrash(projectId);
    }
    // ゴミ箱のフォルダの記録→作品のゴミ箱の記録→フォルダの一覧の順に
    // 保存し、途中で失敗したら保存済みのものを戻して何も変えない。
    try {
      await saveFolderPreference(
        _trashedFoldersPrefsKey,
        _encodeTrashedFolders([..._trashedFolders, record]),
      );
    } catch (error) {
      throw FolderSaveException(partiallySaved: false, cause: error);
    }
    Future<void> forgetRecord() async {
      try {
        await saveFolderPreference(
          _trashedFoldersPrefsKey,
          _encodeTrashedFolders(_trashedFolders),
        );
      } catch (_) {
        // 残った記録は、起動時にフォルダがまだあれば捨てる。
      }
    }

    final next = {
      ..._trashDeletedAt,
      for (final id in record.projectIds) id: now,
    };
    try {
      await _persistTrashState(next);
    } catch (error) {
      await forgetRecord();
      throw FolderSaveException(partiallySaved: false, cause: error);
    }
    try {
      await _commitFolders([
        for (final f in folders)
          if (!ids.contains(f.id)) f,
      ], shared: shared);
    } catch (error) {
      try {
        await _persistTrashState(_trashDeletedAt);
      } catch (_) {
        // 起動時に、ゴミ箱の記録だけ残った作品はフォルダのまま読む。
      }
      await forgetRecord();
      throw FolderSaveException(partiallySaved: false, cause: error);
    }
    _trashedFolders.add(record);
    for (final id in record.projectIds) {
      final i = _projects.indexWhere((p) => p.id == id);
      if (i >= 0) _moveProjectToTrash(i);
    }
    _trashDeletedAt
      ..clear()
      ..addAll(next);
    _notifyFolders();
    return record;
  });

  /// ゴミ箱のフォルダを中身ごと元の場所へ戻す。元の親のフォルダが無く
  /// なっていれば一番上へ戻す。フォルダの一覧を保存できなければ何も変えずに
  /// [FolderSaveException]を投げる。読めていない作品を含むフォルダも戻す
  /// （断ると、いつまでも読めない作品が1つあるだけで、同じフォルダの読めた
  /// 作品までゴミ箱から出せない）：読めていない作品はゴミ箱の記録から外し、
  /// 読めたときに、戻したフォルダの中の作品として読み込まれるようにする。
  Future<void> restoreTrashedFolder(String folderId) => _queueFolder(() async {
    final record = _trashedFolders
        .where((t) => t.folder.id == folderId)
        .firstOrNull;
    if (record == null) return;
    final unread = _unreadWorksOf(record);
    final parent = record.folder.parentFolderId;
    final folders = record.isShared ? _sharedFolders : _folders;
    try {
      await _commitFolders([
        ...folders,
        if (!folders.any((f) => f.id == record.folder.id))
          parent != null && !folders.any((f) => f.id == parent)
              ? record.folder.copyWith(parentFolderId: null)
              : record.folder,
        for (final f in record.subfolders)
          if (!folders.any((g) => g.id == f.id)) f,
      ], shared: record.isShared);
    } catch (error) {
      throw FolderSaveException(partiallySaved: false, cause: error);
    }
    _trashedFolders.remove(record);
    await _persistTrashedFolders();
    // 読めていない作品（保存には、入っていたフォルダのIDが残っている）。
    // ゴミ箱の記録に残すと、読めた後にゴミ箱の1件ずつの行に出る。
    if (unread.isNotEmpty) {
      final next = {..._trashDeletedAt}
        ..removeWhere((id, _) => unread.contains(id));
      try {
        await _persistTrashState(next);
        _trashDeletedAt
          ..clear()
          ..addAll(next);
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
      }
    }
    // フォルダの列の中なので、作品の保存の列だけを通す（restoreProjectは
    // フォルダの列に並ぶので、ここから待つと止まる）。戻せなかった作品は
    // ゴミ箱に1件ずつ残り、そこから戻し直せる。
    for (final id in record.projectIds) {
      if (!_trash.any((p) => p.id == id)) continue;
      try {
        await _queueProjectSave(id, () => _restoreProjectNow(id));
      } catch (error, stackTrace) {
        AppErrorReporter.record(error, stackTrace);
      }
    }
    _notifyFolders();
  });

  /// ゴミ箱のフォルダを中の作品ごと完全に削除する（元に戻せない）。
  /// 読めていない作品を含むフォルダは、何も変えずに
  /// [TrashedFolderUnreadException]を投げる。
  Future<void> permanentDeleteTrashedFolder(String folderId) =>
      _queueFolder(() async {
        final record = _trashedFolders
            .where((t) => t.folder.id == folderId)
            .firstOrNull;
        if (record == null) return;
        if (trashedFolderHasUnreadWorks(record)) {
          throw const TrashedFolderUnreadException();
        }
        _trashedFolders.remove(record);
        await _persistTrashedFolders();
        // 消せなかった作品はゴミ箱に1件ずつ残り、そこから消し直せる。
        for (final id in record.projectIds) {
          if (!_trash.any((p) => p.id == id)) continue;
          try {
            await _queueProjectSave(id, () => _permanentDeleteNow(id));
          } catch (error, stackTrace) {
            AppErrorReporter.record(error, stackTrace);
          }
        }
        _notifyFolders();
      });

  /// ゴミ箱を空にする（フォルダも作品もすべて完全に削除する）。
  /// 読めていない作品を含むフォルダは中の読めた作品ごと残し、他を消し
  /// 終えてから[TrashedFolderUnreadException]を投げる。
  Future<void> emptyTrash() async {
    final heldBack = _trashedFolders
        .where(trashedFolderHasUnreadWorks)
        .toList();
    for (final t in List.of(_trashedFolders)) {
      if (heldBack.contains(t)) continue;
      await permanentDeleteTrashedFolder(t.folder.id);
    }
    for (final project in List.of(_trash)) {
      if (heldBack.any((t) => t.projectIds.contains(project.id))) continue;
      await permanentDelete(project.id);
    }
    if (heldBack.isNotEmpty) throw const TrashedFolderUnreadException();
  }

  /// 日本語の形の複製の名前。複製の複製も元の名前に番号を付ける
  /// （[fallbackCopyName]。一覧の「複製」・設定の引き継ぎと同じ決まり）。
  static String _nextCopyName(String original, Iterable<String> usedNames) =>
      fallbackCopyName(original, usedNames);

  /// フォルダを中身（下の階層のフォルダ・作品）ごと複製して
  /// [targetParentId]（nullは一番上）に置く。いちばん上のフォルダだけ
  /// [name]にし、中のフォルダ・作品は元の名前のまま。自分自身やその中へも
  /// 複製できる（写すものを先に決めておくので、複製したものは写さない）。
  /// フォルダが見つからなければnull。
  Future<ProjectFolder?> duplicateFolder(
    String folderId, {
    String? targetParentId,
    required String name,
    CopyNamer? namer,
  }) => _queueFolder(() async {
    final top = _folders.where((f) => f.id == folderId).firstOrNull;
    if (top == null) return null;
    final siblingNames = _folders
        .where((f) => f.parentFolderId == targetParentId)
        .map((f) => f.name)
        .toSet();
    // ホームの貼り付けが渡す既定の名前（「名前 (コピー)」）は、複製の複製でも
    // 元の名前に空いている番号を付ける（「名前 (コピー) (コピー)」にしない。
    // 並びに無い名前を返すので、下の番号付けは通らない）。
    var copyTopName =
        namer?.call(top.name, siblingNames) ??
        (name == '${top.name} (コピー)'
            ? _nextCopyName(top.name, siblingNames)
            : name);
    if (siblingNames.contains(copyTopName)) {
      copyTopName = uniqueFolderName(name, parentFolderId: targetParentId);
    }
    // 写すものを先に決めておく（複製したフォルダ・作品を数え直さない）。
    final ids = folderSubtreeIds(folderId);
    final projects = [
      for (final p in _projects)
        if (!p.isSharedImport && ids.contains(p.folderId)) p,
    ];
    final ordered = <ProjectFolder>[top];
    for (var i = 0; i < ordered.length; i++) {
      for (final f in _folders) {
        if (f.parentFolderId == ordered[i].id && ids.contains(f.id)) {
          ordered.add(f);
        }
      }
    }
    final copies = <String, String>{};
    final added = <ProjectFolder>[];
    for (final f in ordered) {
      final isTop = f.id == folderId;
      final copy = ProjectFolder(
        id: _nextId('folder'),
        name: isTop ? copyTopName : f.name,
        color: f.color,
        parentFolderId: isTop ? targetParentId : copies[f.parentFolderId],
      );
      copies[f.id] = copy.id;
      added.add(copy);
    }
    await _commitFolders([..._folders, ...added]);
    for (final p in projects) {
      final previous = _projects.map((project) => project.id).toSet();
      if (!await duplicateProject(
        p.id,
        targetFolderId: copies[p.folderId],
        useTargetFolder: true,
        name: p.name,
      )) {
        throw StateError('Folder project vanished during copy: ${p.id}');
      }
      final created = _projects
          .where(
            (project) =>
                !previous.contains(project.id) &&
                copies.values.contains(project.folderId),
          )
          .single;
      await saveProject(created.id);
    }
    return _folders.firstWhere((f) => f.id == copies[folderId]);
  });

  /// フォルダ削除時、直下のプロジェクト・子フォルダはルート（トップレベル）へ戻す
  /// （「フォルダ削除時は中のプロジェクトをルートへ戻すか確認ダイアログを
  /// 表示する」。確認ダイアログ自体はUI側で表示し、本メソッドは確定後の処理）。
  Future<void> deleteFolder(String folderId) =>
      _deleteFolder(folderId, shared: false);

  Future<void> _deleteFolder(
    String folderId, {
    required bool shared,
  }) => _queueFolder(() async {
    final folders = shared ? _sharedFolders : _folders;
    if (!folders.any((f) => f.id == folderId)) return;
    var moved = 0;
    try {
      final contents = [..._projects, ..._trash]
          .where(
            (p) => shared
                ? p.isSharedImport && p.sharedFolderId == folderId
                : p.folderId == folderId,
          )
          .toList();
      // Keep the folder until every referenced project file acknowledges root.
      // On partial failure the already moved projects remain safely at root;
      // retry resumes the remaining contents, without rolling back drawings.
      for (final p in contents) {
        await _saveMembership(p.id, null, shared: shared);
        moved++;
      }
      final next = folders
          .where((f) => f.id != folderId)
          .map(
            (f) => !shared && f.parentFolderId == folderId
                ? f.copyWith(parentFolderId: null)
                : f,
          )
          .toList();
      await _commitFolders(next, shared: shared);
    } catch (error) {
      if (moved > 0) _notifyFolders();
      throw FolderSaveException(partiallySaved: moved > 0, cause: error);
    }
  });

  // ─── 共有タブ用フォルダ（ホーム画面「共有」タブへのフォルダ新規追加機能） ──
  // プロジェクト一覧タブのフォルダ（_folders/folderId）とは独立した、共有
  // タブ専用の階層（sharedFolderId）。ネストはサポートしない（常にルート
  // 直下の1階層のみ）——共有タブは一覧の分類が主目的であり、複数階層まで
  // 必要になる想定が薄いため、UIを簡潔に保つ設計判断。

  final List<ProjectFolder> _sharedFolders = [];
  List<ProjectFolder> get sharedFolders => List.unmodifiable(_sharedFolders);

  Future<ProjectFolder> createSharedFolder(String name) =>
      _queueFolder(() async {
        final folder = ProjectFolder(id: _nextId('shared_folder'), name: name);
        await _commitFolders([..._sharedFolders, folder], shared: true);
        return folder;
      });

  /// 共有の受信フォルダを、中の受信プロジェクトと一緒に複製する。フォルダと
  /// 中の作品の複製の名前は[namer]で付ける（省略すると日本語の「(コピー)」）。
  Future<ProjectFolder> duplicateSharedFolderWithContents(
    String folderId, {
    CopyNamer? namer,
  }) async {
    final source = _sharedFolders.where((f) => f.id == folderId).firstOrNull;
    if (source == null) throw StateError('Shared folder missing: $folderId');
    final projects = _projects
        .where((p) => p.isSharedImport && p.sharedFolderId == folderId)
        .toList();
    final copyName = (namer ?? _nextCopyName)(source.name, {
      for (final folder in _sharedFolders) folder.name,
    });
    final target = await createSharedFolder(copyName);
    for (final project in projects) {
      final oldIds = _projects.map((p) => p.id).toSet();
      if (!await duplicateProject(
        project.id,
        targetSharedFolderId: target.id,
        useTargetSharedFolder: true,
        namer: namer,
      )) {
        throw StateError('Shared project missing: ${project.id}');
      }
      final created = _projects
          .where((p) => !oldIds.contains(p.id) && p.sharedFolderId == target.id)
          .single;
      // duplicateProject queues an async save; acknowledge its completion
      // before reporting the entire folder copy as complete.
      await saveProject(created.id);
    }
    return target;
  }

  Future<void> renameSharedFolder(String folderId, String name) =>
      _queueFolder(() async {
        final i = _sharedFolders.indexWhere((f) => f.id == folderId);
        if (i < 0) return;
        final next = [..._sharedFolders];
        next[i] = next[i].copyWith(name: name);
        await _commitFolders(next, shared: true);
      });

  Future<void> deleteSharedFolder(String folderId) =>
      _deleteFolder(folderId, shared: true);

  Future<void> moveToSharedFolder(String projectId, String? folderId) =>
      _queueFolder(() async {
        if (!_projects.any((p) => p.id == projectId && p.isSharedImport)) {
          return;
        }
        if (folderId != null && !_sharedFolders.any((f) => f.id == folderId)) {
          throw const FolderSaveException(partiallySaved: false);
        }
        try {
          await _saveMembership(projectId, folderId, shared: true);
        } catch (error) {
          throw FolderSaveException(partiallySaved: false, cause: error);
        }
        _notifyFolders();
      });

  static const _sharedFoldersPrefsKey = 'shared_folders';

  Future<void> _loadSharedFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.readString(_sharedFoldersPrefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _sharedFolders
        ..clear()
        ..addAll(
          list.map((e) => ProjectFolder.fromJson(e as Map<String, dynamic>)),
        );
    } catch (_) {
      // 読み込み失敗時はフォルダなしとして続行
    }
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
      final raw = prefs.readString(_foldersPrefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _folders
        ..clear()
        ..addAll(
          list.map((e) => ProjectFolder.fromJson(e as Map<String, dynamic>)),
        );
    } catch (_) {
      // 読み込み失敗時はフォルダなしとして続行
    }
  }

  static const _trashedFoldersPrefsKey = 'trashed_project_folders';

  Future<void> _loadTrashedFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.readString(_trashedFoldersPrefsKey);
      if (raw == null) return;
      _trashedFolders
        ..clear()
        ..addAll([
          for (final e in jsonDecode(raw) as List<dynamic>)
            TrashedFolder.fromJson(e as Map<String, dynamic>),
        ])
        // ゴミ箱へ移す途中で終わったときは、フォルダがまだ一覧にある。
        ..removeWhere(
          (t) => (t.isShared ? _sharedFolders : _folders).any(
            (f) => f.id == t.folder.id,
          ),
        );
    } catch (error, stackTrace) {
      // 読めなければゴミ箱のフォルダなしとして続ける（中の作品はゴミ箱に
      // 1件ずつ出る）。
      AppErrorReporter.record(error, stackTrace);
    }
  }

  static String _encodeTrashedFolders(List<TrashedFolder> folders) =>
      jsonEncode([for (final t in folders) t.toJson()]);

  Future<void> _persistTrashedFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _trashedFoldersPrefsKey,
        _encodeTrashedFolders(_trashedFolders),
      );
    } catch (_) {
      // 保存失敗時も続行（次回操作時に再試行される）
    }
  }
}

/// Undo for [ProjectService.replaceLayerPixels]: the replaced tiles and,
/// when they changed with them, the layer's own settings.
class _LayerPixelsUndoAction extends UndoAction {
  _LayerPixelsUndoAction({
    required this.projects,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.layerKey,
    required this.before,
    required this.after,
    this.layerBefore,
    this.layerAfter,
  });

  final ProjectService projects;
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String layerKey;
  final Map<String, Uint8List?> before;
  final Map<String, Uint8List?> after;
  final Layer? layerBefore;
  final Layer? layerAfter;

  void _restore(Map<String, Uint8List?> tiles, Layer? layer) {
    if (tiles.isNotEmpty) {
      projects.tileManagerOf(projectId).applyTileSnapshot(layerKey, tiles);
    }
    if (layer != null) {
      projects.updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layer: layer,
        recordUndo: false,
      );
    }
    if (layer == null && tiles.isNotEmpty) {
      projects._notifyProjectPixelsChanged(projectId);
    }
  }

  @override
  void undo() => _restore(before, layerBefore);

  @override
  void redo() => _restore(after, layerAfter);

  @override
  String get description => 'Filter on $layerKey';

  @override
  HistoryFrame frameForHistory({required bool redo}) =>
      (sceneId: sceneId, frameIndex: frameIndex);
}

class _TimelineEditState {
  const _TimelineEditState(this.scenes, this.homes, this.project);

  final List<Scene> scenes;
  final Map<String, LayerHome> homes;
  final Project? project;
}
