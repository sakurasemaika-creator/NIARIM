import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_pressure_resolver.dart';
import 'package:niarim/services/brush_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Every installed brush has a distinct preset ID and a valid tip', () {
    final presets = BrushService.builtInBrushes;
    expect(presets.length, greaterThan(18));
    expect(presets.map((b) => b.id).toSet().length, presets.length);
    for (final preset in presets) {
      expect(preset.name.trim(), isNotEmpty, reason: preset.id);
      expect(preset.size, greaterThan(0), reason: preset.name);
      expect(preset.opacity, inInclusiveRange(1, 100), reason: preset.name);
    }
  });

  test('Named soft presets actually enable the softness raster parameter', () {
    final presets = {for (final b in BrushService.builtInBrushes) b.id: b};
    for (final (id, blur) in <(String, int)>[
      ('Brush0003', 50), // Airbrush.
      ('Brush0004', 10), // Color-mixing brush.
      ('Brush0010', 30), // Watercolor.
      ('Brush0011', 90), // Soft blur brush.
      ('Brush0013', 20), // Spray.
    ]) {
      final brush = presets[id]!;
      expect(brush.pressureOff.blur.enabled, isTrue, reason: brush.name);
      final off = resolveBrushPressure(
        brush: brush,
        pressureEnabled: false,
        curvedPressure: 1,
      );
      final on = resolveBrushPressure(
        brush: brush,
        pressureEnabled: true,
        curvedPressure: 1,
      );
      expect(off.blur, blur, reason: brush.name);
      expect(on.blur, blur, reason: brush.name);
    }
    expect(presets['Brush0014']!.pixelMode, isTrue);
    expect(presets['Brush0014']!.pressureOff.blur.enabled, isFalse);
    expect(presets['Brush0001']!.pressureOff.blur.enabled, isFalse);
    expect(presets['Brush0012']!.scatter, greaterThan(0));
    expect(presets['Brush0013']!.scatter, greaterThan(0));
  });

  testWidgets('Airbrush paints a graded feathered halo, not a hard disc', (
    tester,
  ) async {
    final presets = {for (final b in BrushService.builtInBrushes) b.id: b};
    Future<Uint8List> paint(Brush brush) async {
      final tiles = TileManager(canvasWidth: 132, canvasHeight: 132);
      try {
        final engine = DrawingEngine(tileManager: tiles)
          ..currentColor = Colors.black
          ..currentBrush = brush
          ..pressureEnabled = false;
        engine.beginStroke(const StrokePoint(x: 66, y: 66), 'layer');
        engine.endStroke();
        final image = await tiles.compositeLayerToImage('layer');
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List();
      } finally {
        tiles.dispose();
      }
    }

    final samples = await tester.runAsync(
      () async => [
        await paint(presets['Brush0003']!),
        await paint(presets['Brush0001']!.copyWith(size: 30, opacity: 40)),
      ],
    );
    expect(samples, isNotNull);
    final airbrush = samples![0];
    final pen = samples[1];
    int alpha(Uint8List pixels, int distance) =>
        pixels[((66 * 132) + 66 + distance) * 4 + 3];
    expect(alpha(airbrush, 0), greaterThan(alpha(airbrush, 15)));
    expect(alpha(airbrush, 15), greaterThan(alpha(airbrush, 45)));
    expect(alpha(airbrush, 45), greaterThan(0));
    expect(alpha(airbrush, 45), lessThan(90));
    expect(alpha(pen, 45), 0);
  });
}
