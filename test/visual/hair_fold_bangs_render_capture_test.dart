import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

Future<void> _capture(Brush brush, String name) async {
  await preloadBrushTextures(brush.customImagePaths);
  for (final path in brush.customImagePaths) {
    expect(getCachedBrushTexture(path), isNotNull, reason: 'missing bangs texture: $path');
  }

  final tiles = TileManager(canvasWidth: 720, canvasHeight: 520);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xFF202020);
  const layer = 'hair-fold-capture';

  for (var row = 0; row < 5; row++) {
    final y = 72.0 + row * 88.0;
    engine.beginStroke(
      StrokePoint(x: 70, y: y, pressure: .82, tiltX: 0, tiltY: 0),
      layer,
    );
    for (var step = 1; step <= 24; step++) {
      final phase = step / 24.0;
      final x = 70.0 + step * 10.0;
      final pressure = .55 + .4 * math.sin(phase * math.pi);
      engine.continueStroke(
        StrokePoint(x: x, y: y, pressure: pressure, tiltX: 0, tiltY: 0),
        layer,
      );
    }
    for (var step = 1; step <= 22; step++) {
      final phase = step / 22.0;
      final x = 310.0 + step * 10.5;
      final drop = (row.isEven ? 1.0 : -1.0) * step * 4.8;
      engine.continueStroke(
        StrokePoint(
          x: x,
          y: y + drop,
          pressure: .9 - .3 * phase,
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

  test('capture production bangs straight and wave fold strokes', () async {
    final bangs = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0024');
    expect(bangs.customImagePaths.length, 5);

    await _capture(
      bangs.copyWith(
        foldWaveEnabled: false,
        foldCurveStrength: 5,
      ),
      'bangs_straight_5strokes',
    );
    await _capture(
      bangs.copyWith(
        foldWaveEnabled: true,
        foldWaveEndRatio: .45,
        foldWaveTriggerAngle: 20,
        foldCurveStrength: 5,
      ),
      'bangs_wave_5strokes',
    );
  });
}
