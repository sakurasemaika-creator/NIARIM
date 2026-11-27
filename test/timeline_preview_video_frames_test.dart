import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_timeline.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// Solid frames whose red channel is 100 + 10 × the source frame index.
class _SolidDecoder implements VideoFrameDecoder {
  final decodes = <int>[];

  @override
  Future<VideoFrameTimeline> probe(String path) async =>
      VideoFrameTimeline.fromPresentationMicros([
        for (var i = 0; i < 30; i++) i * 100000,
      ]);

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
        ..[i] = 100 + frameIndex * 10
        ..[i + 1] = 40
        ..[i + 2] = 90
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

/// A file that cannot be read as a video.
class _UnreadableDecoder implements VideoFrameDecoder {
  @override
  Future<VideoFrameTimeline> probe(String path) async =>
      throw const FileSystemException('not a video');

  @override
  Future<DecodedVideoFrame> decode({
    required String path,
    required VideoFrameTimeline timeline,
    required int frameIndex,
    required int width,
    required int height,
  }) async => throw const FileSystemException('not a video');
}

void main() {
  testWidgets('the timeline preview composites the decoded video frame and '
      'releases its decoder when the timeline closes', (tester) async {
    final decoder = _SolidDecoder();
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
    final directory = Directory.systemTemp.createTempSync('timeline-video-');
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

    final projectId = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'video-preview',
        fps: 10,
        durationSeconds: 1,
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
      final sceneId = ps.scenesOf(project.id).first.id;
      final layer = ps.addLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.timelineVideo,
        name: 'clip',
      );
      final tiles = ps.tileManagerOf(project.id);
      // The grey placeholder the project stores for a video layer.
      tiles.replaceLayerPixels(
        ps.tileKeyFor(project.id, sceneId, 0, layer.id),
        Uint8List.fromList(
          List.generate(
            tiles.canvasWidth * tiles.canvasHeight * 4,
            (i) => i % 4 == 3 ? 255 : 128,
          ),
        ),
      );
      ps.updateLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 10,
          materialId: asset.id,
          sourceTrimStart: 3,
          sourceTrimEnd: 12,
        ),
      );
      return project.id;
    });

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));

    final picture = find.byKey(const Key('timelinePreviewPicture'));
    Future<int?> centrePixel() async {
      if (picture.evaluate().isEmpty) return null;
      final image = tester.renderObject<RenderImage>(picture).image!.clone();
      return tester.runAsync(() async {
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          return data.getUint32(
            ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4,
          );
        } finally {
          image.dispose();
        }
      });
    }

    // Timeline frame 0 plays source frame 3: red 130 over white paper.
    const expected = 0x82285AFF;
    int? seen;
    for (var i = 0; i < 60 && seen != expected; i++) {
      await pumpRealAsync(tester, const Duration(milliseconds: 50));
      seen = await centrePixel();
    }
    expect(seen, expected, reason: 'not the grey placeholder (0x808080FF)');
    expect(decoder.decodes, contains(3));
    expect(
      find.byKey(const Key('timelineVideoFrameUnavailable')),
      findsNothing,
      reason: 'the picture is drawn',
    );

    List<String> previewFolders() => [
      for (final entity in directory.listSync())
        if (entity.path.contains('timeline_preview_video_frames_')) entity.path,
    ];
    expect(previewFolders(), hasLength(1));

    appRouter.go('/');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(find.byType(TimelineScreen), findsNothing);
    expect(previewFolders(), isEmpty);
  });

  testWidgets(
    'a video whose picture cannot be drawn is marked in the preview',
    (tester) async {
      final decoder = _UnreadableDecoder();
      TimelineScreen.videoDecoderFor = (_) => decoder;
      addTearDown(
        () =>
            TimelineScreen.videoDecoderFor = FfmpegVideoFrameDecoder.ffmpegKit,
      );
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': 0,
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      final directory = Directory.systemTemp.createTempSync('timeline-video-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      // Registering a material reads its metadata with FFmpegKit, which has no
      // plugin in tests; the material stays registered without it.
      const ffmpegEvents = EventChannel(
        'flutter.arthenica.com/ffmpeg_kit_event',
      );
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

      final projectId = await tester.runAsync(() async {
        final project = await ps.createProject(
          name: 'video-preview',
          fps: 10,
          durationSeconds: 1,
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
        final sceneId = ps.scenesOf(project.id).first.id;
        final layer = ps.addLayer(
          projectId: project.id,
          sceneId: sceneId,
          frameIndex: 0,
          type: LayerType.timelineVideo,
          name: 'clip',
        );
        final tiles = ps.tileManagerOf(project.id);
        // The grey placeholder the project stores for a video layer.
        tiles.replaceLayerPixels(
          ps.tileKeyFor(project.id, sceneId, 0, layer.id),
          Uint8List.fromList(
            List.generate(
              tiles.canvasWidth * tiles.canvasHeight * 4,
              (i) => i % 4 == 3 ? 255 : 128,
            ),
          ),
        );
        ps.updateLayer(
          projectId: project.id,
          sceneId: sceneId,
          frameIndex: 0,
          layer: layer.copyWith(
            rangeMode: LayerRangeMode.frameRange,
            rangeStart: 1,
            rangeEnd: 10,
            materialId: asset.id,
            sourceTrimStart: 3,
            sourceTrimEnd: 12,
          ),
        );
        return project.id;
      });

      appRouter.go('/timeline/$projectId');
      await pumpRealAsync(tester, const Duration(milliseconds: 600));

      // The file cannot be read: the preview draws nothing for it, and says so.
      final mark = find.byKey(const Key('timelineVideoFrameUnavailable'));
      for (var i = 0; i < 40 && mark.evaluate().isEmpty; i++) {
        await pumpRealAsync(tester, const Duration(milliseconds: 50));
      }
      expect(mark, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
