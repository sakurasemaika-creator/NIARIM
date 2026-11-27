// 書き出しに足した3つ（所有者の判断、2026-11-27、全部入りの作品づくりの判断カード
// J20）：大きさ・画質を選ぶ、書き出す範囲（シーン・フレーム）を選ぶ、全部の
// フレームを連番の画像（PNG）で書き出す。以前は作品の大きさ・決まった画質で、
// いつも全部のシーンを書き出し、画像は1フレームずつしか書き出せなかった。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_audio.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/export/export_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

const _w = 80;
const _h = 48;
const _layer = Layer(id: 'Layer0001', name: 'L', type: LayerType.normal);

/// A whole frame of one colour, a different one for each frame.
Uint8List _solid(int value) {
  final pixels = Uint8List(_w * _h * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels
      ..[i] = value
      ..[i + 1] = 0
      ..[i + 2] = 255 - value
      ..[i + 3] = 255;
  }
  return pixels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  // Two scenes: A with frames 0–2, B with frames 0–3; each frame has its
  // own red.
  List<Scene> scenes() => [
    Scene(
      id: 'A',
      index: 0,
      frames: [
        for (var i = 0; i < 3; i++) Frame(index: i, layers: const [_layer]),
      ],
    ),
    Scene(
      id: 'B',
      index: 1,
      frames: [
        for (var i = 0; i < 4; i++) Frame(index: i, layers: const [_layer]),
      ],
    ),
  ];
  int redOf(String scene, int frame) => (scene == 'A' ? 10 : 100) + frame * 20;
  TileManager tiles() {
    final manager = TileManager(canvasWidth: _w, canvasHeight: _h);
    for (final scene in scenes()) {
      for (final frame in scene.frames) {
        manager.replaceLayerPixels(
          frameLayerKey(scene.id, frame.index, _layer.id),
          _solid(redOf(scene.id, frame.index)),
        );
      }
    }
    return manager;
  }

  group('the timing', () {
    const window = ExportWindow(sceneId: 'B', start: 1, end: 2);
    test('counts and plays only the chosen frames', () {
      const timing = ExportTiming(sourceFps: 4, outputFps: 8, window: window);
      expect(timing.framesIn(scenes()), 2);
      expect(timing.outputFrames(scenes()), 4);
      expect(
        [
          for (final (:scene, :frame) in timing.samples(scenes()))
            '${scene.id}${frame.index}',
        ],
        ['B1', 'B1', 'B2', 'B2'],
      );
      const whole = ExportTiming(sourceFps: 4, outputFps: 4);
      expect(whole.framesIn(scenes()), 7);
    });

    test('a sound is placed from the first chosen frame', () async {
      final dir = Directory.systemTemp.createTempSync('niarim-j20-audio-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.wav')..writeAsBytesSync([0]);
      final withSound = [
        scenes()[0],
        Scene(
          id: 'B',
          index: 1,
          frames: scenes()[1].frames,
          audioClips: const [
            // From frame 0 for 4 frames: starts before the window.
            AudioClip(
              id: 'a',
              label: 'a',
              materialId: 'm',
              startFrame: 0,
              lengthFrames: 4,
            ),
            // Only in frame 3: after the window.
            AudioClip(
              id: 'b',
              label: 'b',
              materialId: 'm',
              startFrame: 3,
              lengthFrames: 1,
            ),
          ],
        ),
      ];
      final plan = await buildExportAudioPlan(
        scenes: withSound,
        sourceFps: 4,
        window: window,
        pathOf: (_) async => file.path,
      );
      expect(plan.sources, hasLength(1));
      final sound = plan.sources.single;
      expect(sound.startSeconds, 0, reason: 'at the start of the export');
      expect(sound.sourceSeconds, closeTo(1 / 4, 1e-9), reason: 'a frame in');
      expect(sound.durationSeconds, closeTo(2 / 4, 1e-9));
    });
  });

  group('the files', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('niarim-j20-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => root.path);
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('a GIF of the chosen frames at half the size', () async {
      final manager = tiles();
      addTearDown(manager.dispose);
      final output = await ExportEngine().exportGif(
        scenes: scenes(),
        tileManager: manager,
        fps: 4,
        sourceFps: 4,
        drawingWidth: _w,
        drawingHeight: _h,
        width: _w ~/ 2,
        height: _h ~/ 2,
        backgroundColor: 0xFFFFFFFF,
        window: const ExportWindow(sceneId: 'B', start: 1, end: 2),
      );
      final gif = img.decodeGif(File(output).readAsBytesSync())!;
      expect((gif.width, gif.height), (_w ~/ 2, _h ~/ 2));
      expect(gif.frames, hasLength(2));
      for (final (i, frame) in gif.frames.indexed) {
        final red = frame.convert(numChannels: 4).getPixel(4, 4).r;
        expect(red, closeTo(redOf('B', 1 + i), 2), reason: 'frame $i');
      }
    });

    test('every chosen frame as numbered pictures', () async {
      final manager = tiles();
      addTearDown(manager.dispose);
      final paths = await ExportEngine().exportFrameSequence(
        projectName: 'Walk',
        scenes: scenes(),
        tileManager: manager,
        drawingWidth: _w,
        drawingHeight: _h,
        width: _w,
        height: _h,
        backgroundColor: 0xFFFFFFFF,
      );
      expect(paths, hasLength(7));
      final names = [for (final p in paths) p.split('/').last];
      expect(names.first, startsWith('Walk F001 '));
      expect(names.last, startsWith('Walk F007 '));
      // One date and time for the whole run, so they sort in order.
      expect(names.map((n) => n.split(' ').last).toSet(), hasLength(1));
      final last = img.decodePng(File(paths.last).readAsBytesSync())!;
      expect(last.getPixel(4, 4).r, redOf('B', 3));

      // Cancelled part-way: none of it is left.
      final token = ExportCancelToken();
      final before = root.listSync(recursive: true).length;
      await expectLater(
        ExportEngine().exportFrameSequence(
          scenes: scenes(),
          tileManager: manager,
          drawingWidth: _w,
          drawingHeight: _h,
          width: _w,
          height: _h,
          backgroundColor: 0xFFFFFFFF,
          cancelToken: token,
          onProgress: (current, _) {
            if (current == 2) token.cancel();
          },
        ),
        throwsA(isA<ExportCancelledException>()),
      );
      expect(root.listSync(recursive: true).length, before);
    });

    test('the pictures go into their folder with one save', () async {
      SharedPreferences.setMockInitialValues({});
      final folders = WorkFolderService();
      await folders.init();
      final folder = await folders.createFolder('Walk (frames)');
      var saves = 0;
      folders.addListener(() => saves++);
      await folders.moveFilesToFolder([
        for (var i = 1; i <= 240; i++) 'Walk F${'$i'.padLeft(3, '0')}.png',
      ], folder.id);
      expect(saves, 1);
      expect(folders.folderIdOf('Walk F001.png'), folder.id);
      expect(folders.folderIdOf('Walk F240.png'), folder.id);
      final restored = WorkFolderService();
      await restored.init();
      expect(restored.folderIdOf('Walk F120.png'), folder.id);
    });
  });

  testWidgets('the screen chooses the scene, frames, size and quality', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('niarim-j20-ui-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => directory.path,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'j20',
        fps: 4,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 1920,
        exportHeight: 1080,
      ),
    ))!;
    final scene = ps.scenesOf(project.id).first;
    appRouter.go('/export/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 500));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExportScreen)),
    )!;
    Future<void> tapKey(String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pump();
    }

    expect(find.text(l10n.exportRangeSection), findsOneWidget);
    expect(find.byKey(const ValueKey('exportRangeFrames')), findsNothing);
    await tapKey('exportRangeScene-${scene.id}');
    expect(find.byKey(const ValueKey('exportRangeFrames')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('exportRangeFramesText')))
          .data,
      l10n.exportRangeFrames(1, 8),
    );

    // Half the size: the summary says so.
    await tapKey('exportSize-0.50');
    expect(find.textContaining('960 × 540 px'), findsOneWidget);

    // The quality is for the videos; a GIF has none.
    expect(find.byKey(const ValueKey('exportQuality-high')), findsOneWidget);
    final gif = find.text(l10n.exportFormatGif);
    await tester.ensureVisible(gif);
    await tester.pump();
    await tester.tap(gif);
    await tester.pump();
    expect(find.byKey(const ValueKey('exportQuality-high')), findsNothing);
    expect(find.byKey(const ValueKey('exportFrameSequence')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
