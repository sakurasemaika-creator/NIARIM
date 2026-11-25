import 'dart:io';
import 'dart:ui' as ui;

import 'dart:async';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_timeline.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

final _captureKey = GlobalKey();

/// Writes the screen to build/timeline-playback-skips/[name].png for a look.
Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  final directory = Directory('build/timeline-playback-skips')
    ..createSync(recursive: true);
  File('${directory.path}/$name.png').writeAsBytesSync(bytes!);
}

/// A video whose frames take longer to decode than playback gives them
/// (they never finish here), as on a device that cannot keep up.
class _SlowDecoder implements VideoFrameDecoder {
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
  }) => Completer<DecodedVideoFrame>().future;
}

/// Playback that cannot keep up skips frames rather than slowing down (the
/// sound plays on in real time), and the preview says so while it plays
/// (spec 26 7.2); the export has every frame.
void main() {
  testWidgets('frames the preview could not show while playing are told', (
    tester,
  ) async {
    TimelineScreen.videoDecoderFor = (_) => _SlowDecoder();
    addTearDown(
      () => TimelineScreen.videoDecoderFor = FfmpegVideoFrameDecoder.ffmpegKit,
    );
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-skips-');
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
    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final materials = tester
        .element(find.byType(MaterialApp).first)
        .read<MaterialService>();
    final projectId = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'skips',
        fps: 10,
        durationSeconds: 3,
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
      ps.updateLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 30,
          materialId: asset.id,
          sourceTrimStart: 0,
          sourceTrimEnd: 29,
        ),
      );
      return project.id;
    });
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    final notice = find.byKey(const Key('timelinePlaybackSkipNotice'));
    expect(notice, findsNothing);

    // Play: the frames come faster than the video's frames can be made.
    await tester.tap(find.byTooltip(l10n.commonPlay).first);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(notice, findsOneWidget);
    expect(find.text(l10n.timelinePlaybackSkipNotice), findsOneWidget);
    await _capture(tester, '1_skipping');

    // Stopped: nothing to tell; the next playback starts afresh.
    await tester.tap(find.byTooltip(l10n.commonPause).first);
    await tester.pump();
    expect(notice, findsNothing);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
  });
}
