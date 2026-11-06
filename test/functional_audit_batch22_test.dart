import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('拡張描画領域64x48から書き出し32x24を中央クロップし全画素一致する', () async {
    const dw = 64;
    const dh = 48;
    const ew = 32;
    const eh = 24;
    const sceneId = 'Scene0001';
    const layerId = 'Layer0001';
    final tm = TileManager(canvasWidth: dw, canvasHeight: dh);
    final src = Uint8List(dw * dh * 4);

    // 各座標を一意に判別できる不透明色。補間不要な整数クロップを検査する。
    for (var y = 0; y < dh; y++) {
      for (var x = 0; x < dw; x++) {
        final i = (y * dw + x) * 4;
        src[i] = (x * 3 + y) & 0xff;
        src[i + 1] = (x + y * 5) & 0xff;
        src[i + 2] = (x * 7 + y * 11) & 0xff;
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
    );

    // offset=(16,12)。書き出し各画素は描画領域中央の同座標と完全一致する。
    final expected = Uint8List(ew * eh * 4);
    for (var y = 0; y < eh; y++) {
      for (var x = 0; x < ew; x++) {
        final si = ((y + 12) * dw + (x + 16)) * 4;
        final di = (y * ew + x) * 4;
        expected.setRange(di, di + 4, src, si);
      }
    }
    expect(
      actual,
      orderedEquals(expected),
      reason: '赤枠に相当する中央32x24だけが1pxのずれなく書き出されること',
    );
  });

  test('カメラX=+4は書き出しビューを描画領域の右へ4px移動する', () async {
    const dw = 64;
    const dh = 48;
    const ew = 32;
    const eh = 24;
    const sceneId = 'Scene0001';
    const layerId = 'Layer0001';
    final tm = TileManager(canvasWidth: dw, canvasHeight: dh);
    final src = Uint8List(dw * dh * 4);
    for (var y = 0; y < dh; y++) {
      for (var x = 0; x < dw; x++) {
        final i = (y * dw + x) * 4;
        src[i] = x * 4;
        src[i + 1] = y * 5;
        src[i + 2] = (x + y) * 2;
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
        CameraKeyframe(frameIndex: 0, x: 4, y: 0, zoom: 1, rotation: 0),
      ],
    );

    // CameraEngineは中心基準でtranslate(-x,-y)するため、正のxは内容を左へ4px、
    // すなわち出力pixel(x,y)が元描画領域pixel(x+16+4,y+12)を参照する。
    final expected = Uint8List(ew * eh * 4);
    for (var y = 0; y < eh; y++) {
      for (var x = 0; x < ew; x++) {
        final si = ((y + 12) * dw + (x + 20)) * 4;
        final di = (y * ew + x) * 4;
        expected.setRange(di, di + 4, src, si);
      }
    }
    expect(
      actual,
      orderedEquals(expected),
      reason: 'カメラ移動が書き出し時にも整数4pxぶん正しい方向へ反映されること',
    );
  });
}
