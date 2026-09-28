import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/ruler_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush_presets_extension.dart';
import 'package:niarim/models/ruler.dart';

void main() {
  List<int> pixel(DrawingEngine engine, int x, int y) {
    final tile = engine.tileManager.getOrCreateTile('layer', 0, 0);
    final index = (y * TileManager.tileSize + x) * 4;
    return tile.sublist(index, index + 4);
  }

  test('four-panel preset follows a snapped straight-ruler path', () {
    final preset =
        brushExtensionPresets().singleWhere((b) => b.id == 'Brush0025');
    final ruler = RulerEngine()
      ..setActiveRuler(
        const Ruler(
          type: RulerType.line,
          position: Offset(0, 128),
          rotation: 0,
          snapEnabled: true,
          settings: RulerSettings(),
        ),
      )
      ..beginStroke();
    final engine = DrawingEngine(
      tileManager: TileManager(canvasWidth: 512, canvasHeight: 256),
    )
      ..currentBrush = preset
      ..currentColor = const Color(0xFF000000);

    Offset snapped(double x, double y) => ruler.snapToRuler(Offset(x, y));
    final start = snapped(80, 92);
    engine.beginStroke(
      StrokePoint(
        x: start.dx,
        y: start.dy,
        pressure: 1,
        tiltX: 0,
        tiltY: 0,
      ),
      'layer',
    );
    for (var x = 100.0; x <= 420; x += 20) {
      final p = snapped(x, x.isEven ? 170 : 90);
      expect(p.dy, 128);
      engine.continueStroke(
        StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0),
        'layer',
      );
    }
    engine.endStroke();

    // The first frame is centered on the ruler and stays hollow.
    expect(pixel(engine, 80, 128)[3], 0);
    expect(pixel(engine, 40, 128)[3], greaterThan(0));

    // No parallel row is created away from the straight ruler.
    expect(pixel(engine, 80, 48)[3], 0);
    expect(pixel(engine, 80, 208)[3], 0);

    // Subsequent frame ink remains distributed along the ruler direction.
    var ink = 0;
    for (var y = 88; y <= 168; y++) {
      for (var x = 160; x <= 420; x++) {
        if (pixel(engine, x, y)[3] > 0) ink++;
      }
    }
    expect(ink, greaterThan(0));
  });
}
