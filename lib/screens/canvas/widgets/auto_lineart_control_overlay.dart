import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../engine/auto_lineart_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/grab_pan_gesture_recognizer.dart';

enum AutoLineartControlMode { move, add, delete }

class AutoLineartControlOverlay extends StatefulWidget {
  final ui.Image image;
  final AutoLineartGraph graph;
  final void Function(int pathIndex, int pointIndex, AutoLineartPoint point)
  onPointMoved;
  final ValueChanged<AutoLineartGraph>? onGraphChanged;
  final AutoLineartControlMode mode;

  const AutoLineartControlOverlay({
    super.key,
    required this.image,
    required this.graph,
    required this.onPointMoved,
    this.onGraphChanged,
    this.mode = AutoLineartControlMode.move,
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
  // A press in add mode, waiting to see whether it is a tap.
  int? _addPointer;
  Offset? _addDown;

  /// How far a finger may move and still be tapping.
  static const double _tapSlop = 4;
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
      dotRadius: old.dotRadius,
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
        dotRadius: old.dotRadius,
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
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.filterAutoLineartDeletePointTooltip),
          content: Text(l10n.filterAutoLineartDeletePointConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
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
        // The Listener moves the points; this only keeps a grabbed point's
        // drag from also scrolling the panel the preview sits in.
        return RawGestureDetector(
          gestures: {
            GrabPanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<GrabPanGestureRecognizer>(
                  () => GrabPanGestureRecognizer(grabSlop: 0),
                  (recognizer) {
                    recognizer.grabs = (local) =>
                        widget.mode == AutoLineartControlMode.move &&
                        _hit(local, rect) != null;
                    // A pan with no handlers never takes part.
                    recognizer.onStart = (_) {};
                  },
                ),
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              final active = _hit(event.localPosition, rect);
              if (widget.mode == AutoLineartControlMode.delete) {
                if (active != null) {
                  _publishGraph(_withPointDeleted(active.$1, active.$2));
                }
                return;
              }
              if (widget.mode == AutoLineartControlMode.add) {
                // Added when the tap ends, so a finger that lands on the
                // line to scroll adds nothing.
                _addPointer = event.pointer;
                _addDown = event.localPosition;
                return;
              }
              if (active != null) {
                _active = active;
                _activePointer = event.pointer;
                _pointerDown = event.localPosition;
                _dragged = false;
                return;
              }
            },
            onPointerMove: (event) {
              if (event.pointer == _addPointer &&
                  _addDown != null &&
                  (event.localPosition - _addDown!).distance > _tapSlop) {
                _addPointer = null;
                _addDown = null;
              }
              final active = _active;
              if (active == null || _activePointer != event.pointer) return;
              final down = _pointerDown;
              if (down != null &&
                  (event.localPosition - down).distance > _tapSlop) {
                _dragged = true;
              }
              // A press that only wobbles is a tap (it asks to delete the
              // point): the point stays put until the finger really moves.
              if (!_dragged) return;
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
            onPointerUp: (event) {
              if (event.pointer == _addPointer) {
                final down = _addDown;
                _addPointer = null;
                _addDown = null;
                final segment = down == null ? null : _hitSegment(down, rect);
                if (segment != null) {
                  _publishGraph(
                    _withPointInserted(
                      segment.$1,
                      segment.$2,
                      _toGraph(down!, rect),
                    ),
                  );
                }
                return;
              }
              _finishPointer(event.pointer);
            },
            onPointerCancel: (event) {
              if (event.pointer == _addPointer) {
                _addPointer = null;
                _addDown = null;
              }
              _finishPointer(event.pointer, cancelled: true);
            },
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
