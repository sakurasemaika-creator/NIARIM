// 自動保存と作品の保存は、変わったタイルだけを圧縮し、ほかは保存されている
// まま写す。
//
// 実際に使ってみたとき（2026-11-27）、描くのを止めて5秒たつたびに自動保存が
// 画面の処理と同じ所で「前回の自動保存を全部展開して比べる→全部のタイルを
// 圧縮し直す」をしていて、描き込んだタイル200枚で約4秒、画面が止まった
// （止まっている間のペンの点が落ち、円の後半が直線になった）。作品の保存も、
// 変わっていないタイルまで展開して圧縮し直し、作品を開くと全部のタイルが
// 「変わった」ことになっていた。
//
// 写したか圧縮し直したかは、元のファイルの1タイルを無圧縮で入れておき、
// 保存の後も無圧縮のまま残るかで見分ける（同じ中身を圧縮し直すと同じ
// バイト列になるので、バイト列の比較では見分けられない）。
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/autosave_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _size = TileManager.tileSize;

Uint8List _tile(int seed) {
  final pixels = Uint8List(_size * _size * 4);
  for (var i = 0; i < _size * _size; i++) {
    final alpha = (i * 7 + seed) % 256;
    pixels[i * 4] = alpha ~/ 2;
    pixels[i * 4 + 1] = alpha ~/ 3;
    pixels[i * 4 + 2] = alpha;
    pixels[i * 4 + 3] = alpha;
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

Map<String, ArchiveFile> _entries(String path) => {
  for (final f in ZipDecoder().decodeBytes(File(path).readAsBytesSync()).files)
    if (f.isFile) f.name: f,
};

/// Rewrites the zip at [path] with the entries ending in [suffix] stored
/// uncompressed (every other entry as it was).
void _storeUncompressed(String path, String suffix) {
  final out = Archive();
  for (final f
      in ZipDecoder().decodeBytes(File(path).readAsBytesSync()).files) {
    if (!f.isFile) continue;
    final bytes = f.content as List<int>;
    out.addFile(
      f.name.endsWith(suffix)
          ? ArchiveFile.noCompress(f.name, bytes.length, bytes)
          : ArchiveFile(f.name, bytes.length, bytes),
    );
  }
  File(path).writeAsBytesSync(ZipEncoder().encode(out)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-autosave-incremental-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String workFile(String id) => '${temp.path}/niarim/projects/$id/$id.niapro';
  String slotFile(String id, int slot) =>
      '${temp.path}/niarim/projects/$id/autosave/slot_$slot.niapro';

  /// A saved work with two painted tiles whose tile "1,1" is stored
  /// uncompressed; its id and layer key.
  Future<(String, String)> savedWork() async {
    final service = ProjectService();
    await service.init();
    final project = await service.createProject(
      name: '作品',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 640,
      exportHeight: 360,
    );
    final scene = service.scenesOf(project.id).first;
    final layer = scene.frames.first.layers.firstWhere(
      (l) => l.type == LayerType.normal,
    );
    final key = frameLayerKey(scene.id, 0, layer.id);
    service.tileManagerOf(project.id).importAll({
      key: {'0,0': _tile(1), '1,1': _tile(2)},
    });
    await service.saveProject(project.id);
    service.dispose();
    _storeUncompressed(workFile(project.id), '_1,1.bin');
    return (project.id, key);
  }

  Future<ProjectService> started([AutosaveService? autosaves]) async {
    final service = ProjectService(autosaves);
    await service.init();
    addTearDown(service.dispose);
    return service;
  }

  ArchiveFile tileEntry(Map<String, ArchiveFile> entries, String tile) =>
      entries.entries.singleWhere((e) => e.key.endsWith('_$tile.bin')).value;

  test('opening a work marks none of its tiles as changed', () async {
    final (id, _) = await savedWork();
    final service = await started();
    expect(service.tileManagerOf(id).hasDirtyTiles, isFalse);
  });

  test('saving an opened work writes the changed tile and copies the others '
      'as stored', () async {
    final (id, key) = await savedWork();
    final service = await started();
    final tiles = service.tileManagerOf(id);
    tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, [9, 9, 9, 255]);
    final expected = _copy(tiles.exportAll());
    await service.saveProject(id);

    final saved = _entries(workFile(id));
    expect(
      tileEntry(saved, '1,1').isCompressed,
      isFalse,
      reason: 'the unchanged tile was expanded and compressed again',
    );
    expect(tileEntry(saved, '0,0').isCompressed, isTrue);
    expect(tiles.hasDirtyTiles, isFalse);
    final next = await started();
    expect(next.tileManagerOf(id).exportAll(), expected);
  });

  test('automatic saves write only the tiles changed since the last one and '
      'skip when nothing changed', () async {
    final (id, key) = await savedWork();
    final autosaves = AutosaveService();
    addTearDown(autosaves.dispose);
    await autosaves.init();
    final service = await started(autosaves);
    final tiles = service.tileManagerOf(id);

    // Opened and not changed: the work file already keeps it.
    await autosaves.save(id, service, skipUnchanged: true);
    expect(autosaves.slots, isEmpty);

    // The first automatic save copies the unchanged tile from the work file.
    tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, [10, 20, 30, 255]);
    await autosaves.save(id, service, skipUnchanged: true);
    expect(autosaves.slots, hasLength(1));
    final first = autosaves.slots.last.slotIndex;
    var slot = _entries(slotFile(id, first));
    expect(tileEntry(slot, '1,1').isCompressed, isFalse);
    expect(tileEntry(slot, '0,0').isCompressed, isTrue);
    expect(
      (await NiaproSerializer.loadAutosave(id, first)).tileData,
      _copy(tiles.exportAll()),
    );

    // The next one copies from the last automatic save what did not change.
    _storeUncompressed(slotFile(id, first), '_0,0.bin');
    tiles.getOrCreateTile(key, 1, 1).setRange(0, 4, [40, 50, 60, 255]);
    await autosaves.save(id, service, skipUnchanged: true);
    expect(autosaves.slots, hasLength(2));
    final second = autosaves.slots.last.slotIndex;
    slot = _entries(slotFile(id, second));
    expect(tileEntry(slot, '0,0').isCompressed, isFalse);
    expect(tileEntry(slot, '1,1').isCompressed, isTrue);
    expect(
      (await NiaproSerializer.loadAutosave(id, second)).tileData,
      _copy(tiles.exportAll()),
    );

    // Nothing changed since: no new automatic save.
    await autosaves.save(id, service, skipUnchanged: true);
    expect(autosaves.slots, hasLength(2));

    // A change of the scenes alone is saved.
    final scene = service.scenesOf(id).first;
    service.updateLayer(
      projectId: id,
      sceneId: scene.id,
      frameIndex: 0,
      layer: scene.frames.first.layers.first.copyWith(name: '名前を変えた'),
    );
    await autosaves.save(id, service, skipUnchanged: true);
    expect(autosaves.slots, hasLength(3));
    final renamed = await NiaproSerializer.loadAutosave(
      id,
      autosaves.slots.last.slotIndex,
    );
    expect(renamed.scenes.first.frames.first.layers.first.name, '名前を変えた');
    expect(renamed.tileData, _copy(tiles.exportAll()));
  });

  test('an automatic save leaves the changed tiles to the next save of the '
      'work file', () async {
    final (id, key) = await savedWork();
    final autosaves = AutosaveService();
    addTearDown(autosaves.dispose);
    await autosaves.init();
    final service = await started(autosaves);
    final tiles = service.tileManagerOf(id);
    tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, [70, 80, 90, 255]);
    final expected = _copy(tiles.exportAll());
    await autosaves.save(id, service, skipUnchanged: true);
    expect(tiles.hasDirtyTiles, isTrue);

    await service.saveProject(id);
    final next = await started();
    expect(next.tileManagerOf(id).exportAll(), expected);
  });
}
