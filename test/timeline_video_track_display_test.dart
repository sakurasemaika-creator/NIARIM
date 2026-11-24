import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_provider.dart';
import 'package:niarim/engine/video_frame_timeline.dart';
import 'package:niarim/engine/video_material_snapshot.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/models/timeline_row_kind.dart';
import 'package:niarim/models/video_track_display.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/screens/timeline/widgets/video_filmstrip.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// 30 frames at 10 fps, 16:9. A frame's red channel is 3 × its index + 10.
class _IndexDecoder implements VideoFrameDecoder {
  final decodes = <int>[];

  @override
  Future<VideoFrameTimeline> probe(String path) async =>
      VideoFrameTimeline.fromPresentationMicros(
        [for (var i = 0; i < 30; i++) i * 100000],
        displayWidth: 160,
        displayHeight: 90,
      );

  @override
  Future<DecodedVideoFrame> decode({
    required String path,
    required VideoFrameTimeline timeline,
    required int frameIndex,
    required int width,
    required int height,
  }) async {
    decodes.add(frameIndex);
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba
        ..[i] = 3 * frameIndex + 10
        ..[i + 3] = 255;
    }
    return DecodedVideoFrame(
      rgba: rgba,
      width: width,
      height: height,
      frameIndex: frameIndex,
    );
  }
}

Future<int?> _redOf(WidgetTester tester, Finder rawImage) async {
  final image = tester.widget<RawImage>(rawImage).image?.clone();
  if (image == null) return null;
  return tester.runAsync(() async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data!.getUint8(0);
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('filmstrip slots', () {
    test('one slot per frame width, at least 40 px, at most 32 and the '
        'clip\'s frame count', () {
      int count(double width, double frameWidth, int length) =>
          VideoFilmstrip.slotCountFor(
            width: width,
            frameWidth: frameWidth,
            lengthFrames: length,
          );
      expect(count(400, 80, 100), 5);
      expect(count(401, 80, 100), 6);
      expect(count(10, 80, 100), 1);
      // Narrow frames (a tall video) still get 40 px.
      expect(count(400, 20, 100), 10);
      expect(count(100000, 80, 1000), VideoFilmstrip.maxSlots);
      expect(count(400, 80, 3), 3);
      expect(count(0, 80, 10), 0);
      expect(count(400, 80, 0), 0);
    });

    test('each slot shows the frame under its middle', () {
      expect(
        VideoFilmstrip.slotFrames(startFrame: 0, lengthFrames: 20, slots: 5),
        [2, 6, 10, 14, 18],
      );
      expect(
        VideoFilmstrip.slotFrames(startFrame: 7, lengthFrames: 3, slots: 3),
        [7, 8, 9],
      );
      expect(
        VideoFilmstrip.slotFrames(startFrame: 4, lengthFrames: 1, slots: 1),
        [4],
      );
    });
  });

  testWidgets('a filmstrip shows the source frames the clip plays, at its '
      'speed and trim, and asks again when it is resized', (tester) async {
    final dir = Directory.systemTemp.createTempSync('niarim-filmstrip-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v.mp4')..writeAsBytesSync([0]);
    final decoder = _IndexDecoder();
    final frames = VideoFrameProvider(
      snapshot: VideoMaterialSnapshot.fromAssets(
        [
          MaterialAsset(
            id: 'v',
            originalFileName: 'v.mp4',
            type: MaterialType.video,
            sizeBytes: 1,
            addedAt: DateTime(2026),
          ),
        ],
        {'v': file.path},
      ),
      decoder: decoder,
    );
    addTearDown(frames.dispose);
    final width = ValueNotifier<double>(400);
    addTearDown(width.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, w, _) => SizedBox(
              width: w,
              height: 45,
              child: VideoFilmstrip(
                frames: frames,
                materialId: 'v',
                timing: (
                  startFrame: 0,
                  lengthFrames: 20,
                  trimStartFrame: 2,
                  trimEndFrame: 29,
                  playbackRate: 1.5,
                ),
                framesPerSecond: 10,
              ),
            ),
          ),
        ),
      ),
    );

    Future<List<int?>> reds(int slots) async => [
      for (var slot = 0; slot < slots; slot++)
        await _redOf(
          tester,
          find.descendant(
            of: find.byKey(ValueKey('filmstripSlot$slot')),
            matching: find.byType(RawImage),
          ),
        ),
    ];

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 40));
        if (find.byType(RawImage).evaluate().length ==
            find
                .byWidgetPredicate((w) {
                  final key = w.key;
                  return key is ValueKey<String> &&
                      key.value.startsWith('filmstripSlot');
                })
                .evaluate()
                .length) {
          break;
        }
      }
    }

    await settle();
    // 16:9 at 45 px tall is 80 px: 5 slots at timeline frames 2, 6, 10, 14,
    // 18, which play source frames 2 + 1.5 × those: 5, 11, 17, 23, 29.
    expect(find.byType(RawImage), findsNWidgets(5));
    expect(await reds(5), [25, 43, 61, 79, 97]);

    width.value = 160;
    await settle();
    // 2 slots at timeline frames 5 and 15: source 9.5 and 24.5 → 9 and 24.
    expect(find.byType(RawImage), findsNWidgets(2));
    expect(await reds(2), [37, 82]);
    expect(decoder.decodes.toSet(), containsAll([5, 11, 17, 23, 29, 9, 24]));
  });

  test('each video row keeps its display when saved; old projects show '
      'frames', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-row-display-');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.utc(2026);
    final project = Project(
      id: 'p',
      name: 'p',
      fps: 10,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: now,
      updatedAt: now,
      totalWorkSeconds: 0,
    );
    Future<Scene> roundTrip(Scene scene) async {
      final path = '${dir.path}/${scene.id}.niapro';
      await NiaproSerializer.saveToPath(
        filePath: path,
        project: project,
        scenes: [scene],
        tileManager: TileManager(canvasWidth: 8, canvasHeight: 8),
      );
      return (await NiaproSerializer.load(path)).scenes.single;
    }

    final saved = await roundTrip(
      const Scene(
        id: 'Scene0001',
        index: 0,
        frames: [Frame(index: 0)],
        videoRowNames: [null, null, 'B'],
        videoRowDisplays: [
          VideoTrackDisplay.frames,
          VideoTrackDisplay.frames,
          VideoTrackDisplay.waveform,
        ],
      ),
    );
    expect(saved.videoRowDisplayOf(0), VideoTrackDisplay.frames);
    expect(saved.videoRowDisplayOf(2), VideoTrackDisplay.waveform);
    expect(saved.videoRowDisplayOf(5), VideoTrackDisplay.frames);

    final plain = await roundTrip(
      const Scene(id: 'Scene0002', index: 0, frames: [Frame(index: 0)]),
    );
    expect(plain.videoRowDisplays, isEmpty);
    expect(plain.videoRowDisplayOf(0), VideoTrackDisplay.frames);
    expect(
      VideoTrackDisplay.fromName('something new'),
      VideoTrackDisplay.frames,
    );
    expect(VideoTrackDisplay.fromName(null), VideoTrackDisplay.frames);
  });

  testWidgets('a video row switches between frames and the waveform, the '
      'choice is one Undo step, and removing a row moves the later rows\' '
      'choices up', (tester) async {
    final decoder = _IndexDecoder();
    TimelineScreen.videoDecoderFor = (_) => decoder;
    addTearDown(
      () => TimelineScreen.videoDecoderFor = FfmpegVideoFrameDecoder.ffmpegKit,
    );
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-rows-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    // Registering a material reads its metadata with FFmpegKit, which has no
    // plugin in tests; the material stays registered without it.
    const ffmpegEvents = EventChannel('flutter.arthenica.com/ffmpeg_kit_event');
    messenger.setMockStreamHandler(
      ffmpegEvents,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    addTearDown(() {
      messenger.setMockStreamHandler(ffmpegEvents, null);
      messenger.setMockMethodCallHandler(channel, null);
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
    final context = tester.element(find.byType(MaterialApp).first);
    final ps = context.read<ProjectService>();
    final materials = context.read<MaterialService>();

    late String sceneId;
    late String videoId;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'rows',
        fps: 10,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      final source = File('${directory.path}/clip.mp4')
        ..writeAsBytesSync(List.filled(64, 7));
      final asset = await materials.addMaterial(
        projectId: project.id,
        sourcePath: source.path,
        type: MaterialType.video,
      );
      sceneId = ps.scenesOf(project.id).first.id;
      final layer = ps.addLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.timelineVideo,
        name: 'clip',
      );
      videoId = layer.id;
      ps.updateLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 10,
          materialId: asset.id,
          sourceTrimStart: 0,
          sourceTrimEnd: 29,
        ),
      );
      return project.id;
    });
    final projectId = created!;

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));

    // Frames by default, drawn from the decoded video.
    final filmstrip = find.byKey(ValueKey('filmstrip_$videoId'));
    expect(filmstrip, findsOneWidget);
    expect(find.byKey(ValueKey('wf_$videoId')), findsNothing);
    final stripImages = find.descendant(
      of: filmstrip,
      matching: find.byType(RawImage),
    );
    for (var i = 0; i < 40 && stripImages.evaluate().isEmpty; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 50));
    }
    expect(stripImages, findsWidgets);
    // The first slot is at the clip's start: source frame 0 or a later one.
    expect(await _redOf(tester, stripImages.first), greaterThanOrEqualTo(10));

    final toggle = find.byKey(const ValueKey('videoRowDisplay-0'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(
      ps.videoRowDisplayOf(projectId, sceneId, 0),
      VideoTrackDisplay.waveform,
    );
    expect(filmstrip, findsNothing);
    expect(find.byKey(ValueKey('wf_$videoId')), findsOneWidget);

    // One Undo puts frames back.
    await tester.tap(find.byIcon(Icons.undo).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(
      ps.videoRowDisplayOf(projectId, sceneId, 0),
      VideoTrackDisplay.frames,
    );
    expect(filmstrip, findsOneWidget);

    // Rows 1 and 2 are added; row 2 shows the waveform. Removing the empty
    // row 1 moves row 2 (and its choice) up to row 1.
    ps.addTrackRow(projectId, sceneId, TimelineRowKind.video);
    ps.addTrackRow(projectId, sceneId, TimelineRowKind.video);
    ps.setVideoRowDisplay(projectId, sceneId, 2, VideoTrackDisplay.waveform);
    expect(
      ps.videoRowDisplayOf(projectId, sceneId, 1),
      VideoTrackDisplay.frames,
    );
    expect(
      ps.removeTrackRow(projectId, sceneId, TimelineRowKind.video, 1),
      isTrue,
    );
    expect(
      ps.videoRowDisplayOf(projectId, sceneId, 1),
      VideoTrackDisplay.waveform,
    );
    expect(
      ps.videoRowDisplayOf(projectId, sceneId, 0),
      VideoTrackDisplay.frames,
    );

    // Leaving the timeline releases the filmstrip's frames with the preview's.
    appRouter.go('/');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(find.byType(TimelineScreen), findsNothing);
    expect(
      directory.listSync().where(
        (e) => e.path.contains('timeline_preview_video_frames_'),
      ),
      isEmpty,
    );
  });
}
