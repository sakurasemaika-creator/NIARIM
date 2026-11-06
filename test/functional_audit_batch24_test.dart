import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/filter_engine.dart' show EffectFilterType;
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('書き出し時のカメラ180度回転で4象限が対角へ正しく入れ替わる', () async {
    const w = 40;
    const h = 40;
    const sceneId = 'Scene0001';
    const layerId = 'Layer0001';
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final src = Uint8List(w * h * 4);

    // 境界の補間誤差に影響されないよう、各象限を十分広い完全不透明な単色にする。
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final (r, g, b) = switch ((x >= 20, y >= 20)) {
          (false, false) => (240, 20, 30),
          (true, false) => (20, 220, 40),
          (false, true) => (30, 60, 230),
          (true, true) => (230, 210, 20),
        };
        src[i] = r;
        src[i + 1] = g;
        src[i + 2] = b;
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
      drawingWidth: w,
      drawingHeight: h,
      width: w,
      height: h,
      backgroundColor: 0x00000000,
      cameraKeyframes: const [CameraKeyframe(frameIndex: 0, rotation: 180)],
    );

    List<int> rgbaAt(int x, int y) {
      final i = (y * w + x) * 4;
      return actual.sublist(i, i + 4);
    }

    // 180度回転では各象限が対角へ移る。境界から10px離した点だけを見ることで
    // rasterizerの境界丸めとは無関係に、回転方向と中心が正しいことを検証する。
    expect(rgbaAt(10, 10), orderedEquals([230, 210, 20, 255]));
    expect(rgbaAt(30, 10), orderedEquals([30, 60, 230, 255]));
    expect(rgbaAt(10, 30), orderedEquals([20, 220, 40, 255]));
    expect(rgbaAt(30, 30), orderedEquals([240, 20, 30, 255]));
  });

  test('演出fadeは書き出し最終RGBAへ50%適用されalphaを保持する', () async {
    const w = 8;
    const h = 6;
    const sceneId = 'Scene0001';
    const layerId = 'Layer0001';
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final src = Uint8List(w * h * 4);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        src[i] = 20 + x * 17;
        src[i + 1] = 35 + y * 21;
        src[i + 2] = 180 - x * 9 - y * 7;
        // alphaも複数値にして、fadeが透明度を壊さないことを同時に見る。
        src[i + 3] = 40 + ((x + y) * 19) % 216;
      }
    }
    tm.replaceLayerPixels(frameLayerKey(sceneId, 5, layerId), src);
    const layer = Layer(id: layerId, name: 'L', type: LayerType.normal);
    const fadeColor = Color.fromARGB(255, 200, 80, 20);

    final actual = await ExportEngine().renderFrame(
      layers: const [layer],
      tileManager: tm,
      sceneId: sceneId,
      frameIndex: 5,
      drawingWidth: w,
      drawingHeight: h,
      width: w,
      height: h,
      backgroundColor: 0x00000000,
      effectFilters: const [
        EffectFilterInstance(
          id: 'fade-half',
          type: EffectFilterType.fade,
          startFrame: 0,
          endFrame: 10,
          fadeColor: fadeColor,
        ),
      ],
    );

    final expected = Uint8List.fromList(src);
    for (var i = 0; i < expected.length; i += 4) {
      expected[i] = ((src[i] + 200) / 2).round();
      expected[i + 1] = ((src[i + 1] + 80) / 2).round();
      expected[i + 2] = ((src[i + 2] + 20) / 2).round();
      expected[i + 3] = src[i + 3];
    }

    expect(
      actual,
      orderedEquals(expected),
      reason: 'frame=5は0→10のちょうど50%なのでRGBだけがfade色へ半分寄り、alphaは全画素不変であること',
    );
  });
}
