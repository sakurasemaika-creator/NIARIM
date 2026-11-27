import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/timeline_frame_renderer.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/layer.dart';

/// Where the output frame is the whole drawing, unmoved by the camera, on an
/// opaque or fully transparent background, the renderer hands over the
/// composited drawing instead of drawing it once more into the output
/// frame. The frame must be the same bytes either way, in every case the
/// shortcut takes and in the ones it leaves to the full path.
void _fill(
  TileManager tiles,
  String key,
  Random random, {
  bool sparse = false,
}) {
  for (var ty = 0; ty < tiles.tilesY; ty++) {
    for (var tx = 0; tx < tiles.tilesX; tx++) {
      final tile = tiles.getOrCreateTile(key, tx, ty);
      for (var i = 0; i < tile.length; i += 4) {
        if (sparse && random.nextInt(3) != 0) continue;
        final alpha = random.nextInt(256);
        tile[i] = random.nextInt(alpha + 1);
        tile[i + 1] = random.nextInt(alpha + 1);
        tile[i + 2] = random.nextInt(alpha + 1);
        tile[i + 3] = alpha;
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => TimelineFrameRenderer.debugAlwaysDrawViewport = false);

  test('the frame is the same with and without the copy shortcut', () async {
    final random = Random(1127);
    for (final (width, height) in [(300, 200), (301, 199)]) {
      final tiles = TileManager(canvasWidth: width, canvasHeight: height);
      addTearDown(tiles.dispose);
      String key(String id) => frameLayerKey('S', 0, id);
      _fill(tiles, key('Ink'), random, sparse: true);
      _fill(tiles, key('Shade'), random, sparse: true);
      _fill(tiles, key('Glow'), random, sparse: true);
      const layers = [
        Layer(id: 'Ink', name: 'Ink', type: LayerType.normal),
        Layer(
          id: 'Shade',
          name: 'Shade',
          type: LayerType.normal,
          opacity: 60,
          blendMode: LayerBlendMode.multiply,
        ),
        // Blended on the CPU.
        Layer(
          id: 'Glow',
          name: 'Glow',
          type: LayerType.normal,
          blendMode: LayerBlendMode.subtract,
        ),
      ];
      final cameras = <List<CameraKeyframe>>[
        const [],
        const [CameraKeyframe(frameIndex: 0)],
        const [CameraKeyframe(frameIndex: 0, zoom: 0)],
        // Not a copy: the full path in both runs.
        const [CameraKeyframe(frameIndex: 0, x: 3, zoom: 1.5, rotation: 7)],
      ];
      for (final background in [
        0xFFFFFFFF,
        0xFF102030,
        0x00000000,
        0x00FF8040,
        0x80FFFFFF,
      ]) {
        for (final camera in cameras) {
          for (final output in [(width, height), (width - 40, height - 20)]) {
            Future<Uint8List> render(bool alwaysDraw) {
              TimelineFrameRenderer.debugAlwaysDrawViewport = alwaysDraw;
              return TimelineFrameRenderer().renderRgba(
                TimelineFrameRequest(
                  tileManager: tiles,
                  layers: layers,
                  keyOf: (l) => key(l.id),
                  frameIndex: 0,
                  drawingWidth: width,
                  drawingHeight: height,
                  outputWidth: output.$1,
                  outputHeight: output.$2,
                  backgroundColor: background,
                  cameraKeyframes: camera,
                ),
              );
            }

            final full = await render(true);
            final shortcut = await render(false);
            expect(
              shortcut,
              full,
              reason:
                  '${width}x$height → ${output.$1}x${output.$2}, '
                  'background ${background.toRadixString(16)}, camera $camera',
            );
          }
        }
      }
    }
  });
}
