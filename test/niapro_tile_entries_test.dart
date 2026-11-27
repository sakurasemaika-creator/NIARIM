// 作品のファイル・自動保存のタイルの項目は、端末のzlibで圧縮し（Dartの圧縮と
// 同じ段階6）、チェックサムを付けてから書く。どの展開器で読んでも元の画素に
// 戻り、ZIPのチェックサムが中身と合うこと、作品を読み直したタイルが保存した
// タイルと1バイトも違わないことを、全部書く保存・変わったタイルだけ書く保存・
// 自動保存のそれぞれで確かめる。
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

const _size = TileManager.tileSize;

/// A premultiplied tile: transparent, opaque and part-transparent pixels.
void _fill(Uint8List tile, Random random) {
  for (var i = 0; i < tile.length; i += 4) {
    switch (random.nextInt(4)) {
      case 0:
        tile.fillRange(i, i + 4, 0);
      case 1:
        tile.setAll(i, [
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
          255,
        ]);
      default:
        final alpha = random.nextInt(256);
        tile.setAll(i, [
          random.nextInt(alpha + 1),
          random.nextInt(alpha + 1),
          random.nextInt(alpha + 1),
          alpha,
        ]);
    }
  }
}

/// Checks every tile entry of the zip at [path] against [tiles]: stored
/// with DEFLATE, the Dart and the platform's inflater both give the tile,
/// and the entry's checksums (central directory and local header) are the
/// tile's.
void _expectTileEntries(
  String path,
  Map<String, Map<String, Uint8List>> tiles,
) {
  final directory = ZipDirectory.read(
    InputStream(File(path).readAsBytesSync()),
  );
  var checked = 0;
  for (final header in directory.fileHeaders) {
    if (!header.filename.startsWith('Tiles/')) continue;
    final match = RegExp(
      r'^Tiles/(.+)/(\d+)/(.+)_(\d+,\d+)\.bin$',
    ).firstMatch(header.filename)!;
    final want =
        tiles[frameLayerKey(
          match[1]!,
          int.parse(match[2]!),
          match[3]!,
        )]![match[4]!]!;
    final name = header.filename;
    final entry = header.file!;
    expect(
      header.compressionMethod,
      ZipFile.zipCompressionDeflate,
      reason: name,
    );
    expect(
      entry.compressionMethod,
      ZipFile.zipCompressionDeflate,
      reason: name,
    );
    expect(header.uncompressedSize, want.length, reason: name);
    expect(header.crc32, getCrc32(want), reason: name);
    expect(entry.crc32, getCrc32(want), reason: name);
    final raw = entry.rawContent!.toUint8List();
    expect(Inflate(raw, want.length).getBytes(), want, reason: name);
    expect(entry.content, want, reason: name);
    checked++;
  }
  expect(checked, tiles.values.fold<int>(0, (n, layer) => n + layer.length));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('niarim-tile-entries-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test('saved tiles read back the same through any inflater', () async {
    const ink = Layer(id: 'Layer0001', name: 'Ink', type: LayerType.normal);
    const paint = Layer(id: 'Layer0002', name: 'Paint', type: LayerType.normal);
    const scene = Scene(
      id: 'Scene0001',
      index: 0,
      frames: [
        Frame(index: 0, layers: [ink, paint]),
        Frame(index: 1, layers: [ink]),
      ],
    );
    final project = Project(
      id: 'tile-entries',
      name: 'Tile entries',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 3 * _size,
      exportHeight: 2 * _size,
      createdAt: DateTime(2026, 11, 27),
      updatedAt: DateTime(2026, 11, 27),
      totalWorkSeconds: 0,
    );
    final tiles = TileManager(canvasWidth: 3 * _size, canvasHeight: 2 * _size);
    addTearDown(tiles.dispose);
    final random = Random(1127);
    final ink0 = frameLayerKey('Scene0001', 0, 'Layer0001');
    final paint0 = frameLayerKey('Scene0001', 0, 'Layer0002');
    final ink1 = frameLayerKey('Scene0001', 1, 'Layer0001');
    for (final (key, tx, ty) in [
      (ink0, 0, 0),
      (ink0, 2, 1),
      (paint0, 1, 0),
      (ink1, 1, 1),
    ]) {
      _fill(tiles.getOrCreateTile(key, tx, ty), random);
    }
    // A tile with nothing on it and one painted over completely.
    tiles.getOrCreateTile(paint0, 0, 1);
    tiles.getOrCreateTile(ink1, 2, 0).fillRange(0, _size * _size * 4, 255);

    Map<String, Map<String, Uint8List>> snapshot() => {
      for (final layer in tiles.exportAll().entries)
        layer.key: {
          for (final tile in layer.value.entries)
            tile.key: Uint8List.fromList(tile.value),
        },
    };

    void expectLoadsBack(
      String path,
      Map<String, Map<String, Uint8List>> want,
    ) {
      final data = NiaproSerializer.loadFromBytes(File(path).readAsBytesSync());
      for (final layer in want.entries) {
        for (final tile in layer.value.entries) {
          expect(
            data.tileData[layer.key]![tile.key],
            tile.value,
            reason: '${layer.key} ${tile.key}',
          );
        }
      }
    }

    // The first save writes every tile.
    final file = await NiaproSerializer.save(
      project: project,
      scenes: [scene],
      tileManager: tiles,
    );
    final first = snapshot();
    _expectTileEntries(file.path, first);
    expectLoadsBack(file.path, first);

    // The next save writes the changed tile and copies the others.
    _fill(tiles.getOrCreateTile(ink0, 2, 1), random);
    _fill(tiles.getOrCreateTile(paint0, 2, 1), random);
    await NiaproSerializer.save(
      project: project,
      scenes: [scene],
      tileManager: tiles,
    );
    final second = snapshot();
    _expectTileEntries(file.path, second);
    expectLoadsBack(file.path, second);

    // The automatic save writes every tile anew.
    _fill(tiles.getOrCreateTile(ink1, 0, 0), random);
    final autosave = await NiaproSerializer.saveAutosave(
      project: project,
      scenes: [scene],
      tileManager: tiles,
      slotIndex: 0,
    );
    final third = snapshot();
    _expectTileEntries(autosave.path, third);
    expectLoadsBack(autosave.path, third);
  });
}
