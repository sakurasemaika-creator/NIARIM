// 消したレイヤー（タイムラインの素材クリップを含む）の絵は、作品のファイルと
// 自動保存に書かない。取り消しで戻したら、次の保存でまた書く。
//
// 実際に使ってみたとき（2026-11-27）、消した素材クリップ（貼り付けた画像・
// 文字）のタイルが、どのコマからも使われていないのに作品のファイルと自動保存に
// 残り続け、ファイルが大きくなる一方だった。消したレイヤーの絵は取り消しで
// 戻せるようにメモリに残しておくが、保存は全部のタイルを書いていた。
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show MethodChannel, Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _size = TileManager.tileSize;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-removed-layer-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('a removed layer\'s tiles are left out of the saves until Undo brings '
      'the layer back', () async {
    final service = ProjectService();
    await service.init();
    addTearDown(service.dispose);
    final undo = UndoManager();
    service.setUndoManager(undo);
    final project = await service.createProject(
      name: '消したレイヤー',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 640,
      exportHeight: 360,
    );
    undo.selectProject(project.id);
    final scene = service.scenesOf(project.id).first;
    final kept = scene.frames.first.layers.firstWhere(
      (l) => l.type == LayerType.normal,
    );
    final removed = service.addLayer(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'removed',
    );
    Uint8List paint(int value) =>
        Uint8List(_size * _size * 4)..fillRange(0, _size * _size * 4, value);
    service.tileManagerOf(project.id).importAll({
      frameLayerKey(scene.id, 0, kept.id): {'0,0': paint(100)},
      frameLayerKey(scene.id, 0, removed.id): {
        '0,0': paint(200),
        '1,0': paint(201),
      },
    });
    await service.saveProject(project.id);

    final workFile = File(
      '${temp.path}/niarim/projects/${project.id}/${project.id}.niapro',
    );
    Set<String> tileEntries(File file) => {
      for (final f in ZipDecoder().decodeBytes(file.readAsBytesSync()).files)
        if (f.name.startsWith('Tiles/')) f.name,
    };
    String entry(String layerId, String tile) =>
        'Tiles/${scene.id}/0/${layerId}_$tile.bin';
    expect(tileEntries(workFile), contains(entry(removed.id, '1,0')));

    service.removeLayer(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      layerId: removed.id,
    );
    await service.saveProject(project.id);
    expect(tileEntries(workFile), {entry(kept.id, '0,0')});

    final autosave = await NiaproSerializer.saveAutosaveFrom(
      project: service.projects.singleWhere((p) => p.id == project.id),
      scenes: service.scenesOf(project.id),
      tileManager: service.tileManagerOf(project.id),
      slotIndex: 0,
      base: null,
    );
    expect(tileEntries(autosave), {entry(kept.id, '0,0')});

    // Undo brings the layer back; its tiles are written again.
    undo.undo(projectId: project.id);
    expect(
      service.layersOf(project.id, scene.id, 0).map((l) => l.id),
      contains(removed.id),
    );
    await service.saveProject(project.id);
    expect(tileEntries(workFile), {
      entry(kept.id, '0,0'),
      entry(removed.id, '0,0'),
      entry(removed.id, '1,0'),
    });
    final reopened = await NiaproSerializer.load(workFile.path);
    expect(
      reopened.tileData[frameLayerKey(scene.id, 0, removed.id)]?['1,0'],
      paint(201),
    );
  });
}
