// 書き出し（ExportEngine.renderFrame）もシーンの重なり順とフレーム
// （イラスト）のマスクに従うこと：テキスト1とテキスト2の間にイラストを
// 挟める、イラストをマスクすると後ろのテキストが見える、素材は表示範囲の
// フレームにだけ出る。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/models/scene_stack.dart';

const _size = 40;

Uint8List _solid(int r, int g, int b) {
  final data = Uint8List(_size * _size * 4);
  for (var i = 0; i < data.length; i += 4) {
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = 255;
  }
  return data;
}

Layer _text(String id, int row, {int start = 1, int end = 3}) => Layer(
  id: id,
  name: id,
  type: LayerType.timelineText,
  trackRow: row,
  rangeMode: LayerRangeMode.frameRange,
  rangeStart: start,
  rangeEnd: end,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the export follows the stacking order and the frame mask', (
    tester,
  ) async {
    final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
    String key(String id) => frameLayerKey('s', 0, id);
    tiles.replaceLayerPixels(key('t1'), _solid(255, 0, 0));
    tiles.replaceLayerPixels(key('drawing'), _solid(0, 255, 0));
    tiles.replaceLayerPixels(key('t2'), _solid(0, 0, 255));
    tiles.replaceLayerPixels(key('late'), _solid(255, 255, 0));
    const drawing = Layer(id: 'drawing', name: 'd', type: LayerType.normal);
    final layers = [
      _text('t2', 1),
      drawing,
      _text('t1', 0),
      _text('late', 2, start: 3, end: 3),
    ];

    Future<List<int>> pixel(Scene scene, int x, int y, {int frame = 0}) async {
      final rgba = (await tester.runAsync(
        () => ExportEngine().renderFrame(
          layers: layers,
          tileManager: tiles,
          sceneId: 's',
          frameIndex: frame,
          drawingWidth: _size,
          drawingHeight: _size,
          width: _size,
          height: _size,
          backgroundColor: 0xFFFFFFFF,
          // Every layer's pixels live in frame 0 (the materials' home).
          layerHomes: {
            for (final l in layers) l.id: (sceneId: 's', frameIndex: 0),
          },
          scene: scene,
        ),
      ))!;
      final i = (y * _size + x) * 4;
      return [rgba[i], rgba[i + 1], rgba[i + 2]];
    }

    // Default: text 1 in front.
    expect(await pixel(const Scene(id: 's', index: 0), 20, 20), [255, 0, 0]);

    // The drawing in front of text 2 but behind text 1, and text 1 moved
    // behind it from a frame on.
    final between = Scene(
      id: 's',
      index: 0,
      stack: SceneStack(
        order: [
          kStackFrame,
          stackTrackKey(StackTrackKind.text, 0),
          stackTrackKey(StackTrackKind.text, 1),
        ],
      ),
    );
    expect(await pixel(between, 20, 20), [0, 255, 0]);

    // Masking the drawing to a small ellipse shows text 1 behind it at the
    // corner, and the drawing still in the middle.
    final masked = between.copyWith(
      stack: between.stack.copyWith(
        frameMask: const LayerMask(
          shape: LayerMaskShape.ellipse,
          width: 40,
          height: 40,
        ),
      ),
    );
    expect(await pixel(masked, 20, 20), [0, 255, 0]);
    expect(await pixel(masked, 2, 2), [255, 0, 0]);

    // A material only shows within its frames (F3 here, frame index 2):
    // text 3 in front of everything there, the drawing in front elsewhere.
    final lateFirst = Scene(
      id: 's',
      index: 0,
      stack: SceneStack(
        order: [
          stackTrackKey(StackTrackKind.text, 2),
          kStackFrame,
          stackTrackKey(StackTrackKind.text, 0),
          stackTrackKey(StackTrackKind.text, 1),
        ],
      ),
    );
    expect(await pixel(lateFirst, 20, 20), [0, 255, 0]);
    expect(await pixel(lateFirst, 20, 20, frame: 2), [255, 255, 0]);
  });
}
