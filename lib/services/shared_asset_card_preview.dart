import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/brush_texture_cache.dart';
import '../engine/drawing_engine.dart';
import '../engine/procedural_texture.dart';
import '../engine/stamp_engine.dart';
import '../engine/tile_manager.dart';
import '../engine/tone_engine.dart';
import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';

/// A stroke rendered with the canvas drawing engines for the tool list and shared cards.
class SharedAssetCardPreview {
  SharedAssetCardPreview._();

  static const int _width = 240;
  static const int _height = 48;
  static const int _waveInset = 12;
  static const int _waveAmplitude = 9;

  static List<ui.Offset> _wavePoints([int inset = _waveInset]) => [
    for (var x = inset; x <= _width - inset; x += 2)
      ui.Offset(
        x.toDouble(),
        _height / 2 +
            _waveAmplitude *
                math.sin((x - inset) / (_width - 2 * inset) * math.pi * 4),
      ),
  ];

  static Future<ui.Image> _decode(Uint8List rgba) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      _width,
      _height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  static Future<ui.Image> render({
    Brush? brush,
    Tone? tone,
    Stamp? stamp,
    Color color = Colors.black,
  }) async {
    if (brush != null) {
      await preloadBrushTextures(
        brush.resolvedCustomImagePaths,
        mode: brush.imageInkMode,
      );
      // A soft preset can spread far beyond its nominal pen size. Scale
      // BOTH the diameter and the blur radius to keep the whole soft edge
      // visible in this 48px strip. Previously only size was clamped, which
      // made e.g. a 30px/50-blur airbrush look like a solid, clipped mark.
      final offBlur = brush.pressureOff.blur;
      final onBlur = brush.pressureOn.blur;
      final maxBlur = math.max(
        offBlur.enabled ? offBlur.value : 0,
        onBlur.enabled ? math.max(onBlur.weak, onBlur.strong) : 0,
      );
      final extent = brush.size / 2 + maxBlur;
      // The drawing engine stretches fixed-angle tips before rotating them.
      // Project that ellipse onto the preview axes to leave room for its halo.
      final angle = brush.calligraphyAngle;
      var horizontalScale = 1.0;
      var verticalScale = 1.0;
      if (angle != null) {
        final radians = angle * math.pi / 180;
        final cos = math.cos(radians);
        final sin = math.sin(radians);
        final ratio = Brush.clampNibWidthRatio(brush.nibWidthRatio);
        final widthScaleSquared = ratio * ratio;
        horizontalScale = brush.rotation
            ? math.max(ratio, 1.0)
            : math.sqrt(widthScaleSquared * cos * cos + sin * sin);
        verticalScale = brush.rotation
            ? math.max(ratio, 1.0)
            : math.sqrt(widthScaleSquared * sin * sin + cos * cos);
      }
      final verticalRoom = _height / 2 - _waveAmplitude - 2;
      final scale = math.min(
        1.0,
        math.min(
          19.0 / math.max(brush.size, 1),
          (angle == null ? 16.0 : verticalRoom / verticalScale - 1) /
              math.max(extent, 1),
        ),
      );
      int scaledBlur(int original) => (original * scale).round().clamp(0, 100);
      final previewBrush = brush.copyWith(
        size: math.max(0.5, brush.size * scale),
        // Keep the gap-to-tip ratio when compressing large tips into the list.
        // Ratio-based tips already scale their spacing with size in the engine.
        spacing: math.max(1, (brush.spacing * scale).round()),
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
      final tiles = TileManager(canvasWidth: _width, canvasHeight: _height);
      try {
        final engine = DrawingEngine(tileManager: tiles)
          ..currentColor = brush.presetColor == null
              ? color
              : Color(brush.presetColor!)
          ..currentBrush = previewBrush
          // Simulate a stylus moving with variable pressure, so G pens,
          // pencils and user-configured pressure-sensitive brushes also
          // show their characteristic thickness and opacity.
          ..pressureEnabled = true;
        final inset = angle == null
            ? _waveInset
            : math.max(
                _waveInset,
                ((previewBrush.size / 2 + scaledBlur(maxBlur) + 0.5) *
                            horizontalScale)
                        .ceil() +
                    2,
              );
        final points = _wavePoints(inset);
        StrokePoint samplePoint(ui.Offset p, int index) {
          final t = index / (points.length - 1);
          return StrokePoint(
            x: p.dx,
            y: p.dy,
            inputType: InputType.stylus,
            pressure: 0.4 + 0.6 * math.sin(math.pi * t),
          );
        }

        engine.beginStroke(samplePoint(points.first, 0), 'preview');
        for (var i = 1; i < points.length; i++) {
          engine.continueStroke(samplePoint(points[i], i), 'preview');
        }
        if (engine.needsFinalFadeReplay) {
          engine.replayCurrentStrokeWithFinalFade();
        }
        engine.endStroke();
        return await tiles.compositeLayerToImage('preview');
      } finally {
        tiles.dispose();
      }
    }

    if (tone != null) {
      const textureSize = 64;
      await ensureToneTextureLoaded(tone, size: textureSize);
      final texture = generateBuiltInToneTexture(tone, size: textureSize);
      final result = ToneEngine().drawToneStroke(
        points: _wavePoints(),
        brushSize: 17,
        color: color,
        canvasData: Uint8List(_width * _height * 4),
        canvasWidth: _width,
        canvasHeight: _height,
        toneTexture: texture,
        toneWidth: textureSize,
        toneHeight: textureSize,
      );
      return _decode(result);
    }

    final activeStamp = stamp!;
    const stampSize = 23.0;
    final texture = await generateBuiltInStampTexture(
      activeStamp,
      size: 48,
      renderedSize: stampSize,
      color: color,
    );
    final result = StampEngine().stampAlongPath(
      canvasData: Uint8List(_width * _height * 4),
      width: _width,
      height: _height,
      texture: texture,
      texSize: 48,
      points: _wavePoints(),
      stampSize: stampSize,
      rotation: activeStamp.rotation,
      scatter: activeStamp.scatter * stampSize,
      density: activeStamp.density,
      // The source texture has already had its opacity applied.
      opacity: 100,
      premultiplied: true,
      seed: 0,
    );
    return _decode(result);
  }
}
