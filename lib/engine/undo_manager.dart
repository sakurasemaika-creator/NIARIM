import 'package:flutter/foundation.dart';

import '../models/ruler.dart';
import 'tile_manager.dart';

class UndoManager extends ChangeNotifier {
  final List<UndoAction> _undoStack = [];
  final List<UndoAction> _redoStack = [];
  int _maxUndoCount = 50;

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void setMaxUndoCount(int count) {
    _maxUndoCount = count;
    while (_undoStack.length > _maxUndoCount) {
      _undoStack.removeAt(0);
    }
  }

  void push(UndoAction action) {
    _undoStack.add(action);
    _redoStack.clear();
    if (_undoStack.length > _maxUndoCount) _undoStack.removeAt(0);
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    final action = _undoStack.removeLast();
    action.undo();
    _redoStack.add(action);
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final action = _redoStack.removeLast();
    action.redo();
    _undoStack.add(action);
    notifyListeners();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}

abstract class UndoAction {
  void undo();
  void redo();
  String get description;
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

  TileUndoAction({
    required this.tileManager,
    required this.layerId,
    required this.before,
    required this.after,
    required this.onApply,
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
}

/// レイヤー追加のUndo/Redo。
/// 復元時に元の挿入位置を失わないよう、insertIndexもコールバックへ渡す。
class LayerAddUndoAction extends UndoAction {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String layerId;
  final int insertIndex;
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
    required void Function(
      String projectId,
      String sceneId,
      int frameIndex,
      String layerId,
      int insertIndex,
    )
    doAdd,
    required void Function(
      String projectId,
      String sceneId,
      int frameIndex,
      String layerId,
    )
    doRemove,
  }) : _doAdd = doAdd,
       _doRemove = doRemove;

  @override
  void undo() => _doRemove(projectId, sceneId, frameIndex, layerId);

  @override
  void redo() => _doAdd(projectId, sceneId, frameIndex, layerId, insertIndex);

  @override
  String get description => 'Add layer $layerId';
}

/// レイヤー削除のUndo/Redo。
/// Undo時に元のremovedIndexへ戻すことでレイヤー順を完全に復元する。
class LayerRemoveUndoAction extends UndoAction {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String layerId;
  final int removedIndex;
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
    required void Function(
      String projectId,
      String sceneId,
      int frameIndex,
      String layerId,
      int insertIndex,
    )
    doAdd,
    required void Function(
      String projectId,
      String sceneId,
      int frameIndex,
      String layerId,
    )
    doRemove,
  }) : _doAdd = doAdd,
       _doRemove = doRemove;

  @override
  void undo() => _doAdd(projectId, sceneId, frameIndex, layerId, removedIndex);

  @override
  void redo() => _doRemove(projectId, sceneId, frameIndex, layerId);

  @override
  String get description => 'Remove layer $layerId';
}

/// 定規の作成・削除・移動・回転・サイズ変更・消失点変更のUndo/Redo。
class RulerUndoAction extends UndoAction {
  final Ruler? before;
  final Ruler? after;
  final ValueChanged<Ruler?> onApply;

  RulerUndoAction({
    required this.before,
    required this.after,
    required this.onApply,
  });

  @override
  void undo() => onApply(before);

  @override
  void redo() => onApply(after);

  @override
  String get description => '定規を編集';
}
