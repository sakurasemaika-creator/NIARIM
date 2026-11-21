import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

const _layer = Layer(id: 'Layer0001', name: 'Ink', type: LayerType.normal);
const _scene = Scene(
  id: 'Scene0001',
  index: 0,
  frames: [
    Frame(index: 0, layers: [_layer]),
    Frame(index: 1, layers: [_layer]),
  ],
);
const _key0 = 'Scene0001#0#Layer0001';
const _key1 = 'Scene0001#1#Layer0001';
const _currentTile = 'Tiles/Scene0001/0/Layer0001_0,0.bin';
const _oldRootTile = 'Tiles/Layer0001_0,0.bin';
const _oldSceneTile = 'Scene/Scene0001/tiles/Layer0001_0,0.bin';
const _expected = [
  128, 32, 16, 128, // Old straight RGB over transparent paper.
  40, 20, 10, 128, // Valid premultiplied data is retained byte for byte.
  0, 0, 0, 0, // No colour with zero opacity.
  45, 200, 123, 255, // Opaque pixels are unchanged.
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late Project project;
  late TileManager tiles;

  setUp(() {
    root = Directory.systemTemp.createTempSync('niarim-alpha-archive-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    project = Project(
      id: 'alpha-archive',
      name: 'Alpha compatibility',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0x00000000,
      exportWidth: 4,
      exportHeight: 4,
      createdAt: DateTime(2026, 10, 30),
      updatedAt: DateTime(2026, 10, 30),
      totalWorkSeconds: 0,
    );
    tiles = TileManager(canvasWidth: 4, canvasHeight: 4);
  });

  tearDown(() {
    tiles.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  for (final tilePath in [_currentTile, _oldRootTile, _oldSceneTile]) {
    test('old paint opens and saves correctly from $tilePath', () async {
      final file = await NiaproSerializer.save(
        project: project,
        scenes: [_scene],
        tileManager: tiles,
      );
      final zip = ZipDecoder().decodeBytes(await file.readAsBytes());
      final raw = Uint8List(TileManager.tileSize * TileManager.tileSize * 4)
        ..setAll(0, [
          255,
          64,
          32,
          128,
          40,
          20,
          10,
          128,
          20,
          60,
          200,
          0,
          45,
          200,
          123,
          255,
        ]);
      zip.addFile(ArchiveFile(tilePath, raw.length, raw));
      final original = ZipEncoder().encode(zip)!;
      await file.writeAsBytes(original);

      final opened = await NiaproSerializer.load(file.path);
      expect(await file.readAsBytes(), orderedEquals(original));
      tiles.importAll(opened.tileData);
      final black = await ExportEngine().renderFrame(
        layers: [_layer],
        tileManager: tiles,
        sceneId: _scene.id,
        frameIndex: 0,
        drawingWidth: 4,
        drawingHeight: 4,
        width: 4,
        height: 4,
        backgroundColor: 0xFF000000,
      );
      expect(black.take(4), [128, 32, 16, 255]);
      expect(opened.tileData[_key0]!['0,0']!.take(16), _expected);
      if (tilePath == _currentTile) {
        expect(opened.tileData, isNot(contains(_key1)));
      } else {
        expect(opened.tileData[_key1]!['0,0']!.take(16), _expected);
      }
      expect(await file.readAsBytes(), orderedEquals(original));

      await NiaproSerializer.save(
        project: opened.project,
        scenes: opened.scenes,
        tileManager: tiles,
      );
      final updated = ZipDecoder().decodeBytes(await file.readAsBytes());
      final data = updated.findFile(_currentTile)!.content as List<int>;
      expect(data.take(16), _expected);
      expect(
        (await NiaproSerializer.load(
          file.path,
        )).tileData[_key0]!['0,0']!.take(16),
        _expected,
      );
      final share = await NiaproSerializer.saveShare(
        project: opened.project,
        scenes: opened.scenes,
        tileManager: tiles,
        outputDir: root.path,
      );
      expect(
        (await NiaproSerializer.load(
          share.path,
        )).tileData[_key0]!['0,0']!.take(16),
        _expected,
      );
    });
  }
}
