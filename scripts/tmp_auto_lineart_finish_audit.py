from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1):
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f'anchor not found in {path}: {old[:120]!r}')
    p.write_text(s.replace(old, new, count))

# Make generated-layer insertion position part of the undo action, instead of
# adding at index 0 and reordering afterward (which made redo restore index 0).
p = Path('lib/services/project_service.dart')
s = p.read_text()
s = s.replace(
    '''    required LayerType type,
    required String name,
    String? id,
  }) {
    final layerId = id ?? _nextLayerId(projectId);
    final layer = Layer(id: layerId, name: name, type: type);
    _applyLayerInsert(projectId, sceneId, frameIndex, layer, 0);''',
    '''    required LayerType type,
    required String name,
    String? id,
    int insertIndex = 0,
  }) {
    final layerId = id ?? _nextLayerId(projectId);
    final layer = Layer(id: layerId, name: name, type: type);
    final frameLayers = layersOf(projectId, sceneId, frameIndex);
    final safeInsertIndex = insertIndex.clamp(0, frameLayers.length);
    _applyLayerInsert(
      projectId,
      sceneId,
      frameIndex,
      layer,
      safeInsertIndex,
    );''',
    1,
)
s = s.replace(
    '''        insertIndex: 0,
        doAdd: _insertLayerById,
        doRemove: _removeLayerById,
      ),
    );
    return layer;
  }

  /// レイヤーを複製する''',
    '''        insertIndex: safeInsertIndex,
        doAdd: _insertLayerById,
        doRemove: _removeLayerById,
      ),
    );
    return layer;
  }

  /// レイヤーを複製する''',
    1,
)
p.write_text(s)

p = Path('lib/screens/canvas/widgets/filter_panel.dart')
s = p.read_text()
old = '''    final sourceName = sourceLayer?.name ?? 'Layer';
    final created = ps.addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name: nameBuilder(sourceName),
      id: generatedLayerId,
    );
    final layers = ps.layersOf(widget.projectId, widget.sceneId, frameIndex);
    final createdIndex = layers.indexWhere((l) => l.id == created.id);
    final sourceIndex = layers.indexWhere((l) => l.id == sourceLayerId);
    final targetIndex = sourceIndex < 0 ? createdIndex : sourceIndex + 1;
    if (createdIndex >= 0 && targetIndex >= 0 && createdIndex != targetIndex) {
      ps.reorderLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: frameIndex,
        oldIndex: createdIndex,
        newIndex: targetIndex,
      );
    }'''
new = '''    final sourceName = sourceLayer?.name ?? 'Layer';
    final before = ps.layersOf(widget.projectId, widget.sceneId, frameIndex);
    final sourceIndex = before.indexWhere((l) => l.id == sourceLayerId);
    final targetIndex = sourceIndex < 0 ? 0 : sourceIndex + 1;
    final created = ps.addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name: nameBuilder(sourceName),
      id: generatedLayerId,
      insertIndex: targetIndex,
    );'''
if old not in s:
    raise SystemExit('generated layer reorder block not found')
p.write_text(s.replace(old, new, 1))

# Two-finger gestures must cancel an active control drag. Outside this 200px
# preview the Canvas keeps receiving its normal pinch gesture.
p = Path('lib/screens/canvas/widgets/auto_lineart_control_overlay.dart')
s = p.read_text()
s = s.replace(
    'class _AutoLineartControlOverlayState extends State<AutoLineartControlOverlay> {\n  (int, int)? _active;',
    'class _AutoLineartControlOverlayState extends State<AutoLineartControlOverlay> {\n  (int, int)? _active;\n  int _pointerCount = 0;',
    1,
)
old = '''        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _active = _hit(details.localPosition, rect),
          onPanUpdate: (details) {
            final active = _active;
            if (active == null) return;
            widget.onPointMoved(
              active.$1,
              active.$2,
              _toGraph(details.localPosition, rect),
            );
          },
          onPanEnd: (_) => _active = null,
          onPanCancel: () => _active = null,
          child: Stack('''
new = '''        return Listener(
          onPointerDown: (_) {
            _pointerCount++;
            if (_pointerCount > 1) _active = null;
          },
          onPointerUp: (_) => _pointerCount = math.max(0, _pointerCount - 1),
          onPointerCancel: (_) {
            _pointerCount = math.max(0, _pointerCount - 1);
            _active = null;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              if (_pointerCount <= 1) {
                _active = _hit(details.localPosition, rect);
              }
            },
            onPanUpdate: (details) {
              final active = _active;
              if (active == null || _pointerCount > 1) return;
              widget.onPointMoved(
                active.$1,
                active.$2,
                _toGraph(details.localPosition, rect),
              );
            },
            onPanEnd: (_) => _active = null,
            onPanCancel: () => _active = null,
            child: Stack('''
if old not in s:
    raise SystemExit('overlay gesture block not found')
s = s.replace(old, new, 1)
# Listener + GestureDetector add one extra nesting level before LayoutBuilder close.
old_close = '''            ],
          ),
        );
      },
    );'''
new_close = '''              ],
            ),
          ),
        );
      },
    );'''
if old_close not in s:
    raise SystemExit('overlay close block not found')
s = s.replace(old_close, new_close, 1)
p.write_text(s)

# Add a two-pointer regression to overlay tests.
p = Path('test/auto_lineart_control_overlay_test.dart')
s = p.read_text()
insert_marker = '\n  testWidgets(\n    \'control hit target stays screen-fixed at 4x graph scale\','
if insert_marker not in s:
    raise SystemExit('overlay test marker not found')
insert = r'''

  testWidgets('second pointer cancels a control drag instead of moving it', (
    tester,
  ) async {
    final graph = AutoLineartGraph(
      width: 100,
      height: 100,
      paths: const [
        AutoLineartPath(
          points: [AutoLineartPoint(25, 50), AutoLineartPoint(75, 50)],
          startIsJunction: false,
          endIsJunction: false,
          persistence: 1,
        ),
      ],
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..color = Colors.white,
    );
    final image = await recorder.endRecording().toImage(100, 100);
    addTearDown(image.dispose);
    final moves = <AutoLineartPoint>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: AutoLineartControlOverlay(
            image: image,
            graph: graph,
            onPointMoved: (_, _, point) => moves.add(point),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(AutoLineartControlOverlay));
    final first = await tester.startGesture(
      Offset(box.left + 50, box.top + 100),
      pointer: 1,
    );
    final second = await tester.startGesture(
      Offset(box.left + 160, box.top + 160),
      pointer: 2,
    );
    await first.moveBy(const Offset(30, -20));
    await tester.pump();
    await second.up();
    await first.up();
    expect(moves, isEmpty);
  });
'''
s = s.replace(insert_marker, insert + insert_marker, 1)
p.write_text(s)
