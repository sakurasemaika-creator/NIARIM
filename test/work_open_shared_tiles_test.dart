// 作品を開くとき、同じ画素のタイル（複製したコマ・シーン）は1回だけ展開して
// 1つのバッファで持つ（書き込むときに写すCopy-on-Write）。
//
// 1080×1080・12コマの作品で、コマを複製して2割だけ描き直したものは、開いた
// ときのタイルのメモリが139MiBから26MiBに減った。ここでは、まとめて持っても
// 描く・取り消す・保存・自動保存・コマの複製と削除・書き出し・.niashareの
// 結果が、1つずつ持ったとき（`debugShareIdenticalTiles = false`）と1バイトも
// 変わらないことを確かめる。
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/autosave_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _size = TileManager.tileSize;

Uint8List _tile(int seed) {
  final pixels = Uint8List(_size * _size * 4);
  for (var i = 0; i < _size * _size; i++) {
    final alpha = (i * 7 + seed * 13) % 256;
    pixels[i * 4] = alpha ~/ 2;
    pixels[i * 4 + 1] = (alpha * seed) % (alpha + 1);
    pixels[i * 4 + 2] = alpha;
    pixels[i * 4 + 3] = alpha;
  }
  return pixels;
}

/// Straight colour in a premultiplied tile (as older writers saved it): the
/// reader repairs it, and its CRC-32 is not kept.
Uint8List _unrepairedTile() {
  final pixels = _tile(5);
  for (var i = 0; i < _size * _size; i += 3) {
    pixels[i * 4] = 250;
    pixels[i * 4 + 3] = 40;
  }
  return pixels;
}

Map<String, Map<String, Uint8List>> _copy(
  Map<String, Map<String, Uint8List>> tiles,
) => {
  for (final layer in tiles.entries)
    layer.key: {
      for (final tile in layer.value.entries)
        tile.key: Uint8List.fromList(tile.value),
    },
};

int _distinctBuffers(Map<String, Map<String, Uint8List>> tiles) => {
  for (final layer in tiles.values)
    for (final tile in layer.values) identityHashCode(tile): tile,
}.length;

/// Every entry of the zip at [path] as stored: how, its CRC-32 and its
/// stored bytes ([leaveOut] entries are not compared: they hold the time of
/// the save).
Map<String, Map<String, Object?>> _stored(
  String path, {
  Set<String> leaveOut = const {'manifest.json'},
}) => {
  for (final f in ZipDecoder().decodeBytes(File(path).readAsBytesSync()).files)
    if (f.isFile && !leaveOut.contains(f.name))
      f.name: {
        'how': f.compressionType,
        'crc': f.crc32,
        'bytes': List<int>.of(f.rawContent!.toUint8List()),
      },
};

/// Rewrites the zip at [path]: the entry [uncompressed] stored as is, the
/// entry [forged] stored as is with the CRC-32 of [forgedAs] in its headers
/// (every other entry compressed again, so copies get the same stored
/// bytes).
void _rewrite(
  String path, {
  required String uncompressed,
  required String forged,
  required String forgedAs,
}) {
  final source = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
  final forgedCrc = source.files.singleWhere((f) => f.name == forgedAs).crc32;
  final out = Archive();
  for (final f in source.files) {
    if (!f.isFile) continue;
    final bytes = f.content as List<int>;
    // The encoder keeps a given CRC-32 only for an entry it stores as is.
    final entry = f.name == uncompressed || f.name == forged
        ? ArchiveFile.noCompress(f.name, bytes.length, bytes)
        : ArchiveFile(f.name, bytes.length, bytes);
    if (f.name == forged) entry.crc32 = forgedCrc;
    out.addFile(entry);
  }
  File(path).writeAsBytesSync(ZipEncoder().encode(out)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  late Directory root;

  void useRoot(Directory dir) {
    root = dir;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => dir.path);
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-shared-tiles-');
    SharedPreferences.setMockInitialValues({});
    NiaproSerializer.debugShareIdenticalTiles = true;
  });
  tearDown(() {
    NiaproSerializer.debugShareIdenticalTiles = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String workFile(String id) => '${root.path}/niarim/projects/$id/$id.niapro';

  /// A saved work of 3 frames copied from the first (the last one redrawn in
  /// part) and its scene copied, under [dir]; the keys of the first scene's
  /// layers by frame. Frame 1's drawing tile "0,0" is stored uncompressed
  /// (the same pixels and CRC-32 as frame 0's, other stored bytes), frame
  /// 2's "1,0" carries the CRC-32 of frame 0's "1,0" (other pixels).
  Future<({String id, String scene, List<String> drawing, List<String> old})>
  savedWork(Directory dir) async {
    useRoot(dir);
    final service = ProjectService();
    await service.init();
    final project = await service.createProject(
      name: '作品',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 512,
      exportHeight: 256,
    );
    final id = project.id;
    final sceneId = service.scenesOf(id).first.id;
    service.addLayer(
      projectId: id,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'old',
    );
    String key(int frame, {required bool old}) {
      final layer = service
          .scenesOf(id)
          .first
          .frames[frame]
          .layers
          .firstWhere(
            (l) => l.type == LayerType.normal && (l.name == 'old') == old,
          );
      return service.tileKeyFor(id, sceneId, frame, layer.id);
    }

    final tiles = service.tileManagerOf(id);
    tiles.getOrCreateTile(key(0, old: false), 0, 0).setAll(0, _tile(1));
    tiles.getOrCreateTile(key(0, old: false), 1, 0).setAll(0, _tile(2));
    tiles.getOrCreateTile(key(0, old: true), 0, 0).setAll(0, _unrepairedTile());
    final frames = service.scenesOf(id).first.frames.length;
    for (var f = frames - 1; f >= 1; f--) {
      service.removeFrame(id, sceneId, f);
    }
    service.duplicateFrame(id, sceneId, 0);
    service.duplicateFrame(id, sceneId, 1);
    tiles.getOrCreateTile(key(2, old: false), 1, 0).setAll(0, _tile(3));
    final drawing = [for (var f = 0; f < 3; f++) key(f, old: false)];
    final old = [for (var f = 0; f < 3; f++) key(f, old: true)];
    service.duplicateScene(id, sceneId);
    await service.saveProject(id);
    service.dispose();
    String entry(int frame, String tile) {
      final layerId = parseFrameLayerKey(drawing[frame])!.layerId;
      return 'Tiles/$sceneId/$frame/${layerId}_$tile.bin';
    }

    _rewrite(
      workFile(id),
      uncompressed: entry(1, '0,0'),
      forged: entry(2, '1,0'),
      forgedAs: entry(0, '1,0'),
    );
    return (id: id, scene: sceneId, drawing: drawing, old: old);
  }

  test('identical tiles are read into one buffer, and every tile and CRC-32 '
      'is what reading each on its own gives', () async {
    final work = await savedWork(temp);
    final path = workFile(work.id);
    final sharedCrcs = <String, int>{};
    final shared = NiaproSerializer.loadTilesSync(path, crcs: sharedCrcs);
    NiaproSerializer.debugShareIdenticalTiles = false;
    final ownCrcs = <String, int>{};
    final own = NiaproSerializer.loadTilesSync(path, crcs: ownCrcs);

    expect(shared, own);
    expect(sharedCrcs, ownCrcs);
    final drawing = work.drawing;
    final old = work.old;
    // The repaired tile keeps no CRC-32 either way.
    expect(ownCrcs.containsKey('${old[0]}:0,0'), isFalse);

    // 2 scenes of 3 frames, 3 tiles a frame.
    expect(_distinctBuffers(own), 18);
    // The drawing's 3 tiles (the redrawn one twice: once with its CRC-32
    // forged) and the repaired tile.
    expect(_distinctBuffers(shared), 5);
    // The same stored bytes.
    expect(
      identical(shared[drawing[0]]!['1,0'], shared[drawing[1]]!['1,0']),
      isTrue,
    );
    // The same pixels stored another way.
    expect(
      identical(shared[drawing[0]]!['0,0'], shared[drawing[1]]!['0,0']),
      isTrue,
    );
    // The same CRC-32, other pixels.
    expect(
      identical(shared[drawing[0]]!['1,0'], shared[drawing[2]]!['1,0']),
      isFalse,
    );
    // Repaired copies.
    expect(identical(shared[old[0]]!['0,0'], shared[old[2]]!['0,0']), isTrue);
  });

  test('a shared tile of an opened work is drawn on through a copy of its '
      'own, and reading it gives a buffer that cannot be written', () async {
    final work = await savedWork(temp);
    final service = ProjectService();
    await service.init();
    addTearDown(service.dispose);
    final tiles = service.tileManagerOf(work.id);
    String key(int frame) => work.drawing[frame];
    final before = _copy(tiles.exportAll());

    expect(
      () => tiles.getTile(key(1), 0, 0)!.setRange(0, 4, [1, 2, 3, 255]),
      throwsUnsupportedError,
    );
    tiles.getOrCreateTile(key(1), 0, 0).setRange(0, 4, [1, 2, 3, 255]);
    tiles.getTile(key(1), 0, 0)!.setRange(4, 8, [4, 5, 6, 255]);

    final after = tiles.exportAll();
    expect(after[key(1)]!['0,0']!.sublist(0, 8), [1, 2, 3, 255, 4, 5, 6, 255]);
    for (final layer in before.keys) {
      for (final tile in before[layer]!.keys) {
        if (layer == key(1) && tile == '0,0') continue;
        expect(after[layer]![tile], before[layer]![tile], reason: layer);
      }
    }
  });

  test('drawing, undo and redo, copying and removing frames, saving, '
      'autosaving, exporting and .niashare give the same bytes as reading '
      'every tile into a buffer of its own', () async {
    final template = Directory('${temp.path}/template')..createSync();
    final work = await savedWork(template);

    Future<Map<String, Object>> run(bool share) async {
      final dir = Directory('${temp.path}/run-$share')..createSync();
      for (final entity in template.listSync(recursive: true)) {
        if (entity is! File) continue;
        final relative = entity.path.substring(template.path.length);
        File('${dir.path}$relative')
          ..createSync(recursive: true)
          ..writeAsBytesSync(entity.readAsBytesSync());
      }
      useRoot(dir);
      SharedPreferences.setMockInitialValues({});
      NiaproSerializer.debugShareIdenticalTiles = share;
      final results = <String, Object>{};
      final autosaves = AutosaveService();
      await autosaves.init();
      final service = ProjectService(autosaves);
      await service.init();
      final undo = UndoManager();
      service.setUndoManager(undo);
      undo.selectProject(work.id);
      final id = work.id;
      final tiles = service.tileManagerOf(id);
      results['opened'] = _copy(tiles.exportAll());

      void stroke(int frame, List<int> colour) {
        final layer = service
            .scenesOf(id)
            .first
            .frames[frame]
            .layers
            .firstWhere((l) => l.type == LayerType.normal && l.name != 'old');
        final key = service.tileKeyFor(id, work.scene, frame, layer.id);
        tiles.beginUndoRecording(key);
        tiles.getOrCreateTile(key, 0, 0).setRange(400, 404, colour);
        tiles.getOrCreateTile(key, 1, 0).setRange(800, 804, colour);
        final recorded = tiles.endUndoRecording();
        undo.push(
          TileUndoAction(
            tileManager: tiles,
            layerId: key,
            before: recorded.before,
            after: recorded.after,
            onApply: () {},
          ),
          projectId: id,
        );
      }

      stroke(1, [9, 8, 7, 255]);
      results['drawn'] = _copy(tiles.exportAll());
      undo.undo(projectId: id);
      results['undone'] = _copy(tiles.exportAll());
      undo.redo(projectId: id);
      results['redone'] = _copy(tiles.exportAll());

      service.duplicateFrame(id, work.scene, 2);
      results['copied frame'] = _copy(tiles.exportAll());
      stroke(3, [1, 1, 200, 255]);
      service.removeFrame(id, work.scene, 0);
      results['removed frame'] = _copy(tiles.exportAll());
      undo.undo(projectId: id);
      undo.undo(projectId: id);
      results['undone frames'] = _copy(tiles.exportAll());
      undo.redo(projectId: id);
      undo.redo(projectId: id);
      stroke(0, [50, 60, 70, 255]);
      results['redone frames'] = _copy(tiles.exportAll());

      await autosaves.save(id, service, skipUnchanged: true);
      results['autosave'] = _stored(
        '${dir.path}/niarim/projects/$id/autosave/'
        'slot_${autosaves.slots.last.slotIndex}.niapro',
      );
      await service.saveProject(id);
      results['saved'] = _stored(workFile(id));

      final project = service.projects.singleWhere((p) => p.id == id);
      final exported = <String, Uint8List>{};
      for (final scene in service.scenesOf(id)) {
        for (final frame in scene.frames) {
          exported['${scene.id}#${frame.index}'] = await ExportEngine()
              .renderFrame(
                layers: frame.layers,
                tileManager: tiles,
                sceneId: scene.id,
                frameIndex: frame.index,
                drawingWidth: project.drawingWidth,
                drawingHeight: project.drawingHeight,
                width: project.exportWidth,
                height: project.exportHeight,
                backgroundColor: project.backgroundColor,
                layerHomes: service.layerHomesOf(id),
                scene: scene,
              );
        }
      }
      results['exported'] = exported;
      final share0 = await NiaproSerializer.saveShare(
        project: project,
        scenes: service.scenesOf(id),
        tileManager: tiles,
        outputDir: dir.path,
      );
      results['niashare'] = _stored(share0.path);
      service.dispose();
      autosaves.dispose();

      final reopened = ProjectService();
      await reopened.init();
      results['reopened'] = _copy(reopened.tileManagerOf(id).exportAll());
      reopened.dispose();
      return results;
    }

    final shared = await run(true);
    final own = await run(false);
    expect(shared.keys, own.keys);
    for (final step in own.keys) {
      expect(shared[step], own[step], reason: step);
    }
    // The steps did change the picture.
    expect(own['drawn'], isNot(own['opened']));
    expect(own['undone'], own['opened']);
  });
}
