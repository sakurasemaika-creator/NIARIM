import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

/// A work's tiles are read with one word per pixel, and a tile that only one
/// entry gives keeps the expanded bytes instead of a copy. The tiles read must
/// stay byte for byte what the per-byte check gave (old straight RGB repaired,
/// everything else untouched), with the same checksums kept.
Uint8List _repaired(Uint8List raw) {
  final bytes = Uint8List.fromList(raw);
  for (var i = 0; i + 3 < bytes.length; i += 4) {
    final alpha = bytes[i + 3];
    if (bytes[i] <= alpha && bytes[i + 1] <= alpha && bytes[i + 2] <= alpha) {
      continue;
    }
    bytes[i] = (bytes[i] * alpha + 127) ~/ 255;
    bytes[i + 1] = (bytes[i + 1] * alpha + 127) ~/ 255;
    bytes[i + 2] = (bytes[i + 2] * alpha + 127) ~/ 255;
  }
  return bytes;
}

Uint8List _tile(Random random, {required bool straight}) {
  final tile = Uint8List(TileManager.tileSize * TileManager.tileSize * 4);
  for (var i = 0; i < tile.length; i += 4) {
    switch (random.nextInt(4)) {
      case 0:
        break; // transparent
      case 1:
        tile.setAll(i, [
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
          255,
        ]);
      default:
        final alpha = random.nextInt(256);
        int channel() =>
            straight ? random.nextInt(256) : random.nextInt(alpha + 1);
        tile.setAll(i, [channel(), channel(), channel(), alpha]);
    }
  }
  return tile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('niarim-tile-read-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test(
    'tiles read the same bytes and checksums as the per-byte check',
    () async {
      const layer = Layer(id: 'Layer0001', name: 'Ink', type: LayerType.normal);
      const scene = Scene(
        id: 'Scene0001',
        index: 0,
        frames: [
          Frame(index: 0, layers: [layer]),
          Frame(index: 1, layers: [layer]),
        ],
      );
      final project = Project(
        id: 'tile-read',
        name: 'Tile read',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 512,
        exportHeight: 512,
        createdAt: DateTime(2026, 11, 27),
        updatedAt: DateTime(2026, 11, 27),
        totalWorkSeconds: 0,
      );
      final tiles = TileManager(canvasWidth: 512, canvasHeight: 512);
      addTearDown(tiles.dispose);
      final file = await NiaproSerializer.save(
        project: project,
        scenes: [scene],
        tileManager: tiles,
      );
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final random = Random(27);
      final raw = <String, Uint8List>{
        // Each of these gives one tile.
        'Tiles/Scene0001/0/Layer0001_0,0.bin': _tile(random, straight: false),
        'Tiles/Scene0001/0/Layer0001_1,0.bin': _tile(random, straight: true),
        'Tiles/Scene0001/1/Layer0001_0,1.bin': _tile(random, straight: true),
        // An old work's tile is given to every frame that uses its layer.
        'Tiles/Layer0001_1,1.bin': _tile(random, straight: true),
      };
      for (final entry in raw.entries) {
        archive.addFile(
          ArchiveFile(entry.key, entry.value.length, entry.value),
        );
      }
      // A stored (not compressed) tile is read from inside the archive's bytes.
      final stored = _tile(random, straight: true);
      archive.addFile(
        ArchiveFile(
          'Tiles/Scene0001/1/Layer0001_1,0.bin',
          stored.length,
          stored,
        )..compress = false,
      );
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final original = Uint8List.fromList(bytes);

      final crcs = <String, int>{};
      final data = NiaproSerializer.loadFromBytes(bytes, tileCrcs: crcs);
      final key0 = frameLayerKey('Scene0001', 0, 'Layer0001');
      final key1 = frameLayerKey('Scene0001', 1, 'Layer0001');
      final expected = <(String, String), Uint8List>{
        (key0, '0,0'): _repaired(raw['Tiles/Scene0001/0/Layer0001_0,0.bin']!),
        (key0, '1,0'): _repaired(raw['Tiles/Scene0001/0/Layer0001_1,0.bin']!),
        (key1, '0,1'): _repaired(raw['Tiles/Scene0001/1/Layer0001_0,1.bin']!),
        (key1, '1,0'): _repaired(stored),
        (key0, '1,1'): _repaired(raw['Tiles/Layer0001_1,1.bin']!),
        (key1, '1,1'): _repaired(raw['Tiles/Layer0001_1,1.bin']!),
      };
      for (final MapEntry(key: (layerKey, tileKey), value: want)
          in expected.entries) {
        expect(
          data.tileData[layerKey]![tileKey],
          want,
          reason: '$layerKey $tileKey',
        );
      }
      // Only the tiles kept exactly as stored keep their checksum.
      expect(crcs.keys, unorderedEquals(['$key0:0,0']));
      // The archive's own bytes are not changed by the repair.
      expect(bytes, original);
      // The two frames given the same old tile do not share its bytes.
      data.tileData[key0]!['1,1']![0] ^= 0xff;
      expect(data.tileData[key1]!['1,1'], expected[(key1, '1,1')]);
    },
  );
}
