import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';

const _ink = Layer(id: 'Layer0001', name: 'Ink', type: LayerType.normal);
const _scene = Scene(
  id: 'Scene0001',
  index: 0,
  frames: [
    Frame(index: 0, layers: [_ink]),
  ],
);

List<int> _rgba(img.Pixel p) => [
  p.r.toInt(),
  p.g.toInt(),
  p.b.toInt(),
  p.a.toInt(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late TileManager tiles;

  setUp(() {
    root = Directory.systemTemp.createTempSync('niarim-alpha-png-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    tiles = TileManager(canvasWidth: 4, canvasHeight: 4);
    tiles.getOrCreateTile('Scene0001#0#Layer0001', 0, 0).setAll(0, [
      128,
      32,
      16,
      128,
      0,
      0,
      0,
      0,
      45,
      200,
      123,
      255,
    ]);
  });

  tearDown(() {
    tiles.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  Future<File> exportPng(int background) async => File(
    await ExportEngine().exportFrameImage(
      scenes: [_scene],
      tileManager: tiles,
      sceneId: _scene.id,
      frameIndex: 0,
      drawingWidth: 4,
      drawingHeight: 4,
      width: 4,
      height: 4,
      backgroundColor: background,
      asJpeg: false,
    ),
  );

  test('transparent PNG keeps colour and opacity when reopened', () async {
    final bytes = await (await exportPng(0x00000000)).readAsBytes();
    final png = img.decodePng(bytes)!;
    expect(_rgba(png.getPixel(0, 0)), [255, 64, 32, 128]);
    expect(_rgba(png.getPixel(1, 0)), [0, 0, 0, 0]);
    expect(_rgba(png.getPixel(2, 0)), [45, 200, 123, 255]);

    final codec = await ui.instantiateImageCodec(bytes);
    final reopened = (await codec.getNextFrame()).image;
    final decoded = await reopened.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(decoded!.buffer.asUint8List().take(4), [128, 32, 16, 128]);
    reopened.dispose();
    codec.dispose();
    expect(tiles.getTile('Scene0001#0#Layer0001', 0, 0)!.take(4), [
      128,
      32,
      16,
      128,
    ]);
  });

  test('an opaque PNG retains its composited colours', () async {
    final png = img.decodePng(
      await (await exportPng(0xFF000000)).readAsBytes(),
    )!;
    expect(_rgba(png.getPixel(0, 0)), [128, 32, 16, 255]);
    expect(_rgba(png.getPixel(1, 0)), [0, 0, 0, 255]);
    expect(_rgba(png.getPixel(2, 0)), [45, 200, 123, 255]);
  });
}
