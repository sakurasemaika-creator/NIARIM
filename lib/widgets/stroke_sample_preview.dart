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

/// A wave drawn by the same raster engines used by the canvas.
/// The strip is read-only: it never changes the user's project.
class StrokeSamplePreview extends StatefulWidget {
  const StrokeSamplePreview({
    super.key,
    this.brush,
    this.tone,
    this.stamp,
    required this.color,
    this.height = 38,
  }) : assert(
         (brush != null ? 1 : 0) +
                 (tone != null ? 1 : 0) +
                 (stamp != null ? 1 : 0) ==
             1,
       );

  final Brush? brush;
  final Tone? tone;
  final Stamp? stamp;
  final Color color;
  final double height;

  @override
  State<StrokeSamplePreview> createState() => _StrokeSamplePreviewState();
}

class _StrokeSamplePreviewState extends State<StrokeSamplePreview> {
  static const int _width = 240;
  static const int _height = 48;
  ui.Image? _sample;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(StrokeSamplePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brush != widget.brush ||
        oldWidget.tone != widget.tone ||
        oldWidget.stamp != widget.stamp ||
        oldWidget.color != widget.color) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _revision++;
    _sample?.dispose();
    super.dispose();
  }

  static List<ui.Offset> _wavePoints() => [
    for (var x = 12; x <= _width - 12; x += 2)
      ui.Offset(
        x.toDouble(),
        _height / 2 + 9 * math.sin((x - 12) / (_width - 24) * math.pi * 4),
      ),
  ];

  Future<ui.Image> _decode(Uint8List rgba) {
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

  Future<ui.Image> _render() async {
    final brush = widget.brush;
    final tone = widget.tone;
    final stamp = widget.stamp;
    final color = widget.color;

    if (brush != null) {
      await preloadBrushTextures(
        brush.resolvedCustomImagePaths,
        mode: brush.imageInkMode,
      );
      final tiles = TileManager(canvasWidth: _width, canvasHeight: _height);
      try {
        final engine = DrawingEngine(tileManager: tiles)
          ..currentColor = color
          ..currentBrush = brush.copyWith(
            // Fit larger brush sizes into the strip; preserve tip,
            // scattering, fade and stroke shape settings.
            size: brush.size.clamp(1.0, 19.0).toDouble(),
          )
          ..pressureEnabled = false;
        final points = _wavePoints();
        engine.beginStroke(
          StrokePoint(x: points.first.dx, y: points.first.dy),
          'preview',
        );
        for (final p in points.skip(1)) {
          engine.continueStroke(StrokePoint(x: p.dx, y: p.dy), 'preview');
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
    final texture = await generateBuiltInStampTexture(
      activeStamp,
      size: 48,
    );
    final result = StampEngine().stampAlongPath(
      canvasData: Uint8List(_width * _height * 4),
      width: _width,
      height: _height,
      texture: texture,
      texSize: 48,
      points: _wavePoints(),
      stampSize: 23,
      rotation: activeStamp.rotation,
      scatter: activeStamp.scatter,
      density: activeStamp.density,
      // The source texture has already had its opacity applied.
      opacity: 100,
      seed: 0,
    );
    return _decode(result);
  }

  Future<void> _refresh() async {
    final revision = ++_revision;
    try {
      final next = await _render();
      if (!mounted || revision != _revision) {
        next.dispose();
        return;
      }
      setState(() {
        _sample?.dispose();
        _sample = next;
      });
    } catch (_) {
      // An unreadable user texture must not break the tool list.
      if (mounted && revision == _revision) {
        setState(() {
          _sample?.dispose();
          _sample = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          key: ValueKey(
            widget.brush?.id ?? widget.tone?.id ?? widget.stamp?.id,
          ),
          height: widget.height,
          child: ColoredBox(
            color: scheme.surfaceContainerLow,
            child: _sample == null
                ? const SizedBox.expand()
                : RawImage(image: _sample, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
