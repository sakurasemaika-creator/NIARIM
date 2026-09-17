from pathlib import Path

OVERLAY = Path('lib/screens/canvas/widgets/auto_lineart_control_overlay.dart')
PANEL = Path('lib/screens/canvas/widgets/filter_panel.dart')
TEST = Path('test/auto_lineart_control_overlay_test.dart')

s = OVERLAY.read_text()
if 'onGraphChanged' not in s:
    s = s.replace(
        '  onPointMoved;\n',
        '  onPointMoved;\n  final ValueChanged<AutoLineartGraph>? onGraphChanged;\n',
        1,
    )
    s = s.replace(
        '    required this.onPointMoved,\n',
        '    required this.onPointMoved,\n    this.onGraphChanged,\n',
        1,
    )
    s = s.replace(
        '  int? _activePointer;\n',
        '  int? _activePointer;\n  Offset? _pointerDown;\n  bool _dragged = false;\n',
        1,
    )

    marker = '''  void _finishPointer(int pointer) {
    if (_activePointer != pointer) return;
    _active = null;
    _activePointer = null;
  }
'''
    helpers = r'''  (int, int)? _hitSegment(Offset local, Rect rect) {
    const radius = 14.0;
    var best = radius * radius;
    (int, int)? result;
    for (var p = 0; p < _displayGraph.paths.length; p++) {
      final points = _displayGraph.paths[p].points;
      for (var i = 0; i < points.length - 1; i++) {
        final a = _toScreen(points[i], rect);
        final b = _toScreen(points[i + 1], rect);
        final ab = b - a;
        final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
        if (length2 <= 0) continue;
        final ap = local - a;
        final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / length2).clamp(0.0, 1.0);
        final nearest = a + ab * t;
        final d = (nearest - local).distanceSquared;
        if (d <= best) {
          best = d;
          result = (p, i + 1);
        }
      }
    }
    return result;
  }

  AutoLineartGraph _withPointInserted(
    int pathIndex,
    int pointIndex,
    AutoLineartPoint point,
  ) {
    final paths = List<AutoLineartPath>.from(_displayGraph.paths);
    final old = paths[pathIndex];
    final points = List<AutoLineartPoint>.from(old.points)..insert(pointIndex, point);
    paths[pathIndex] = AutoLineartPath(
      points: points,
      startIsJunction: old.startIsJunction,
      endIsJunction: old.endIsJunction,
      persistence: old.persistence,
    );
    return AutoLineartGraph(
      width: _displayGraph.width,
      height: _displayGraph.height,
      paths: paths,
      analysisWidth: _displayGraph.analysisWidth,
      analysisHeight: _displayGraph.analysisHeight,
    );
  }

  AutoLineartGraph _withPointDeleted(int pathIndex, int pointIndex) {
    final paths = List<AutoLineartPath>.from(_displayGraph.paths);
    final old = paths[pathIndex];
    final points = List<AutoLineartPoint>.from(old.points)..removeAt(pointIndex);
    if (points.length < 2) {
      paths.removeAt(pathIndex);
    } else {
      paths[pathIndex] = AutoLineartPath(
        points: points,
        startIsJunction: pointIndex == 0 ? false : old.startIsJunction,
        endIsJunction: pointIndex == old.points.length - 1 ? false : old.endIsJunction,
        persistence: old.persistence,
      );
    }
    return AutoLineartGraph(
      width: _displayGraph.width,
      height: _displayGraph.height,
      paths: paths,
      analysisWidth: _displayGraph.analysisWidth,
      analysisHeight: _displayGraph.analysisHeight,
    );
  }

  void _publishGraph(AutoLineartGraph graph) {
    setState(() => _displayGraph = graph);
    widget.onGraphChanged?.call(graph);
  }

  Future<void> _confirmDelete((int, int) active) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('制御点を削除'),
        content: const Text('この制御点を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    _publishGraph(_withPointDeleted(active.$1, active.$2));
  }

  void _finishPointer(int pointer, {bool cancelled = false}) {
    if (_activePointer != pointer) return;
    final active = _active;
    final shouldDelete = !cancelled && !_dragged && active != null;
    _active = null;
    _activePointer = null;
    _pointerDown = null;
    _dragged = false;
    if (shouldDelete) _confirmDelete(active);
  }
'''
    if marker not in s:
        raise SystemExit('overlay finish-pointer marker not found')
    s = s.replace(marker, helpers, 1)

    old_down = '''          onPointerDown: (event) {
            final active = _hit(event.localPosition, rect);
            if (active == null) return;
            _active = active;
            _activePointer = event.pointer;
          },
'''
    new_down = '''          onPointerDown: (event) {
            final active = _hit(event.localPosition, rect);
            if (active != null) {
              _active = active;
              _activePointer = event.pointer;
              _pointerDown = event.localPosition;
              _dragged = false;
              return;
            }
            final segment = _hitSegment(event.localPosition, rect);
            if (segment == null) return;
            final point = _toGraph(event.localPosition, rect);
            _publishGraph(_withPointInserted(segment.$1, segment.$2, point));
          },
'''
    if old_down not in s:
        raise SystemExit('overlay pointer-down marker not found')
    s = s.replace(old_down, new_down, 1)

    s = s.replace(
        '            final point = _toGraph(event.localPosition, rect);\n            setState(() {',
        '''            final down = _pointerDown;
            if (down != null && (event.localPosition - down).distance > 4) {
              _dragged = true;
            }
            final point = _toGraph(event.localPosition, rect);
            setState(() {''',
        1,
    )
    s = s.replace(
        '                point: point,\n              );',
        '                point: point,\n                moveCoincident: false,\n              );',
        1,
    )
    s = s.replace(
        '          onPointerCancel: (event) => _finishPointer(event.pointer),',
        '          onPointerCancel: (event) => _finishPointer(event.pointer, cancelled: true),',
        1,
    )
    OVERLAY.write_text(s)

p = PANEL.read_text()
if 'onGraphChanged: (graph)' not in p:
    needle = '''                                              _autoLineartManualEdited = true;
                                              _scheduleAutoLineartPreviewUpdate();
                                            },
                                          )
'''
    replacement = '''                                              _autoLineartManualEdited = true;
                                              _scheduleAutoLineartPreviewUpdate();
                                            },
                                            onGraphChanged: (graph) {
                                              _autoLineartPreviewGraph = graph;
                                              _autoLineartManualEdited = true;
                                              _scheduleAutoLineartPreviewUpdate();
                                            },
                                          )
'''
    if needle not in p:
        raise SystemExit('filter-panel overlay callback marker not found')
    p = p.replace(needle, replacement, 1)
    old = '''                                                    pointIndex: pointIndex,
                                                    point: point,
                                                  );'''
    new = '''                                                    pointIndex: pointIndex,
                                                    point: point,
                                                    moveCoincident: false,
                                                  );'''
    if old in p:
        p = p.replace(old, new, 1)
    PANEL.write_text(p)

# Add focused interaction tests once. They deliberately exercise the production widget.
t = TEST.read_text()
if 'tap on vector segment adds a control point' not in t:
    insert = r'''
  testWidgets('tap on vector segment adds a control point', (tester) async {
    final image = await _makeImage(100, 100);
    AutoLineartGraph? changed;
    const graph = AutoLineartGraph(
      width: 100,
      height: 100,
      paths: [AutoLineartPath(
        points: [AutoLineartPoint(20, 50), AutoLineartPoint(80, 50)],
        startIsJunction: false,
        endIsJunction: false,
        persistence: 1,
      )],
    );
    await tester.pumpWidget(MaterialApp(home: Center(child: SizedBox(
      width: 200,
      height: 200,
      child: AutoLineartControlOverlay(
        image: image,
        graph: graph,
        onPointMoved: (_, _, _) {},
        onGraphChanged: (value) => changed = value,
      ),
    ))));
    final rect = tester.getRect(find.byType(AutoLineartControlOverlay));
    await tester.tapAt(rect.center);
    await tester.pump();
    expect(changed, isNotNull);
    expect(changed!.paths.single.points, hasLength(3));
    image.dispose();
  });

  testWidgets('control point tap asks before deletion and cancel preserves it', (tester) async {
    final image = await _makeImage(100, 100);
    AutoLineartGraph? changed;
    const graph = AutoLineartGraph(
      width: 100,
      height: 100,
      paths: [AutoLineartPath(
        points: [AutoLineartPoint(20, 50), AutoLineartPoint(50, 50), AutoLineartPoint(80, 50)],
        startIsJunction: false,
        endIsJunction: false,
        persistence: 1,
      )],
    );
    await tester.pumpWidget(MaterialApp(home: Center(child: SizedBox(
      width: 200,
      height: 200,
      child: AutoLineartControlOverlay(
        image: image,
        graph: graph,
        onPointMoved: (_, _, _) {},
        onGraphChanged: (value) => changed = value,
      ),
    ))));
    final rect = tester.getRect(find.byType(AutoLineartControlOverlay));
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    expect(find.text('制御点を削除'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(changed, isNull);

    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(changed, isNotNull);
    expect(changed!.paths.single.points, hasLength(2));
    image.dispose();
  });
'''
    pos = t.rfind('\n}')
    if pos < 0:
        raise SystemExit('test main closing brace not found')
    t = t[:pos] + insert + t[pos:]
    TEST.write_text(t)
