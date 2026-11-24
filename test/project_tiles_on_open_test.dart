// 作品の絵（タイル）は、作品を開いたときに読む。
//
// 起動のときに全部の作品の絵をメモリへ読むと、長い作品が数本ある端末で
// 起動の途中にメモリが尽きた（1920×1080の1コマ1レイヤーで最大8MB）。
// 一覧に出すときは作品の情報とシーンだけを読み、絵は開いたときに読む。
// 開いていない作品を保存し直しても（名前の変更・ゴミ箱へ移す前の保存）
// 絵はファイルのまま残り、開いたときに読めなかった作品はファイルを
// 上書きしない。
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-tiles-on-open-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A saved work with two painted tiles; its id and tiles.
  Future<(String, Map<String, Map<String, Uint8List>>)> savedWork() async {
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
    final tiles = service.tileManagerOf(project.id);
    tiles.importAll({
      frameLayerKey(scene.id, 0, layer.id): {'0,0': _tile(1), '1,1': _tile(2)},
    });
    await service.saveProject(project.id);
    final saved = _copy(tiles.exportAll());
    service.dispose();
    return (project.id, saved);
  }

  Future<ProjectService> started() async {
    final service = ProjectService();
    await service.init();
    addTearDown(service.dispose);
    return service;
  }

  test('listing a work reads no tiles; opening it reads them', () async {
    final (id, saved) = await savedWork();
    final service = await started();
    expect(service.projects.map((p) => p.id), contains(id));
    expect(service.tilesRead(id), isFalse);
    expect(service.tileManagerOf(id).exportAll(), saved);
    expect(service.tilesRead(id), isTrue);
  });

  test('saving a work that was not opened keeps its picture', () async {
    final (id, saved) = await savedWork();
    final service = await started();
    await service.renameProject(id, '名前を変えた作品');
    await service.saveProject(id);
    expect(
      service.tilesRead(id),
      isFalse,
      reason: 'saving the work read its picture into memory',
    );

    final next = await started();
    expect(next.projects.singleWhere((p) => p.id == id).name, '名前を変えた作品');
    expect(next.tileManagerOf(id).exportAll(), saved);
  });

  test('moving a work that was not opened to the trash and back keeps its '
      'picture', () async {
    final (id, saved) = await savedWork();
    final service = await started();
    await service.deleteProject(id);
    expect(service.trash.map((p) => p.id), contains(id));
    await service.restoreProject(id);
    expect(service.tileManagerOf(id).exportAll(), saved);

    final next = await started();
    expect(next.tileManagerOf(id).exportAll(), saved);
  });

  test('a work whose picture cannot be read when it is opened is never saved '
      'over', () async {
    final (id, _) = await savedWork();
    final service = await started();
    final file = File('${temp.path}/niarim/projects/$id/$id.niapro');
    final broken = Uint8List.fromList(List.generate(4096, (i) => i % 251));
    file.writeAsBytesSync(broken);

    expect(service.tileManagerOf(id).exportAll(), isEmpty);
    expect(service.tilesUnreadable(id), isTrue);
    await expectLater(
      service.saveProject(id),
      throwsA(isA<FileSystemException>()),
    );
    expect(file.readAsBytesSync(), broken);
    final count = service.projects.length;
    await expectLater(
      service.duplicateProject(id),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      service.projects,
      hasLength(count),
      reason: 'an empty copy was made',
    );
  });
}
