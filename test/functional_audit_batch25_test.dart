import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('カメラzoom=2は中央の実画素矩形を書き出し上で正確に2倍へ拡大する', () async {
    const dw = 64;
    const dh = 48;
    const ew = 32;
    const eh = 24;
    const sceneId = 'Scene0001';
    const layerId = 'Layer0001';

    final tm = TileManager(canvasWidth: dw, canvasHeight: dh);
    final src = Uint8List(dw * dh * 4);

    // 描画領域中央(32,24)を中心に、8x6の不透明矩形を置く。
    // 中央クロップ後は同じ8x6、camera zoom=2なら中心を保ったまま16x12になる。
    for (var y = 21; y < 27; y++) {
      for (var x = 28; x < 36; x++) {
        final i = (y * dw + x) * 4;
        src[i] = 37;
        src[i + 1] = 149;
        src[i + 2] = 231;
        src[i + 3] = 255;
      }
    }
    tm.replaceLayerPixels(frameLayerKey(sceneId, 0, layerId), src);
    const layer = Layer(id: layerId, name: 'L', type: LayerType.normal);

    final actual = await ExportEngine().renderFrame(
      layers: const [layer],
      tileManager: tm,
      sceneId: sceneId,
      frameIndex: 0,
      drawingWidth: dw,
      drawingHeight: dh,
      width: ew,
      height: eh,
      backgroundColor: 0x00000000,
      cameraKeyframes: const [
        CameraKeyframe(frameIndex: 0, x: 0, y: 0, zoom: 2, rotation: 0),
      ],
    );

    var minX = ew;
    var minY = eh;
    var maxX = -1;
    var maxY = -1;
    var opaque = 0;
    for (var y = 0; y < eh; y++) {
      for (var x = 0; x < ew; x++) {
        final i = (y * ew + x) * 4;
        if (actual[i + 3] == 0) continue;
        opaque++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        expect(actual[i], 37);
        expect(actual[i + 1], 149);
        expect(actual[i + 2], 231);
        expect(actual[i + 3], 255);
      }
    }

    expect(opaque, 16 * 12, reason: '8x6の元矩形がzoom=2で16x12=192画素へ拡大されること');
    expect(minX, 8);
    expect(maxX, 23);
    expect(minY, 6);
    expect(maxY, 17);
  });
}
