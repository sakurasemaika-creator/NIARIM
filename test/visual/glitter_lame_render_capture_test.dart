import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const _glitter = Brush(
  id: 'Brush0016', name: 'グリッターペン', size: 12, opacity: 90,
  spacing: 8, blurRadius: 6, stabilization: false,
  stabilizationStrength: 0, pixelMode: false,
  pressureMode: PressureMode.opacity, pressureStrength: 35,
  fadeMode: FadeMode.off, strokeDecay: false,
  mixingMode: BrushMixingMode.off, mixingRate: 0,
  density: 1.7, scatter: 0.85, edgeJitter: true, edgeJitterStrength: 55,
);

const _lame = Brush(
  id: 'Brush0017', name: 'ラメペン', size: 5, opacity: 76,
  spacing: 4, blurRadius: 1, stabilization: true,
  stabilizationStrength: 20, pixelMode: false,
  pressureMode: PressureMode.opacity, pressureStrength: 25,
  fadeMode: FadeMode.off, strokeDecay: false,
  mixingMode: BrushMixingMode.off, mixingRate: 0,
  density: 2.8, scatter: 0.45, edgeJitter: true, edgeJitterStrength: 30,
);

Future<void> _capture(Brush brush, String name) async {
  final tiles = TileManager(canvasWidth: 640, canvasHeight: 360);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xFF202020);
  const layer = 'capture-layer';

  for (var row = 0; row < 4; row++) {
    final y = 72.0 + row * 72.0;
    engine.beginStroke(
      StrokePoint(x: 55, y: y, pressure: 1, tiltX: 0, tiltY: 0), layer);
    for (var x = 65.0; x <= 585; x += 10) {
      final wave = row.isEven ? 10.0 : 5.0;
      engine.continueStroke(
        StrokePoint(
          x: x, y: y + wave * math.sin(x / 45.0),
          pressure: 1, tiltX: 0, tiltY: 0),
        layer,
      );
    }
    engine.endStroke();
  }

  final image = await tiles.compositeLayerToImage(layer);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(data, isNotNull);
  final out = File('build/glitter_visual/$name.png');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
  tiles.dispose();
  expect(await out.length(), greaterThan(1000));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('capture actual DrawingEngine output for glitter and lame presets', () async {
    await _capture(_glitter, 'glitter_pen_actual');
    await _capture(_lame, 'lame_pen_actual');
  });
}
