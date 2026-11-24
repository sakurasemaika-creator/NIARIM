import 'dart:io';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/video_frame_decoder.dart';
import 'package:niarim/engine/video_frame_timeline.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/screens/timeline/widgets/clip_speed_control.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/icon_notice.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

class _BlankDecoder implements VideoFrameDecoder {
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
  }) async => DecodedVideoFrame(
    rgba: Uint8List(width * height * 4),
    width: width,
    height: height,
    frameIndex: frameIndex,
  );
}

void main() {
  testWidgets('speed: the audio sheet changes a clip\'s length and refuses an '
      'overlap; the video panel retimes keyframes and Undo restores it', (
    tester,
  ) async {
    TimelineScreen.videoDecoderFor = (_) => _BlankDecoder();
    addTearDown(
      () => TimelineScreen.videoDecoderFor = FfmpegVideoFrameDecoder.ffmpegKit,
    );
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-speed-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
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
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();

    late String sceneId;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'speed',
        fps: 10,
        durationSeconds: 3,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      sceneId = ps.scenesOf(project.id).first.id;
      ps.addAudioClip(
        project.id,
        sceneId,
        const AudioClip(id: 'a', label: 'A', startFrame: 0, lengthFrames: 10),
      );
      ps.addAudioClip(
        project.id,
        sceneId,
        const AudioClip(id: 'b', label: 'B', startFrame: 15, lengthFrames: 5),
      );
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
          rangeEnd: 10,
          sourceTrimStart: 0,
          sourceTrimEnd: 9,
          keyframes: const [
            LayerKeyframe(frameIndex: 0),
            LayerKeyframe(frameIndex: 8, x: 40),
          ],
        ),
      );
      return project.id;
    });
    final projectId = created!;

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    AudioClip audio(String id) =>
        ps.audioClipsOf(projectId, sceneId).firstWhere((c) => c.id == id);
    Layer video() => ps
        .storedLayersOf(projectId, sceneId, 0)
        .firstWhere((l) => l.type == LayerType.timelineVideo);
    final videoId = video().id;

    // Clips run past the right edge at this zoom: tap inside their left part,
    // clear of the resize handle.
    Future<void> tapClip(Finder clip) async {
      await tester.ensureVisible(clip);
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(clip) + const Offset(60, 20));
      await pumpRealAsync(tester, const Duration(milliseconds: 400));
    }

    Future<void> tapQuick(double rate) async {
      final chip = find.byKey(ValueKey('clipSpeedQuick$rate'));
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
    }

    // ── Audio ──
    final clipA = find.byKey(const ValueKey('timelineClip-a'));
    await tapClip(clipA);
    expect(find.byType(ClipSpeedControl), findsOneWidget);

    // 0.5x would make A 20 frames long, over B at frame 15.
    await tapQuick(0.5);
    expect(
      tester
          .widget<IconNotice>(find.byKey(const ValueKey('clipSpeedProblem')))
          .message,
      l10n.timelineClipSpeedOverlap,
    );
    // 2x: 5 frames.
    await tapQuick(2.0);
    expect(find.byKey(const ValueKey('clipSpeedProblem')), findsNothing);
    await tester.tap(find.byTooltip(l10n.commonOk));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(audio('a').playbackRate, 2.0);
    expect(audio('a').lengthFrames, 5);
    expect(audio('b').lengthFrames, 5);

    // Cancel puts the speed and length back.
    await tapClip(clipA);
    await tapQuick(4.0);
    await tester.tap(find.byTooltip(l10n.commonCancel));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(audio('a').playbackRate, 2.0);
    expect(audio('a').lengthFrames, 5);

    // ── Video ──
    final clipV = find.byKey(ValueKey('timelineClip-$videoId'));
    await tapClip(clipV);
    // The speed is in the panel's 長さ調整 section, with the time range.
    final durationChip = find.widgetWithIcon(ChoiceChip, Icons.timelapse);
    await tester.ensureVisible(durationChip);
    await tester.tap(durationChip);
    await tester.pump();
    expect(find.byType(ClipSpeedControl), findsOneWidget);

    await tapQuick(2.0);
    expect(find.byKey(const ValueKey('clipSpeedProblem')), findsNothing);
    expect(video().playbackRate, 2.0);
    expect(video().rangeEnd, 5);
    expect(video().keyframes.map((k) => k.frameIndex), [0, 4]);
    expect(video().keyframes.last.x, 40);

    // 100x would put both keyframes on frame 0.
    await tapQuick(100.0);
    expect(
      tester
          .widget<IconNotice>(find.byKey(const ValueKey('clipSpeedProblem')))
          .message,
      l10n.timelineClipSpeedKeyframeClash,
    );
    expect(video().playbackRate, 2.0);

    // One Undo returns the speed, the length and the keyframes together.
    final undo = find.byIcon(Icons.undo).first;
    await tester.tap(undo);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(video().playbackRate, 1.0);
    expect(video().rangeEnd, 10);
    expect(video().keyframes.map((k) => k.frameIndex), [0, 8]);

    // The sound can stay at normal speed (one Undo step too).
    final soundSwitch = find.byKey(const ValueKey('videoSoundFollowsSpeed'));
    await tester.ensureVisible(soundSwitch);
    await tester.pump();
    await tester.tap(soundSwitch);
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(video().videoSoundFollowsSpeed, isFalse);
    await tester.tap(undo);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(video().videoSoundFollowsSpeed, isTrue);
  });

  testWidgets('a range of camera keys and of a material\'s keys plays at a '
      'chosen speed; a speed that would leave the scene is refused; one Undo '
      'puts them back', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-retime-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
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
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();

    late String sceneId;
    late String imageId;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'retime',
        fps: 10,
        durationSeconds: 3,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      sceneId = ps.scenesOf(project.id).first.id;
      for (final f in [0, 10, 20]) {
        ps.addCameraKeyframe(
          project.id,
          sceneId,
          CameraKeyframe(frameIndex: f, x: f.toDouble()),
        );
      }
      final layer = ps.addLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.timelineImage,
        name: 'picture',
      );
      imageId = layer.id;
      ps.updateLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 20,
          keyframes: const [
            LayerKeyframe(frameIndex: 0),
            LayerKeyframe(frameIndex: 6, x: 10),
            LayerKeyframe(frameIndex: 12, x: 20),
          ],
        ),
      );
      return project.id;
    });
    final projectId = created!;
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    List<int> cameraKeys() => [
      for (final k in ps.cameraKeyframesOf(projectId, sceneId)) k.frameIndex,
    ];
    List<int> imageKeys() => [
      for (final k
          in ps
              .storedLayersOf(projectId, sceneId, 0)
              .firstWhere((l) => l.id == imageId)
              .keyframes)
        k.frameIndex,
    ];
    String previewText() => tester
        .widget<IconNotice>(find.byKey(const ValueKey('keyframeRetimePreview')))
        .message;
    Future<void> tapQuick(double rate) async {
      final chip = find.byKey(ValueKey('clipSpeedQuick$rate'));
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
    }

    // ── Camera: the whole range at 2x ──
    final cameraButton = find.byKey(const ValueKey('cameraKeyframeRetime'));
    await tester.ensureVisible(cameraButton);
    await tester.tap(cameraButton);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(
      previewText(),
      l10n.keyframeRetimePreview('F1 · F11 · F21', 'F1 · F11 · F21'),
    );
    await tapQuick(2.0);
    expect(
      previewText(),
      l10n.keyframeRetimePreview('F1 · F11 · F21', 'F1 · F6 · F11'),
    );
    // 0.25x would put the last key at F81, past the scene's 30 frames.
    await tapQuick(0.25);
    expect(
      tester
          .widget<IconNotice>(find.byKey(const ValueKey('clipSpeedProblem')))
          .message,
      l10n.keyframeRetimeClash,
    );
    await tester.tap(find.byKey(const ValueKey('keyframeRetimeApply')));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(cameraKeys(), [0, 5, 10]);
    expect(ps.cameraKeyframesOf(projectId, sceneId).map((k) => k.x), [
      0,
      10,
      20,
    ]);
    await tester.tap(find.byIcon(Icons.undo).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(cameraKeys(), [0, 10, 20]);

    // ── Image: the keys F7–F13 at 0.5x; F1 stays put ──
    final clip = find.byKey(ValueKey('timelineClip-$imageId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(60, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final transformChip = find.widgetWithIcon(ChoiceChip, Icons.open_with);
    if (transformChip.evaluate().isNotEmpty) {
      await tester.ensureVisible(transformChip);
      await tester.tap(transformChip);
      await tester.pump();
    }
    final retimeButton = find.byKey(const ValueKey('keyframeRetimeButton'));
    await tester.ensureVisible(retimeButton);
    await tester.pump();
    await tester.tap(retimeButton);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('keyframeRetimeFrom')));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('F7').last);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tapQuick(0.5);
    expect(previewText(), l10n.keyframeRetimePreview('F7 · F13', 'F7 · F19'));
    await tester.tap(find.byKey(const ValueKey('keyframeRetimeApply')));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(imageKeys(), [0, 6, 18]);
    await tester.tap(find.byIcon(Icons.undo).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(imageKeys(), [0, 6, 12]);
  });

  testWidgets('cutting and pasting a clip keeps its speed and the fraction '
      'of a frame it starts at', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-paste-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
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
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    late String sceneId;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'paste',
        fps: 10,
        durationSeconds: 3,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      sceneId = ps.scenesOf(project.id).first.id;
      ps.addAudioClip(
        project.id,
        sceneId,
        const AudioClip(
          id: 'a',
          label: 'A',
          startFrame: 0,
          lengthFrames: 5,
          sourceStartFrame: 3,
          sourceStartFraction: 0.5,
          playbackRate: 2,
        ),
      );
      return project.id;
    });
    final projectId = created!;
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;

    await tester.tap(find.byKey(const Key('timelineSelectionMenu')));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text(l10n.timelineSelectionClips).last);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final clip = find.byKey(const ValueKey('timelineClip-a'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip(l10n.commonCut).last);
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('timelinePasteButton')).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));

    final clips = ps.audioClipsOf(projectId, sceneId);
    expect(clips, hasLength(1));
    final pasted = clips.single;
    expect(pasted.id, isNot('a'));
    expect(pasted.startFrame, 0);
    expect(pasted.lengthFrames, 5);
    expect(pasted.sourceStartFrame, 3);
    expect(pasted.sourceStartFraction, 0.5);
    expect(pasted.playbackRate, 2);
  });
}
