// 大きな作品を開いたとき、使っていないタイルは圧縮したまま持ち、使うときに
// 展開する（展開して持つタイルは端末のメモリから決めた数まで）。
//
// 1920×1080で約125コマ分（同じ画素をまとめた後のタイル約5000枚、1枚256KB）を
// 全部展開して持つと、3〜4GBの端末では開いただけで強制終了しうった。ここでは、
// 展開して持てる数をとても小さくして（ほとんどのタイルを圧縮したまま持たせて）、
// 開く・描く・取り消す・コマの複製と削除・保存・自動保存・書き出し・.niashare・
// メイキング・作品の複製の結果が、全部を展開して持ったときと1バイトも変わらない
// ことを確かめる。
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/making_log.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/autosave_service.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/making_recorder.dart';
import 'package:niarim/services/making_service.dart';
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
/// reader repairs it.
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

/// Every entry of the zip at [path] as stored ([leaveOut] entries are not
/// compared: they hold the time of the save).
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

/// The tiles each manager keeps expanded and compressed (from the tiles of
/// its layer snapshot).
({int expanded, int compressed}) _held(TileManager tiles) {
  final seen = <StoredTile>{};
  var expanded = 0, compressed = 0;
  for (final layer in tiles.structuralSnapshot().values) {
    for (final tile in layer.values) {
      if (!seen.add(tile)) continue;
      if (TileManager.isExpanded(tile)) {
        expanded++;
      } else {
        compressed++;
      }
    }
  }
  return (expanded: expanded, compressed: compressed);
}

/// Lets the tile manager compress the tiles past the budget.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

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
    temp = Directory.systemTemp.createTempSync('niarim-compressed-tiles-');
    SharedPreferences.setMockInitialValues({});
    TileManager.debugExpandedTileBudget = null;
  });
  tearDown(() {
    TileManager.debugExpandedTileBudget = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String workFile(String id) => '${root.path}/niarim/projects/$id/$id.niapro';

  /// A saved 1024×512 work (8 tiles a layer) of 4 frames copied from the
  /// first and partly redrawn, its scene copied, with an entry stored
  /// uncompressed and a tile that is repaired on reading.
  Future<({String id, String scene})> savedWork(Directory dir) async {
    useRoot(dir);
    final service = ProjectService();
    await service.init();
    final project = await service.createProject(
      name: '大きな作品',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 1024,
      exportHeight: 512,
      makingEnabled: true,
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
    for (var t = 0; t < 8; t++) {
      tiles
          .getOrCreateTile(key(0, old: false), t % 4, t ~/ 4)
          .setAll(0, _tile(t + 1));
    }
    tiles.getOrCreateTile(key(0, old: true), 0, 0).setAll(0, _unrepairedTile());
    tiles.getOrCreateTile(key(0, old: true), 3, 1).setAll(0, _tile(40));
    final frames = service.scenesOf(id).first.frames.length;
    for (var f = frames - 1; f >= 1; f--) {
      service.removeFrame(id, sceneId, f);
    }
    for (var f = 0; f < 3; f++) {
      service.duplicateFrame(id, sceneId, f);
      tiles
          .getOrCreateTile(key(f + 1, old: false), f, 1)
          .setAll(0, _tile(20 + f));
    }
    service.duplicateScene(id, sceneId);
    await service.saveProject(id);
    await service.settleWrites();
    service.dispose();

    // One entry stored as it is (uncompressed).
    final layerId = parseFrameLayerKey(key(1, old: false))!.layerId;
    final uncompressed = 'Tiles/$sceneId/1/${layerId}_1,0.bin';
    final source = ZipDecoder().decodeBytes(
      File(workFile(id)).readAsBytesSync(),
    );
    final out = Archive();
    for (final f in source.files) {
      if (!f.isFile) continue;
      final bytes = f.content as List<int>;
      out.addFile(
        f.name == uncompressed
            ? ArchiveFile.noCompress(f.name, bytes.length, bytes)
            : ArchiveFile(f.name, bytes.length, bytes),
      );
    }
    File(workFile(id)).writeAsBytesSync(ZipEncoder().encode(out)!);
    return (id: id, scene: sceneId);
  }

  test('a work read with a tiny budget gives the same tiles and checksums, '
      'most of them kept compressed', () async {
    final work = await savedWork(temp);
    final path = workFile(work.id);
    final expandedCrcs = <String, int>{};
    final expanded = NiaproSerializer.loadTilesSync(path, crcs: expandedCrcs);

    TileManager.debugExpandedTileBudget = 3;
    final storedCrcs = <String, int>{};
    final stored = NiaproSerializer.loadStoredTilesSync(path, crcs: storedCrcs);
    final tiles = TileManager(canvasWidth: 1024, canvasHeight: 512)
      ..importStoredTiles(stored, storedCrcs: storedCrcs);

    expect(storedCrcs, expandedCrcs);
    expect(tiles.exportAll(), expanded);
    final held = _held(tiles);
    expect(held.expanded, lessThanOrEqualTo(3));
    expect(held.compressed, greaterThanOrEqualTo(held.expanded + 7));
    // Reading through exportAll expands nothing to keep.
    expect(_held(tiles).expanded, held.expanded);
  });

  test('drawing, undo and redo, copying and removing frames, saving, '
      'autosaving, exporting, .niashare, the making and copying the work '
      'give the same bytes as holding every tile expanded', () async {
    final template = Directory('${temp.path}/template')..createSync();
    final work = await savedWork(template);
    final brush = BrushService.builtInBrushes.firstWhere(
      (b) => b.id == 'Brush0001',
    );

    Future<Map<String, Object>> run(int? budget) async {
      final dir = Directory('${temp.path}/run-$budget')..createSync();
      for (final entity in template.listSync(recursive: true)) {
        if (entity is! File) continue;
        final relative = entity.path.substring(template.path.length);
        File('${dir.path}$relative')
          ..createSync(recursive: true)
          ..writeAsBytesSync(entity.readAsBytesSync());
      }
      useRoot(dir);
      SharedPreferences.setMockInitialValues({});
      TileManager.debugExpandedTileBudget = budget;
      final compressionsBefore = TileManager.debugCompressions;
      final results = <String, Object>{};
      final autosaves = AutosaveService();
      await autosaves.init();
      final service = ProjectService(autosaves);
      await service.init();
      final undo = UndoManager();
      service.setUndoManager(undo);
      undo.selectProject(work.id);
      final recorder = MakingRecorder(service, undo);
      final id = work.id;
      final tiles = service.tileManagerOf(id);
      results['opened'] = _copy(tiles.exportAll());
      results['stored crcs'] = {
        for (final layer in tiles.layerKeys)
          for (final tile in tiles.tileKeysOf(layer))
            '$layer:$tile': tiles.storedCrc(layer, tile),
      };
      await _settle();

      String keyOf(int frame) {
        final layer = service
            .scenesOf(id)
            .first
            .frames[frame]
            .layers
            .firstWhere((l) => l.type == LayerType.normal && l.name != 'old');
        return service.tileKeyFor(id, work.scene, frame, layer.id);
      }

      void push(
        String key,
        ({Map<String, Uint8List?> before, Map<String, Uint8List?> after})
        recorded,
      ) {
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

      // Written pixel by pixel, as the bucket and the blur do.
      Future<void> stroke(int frame, List<int> colour) async {
        final key = keyOf(frame);
        tiles.beginUndoRecording(key);
        tiles.getOrCreateTile(key, 0, 0).setRange(400, 404, colour);
        tiles.getOrCreateTile(key, 3, 1).setRange(800, 804, colour);
        push(key, tiles.endUndoRecording());
        await _settle();
      }

      // A brush stroke over several tiles, with the trims between its points.
      Future<void> brushStroke(int frame) async {
        final key = keyOf(frame);
        final engine = DrawingEngine(tileManager: tiles)
          ..currentColor = Colors.black
          ..currentBrush = brush
          ..pressureEnabled = false;
        tiles.beginUndoRecording(key);
        engine.beginStroke(const StrokePoint(x: 30, y: 40), key);
        for (var p = 1; p <= 40; p++) {
          engine.continueStroke(
            StrokePoint(x: 30.0 + p * 24, y: 40.0 + p * 10),
            key,
          );
          await _settle();
        }
        engine.endStroke();
        push(key, tiles.endUndoRecording());
        await _settle();
      }

      await stroke(1, [9, 8, 7, 255]);
      await brushStroke(2);
      results['drawn'] = _copy(tiles.exportAll());
      // Written through the reading buffer of a tile of its own (drawn on
      // above, and compressed since), and marked: the change is kept when
      // the tile is compressed again.
      final read = tiles.getTile(keyOf(1), 0, 0)!;
      read.setRange(0, 8, [1, 2, 3, 255, 4, 5, 6, 255]);
      tiles.invalidateTile(keyOf(1), 0, 0);
      await _settle();
      results['written'] = _copy(tiles.exportAll());
      undo.undo(projectId: id);
      await _settle();
      results['undone'] = _copy(tiles.exportAll());
      undo.redo(projectId: id);
      await _settle();
      results['redone'] = _copy(tiles.exportAll());

      service.duplicateFrame(id, work.scene, 2);
      await _settle();
      results['copied frame'] = _copy(tiles.exportAll());
      await stroke(3, [1, 1, 200, 255]);
      service.removeFrame(id, work.scene, 0);
      await _settle();
      results['removed frame'] = _copy(tiles.exportAll());
      undo.undo(projectId: id);
      undo.undo(projectId: id);
      await _settle();
      results['undone frames'] = _copy(tiles.exportAll());
      undo.redo(projectId: id);
      undo.redo(projectId: id);
      await stroke(0, [50, 60, 70, 255]);
      results['redone frames'] = _copy(tiles.exportAll());

      await autosaves.save(id, service, skipUnchanged: true);
      results['autosave'] = _stored(
        '${dir.path}/niarim/projects/$id/autosave/'
        'slot_${autosaves.slots.last.slotIndex}.niapro',
      );
      await service.saveProject(id);
      await service.settleWrites();
      results['saved'] = _stored(workFile(id));
      await stroke(1, [70, 20, 90, 255]);
      await service.saveProject(id);
      await service.settleWrites();
      results['saved again'] = _stored(workFile(id));

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
      final share = await NiaproSerializer.saveShare(
        project: project,
        scenes: service.scenesOf(id),
        tileManager: tiles,
        outputDir: dir.path,
      );
      results['niashare'] = _stored(share.path);

      await recorder.flush();
      final logDir = await MakingService.logDirectory(id);
      final log = MakingLogData.read(logDir);
      results['making steps'] = [
        for (final step in log.steps)
          {
            'frame': '${step.sceneId}#${step.frameIndex}',
            'structure': step.structure,
            'tiles': [
              for (final t in step.tiles)
                '${t.layerKey}:${t.tileKey}@${t.offset}+${t.length}',
            ],
          },
      ];
      results['making blobs'] = File(
        '$logDir/${MakingLog.blobsFile}',
      ).readAsBytesSync();

      final before = service.projects.map((p) => p.id).toSet();
      await service.duplicateProject(id);
      await service.settleWrites();
      final copyId = service.projects
          .map((p) => p.id)
          .firstWhere((p) => !before.contains(p));
      results['copied work'] = _copy(service.tileManagerOf(copyId).exportAll());
      results['copied work file'] = _stored(workFile(copyId));

      if (budget != null) {
        expect(
          TileManager.debugCompressions - compressionsBefore,
          greaterThan(20),
          reason: 'the run kept tiles compressed',
        );
        expect(_held(tiles).expanded, lessThanOrEqualTo(budget + 8));
      }
      recorder.dispose();
      service.dispose();
      autosaves.dispose();
      await MakingLogWriter.forget(logDir);

      final reopened = ProjectService();
      await reopened.init();
      results['reopened'] = _copy(reopened.tileManagerOf(id).exportAll());
      reopened.dispose();
      return results;
    }

    final compressed = await run(3);
    final expanded = await run(null);
    expect(compressed.keys, expanded.keys);
    for (final step in expanded.keys) {
      expect(compressed[step], expanded[step], reason: step);
    }
    // The steps did change the picture.
    expect(expanded['drawn'], isNot(expanded['opened']));
    expect(expanded['written'], isNot(expanded['drawn']));
    expect(expanded['undone'], isNot(expanded['written']));
    expect(expanded['redone'], expanded['written']);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
