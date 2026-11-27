import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;

import '../models/camera_keyframe.dart';
import '../models/effect_filter_instance.dart';
import '../models/layer.dart';
import '../models/layer_group.dart';
import '../models/layer_keyframe.dart';
import 'camera_engine.dart';
import 'filter_engine.dart';
import 'layer_compositor.dart';
import 'layer_keyframe_engine.dart';
import 'tile_manager.dart';
import 'timeline_output_viewport.dart';
import 'timeline_stack.dart';

/// Everything that decides how one timeline frame looks. The timeline
/// preview and the export build the same request for the same frame, so the
/// frame is drawn by one pipeline in both.
class TimelineFrameRequest {
  const TimelineFrameRequest({
    required this.tileManager,
    required this.layers,
    required this.keyOf,
    required this.frameIndex,
    required this.drawingWidth,
    required this.drawingHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.backgroundColor,
    this.maskGroups = const [],
    this.groups = const [],
    this.cameraKeyframes = const [],
    this.effectFilters = const [],
    this.pixelsOf,
  });

  final TileManager tileManager;

  /// The frame's layers in the scene's stacking order (front first).
  final List<Layer> layers;
  final String Function(Layer layer) keyOf;
  final int frameIndex;
  final int drawingWidth;
  final int drawingHeight;
  final int outputWidth;
  final int outputHeight;
  final int backgroundColor;
  final List<LayerMaskGroup> maskGroups;
  final List<LayerGroup> groups;
  final List<CameraKeyframe> cameraKeyframes;
  final List<EffectFilterInstance> effectFilters;

  /// Pixels supplied in place of stored ones (decoded video frames).
  final LayerPixelSource? pixelsOf;
}

/// Draws timeline frames: layers (keyframes, groups, masks, blend modes,
/// supplied video frames) composited on the project's paper, the centred
/// output crop with the camera, then the scene's effect filters.
class TimelineFrameRenderer {
  final CameraEngine _cameraEngine = CameraEngine();
  final LayerKeyframeEngine _layerKeyframeEngine = LayerKeyframeEngine();
  final FilterEngine _filterEngine = FilterEngine();

  LayerKeyframe? _groupKeyframeOf(TimelineFrameRequest request, Layer layer) {
    for (final group in request.groups) {
      if (group.memberLayerIds.contains(layer.id)) {
        return group.keyframes.isEmpty
            ? null
            : _layerKeyframeEngine.valueAt(group.keyframes, request.frameIndex);
      }
    }
    return null;
  }

  /// Draws the output frame even where it would copy the drawing (for
  /// tests comparing the two).
  static bool debugAlwaysDrawViewport = false;

  /// The frame before effect filters, at the output size.
  Future<ui.Image> compose(TimelineFrameRequest request) async {
    final drawing = await LayerCompositor.composite(
      request.tileManager,
      request.layers,
      request.keyOf,
      request.drawingWidth,
      request.drawingHeight,
      keyframeOf: (layer) => layer.keyframes.isEmpty
          ? null
          : _layerKeyframeEngine.valueAt(layer.keyframes, request.frameIndex),
      groupKeyframeOf: (layer) => _groupKeyframeOf(request, layer),
      // The paper takes part in blend modes (Linear Dodge brightens it).
      paperColor: request.backgroundColor,
      maskGroups: request.maskGroups,
      pixelsOf: request.pixelsOf,
    );
    final camera = _cameraEngine.valueAt(
      request.cameraKeyframes,
      request.frameIndex,
    );
    if (!debugAlwaysDrawViewport && _viewportCopiesDrawing(request, camera)) {
      return drawing;
    }
    try {
      return await renderOutputViewportImage(
        drawingImage: drawing,
        viewport: TimelineOutputViewport(
          drawingWidth: request.drawingWidth,
          drawingHeight: request.drawingHeight,
          outputWidth: request.outputWidth,
          outputHeight: request.outputHeight,
        ),
        backgroundColor: request.backgroundColor,
        cameraEngine: _cameraEngine,
        cameraKeyframe: camera,
      );
    } finally {
      drawing.dispose();
    }
  }

  /// Whether the output frame would be a pixel-for-pixel copy of the
  /// composited drawing, so drawing it a second time can be skipped: the
  /// output is the whole drawing (no crop), the camera does not move it, and
  /// the background under it changes nothing (opaque, so the drawing was
  /// composited onto that same paper and covers it; or fully transparent).
  static bool _viewportCopiesDrawing(
    TimelineFrameRequest request,
    CameraKeyframe camera,
  ) {
    if (request.outputWidth != request.drawingWidth ||
        request.outputHeight != request.drawingHeight) {
      return false;
    }
    if (camera.x != 0 ||
        camera.y != 0 ||
        camera.rotation != 0 ||
        (camera.zoom != 1 && camera.zoom != 0)) {
      return false;
    }
    final alpha = request.backgroundColor >>> 24;
    return alpha == 0xFF || alpha == 0;
  }

  /// The finished frame as RGBA bytes (what the export encodes).
  Future<Uint8List> renderRgba(TimelineFrameRequest request) async {
    final image = await compose(request);
    final ByteData? data;
    try {
      data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
    final rgba = data!.buffer.asUint8List();
    return _applyEffects(request, rgba);
  }

  /// The finished frame as an image (what the preview shows). The effect
  /// filters run off the screen's thread (some take seconds on a big frame,
  /// and the timeline stopped taking touches meanwhile); a frame no effect
  /// covers is shown as it was composed (the same picture: no effect changes
  /// it).
  Future<ui.Image> renderImage(TimelineFrameRequest request) async {
    final image = await compose(request);
    final active = [
      for (final e in request.effectFilters)
        if (e.enabled &&
            request.frameIndex >= e.startFrame &&
            request.frameIndex <= e.endFrame)
          e,
    ];
    if (active.isEmpty) return image;
    final ByteData? data;
    try {
      data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
    final filtered = await compute(_applyEffectsApart, (
      rgba: data!.buffer.asUint8List(),
      width: request.outputWidth,
      height: request.outputHeight,
      effects: active,
      frameIndex: request.frameIndex,
    ));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      filtered,
      request.outputWidth,
      request.outputHeight,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Uint8List _applyEffects(TimelineFrameRequest request, Uint8List rgba) {
    if (request.effectFilters.isEmpty) return rgba;
    return _filterEngine.applyEffectFilters(
      rgba,
      request.outputWidth,
      request.outputHeight,
      request.effectFilters,
      request.frameIndex,
    );
  }
}

/// [FilterEngine.applyEffectFilters] for a frame of the preview, in a
/// background isolate.
Uint8List _applyEffectsApart(
  ({
    Uint8List rgba,
    int width,
    int height,
    List<EffectFilterInstance> effects,
    int frameIndex,
  })
  job,
) => FilterEngine().applyEffectFilters(
  job.rgba,
  job.width,
  job.height,
  job.effects,
  job.frameIndex,
);
