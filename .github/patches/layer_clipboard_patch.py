from pathlib import Path

# TextObject ID must follow a duplicated text layer's new Layer ID.
path = Path('lib/models/text_object.dart')
text = path.read_text()
anchor = "  TextObject copyWith({\n    String? text,"
replacement = "  TextObject copyWith({\n    String? id,\n    String? text,"
if text.count(anchor) != 1:
    raise SystemExit(f'text copyWith anchor count={text.count(anchor)}')
text = text.replace(anchor, replacement, 1)
anchor = "  }) {\n    return TextObject(\n      id: id,\n      text: text ?? this.text,"
replacement = "  }) {\n    return TextObject(\n      id: id ?? this.id,\n      text: text ?? this.text,"
if text.count(anchor) != 1:
    raise SystemExit(f'text id anchor count={text.count(anchor)}')
path.write_text(text.replace(anchor, replacement, 1))

# ProjectService exact-index insertion for metadata + pixel snapshots.
path = Path('lib/services/project_service.dart')
text = path.read_text()
marker = "  /// レイヤーを複製する（メタデータ・キーフレーム等の設定に加えて"
if text.count(marker) != 1:
    raise SystemExit(f'insert snapshot marker count={text.count(marker)}')
method = '''  /// コピー時に保持したレイヤーのメタデータと画素を、既存レイヤーを
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
      tileManagerOf(projectId).replaceLayerPixels(
        targetKey,
        Uint8List.fromList(pixels),
      );
    }
    _undoManager?.push(
      LayerAddUndoAction(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layerId: newId,
        insertIndex: targetIndex,
        doAdd: _insertLayerById,
        doRemove: _removeLayerById,
      ),
    );
    return copy;
  }

'''
text = text.replace(marker, method + marker, 1)
path.write_text(text)

# LayerPanel row gestures.
path = Path('lib/screens/canvas/widgets/layer_panel.dart')
text = path.read_text()
anchor = "import '../../../services/project_service.dart';\nimport '../../../services/tone_service.dart';"
replacement = "import '../../../services/project_service.dart';\nimport '../../../services/layer_clipboard_service.dart';\nimport '../../../services/tone_service.dart';"
if text.count(anchor) != 1:
    raise SystemExit(f'clipboard import anchor count={text.count(anchor)}')
text = text.replace(anchor, replacement, 1)
anchor = "import 'panel_close_bar.dart';\nimport '../../../config/font_fallback.dart';"
replacement = "import 'panel_close_bar.dart';\nimport 'two_finger_vertical_swipe_detector.dart';\nimport '../../../config/font_fallback.dart';"
if text.count(anchor) != 1:
    raise SystemExit(f'gesture import anchor count={text.count(anchor)}')
text = text.replace(anchor, replacement, 1)
anchor = "                return ListTile(\n                  key: ValueKey(layer.id),"
replacement = '''                return TwoFingerVerticalSwipeDetector(
                  key: ValueKey(layer.id),
                  onSwipeUp: () => _copyLayerWithGesture(context, layer),
                  onSwipeDown: () => _pasteLayerBeforeWithGesture(
                    context,
                    layer,
                  ),
                  child: ListTile(
                    key: ValueKey(layer.id),'''
if text.count(anchor) != 1:
    raise SystemExit(f'row wrapper anchor count={text.count(anchor)}')
text = text.replace(anchor, replacement, 1)
anchor = '''                  onLongPress: () => setState(() {
                    if (!_isSelectionMode) {
                      _isSelectionMode = true;
                      _selectionBaseType = layer.type;
                      _selectedIds.add(layer.id);
                    }
                  }),
                );'''
replacement = '''                    onLongPress: () => setState(() {
                      if (!_isSelectionMode) {
                        _isSelectionMode = true;
                        _selectionBaseType = layer.type;
                        _selectedIds.add(layer.id);
                      }
                    }),
                  ),
                );'''
if text.count(anchor) != 1:
    raise SystemExit(f'row wrapper close anchor count={text.count(anchor)}')
text = text.replace(anchor, replacement, 1)
marker = "  Widget _layerTypeIcon(BuildContext context, model.LayerType type) {"
methods = '''  Future<void> _copyLayerWithGesture(
    BuildContext context,
    model.Layer layer,
  ) async {
    final projectService = context.read<ProjectService>();
    final copied = await LayerClipboardService.instance.copy(
      projectService: projectService,
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerId: layer.id,
    );
    if (!mounted || !copied) return;
    final refreshed = _visibleLayers(
      projectService.layersOf(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
      ),
    );
    final index = refreshed.indexWhere((item) => item.id == layer.id);
    if (index >= 0) setState(() => _selectedIndex = index);
  }

  void _pasteLayerBeforeWithGesture(
    BuildContext context,
    model.Layer target,
  ) {
    final projectService = context.read<ProjectService>();
    final pasted = LayerClipboardService.instance.pasteBefore(
      projectService: projectService,
      projectId: widget.projectId,
      targetSceneId: widget.sceneId,
      targetFrameIndex: widget.frameIndex,
      beforeLayerId: target.id,
    );
    if (pasted == null) return;
    final refreshed = _visibleLayers(
      projectService.layersOf(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
      ),
    );
    final index = refreshed.indexWhere((item) => item.id == pasted.id);
    if (index >= 0) setState(() => _selectedIndex = index);
    if (pasted.type != model.LayerType.folder) {
      widget.onLayerSelected?.call(pasted.id);
    }
  }

'''
if text.count(marker) != 1:
    raise SystemExit(f'layer helper marker count={text.count(marker)}')
text = text.replace(marker, methods + marker, 1)
path.write_text(text)

# Keyboard shortcuts use the same cross-frame snapshot clipboard.
path = Path('lib/screens/canvas/canvas_screen.dart')
text = path.read_text()
anchor = "import '../../services/project_service.dart';\nimport '../../services/brush_service.dart';"
replacement = "import '../../services/project_service.dart';\nimport '../../services/layer_clipboard_service.dart';\nimport '../../services/brush_service.dart';"
if text.count(anchor) != 1:
    raise SystemExit(f'canvas clipboard import anchor count={text.count(anchor)}')
text = text.replace(anchor, replacement, 1)
field = '''  // ショートカット（Ctrl+C/Ctrl+V）で現在アクティブなレイヤーを
  // コピー＆ペーストするための、セッション内のみのクリップボード。
  String? _copiedLayerId;
'''
if text.count(field) != 1:
    raise SystemExit(f'old copied field count={text.count(field)}')
text = text.replace(field, '', 1)
old = '''  /// 現在アクティブなレイヤーをコピー（Ctrl+C）。
  void _copyActiveLayer() {
    if (_currentLayerId == null) return;
    setState(() => _copiedLayerId = _currentLayerId);
  }

  /// コピー済みのレイヤーを複製して貼り付ける（Ctrl+V）。ピクセル内容も
  /// 含めて元レイヤーのすぐ上に複製し、複製後のレイヤーをアクティブにする。
  void _pasteCopiedLayer() {
    final sourceId = _copiedLayerId;
    if (sourceId == null) return;
    final copy = context.read<ProjectService>().duplicateLayer(
      projectId: widget.projectId,
      sceneId: _currentSceneId,
      frameIndex: _currentFrame,
      layerId: sourceId,
      nameOverride: null,
    );
    if (copy == null) return;
    setState(() => _currentLayerId = copy.id);
  }
'''
new = '''  /// 現在アクティブなレイヤーをコピー（Ctrl+C）。2本指上スワイプと
  /// 同じスナップショット式クリップボードを使うため、フレーム移動後も貼れる。
  void _copyActiveLayer() {
    final layerId = _currentLayerId;
    if (layerId == null) return;
    LayerClipboardService.instance.copy(
      projectService: context.read<ProjectService>(),
      projectId: widget.projectId,
      sceneId: _currentSceneId,
      frameIndex: _currentFrame,
      layerId: layerId,
    );
  }

  /// Ctrl+Vは現在アクティブなレイヤーの直前へ割り込み挿入する。
  /// 2本指下スワイプと同じく既存レイヤーを上書きしない。
  void _pasteCopiedLayer() {
    final targetId = _currentLayerId;
    if (targetId == null) return;
    final copy = LayerClipboardService.instance.pasteBefore(
      projectService: context.read<ProjectService>(),
      projectId: widget.projectId,
      targetSceneId: _currentSceneId,
      targetFrameIndex: _currentFrame,
      beforeLayerId: targetId,
    );
    if (copy == null) return;
    setState(() => _currentLayerId = copy.id);
  }
'''
if text.count(old) != 1:
    raise SystemExit(f'keyboard methods anchor count={text.count(old)}')
path.write_text(text.replace(old, new, 1))
