import 'package:flutter/foundation.dart';
import '../engine/niapro_serializer.dart';
import '../engine/tile_manager.dart';
import '../models/project.dart';
import '../models/save_node.dart';
import '../models/scene.dart';

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

  List<SaveNode> getNodes(String projectId) =>
      List.unmodifiable(_nodesByProject[projectId] ?? []);

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
    assert(slotIndex >= 0 && slotIndex < _slotMax,
        'slotIndex must be 0..${ _slotMax - 1}');
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
          projectId, nodeId, thumbnailPngBytes);
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
          projectId, nodeId, thumbnailPngBytes);
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
      newNodes = keep.map((n) => SaveNode(
        id: n.id,
        projectId: n.projectId,
        savedAt: n.savedAt,
        comment: n.comment,
        thumbnailPath: n.thumbnailPath,
        parentId: null,
        slotIndex: -1,
      )).toList();
    }

    _nodesByProject[projectId] = newNodes;
    _isTreeMode = newIsTreeMode;
    notifyListeners();
  }

  /// スロット→ツリー方式へ変更した時にアーカイブを自動復元（外部呼び出し用）
  void restoreArchive(String projectId) {
    final archived = _archivedByProject[projectId];
    if (archived == null || archived.isEmpty) return;
    _nodesByProject.putIfAbsent(projectId, () => []);
    _nodesByProject[projectId]!.addAll(archived);
    _archivedByProject[projectId] = [];
    notifyListeners();
  }
}
