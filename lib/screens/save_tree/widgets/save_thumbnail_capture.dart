import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../engine/layer_compositor.dart';
import '../../../engine/layer_keyframe_engine.dart';
import '../../../engine/layer_range_resolver.dart';
import '../../../engine/niapro_serializer.dart';
import '../../../engine/tile_manager.dart';
import '../../../engine/timeline_stack.dart';
import '../../../models/layer.dart';
import '../../../models/layer_keyframe.dart';
import '../../../models/scene.dart';
import '../../../services/project_service.dart';

final _keyframes = LayerKeyframeEngine();

/// Capture a snapshot from the project at save time, including the actual
/// canvas/paper color beneath transparent pixels. Both save modes use this
/// single path so their previews cannot disagree.
/// The leading scene/frame is the project's representative still frame.
Future<Uint8List> captureSaveThumbnail(
  ProjectService service,
  String projectId,
) async {
  final project = service.projects.where((p) => p.id == projectId).firstOrNull;
  final scene = service.scenesOf(projectId).firstOrNull;
  final frame = scene?.frames.firstOrNull;
  final stack = frame == null
      ? null
      : service.stackedLayersOf(projectId, scene!.id, frame.index);
  return _capture(
    service.tileManagerOf(projectId),
    project?.backgroundColor ?? 0xFFFFFFFF,
    stack,
    (layer) => service.tileKeyFor(projectId, scene!.id, frame!.index, layer.id),
    scene: scene,
    frameIndex: frame?.index ?? 0,
  );
}

/// Renders the saved first frame from its own archived tiles and paper color.
/// This also works for saves created without a thumbnail file.
Future<Uint8List> captureSavedThumbnail(NiaproData data) async {
  final scene = data.scenes.first;
  final frame = scene.frames.first;
  final homes = buildLayerHomeIndex(data.scenes);
  final layers = resolveFrameLayers(
    data.scenes,
    homes,
    scene.id,
    frame.index,
    frame.layers,
  );
  final stack = stackFrameLayers(scene, frame.index, layers);
  String keyOf(Layer layer) =>
      resolveTileKey(homes, scene.id, frame.index, layer.id);
  final tiles = TileManager(
    canvasWidth: data.project.drawingWidth,
    canvasHeight: data.project.drawingHeight,
  );
  try {
    // Only import the tiles this frame can read, including shared layers.
    tiles.importAll({
      for (final key in stack.layers.map(keyOf)) key: ?data.tileData[key],
    });
    return await _capture(
      tiles,
      data.project.backgroundColor,
      stack,
      keyOf,
      scene: scene,
      frameIndex: frame.index,
    );
  } finally {
    tiles.dispose();
  }
}

Future<Uint8List> _capture(
  TileManager tileManager,
  int background,
  StackedFrameLayers? stack,
  String Function(Layer) keyOf, {
  required Scene? scene,
  required int frameIndex,
}) async {
  final width = tileManager.canvasWidth;
  final height = tileManager.canvasHeight;
  if (width <= 0 || height <= 0) {
    throw StateError('Cannot capture a save with invalid canvas dimensions');
  }

  const maxEdge = 200;
  final scale = maxEdge / math.max(width, height);
  final targetWidth = (width * scale).round().clamp(1, maxEdge);
  final targetHeight = (height * scale).round().clamp(1, maxEdge);
  // Rasterize large drawings at twice the thumbnail size to retain fine lines
  // without allocating a full-canvas image for each layer.
  final rasterSize = scale < .5
      ? ui.Size((targetWidth * 2).toDouble(), (targetHeight * 2).toDouble())
      : null;
  LayerKeyframe? groupKeyframeOf(Layer layer) {
    final group = scene?.groups
        .where((group) => group.memberLayerIds.contains(layer.id))
        .firstOrNull;
    return group == null || group.keyframes.isEmpty
        ? null
        : _keyframes.valueAt(group.keyframes, frameIndex);
  }

  final composited = stack == null
      ? null
      : await LayerCompositor.composite(
          tileManager,
          stack.layers,
          keyOf,
          width,
          height,
          keyframeOf: (layer) => layer.keyframes.isEmpty
              ? null
              : _keyframes.valueAt(layer.keyframes, frameIndex),
          groupKeyframeOf: groupKeyframeOf,
          paperColor: LayerCompositor.paperForBlendModes(
            stack.layers,
            background,
          ),
          maskGroups: stack.maskGroups,
          rasterSize: rasterSize,
        );

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // A normal-blend composite has transparent pixels where the paper shows.
  // Explicitly paint that paper into the save PNG, rather than allowing the
  // save-card theme background to change what the user sees.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
    ui.Paint()..color = ui.Color(background),
  );
  if (composited != null) {
    try {
      canvas.drawImageRect(
        composited,
        ui.Rect.fromLTWH(
          0,
          0,
          composited.width.toDouble(),
          composited.height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
    } finally {
      composited.dispose();
    }
  }

  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(targetWidth, targetHeight);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Failed to encode the save thumbnail');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

/// Backward-compatible entry point used by older callers and tests.
Future<Uint8List?> captureEmptySaveThumbnail(
  ProjectService service,
  String projectId,
) => captureSaveThumbnail(service, projectId);
