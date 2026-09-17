import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../engine/auto_lineart_engine.dart';

class AutoLineartControlOverlay extends StatefulWidget {
  final ui.Image image;
  final AutoLineartGraph graph;
  final void Function(int pathIndex, int pointIndex, AutoLineartPoint point)
  onPointMoved;
  final ValueChanged<AutoLineartGraph>? onGraphChanged;

  const AutoLineartControlOverlay({
    super.key,
    required this.image,
    required this.graph,
    required this.onPointMoved,
    this.onGraphChanged,
  });

  @override
  State<AutoLineartControlOverlay> createState() =>
      _AutoLineartControlOverlayState();
}

class _AutoLineartControlOverlayState extends State<AutoLineartControlOverlay> {
  (int, int)? _active;
  int? _activePointer;
  Offset? _pointerDown;
  bool _dragged = false;
  late AutoLineartGraph _displayGraph;

  @override
  void initState() {
    super.initState();
    _displayGraph = widget.graph;
  }

  @override
  void didUpdateWidget(covariant AutoLineartControlOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graph != widget.graph) {
      _displayGraph = widget.graph;
    }
  }

  Rect _imageRect(Size size) {
    final iw = _displayGraph.width.toDouble();
    final ih = _displayGraph.height.toDouble();
    if (iw <= 0 || ih <= 0) return Offset.zero & size;
    final scale = math.min(size.width / iw, size.height / ih);
    final w = iw * scale;
    final h = ih * scale;
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  Offset _toScreen(AutoLineartPoint point, Rect rect) => Offset(
    rect.left + point.x / math.max(1, _displayGraph.width) * rect.width,
    rect.top + point.y / math.max(1, _displayGraph.height) * rect.height,
  );

  AutoLineartPoint _toGraph(Offset point, Rect rect) => AutoLineartPoint(
    ((point.dx - rect.left) / math.max(1.0, rect.width) * _displayGraph.width)
        .clamp(0.0, math.max(0, _displayGraph.width - 1).toDouble()),
    ((point.dy - rect.top) / math.max(1.0, rect.height) * _displayGraph.height)
        .clamp(0.0, math.max(0, _displayGraph.height - 1).toDouble()),
  );

  (int, int)? _hit(Offset local, Rect rect) {
    const radius = 22.0;
    var best = radius * radius;
    (int, int)? result;
    for (var p = 0; p < _displayGraph.paths.length; p++) {
      final path = _displayGraph.paths[p];
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

  (int, int)? _hitSegment(Offset local, Rect rect) {
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
    final points = List<AutoLineartPoint>.from(old.points)
      ..insert(pointIndex, point);
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
    final points = List<AutoLineartPoint>.from(old.points)
      ..removeAt(pointIndex);
    if (points.length < 2) {
      paths.removeAt(pathIndex);
    } else {
      paths[pathIndex] = AutoLineartPath(
        points: points,
        startIsJunction: pointIndex == 0 ? false : old.startIsJunction,
        endIsJunction: pointIndex == old.points.length - 1
            ? false
            : old.endIsJunction,
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final rect = _imageRect(size);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
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
          onPointerMove: (event) {
            final active = _active;
            if (active == null || _activePointer != event.pointer) return;
            final down = _pointerDown;
            if (down != null && (event.localPosition - down).distance > 4) {
              _dragged = true;
            }
            final point = _toGraph(event.localPosition, rect);
            setState(() {
              // Keep the editor graph immutable. FilterPanel retains the
              // pre-edit graph as the baseline used to transfer manual edits
              // across smoothing/rough-width changes, so mutating the shared
              // graph here would erase the very displacement we need to
              // preserve. A fresh graph also makes CustomPainter repaint
              // immediately while each control remains independently editable.
              _displayGraph = AutoLineartEngine.moveControlPoint(
                _displayGraph,
                pathIndex: active.$1,
                pointIndex: active.$2,
                point: point,
              );
            });
            widget.onPointMoved(active.$1, active.$2, point);
          },
          onPointerUp: (event) => _finishPointer(event.pointer),
          onPointerCancel: (event) =>
              _finishPointer(event.pointer, cancelled: true),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RawImage(image: widget.image, fit: BoxFit.contain),
              CustomPaint(
                painter: _ControlPainter(
                  graph: _displayGraph,
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
      final uiPath = Path()
        ..moveTo(_screen(path.points.first).dx, _screen(path.points.first).dy);
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
