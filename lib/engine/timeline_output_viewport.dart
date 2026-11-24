import 'dart:ui' as ui;

import '../models/camera_keyframe.dart';
import 'camera_engine.dart';

/// Geometry shared by timeline preview and export for the visible output area.
///
/// The drawing canvas may be larger than the requested output. In that case
/// the output is the centred rectangle of the drawing canvas. Keeping this
/// calculation in one place prevents preview/export crop drift.
class TimelineOutputViewport {
  const TimelineOutputViewport({
    required this.drawingWidth,
    required this.drawingHeight,
    required this.outputWidth,
    required this.outputHeight,
  }) : assert(drawingWidth > 0),
       assert(drawingHeight > 0),
       assert(outputWidth > 0),
       assert(outputHeight > 0);

  final int drawingWidth;
  final int drawingHeight;
  final int outputWidth;
  final int outputHeight;

  double get cropLeft => (drawingWidth - outputWidth) / 2;
  double get cropTop => (drawingHeight - outputHeight) / 2;

  /// Position at which the full drawing image is placed on the output canvas.
  double get imageOffsetX => -cropLeft;
  double get imageOffsetY => -cropTop;
}

/// Paints the drawing image into the output frame using the shared crop.
/// Callers apply the camera transform to [canvas] before calling this method.
void paintOutputViewport(
  ui.Canvas canvas,
  ui.Image image,
  TimelineOutputViewport viewport,
) {
  canvas.drawImage(
    image,
    ui.Offset(viewport.imageOffsetX, viewport.imageOffsetY),
    ui.Paint(),
  );
}

/// Renders the output frame identically for timeline preview and export.
/// The background is outside the camera transform; the drawing image is
/// cropped and then transformed around the output frame's centre.
Future<ui.Image> renderOutputViewportImage({
  required ui.Image drawingImage,
  required TimelineOutputViewport viewport,
  required int backgroundColor,
  required CameraEngine cameraEngine,
  required CameraKeyframe? cameraKeyframe,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(
      0,
      0,
      viewport.outputWidth.toDouble(),
      viewport.outputHeight.toDouble(),
    ),
    ui.Paint()..color = ui.Color(backgroundColor),
  );
  canvas.save();
  cameraEngine.apply(
    canvas,
    cameraKeyframe,
    viewport.outputWidth.toDouble(),
    viewport.outputHeight.toDouble(),
  );
  paintOutputViewport(canvas, drawingImage, viewport);
  canvas.restore();
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(
      viewport.outputWidth,
      viewport.outputHeight,
    );
  } finally {
    picture.dispose();
  }
}
