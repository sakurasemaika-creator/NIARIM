// メイキングの古い記録は、動画にした方が軽いときだけ、何もしていない間に
// 1080pの動画の区切り（segment）にする（所有者の依頼、2026-11-27「とにかく、
// 最もアプリが軽量になる方法で実装してくれたら問題ないです」「解像度は1080pで」）。
//
// 端末のH.264エンコーダーはテストの環境に無いので、システムのffmpeg（x264、
// 端末と同じくBフレームなし・2秒ごとのキーフレーム・0.1bit/画素）で代える。
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/making_export.dart';
import 'package:niarim/engine/making_log.dart';
import 'package:niarim/engine/making_player.dart';
import 'package:niarim/engine/making_video.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/making_recorder.dart';
import 'package:niarim/services/making_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/utils/app_error_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/system_video_tools.dart';

const _size = 512;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;
  late SystemVideoTools tools;
  late bool haveTools;

  setUpAll(() async {
    haveTools = await SystemVideoTools.available();
  });

  setUp(() {
    temp = Directory.systemTemp.createTempSync('niarim-making-compaction-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    SharedPreferences.setMockInitialValues({});
    tools = SystemVideoTools();
    MakingVideoTools.instance = tools;
  });
  tearDown(() {
    MakingVideoTools.instance = MakingVideoTools.device;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<(ProjectService, UndoManager, MakingRecorder)> started({
    Duration idleDelay = const Duration(seconds: 4),
  }) async {
    final projects = ProjectService();
    await projects.init();
    final history = UndoManager();
    projects.setUndoManager(history);
    final recorder = MakingRecorder(projects, history, idleDelay: idleDelay);
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
      exportWidth: _size,
      exportHeight: _size,
      makingEnabled: true,
    );
    final scene = projects.scenesOf(project.id).first;
    final layer = scene.frames.first.layers.firstWhere(
      (l) => l.type == LayerType.normal,
    );
    return (project.id, frameLayerKey(scene.id, 0, layer.id));
  }

  /// Paints tile [tx],[ty] with a textured picture (soft noise around a
  /// colour, like paper tooth: it does not compress) as one operation.
  void paint(
    ProjectService projects,
    UndoManager history,
    String id,
    String key,
    int tx,
    int ty,
    int seed, {
    bool raw = false,
  }) {
    final tiles = projects.tileManagerOf(id);
    final tileKey = '$tx,$ty';
    final before = tiles.layerTiles(key)[tileKey];
    final beforeCopy = before == null ? null : Uint8List.fromList(before);
    final tile = tiles.getOrCreateTile(key, tx, ty);
    final random = math.Random(seed);
    final base = [
      40 + random.nextInt(170),
      40 + random.nextInt(170),
      40 + random.nextInt(170),
    ];
    for (var i = 0; i < tile.length; i += 4) {
      for (var c = 0; c < 3; c++) {
        tile[i + c] = raw
            ? random.nextInt(256)
            : (base[c] + random.nextInt(31) - 15).clamp(0, 255);
      }
      tile[i + 3] = 255;
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

  /// Steps on the four tiles of the canvas, with an Undo and a Redo now and
  /// then.
  Future<void> record(
    ProjectService projects,
    UndoManager history,
    MakingRecorder recorder,
    String id,
    String key,
    int count, {
    int seed = 0,
  }) async {
    for (var i = 0; i < count; i++) {
      if (i % 9 == 8) {
        history.undo(projectId: id);
      } else if (i % 9 == 0 && i > 0) {
        history.redo(projectId: id);
      } else {
        paint(projects, history, id, key, i % 2, (i ~/ 2) % 2, seed + i);
      }
      await recorder.flush();
    }
  }

  Future<Uint8List> pixels(ui.Image image) async {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<List<Uint8List>> allFrames(String id) async {
    final player = await MakingPlayer.open(id);
    try {
      return [
        for (var i = 0; i < player.length; i++)
          await pixels(await player.render(i)),
      ];
    } finally {
      player.dispose();
    }
  }

  int logBytes(String dir) {
    var total = 0;
    for (final name in [MakingLog.blobsFile, MakingLog.stepsFile]) {
      final file = File('$dir/$name');
      if (file.existsSync()) total += file.lengthSync();
    }
    return total;
  }

  List<File> segmentFiles(String id) {
    final dir = Directory(
      '${temp.path}/niarim/projects/$id/Making/${MakingLog.segmentsFolder}',
    );
    if (!dir.existsSync()) return const [];
    return dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  test('the making video is 1080p: fitted in 1920×1080 (1080×1920 upright), '
      'never larger than the canvas, with even sides', () {
    expect(MakingLog.frameSize(1920, 1080), (1920, 1080));
    expect(MakingLog.frameSize(3840, 2160), (1920, 1080));
    expect(MakingLog.frameSize(1080, 1920), (1080, 1920));
    expect(MakingLog.frameSize(4000, 4000), (1080, 1080));
    expect(MakingLog.frameSize(1001, 601), (1000, 600));
    expect(MakingLog.frameSize(640, 360), (640, 360));
    expect(MakingLog.frameSize(3, 3), (2, 2));
    final (w, h) = MakingLog.frameSize(2480, 3508);
    expect(h, lessThanOrEqualTo(1920));
    expect(w, lessThanOrEqualTo(1080));
    expect(w.isEven && h.isEven, isTrue);
  });

  test(
    'the oldest steps become a video segment; the steps after it play '
    'exactly as before, and the segment\'s frames show the same pictures',
    () async {
      if (!haveTools) markTestSkipped('ffmpeg is not installed');
      final (projects, history, recorder) = await started();
      final (id, key) = await newWork(projects);
      final dir = await MakingService.logDirectory(id);
      await record(projects, history, recorder, id, key, 40);
      final before = await allFrames(id);
      final bytesBefore = logBytes(dir);

      expect(await recorder.compactor.compactNow(id, dir), isTrue);
      final log = MakingLogData.read(dir);
      expect(log.segments, hasLength(1));
      final segmentFrames = log.segments.single.frames;
      expect(segmentFrames, greaterThanOrEqualTo(16));
      expect(log.base, segmentFrames);
      expect(segmentFrames + log.steps.length, before.length);
      expect(log.initial, isNotEmpty, reason: 'the key frame');
      // The log keeps the key frame and the steps after it: far smaller.
      expect(logBytes(dir), lessThan(bytesBefore ~/ 2));
      expect(segmentFiles(id), hasLength(1));
      // The segment was encoded once, from one picture per step.
      expect(tools.encoded.single, hasLength(segmentFrames));

      final after = await allFrames(id);
      expect(after, hasLength(before.length));
      for (var i = 0; i < before.length; i++) {
        if (i < segmentFrames) {
          expect(
            MakingVideo.looksLike(after[i], before[i], _size, _size),
            isTrue,
            reason: 'video frame $i',
          );
        } else {
          expect(after[i], before[i], reason: 'step $i (key frame + log)');
        }
      }
      // A video frame is a picture of its own step, not of a neighbour.
      expect(MakingVideo.looksLike(after[3], before[4], _size, _size), isFalse);
    },
  );

  test('a second compaction adds a segment after the first; playback goes '
      'through both and on into the log in order', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    final dir = await MakingService.logDirectory(id);
    await record(projects, history, recorder, id, key, 30);
    expect(await recorder.compactor.compactNow(id, dir), isTrue);
    await record(projects, history, recorder, id, key, 30, seed: 1000);
    final before = await allFrames(id);
    expect(await recorder.compactor.compactNow(id, dir), isTrue);
    final log = MakingLogData.read(dir);
    expect(log.segments, hasLength(2));
    expect(segmentFiles(id).map((f) => f.uri.pathSegments.last), [
      'seg_000001.mp4',
      'seg_000002.mp4',
    ]);
    final after = await allFrames(id);
    expect(after, hasLength(before.length));
    final videoFrames = log.base;
    for (var i = 0; i < before.length; i++) {
      if (i < videoFrames) {
        expect(
          MakingVideo.looksLike(after[i], before[i], _size, _size),
          isTrue,
          reason: 'video frame $i',
        );
      } else {
        expect(after[i], before[i], reason: 'step $i');
      }
    }
  });

  test('MP4: the segments are put in the video as they are (not encoded '
      'again); only the log\'s steps and the end mark are encoded', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    final dir = await MakingService.logDirectory(id);
    await record(projects, history, recorder, id, key, 30);
    expect(await recorder.compactor.compactNow(id, dir), isTrue);
    await record(projects, history, recorder, id, key, 30, seed: 1000);
    expect(await recorder.compactor.compactNow(id, dir), isTrue);
    await record(projects, history, recorder, id, key, 5, seed: 2000);
    final before = await allFrames(id);
    final log = MakingLogData.read(dir);
    tools.encoded.clear();
    tools.ffmpegRuns.clear();

    final player = await MakingPlayer.open(id);
    addTearDown(player.dispose);
    final output = '${temp.path}/making.mp4';
    await MakingExport.export(
      frames: player,
      format: MakingExportFormat.mp4,
      outputPath: output,
      officialMark: true,
    );
    const endCard = MakingExport.fps * ExportEngine.officialEndCardSeconds;
    expect(tools.encoded.single, hasLength(log.steps.length + endCard));
    // One stream copy of the parts.
    final concat = tools.ffmpegRuns.where((a) => a.contains('concat'));
    expect(concat, hasLength(1));
    expect(concat.single, containsAllInOrder(['-c', 'copy']));
    final timeline = await MakingVideo.probe(output, temp);
    expect(timeline.frameCount, before.length + endCard);
    // Each frame of the video is its step's picture (the segments, then the
    // log), then the end mark.
    final decoder = tools.decoder(temp);
    for (final index in [
      0,
      log.segments.first.frames,
      log.base,
      before.length - 1,
    ]) {
      final frame = await decoder.decode(
        path: output,
        timeline: timeline,
        frameIndex: index,
        width: _size,
        height: _size,
      );
      expect(
        MakingVideo.looksLike(frame.rgba, before[index], _size, _size),
        isTrue,
        reason: 'frame $index',
      );
    }
  });

  test('a shorter making video picks its frames evenly from the segments '
      'and the log; a segment\'s picked frames are read in one pass', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    final dir = await MakingService.logDirectory(id);
    await record(projects, history, recorder, id, key, 60);
    expect(await recorder.compactor.compactNow(id, dir), isTrue);
    await record(projects, history, recorder, id, key, 80, seed: 1000);
    final before = await allFrames(id);
    final log = MakingLogData.read(dir);
    expect(log.segments, isNotEmpty);
    final inSegments = log.segments.fold(0, (sum, s) => sum + s.frames);
    expect(
      MakingExport.lengthLimitSeconds(before.length, MakingExportFormat.mp4),
      greaterThan(15),
    );
    tools.ffmpegRuns.clear();
    tools.encoded.clear();

    final player = await MakingPlayer.open(id);
    addTearDown(player.dispose);
    final output = '${temp.path}/making_short.mp4';
    await MakingExport.export(
      frames: player,
      format: MakingExportFormat.mp4,
      outputPath: output,
      officialMark: false,
      maxSeconds: 15,
    );
    const body = 15 * MakingExport.fps;
    final timeline = await MakingVideo.probe(output, temp);
    expect(timeline.frameCount, body);
    final picked = [
      for (var k = 0; k < body; k++)
        (k * (before.length - 1) / (body - 1)).round(),
    ];
    final decoder = tools.decoder(temp);
    for (final k in [
      0,
      picked.indexWhere((index) => index > 3) + 1,
      picked.lastIndexWhere((index) => index < inSegments),
      picked.indexWhere((index) => index >= inSegments),
      body - 1,
    ]) {
      final frame = await decoder.decode(
        path: output,
        timeline: timeline,
        frameIndex: k,
        width: _size,
        height: _size,
      );
      expect(
        MakingVideo.looksLike(frame.rgba, before[picked[k]], _size, _size),
        isTrue,
        reason: 'frame $k (step ${picked[k]})',
      );
    }
    // The segments are not copied whole (they show every step): every
    // picked frame is encoded. The picked frames of a segment are read a few
    // passes at a time, not one FFmpeg run per frame.
    expect(tools.encoded.fold(0, (sum, frames) => sum + frames.length), body);
    final reads = tools.ffmpegRuns.where(
      (a) => a.any((argument) => argument.contains('select=')),
    );
    final pickedInSegments = picked.where((i) => i < inSegments).length;
    expect(reads, isNotEmpty);
    expect(reads.length, lessThan(pickedInSegments ~/ 4));
  });

  test('WebM and GIF read the frames of the segments', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    final dir = await MakingService.logDirectory(id);
    await record(projects, history, recorder, id, key, 30);
    expect(await recorder.compactor.compactNow(id, dir), isTrue);
    final player = await MakingPlayer.open(id);
    addTearDown(player.dispose);
    final webm = '${temp.path}/making.webm';
    await MakingExport.export(
      frames: player,
      format: MakingExportFormat.webm,
      outputPath: webm,
      officialMark: false,
    );
    expect((await MakingVideo.probe(webm, temp)).frameCount, player.length);
    final gif = '${temp.path}/making.gif';
    await MakingExport.export(
      frames: player,
      format: MakingExportFormat.gif,
      outputPath: gif,
      officialMark: false,
    );
    expect(File(gif).lengthSync(), greaterThan(0));
  });

  test(
    'steps not worth a video (they keep little history) stay in the log',
    () async {
      if (!haveTools) markTestSkipped('ffmpeg is not installed');
      final (projects, history, recorder) = await started();
      final (id, key) = await newWork(projects);
      final dir = await MakingService.logDirectory(id);
      final tiles = projects.tileManagerOf(id);
      // Flat colours: a tile is a few hundred bytes in the log.
      for (var i = 0; i < 40; i++) {
        final tileKey = '${i % 2},0';
        final before = tiles.layerTiles(key)[tileKey];
        final tile = tiles.getOrCreateTile(key, i % 2, 0);
        for (var p = 0; p < tile.length; p += 4) {
          tile.setAll(p, [i * 5 % 256, 90, 200, 255]);
        }
        history.push(
          TileUndoAction(
            tileManager: tiles,
            layerId: key,
            before: {
              tileKey: before == null ? null : Uint8List.fromList(before),
            },
            after: {tileKey: Uint8List.fromList(tile)},
            onApply: () {},
          ),
          projectId: id,
        );
        await recorder.flush();
      }
      final bytes = logBytes(dir);
      expect(await MakingLogWriter.plan(dir), isNull);
      expect(await recorder.compactor.compactNow(id, dir), isFalse);
      expect(logBytes(dir), bytes);
      expect(tools.encoded, isEmpty, reason: 'nothing was encoded');
    },
  );

  test('recording goes on past the old 64 MB limit, and in idle time the '
      'log is turned into video (it stays small)', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    final (projects, history, recorder) = await started(
      idleDelay: const Duration(milliseconds: 300),
    );
    final (id, key) = await newWork(projects);
    final dir = await MakingService.logDirectory(id);
    // 256 KB a step (pixels that do not compress), faster than the idle
    // delay: no compaction yet.
    for (var i = 0; i < 320; i++) {
      paint(projects, history, id, key, i % 2, (i ~/ 2) % 2, i, raw: true);
      await recorder.flush();
    }
    await recorder.flush();
    expect(logBytes(dir), greaterThan(64 * 1024 * 1024));
    expect(MakingLogData.read(dir).limitReached, isFalse);
    expect(MakingLogData.read(dir).steps, hasLength(320));
    expect(tools.encoded, isEmpty, reason: 'nothing while drawing');

    // Idle: the compaction starts by itself.
    for (var i = 0; i < 600 && segmentFiles(id).isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await recorder.compactor.settled;
    final log = MakingLogData.read(dir);
    // ignore: avoid_print
    print('ERRORS ${AppErrorReporter.recentErrors}');
    expect(log.segments, isNotEmpty);
    expect(log.base + log.steps.length, 320);
    expect(logBytes(dir), lessThan(8 * 1024 * 1024));
    // And recording goes on after it.
    paint(projects, history, id, key, 0, 0, 9999);
    await recorder.flush();
    expect(MakingLogData.read(dir).steps.length, log.steps.length + 1);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('no compaction while the user is drawing', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    final (projects, history, recorder) = await started(
      idleDelay: const Duration(milliseconds: 400),
    );
    final (id, key) = await newWork(projects);
    final dir = await MakingService.logDirectory(id);
    await record(projects, history, recorder, id, key, 40);
    final compaction = recorder.compactor.compactNow(
      id,
      dir,
      waitForIdle: true,
    );
    // Input keeps coming: no frame is drawn, nothing is encoded.
    for (var i = 0; i < 10; i++) {
      recorder.compactor.noteInput();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(tools.encoded, isEmpty);
    expect(
      Directory(temp.path).listSync().where(
        (e) =>
            e.path.contains('niarim_making_compact_') &&
            Directory(e.path).listSync().isNotEmpty,
      ),
      isEmpty,
      reason: 'no frame was drawn',
    );
    // Then the user stops.
    expect(await compaction, isTrue);
    expect(tools.encoded, hasLength(1));
  });

  test('a device whose encoder fails or makes a wrong video keeps the log '
      'as it is, and recording goes on', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    for (final broken in [
      SystemVideoTools(failEncode: true),
      SystemVideoTools(garble: true),
    ]) {
      MakingVideoTools.instance = broken;
      final (projects, history, recorder) = await started();
      final (id, key) = await newWork(projects);
      final dir = await MakingService.logDirectory(id);
      await record(projects, history, recorder, id, key, 40);
      final steps = File('$dir/${MakingLog.stepsFile}').readAsStringSync();
      final bytes = logBytes(dir);
      expect(await recorder.compactor.compactNow(id, dir), isFalse);
      expect(broken.encoded, hasLength(1));
      expect(File('$dir/${MakingLog.stepsFile}').readAsStringSync(), steps);
      expect(logBytes(dir), bytes);
      expect(segmentFiles(id), isEmpty);
      paint(projects, history, id, key, 0, 0, 7);
      await recorder.flush();
      expect(MakingLogData.read(dir).steps, hasLength(41));
    }
  });

  test('a crash while a compacted log is being put in place leaves the old '
      'log or the new one, never part of both', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    final (projects, history, recorder) = await started();
    final (id, key) = await newWork(projects);
    final dir = await MakingService.logDirectory(id);
    final making = Directory(dir).parent.path;
    await record(projects, history, recorder, id, key, 40);
    final beforeFrames = await allFrames(id);
    final old = Directory('${temp.path}/old')..createSync();
    for (final file in Directory(dir).listSync().whereType<File>()) {
      file.copySync('${old.path}/${file.uri.pathSegments.last}');
    }
    expect(await recorder.compactor.compactNow(id, dir), isTrue);
    final compacted = Directory('${temp.path}/compacted')..createSync();
    for (final file in Directory(dir).listSync().whereType<File>()) {
      file.copySync('${compacted.path}/${file.uri.pathSegments.last}');
    }
    final segment = segmentFiles(id).single;
    final segmentCopy = segment.copySync('${temp.path}/segment.mp4');
    final compactedFrames = await allFrames(id);

    Future<void> restart() async {
      await MakingLogWriter.forget(dir);
      await MakingLogWriter.prepare(dir);
    }

    void put(Directory from, String to) {
      Directory(to).createSync(recursive: true);
      for (final file in from.listSync().whereType<File>()) {
        file.copySync('$to/${file.uri.pathSegments.last}');
      }
    }

    // 1. The new log was being written (the old one is still in place), and
    //    the segment was already moved in: the old log stays, the unlisted
    //    segment goes.
    Directory(dir).deleteSync(recursive: true);
    put(old, dir);
    put(compacted, '$making/${MakingLog.nextFolder}');
    File(
      '$making/${MakingLog.nextFolder}/${MakingLog.stepsFile}',
    ).writeAsStringSync('{"k":"key","v":2,"ba', mode: FileMode.append);
    await restart();
    expect(Directory('$making/${MakingLog.nextFolder}').existsSync(), isFalse);
    expect(segment.existsSync(), isFalse, reason: 'unlisted');
    expect(await allFrames(id), beforeFrames);

    // 2. Between the two renames (log → log.old, log.next → log): the new
    //    log is put in place.
    segment.parent.createSync(recursive: true);
    segmentCopy.copySync(segment.path);
    Directory(dir).renameSync('$making/${MakingLog.oldFolder}');
    put(compacted, '$making/${MakingLog.nextFolder}');
    await restart();
    expect(Directory('$making/${MakingLog.oldFolder}').existsSync(), isFalse);
    expect(Directory('$making/${MakingLog.nextFolder}').existsSync(), isFalse);
    expect(MakingLogData.read(dir).segments, hasLength(1));
    expect(segment.existsSync(), isTrue);
    expect(await allFrames(id), compactedFrames);

    // 3. A step line cut short by a crash is ignored.
    final steps = MakingLogData.read(dir).steps.length;
    File(
      '$dir/${MakingLog.stepsFile}',
    ).writeAsStringSync('{"k":"t","n":99,"e":[["a', mode: FileMode.append);
    await restart();
    expect(MakingLogData.read(dir).steps, hasLength(steps));
    expect(await allFrames(id), compactedFrames);
  });

  test('deleting the history stops a compaction and removes the segments; '
      'nothing is made again in the deleted folder', () async {
    if (!haveTools) markTestSkipped('ffmpeg is not installed');
    final (projects, history, recorder) = await started(
      idleDelay: const Duration(milliseconds: 300),
    );
    final (id, key) = await newWork(projects);
    final dir = await MakingService.logDirectory(id);
    await record(projects, history, recorder, id, key, 30);
    expect(await recorder.compactor.compactNow(id, dir), isTrue);
    await record(projects, history, recorder, id, key, 40, seed: 500);
    final making = Directory(dir).parent;
    // A compaction waiting for the user to stop drawing.
    recorder.compactor.noteInput();
    final compaction = recorder.compactor.compactNow(
      id,
      dir,
      waitForIdle: true,
    );
    await MakingService.deleteHistory(id);
    expect(await compaction, isFalse);
    expect(making.existsSync(), isFalse);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(making.existsSync(), isFalse, reason: 'not made again');
    expect(
      Directory(
        temp.path,
      ).listSync().where((e) => e.path.contains('niarim_making_compact_')),
      isEmpty,
    );
  });
}
