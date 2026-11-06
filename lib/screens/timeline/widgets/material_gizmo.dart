import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../engine/perspective_transform.dart';
import '../../../models/camera_keyframe.dart';
import '../../../models/layer_keyframe.dart';

/// What a drag on the preview changes.
enum _GizmoDrag { move, scale, rotate, pinch }

/// Handles over the timeline preview for the material being edited: drag
/// anywhere to move it, a corner dot to resize it, the dot above it to turn
/// it, or two fingers to move, resize and turn at once. The frame around it
/// follows the material's own X/Y turn and the camera, so it lies on what
/// the preview shows.
class MaterialTransformGizmo extends StatefulWidget {
  const MaterialTransformGizmo({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.value,
    required this.onChanged,
    this.contentBounds,
    this.camera,
    this.color,
  });

  final int canvasWidth;
  final int canvasHeight;

  /// The material's drawn part on its own layer (canvas pixels), or null
  /// when nothing is drawn.
  final Rect? contentBounds;

  /// Where the material is at the frame shown.
  final LayerKeyframe value;

  /// The camera at the frame shown (the preview is seen through it).
  final CameraKeyframe? camera;

  /// Called while dragging with the material's new move, scale and Z turn.
  final ValueChanged<LayerKeyframe> onChanged;
  final Color? color;

  @override
  State<MaterialTransformGizmo> createState() => _MaterialTransformGizmoState();
}

/// The geometry of the handles in the gizmo's own coordinates.
class _GizmoGeometry {
  _GizmoGeometry({
    required Size box,
    required this.canvasWidth,
    required this.canvasHeight,
    required LayerKeyframe value,
    required this.camera,
    required Rect? bounds,
  }) {
    final w = canvasWidth.toDouble();
    final h = canvasHeight.toDouble();
    fit = math.min(box.width / w, box.height / h);
    origin = Offset((box.width - w * fit) / 2, (box.height - h * fit) / 2);
    matrix = perspectiveLayerMatrix(
      width: w,
      height: h,
      dx: value.x,
      dy: value.y,
      scale: value.scale,
      rotationX: value.rotationX,
      rotationY: value.rotationY,
      rotationZ: value.rotation,
    );
    pivot = _toBox(Offset(w / 2 + value.x, h / 2 + value.y));
    if (bounds != null && !bounds.isEmpty) {
      corners = [
        _layerToBox(bounds.topLeft),
        _layerToBox(bounds.topRight),
        _layerToBox(bounds.bottomRight),
        _layerToBox(bounds.bottomLeft),
      ];
      final topMid = (corners![0] + corners![1]) / 2;
      final outward = topMid - pivot;
      final length = outward.distance;
      final direction = length < 1e-6 ? const Offset(0, -1) : outward / length;
      rotateStem = topMid;
      rotateHandle = topMid + direction * 28;
    }
  }

  final int canvasWidth;
  final int canvasHeight;
  final CameraKeyframe? camera;
  late final double fit;
  late final Offset origin;
  late final Float64List matrix;
  late final Offset pivot;
  List<Offset>? corners;
  Offset? rotateStem;
  Offset? rotateHandle;

  double get _cameraZoom {
    final zoom = camera?.zoom ?? 1;
    return zoom == 0 ? 1 : zoom;
  }

  double get _cameraTurn => (camera?.rotation ?? 0) * math.pi / 180;

  /// A point of the composited picture as the preview shows it.
  Offset _toBox(Offset canvasPoint) {
    final c = Offset(canvasWidth / 2, canvasHeight / 2);
    var p = canvasPoint - c - Offset(camera?.x ?? 0, camera?.y ?? 0);
    p = p * _cameraZoom;
    final turn = _cameraTurn;
    p = Offset(
      p.dx * math.cos(turn) - p.dy * math.sin(turn),
      p.dx * math.sin(turn) + p.dy * math.cos(turn),
    );
    return origin + (c + p) * fit;
  }

  Offset _layerToBox(Offset layerPoint) {
    final (x, y) = transformPoint(matrix, layerPoint.dx, layerPoint.dy);
    return _toBox(Offset(x, y));
  }

  /// A movement on the preview as a movement of the picture before the
  /// camera.
  Offset boxDeltaToCanvas(Offset delta) {
    final d = delta / fit / _cameraZoom;
    final turn = -_cameraTurn;
    return Offset(
      d.dx * math.cos(turn) - d.dy * math.sin(turn),
      d.dx * math.sin(turn) + d.dy * math.cos(turn),
    );
  }
}

class _MaterialTransformGizmoState extends State<MaterialTransformGizmo> {
  static const double _hitRadius = 24;

  _GizmoDrag? _drag;
  late LayerKeyframe _start;
  Offset _startFocal = Offset.zero;
  late _GizmoGeometry _startGeometry;
  Size _box = Size.zero;

  _GizmoGeometry _geometry(Size box) => _GizmoGeometry(
    box: box,
    canvasWidth: widget.canvasWidth,
    canvasHeight: widget.canvasHeight,
    value: widget.value,
    camera: widget.camera,
    bounds: widget.contentBounds,
  );

  void _onStart(ScaleStartDetails d) {
    final g = _geometry(_box);
    _startGeometry = g;
    _start = widget.value;
    _startFocal = d.localFocalPoint;
    if (d.pointerCount >= 2) {
      _drag = _GizmoDrag.pinch;
      return;
    }
    final handle = g.rotateHandle;
    if (handle != null && (handle - d.localFocalPoint).distance < _hitRadius) {
      _drag = _GizmoDrag.rotate;
    } else if (g.corners?.any(
          (c) => (c - d.localFocalPoint).distance < _hitRadius,
        ) ??
        false) {
      _drag = _GizmoDrag.scale;
    } else {
      _drag = _GizmoDrag.move;
    }
  }

  void _onUpdate(ScaleUpdateDetails d) {
    final drag = _drag;
    if (drag == null) return;
    if (drag != _GizmoDrag.pinch && d.pointerCount >= 2) {
      // A second finger came down: carry on as a pinch from here.
      _onStart(
        ScaleStartDetails(
          focalPoint: d.focalPoint,
          localFocalPoint: d.localFocalPoint,
          pointerCount: d.pointerCount,
        ),
      );
      return;
    }
    final g = _startGeometry;
    final pivot = g.pivot;
    var next = _start;
    switch (drag) {
      case _GizmoDrag.move:
        next = _moved(_start, g, d.localFocalPoint - _startFocal);
      case _GizmoDrag.scale:
        final from = (_startFocal - pivot).distance;
        final to = (d.localFocalPoint - pivot).distance;
        if (from > 1) {
          next = _start.copyWith(scale: _clampScale(_start.scale * to / from));
        }
      case _GizmoDrag.rotate:
        final a0 = (_startFocal - pivot).direction;
        final a1 = (d.localFocalPoint - pivot).direction;
        next = _start.copyWith(
          rotation: _normalizedDegrees(
            _start.rotation + (a1 - a0) * 180 / math.pi,
          ),
        );
      case _GizmoDrag.pinch:
        next = _moved(_start, g, d.localFocalPoint - _startFocal).copyWith(
          scale: _clampScale(_start.scale * d.scale),
          rotation: _normalizedDegrees(
            _start.rotation + d.rotation * 180 / math.pi,
          ),
        );
    }
    widget.onChanged(next);
  }

  LayerKeyframe _moved(LayerKeyframe from, _GizmoGeometry g, Offset delta) {
    final move = g.boxDeltaToCanvas(delta);
    final w = widget.canvasWidth.toDouble();
    final h = widget.canvasHeight.toDouble();
    return from.copyWith(
      x: (from.x + move.dx).clamp(-w, w).roundToDouble(),
      y: (from.y + move.dy).clamp(-h, h).roundToDouble(),
    );
  }

  static double _clampScale(double s) =>
      ((s.clamp(0.05, 5.0)) * 100).roundToDouble() / 100;

  static double _normalizedDegrees(double degrees) {
    var d = degrees % 360;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d.roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        _box = constraints.biggest;
        final g = _geometry(_box);
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            ScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(
                    dragStartBehavior: DragStartBehavior.down,
                  ),
                  (r) => r
                    ..onStart = _onStart
                    ..onUpdate = _onUpdate
                    ..onEnd = (_) => _drag = null,
                ),
          },
          child: CustomPaint(size: _box, painter: _GizmoPainter(g, color)),
        );
      },
    );
  }
}

class _GizmoPainter extends CustomPainter {
  _GizmoPainter(this.g, this.color);

  final _GizmoGeometry g;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()..color = color;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final corners = g.corners;
    if (corners != null) {
      final path = Path()..addPolygon(corners, true);
      canvas.drawPath(path, shadow);
      canvas.drawPath(path, line);
      final stem = g.rotateStem!;
      final handle = g.rotateHandle!;
      canvas.drawLine(stem, handle, shadow);
      canvas.drawLine(stem, handle, line);
      for (final c in corners) {
        canvas.drawCircle(c, 7, fill);
        canvas.drawCircle(c, 7, ring);
      }
      canvas.drawCircle(handle, 9, fill);
      canvas.drawCircle(handle, 9, ring);
    }
    canvas.drawCircle(g.pivot, 4, fill);
    canvas.drawCircle(g.pivot, 4, ring);
  }

  @override
  bool shouldRepaint(_GizmoPainter old) =>
      old.color != color ||
      old.g.pivot != g.pivot ||
      !_sameCorners(old.g.corners, g.corners);

  static bool _sameCorners(List<Offset>? a, List<Offset>? b) {
    if (a == null || b == null) return a == b;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
