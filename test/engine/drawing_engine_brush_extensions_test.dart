import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

void main() {
  Brush brush({
    bool lateral = false,
    int count = 1,
    double lateralSpacing = 1,
    bool outline = false,
    double outlineWidth = 1.5,
    BrushTipShape tip = BrushTipShape.round,
  }) => Brush(
    id: 'test',
    name: 'test',
    size: 20,
    opacity: 100,
    spacing: 20,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    fadeMode: FadeMode.off,
    strokeDecay: false,
    lateralRepeatEnabled: lateral,
    lateralRepeatCount: count,
    lateralRepeatSpacing: lateralSpacing,
    outlineEnabled: outline,
    outlineWidth: outlineWidth,
    outlineColor: 0xFF000000,
    tipShape: tip,
  );

  DrawingEngine engineFor(Brush value, {Color color = const Color(0xFFFF0000)}) {
    final engine = DrawingEngine(
      tileManager: TileManager(canvasWidth: 128, canvasHeight: 128),
    );
    engine.currentBrush = value;
    engine.currentColor = color;
    return engine;
  }

  List<int> pixel(DrawingEngine engine, int x, int y) {
    final tile = engine.tileManager.getOrCreateTile('layer', 0, 0);
    final index = (y * TileManager.tileSize + x) * 4;
    return tile.sublist(index, index + 4);
  }

  test('lateral repeat rasterizes symmetric normal-space columns', () {
    final engine = engineFor(
      brush(lateral: true, count: 3, lateralSpacing: 1),
    );
    engine.beginStroke(
      const StrokePoint(x: 64, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
    engine.continueStroke(
      const StrokePoint(x: 84, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
    engine.endStroke();

    expect(pixel(engine, 64, 44)[3], greaterThan(0));
    expect(pixel(engine, 64, 64)[3], greaterThan(0));
    expect(pixel(engine, 64, 84)[3], greaterThan(0));
  });

  test('hollow-square tip leaves the center transparent', () {
    final engine = engineFor(brush(tip: BrushTipShape.hollowSquare));
    engine.beginStroke(
      const StrokePoint(x: 64, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
    engine.endStroke();

    expect(pixel(engine, 64, 64)[3], 0);
    expect(pixel(engine, 56, 64)[3], greaterThan(0));
  });

  test('outline rasterizes black outside current-color fill', () {
    final engine = engineFor(brush(outline: true, outlineWidth: 3));
    engine.beginStroke(
      const StrokePoint(x: 64, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
    engine.endStroke();

    final fill = pixel(engine, 64, 64);
    final outline = pixel(engine, 75, 64);
    expect(fill, [255, 0, 0, 255]);
    expect(outline, [0, 0, 0, 255]);
  });
}
