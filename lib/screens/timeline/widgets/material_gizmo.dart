import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../engine/perspective_transform.dart';
import '../../../models/layer_crop.dart';
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
    this.outputWidth,
    this.outputHeight,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.contentBounds,
    this.camera,
    this.color,
  });

  final int canvasWidth;
  final int canvasHeight;
  final int? outputWidth;
  final int? outputHeight;

  /// The material's drawn part on its own layer (canvas pixels), or null
  /// when nothing is drawn.
  final Rect? contentBounds;

  /// Where the material is at the frame shown.
  final LayerKeyframe value;

  /// The camera at the frame shown (the preview is seen through it).
  final CameraKeyframe? camera;

  /// Called while dragging with the material's new move, scale and Z turn.
  final ValueChanged<LayerKeyframe> onChanged;
  final VoidCallback? onChangeEnd;
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
    required this.outputWidth,
    required this.outputHeight,
    required LayerKeyframe value,
    required this.camera,
    required Rect? bounds,
  }) {
    final w = canvasWidth.toDouble();
    final h = canvasHeight.toDouble();
    final outputW = outputWidth.toDouble();
    final outputH = outputHeight.toDouble();
    fit = math.min(box.width / outputW, box.height / outputH);
    origin = Offset(
      (box.width - outputW * fit) / 2,
      (box.height - outputH * fit) / 2,
    );
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
  final int outputWidth;
  final int outputHeight;
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
    final c = Offset(outputWidth / 2, outputHeight / 2);
    final crop = Offset(
      (canvasWidth - outputWidth) / 2,
      (canvasHeight - outputHeight) / 2,
    );
    var p = canvasPoint - crop - c - Offset(camera?.x ?? 0, camera?.y ?? 0);
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
    outputWidth: widget.outputWidth ?? widget.canvasWidth,
    outputHeight: widget.outputHeight ?? widget.canvasHeight,
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
                    ..onEnd = (_) {
                      _drag = null;
                      widget.onChangeEnd?.call();
                    },
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

/// Which edges of the crop a handle of [MaterialCropGizmo] moves.
typedef CropHandle = ({bool left, bool top, bool right, bool bottom});

/// Handles over the timeline preview for cropping the material being edited:
/// drag a corner to move two edges, or the middle of an edge to move that
/// edge. The crop's frame lies where the preview shows the material (its
/// position, turn and the camera are followed), and the crop stays inside
/// the material's drawn part ([frame]).
class MaterialCropGizmo extends StatefulWidget {
  const MaterialCropGizmo({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    this.outputWidth,
    this.outputHeight,
    required this.value,
    required this.frame,
    required this.crop,
    required this.onChanged,
    this.onChangeEnd,
    this.camera,
    this.color,
  });

  final int canvasWidth;
  final int canvasHeight;
  final int? outputWidth;
  final int? outputHeight;

  /// Where the material is at the frame shown.
  final LayerKeyframe value;

  /// The material's drawn part on its layer (canvas pixels).
  final Rect frame;

  /// The crop now (null: nothing is cut).
  final LayerCrop? crop;

  /// Called while dragging with the new crop (null when nothing is cut).
  final ValueChanged<LayerCrop?> onChanged;
  final VoidCallback? onChangeEnd;
  final CameraKeyframe? camera;
  final Color? color;

  /// The handles: the four corners, then the middles of the four edges.
  static const List<CropHandle> handles = [
    (left: true, top: true, right: false, bottom: false),
    (left: false, top: true, right: true, bottom: false),
    (left: false, top: false, right: true, bottom: true),
    (left: true, top: false, right: false, bottom: true),
    (left: false, top: true, right: false, bottom: false),
    (left: false, top: false, right: true, bottom: false),
    (left: false, top: false, right: false, bottom: true),
    (left: true, top: false, right: false, bottom: false),
  ];

  /// Where each handle sits on [rect] (layer pixels), in [handles] order.
  static List<Offset> handlePoints(Rect rect) => [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
    rect.topCenter,
    rect.centerRight,
    rect.bottomCenter,
    rect.centerLeft,
  ];

  /// The kept part of the layer (pixels) that [crop] shows of [frame].
  static Rect keptRect(LayerCrop? crop, Rect frame, double w, double h) {
    if (crop == null) return frame;
    final kept = crop.rectIn(w, h).intersect(frame);
    return kept.width > 0 && kept.height > 0 ? kept : frame;
  }

  /// [rect] (layer pixels) as a crop of a [w] × [h] layer, or null when it
  /// keeps the whole [frame].
  static LayerCrop? cropOf(Rect rect, Rect frame, double w, double h) {
    const near = 0.5;
    if ((rect.left - frame.left).abs() < near &&
        (rect.top - frame.top).abs() < near &&
        (rect.right - frame.right).abs() < near &&
        (rect.bottom - frame.bottom).abs() < near) {
      return null;
    }
    final crop = LayerCrop(
      left: (rect.left / w).clamp(0, 1),
      top: (rect.top / h).clamp(0, 1),
      right: (rect.right / w).clamp(0, 1),
      bottom: (rect.bottom / h).clamp(0, 1),
    );
    return crop.isValid ? crop : null;
  }

  /// [start] with [handle]'s edges moved by [delta] (layer pixels), kept
  /// inside [frame] and at least 1% of it across and down.
  static Rect dragged(Rect start, CropHandle handle, Offset delta, Rect frame) {
    final minW = math.max(1.0, frame.width / 100);
    final minH = math.max(1.0, frame.height / 100);
    var l = start.left, t = start.top, r = start.right, b = start.bottom;
    if (handle.left) l = (l + delta.dx).clamp(frame.left, r - minW);
    if (handle.right) r = (r + delta.dx).clamp(l + minW, frame.right);
    if (handle.top) t = (t + delta.dy).clamp(frame.top, b - minH);
    if (handle.bottom) b = (b + delta.dy).clamp(t + minH, frame.bottom);
    return Rect.fromLTRB(l, t, r, b);
  }

  @override
  State<MaterialCropGizmo> createState() => _MaterialCropGizmoState();
}

class _MaterialCropGizmoState extends State<MaterialCropGizmo> {
  static const double _hitRadius = 24;

  Size _box = Size.zero;
  CropHandle? _handle;
  late Rect _startRect;
  late Offset _startPoint;

  /// Layer pixels per preview pixel along the layer's x and y at the handle,
  /// so a drag follows the handle under the finger whatever the material's
  /// turn, scale and the camera.
  late Offset _boxPerLayerX;
  late Offset _boxPerLayerY;

  _GizmoGeometry _geometry(Rect bounds) => _GizmoGeometry(
    box: _box,
    canvasWidth: widget.canvasWidth,
    canvasHeight: widget.canvasHeight,
    outputWidth: widget.outputWidth ?? widget.canvasWidth,
    outputHeight: widget.outputHeight ?? widget.canvasHeight,
    value: widget.value,
    camera: widget.camera,
    bounds: bounds,
  );

  Rect get _kept => MaterialCropGizmo.keptRect(
    widget.crop,
    widget.frame,
    widget.canvasWidth.toDouble(),
    widget.canvasHeight.toDouble(),
  );

  void _onStart(DragStartDetails d) {
    final rect = _kept;
    final g = _geometry(rect);
    final points = MaterialCropGizmo.handlePoints(rect);
    _handle = null;
    var best = _hitRadius;
    for (var i = 0; i < points.length; i++) {
      final distance = (g._layerToBox(points[i]) - d.localPosition).distance;
      if (distance < best) {
        best = distance;
        _handle = MaterialCropGizmo.handles[i];
        _startPoint = points[i];
      }
    }
    if (_handle == null) return;
    _startRect = rect;
    final at = g._layerToBox(_startPoint);
    _boxPerLayerX = g._layerToBox(_startPoint + const Offset(1, 0)) - at;
    _boxPerLayerY = g._layerToBox(_startPoint + const Offset(0, 1)) - at;
    _startBox = d.localPosition;
  }

  Offset _startBox = Offset.zero;

  void _onUpdate(DragUpdateDetails d) {
    final handle = _handle;
    if (handle == null) return;
    // Solve boxDelta = dx · perX + dy · perY for the layer movement.
    final delta = d.localPosition - _startBox;
    final ax = _boxPerLayerX, ay = _boxPerLayerY;
    final det = ax.dx * ay.dy - ay.dx * ax.dy;
    if (det.abs() < 1e-9) return;
    final dx = (delta.dx * ay.dy - ay.dx * delta.dy) / det;
    final dy = (ax.dx * delta.dy - delta.dx * ax.dy) / det;
    final rect = MaterialCropGizmo.dragged(
      _startRect,
      handle,
      Offset(dx, dy),
      widget.frame,
    );
    widget.onChanged(
      MaterialCropGizmo.cropOf(
        rect,
        widget.frame,
        widget.canvasWidth.toDouble(),
        widget.canvasHeight.toDouble(),
      ),
    );
  }

  void _onEnd() {
    if (_handle == null) return;
    _handle = null;
    widget.onChangeEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        _box = constraints.biggest;
        final kept = _kept;
        final g = _geometry(kept);
        final frame = _geometry(widget.frame).corners;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: _onStart,
          onPanUpdate: _onUpdate,
          onPanEnd: (_) => _onEnd(),
          onPanCancel: _onEnd,
          child: CustomPaint(
            size: _box,
            painter: _CropGizmoPainter(
              frame: frame ?? const [],
              kept: g.corners ?? const [],
              handles: [
                for (final p in MaterialCropGizmo.handlePoints(kept))
                  g._layerToBox(p),
              ],
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class _CropGizmoPainter extends CustomPainter {
  _CropGizmoPainter({
    required this.frame,
    required this.kept,
    required this.handles,
    required this.color,
  });

  final List<Offset> frame;
  final List<Offset> kept;
  final List<Offset> handles;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (kept.length != 4) return;
    final keptPath = Path()..addPolygon(kept, true);
    if (frame.length == 4) {
      // The cut-away part of the picture is shaded.
      final cut = Path.combine(
        PathOperation.difference,
        Path()..addPolygon(frame, true),
        keptPath,
      );
      canvas.drawPath(
        cut,
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );
    }
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(keptPath, shadow);
    canvas.drawPath(keptPath, line);
    final fill = Paint()..color = color;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < handles.length; i++) {
      final radius = i < 4 ? 7.0 : 5.5;
      canvas.drawCircle(handles[i], radius, fill);
      canvas.drawCircle(handles[i], radius, ring);
    }
  }

  static bool _same(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool shouldRepaint(_CropGizmoPainter old) =>
      old.color != color ||
      !_same(old.kept, kept) ||
      !_same(old.frame, frame) ||
      !_same(old.handles, handles);
}
