import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../engine/niapro_serializer.dart';
import '../engine/tile_manager.dart';
import '../models/project.dart';
import '../models/save_node.dart';
import '../models/scene.dart';
import '../utils/app_error_reporter.dart';

/// セーブツリーサービス
/// スロット方式：固定数のスロットで管理
/// ツリー方式：保存数制限なし・ツリー状に履歴管理
///
/// 各ノードはSaveTree/{nodeId}.niaproとして実データ（シーン・タイル）を
/// ディスクへ保存する。自動保存（クラッシュ復元専用）とは
/// 完全に別領域・別ライフサイクルで管理される。
class SaveTreeService extends ChangeNotifier {
  int _slotMax = 10;
  int get slotMax => _slotMax;

  bool _isTreeMode = false;
  bool get isTreeMode => _isTreeMode;

  void setSlotMax(int max) {
    assert(max > 0);
    _slotMax = max;
    notifyListeners();
  }

  void setTreeMode(bool treeMode) {
    _isTreeMode = treeMode;
    notifyListeners();
  }

  final Map<String, List<SaveNode>> _nodesByProject = {};
  // アーカイブ：スロット→ツリー方式復元時に自動復元する保存データ
  final Map<String, List<SaveNode>> _archivedByProject = {};
  int _idCounter = 0;

  String _newId() =>
      'save_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  /// 作品ごとの保存の一覧のファイル名（SaveTree/の中）。
  static const String indexFileName = 'index.json';

  /// 起動時に、各作品の保存の一覧（SaveTree/index.json）を読み込む。一覧に
  /// 無い保存のファイル（一覧を書けなかった・以前の版で保存した）も拾い直す。
  /// 読めないものは飛ばし、起動は止めない。
  Future<void> init() async {
    final String base;
    try {
      base = await NiaproSerializer.projectsBasePath();
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
      return;
    }
    final root = Directory(base);
    if (!root.existsSync()) return;
    for (final dir in root.listSync().whereType<Directory>()) {
      final projectId = dir.path.split(RegExp(r'[\\/]')).last;
      try {
        await _loadProject(projectId, Directory('${dir.path}/SaveTree'));
      } catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }
    notifyListeners();
  }

  Future<void> _loadProject(String projectId, Directory dir) async {
    if (!dir.existsSync()) return;
    String? thumbnailOf(String id) {
      final file = File('${dir.path}/${id}_thumb.png');
      return file.existsSync() ? file.path : null;
    }

    bool hasData(String id) => File('${dir.path}/$id.niapro').existsSync();
    final nodes = <SaveNode>[];
    final archived = <SaveNode>[];
    final known = <String>{};
    final index = File('${dir.path}/$indexFileName');
    if (index.existsSync()) {
      try {
        final json = jsonDecode(index.readAsStringSync());
        if (json is Map) {
          for (final (key, into) in [
            ('nodes', nodes),
            ('archived', archived),
          ]) {
            final list = json[key];
            if (list is! List) continue;
            for (final item in list) {
              final id = item is Map ? item['id'] : null;
              // 実データの無い保存は出さない（開くと失敗するため）。
              if (id is! String || known.contains(id) || !hasData(id)) {
                continue;
              }
              final node = SaveNode.fromJson(
                item,
                projectId: projectId,
                thumbnailPath: thumbnailOf(id),
              );
              if (node == null) continue;
              known.add(id);
              into.add(node);
            }
          }
        }
      } on FormatException catch (error, stack) {
        AppErrorReporter.record(error, stack);
      }
    }
    // 一覧に無い保存のファイルを古い順に拾い直す。
    final orphans = <SaveNode>[];
    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.niapro')) continue;
      final id = name.substring(0, name.length - '.niapro'.length);
      if (known.contains(id)) continue;
      orphans.add(
        SaveNode(
          id: id,
          projectId: projectId,
          savedAt: _savedAtOf(id) ?? file.lastModifiedSync(),
          thumbnailPath: thumbnailOf(id),
        ),
      );
    }
    orphans.sort((a, b) => a.savedAt.compareTo(b.savedAt));
    if (_isTreeMode) {
      nodes.addAll(orphans);
    } else {
      // スロット方式：空いているスロットへ入れ、入りきらない分は退避する
      // （ツリー方式へ変えると出る）。
      final used = {
        for (final n in nodes)
          if (n.slotIndex >= 0) n.slotIndex,
      };
      for (final orphan in orphans) {
        int? free;
        for (var i = 0; i < _slotMax; i++) {
          if (!used.contains(i)) {
            free = i;
            break;
          }
        }
        if (free == null) {
          archived.add(orphan);
          continue;
        }
        used.add(free);
        nodes.add(
          SaveNode(
            id: orphan.id,
            projectId: projectId,
            savedAt: orphan.savedAt,
            thumbnailPath: orphan.thumbnailPath,
            slotIndex: free,
          ),
        );
      }
    }
    if (nodes.isEmpty && archived.isEmpty) return;
    _nodesByProject[projectId] = nodes;
    if (archived.isNotEmpty) _archivedByProject[projectId] = archived;
    if (orphans.isNotEmpty) await _persist(projectId);
  }

  /// 保存のIDは`save_<ミリ秒>_<連番>`なので、そこから保存した時刻が分かる。
  static DateTime? _savedAtOf(String id) {
    final match = RegExp(r'^save_(\d+)_').firstMatch(id);
    if (match == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(match.group(1)!));
  }

  final Map<String, Future<void>> _persisting = {};

  /// 作品の保存の一覧を書く。同じ作品の書き込みは1つずつ順に行う。失敗は
  /// 記録だけして続ける（保存のファイル自体は残り、次の起動で拾い直す）。
  Future<void> _persist(String projectId) {
    final previous = _persisting[projectId] ?? Future<void>.value();
    final next = previous.then((_) => _writeIndex(projectId));
    _persisting[projectId] = next;
    return next;
  }

  Future<void> _writeIndex(String projectId) async {
    try {
      final base = await NiaproSerializer.projectsBasePath();
      // 作品ごと消えたあとは書かない（フォルダを作り直さない）。
      if (!Directory('$base/$projectId').existsSync()) return;
      final dir = Directory('$base/$projectId/SaveTree');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final json = jsonEncode({
        'nodes': [
          for (final n in _nodesByProject[projectId] ?? const <SaveNode>[])
            n.toJson(),
        ],
        'archived': [
          for (final n in _archivedByProject[projectId] ?? const <SaveNode>[])
            n.toJson(),
        ],
      });
      // 書き込みと置き換えは同期で行い、途中で別の書き込みが割り込まない
      // ようにする（作品の保存と同じ）。
      File('${dir.path}/$indexFileName.tmp')
        ..writeAsStringSync(json, flush: true)
        ..renameSync('${dir.path}/$indexFileName');
    } catch (error, stack) {
      AppErrorReporter.record(error, stack);
    }
  }

  List<SaveNode> getNodes(String projectId) =>
      List.unmodifiable(_nodesByProject[projectId] ?? []);

  /// この作品の保存のうち一番新しいものの時刻（無ければnull）。保存の画面へ
  /// 移る前と戻った後で比べると、その間に保存したかが分かる。
  DateTime? latestSaveOf(String projectId) {
    DateTime? latest;
    for (final n in _nodesByProject[projectId] ?? const <SaveNode>[]) {
      if (latest == null || n.savedAt.isAfter(latest)) latest = n.savedAt;
    }
    return latest;
  }

  List<SaveNode> getArchivedNodes(String projectId) =>
      List.unmodifiable(_archivedByProject[projectId] ?? []);

  /// スロット方式：指定スロットへ上書き保存。実データ（シーン・タイル）を
  /// SaveTree/{nodeId}.niaproへ書き込む。
  Future<SaveNode> saveToSlot({
    required String projectId,
    required int slotIndex,
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
    String? comment,
    Uint8List? thumbnailPngBytes,
  }) async {
    assert(
      slotIndex >= 0 && slotIndex < _slotMax,
      'slotIndex must be 0..${_slotMax - 1}',
    );
    _nodesByProject.putIfAbsent(projectId, () => []);
    final old = _nodesByProject[projectId]!
        .where((n) => n.slotIndex == slotIndex)
        .toList();
    final nodeId = _newId();
    // 【重要】既存スロットの差し替えは「新しい保存が完全に書き終わってから」
    // 行う。以前はここより前に removeWhere で既存ノードを一覧から外して
    // いたため、この書き込みが失敗すると（空き容量不足・書き込みエラー等）
    // 新しい保存が作られないまま古い保存だけが失われ、上書き保存の失敗が
    // そのままデータ損失になっていた。書き込み成功後に入れ替えることで、
    // 失敗しても直前の保存がそのまま残るようにする。
    await NiaproSerializer.saveSaveTreeNode(
      project: project,
      scenes: scenes,
      tileManager: tileManager,
      nodeId: nodeId,
    );
    String? thumbnailPath;
    if (thumbnailPngBytes != null) {
      thumbnailPath = await NiaproSerializer.saveSaveTreeThumbnail(
        projectId,
        nodeId,
        thumbnailPngBytes,
      );
    }
    _nodesByProject[projectId]!.removeWhere((n) => n.slotIndex == slotIndex);
    final node = SaveNode(
      id: nodeId,
      projectId: projectId,
      savedAt: DateTime.now(),
      comment: comment,
      thumbnailPath: thumbnailPath,
      slotIndex: slotIndex,
    );
    for (final o in old) {
      await NiaproSerializer.deleteSaveTreeNode(projectId, o.id);
    }
    _nodesByProject[projectId]!.add(node);
    notifyListeners();
    await _persist(projectId);
    return node;
  }

  /// ツリー方式：親ノードから枝分かれして保存。実データ（シーン・タイル）を
  /// SaveTree/{nodeId}.niaproへ書き込む。
  Future<SaveNode> saveAsChild({
    required String projectId,
    required Project project,
    required List<Scene> scenes,
    required TileManager tileManager,
    String? parentId,
    String? comment,
    Uint8List? thumbnailPngBytes,
  }) async {
    _nodesByProject.putIfAbsent(projectId, () => []);
    final nodeId = _newId();
    await NiaproSerializer.saveSaveTreeNode(
      project: project,
      scenes: scenes,
      tileManager: tileManager,
      nodeId: nodeId,
    );
    String? thumbnailPath;
    if (thumbnailPngBytes != null) {
      thumbnailPath = await NiaproSerializer.saveSaveTreeThumbnail(
        projectId,
        nodeId,
        thumbnailPngBytes,
      );
    }
    final node = SaveNode(
      id: nodeId,
      projectId: projectId,
      savedAt: DateTime.now(),
      comment: comment,
      thumbnailPath: thumbnailPath,
      parentId: parentId,
      slotIndex: -1,
    );
    _nodesByProject[projectId]!.add(node);
    notifyListeners();
    await _persist(projectId);
    return node;
  }

  /// 指定ノードの実データを読み込む（復元用）。ファイルが存在しない・
  /// 破損している場合はnullを返す。
  Future<NiaproData?> loadNode(String projectId, String nodeId) async {
    try {
      return await NiaproSerializer.loadSaveTreeNode(projectId, nodeId);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteNode(String projectId, String nodeId) async {
    _nodesByProject[projectId]?.removeWhere((n) => n.id == nodeId);
    notifyListeners();
    await NiaproSerializer.deleteSaveTreeNode(projectId, nodeId);
    await _persist(projectId);
  }

  List<SaveNode> getChildren(String projectId, String? parentId) {
    return (_nodesByProject[projectId] ?? [])
        .where((n) => n.parentId == parentId)
        .toList();
  }

  List<int> getUsedSlots(String projectId) {
    return (_nodesByProject[projectId] ?? [])
        .where((n) => n.slotIndex >= 0)
        .map((n) => n.slotIndex)
        .toList();
  }

  /// 保存データ変更フロー専用処理
  /// （ツリー→スロット変換・スロット数削減）
  /// [keepIds] 保持するノードID一覧
  /// [archive] true=アーカイブ、false=完全削除（実ファイルも削除する）
  /// [newSlotMax] スロット方式の場合の新スロット数（null=ツリー方式へ変更）
  Future<void> applyModeChange({
    required String projectId,
    required List<String> keepIds,
    required bool archive,
    required bool newIsTreeMode,
    int? newSlotMax,
  }) async {
    final all = _nodesByProject[projectId] ?? [];
    final keep = all.where((n) => keepIds.contains(n.id)).toList();
    final discard = all.where((n) => !keepIds.contains(n.id)).toList();

    if (archive) {
      _archivedByProject.putIfAbsent(projectId, () => []);
      _archivedByProject[projectId]!.addAll(discard);
    } else {
      // 完全削除：実データ（SaveTree/{nodeId}.niapro）も削除する
      for (final n in discard) {
        await NiaproSerializer.deleteSaveTreeNode(projectId, n.id);
      }
    }

    // スロット方式の場合、選択ノードにスロット番号を再割り当て
    List<SaveNode> newNodes;
    if (!newIsTreeMode) {
      newNodes = keep.asMap().entries.map((e) {
        return SaveNode(
          id: e.value.id,
          projectId: e.value.projectId,
          savedAt: e.value.savedAt,
          comment: e.value.comment,
          thumbnailPath: e.value.thumbnailPath,
          slotIndex: e.key,
        );
      }).toList();
      if (newSlotMax != null) _slotMax = newSlotMax;
    } else {
      newNodes = keep
          .map(
            (n) => SaveNode(
              id: n.id,
              projectId: n.projectId,
              savedAt: n.savedAt,
              comment: n.comment,
              thumbnailPath: n.thumbnailPath,
              parentId: null,
              slotIndex: -1,
            ),
          )
          .toList();
    }

    _nodesByProject[projectId] = newNodes;
    _isTreeMode = newIsTreeMode;
    notifyListeners();
    await _persist(projectId);
  }

  /// スロット→ツリー方式へ変更した時にアーカイブを自動復元（外部呼び出し用）
  void restoreArchive(String projectId) {
    final archived = _archivedByProject[projectId];
    if (archived == null || archived.isEmpty) return;
    _nodesByProject.putIfAbsent(projectId, () => []);
    _nodesByProject[projectId]!.addAll(archived);
    _archivedByProject[projectId] = [];
    notifyListeners();
    unawaited(_persist(projectId));
  }
}
