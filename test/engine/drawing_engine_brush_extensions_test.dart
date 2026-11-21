import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Brush brush({
    bool lateral = false,
    int count = 1,
    double lateralSpacing = 1,
    bool outline = false,
    double outlineWidth = 1.5,
    bool fold = false,
    double foldTriggerDepthRatio = 1,
    BrushTipShape tip = BrushTipShape.round,
    List<String> customImagePaths = const [],
    BrushImageSelectionMode customImageSelectionMode =
        BrushImageSelectionMode.random,
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
    foldEnabled: fold,
    foldTriggerDepthRatio: foldTriggerDepthRatio,
    yBranchAngle: 45,
    yBranchLengthRatio: 0.8,
    yBranchWidthRatio: 0.12,
    yBranchEndTaperRatio: 0.4,
    tipShape: tip,
    customImagePaths: customImagePaths,
    customImageSelectionMode: customImageSelectionMode,
  );

  DrawingEngine engineFor(
    Brush value, {
    Color color = const Color(0xFFFF0000),
  }) {
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

  test('drawing engine selects one sequential texture per stroke', () {
    final engine = engineFor(
      brush(
        customImagePaths: const ['a.png', 'b.png'],
        customImageSelectionMode: BrushImageSelectionMode.sequential,
      ),
    );
    const point = StrokePoint(x: 64, y: 64, pressure: 1, tiltX: 0, tiltY: 0);

    engine.beginStroke(point, 'layer');
    expect(engine.debugActiveBrushTexturePath, 'a.png');
    engine.continueStroke(
      const StrokePoint(x: 84, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
    expect(engine.debugActiveBrushTexturePath, 'a.png');
    engine.endStroke();
    expect(engine.debugActiveBrushTexturePath, isNull);

    engine.beginStroke(point, 'layer');
    expect(engine.debugActiveBrushTexturePath, 'b.png');
    engine.endStroke();
  });

  test('lateral repeat rasterizes symmetric normal-space columns', () {
    final engine = engineFor(brush(lateral: true, count: 3, lateralSpacing: 1));
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

  test('a single net stroke draws four connected rows of cells', () async {
    final net = brushExtensionPresets().singleWhere(
      (brush) => brush.id == 'Brush0022',
    );
    await preloadBrushTextures(
      net.resolvedCustomImagePaths,
      mode: net.imageInkMode,
    );

    for (final vertical in [false, true]) {
      final engine = engineFor(net.copyWith(size: 20, stabilization: false));
      Offset orient(Offset point) =>
          vertical ? Offset(point.dy, point.dx) : point;
      StrokePoint sample(Offset point) {
        final position = orient(point);
        return StrokePoint(x: position.dx, y: position.dy);
      }

      engine.beginStroke(sample(const Offset(32, 64)), 'layer');
      engine.continueStroke(sample(const Offset(105, 64)), 'layer');
      engine.endStroke();

      int alphaAt(double x, double y) {
        final position = orient(Offset(x, y));
        return pixel(engine, position.dx.round(), position.dy.round())[3];
      }

      for (final column in [32.0, 51.0, 70.0, 88.0]) {
        for (final row in [36.0, 55.0, 73.0, 92.0]) {
          expect(alphaAt(column, row), 0);
          expect(alphaAt(column + 9, row), greaterThan(0));
        }
        for (final crossing in [45.0, 64.0, 83.0]) {
          expect(alphaAt(column, crossing), greaterThan(0));
        }
      }
      engine.tileManager.dispose();
    }
  });

  test(
    'four-panel manga keeps a thin frame and scales the gap with brush size',
    () async {
      final preset = brushExtensionPresets().singleWhere(
        (b) => b.id == 'Brush0025',
      );
      await preloadBrushTextures(
        preset.resolvedCustomImagePaths,
        mode: preset.imageInkMode,
      );
      for (final size in [40.0, 80.0]) {
        final engine =
            DrawingEngine(
                tileManager: TileManager(canvasWidth: 256, canvasHeight: 256),
              )
              ..currentBrush = preset.copyWith(size: size, stabilization: false)
              ..currentColor = const Color(0xFF000000);

        engine.beginStroke(const StrokePoint(x: 64, y: 128), 'layer');
        engine.continueStroke(StrokePoint(x: 64 + 1.3 * size, y: 128), 'layer');
        engine.endStroke();

        final frameLeft = (64 - size * .47).round();
        final nextFrame = (64 + 1.15 * size).round();
        expect(pixel(engine, 64, 128)[3], 0);
        expect(pixel(engine, frameLeft, 128)[3], greaterThan(0));
        expect(pixel(engine, frameLeft + (size * .08).ceil(), 128)[3], 0);
        expect(pixel(engine, (64 + size * .55).round(), 128)[3], 0);
        expect(pixel(engine, nextFrame, 128)[3], 0);
        expect(
          pixel(engine, nextFrame, (128 - size * .47).round())[3],
          greaterThan(0),
        );
        expect(pixel(engine, 64, (128 - size).round())[3], 0);
      }
    },
  );

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

  test(
    'fold-enabled outlined stroke rasterizes inward Y branches at a sharp bend',
    () {
      final engine = engineFor(
        brush(
          outline: true,
          outlineWidth: 2,
          fold: true,
          foldTriggerDepthRatio: 0,
        ),
      );
      engine.beginStroke(
        const StrokePoint(x: 30, y: 50, pressure: 1, tiltX: 0, tiltY: 0),
        'layer',
        screenPosition: const Offset(30, 50),
      );
      engine.continueStroke(
        const StrokePoint(x: 50, y: 50, pressure: 1, tiltX: 0, tiltY: 0),
        'layer',
        screenPosition: const Offset(50, 50),
      );
      engine.continueStroke(
        const StrokePoint(x: 50, y: 70, pressure: 1, tiltX: 0, tiltY: 0),
        'layer',
        screenPosition: const Offset(50, 70),
      );
      engine.endStroke();

      var foldInk = 0;
      for (var y = 50; y <= 90; y++) {
        for (var x = 25; x <= 55; x++) {
          if (pixel(engine, x, y)[3] > 0) foldInk++;
        }
      }
      expect(foldInk, greaterThan(0));
    },
  );

  test('folds depend on the stroke, not on the display zoom', () {
    // Folds are judged from the document-space stroke relative to its own
    // width, so the same stroke folds identically at any zoom.
    List<int> render(double zoom) {
      final engine = engineFor(
        brush(
          outline: true,
          outlineWidth: 2,
          fold: true,
          foldTriggerDepthRatio: 0,
        ),
      );
      const path = [Offset(20, 20), Offset(70, 60), Offset(20, 100)];
      StrokePoint at(Offset p) =>
          StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0);
      engine.beginStroke(
        at(path.first),
        'layer',
        screenPosition: path.first * zoom,
      );
      for (var i = 1; i < path.length; i++) {
        for (var t = 1; t <= 40; t++) {
          final p = Offset.lerp(path[i - 1], path[i], t / 40)!;
          engine.continueStroke(at(p), 'layer', screenPosition: p * zoom);
        }
      }
      engine.endStroke();
      return engine.tileManager.getOrCreateTile('layer', 0, 0).toList();
    }

    expect(render(5), render(1));
  });
}
