// タイムラインのプレビューの演出フィルターは画面の処理の外でかける（作品
// づくりで見つかったU66：墨溜まり・VHS等が今のフレームにかかっていると、値を
// 変えるたびの描き直しで入力が数秒止まり、押した所がずれた）。かかる演出
// フィルターが無いフレームは、合成した絵をそのまま出す。どちらも、書き出しと
// 同じ絵（1バイトも違わない）でなければならない。
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart' show EffectFilterType;
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/timeline_frame_renderer.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the preview shows the export’s frame, with or without effects',
    () async {
      const width = 160;
      const height = 96;
      final tiles = TileManager(canvasWidth: width, canvasHeight: height);
      addTearDown(tiles.dispose);
      final random = Random(66);
      const layer = Layer(id: 'Ink', name: 'Ink', type: LayerType.normal);
      for (var frame = 0; frame < 3; frame++) {
        for (var ty = 0; ty < tiles.tilesY; ty++) {
          for (var tx = 0; tx < tiles.tilesX; tx++) {
            final tile = tiles.getOrCreateTile(
              frameLayerKey('S', frame, layer.id),
              tx,
              ty,
            );
            for (var i = 0; i < tile.length; i += 4) {
              final alpha = random.nextInt(256);
              tile[i] = random.nextInt(alpha + 1);
              tile[i + 1] = random.nextInt(alpha + 1);
              tile[i + 2] = random.nextInt(alpha + 1);
              tile[i + 3] = alpha;
            }
          }
        }
      }
      // Frame 0: sepia then a blur; frame 1: only a turned-off effect and one
      // that ends before it; frame 2: none listed at all.
      const effects = [
        EffectFilterInstance(
          id: 'sepia',
          type: EffectFilterType.sepia,
          startFrame: 0,
          endFrame: 0,
        ),
        EffectFilterInstance(
          id: 'blur',
          type: EffectFilterType.gaussianBlur,
          startFrame: 0,
          endFrame: 0,
          param1: 6,
        ),
        EffectFilterInstance(
          id: 'off',
          type: EffectFilterType.mosaic,
          startFrame: 1,
          endFrame: 1,
          enabled: false,
        ),
      ];
      final renderer = TimelineFrameRenderer();
      TimelineFrameRequest request(int frame, List<EffectFilterInstance> e) =>
          TimelineFrameRequest(
            tileManager: tiles,
            layers: const [layer],
            keyOf: (l) => frameLayerKey('S', frame, l.id),
            frameIndex: frame,
            drawingWidth: width,
            drawingHeight: height,
            outputWidth: width,
            outputHeight: height,
            backgroundColor: 0xFFFFFFFF,
            effectFilters: e,
          );
      Future<Uint8List> previewBytes(TimelineFrameRequest r) async {
        final image = await renderer.renderImage(r);
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          return data!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      }

      for (final (frame, list) in [
        (0, effects),
        (1, effects),
        (2, const <EffectFilterInstance>[]),
      ]) {
        final exported = await renderer.renderRgba(request(frame, list));
        final shown = await previewBytes(request(frame, list));
        expect(shown, exported, reason: 'frame $frame');
      }
      // The effects did change frame 0.
      final plain = await renderer.renderRgba(request(0, const []));
      final filtered = await renderer.renderRgba(request(0, effects));
      expect(plain, isNot(filtered));
    },
  );
}
