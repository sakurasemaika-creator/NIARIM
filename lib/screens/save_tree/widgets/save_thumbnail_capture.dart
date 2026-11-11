import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../engine/layer_compositor.dart';
import '../../../services/project_service.dart';

/// Capture a snapshot from the project at save time, including the actual
/// canvas/paper color beneath transparent pixels. Both save modes use this
/// single path so their previews cannot disagree.
/// The leading scene/frame is the project's representative still frame.
Future<Uint8List> captureSaveThumbnail(
  ProjectService service,
  String projectId,
) async {
  final project =
      service.projects.where((p) => p.id == projectId).firstOrNull;
  final tileManager = service.tileManagerOf(projectId);
  final width = tileManager.canvasWidth;
  final height = tileManager.canvasHeight;
  if (width <= 0 || height <= 0) {
    throw StateError('Cannot capture a save with invalid canvas dimensions');
  }

  const maxEdge = 200;
  final scale = maxEdge / math.max(width, height);
  final targetWidth = (width * scale).round().clamp(1, maxEdge);
  final targetHeight = (height * scale).round().clamp(1, maxEdge);
  final background = project?.backgroundColor ?? 0xFFFFFFFF;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // A normal-blend composite has transparent pixels where the paper shows.
  // Explicitly paint that paper into the save PNG, rather than allowing the
  // save-card theme background to change what the user sees.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
    ui.Paint()..color = ui.Color(background),
  );
  final scenes = service.scenesOf(projectId);
  if (scenes.isNotEmpty && scenes.first.frames.isNotEmpty) {
    final scene = scenes.first;
    final frame = scene.frames.first;
    final layers = service.layersOf(projectId, scene.id, frame.index);
    final composited = await LayerCompositor.composite(
      tileManager,
      layers,
      (layer) =>
          service.tileKeyFor(projectId, scene.id, frame.index, layer.id),
      width,
      height,
      paperColor: LayerCompositor.paperForBlendModes(layers, background),
    );
    try {
      canvas.drawImageRect(
        composited,
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Rect.fromLTWH(
          0,
          0,
          targetWidth.toDouble(),
          targetHeight.toDouble(),
        ),
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
