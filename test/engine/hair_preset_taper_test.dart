import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('five ribbon presets ignore changes in stylus pressure', () async {
    for (final ribbon in brushExtensionPresets().where(
      (brush) => brush.name.startsWith('リボン'),
    )) {
      Future<List<int>> draw(bool varyPressure) async {
        final tiles = TileManager(canvasWidth: 240, canvasHeight: 160);
        final engine = DrawingEngine(tileManager: tiles)
          ..pressureEnabled = true
          ..currentBrush = ribbon
          ..currentColor = ui.Color(ribbon.presetColor!);
        final points = [
          for (var i = 0; i <= 40; i++)
            StrokePoint(
              x: 20.0 + i * 5,
              y: 50.0 + (i - 20).abs() * 3,
              pressure: varyPressure ? .15 + (i % 5) * .15 : 1,
            ),
        ];
        engine.beginStroke(points.first, 'ribbon');
        for (final point in points.skip(1)) {
          engine.continueStroke(point, 'ribbon');
        }
        engine.endStroke();
        final image = await tiles.compositeLayerToImage('ribbon');
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          return data!.buffer.asUint8List();
        } finally {
          image.dispose();
          tiles.dispose();
        }
      }

      final steady = await draw(false);
      expect(steady.any((byte) => byte > 0), isTrue, reason: ribbon.name);
      expect(await draw(true), steady, reason: ribbon.name);
    }
  });
  test('ribbon ends come from its PNG with folding on or off', () async {
    final presets = brushExtensionPresets().where(
      (brush) => brush.name.startsWith('リボン'),
    );
    for (final preset in presets) {
      await preloadBrushTextures(
        preset.resolvedCustomImagePaths,
        mode: preset.imageInkMode,
      );
      Future<List<int>> draw(bool fold) async {
        final tiles = TileManager(canvasWidth: 120, canvasHeight: 70);
        final engine = DrawingEngine(tileManager: tiles)
          ..currentBrush = preset.copyWith(
            stabilization: false,
            foldEnabled: fold,
          )
          ..currentColor = ui.Color(preset.presetColor!);
        engine.beginStroke(const StrokePoint(x: 20, y: 35), 'ribbon');
        engine.continueStroke(const StrokePoint(x: 100, y: 35), 'ribbon');
        engine.endStroke();
        final image = await tiles.compositeLayerToImage('ribbon');
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        tiles.dispose();
        return bytes;
      }

      final folded = await draw(true);
      expect(folded, orderedEquals(await draw(false)), reason: preset.name);
      int alpha(int x, int y) => folded[(y * 120 + x) * 4 + 3];
      expect(alpha(18, 35), greaterThan(0), reason: preset.name);
      expect(alpha(101, 35), greaterThan(0), reason: preset.name);
      expect(alpha(95, 43), 255, reason: preset.name);
    }
  });
  for (final id in ['Brush0023']) {
    for (final multiplier in [1.0, 2.0]) {
      for (final mode in <HairFoldMode?>[
        null,
        HairFoldMode.waveTopView,
        HairFoldMode.crescent,
      ]) {
        test(
          '$id ${mode?.name ?? "straight"} tapers to the minimum exit at size multiplier $multiplier after restore',
          () async {
            final preset = brushExtensionPresets().singleWhere(
              (b) => b.id == id,
            );
            final brush = Brush.fromJson(
              preset
                  .copyWith(
                    size: preset.size * multiplier,
                    stabilization: false,
                    foldMode: mode,
                    foldTriggerAngle: 30,
                    customImageSelectionMode:
                        BrushImageSelectionMode.sequential,
                  )
                  .toJson(),
            );
            await preloadBrushTextures(
              brush.resolvedCustomImagePaths,
              mode: brush.imageInkMode,
            );
            final tiles = TileManager(canvasWidth: 220, canvasHeight: 450);
            addTearDown(tiles.dispose);
            final engine = DrawingEngine(tileManager: tiles)
              ..pressureEnabled = false
              ..currentColor = const ui.Color(0xffffffff)
              ..currentBrush = brush;
            StrokePoint point(ui.Offset p) =>
                StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0);
            final path = <ui.Offset>[
              const ui.Offset(100.5, 40.5),
              if (mode != null) ...[
                const ui.Offset(100.5, 120.5),
                const ui.Offset(180.5, 200.5),
                const ui.Offset(100.5, 280.5),
              ],
              const ui.Offset(100.5, 400.5),
            ];
            tiles.beginUndoRecording('hair');
            engine.beginStroke(
              point(path.first),
              'hair',
              screenPosition: path.first * .5,
            );
            for (var i = 1; i < path.length; i++) {
              final steps = ((path[i] - path[i - 1]).distance / 2).ceil();
              for (var step = 1; step <= steps; step++) {
                final p = ui.Offset.lerp(path[i - 1], path[i], step / steps)!;
                engine.continueStroke(point(p), 'hair', screenPosition: p * .5);
              }
            }
            if (engine.needsFinalFadeReplay) {
              final preview = tiles.endUndoRecording();
              tiles.applyTileSnapshot('hair', preview.before);
              tiles.beginUndoRecording('hair');
              engine.replayCurrentStrokeWithFinalFade();
            }
            engine.endStroke();
            tiles.endUndoRecording();
            final image = await tiles.compositeLayerToImage('hair');
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            image.dispose();
            int alpha(int x, int y) => data[(y * 220 + x) * 4 + 3];
            // The taper narrows the outline pen to a point without fading
            // it, so the end pixel holds only that point's anti-aliasing.
            expect(
              alpha(100, 400),
              lessThan(64),
              reason: '0% exit reaches the minimum at the actual stroke end',
            );
            final visible = [
              for (var x = 50; x <= 150; x++)
                if (alpha(x, 400) > 127) x,
            ];
            expect(
              visible.length,
              lessThanOrEqualTo(1),
              reason: 'the minimum exit must not leave a thick cap',
            );
            expect(alpha(100, 50), greaterThan(240));
          },
        );
      }
    }
  }
}
