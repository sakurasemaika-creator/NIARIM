import 'package:flutter/foundation.dart';
import '../models/save_node.dart';

/// セーブツリーサービス
/// スロット方式：固定数のスロットで管理
/// ツリー方式：保存数制限なし・ツリー状に履歴管理
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

  /// スロット方式：指定スロットへ上書き保存
  SaveNode saveToSlot({
    required String projectId,
    required int slotIndex,
    String? comment,
    String? thumbnailPath,
  }) {
    assert(slotIndex >= 0 && slotIndex < _slotMax,
        'slotIndex must be 0..${ _slotMax - 1}');
    _nodesByProject.putIfAbsent(projectId, () => []);
    _nodesByProject[projectId]!.removeWhere((n) => n.slotIndex == slotIndex);
    final node = SaveNode(
      id: _newId(),
      projectId: projectId,
      savedAt: DateTime.now(),
      comment: comment,
      thumbnailPath: thumbnailPath,
      slotIndex: slotIndex,
    );
    _nodesByProject[projectId]!.add(node);
    notifyListeners();
    return node;
  }

  /// ツリー方式：親ノードから枝分かれして保存
  SaveNode saveAsChild({
    required String projectId,
    String? parentId,
    String? comment,
    String? thumbnailPath,
  }) {
    _nodesByProject.putIfAbsent(projectId, () => []);
    final node = SaveNode(
      id: _newId(),
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

  void deleteNode(String projectId, String nodeId) {
    _nodesByProject[projectId]?.removeWhere((n) => n.id == nodeId);
    notifyListeners();
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
  /// [archive] true=アーカイブ、false=完全削除
  /// [newSlotMax] スロット方式の場合の新スロット数（null=ツリー方式へ変更）
  void applyModeChange({
    required String projectId,
    required List<String> keepIds,
    required bool archive,
    required bool newIsTreeMode,
    int? newSlotMax,
  }) {
    final all = _nodesByProject[projectId] ?? [];
    final keep = all.where((n) => keepIds.contains(n.id)).toList();
    final discard = all.where((n) => !keepIds.contains(n.id)).toList();

    if (archive) {
      _archivedByProject.putIfAbsent(projectId, () => []);
      _archivedByProject[projectId]!.addAll(discard);
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
