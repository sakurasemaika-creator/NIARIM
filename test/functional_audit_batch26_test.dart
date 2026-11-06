import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('カメラキーフレーム0→10の中間frame=5はXY移動も50%補間して書き出す', () async {
    const dw = 64;
    const dh = 48;
    const ew = 32;
    const eh = 24;
    const sceneId = 'Scene0001';
    const layerId = 'Layer0001';

    final tm = TileManager(canvasWidth: dw, canvasHeight: dh);
    final src = Uint8List(dw * dh * 4);

    // 各座標をRGBから一意に追える不透明パターン。
    for (var y = 0; y < dh; y++) {
      for (var x = 0; x < dw; x++) {
        final i = (y * dw + x) * 4;
        src[i] = (x * 3 + y) & 0xff;
        src[i + 1] = (x + y * 5) & 0xff;
        src[i + 2] = (x * 7 + y * 11) & 0xff;
        src[i + 3] = 255;
      }
    }
    tm.replaceLayerPixels(frameLayerKey(sceneId, 5, layerId), src);
    const layer = Layer(id: layerId, name: 'L', type: LayerType.normal);

    final actual = await ExportEngine().renderFrame(
      layers: const [layer],
      tileManager: tm,
      sceneId: sceneId,
      frameIndex: 5,
      drawingWidth: dw,
      drawingHeight: dh,
      width: ew,
      height: eh,
      backgroundColor: 0x00000000,
      cameraKeyframes: const [
        CameraKeyframe(frameIndex: 0, x: 0, y: 0, zoom: 1, rotation: 0),
        CameraKeyframe(frameIndex: 10, x: 8, y: 6, zoom: 1, rotation: 0),
      ],
    );

    // frame=5ではx=4,y=3。中央クロップoffset=(16,12)に加え、
    // CameraEngineの正方向移動は参照元を右/下へずらすため(+4,+3)を加える。
    final expected = Uint8List(ew * eh * 4);
    for (var y = 0; y < eh; y++) {
      for (var x = 0; x < ew; x++) {
        final si = ((y + 15) * dw + (x + 20)) * 4;
        final di = (y * ew + x) * 4;
        expected.setRange(di, di + 4, src, si);
      }
    }

    expect(
      actual,
      orderedEquals(expected),
      reason: 'カメラXYがキーフレーム間で50%補間され、その中間値が書き出し全RGBAへ1pxずれなく反映されること',
    );
  });
}
