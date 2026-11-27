// GIFの書き出しで、出力のfpsが元のfpsより高く同じ元のコマが続くときは、
// コマを描き直さずに前のコマのバイト列と（隅のロゴの置き場所を決める）
// ウォーターマークの重なりを使い回す。描き直したときと同じGIFになり、
// 描くたびに違う模様になる演出（ノイズ）がある場面だけは今までどおり
// 毎回描き直す。
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';

const _w = 200;
const _h = 120;
const _sceneId = 'Scene0001';
const _layer = Layer(id: 'Layer0001', name: 'L', type: LayerType.normal);
const _mark = Layer(id: 'Mark0001', name: 'W', type: LayerType.watermark);

/// A frame with a block of [rgb] moved along by [index].
Uint8List _frame(int index, int rgb) {
  final pixels = Uint8List(_w * _h * 4);
  for (var y = 20; y < 80; y++) {
    for (var x = 10 + index * 30; x < 60 + index * 30; x++) {
      final i = (y * _w + x) * 4;
      pixels
        ..[i] = (rgb >> 16) & 0xFF
        ..[i + 1] = (rgb >> 8) & 0xFF
        ..[i + 2] = rgb & 0xFF
        ..[i + 3] = 255;
    }
  }
  return pixels;
}

/// The user's watermark in the bottom left corner.
Uint8List _markPixels() {
  final pixels = Uint8List(_w * _h * 4);
  for (var y = _h - 30; y < _h - 4; y++) {
    for (var x = 4; x < 70; x++) {
      final i = (y * _w + x) * 4;
      pixels
        ..[i] = 200
        ..[i + 3] = 255;
    }
  }
  return pixels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('niarim-gif-repeat-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => root.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<List<Uint8List>> export({
    required int fps,
    bool cornerLogo = false,
    bool noise = false,
  }) async {
    final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
    addTearDown(tiles.dispose);
    const colours = [0x2050C0, 0xC05020, 0x20A040];
    for (final (index, rgb) in colours.indexed) {
      tiles.replaceLayerPixels(
        frameLayerKey(_sceneId, index, _layer.id),
        _frame(index, rgb),
      );
      tiles.replaceLayerPixels(
        frameLayerKey(_sceneId, index, _mark.id),
        _markPixels(),
      );
    }
    final output = await ExportEngine().exportGif(
      scenes: [
        Scene(
          id: _sceneId,
          index: 0,
          frames: [
            for (var i = 0; i < colours.length; i++)
              Frame(index: i, layers: const [_mark, _layer]),
          ],
          effectFilters: [
            if (noise)
              const EffectFilterInstance(
                id: 'Noise',
                type: EffectFilterType.noise,
                startFrame: 0,
                endFrame: 2,
                param1: 10,
              ),
          ],
        ),
      ],
      tileManager: tiles,
      fps: fps,
      sourceFps: 4,
      drawingWidth: _w,
      drawingHeight: _h,
      width: _w,
      height: _h,
      backgroundColor: 0xFFFFFFFF,
      cornerLogo: cornerLogo,
    );
    final gif = img.decodeGif(File(output).readAsBytesSync())!;
    return [
      for (final frame in gif.frames)
        frame.convert(numChannels: 4).toUint8List(),
    ];
  }

  for (final cornerLogo in [false, true]) {
    test('each repeated source frame is the frame drawn once '
        '(corner logo: $cornerLogo)', () async {
      final once = await export(fps: 4, cornerLogo: cornerLogo);
      final twice = await export(fps: 8, cornerLogo: cornerLogo);
      final thrice = await export(fps: 12, cornerLogo: cornerLogo);
      expect(once, hasLength(3));
      expect(twice, hasLength(6));
      expect(thrice, hasLength(9));
      for (var i = 0; i < twice.length; i++) {
        expect(twice[i], once[i ~/ 2], reason: 'frame $i of 6');
      }
      for (var i = 0; i < thrice.length; i++) {
        expect(thrice[i], once[i ~/ 3], reason: 'frame $i of 9');
      }
    });
  }

  test('a scene with the noise effect draws each output frame anew', () async {
    final frames = await export(fps: 8, noise: true);
    expect(frames, hasLength(6));
    for (var i = 0; i < frames.length; i += 2) {
      expect(frames[i], isNot(frames[i + 1]), reason: 'frames $i, ${i + 1}');
    }
  });
}
