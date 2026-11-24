import 'dart:ui' as ui;

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
