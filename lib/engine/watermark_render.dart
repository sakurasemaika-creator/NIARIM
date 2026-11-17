import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/text_object.dart';
import '../models/watermark_asset.dart';
import 'filter_engine.dart';
import 'premultiplied.dart';
import 'text_render.dart';

/// Renders a watermark and its effects into a premultiplied RGBA layer.
/// Previews center the watermark so its edges are visible in a small tile.
Future<Uint8List?> rasterizeWatermark(
  WatermarkAsset asset,
  int width,
  int height, {
  String? imagePath,
  double angle = 0,
  double scale = .25,
  bool preview = false,
}) async {
  final pixels = switch (asset.type) {
    WatermarkAssetType.text => await _renderText(
      asset,
      width,
      height,
      angle,
      scale,
      preview,
    ),
    WatermarkAssetType.image when imagePath != null => await _renderImage(
      imagePath,
      width,
      height,
      angle,
      scale,
      preview,
    ),
    _ => null,
  };
  if (pixels == null) return null;
  return _applyEffects(pixels, width, height, asset);
}

Future<Uint8List?> _renderText(
  WatermarkAsset asset,
  int width,
  int height,
  double angle,
  double scale,
  bool preview,
) {
  final text = asset.text ?? '';
  if (text.isEmpty) return Future.value(null);
  final fontSize = preview ? height * .21 : height * .18 * scale;
  return rasterizeTextObject(
    TextObject(
      id: asset.id,
      text: text,
      fontSize: fontSize,
      color: ui.Color(asset.textColor ?? 0xFFFFFFFF),
      fontFamily: asset.fontFamily ?? 'Roboto',
      align: preview ? ui.TextAlign.center : ui.TextAlign.right,
      rotation: angle,
      position: ui.Offset(width * .1, height - fontSize * 1.6 - height * .02),
    ),
    width,
    height,
    center: preview ? ui.Offset(width / 2, height / 2) : null,
  );
}

Future<Uint8List?> _renderImage(
  String path,
  int width,
  int height,
  double angle,
  double scale,
  bool preview,
) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  try {
    final imageScale = preview
        ? math.min(width * .65 / image.width, height * .65 / image.height)
        : width * scale / image.width;
    final drawWidth = image.width * imageScale;
    final drawHeight = image.height * imageScale;
    final rect = ui.Rect.fromLTWH(
      preview ? (width - drawWidth) / 2 : width - drawWidth - 16,
      preview ? (height - drawHeight) / 2 : height - drawHeight - 16,
      drawWidth,
      drawHeight,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..translate(rect.center.dx, rect.center.dy)
      ..rotate(angle * math.pi / 180)
      ..translate(-rect.center.dx, -rect.center.dy);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final ui.Image rendered;
    try {
      rendered = await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
    try {
      final data = await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return data?.buffer.asUint8List();
    } finally {
      rendered.dispose();
    }
  } finally {
    image.dispose();
  }
}

Uint8List _applyEffects(
  Uint8List pixels,
  int width,
  int height,
  WatermarkAsset asset,
) {
  final filters = FilterEngine();
  final foreground = asset.outlineEnabled
      ? filters.applyOutline(
          pixels,
          width,
          height,
          color: asset.outlineColor,
          widthPx: asset.outlineWidth,
        )
      : pixels;
  if (!asset.shadowEnabled) return foreground;

  final shadow = Uint8List(pixels.length);
  final alpha = (asset.shadowColor >> 24) & 255;
  final red = (asset.shadowColor >> 16) & 255;
  final green = (asset.shadowColor >> 8) & 255;
  final blue = asset.shadowColor & 255;
  final dx = asset.shadowOffsetX.round();
  final dy = asset.shadowOffsetY.round();
  for (var y = math.max(0, dy); y < math.min(height, height + dy); y++) {
    for (var x = math.max(0, dx); x < math.min(width, width + dx); x++) {
      final source = ((y - dy) * width + x - dx) * 4;
      final target = (y * width + x) * 4;
      final opacity = premultipliedChannel(alpha, foreground[source + 3]);
      shadow[target] = premultipliedChannel(red, opacity);
      shadow[target + 1] = premultipliedChannel(green, opacity);
      shadow[target + 2] = premultipliedChannel(blue, opacity);
      shadow[target + 3] = opacity;
    }
  }
  final result = asset.shadowBlur > 0
      ? filters.applyGaussianBlur(shadow, width, height, asset.shadowBlur)
      : shadow;
  for (var i = 0; i < result.length; i += 4) {
    final keep = 255 - foreground[i + 3];
    for (var channel = 0; channel < 4; channel++) {
      result[i + channel] =
          foreground[i + channel] +
          premultipliedChannel(result[i + channel], keep);
    }
  }
  return result;
}
