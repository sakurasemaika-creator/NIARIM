import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../engine/perspective_transform.dart';
import '../../../models/layer_crop.dart';
import '../../../models/layer_region_edit.dart';
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

  /// The point of the material's own layer (canvas pixels) that the
  /// preview shows at [box]: the inverse of [_layerToBox].
  Offset boxToLayer(Offset box) {
    final c = Offset(outputWidth / 2, outputHeight / 2);
    final crop = Offset(
      (canvasWidth - outputWidth) / 2,
      (canvasHeight - outputHeight) / 2,
    );
    var p = (box - origin) / fit - c;
    final turn = -_cameraTurn;
    p = Offset(
      p.dx * math.cos(turn) - p.dy * math.sin(turn),
      p.dx * math.sin(turn) + p.dy * math.cos(turn),
    );
    p = p / _cameraZoom;
    final canvasPoint = p + crop + c + Offset(camera?.x ?? 0, camera?.y ?? 0);
    // The layer's matrix on its own plane is a homography: invert it.
    final m = matrix;
    final a = m[0], b = m[4], tx = m[12];
    final d = m[1], e = m[5], ty = m[13];
    final g = m[3], h = m[7], i = m[15];
    final det =
        a * (e * i - ty * h) - b * (d * i - ty * g) + tx * (d * h - e * g);
    if (det.abs() < 1e-12) return canvasPoint;
    final x = canvasPoint.dx, y = canvasPoint.dy;
    final px = (e * i - ty * h) * x + (tx * h - b * i) * y + (b * ty - tx * e);
    final py = (ty * g - d * i) * x + (a * i - tx * g) * y + (tx * d - a * ty);
    final pw = (d * h - e * g) * x + (b * g - a * h) * y + (a * e - b * d);
    if (pw.abs() < 1e-12) return canvasPoint;
    return Offset(px / pw, py / pw);
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

/// What a drag over [MaterialRegionGizmo] changes.
enum _RegionDrag {
  draw,
  moveSelection,
  resizeSelection,
  movePiece,
  scalePiece,
  stretchPiece,
  turnPiece,
  pinchPiece,
}

/// Handles over the timeline preview for selecting a part of the image or
/// video being edited (範囲選択) and changing a moved or copied part.
///
/// Without [edit]: drag on the preview to outline a part in [shape] (a
/// rectangle, an ellipse, or freehand), drag inside the outline to move it,
/// a dot of a rectangle or an ellipse to resize it; a tap outside clears it.
/// With [edit] (a moved or copied part): drag anywhere to move the part, a
/// corner dot to resize it, the middle of a side to stretch it, the dot
/// above it to turn it, or two fingers to move, resize and turn at once.
/// Everything lies where the preview shows the material (its position, turn
/// and the camera are followed).
class MaterialRegionGizmo extends StatefulWidget {
  const MaterialRegionGizmo({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    this.outputWidth,
    this.outputHeight,
    required this.value,
    required this.shape,
    required this.selection,
    required this.onSelectionChanged,
    this.edit,
    this.onEditChanged,
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

  /// The shape a new outline is drawn in.
  final RegionShape shape;

  /// The part selected now (null: none).
  final RegionSelection? selection;
  final ValueChanged<RegionSelection?> onSelectionChanged;

  /// The moved or copied part being changed (null: selecting).
  final LayerRegionEdit? edit;
  final ValueChanged<LayerRegionEdit>? onEditChanged;
  final VoidCallback? onChangeEnd;
  final CameraKeyframe? camera;
  final Color? color;

  /// The handles of a rectangle's or an ellipse's box, in
  /// [MaterialCropGizmo.handles] order.
  static List<Offset> selectionHandles(Rect box) =>
      MaterialCropGizmo.handlePoints(box);

  /// The corners of a moved or copied part's box, then the middles of its
  /// sides (top, right, bottom, left), where they are drawn (layer pixels).
  static List<Offset> pieceHandles(LayerRegionEdit edit, double w, double h) {
    final b = Rect.fromLTRB(
      edit.region.bounds.left * w,
      edit.region.bounds.top * h,
      edit.region.bounds.right * w,
      edit.region.bounds.bottom * h,
    );
    return [
      for (final p in MaterialCropGizmo.handlePoints(b)) edit.mapPoint(p, w, h),
    ];
  }

  @override
  State<MaterialRegionGizmo> createState() => _MaterialRegionGizmoState();
}

class _MaterialRegionGizmoState extends State<MaterialRegionGizmo> {
  static const double _hitRadius = 24;

  /// How far (preview pixels) a freehand outline goes before a point is
  /// added.
  static const double _freehandStep = 3;

  Size _box = Size.zero;
  _RegionDrag? _drag;
  late _GizmoGeometry _startGeometry;
  Offset _startBox = Offset.zero;
  Offset _startLayer = Offset.zero;
  Offset _lastBox = Offset.zero;
  RegionSelection? _startSelection;
  CropHandle? _resizeHandle;
  LayerRegionEdit? _startEdit;
  int _stretchHandle = 0;

  /// The handle of the moved part that was grabbed (layer pixels): resizing
  /// follows it, not the point the finger came down on.
  Offset _grabbedHandle = Offset.zero;
  List<Offset> _freehand = [];

  /// Where the first finger came down: a drag starts there (the gesture is
  /// only told once it has moved a little).
  Offset? _down;
  int _pointers = 0;

  double get _w => widget.canvasWidth.toDouble();
  double get _h => widget.canvasHeight.toDouble();

  _GizmoGeometry _geometry() => _GizmoGeometry(
    box: _box,
    canvasWidth: widget.canvasWidth,
    canvasHeight: widget.canvasHeight,
    outputWidth: widget.outputWidth ?? widget.canvasWidth,
    outputHeight: widget.outputHeight ?? widget.canvasHeight,
    value: widget.value,
    camera: widget.camera,
    bounds: null,
  );

  Offset _clampedLayer(Offset p) =>
      Offset(p.dx.clamp(0, _w).toDouble(), p.dy.clamp(0, _h).toDouble());

  Offset _fraction(Offset layer) => Offset(layer.dx / _w, layer.dy / _h);

  Rect _layerBox(RegionSelection s) => Rect.fromLTRB(
    s.bounds.left * _w,
    s.bounds.top * _h,
    s.bounds.right * _w,
    s.bounds.bottom * _h,
  );

  /// The moved or copied part, when one is being changed.
  LayerRegionEdit? get _piece {
    final edit = widget.edit;
    return edit != null && edit.drawsPiece ? edit : null;
  }

  /// The centre of [edit]'s part where it is drawn (layer pixels).
  Offset _pieceCentre(LayerRegionEdit edit) =>
      edit.centreIn(_w, _h) + Offset(edit.dx * _w, edit.dy * _h);

  void _onStart(ScaleStartDetails d) {
    final g = _geometry();
    _startGeometry = g;
    final down = _down;
    final at = d.pointerCount < 2 && down != null ? down : d.localFocalPoint;
    _startBox = at;
    _lastBox = at;
    _startLayer = g.boxToLayer(at);
    final piece = _piece;
    if (piece != null) {
      _startEdit = piece;
      if (d.pointerCount >= 2) {
        _drag = _RegionDrag.pinchPiece;
        return;
      }
      final handles = [
        for (final p in MaterialRegionGizmo.pieceHandles(piece, _w, _h))
          g._layerToBox(p),
      ];
      final turn = _turnHandle(g, piece, handles);
      if ((turn - at).distance < _hitRadius) {
        _drag = _RegionDrag.turnPiece;
        return;
      }
      final offered = _offered(handles);
      var best = _reachAt(offered, at);
      int? hit;
      for (var i = 0; i < offered.length; i++) {
        final distance = (offered[i] - at).distance;
        if (distance < best) {
          best = distance;
          hit = i;
        }
      }
      if (hit != null) {
        _grabbedHandle = MaterialRegionGizmo.pieceHandles(piece, _w, _h)[hit];
      }
      if (hit == null) {
        _drag = _RegionDrag.movePiece;
      } else if (hit < 4) {
        _drag = _RegionDrag.scalePiece;
      } else {
        _drag = _RegionDrag.stretchPiece;
        _stretchHandle = hit;
      }
      return;
    }
    final selection = widget.selection;
    _startSelection = selection;
    if (selection != null) {
      if (selection.shape != RegionShape.freehand) {
        final box = _layerBox(selection);
        final points = _offered([
          for (final p in MaterialRegionGizmo.selectionHandles(box))
            g._layerToBox(p),
        ]);
        var best = _reachAt(points, at);
        _resizeHandle = null;
        for (var i = 0; i < points.length; i++) {
          final distance = (points[i] - at).distance;
          if (distance < best) {
            best = distance;
            _resizeHandle = MaterialCropGizmo.handles[i];
          }
        }
        if (_resizeHandle != null) {
          _drag = _RegionDrag.resizeSelection;
          return;
        }
      }
      if (selection.pathIn(_w, _h).contains(_startLayer)) {
        _drag = _RegionDrag.moveSelection;
        return;
      }
    }
    _drag = _RegionDrag.draw;
    _freehand = [_fraction(_clampedLayer(_startLayer))];
  }

  /// How near (preview pixels) [at] must be to one of [handles] (corners
  /// first) to grab it. Inside a small box the corners only take the part
  /// near them, so the middle of the box still moves it (a corner's reach
  /// covered the whole of a 43 × 27 part, and grabbing it near the middle
  /// resized it). Outside the box the reach is the whole radius.
  static double _reachAt(List<Offset> handles, Offset at) {
    final corners = handles.sublist(0, 4);
    var depth = double.infinity;
    var turn = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      final side = b - a;
      final length = side.distance;
      if (length < 1e-6) return _hitRadius;
      final cross = side.dx * (at.dy - a.dy) - side.dy * (at.dx - a.dx);
      // The corners go round one way or the other (a flip mirrors them):
      // inside, every side sees the point on the same hand.
      if (turn == 0) turn = cross.sign;
      if (cross.sign != turn) return _hitRadius;
      depth = math.min(depth, cross.abs() / length);
    }
    if (depth <= 0) return _hitRadius;
    final shortest = math.min(
      (corners[1] - corners[0]).distance,
      (corners[2] - corners[1]).distance,
    );
    return math.min(_hitRadius, shortest / 3);
  }

  /// The handles that are offered of [handles] (preview pixels, corners
  /// first): the middles of the sides only when the box is big enough on
  /// the preview that they and the corners can each be grabbed.
  static List<Offset> _offered(List<Offset> handles) {
    if (handles.length < 8) return handles;
    const room = 56.0;
    final across = (handles[1] - handles[0]).distance;
    final down = (handles[2] - handles[1]).distance;
    return across >= room && down >= room ? handles : handles.sublist(0, 4);
  }

  /// Where the dot that turns [piece] is drawn: above the middle of its top
  /// side, away from its centre.
  Offset _turnHandle(
    _GizmoGeometry g,
    LayerRegionEdit piece,
    List<Offset> handles,
  ) {
    final topMid = handles[4];
    final centre = g._layerToBox(_pieceCentre(piece));
    final outward = topMid - centre;
    final length = outward.distance;
    final direction = length < 1e-6 ? const Offset(0, -1) : outward / length;
    return topMid + direction * 28;
  }

  void _onUpdate(ScaleUpdateDetails d) {
    final drag = _drag;
    if (drag == null) return;
    final g = _startGeometry;
    final now = g.boxToLayer(d.localFocalPoint);
    switch (drag) {
      case _RegionDrag.draw:
        _draw(d.localFocalPoint, now);
      case _RegionDrag.moveSelection:
        final start = _startSelection;
        if (start == null) return;
        widget.onSelectionChanged(
          start.translated(_fraction(now - _startLayer)),
        );
      case _RegionDrag.resizeSelection:
        final start = _startSelection;
        final handle = _resizeHandle;
        if (start == null || handle == null) return;
        final rect = MaterialCropGizmo.dragged(
          _layerBox(start),
          handle,
          now - _startLayer,
          Rect.fromLTWH(0, 0, _w, _h),
        );
        widget.onSelectionChanged(
          RegionSelection.box(
            start.shape,
            Rect.fromLTRB(
              rect.left / _w,
              rect.top / _h,
              rect.right / _w,
              rect.bottom / _h,
            ),
          ),
        );
      case _RegionDrag.movePiece ||
          _RegionDrag.scalePiece ||
          _RegionDrag.stretchPiece ||
          _RegionDrag.turnPiece ||
          _RegionDrag.pinchPiece:
        if (drag != _RegionDrag.pinchPiece && d.pointerCount >= 2) {
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
        final next = _changedPiece(drag, d, now);
        if (next != null && next != widget.edit) {
          widget.onEditChanged?.call(next);
        }
    }
  }

  void _draw(Offset box, Offset layer) {
    final at = _fraction(_clampedLayer(layer));
    if (widget.shape == RegionShape.freehand) {
      if ((box - _lastBox).distance < _freehandStep) return;
      _lastBox = box;
      if (_freehand.length >= RegionSelection.maxPoints) return;
      _freehand = [..._freehand, at];
      if (_freehand.length < 3) return;
      final outline = RegionSelection.freehand(_freehand);
      if (outline.isValid) widget.onSelectionChanged(outline);
      return;
    }
    final rect = Rect.fromPoints(_freehand.first, at);
    final box0 = RegionSelection.box(widget.shape, rect);
    if (box0.isValid) widget.onSelectionChanged(box0);
  }

  LayerRegionEdit? _changedPiece(
    _RegionDrag drag,
    ScaleUpdateDetails d,
    Offset now,
  ) {
    final start = _startEdit;
    if (start == null) return null;
    final centre = _pieceCentre(start);
    switch (drag) {
      case _RegionDrag.movePiece:
        return _moved(start, now - _startLayer);
      case _RegionDrag.scalePiece || _RegionDrag.stretchPiece:
        // The grabbed handle goes where the finger goes; the size follows
        // how far along from the centre it now is (never through it).
        final axis = _grabbedHandle - centre;
        final squared = axis.dx * axis.dx + axis.dy * axis.dy;
        if (squared < 1e-9) return null;
        final towards = _grabbedHandle + (now - _startLayer) - centre;
        final ratio = math.max(
          0.0,
          (towards.dx * axis.dx + towards.dy * axis.dy) / squared,
        );
        if (drag == _RegionDrag.scalePiece) {
          return _resized(start, ratio, ratio);
        }
        // The middles of the top and bottom sides stretch it down, the
        // others across.
        final down = _stretchHandle == 4 || _stretchHandle == 6;
        return down ? _resized(start, 1, ratio) : _resized(start, ratio, 1);
      case _RegionDrag.turnPiece:
        final a0 = (_startLayer - centre).direction;
        final a1 = (now - centre).direction;
        return start.copyWith(
          rotation: _degrees(start.rotation + (a1 - a0) * 180 / math.pi),
        );
      case _RegionDrag.pinchPiece:
        final g = _startGeometry;
        final moved = _moved(
          start,
          g.boxToLayer(d.localFocalPoint) - g.boxToLayer(_startBox),
        );
        final scaled = _resized(moved, d.scale, d.scale);
        return scaled.copyWith(
          rotation: _degrees(start.rotation + d.rotation * 180 / math.pi),
        );
      case _RegionDrag.draw ||
          _RegionDrag.moveSelection ||
          _RegionDrag.resizeSelection:
        return null;
    }
  }

  /// [from] moved by [delta] (layer pixels), to whole pixels.
  LayerRegionEdit _moved(LayerRegionEdit from, Offset delta) {
    final limit = LayerRegionEdit.maxShift;
    final x = ((from.dx * _w + delta.dx).roundToDouble() / _w).clamp(
      -limit,
      limit,
    );
    final y = ((from.dy * _h + delta.dy).roundToDouble() / _h).clamp(
      -limit,
      limit,
    );
    return from.copyWith(dx: x.toDouble(), dy: y.toDouble());
  }

  /// [from] with its size times [rx] across and [ry] down (a flip is kept).
  static LayerRegionEdit _resized(LayerRegionEdit from, double rx, double ry) {
    double sized(double s, double ratio) {
      final size = (s.abs() * ratio.abs())
          .clamp(LayerRegionEdit.minScale, LayerRegionEdit.maxScale)
          .toDouble();
      return (size * 100).roundToDouble() / 100 * (s < 0 ? -1 : 1);
    }

    return from.copyWith(
      scaleX: sized(from.scaleX, rx),
      scaleY: sized(from.scaleY, ry),
    );
  }

  static double _degrees(double degrees) {
    var d = degrees % 360;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d.roundToDouble();
  }

  void _onEnd() {
    final drag = _drag;
    _drag = null;
    _freehand = [];
    if (drag == null ||
        drag == _RegionDrag.draw ||
        drag == _RegionDrag.moveSelection ||
        drag == _RegionDrag.resizeSelection) {
      // The selection is not part of the material: nothing to record.
      return;
    }
    widget.onChangeEnd?.call();
  }

  /// A tap outside the selection clears it.
  void _onTapUp(TapUpDetails d) {
    final selection = widget.selection;
    if (_piece != null || selection == null) return;
    final at = _geometry().boxToLayer(d.localPosition);
    if (!selection.pathIn(_w, _h).contains(at)) {
      widget.onSelectionChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        _box = constraints.biggest;
        final g = _geometry();
        final piece = _piece;
        List<Offset> toBox(Iterable<Offset> layer) => [
          for (final p in layer) g._layerToBox(p),
        ];
        List<Offset> outline = const [];
        List<Offset> source = const [];
        List<Offset> handles = const [];
        Offset? turn;
        Offset? turnStem;
        final selection = widget.selection;
        if (piece != null) {
          final region = piece.region.outlineIn(_w, _h);
          source = toBox(region);
          outline = toBox(region.map((p) => piece.mapPoint(p, _w, _h)));
          final all = toBox(MaterialRegionGizmo.pieceHandles(piece, _w, _h));
          turn = _turnHandle(g, piece, all);
          turnStem = all[4];
          handles = _offered(all);
        } else if (selection != null) {
          outline = toBox(selection.outlineIn(_w, _h));
          if (selection.shape != RegionShape.freehand) {
            handles = _offered(
              toBox(MaterialRegionGizmo.selectionHandles(_layerBox(selection))),
            );
          }
        }
        return Listener(
          onPointerDown: (e) {
            if (_pointers++ == 0) _down = e.localPosition;
          },
          onPointerUp: (_) => _pointers = math.max(0, _pointers - 1),
          onPointerCancel: (_) => _pointers = math.max(0, _pointers - 1),
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (r) => r.onTapUp = _onTapUp,
                  ),
              ScaleGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer(
                      dragStartBehavior: DragStartBehavior.down,
                    ),
                    (r) => r
                      ..onStart = _onStart
                      ..onUpdate = _onUpdate
                      ..onEnd = (_) => _onEnd(),
                  ),
            },
            child: CustomPaint(
              size: _box,
              painter: _RegionGizmoPainter(
                outline: outline,
                source: source,
                handles: handles,
                turn: turn,
                turnStem: turnStem,
                dashed: piece == null,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RegionGizmoPainter extends CustomPainter {
  _RegionGizmoPainter({
    required this.outline,
    required this.source,
    required this.handles,
    required this.turn,
    required this.turnStem,
    required this.dashed,
    required this.color,
  });

  /// The selection, or the moved or copied part where it is drawn.
  final List<Offset> outline;

  /// Where a moved or copied part was selected.
  final List<Offset> source;
  final List<Offset> handles;
  final Offset? turn;
  final Offset? turnStem;

  /// A selection is drawn dashed, a part being changed solid.
  final bool dashed;
  final Color color;

  static void _drawDashed(Canvas canvas, List<Offset> points, Paint paint) {
    const on = 6.0, off = 4.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final length = (b - a).distance;
      if (length < 1e-6) continue;
      final step = (b - a) / length;
      // Dashes run on across corners so short sides still show.
      var at = 0.0;
      while (at < length) {
        final end = math.min(at + on, length);
        canvas.drawLine(a + step * at, a + step * end, paint);
        at = end + off;
      }
    }
  }

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
    if (source.length >= 3) {
      final faint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      _drawDashed(canvas, source, shadow..strokeWidth = 2.5);
      _drawDashed(canvas, source, faint);
      shadow.strokeWidth = 3.5;
    }
    if (outline.length >= 3) {
      final path = Path()..addPolygon(outline, true);
      canvas.drawPath(path, shadow);
      if (dashed) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        _drawDashed(canvas, outline, line);
      } else {
        canvas.drawPath(path, line);
      }
    }
    final stem = turnStem;
    final dot = turn;
    if (stem != null && dot != null) {
      canvas.drawLine(stem, dot, shadow);
      canvas.drawLine(stem, dot, line);
    }
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
    if (dot != null) {
      canvas.drawCircle(dot, 8, fill);
      canvas.drawCircle(dot, 8, ring);
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
  bool shouldRepaint(_RegionGizmoPainter old) =>
      old.color != color ||
      old.dashed != dashed ||
      old.turn != turn ||
      old.turnStem != turnStem ||
      !_same(old.outline, outline) ||
      !_same(old.source, source) ||
      !_same(old.handles, handles);
}
