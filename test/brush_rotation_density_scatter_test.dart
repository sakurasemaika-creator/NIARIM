import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

Brush _brush({
  double size = 4,
  int spacing = 20,
  bool rotation = false,
  double density = 1.0,
  double scatter = 0.0,
  double? calligraphyAngle,
}) {
  return Brush(
    id: 'test',
    name: 'test',
    size: size,
    opacity: 100,
    spacing: spacing,
    blurRadius: 0,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    pressureMode: PressureMode.off,
    pressureStrength: 0,
    fadeMode: FadeMode.off,
    strokeDecay: false,
    mixingMode: BrushMixingMode.off,
    mixingRate: 0,
    rotation: rotation,
    density: density,
    scatter: scatter,
    calligraphyAngle: calligraphyAngle,
  );
}

Uint8List _tileBytes(TileManager manager, String layer) {
  final tile = manager.getTile(layer, 0, 0);
  return tile == null
      ? Uint8List(TileManager.tileSize * TileManager.tileSize * 4)
      : Uint8List.fromList(tile);
}

int _paintedPixelCount(Uint8List bytes) {
  var count = 0;
  for (int i = 3; i < bytes.length; i += 4) {
    if (bytes[i] != 0) count++;
  }
  return count;
}

({int minX, int maxX, int minY, int maxY}) _bounds(Uint8List bytes) {
  var minX = TileManager.tileSize;
  var minY = TileManager.tileSize;
  var maxX = -1;
  var maxY = -1;
  for (int y = 0; y < TileManager.tileSize; y++) {
    for (int x = 0; x < TileManager.tileSize; x++) {
      final alpha = bytes[(y * TileManager.tileSize + x) * 4 + 3];
      if (alpha == 0) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
}

Uint8List _drawLine(Brush brush, List<StrokePoint> points) {
  final manager = TileManager(canvasWidth: 256, canvasHeight: 256);
  final engine = DrawingEngine(tileManager: manager)..currentBrush = brush;
  const layer = 'layer';
  engine.beginStroke(points.first, layer);
  for (final p in points.skip(1)) {
    engine.continueStroke(p, layer);
  }
  engine.endStroke();
  return _tileBytes(manager, layer);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Brush JSON round-trips rotation density and scatter with old-data defaults',
    () {
      final brush = _brush(rotation: true, density: 2.4, scatter: 0.35);
      final restored = Brush.fromJson(brush.toJson());
      expect(restored.rotation, true);
      expect(restored.density, 2.4);
      expect(restored.scatter, 0.35);

      final legacy = Map<String, dynamic>.from(brush.toJson())
        ..remove('rotation')
        ..remove('density')
        ..remove('scatter');
      final legacyRestored = Brush.fromJson(legacy);
      expect(legacyRestored.rotation, false);
      expect(legacyRestored.density, 1.0);
      expect(legacyRestored.scatter, 0.0);
    },
  );

  test('higher brush density creates more separated stamp coverage', () {
    final normal = _drawLine(_brush(size: 2, spacing: 20, density: 1.0), const [
      StrokePoint(x: 10, y: 100),
      StrokePoint(x: 210, y: 100),
    ]);
    final dense = _drawLine(_brush(size: 2, spacing: 20, density: 2.0), const [
      StrokePoint(x: 10, y: 100),
      StrokePoint(x: 210, y: 100),
    ]);
    expect(_paintedPixelCount(dense), greaterThan(_paintedPixelCount(normal)));
  });

  test('brush sampling is invariant to input move-event density', () {
    final brush = _brush(size: 5, spacing: 17, density: 1.7, scatter: 0.45);
    final sparse = _drawLine(brush, const [
      StrokePoint(x: 10, y: 100),
      StrokePoint(x: 210, y: 100),
    ]);
    final densePoints = <StrokePoint>[
      for (int x = 10; x <= 210; x += 10) StrokePoint(x: x.toDouble(), y: 100),
    ];
    final dense = _drawLine(brush, densePoints);
    expect(dense, orderedEquals(sparse));
  });

  test('scatter moves brush stamps away from the path normal direction', () {
    final straight = _drawLine(
      _brush(size: 8, spacing: 20, scatter: 0.0),
      const [StrokePoint(x: 20, y: 100), StrokePoint(x: 220, y: 100)],
    );
    final scattered = _drawLine(
      _brush(size: 8, spacing: 20, scatter: 1.0),
      const [StrokePoint(x: 20, y: 100), StrokePoint(x: 220, y: 100)],
    );
    final straightBounds = _bounds(straight);
    final scatterBounds = _bounds(scattered);
    final straightHeight = straightBounds.maxY - straightBounds.minY;
    final scatterHeight = scatterBounds.maxY - scatterBounds.minY;
    expect(scatterHeight, greaterThan(straightHeight));
  });

  test('rotation follows path direction for a flat brush tip', () {
    final fixed = _drawLine(
      _brush(size: 20, spacing: 100, calligraphyAngle: 0, rotation: false),
      const [StrokePoint(x: 100, y: 100), StrokePoint(x: 100, y: 110)],
    );
    final rotating = _drawLine(
      _brush(size: 20, spacing: 100, calligraphyAngle: 0, rotation: true),
      const [StrokePoint(x: 100, y: 100), StrokePoint(x: 100, y: 110)],
    );
    final fixedBounds = _bounds(fixed);
    final rotatingBounds = _bounds(rotating);
    final fixedWidth = fixedBounds.maxX - fixedBounds.minX;
    final fixedHeight = fixedBounds.maxY - fixedBounds.minY;
    final rotatingWidth = rotatingBounds.maxX - rotatingBounds.minX;
    final rotatingHeight = rotatingBounds.maxY - rotatingBounds.minY;
    expect(fixedWidth, greaterThan(fixedHeight));
    expect(rotatingHeight, greaterThan(rotatingWidth));
  });
}
