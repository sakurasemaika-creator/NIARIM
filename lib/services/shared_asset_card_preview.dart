import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/drawing_engine.dart';
import '../engine/procedural_texture.dart';
import '../engine/stamp_engine.dart';
import '../engine/tile_manager.dart';
import '../engine/tone_engine.dart';
import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';

/// Actual drawing-engine sample for a procedural NIARIM share card.
/// Reuses the same raster path as StrokeSamplePreview in the pen panel.
class SharedAssetCardPreview {
  SharedAssetCardPreview._();

  static const int width = 240;
  static const int height = 48;

  static List<ui.Offset> _wave() => [
    for (var x = 12; x <= width - 12; x += 2)
      ui.Offset(
        x.toDouble(),
        height / 2 + 9 * math.sin((x - 12) / (width - 24) * math.pi * 4),
      ),
  ];

  static Future<ui.Image> _decode(Uint8List rgba) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba, width, height, ui.PixelFormat.rgba8888, completer.complete,
    );
    return completer.future;
  }

  static Future<ui.Image> render(
    String kind,
    Map<String, dynamic> json, {
    Color color = Colors.black,
  }) async {
    if (kind == 'brush') {
      final brush = Brush.fromJson(json);
      if (brush.resolvedCustomImagePaths.isNotEmpty) {
        throw const FormatException('Image brush needs original source textures');
      }
      final offBlur = brush.pressureOff.blur;
      final onBlur = brush.pressureOn.blur;
      final maxBlur = math.max(
        offBlur.enabled ? offBlur.value : 0,
        onBlur.enabled ? math.max(onBlur.weak, onBlur.strong) : 0,
      );
      final extent = brush.size / 2 + maxBlur;
      final scale = math.min(
        1.0,
        math.min(19.0 / math.max(brush.size, 1),
            16.0 / math.max(extent, 1)),
      );
      int scaledBlur(int value) => (value * scale).round().clamp(0, 100);
      final preview = brush.copyWith(
        size: math.max(0.5, brush.size * scale),
        pressureOff: brush.pressureOff.copyWith(
          blur: offBlur.copyWith(value: scaledBlur(offBlur.value)),
        ),
        pressureOn: brush.pressureOn.copyWith(
          blur: onBlur.copyWith(
            weak: scaledBlur(onBlur.weak),
            strong: scaledBlur(onBlur.strong),
          ),
        ),
      );
      final tiles = TileManager(canvasWidth: width, canvasHeight: height);
      try {
        final engine = DrawingEngine(tileManager: tiles)
          ..currentColor = color
          ..currentBrush = preview
          ..pressureEnabled = true;
        final points = _wave();
        StrokePoint strokePoint(ui.Offset pos, int i) {
          final t = i / (points.length - 1);
          return StrokePoint(
            x: pos.dx,
            y: pos.dy,
            inputType: InputType.stylus,
            pressure: 0.4 + 0.6 * math.sin(math.pi * t),
          );
        }
        engine.beginStroke(strokePoint(points.first, 0), 'share-card');
        for (var i = 1; i < points.length; i++) {
          engine.continueStroke(strokePoint(points[i], i), 'share-card');
        }
        if (engine.needsFinalFadeReplay) {
          engine.replayCurrentStrokeWithFinalFade();
        }
        engine.endStroke();
        return await tiles.compositeLayerToImage('share-card');
      } finally {
        tiles.dispose();
      }
    }
    if (kind == 'tone') {
      final tone = Tone.fromJson(json);
      if (tone.texturePath != null) {
        throw const FormatException('Image tone needs original source texture');
      }
      const textureSize = 64;
      await ensureToneTextureLoaded(tone, size: textureSize);
      final pixels = ToneEngine().drawToneStroke(
        points: _wave(),
        brushSize: 17,
        color: color,
        canvasData: Uint8List(width * height * 4),
        canvasWidth: width,
        canvasHeight: height,
        toneTexture: generateBuiltInToneTexture(tone, size: textureSize),
        toneWidth: textureSize,
        toneHeight: textureSize,
      );
      return _decode(pixels);
    }
    if (kind == 'stamp') {
      final stamp = Stamp.fromJson(json);
      if (stamp.imagePath != null) {
        throw const FormatException('Image stamp needs original source texture');
      }
      final texture = await generateBuiltInStampTexture(stamp, size: 48);
      final pixels = StampEngine().stampAlongPath(
        canvasData: Uint8List(width * height * 4),
        width: width,
        height: height,
        texture: texture,
        texSize: 48,
        points: _wave(),
        stampSize: 23,
        rotation: stamp.rotation,
        scatter: stamp.scatter,
        density: stamp.density,
        opacity: 100,
        seed: 0,
      );
      return _decode(pixels);
    }
    throw const FormatException('Unsupported share card kind');
  }
}
