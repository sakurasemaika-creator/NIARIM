import 'package:flutter/foundation.dart';

import 'tile_manager.dart';

typedef HistoryFrame = ({String sceneId, int frameIndex});

class UndoManager extends ChangeNotifier {
  final Map<String?, _UndoStacks> _projectStacks = {};
  String? _projectId;
  final List<({String? projectId, List<UndoAction> actions})> _recordingGroups =
      [];
  int _maxUndoCount = 50;

  _UndoStacks _stacksFor(String? projectId) =>
      _projectStacks.putIfAbsent(projectId, _UndoStacks.new);
  List<UndoAction> get _undoStack => _stacksFor(_projectId).undo;
  List<UndoAction> get _redoStack => _stacksFor(_projectId).redo;

  /// The project and frame of the last change to the history (an operation
  /// recorded, undone or redone), for the making recorder. The frame is null
  /// when the operation does not belong to one.
  ({String? projectId, HistoryFrame? frame})? get lastChange => _lastChange;
  ({String? projectId, HistoryFrame? frame})? _lastChange;

  void selectProject(String projectId) {
    if (_projectId == projectId) return;
    _projectId = projectId;
  }

  void discardProject(String projectId) {
    if (_projectStacks.remove(projectId) != null) {
      notifyListeners();
    }
  }

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  bool canUndoFor(String projectId) =>
      _projectStacks[projectId]?.undo.isNotEmpty ?? false;

  bool canRedoFor(String projectId) =>
      _projectStacks[projectId]?.redo.isNotEmpty ?? false;

  /// The project's place in its history: the newest operation that can be
  /// undone and how many there are. Two equal places mean the work was not
  /// changed in between (or was changed and undone back to the same place).
  ({UndoAction? newest, int count}) historyPointFor(String projectId) {
    final undo = _projectStacks[projectId]?.undo;
    return (
      newest: undo == null || undo.isEmpty ? null : undo.last,
      count: undo?.length ?? 0,
    );
  }

  bool retainsMaterial(String projectId, String materialId) {
    final history = _projectStacks[projectId];
    if (history == null) return false;
    bool needsMaterial(UndoAction action) => switch (action) {
      ProjectEditUndoAction() => action.retainedMaterialIds.contains(
        materialId,
      ),
      LayerAddUndoAction() => action.materialId == materialId,
      LayerRemoveUndoAction() => action.materialId == materialId,
      _GroupedUndoAction() => action._actions.any(needsMaterial),
      _ => false,
    };
    return history.undo.any(needsMaterial) || history.redo.any(needsMaterial);
  }

  void setMaxUndoCount(int count) {
    // 負の数だと、空の履歴からさらに取り除こうとして例外になる。
    _maxUndoCount = count < 0 ? 0 : count;
    for (final history in _projectStacks.values) {
      if (history.undo.length > _maxUndoCount) {
        history.undo.removeRange(0, history.undo.length - _maxUndoCount);
      }
    }
  }

  void push(UndoAction action, {String? projectId}) {
    final id = projectId ?? _projectId;
    _projectId ??= id;
    if (_recordingGroups.isNotEmpty &&
        (_recordingGroups.last.projectId == id ||
            _recordingGroups.last.projectId == null)) {
      _recordingGroups.last.actions.add(action);
      return;
    }
    final history = _stacksFor(id);
    history.undo.add(action);
    history.redo.clear();
    if (history.undo.length > _maxUndoCount) history.undo.removeAt(0);
    _lastChange = (projectId: id, frame: action.frameForHistory(redo: true));
    notifyListeners();
  }

  /// Records a serialized operation as one history entry. Partial changes remain
  /// undoable when [operation] throws; callers still receive the original error.
  Future<T> runGrouped<T>({
    required String description,
    required Future<T> Function() operation,
    bool Function(UndoAction action)? shouldUndoAction,
  }) async {
    final actions = <UndoAction>[];
    final projectId = _projectId;
    final group = (projectId: projectId, actions: actions);
    _recordingGroups.add(group);
    try {
      return await operation();
    } finally {
      _recordingGroups.remove(group);
      if (actions.isNotEmpty) {
        push(
          _GroupedUndoAction(description, actions, shouldUndoAction),
          projectId: projectId,
        );
      }
    }
  }

  HistoryFrame? undo({String? projectId}) {
    final history = _stacksFor(projectId ?? _projectId);
    if (history.undo.isEmpty) return null;
    final action = history.undo.removeLast();
    action.undo();
    history.redo.add(action);
    final frame = action.frameForHistory(redo: false);
    _lastChange = (projectId: projectId ?? _projectId, frame: frame);
    notifyListeners();
    return frame;
  }

  HistoryFrame? redo({String? projectId}) {
    final history = _stacksFor(projectId ?? _projectId);
    if (history.redo.isEmpty) return null;
    final action = history.redo.removeLast();
    action.redo();
    history.undo.add(action);
    final frame = action.frameForHistory(redo: true);
    _lastChange = (projectId: projectId ?? _projectId, frame: frame);
    notifyListeners();
    return frame;
  }

  /// Removes the specified operations from both stacks after their caller
  /// has restored the original pixels.
  void discardActions(Set<UndoAction> actions, {String? projectId}) {
    if (actions.isEmpty) return;
    final history = _stacksFor(projectId ?? _projectId);
    history.undo.removeWhere(actions.contains);
    history.redo.removeWhere(actions.contains);
    notifyListeners();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}

class _UndoStacks {
  final List<UndoAction> undo = [];
  final List<UndoAction> redo = [];
}

abstract class UndoAction {
  void undo();
  void redo();
  String get description;
  HistoryFrame? frameForHistory({required bool redo}) => null;
}

class ProjectEditUndoAction extends UndoAction {
  ProjectEditUndoAction(
    this.description,
    this.before,
    this.after, {
    this.retainedMaterialIds = const {},
    this.undoFrame,
    this.redoFrame,
  });

  @override
  final String description;
  final VoidCallback before;
  final VoidCallback after;
  final Iterable<String> retainedMaterialIds;
  final HistoryFrame? undoFrame;
  final HistoryFrame? redoFrame;

  @override
  HistoryFrame? frameForHistory({required bool redo}) =>
      redo ? redoFrame : undoFrame;

  @override
  void undo() => before();

  @override
  void redo() => after();
}

class _GroupedUndoAction extends UndoAction {
  @override
  final String description;
  final List<UndoAction> _actions;
  final bool Function(UndoAction action)? _shouldUndoAction;
  final List<UndoAction> _undone = [];

  _GroupedUndoAction(this.description, this._actions, this._shouldUndoAction);

  @override
  HistoryFrame? frameForHistory({required bool redo}) {
    final actions = redo ? _undone.reversed : _undone;
    for (final action in actions) {
      final frame = action.frameForHistory(redo: redo);
      if (frame != null) return frame;
    }
    return null;
  }

  @override
  void undo() {
    _undone.clear();
    for (final action in _actions.reversed) {
      if (_shouldUndoAction?.call(action) == false) continue;
      action.undo();
      _undone.add(action);
    }
  }

  @override
  void redo() {
    // Only replay actions actually reversed by Undo. A temporary layer consumed
    // by a later merge must not be recreated from an old removed-layer cache.
    for (final action in _undone.reversed) {
      action.redo();
    }
  }
}

/// 描画操作（ペン・消しゴム・バケツ・投げ縄塗り・トーン・スタンプ・
/// 移動・変形・図形）のUndo/Redo。TileManagerが記録した変更差分
/// （実際に変更のあったタイルのみ）を適用し直すことで元に戻す／やり直す。
class TileUndoAction extends UndoAction {
  final TileManager tileManager;
  final String layerId;
  final Map<String, Uint8List?> before;
  final Map<String, Uint8List?> after;
  final VoidCallback onApply;
  final HistoryFrame? editingFrame;

  TileUndoAction({
    required this.tileManager,
    required this.layerId,
    required this.before,
    required this.after,
    required this.onApply,
    this.editingFrame,
  });

  @override
  void undo() {
    tileManager.applyTileSnapshot(layerId, before);
    onApply();
  }

  @override
  void redo() {
    tileManager.applyTileSnapshot(layerId, after);
    onApply();
  }

  @override
  String get description => 'Draw on $layerId';

  @override
  HistoryFrame? frameForHistory({required bool redo}) {
    if (editingFrame != null) return editingFrame;
    final key = parseFrameLayerKey(layerId);
    return key == null
        ? null
        : (sceneId: key.sceneId, frameIndex: key.frameIndex);
  }
}

/// レイヤー追加のUndo/Redo。
/// 復元時に元の挿入位置を失わないよう、insertIndexもコールバックへ渡す。
class LayerAddUndoAction extends UndoAction {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String layerId;
  final int insertIndex;
  final String? materialId;
  final void Function(
    String projectId,
    String sceneId,
    int frameIndex,
    String layerId,
    int insertIndex,
  )
  _doAdd;
  final void Function(
    String projectId,
    String sceneId,
    int frameIndex,
    String layerId,
  )
  _doRemove;

  LayerAddUndoAction({
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.layerId,
    required this.insertIndex,
    this.materialId,
    required this._doAdd,
    required this._doRemove,
  });

  @override
  void undo() => _doRemove(projectId, sceneId, frameIndex, layerId);

  @override
  void redo() => _doAdd(projectId, sceneId, frameIndex, layerId, insertIndex);

  @override
  String get description => 'Add layer $layerId';

  @override
  HistoryFrame frameForHistory({required bool redo}) =>
      (sceneId: sceneId, frameIndex: frameIndex);
}

/// レイヤー削除のUndo/Redo。
/// Undo時に元のremovedIndexへ戻すことでレイヤー順を完全に復元する。
class LayerRemoveUndoAction extends UndoAction {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String layerId;
  final int removedIndex;
  final String? materialId;
  final void Function(
    String projectId,
    String sceneId,
    int frameIndex,
    String layerId,
    int insertIndex,
  )
  _doAdd;
  final void Function(
    String projectId,
    String sceneId,
    int frameIndex,
    String layerId,
  )
  _doRemove;

  LayerRemoveUndoAction({
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.layerId,
    required this.removedIndex,
    this.materialId,
    required this._doAdd,
    required this._doRemove,
  });

  @override
  void undo() => _doAdd(projectId, sceneId, frameIndex, layerId, removedIndex);

  @override
  void redo() => _doRemove(projectId, sceneId, frameIndex, layerId);

  @override
  String get description => 'Remove layer $layerId';

  @override
  HistoryFrame frameForHistory({required bool redo}) =>
      (sceneId: sceneId, frameIndex: frameIndex);
}
