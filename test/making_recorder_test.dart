// メイキングは取り消しの履歴の変化ごとに、変わったタイルだけを記録する
// （所有者の依頼、2026-11-27「取り消した部分も入れておいてほしいです。メイキングの
// 記録方法は最も軽量になる方法を模索してください」）。
//
// 以前は描くたびにコマ全体を合成し、720pxのJPEGにして保存していた（1秒に1枚まで。
// 取り消し・やり直しは記録しない）。今は描いている間に絵を作らず、変わったタイルを
// 写して裏で圧縮して足すだけで、同じ中身のタイルは1回しか保存しない（取り消し・
// やり直しは前に保存したタイルを指すだけ）。絵は再生・書き出しのときに作る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/making_log.dart';
import 'package:niarim/engine/making_player.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/making_recorder.dart';
import 'package:niarim/services/making_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _red = [220, 30, 40, 255];
const _blue = [30, 60, 220, 255];
const _green = [20, 160, 60, 255];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-making-recorder-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A running app's work services: the projects, the history and the
  /// recorder.
  Future<(ProjectService, UndoManager, MakingRecorder)> started() async {
    final projects = ProjectService();
    await projects.init();
    final history = UndoManager();
    projects.setUndoManager(history);
    final recorder = MakingRecorder(projects, history);
    addTearDown(() {
      recorder.dispose();
      projects.dispose();
    });
    return (projects, history, recorder);
  }

  Future<(String, String)> newWork(ProjectService projects) async {
    final project = await projects.createProject(
      name: 'メイキング',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 640,
      exportHeight: 360,
      makingEnabled: true,
    );
    final scene = projects.scenesOf(project.id).first;
    final layer = scene.frames.first.layers.firstWhere(
      (l) => l.type == LayerType.normal,
    );
    return (project.id, frameLayerKey(scene.id, 0, layer.id));
  }

  /// Paints tile [tx],[ty] of [key] with [colour] as one operation in the
  /// history (like a stroke on the canvas).
  void paint(
    ProjectService projects,
    UndoManager history,
    String id,
    String key,
    int tx,
    int ty,
    List<int> colour,
  ) {
    final tiles = projects.tileManagerOf(id);
    final tileKey = '$tx,$ty';
    final before = tiles.layerTiles(key)[tileKey];
    final beforeCopy = before == null ? null : Uint8List.fromList(before);
    final tile = tiles.getOrCreateTile(key, tx, ty);
    for (var i = 0; i < tile.length; i += 4) {
      tile.setRange(i, i + 4, colour);
    }
    history.push(
      TileUndoAction(
        tileManager: tiles,
        layerId: key,
        before: {tileKey: beforeCopy},
        after: {tileKey: Uint8List.fromList(tile)},
        onApply: () {},
      ),
      projectId: id,
    );
  }

  Future<MakingLogData> log(String id) async =>
      MakingLogData.read(await MakingService.logDirectory(id));

  Future<int> blobBytes(String id) async {
    final file = File(
      '${await MakingService.logDirectory(id)}/${MakingLog.blobsFile}',
    );
    return file.existsSync() ? file.lengthSync() : 0;
  }

  test('every operation, Undo and Redo is a step; Undo and Redo point at '
      'tiles already stored', () async {
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);

    paint(projects, history, id, key, 0, 0, _red);
    await recorder.flush();
    paint(projects, history, id, key, 0, 0, _blue);
    await recorder.flush();
    final stored = await blobBytes(id);
    history.undo(projectId: id);
    await recorder.flush();
    history.redo(projectId: id);
    await recorder.flush();

    final steps = (await log(id)).steps;
    expect(steps, hasLength(4));
    int offsetOf(MakingLogStep step) =>
        step.tiles.singleWhere((t) => t.tileKey == '0,0').offset!;
    expect(offsetOf(steps[2]), offsetOf(steps[0]), reason: 'Undo → red');
    expect(offsetOf(steps[3]), offsetOf(steps[1]), reason: 'Redo → blue');
    expect(
      await blobBytes(id),
      stored,
      reason: 'Undo and Redo stored no tile again',
    );
    // Only the changed tile is in each step (nothing else of the canvas).
    for (final step in steps) {
      expect(step.tiles.map((t) => t.tileKey), ['0,0']);
    }
  });

  test('several changes in one go make one step', () async {
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    paint(projects, history, id, key, 0, 0, _red);
    paint(projects, history, id, key, 1, 0, _blue);
    await recorder.flush();
    final steps = (await log(id)).steps;
    expect(steps, hasLength(1));
    expect(steps.single.tiles.map((t) => t.tileKey).toSet(), {'0,0', '1,0'});
  });

  test('the player makes each step\'s picture, Undo included, on the '
      'work\'s paper', () async {
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    paint(projects, history, id, key, 0, 0, _red);
    await recorder.flush();
    paint(projects, history, id, key, 0, 0, _blue);
    await recorder.flush();
    history.undo(projectId: id);
    await recorder.flush();

    final player = await MakingPlayer.open(id);
    addTearDown(player.dispose);
    expect(player.length, 3);
    Future<List<int>> pixel(int index, int x, int y) async {
      final image = await player.render(index);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final at = (y * image.width + x) * 4;
      final rgba = [for (var c = 0; c < 4; c++) data.getUint8(at + c)];
      image.dispose();
      return rgba;
    }

    expect(await pixel(0, 10, 10), _red);
    expect(await pixel(1, 10, 10), _blue);
    expect(await pixel(2, 10, 10), _red, reason: 'the Undo is shown');
    expect(await pixel(2, 600, 300), [255, 255, 255, 255], reason: 'paper');
    // Back to an earlier step (the slider) still shows that step.
    expect(await pixel(1, 10, 10), _blue);

    // Export: the pictures are written as JPEG files, in order.
    final out = Directory('${temp.path}/pictures')..createSync();
    final paths = await player.writePictures(out);
    expect(paths, hasLength(3));
    final second = img.decodeJpg(File(paths[1]).readAsBytesSync())!;
    final p = second.getPixel(10, 10);
    expect((p.b - _blue[2]).abs(), lessThan(12));
    expect((p.r - _blue[0]).abs(), lessThan(12));
  });

  test('nothing is recorded while the making is off; the changes made '
      'meanwhile come with the next step after it is on', () async {
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    await projects.setMakingEnabled(id, false);
    paint(projects, history, id, key, 0, 0, _red);
    await recorder.flush();
    expect((await log(id)).steps, isEmpty);

    await projects.setMakingEnabled(id, true);
    paint(projects, history, id, key, 1, 0, _blue);
    await recorder.flush();
    final steps = (await log(id)).steps;
    expect(steps, hasLength(1));
    expect(steps.single.tiles.map((t) => t.tileKey).toSet(), {'0,0', '1,0'});
  });

  test('a work opened again: unchanged tiles are confirmed by the work '
      'file\'s checksum, tiles changed while the making was off are '
      'recorded', () async {
    late String id;
    late String key;
    late String dir;
    {
      final (projects, history, recorder) = await started();
      (id, key) = await newWork(projects);
      dir = await MakingService.logDirectory(id);
      paint(projects, history, id, key, 0, 0, _red);
      await recorder.flush();
      // Switched off, a tile changes and the work is saved.
      await projects.setMakingEnabled(id, false);
      paint(projects, history, id, key, 0, 1, _green);
      await recorder.flush();
      await projects.setMakingEnabled(id, true);
      await projects.saveProject(id);
      await projects.settleWrites();
    }
    // The app starts again (the writer knows nothing of the log yet).
    await MakingLogWriter.forget(dir);
    final (projects, history, recorder) = await started();
    expect(projects.tileManagerOf(id).storedCrc(key, '0,0'), isNotNull);
    paint(projects, history, id, key, 1, 1, _blue);
    await recorder.flush();
    final steps = (await log(id)).steps;
    expect(steps, hasLength(2));
    expect(
      steps.last.tiles.map((t) => t.tileKey).toSet(),
      {'0,1', '1,1'},
      reason:
          'the tile changed while off is recorded, the unchanged one is not '
          'copied again',
    );
  });

  test('deleting the history starts a new one', () async {
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    paint(projects, history, id, key, 0, 0, _red);
    await recorder.flush();
    await MakingService.deleteHistory(id);
    expect((await log(id)).steps, isEmpty);
    paint(projects, history, id, key, 0, 0, _blue);
    await recorder.flush();
    final steps = (await log(id)).steps;
    expect(steps, hasLength(1));
    // The whole layer as it is now (the earlier log is gone).
    expect(steps.single.tiles.single.offset, 0);
  });
}
