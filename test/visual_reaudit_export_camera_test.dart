import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/filter_engine.dart' show EffectFilterType;
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/layer.dart';

const _dw = 320;
const _dh = 240;
const _ew = 240;
const _eh = 180;
const _scene = 'Scene0001';
const _layer = 'Layer0001';

Uint8List _scenePixels() {
  final out = Uint8List(_dw * _dh * 4);
  void rect(int x0, int y0, int x1, int y1, int r, int g, int b) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * _dw + x) * 4;
        out[i] = r;
        out[i + 1] = g;
        out[i + 2] = b;
        out[i + 3] = 255;
      }
    }
  }

  // Dark background and asymmetric landmarks make crop/move/rotation/zoom obvious.
  rect(0, 0, _dw, _dh, 22, 28, 42);
  rect(38, 38, 116, 96, 240, 64, 70);
  rect(204, 42, 282, 106, 46, 214, 104);
  rect(54, 150, 128, 214, 54, 112, 240);
  rect(198, 148, 286, 216, 240, 204, 48);
  rect(136, 86, 184, 154, 244, 244, 244);
  for (var y = 0; y < _dh; y++) {
    final x = 22 + y;
    if (x >= 0 && x < _dw) {
      for (var dx = -2; dx <= 2; dx++) {
        final xx = x + dx;
        if (xx < 0 || xx >= _dw) continue;
        final i = (y * _dw + xx) * 4;
        out[i] = 255;
        out[i + 1] = 130;
        out[i + 2] = 218;
        out[i + 3] = 255;
      }
    }
  }
  return out;
}

Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final im = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  await File(path).writeAsBytes(img.encodePng(im));
}

Future<Uint8List> _render({
  List<CameraKeyframe> camera = const [],
  List<EffectFilterInstance> effects = const [],
  int frame = 0,
}) async {
  final tm = TileManager(canvasWidth: _dw, canvasHeight: _dh);
  tm.replaceLayerPixels(frameLayerKey(_scene, frame, _layer), _scenePixels());
  return ExportEngine().renderFrame(
    layers: const [Layer(id: _layer, name: 'L', type: LayerType.normal)],
    tileManager: tm,
    sceneId: _scene,
    frameIndex: frame,
    drawingWidth: _dw,
    drawingHeight: _dh,
    width: _ew,
    height: _eh,
    backgroundColor: 0x00000000,
    cameraKeyframes: camera,
    effectFilters: effects,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/export-camera');
  setUpAll(() => out.createSync(recursive: true));

  test('ExportEngineのクロップ・移動・回転・ズーム・補間・fadeをPNGで再監査する', () async {
    await _save(
      _scenePixels(),
      _dw,
      _dh,
      '${out.path}/00_drawing_area_source.png',
    );

    final crop = await _render();
    await _save(crop, _ew, _eh, '${out.path}/01_center_crop.png');

    final moved = await _render(
      camera: const [
        CameraKeyframe(frameIndex: 0, x: 36, y: -18, zoom: 1, rotation: 0),
      ],
    );
    await _save(moved, _ew, _eh, '${out.path}/02_camera_move_x36_y-18.png');

    final rotated = await _render(
      camera: const [CameraKeyframe(frameIndex: 0, rotation: 180)],
    );
    await _save(rotated, _ew, _eh, '${out.path}/03_camera_rotate_180.png');

    final zoomed = await _render(
      camera: const [CameraKeyframe(frameIndex: 0, zoom: 2)],
    );
    await _save(zoomed, _ew, _eh, '${out.path}/04_camera_zoom_2x.png');

    final interpolated = await _render(
      frame: 5,
      camera: const [
        CameraKeyframe(frameIndex: 0, x: 0, y: 0, zoom: 1, rotation: 0),
        CameraKeyframe(frameIndex: 10, x: 48, y: 28, zoom: 1, rotation: 0),
      ],
    );
    await _save(
      interpolated,
      _ew,
      _eh,
      '${out.path}/05_camera_interpolate_50pct.png',
    );

    const fadeColor = Color.fromARGB(255, 230, 76, 30);
    final faded = await _render(
      frame: 5,
      effects: const [
        EffectFilterInstance(
          id: 'fade-half',
          type: EffectFilterType.fade,
          startFrame: 0,
          endFrame: 10,
          fadeColor: fadeColor,
        ),
      ],
    );
    await _save(faded, _ew, _eh, '${out.path}/06_effect_fade_50pct.png');

    // Numeric guards only; visual acceptance is from the emitted PNG set.
    expect(crop, isNot(orderedEquals(moved)));
    expect(crop, isNot(orderedEquals(rotated)));
    expect(crop, isNot(orderedEquals(zoomed)));
    expect(crop, isNot(orderedEquals(interpolated)));
    expect(crop, isNot(orderedEquals(faded)));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
