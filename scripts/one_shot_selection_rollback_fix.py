#!/usr/bin/env python3
from pathlib import Path


def replace_exact(path, old, new, expected=1):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: guard failed, expected {expected}, found {count}')
    p.write_text(text.replace(old, new), encoding='utf-8', newline='\n')
    print(f'patched {path}')

# TileManager: add an explicit rollback primitive for interrupted operations.
replace_exact(
    'lib/engine/tile_manager.dart',
    '''  /// Undo/Redo用：タイルスナップショットをレイヤーへ適用する。\n  /// 値がnullのキーはタイルを削除する（記録時点で未描画だったことを意味する）。\n  void applyTileSnapshot(String layerId, Map<String, Uint8List?> snapshot) {\n''',
    '''  /// Undo記録中の操作をキャンセルし、変更済みタイルを記録開始直前へ\n  /// 即座に戻す。選択変形の浮動画像生成が間に合わずpointer-upされた場合や、\n  /// 変形途中でフレームを切り替えた場合など「操作自体を成立させない」用途。\n  /// Undo履歴へは登録せず、操作前状態へ完全復元する。\n  void cancelUndoRecordingAndRestore() {\n    final layerId = _recordingLayerId;\n    final before = Map<String, Uint8List?>.from(_undoBefore);\n    _recordingUndo = false;\n    _recordingLayerId = null;\n    _undoBefore.clear();\n    if (layerId == null || before.isEmpty) return;\n    applyTileSnapshot(layerId, before);\n  }\n\n  /// Undo/Redo用：タイルスナップショットをレイヤーへ適用する。\n  /// 値がnullのキーはタイルを削除する（記録時点で未描画だったことを意味する）。\n  void applyTileSnapshot(String layerId, Map<String, Uint8List?> snapshot) {\n''',
)

# CanvasArea: central rollback helper adjacent to normal finish helper.
replace_exact(
    'lib/screens/canvas/widgets/canvas_area.dart',
    '''  void _finishTileUndo() {\n    final snapshot = _tileManager.endUndoRecording();\n    final layerKey = _undoRecordingLayerKey;\n    _undoRecordingLayerKey = null;\n    if (snapshot.before.isEmpty || layerKey == null) return;\n    context.read<app_undo.UndoManager>().push(\n      app_undo.TileUndoAction(\n        tileManager: _tileManager,\n        layerId: layerKey,\n        before: snapshot.before,\n        after: snapshot.after,\n        onApply: () {\n          if (mounted) _scheduleComposite();\n        },\n      ),\n    );\n  }\n''',
    '''  void _finishTileUndo() {\n    final snapshot = _tileManager.endUndoRecording();\n    final layerKey = _undoRecordingLayerKey;\n    _undoRecordingLayerKey = null;\n    if (snapshot.before.isEmpty || layerKey == null) return;\n    context.read<app_undo.UndoManager>().push(\n      app_undo.TileUndoAction(\n        tileManager: _tileManager,\n        layerId: layerKey,\n        before: snapshot.before,\n        after: snapshot.after,\n        onApply: () {\n          if (mounted) _scheduleComposite();\n        },\n      ),\n    );\n  }\n\n  /// 開始済みのタイルUndo記録を履歴へ残さずキャンセルし、操作開始前の\n  /// タイルへ即時復元する。非同期プレビューの準備前に操作が終了した場合など、\n  /// 「途中までの変更」を絶対にレイヤーへ残してはいけない経路で使う。\n  void _cancelTileUndoAndRestore() {\n    _tileManager.cancelUndoRecordingAndRestore();\n    _undoRecordingLayerKey = null;\n    if (mounted) _scheduleComposite();\n  }\n''',
)

# Pointer-up before floating image is ready: rollback, don't commit the hole.
replace_exact(
    'lib/screens/canvas/widgets/canvas_area.dart',
    '''    if (floating == null) {\n      // 浮動画像の生成が間に合わないうちに指を離した場合：既に切り取り済みの\n      // 穴だけが残らないよう、Undoで元に戻せる状態のまま記録を終了する。\n      _finishTileUndo();\n      return;\n    }\n''',
    '''    if (floating == null) {\n      // 浮動画像の生成が間に合わないうちに指を離した場合：変形操作は成立\n      // していないので、切り取り途中の画素をUndo履歴として残すのではなく、\n      // 操作開始直前へ即時ロールバックする。\n      _cancelTileUndoAndRestore();\n      return;\n    }\n''',
)

# Frame switch during an active selection transform must rollback cut pixels first.
replace_exact(
    'lib/screens/canvas/widgets/canvas_area.dart',
    '''      if (_selectionTransformActive) {\n        _floatingSelectionImage?.dispose();\n        _floatingSelectionImage = null;\n        _selectionTransformActive = false;\n        _selectionTransformStart = null;\n        _selectionTransformCenter = null;\n        _selectionTransformBounds = null;\n        _selectionTransformLive = null;\n      }\n''',
    '''      if (_selectionTransformActive) {\n        _cancelTileUndoAndRestore();\n        _floatingSelectionImage?.dispose();\n        _floatingSelectionImage = null;\n        _selectionTransformActive = false;\n        _selectionTransformStart = null;\n        _selectionTransformCenter = null;\n        _selectionTransformBounds = null;\n        _selectionTransformLive = null;\n      }\n''',
)

# Leaving the canvas while a selection transform is active must not persist a cut-out hole.
replace_exact(
    'lib/screens/canvas/widgets/canvas_area.dart',
    '''  @override\n  void dispose() {\n    _holdEyedropperTimer?.cancel();\n''',
    '''  @override\n  void dispose() {\n    if (_selectionTransformActive && _undoRecordingLayerKey != null) {\n      _tileManager.cancelUndoRecordingAndRestore();\n      _undoRecordingLayerKey = null;\n    }\n    _holdEyedropperTimer?.cancel();\n''',
)

print('all guarded selection rollback patches applied')
