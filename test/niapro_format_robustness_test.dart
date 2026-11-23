// .niapro の保存形式の強さ（全面監査のD034）。
//
// 保存して読み直すと絵・シーン・設定が同じに戻ること、古い版・新しい版の
// 保存も読めること、壊れたファイル（ZIPでない・途中で切れた・manifestが
// 無い・JSONが壊れた・型が違う）は例外で断り半端なデータを返さないこと、
// 読めた保存の中の壊れたタイルが絵を描く処理を止めないことを確かめる。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

const _size = TileManager.tileSize;

Project _project(String id) {
  final at = DateTime.utc(2026, 5, 1, 12);
  return Project(
    id: id,
    name: '作品 (コピー 2)',
    fps: 12,
    durationSeconds: 1,
    backgroundColor: 0xFF223344,
    createdAt: at,
    updatedAt: at,
    totalWorkSeconds: 42,
    exportWidth: 640,
    exportHeight: 360,
  );
}

Layer _layer(String id) =>
    Layer(id: id, name: 'L $id', type: LayerType.normal, opacity: 50);

/// A tile with a premultiplied gradient so every byte is checked.
Uint8List _tile(int seed) {
  final pixels = Uint8List(_size * _size * 4);
  for (var i = 0; i < _size * _size; i++) {
    final alpha = (i + seed) % 256;
    pixels[i * 4] = alpha ~/ 2;
    pixels[i * 4 + 1] = alpha ~/ 3;
    pixels[i * 4 + 2] = alpha;
    pixels[i * 4 + 3] = alpha;
  }
  return pixels;
}

Future<Uint8List> _save(
  Directory dir, {
  String projectId = 'p1',
  List<String> layerIds = const ['Layer0001', 'Layer0002'],
}) async {
  final tiles = TileManager(canvasWidth: 640, canvasHeight: 360);
  addTearDown(tiles.dispose);
  final scenes = [
    for (var s = 0; s < 2; s++)
      Scene(
        id: 'Scene000${s + 1}',
        index: s,
        name: 'シーン${s + 1}',
        frames: [
          for (var f = 0; f < 2; f++)
            Frame(index: f, layers: [for (final id in layerIds) _layer(id)]),
        ],
      ),
  ];
  final data = <String, Map<String, Uint8List>>{};
  var seed = 0;
  for (final scene in scenes) {
    for (final frame in scene.frames) {
      for (final id in layerIds) {
        data[frameLayerKey(scene.id, frame.index, id)] = {
          '0,0': _tile(seed++),
          '2,1': _tile(seed++),
        };
      }
    }
  }
  tiles.importAll(data);
  final path = '${dir.path}/$projectId.niapro';
  await NiaproSerializer.saveToPath(
    filePath: path,
    project: _project(projectId),
    scenes: scenes,
    tileManager: tiles,
  );
  return File(path).readAsBytesSync();
}

/// The archive with [edit] applied to its entries.
Uint8List _rewrite(
  Uint8List bytes,
  List<ArchiveFile> Function(List<ArchiveFile> files) edit,
) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = edit([
    for (final f in archive.files)
      if (f.isFile) ArchiveFile(f.name, f.size, f.content as List<int>),
  ]);
  final out = Archive();
  for (final f in files) {
    out.addFile(f);
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

ArchiveFile _text(String name, String text) {
  final bytes = utf8.encode(text);
  return ArchiveFile(name, bytes.length, bytes);
}

Map<String, dynamic> _manifestOf(Uint8List bytes) {
  final entry = ZipDecoder().decodeBytes(bytes).findFile('manifest.json')!;
  return jsonDecode(utf8.decode(entry.content as List<int>))
      as Map<String, dynamic>;
}

Uint8List _withManifest(Uint8List bytes, Object manifest) => _rewrite(
  bytes,
  (files) => [
    for (final f in files)
      if (f.name == 'manifest.json')
        _text(
          'manifest.json',
          manifest is String ? manifest : jsonEncode(manifest),
        )
      else
        f,
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('niarim-niapro-format-');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('saving and reading back keeps the project, scenes and pixels', () async {
    final bytes = await _save(dir);
    final data = NiaproSerializer.loadFromBytes(bytes);
    expect(data.project.id, 'p1');
    expect(data.project.name, '作品 (コピー 2)');
    expect(data.project.exportWidth, 640);
    expect(data.project.exportHeight, 360);
    expect(data.project.backgroundColor, 0xFF223344);
    expect(data.project.totalWorkSeconds, 42);
    expect(data.hasEditableFrames, isTrue);
    expect([for (final s in data.scenes) s.id], ['Scene0001', 'Scene0002']);
    expect([for (final s in data.scenes) s.name], ['シーン1', 'シーン2']);
    for (final scene in data.scenes) {
      expect(scene.frames, hasLength(2));
      for (final frame in scene.frames) {
        expect(
          [for (final l in frame.layers) l.id],
          ['Layer0001', 'Layer0002'],
        );
        expect(frame.layers.first.opacity, 50);
      }
    }
    var seed = 0;
    for (final scene in data.scenes) {
      for (var f = 0; f < 2; f++) {
        for (final id in ['Layer0001', 'Layer0002']) {
          final tiles = data.tileData[frameLayerKey(scene.id, f, id)]!;
          expect(tiles.keys.toSet(), {'0,0', '2,1'});
          expect(tiles['0,0'], _tile(seed++));
          expect(tiles['2,1'], _tile(seed++));
        }
      }
    }

    // Saved again from what was read, the same content comes back.
    final again = TileManager(canvasWidth: 640, canvasHeight: 360);
    addTearDown(again.dispose);
    again.importAll(data.tileData);
    final path = '${dir.path}/again.niapro';
    await NiaproSerializer.saveToPath(
      filePath: path,
      project: data.project,
      scenes: data.scenes,
      tileManager: again,
    );
    final reread = NiaproSerializer.loadFromBytes(File(path).readAsBytesSync());
    expect(reread.tileData.keys.toSet(), data.tileData.keys.toSet());
    for (final key in data.tileData.keys) {
      expect(reread.tileData[key], data.tileData[key]);
    }
    String shape(NiaproData d) => [
      for (final s in d.scenes)
        '${s.id}/${s.index}/${s.name}:'
            '${[
              for (final f in s.frames) '${f.index}=${[for (final l in f.layers) '${l.id},${l.name},${l.opacity},${l.type.name}'].join('+')}',
            ].join('|')}',
    ].join(';');
    expect(shape(reread), shape(data));
  });

  test('layer ids with an underscore keep their tiles', () async {
    final bytes = await _save(dir, layerIds: const ['layer_a', 'Layer0002']);
    final data = NiaproSerializer.loadFromBytes(bytes);
    expect(
      data.tileData[frameLayerKey('Scene0001', 0, 'layer_a')]?.keys.toSet(),
      {'0,0', '2,1'},
    );
  });

  test('a shared file keeps its bundled materials', () async {
    final tiles = TileManager(canvasWidth: 640, canvasHeight: 360);
    addTearDown(tiles.dispose);
    final file = await NiaproSerializer.saveShare(
      project: _project('p2'),
      scenes: const [
        Scene(
          id: 'Scene0001',
          index: 0,
          frames: [Frame(index: 0, layers: [])],
        ),
      ],
      tileManager: tiles,
      outputDir: dir.path,
      materialFiles: {
        'voice.m4a': Uint8List.fromList([1, 2, 3, 4]),
        'photo.png': Uint8List.fromList(List.generate(300, (i) => i % 256)),
      },
      materialsManifest: '{"items":[{"id":"voice.m4a"}]}',
    );
    expect(file.path, endsWith('.niashare'));
    final data = NiaproSerializer.loadFromBytes(file.readAsBytesSync());
    expect(data.materialFiles.keys.toSet(), {'voice.m4a', 'photo.png'});
    expect(data.materialFiles['voice.m4a'], [1, 2, 3, 4]);
    expect(data.materialFiles['photo.png'], List.generate(300, (i) => i % 256));
    expect(data.materialsManifest, '{"items":[{"id":"voice.m4a"}]}');
  });

  test('older, newer and unversioned saves are read', () async {
    final bytes = await _save(dir);
    for (final version in ['0.9.0', '1.0.0', '2.3.4', '99', 'abc', null]) {
      final manifest = _manifestOf(bytes);
      if (version == null) {
        manifest.remove('appVersion');
      } else {
        manifest['appVersion'] = version;
      }
      // A newer app may add fields this one does not know.
      manifest['futureField'] = {'nested': true};
      final data = NiaproSerializer.loadFromBytes(
        _withManifest(bytes, manifest),
      );
      expect(data.project.id, 'p1', reason: '$version');
      expect(data.hasEditableFrames, isTrue, reason: '$version');
      expect(data.tileData, hasLength(8), reason: '$version');
    }
  });

  test(
    'damaged files are refused with an exception, never half read',
    () async {
      final bytes = await _save(dir);
      final cases = <String, List<int>>{
        'empty': const [],
        'not a zip': utf8.encode('hello, this is not a project'),
        'random bytes': List.generate(4096, (i) => (i * 7919 + 13) % 256),
        'cut in half': bytes.sublist(0, bytes.length ~/ 2),
        'last byte missing': bytes.sublist(0, bytes.length - 1),
        'first bytes missing': bytes.sublist(64),
        'no manifest': _rewrite(
          bytes,
          (files) => files.where((f) => f.name != 'manifest.json').toList(),
        ),
        'manifest not json': _withManifest(bytes, '{"id": "p1", '),
        'manifest a list': _withManifest(bytes, '[1, 2, 3]'),
        'manifest a string': _withManifest(bytes, '"p1"'),
        'manifest null': _withManifest(bytes, 'null'),
        'manifest not utf8': _rewrite(
          bytes,
          (files) => [
            for (final f in files)
              if (f.name == 'manifest.json')
                ArchiveFile('manifest.json', 4, [0xff, 0xfe, 0x7b, 0x7d])
              else
                f,
          ],
        ),
        'path outside the archive': _rewrite(
          bytes,
          (files) => [...files, _text('Materials/../../evil.txt', 'x')],
        ),
        'frames not json': _rewrite(
          bytes,
          (files) => [
            for (final f in files)
              if (f.name.endsWith('frames.json'))
                _text(f.name, '{"frames": [')
              else
                f,
          ],
        ),
      };
      for (final entry in cases.entries) {
        Object? error;
        NiaproData? data;
        try {
          data = NiaproSerializer.loadFromBytes(entry.value);
        } catch (e) {
          error = e;
        }
        expect(data, isNull, reason: entry.key);
        expect(error, isNotNull, reason: entry.key);
      }
    },
  );

  test('wrong field types in the manifest are refused or defaulted', () async {
    final bytes = await _save(dir);
    for (final field in [
      'id',
      'name',
      'fps',
      'durationSeconds',
      'exportWidth',
      'exportHeight',
      'createdAt',
    ]) {
      for (final value in <Object?>[
        null,
        'x',
        12.5,
        0,
        -5,
        1 << 40,
        <int>[],
        <String, int>{},
      ]) {
        final manifest = _manifestOf(bytes)..[field] = value;
        NiaproData? data;
        try {
          data = NiaproSerializer.loadFromBytes(_withManifest(bytes, manifest));
        } on Object {
          continue; // refused: the caller shows the work as damaged.
        }
        // Read: the values it gives must be usable.
        expect(data.project.id, isNotEmpty, reason: '$field=$value');
        expect(data.project.fps, greaterThan(0), reason: '$field=$value');
        expect(
          data.project.durationSeconds,
          greaterThanOrEqualTo(0),
          reason: '$field=$value',
        );
        for (final edge in [
          data.project.exportWidth,
          data.project.exportHeight,
        ]) {
          expect(edge, inInclusiveRange(1, 1 << 16), reason: '$field=$value');
        }
      }
    }
  });

  test('a damaged tile does not stop the canvas from drawing', () async {
    final bytes = await _save(dir);
    final damaged = _rewrite(
      bytes,
      (files) => [
        for (final f in files)
          if (f.name == 'Tiles/Scene0001/0/Layer0001_0,0.bin')
            ArchiveFile(f.name, 100, Uint8List(100))
          else
            f,
        ArchiveFile('Tiles/Scene0001/0/Layer0001_bad.bin', 16, Uint8List(16)),
        ArchiveFile(
          'Tiles/Scene0001/0/Layer0001_1,x.bin',
          _size * _size * 4,
          _tile(1),
        ),
      ],
    );
    final data = NiaproSerializer.loadFromBytes(damaged);
    final key = frameLayerKey('Scene0001', 0, 'Layer0001');
    final tiles = TileManager(canvasWidth: 640, canvasHeight: 360);
    addTearDown(tiles.dispose);
    tiles.importAll(data.tileData);
    final image = await tiles.compositeLayerToImage(key);
    addTearDown(image.dispose);
    final pixels = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    // The good tile at (2,1) is still drawn.
    final x = 2 * _size + 10, y = 1 * _size + 10;
    final i = (y * image.width + x) * 4;
    expect(pixels.getUint8(i + 3), isNonZero);
  });
}
