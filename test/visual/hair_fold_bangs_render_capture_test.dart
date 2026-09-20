import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/wave_hair_fold_geometry.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

Future<List<List<WaveFoldPathSample>>> _capture(Brush brush, String name) async {
  await preloadBrushTextures(brush.customImagePaths);
  for (final path in brush.customImagePaths) {
    expect(getCachedBrushTexture(path), isNotNull, reason: 'missing bangs texture: $path');
  }

  final tiles = TileManager(canvasWidth: 720, canvasHeight: 520);
  var foldEvents = 0;
  final foldPaths = <List<WaveFoldPathSample>>[];
  final engine = DrawingEngine(tileManager: tiles)
    ..debugOnHairFoldRendered = (path) {
      foldEvents++;
      foldPaths.add(path);
    }
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xFF202020);
  const layer = 'hair-fold-capture';

  for (var row = 0; row < 5; row++) {
    final y = 72.0 + row * 88.0;
    engine.beginStroke(
      StrokePoint(x: 70, y: y, pressure: .82, tiltX: 0, tiltY: 0),
      layer,
    );
    for (var step = 1; step <= 18; step++) {
      engine.continueStroke(
        StrokePoint(
          x: 70.0 + step * 10.0,
          y: y,
          pressure: .8,
          tiltX: 0,
          tiltY: 0,
        ),
        layer,
      );
    }
    for (var step = 1; step <= 18; step++) {
      engine.continueStroke(
        StrokePoint(
          x: 250.0 - step * 10.0,
          y: y + (row.isEven ? step * 2.0 : -step * 2.0),
          pressure: .8,
          tiltX: 0,
          tiltY: 0,
        ),
        layer,
      );
    }
    engine.endStroke();
  }

  expect(foldEvents, greaterThan(0), reason: 'capture did not render any fold');
  expect(foldPaths.every((path) => path.isNotEmpty), isTrue);
  expect(foldPaths.every((path) => path.last.distanceFromStart > 0), isTrue);

  final image = await tiles.compositeLayerToImage(layer);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(data, isNotNull);
  final out = File('build/hair_fold_visual/$name.png');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
  tiles.dispose();
  expect(await out.length(), greaterThan(1000));
  return foldPaths;
}

Future<void> _captureNaturalProductionPreset(Brush brush, String name) async {
  await preloadBrushTextures(brush.customImagePaths);
  for (final path in brush.customImagePaths) {
    expect(getCachedBrushTexture(path), isNotNull,
        reason: 'missing bangs texture: $path');
  }

  final tiles = TileManager(canvasWidth: 720, canvasHeight: 520);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xFF202020);
  const layer = 'hair-fold-production-preset-capture';

  for (var row = 0; row < 5; row++) {
    final y = 70.0 + row * 90.0;
    engine.beginStroke(
      StrokePoint(x: 72, y: y, pressure: .7, tiltX: 0, tiltY: 0),
      layer,
    );
    for (var step = 1; step <= 48; step++) {
      final t = step / 48.0;
      final x = 72.0 + step * 11.0;
      final curve = (row.isEven ? 1.0 : -1.0) *
          (20.0 * math.sin(t * math.pi) + 7.0 * math.sin(t * math.pi * 2));
      engine.continueStroke(
        StrokePoint(
          x: x,
          y: y + curve,
          pressure: .55 + .4 * math.sin(t * math.pi),
          tiltX: 0,
          tiltY: 0,
        ),
        layer,
      );
    }
    engine.endStroke();
  }

  final image = await tiles.compositeLayerToImage(layer);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(data, isNotNull);
  final out = File('build/hair_fold_visual/$name.png');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
  tiles.dispose();
  expect(await out.length(), greaterThan(1000));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('capture untouched production bangs preset with natural strokes', () async {
    final bangs = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0024');
    expect(bangs.stabilization, isTrue);
    expect(bangs.stabilizationStrength, 40);
    expect(bangs.foldEnabled, isTrue);
    expect(bangs.foldWaveEnabled, isFalse);

    await _captureNaturalProductionPreset(
      bangs,
      'bangs_production_preset_5strokes',
    );
  });

  test('capture production bangs fold modes from the same user curve', () async {
    final bangs = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0024');
    final modes = <HairFoldMode, String>{
      HairFoldMode.waveTopView: 'wave_top_view',
      HairFoldMode.waveLowAngle: 'wave_low_angle',
      HairFoldMode.curlRight: 'curl_right',
      HairFoldMode.curlLeft: 'curl_left',
      HairFoldMode.crescent: 'crescent',
    };
    for (final entry in modes.entries) {
      await _capture(
        bangs.copyWith(
          stabilization: false,
          stabilizationStrength: 0,
          foldTriggerAngle: 30,
          foldMode: entry.key,
        ),
        'bangs_\${entry.value}_same_curve',
      );
    }
  });
}
