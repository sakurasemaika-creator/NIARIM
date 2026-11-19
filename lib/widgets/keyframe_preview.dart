import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/camera_engine.dart';
import '../engine/layer_compositor.dart';
import '../engine/layer_keyframe_engine.dart';
import '../l10n/app_localizations.dart';
import '../models/camera_keyframe.dart';
import '../models/layer.dart';
import '../models/layer_keyframe.dart';
import '../services/project_service.dart';
import 'frame_preview_background.dart';

/// The gesture reports translation in project pixels and scale/rotation
/// relative to the beginning of the gesture, without depending on sheet size.
class KeyframePreview extends StatefulWidget {
  const KeyframePreview({
    super.key,
    required this.projects,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.onGestureStart,
    required this.onTransform,
    this.layerId,
    this.groupId,
    this.layerTransform,
    this.camera,
  });

  final ProjectService projects;
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String? layerId;
  final String? groupId;
  final LayerKeyframe? layerTransform;
  final CameraKeyframe? camera;
  final VoidCallback onGestureStart;
  final void Function(Offset translation, double scale, double degrees)
  onTransform;

  @override
  State<KeyframePreview> createState() => _KeyframePreviewState();
}

class _KeyframePreviewState extends State<KeyframePreview> {
  ui.Image? _image;
  bool _rendering = false;
  bool _pending = false;
  int? _imageFrame;
  int? _failedFrame;
  Offset _gestureOrigin = Offset.zero;
  Offset? _pointerDown;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(KeyframePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameIndex != widget.frameIndex ||
        oldWidget.projectId != widget.projectId ||
        oldWidget.sceneId != widget.sceneId ||
        oldWidget.projects != widget.projects ||
        oldWidget.layerId != widget.layerId ||
        oldWidget.groupId != widget.groupId ||
        oldWidget.layerTransform != widget.layerTransform) {
      _refresh();
    }
  }

  Future<ui.Image> _render(KeyframePreview request) async {
    final projects = request.projects;
    final tm = projects.tileManagerOf(request.projectId);
    final stack = projects.stackedLayersOf(
      request.projectId,
      request.sceneId,
      request.frameIndex,
      applyFrameMask: request.camera != null,
    );
    final engine = LayerKeyframeEngine();
    final groupTransforms = <String, LayerKeyframe>{};
    for (final group in projects.layerGroupsOf(
      request.projectId,
      request.sceneId,
    )) {
      final value = group.id == request.groupId
          ? request.layerTransform
          : group.keyframes.isEmpty
          ? null
          : engine.valueAt(group.keyframes, request.frameIndex);
      if (value != null) {
        for (final id in group.memberLayerIds) {
          groupTransforms.putIfAbsent(id, () => value);
        }
      }
    }
    String keyOf(Layer layer) => projects.tileKeyFor(
      request.projectId,
      request.sceneId,
      request.frameIndex,
      layer.id,
    );
    LayerKeyframe? keyframeOf(Layer layer) => layer.id == request.layerId
        ? request.layerTransform
        : layer.keyframes.isEmpty
        ? null
        : engine.valueAt(layer.keyframes, request.frameIndex);
    LayerKeyframe? groupKeyframeOf(Layer layer) => groupTransforms[layer.id];

    final paper = LayerCompositor.paperForBlendModes(
      stack.layers,
      _paperColor(request),
    );
    final needsRaster = stack.layers.any(
      (layer) =>
          layer.isVisible && LayerCompositor.requiresCpuBlend(layer.blendMode),
    );
    // For ordinary layers paint the commands directly into the small preview.
    // Blend modes that need pixel math use the same compositor as playback.
    final raster = needsRaster
        ? await LayerCompositor.composite(
            tm,
            stack.layers,
            keyOf,
            tm.canvasWidth,
            tm.canvasHeight,
            keyframeOf: keyframeOf,
            groupKeyframeOf: groupKeyframeOf,
            maskGroups: stack.maskGroups,
            paperColor: paper,
          )
        : null;
    final picture = needsRaster
        ? null
        : await LayerCompositor.compositeToPicture(
            tm,
            stack.layers,
            keyOf,
            tm.canvasWidth,
            tm.canvasHeight,
            keyframeOf: keyframeOf,
            groupKeyframeOf: groupKeyframeOf,
            maskGroups: stack.maskGroups,
          );
    final scale = math.min(
      1.0,
      720 / math.max(tm.canvasWidth, tm.canvasHeight),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale);
    if (raster != null) {
      canvas.drawImage(raster, Offset.zero, Paint());
    } else {
      if (paper != null) canvas.drawColor(Color(paper), BlendMode.src);
      canvas.drawPicture(picture!);
    }
    final resized = recorder.endRecording();
    try {
      return await resized.toImage(
        math.max(1, (tm.canvasWidth * scale).round()),
        math.max(1, (tm.canvasHeight * scale).round()),
      );
    } finally {
      raster?.dispose();
      picture?.dispose();
      resized.dispose();
    }
  }

  int _paperColor(KeyframePreview request) =>
      request.projects.projects
          .where((project) => project.id == request.projectId)
          .firstOrNull
          ?.backgroundColor ??
      0xFFFFFFFF;

  Future<void> _refresh() async {
    if (_rendering) {
      _pending = true;
      return;
    }
    _rendering = true;
    final request = widget;
    try {
      final image = await _render(request);
      if (!mounted ||
          widget.frameIndex != request.frameIndex ||
          widget.sceneId != request.sceneId ||
          widget.projectId != request.projectId) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _imageFrame = request.frameIndex;
        _failedFrame = null;
      });
    } catch (error) {
      debugPrint('Keyframe preview could not be composed: $error');
      if (mounted && request.frameIndex == widget.frameIndex) {
        setState(() => _failedFrame = request.frameIndex);
      }
    } finally {
      _rendering = false;
      if (mounted && _pending) {
        _pending = false;
        _refresh();
      }
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tm = widget.projects.tileManagerOf(widget.projectId);
    final paper = _paperColor(widget);
    final image = _imageFrame == widget.frameIndex ? _image : null;
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: FramePreviewBackground(
        backgroundColor: paper,
        aspectRatio: tm.canvasWidth / tm.canvasHeight,
        child: _failedFrame == widget.frameIndex
            ? Center(
                child: Text(
                  AppLocalizations.of(context)!.timelinePreviewPlaceholder,
                ),
              )
            : image == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : LayoutBuilder(
                builder: (context, bounds) => MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Listener(
                    onPointerDown: (event) =>
                        _pointerDown = event.localPosition,
                    onPointerUp: (_) => _pointerDown = null,
                    onPointerCancel: (_) => _pointerDown = null,
                    child: GestureDetector(
                      key: const ValueKey('keyframeTransformPreview'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        _gestureOrigin = details.pointerCount == 1
                            ? _pointerDown ?? details.localFocalPoint
                            : details.localFocalPoint;
                        _pointerDown = null;
                        widget.onGestureStart();
                      },
                      onScaleUpdate: (details) {
                        final delta = details.localFocalPoint - _gestureOrigin;
                        widget.onTransform(
                          Offset(
                            delta.dx * tm.canvasWidth / bounds.maxWidth,
                            delta.dy * tm.canvasHeight / bounds.maxHeight,
                          ),
                          details.scale,
                          details.rotation * 180 / math.pi,
                        );
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _PreviewImage(
                            image,
                            widget.camera,
                            tm.canvasWidth,
                            tm.canvasHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PreviewImage extends CustomPainter {
  const _PreviewImage(this.image, this.camera, this.width, this.height);

  final ui.Image image;
  final CameraKeyframe? camera;
  final int width;
  final int height;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / width, size.height / height);
    if (camera case final transform?) {
      CameraEngine().apply(
        canvas,
        transform,
        width.toDouble(),
        height.toDouble(),
      );
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewImage oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.camera != camera ||
      oldDelegate.width != width ||
      oldDelegate.height != height;
}

class KeyframePreviewHint extends StatelessWidget {
  const KeyframePreviewHint({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
    child: Text(
      AppLocalizations.of(context)!.keyframePreviewGestureHint,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium,
    ),
  );
}
