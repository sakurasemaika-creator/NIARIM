import 'dart:math' as math;
import 'dart:ui' as ui;

/// Render an individual layer as it sits over the project's real canvas
/// background. The square list thumbnail is a viewport, not a crop: a tall
/// or wide canvas retains its aspect ratio and transparent pixels show the
/// project background rather than the UI panel's grey placeholder.
Future<ui.Image> renderLayerThumbnail(
  ui.Image layerImage, {
  required int backgroundColor,
  int opacity = 100,
  int size = 48,
}) async {
  assert(size > 0);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = ui.Color(backgroundColor),
  );
  if (layerImage.width > 0 && layerImage.height > 0) {
    final scale = math.min(size / layerImage.width, size / layerImage.height);
    final width = layerImage.width * scale;
    final height = layerImage.height * scale;
    final rect = ui.Rect.fromLTWH(
      (size - width) / 2,
      (size - height) / 2,
      width,
      height,
    );
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..color = ui.Color.fromARGB(
        (opacity.clamp(0, 100) * 255 / 100).round(), 255, 255, 255,
      );
    canvas.drawImageRect(
      layerImage,
      ui.Rect.fromLTWH(
        0, 0, layerImage.width.toDouble(), layerImage.height.toDouble(),
      ),
      rect,
      paint,
    );
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(size, size);
  } finally {
    picture.dispose();
  }
}
