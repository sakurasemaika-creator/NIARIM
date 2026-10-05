import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
