import 'dart:math' as math;
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
    const radius = 22.0;
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
