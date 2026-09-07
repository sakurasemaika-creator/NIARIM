from pathlib import Path

# ---- engine ---------------------------------------------------------------
engine = Path('lib/engine/auto_lineart_engine.dart')
s = engine.read_text(encoding='utf-8')
anchor = '  static Uint8List render(\n'
if 'prepareEditableGraph(' not in s:
    helper = r'''  /// Converts an analyzed topology graph into the temporary editable control
  /// polygon used by the preview. [smoothingLevel] is intentionally discrete
  /// (0..10): higher levels smooth the control polygon and retain fewer points.
  /// Junction/end anchors stay as path endpoints so topology is not detached.
  static AutoLineartGraph prepareEditableGraph(
    AutoLineartGraph source, {
    required int smoothingLevel,
  }) {
    final level = smoothingLevel.clamp(0, 10);
    if (level == 0 || source.paths.isEmpty) return source;

    final paths = <AutoLineartPath>[];
    for (final path in source.paths) {
      final original = path.points;
      if (original.length <= 2) {
        paths.add(path);
        continue;
      }

      var work = List<AutoLineartPoint>.from(original);
      final passes = math.max(1, level);
      final amount = 0.12 + level * 0.025;
      for (var pass = 0; pass < passes; pass++) {
        final next = List<AutoLineartPoint>.from(work);
        for (var i = 1; i < work.length - 1; i++) {
          final prev = work[i - 1];
          final cur = work[i];
          final after = work[i + 1];
          next[i] = AutoLineartPoint(
            cur.x + (((prev.x + after.x) * 0.5) - cur.x) * amount,
            cur.y + (((prev.y + after.y) * 0.5) - cur.y) * amount,
          );
        }
        // Never move topology anchors through automatic smoothing.
        next[0] = original.first;
        next[next.length - 1] = original.last;
        work = next;
      }

      // Retain 92% -> 20% of interior controls over the ten levels. Selecting
      // evenly from the smoothed polygon avoids a bias toward either endpoint.
      final target = math.max(
        2,
        (original.length * (1.0 - level * 0.08)).round(),
      );
      final keepCount = math.min(work.length, target);
      final reduced = <AutoLineartPoint>[];
      for (var i = 0; i < keepCount; i++) {
        final index = keepCount == 1
            ? 0
            : (i * (work.length - 1) / (keepCount - 1)).round();
        final point = work[index];
        if (reduced.isEmpty ||
            reduced.last.x != point.x ||
            reduced.last.y != point.y) {
          reduced.add(point);
        }
      }
      if (reduced.length < 2) {
        reduced
          ..clear()
          ..add(work.first)
          ..add(work.last);
      } else {
        reduced[0] = original.first;
        reduced[reduced.length - 1] = original.last;
      }

      paths.add(
        AutoLineartPath(
          points: reduced,
          startIsJunction: path.startIsJunction,
          endIsJunction: path.endIsJunction,
          persistence: path.persistence,
        ),
      );
    }

    return AutoLineartGraph(
      width: source.width,
      height: source.height,
      paths: paths,
      analysisWidth: source.analysisWidth,
      analysisHeight: source.analysisHeight,
    );
  }

  /// Moves one preview control point. Coincident points (normally the endpoints
  /// of branches sharing a junction) move together so dragging a junction never
  /// tears connected topology apart.
  static AutoLineartGraph moveControlPoint(
    AutoLineartGraph source, {
    required int pathIndex,
    required int pointIndex,
    required AutoLineartPoint point,
    bool moveCoincident = true,
  }) {
    if (pathIndex < 0 ||
        pathIndex >= source.paths.length ||
        pointIndex < 0 ||
        pointIndex >= source.paths[pathIndex].points.length) {
      return source;
    }
    final origin = source.paths[pathIndex].points[pointIndex];
    final nextPoint = AutoLineartPoint(
      point.x.clamp(0.0, math.max(0, source.width - 1).toDouble()),
      point.y.clamp(0.0, math.max(0, source.height - 1).toDouble()),
    );
    const epsilonSq = 0.25;
    final paths = <AutoLineartPath>[];
    for (var p = 0; p < source.paths.length; p++) {
      final oldPath = source.paths[p];
      final points = List<AutoLineartPoint>.from(oldPath.points);
      for (var i = 0; i < points.length; i++) {
        final exactTarget = p == pathIndex && i == pointIndex;
        final dx = points[i].x - origin.x;
        final dy = points[i].y - origin.y;
        final coincident = moveCoincident && dx * dx + dy * dy <= epsilonSq;
        if (exactTarget || coincident) points[i] = nextPoint;
      }
      paths.add(
        AutoLineartPath(
          points: points,
          startIsJunction: oldPath.startIsJunction,
          endIsJunction: oldPath.endIsJunction,
          persistence: oldPath.persistence,
        ),
      );
    }
    return AutoLineartGraph(
      width: source.width,
      height: source.height,
      paths: paths,
      analysisWidth: source.analysisWidth,
      analysisHeight: source.analysisHeight,
    );
  }

  static int controlPointCount(AutoLineartGraph graph) => graph.paths.fold<int>(
    0,
    (sum, path) => sum + path.points.length,
  );

'''
    if anchor not in s:
        raise SystemExit('render anchor not found')
    s = s.replace(anchor, helper + anchor, 1)
engine.write_text(s, encoding='utf-8')

# ---- editable preview widget ----------------------------------------------
overlay = Path('lib/screens/canvas/widgets/auto_lineart_control_overlay.dart')
overlay.write_text(r'''import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../engine/auto_lineart_engine.dart';

class AutoLineartControlOverlay extends StatefulWidget {
  final ui.Image image;
  final AutoLineartGraph graph;
  final void Function(int pathIndex, int pointIndex, AutoLineartPoint point)
  onPointMoved;

  const AutoLineartControlOverlay({
    super.key,
    required this.image,
    required this.graph,
    required this.onPointMoved,
  });

  @override
  State<AutoLineartControlOverlay> createState() =>
      _AutoLineartControlOverlayState();
}

class _AutoLineartControlOverlayState extends State<AutoLineartControlOverlay> {
  (int, int)? _active;

  Rect _imageRect(Size size) {
    final iw = widget.graph.width.toDouble();
    final ih = widget.graph.height.toDouble();
    if (iw <= 0 || ih <= 0) return Offset.zero & size;
    final scale = math.min(size.width / iw, size.height / ih);
    final w = iw * scale;
    final h = ih * scale;
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  Offset _toScreen(AutoLineartPoint point, Rect rect) => Offset(
    rect.left + point.x / math.max(1, widget.graph.width) * rect.width,
    rect.top + point.y / math.max(1, widget.graph.height) * rect.height,
  );

  AutoLineartPoint _toGraph(Offset point, Rect rect) => AutoLineartPoint(
    ((point.dx - rect.left) / math.max(1.0, rect.width) * widget.graph.width)
        .clamp(0.0, math.max(0, widget.graph.width - 1).toDouble()),
    ((point.dy - rect.top) / math.max(1.0, rect.height) * widget.graph.height)
        .clamp(0.0, math.max(0, widget.graph.height - 1).toDouble()),
  );

  (int, int)? _hit(Offset local, Rect rect) {
    const radius = 13.0;
    var best = radius * radius;
    (int, int)? result;
    for (var p = 0; p < widget.graph.paths.length; p++) {
      final path = widget.graph.paths[p];
      for (var i = 0; i < path.points.length; i++) {
        final screen = _toScreen(path.points[i], rect);
        final dx = screen.dx - local.dx;
        final dy = screen.dy - local.dy;
        final d = dx * dx + dy * dy;
        if (d <= best) {
          best = d;
          result = (p, i);
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final rect = _imageRect(size);
        return GestureDetector(
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              RawImage(image: widget.image, fit: BoxFit.contain),
              CustomPaint(
                painter: _ControlPainter(
                  graph: widget.graph,
                  imageRect: rect,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlPainter extends CustomPainter {
  final AutoLineartGraph graph;
  final Rect imageRect;
  final Color color;

  const _ControlPainter({
    required this.graph,
    required this.imageRect,
    required this.color,
  });

  Offset _screen(AutoLineartPoint point) => Offset(
    imageRect.left + point.x / math.max(1, graph.width) * imageRect.width,
    imageRect.top + point.y / math.max(1, graph.height) * imageRect.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final path in graph.paths) {
      if (path.points.length < 2) continue;
      final uiPath = Path()..moveTo(_screen(path.points.first).dx, _screen(path.points.first).dy);
      for (var i = 1; i < path.points.length; i++) {
        final p = _screen(path.points[i]);
        uiPath.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(uiPath, linePaint);
      for (final point in path.points) {
        final p = _screen(point);
        canvas.drawCircle(p, 4.2, pointPaint);
        canvas.drawCircle(p, 4.2, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ControlPainter oldDelegate) =>
      oldDelegate.graph != graph ||
      oldDelegate.imageRect != imageRect ||
      oldDelegate.color != color;
}
''', encoding='utf-8')

# ---- filter panel ----------------------------------------------------------
panel = Path('lib/screens/canvas/widgets/filter_panel.dart')
p = panel.read_text(encoding='utf-8')
if "import 'auto_lineart_control_overlay.dart';" not in p:
    p = p.replace("import 'color_picker_panel.dart';", "import 'auto_lineart_control_overlay.dart';\nimport 'color_picker_panel.dart';", 1)

p = p.replace(
    '  AutoLineartGraph? _autoLineartPreviewGraph;\n  double? _autoLineartPreviewRoughWidth;\n',
    '  AutoLineartGraph? _autoLineartBaseGraph;\n  AutoLineartGraph? _autoLineartPreviewGraph;\n  double? _autoLineartPreviewRoughWidth;\n  int? _autoLineartPreviewSmoothingLevel;\n  bool _autoLineartManualEdited = false;\n',
    1,
)

old_update = '''      if (_autoLineartPreviewGraph == null ||
          _autoLineartPreviewRoughWidth != filter.autoLineartRoughWidth) {
        _autoLineartPreviewGraph = AutoLineartEngine.analyze(
          base,
          _previewW,
          _previewH,
          roughWidthPx: math.max(
            2.0,
            filter.autoLineartRoughWidth * _previewScale,
          ),
        );
        _autoLineartPreviewRoughWidth = filter.autoLineartRoughWidth;
      }
      filtered = AutoLineartEngine.render(
        _autoLineartPreviewGraph!,
        _previewW,
        _previewH,
        outputWidthPx: math.max(
          1.0,
          filter.autoLineartOutputWidth * _previewScale,
        ),
        taperLengthPx: filter.autoLineartTaperLength * _previewScale,
        smoothing: filter.autoLineartSmoothing,
      );'''
new_update = '''      final smoothingLevel =
          (filter.autoLineartSmoothing / 10).round().clamp(0, 10);
      if (_autoLineartBaseGraph == null ||
          _autoLineartPreviewRoughWidth != filter.autoLineartRoughWidth) {
        _autoLineartBaseGraph = AutoLineartEngine.analyze(
          base,
          _previewW,
          _previewH,
          roughWidthPx: math.max(
            2.0,
            filter.autoLineartRoughWidth * _previewScale,
          ),
        );
        _autoLineartPreviewRoughWidth = filter.autoLineartRoughWidth;
        _autoLineartPreviewGraph = null;
        _autoLineartPreviewSmoothingLevel = null;
        _autoLineartManualEdited = false;
      }
      if (_autoLineartPreviewGraph == null ||
          _autoLineartPreviewSmoothingLevel != smoothingLevel) {
        _autoLineartPreviewGraph = AutoLineartEngine.prepareEditableGraph(
          _autoLineartBaseGraph!,
          smoothingLevel: smoothingLevel,
        );
        _autoLineartPreviewSmoothingLevel = smoothingLevel;
        _autoLineartManualEdited = false;
      }
      filtered = AutoLineartEngine.render(
        _autoLineartPreviewGraph!,
        _previewW,
        _previewH,
        outputWidthPx: math.max(
          1.0,
          filter.autoLineartOutputWidth * _previewScale,
        ),
        taperLengthPx: filter.autoLineartTaperLength * _previewScale,
        smoothing: 0,
      );'''
if old_update not in p:
    raise SystemExit('preview update anchor not found')
p = p.replace(old_update, new_update, 1)

old_raw = '''                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: RawImage(
                              image: _previewImage,
                              fit: BoxFit.contain,
                            ),
                          ),'''
new_raw = '''                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: current.kind == FilterKind.autoLineart &&
                                    _autoLineartPreviewGraph != null &&
                                    (bulk == null || bulk.length <= 1)
                                ? AutoLineartControlOverlay(
                                    image: _previewImage!,
                                    graph: _autoLineartPreviewGraph!,
                                    onPointMoved: (pathIndex, pointIndex, point) {
                                      _autoLineartPreviewGraph =
                                          AutoLineartEngine.moveControlPoint(
                                            _autoLineartPreviewGraph!,
                                            pathIndex: pathIndex,
                                            pointIndex: pointIndex,
                                            point: point,
                                          );
                                      _autoLineartManualEdited = true;
                                      _updatePreview();
                                    },
                                  )
                                : RawImage(
                                    image: _previewImage,
                                    fit: BoxFit.contain,
                                  ),
                          ),'''
if old_raw not in p:
    raise SystemExit('preview widget anchor not found')
p = p.replace(old_raw, new_raw, 1)

p = p.replace(
    '''                _autoLineartPreviewGraph = null;
                _autoLineartPreviewRoughWidth = null;
                _updatePreview();''',
    '''                _autoLineartBaseGraph = null;
                _autoLineartPreviewGraph = null;
                _autoLineartPreviewRoughWidth = null;
                _autoLineartPreviewSmoothingLevel = null;
                _autoLineartManualEdited = false;
                _updatePreview();''',
    1,
)

old_smooth = '''            _integerStepperSlider(
              l10n.filterAutoLineartSmoothing,
              current.autoLineartSmoothing.round(),
              0,
              100,
              (v) {
                service.updateFilterParams(
                  current.id,
                  autoLineartSmoothing: v.toDouble(),
                );
                _updatePreview();
              },
            ),'''
new_smooth = '''            _integerStepperSlider(
              l10n.filterAutoLineartSmoothing,
              (current.autoLineartSmoothing / 10).round().clamp(0, 10),
              0,
              10,
              (v) {
                service.updateFilterParams(
                  current.id,
                  autoLineartSmoothing: (v * 10).toDouble(),
                );
                _autoLineartPreviewGraph = null;
                _autoLineartPreviewSmoothingLevel = null;
                _autoLineartManualEdited = false;
                _updatePreview();
              },
            ),'''
if old_smooth not in p:
    raise SystemExit('smoothing control anchor not found')
p = p.replace(old_smooth, new_smooth, 1)

# Manual-edit final render before generic isolate execution.
needle = '''    Uint8List result;
    if (_isPrism(filter)) {'''
replacement = '''    Uint8List result;
    final canUseManualAutoLineart =
        filter.kind == FilterKind.autoLineart &&
        _autoLineartManualEdited &&
        _autoLineartPreviewGraph != null &&
        frameIndex == widget.frameIndex &&
        (widget.bulkFrameIndices == null || widget.bulkFrameIndices!.length <= 1);
    if (canUseManualAutoLineart) {
      result = AutoLineartEngine.render(
        _autoLineartPreviewGraph!,
        tm.canvasWidth,
        tm.canvasHeight,
        outputWidthPx: filter.autoLineartOutputWidth,
        taperLengthPx: filter.autoLineartTaperLength,
        smoothing: 0,
      );
    } else if (_isPrism(filter)) {'''
if needle not in p:
    raise SystemExit('apply result anchor not found')
p = p.replace(needle, replacement, 1)
panel.write_text(p, encoding='utf-8')

# ---- model default: align new discrete scale --------------------------------
model = Path('lib/models/filter_def.dart')
m = model.read_text(encoding='utf-8')
m = m.replace('    this.autoLineartSmoothing = 45,', '    this.autoLineartSmoothing = 50,', 1)
model.write_text(m, encoding='utf-8')

# ---- tests ----------------------------------------------------------------
test = Path('test/auto_lineart_filter_test.dart')
t = test.read_text(encoding='utf-8')
if 'ten-level smoothing reduces editable control points' not in t:
    insert = r'''
    test('ten-level smoothing reduces editable control points', () {
      const w = 160, h = 100;
      final src = _canvas(w, h);
      var lastX = 10;
      var lastY = 50;
      for (var x = 14; x <= 146; x += 4) {
        final y = 50 + ((x ~/ 4).isEven ? 7 : -7);
        _line(src, w, h, lastX, lastY, x, y, 3);
        lastX = x;
        lastY = y;
      }
      final base = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 8);
      final low = AutoLineartEngine.prepareEditableGraph(
        base,
        smoothingLevel: 1,
      );
      final high = AutoLineartEngine.prepareEditableGraph(
        base,
        smoothingLevel: 10,
      );
      expect(AutoLineartEngine.controlPointCount(high),
          lessThan(AutoLineartEngine.controlPointCount(low)));
    });

    test('dragging a shared junction keeps coincident branch endpoints joined', () {
      final graph = AutoLineartGraph(
        width: 100,
        height: 100,
        paths: const [
          AutoLineartPath(
            points: [AutoLineartPoint(10, 10), AutoLineartPoint(50, 50)],
            startIsJunction: false,
            endIsJunction: true,
            persistence: 1,
          ),
          AutoLineartPath(
            points: [AutoLineartPoint(50, 50), AutoLineartPoint(90, 10)],
            startIsJunction: true,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final moved = AutoLineartEngine.moveControlPoint(
        graph,
        pathIndex: 0,
        pointIndex: 1,
        point: const AutoLineartPoint(54, 57),
      );
      expect(moved.paths[0].points.last.x, 54);
      expect(moved.paths[0].points.last.y, 57);
      expect(moved.paths[1].points.first.x, 54);
      expect(moved.paths[1].points.first.y, 57);
    });

    test('manual control movement changes the rasterized line position', () {
      final graph = AutoLineartGraph(
        width: 100,
        height: 80,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 40),
              AutoLineartPoint(50, 40),
              AutoLineartPoint(90, 40),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final moved = AutoLineartEngine.moveControlPoint(
        graph,
        pathIndex: 0,
        pointIndex: 1,
        point: const AutoLineartPoint(50, 25),
      );
      final out = AutoLineartEngine.render(
        moved,
        100,
        80,
        outputWidthPx: 3,
        taperLengthPx: 0,
        smoothing: 0,
      );
      expect(_alpha(out, 100, 50, 25), greaterThan(80));
      expect(_alpha(out, 100, 50, 40), lessThan(80));
    });
'''
    marker = '  });\n}\n'
    pos = t.rfind(marker)
    if pos < 0:
        raise SystemExit('engine test insertion anchor missing')
    t = t[:pos] + insert + t[pos:]
    test.write_text(t, encoding='utf-8')

overlay_test = Path('test/auto_lineart_control_overlay_test.dart')
overlay_test.write_text(r'''import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';
import 'package:niarim/screens/canvas/widgets/auto_lineart_control_overlay.dart';

void main() {
  testWidgets('auto lineart preview control point can be dragged', (tester) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
    final image = await recorder.endRecording().toImage(100, 100);
    int? movedPath;
    int? movedPoint;
    AutoLineartPoint? movedTo;
    const graph = AutoLineartGraph(
      width: 100,
      height: 100,
      paths: [
        AutoLineartPath(
          points: [
            AutoLineartPoint(20, 50),
            AutoLineartPoint(50, 50),
            AutoLineartPoint(80, 50),
          ],
          startIsJunction: false,
          endIsJunction: false,
          persistence: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: AutoLineartControlOverlay(
              image: image,
              graph: graph,
              onPointMoved: (p, i, point) {
                movedPath = p;
                movedPoint = i;
                movedTo = point;
              },
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(AutoLineartControlOverlay));
    final start = Offset(box.left + box.width * .5, box.top + box.height * .5);
    await tester.dragFrom(start, const Offset(25, -30));
    await tester.pump();

    expect(movedPath, 0);
    expect(movedPoint, 1);
    expect(movedTo, isNotNull);
    expect(movedTo!.x, greaterThan(50));
    expect(movedTo!.y, lessThan(50));
    image.dispose();
  });
}
''', encoding='utf-8')

print('Auto Line Art editable control points patch applied')
