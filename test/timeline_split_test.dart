import 'dart:io';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/clip_speed.dart';
import 'package:niarim/engine/export_audio.dart';
import 'package:niarim/engine/timeline_video_time.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// Splitting at the playhead in the real timeline screen: every clip that
/// crosses it becomes two that play exactly what the one did (source
/// position with its speed, fades, keyframes, mask, row, group), and one
/// Undo puts the scene back.
void main() {
  testWidgets('splitting keeps what every track type plays, and one Undo '
      'restores it', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-split-');
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

    const mask = LayerMask(centerX: 40, width: 30, feather: 5);
    late String sceneId;
    late Layer video;
    late Layer image;
    late Layer text;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'split',
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
          materialId: 'm',
          startFrame: 0,
          lengthFrames: 10,
          sourceStartFrame: 2,
          volume: 0.8,
          fadeIn: 0.3,
          fadeOut: 0.4,
          playbackRate: 1.5,
        ),
      );
      ps.addAudioClip(
        project.id,
        sceneId,
        const AudioClip(
          id: 'r',
          label: 'R',
          startFrame: 2,
          lengthFrames: 6,
          isReadAloud: true,
        ),
      );
      Layer add(LayerType type, String name, Layer Function(Layer) edit) {
        final layer = ps.addLayer(
          projectId: project.id,
          sceneId: sceneId,
          frameIndex: 0,
          type: type,
          name: name,
        );
        final edited = edit(layer);
        ps.updateLayer(
          projectId: project.id,
          sceneId: sceneId,
          frameIndex: 0,
          layer: edited,
        );
        return edited;
      }

      video = add(
        LayerType.timelineVideo,
        'video',
        (l) => l.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 10,
          materialId: 'm',
          sourceTrimStart: 1,
          sourceTrimEnd: 29,
          playbackRate: 1.5,
          videoVolume: 0.6,
          videoSoundFollowsSpeed: false,
          mask: mask,
          keyframes: const [
            LayerKeyframe(frameIndex: 0),
            LayerKeyframe(frameIndex: 8, x: 30),
          ],
        ),
      );
      image = add(
        LayerType.timelineImage,
        'image',
        (l) => l.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 3,
          rangeEnd: 8,
          keyframes: const [
            LayerKeyframe(frameIndex: 2),
            LayerKeyframe(frameIndex: 7, scale: 2),
          ],
        ),
      );
      text = add(
        LayerType.timelineText,
        'text',
        (l) => l.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 10,
        ),
      );
      ps.addLayerGroup(project.id, sceneId, 'g', [image.id]);
      return project.id;
    });
    final projectId = created!;

    List<Layer> layersNamed(String name) => [
      for (final l in ps.storedLayersOf(projectId, sceneId, 0))
        if (l.name == name) l,
    ]..sort((a, b) => (a.rangeStart ?? 0).compareTo(b.rangeStart ?? 0));
    Future<List<ExportAudioSource>> soundPlan() async => (await tester.runAsync(
      () => buildExportAudioPlan(
        scenes: [ps.sceneOf(projectId, sceneId)!],
        sourceFps: 10,
        pathOf: (_) async => Platform.resolvedExecutable,
      ),
    ))!.sources;
    final soundBefore = await soundPlan();

    appRouter.go('/timeline/$projectId?frame=4');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('timelineSplitModeButton')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('timelineSplitApplyButton')));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));

    // ── Audio: fades stay on the outer ends; the right half starts where the
    // 1.5x clip had got to (2 + 4 × 1.5 = 8).
    final audio = ps.audioClipsOf(projectId, sceneId).toList()
      ..sort((a, b) => a.startFrame.compareTo(b.startFrame));
    final music = audio.where((c) => !c.isReadAloud).toList();
    expect(music, hasLength(2));
    expect(music[0].id, 'a');
    expect([music[0].startFrame, music[0].lengthFrames], [0, 4]);
    expect([music[0].fadeIn, music[0].fadeOut], [0.3, 0]);
    expect([music[1].startFrame, music[1].lengthFrames], [4, 6]);
    expect([music[1].fadeIn, music[1].fadeOut], [0, 0.4]);
    expect(music[1].sourceStartFrame, 8);
    expect(music[1].sourceStartFraction, 0);
    expect([music[1].playbackRate, music[1].volume], [1.5, 0.8]);
    final readAloud = audio.where((c) => c.isReadAloud).toList();
    expect(
      [
        for (final c in readAloud) [c.startFrame, c.lengthFrames],
      ],
      [
        [2, 2],
        [4, 4],
      ],
    );

    // The exported sound plays the same source time at the same moments.
    final soundAfter = await soundPlan();
    final musicBefore = soundBefore.where((s) => s.playbackRate == 1.5).single;
    final musicAfter = soundAfter.where((s) => s.playbackRate == 1.5).toList()
      ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
    expect(musicAfter, hasLength(2));
    expect(musicAfter[0].startSeconds, musicBefore.startSeconds);
    expect(musicAfter[0].sourceSeconds, musicBefore.sourceSeconds);
    expect(
      musicAfter[1].sourceSeconds,
      closeTo(
        musicBefore.sourceSeconds +
            (musicAfter[1].startSeconds - musicBefore.startSeconds) * 1.5,
        1e-9,
      ),
    );
    expect(
      musicAfter[0].durationSeconds + musicAfter[1].durationSeconds,
      closeTo(musicBefore.durationSeconds, 1e-9),
    );

    // ── Video: every frame shows the same source time as before; the right
    // half keeps the speed, sound setting, mask, keyframes and row.
    final videos = layersNamed('video');
    expect(videos, hasLength(2));
    expect([videos[0].rangeStart, videos[0].rangeEnd], [1, 4]);
    expect([videos[1].rangeStart, videos[1].rangeEnd], [5, 10]);
    for (var frame = 0; frame < 10; frame++) {
      final half = frame < 4 ? videos[0] : videos[1];
      expect(
        TimelineVideoTimeMapper.layerSourceTimeAt(half, frame, 10),
        TimelineVideoTimeMapper.layerSourceTimeAt(video, frame, 10),
        reason: 'frame $frame',
      );
    }
    final right = videos[1];
    expect(right.playbackRate, 1.5);
    expect(right.videoSoundFollowsSpeed, isFalse);
    expect(right.videoVolume, 0.6);
    expect(right.mask?.centerX, mask.centerX);
    expect(right.mask?.width, mask.width);
    expect(right.trackRow, video.trackRow);
    expect(right.keyframes.map((k) => k.frameIndex), [0, 8]);
    expect(
      sourcePositionAfter(
        startFrame: 1,
        startFraction: 0,
        elapsedFrames: 4,
        rate: 1.5,
      ),
      (frame: right.sourceTrimStart!, fraction: right.sourceTrimStartFraction),
    );

    // ── Image and text: display periods split; keyframes and group kept.
    final images = layersNamed('image');
    expect(
      [
        for (final l in images) [l.rangeStart, l.rangeEnd],
      ],
      [
        [3, 4],
        [5, 8],
      ],
    );
    for (final l in images) {
      expect(l.keyframes.map((k) => k.frameIndex), [2, 7]);
    }
    final group = ps.groupContainingLayer(projectId, sceneId, image.id)!;
    expect(group.memberLayerIds, containsAll([for (final l in images) l.id]));
    expect(layersNamed('text'), hasLength(2));
    expect(layersNamed('text').first.id, text.id);

    // ── One Undo puts everything back.
    await tester.tap(find.byIcon(Icons.undo).first);
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(ps.audioClipsOf(projectId, sceneId), hasLength(2));
    expect(ps.audioClipsOf(projectId, sceneId).first.lengthFrames, 10);
    expect(layersNamed('video'), hasLength(1));
    expect(layersNamed('video').single.rangeEnd, 10);
    expect(layersNamed('image'), hasLength(1));
    expect(layersNamed('text'), hasLength(1));
    expect(
      ps.groupContainingLayer(projectId, sceneId, image.id)!.memberLayerIds,
      [image.id],
    );
  });

  testWidgets('splitting a video where its last frame is held keeps showing '
      'that frame on both halves', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-held-');
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
    late Layer video;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'held',
        fps: 10,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      sceneId = ps.scenesOf(project.id).first.id;
      final layer = ps.addLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.timelineVideo,
        name: 'video',
      );
      // Source frames 0–5 over 10 timeline frames: frames 6–9 hold frame 5.
      video = layer.copyWith(
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: 1,
        rangeEnd: 10,
        sourceTrimStart: 0,
        sourceTrimEnd: 5,
      );
      ps.updateLayer(
        projectId: project.id,
        sceneId: sceneId,
        frameIndex: 0,
        layer: video,
      );
      return project.id;
    });
    final projectId = created!;
    appRouter.go('/timeline/$projectId?frame=7');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('timelineSplitModeButton')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('timelineSplitApplyButton')));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));

    final halves = [
      for (final l in ps.storedLayersOf(projectId, sceneId, 0))
        if (l.name == 'video') l,
    ]..sort((a, b) => (a.rangeStart ?? 0).compareTo(b.rangeStart ?? 0));
    expect(halves, hasLength(2));
    for (var frame = 0; frame < 10; frame++) {
      final half = frame < 7 ? halves[0] : halves[1];
      expect(
        TimelineVideoTimeMapper.layerSourceTimeAt(half, frame, 10),
        TimelineVideoTimeMapper.layerSourceTimeAt(video, frame, 10),
        reason: 'frame $frame',
      );
    }
  });
}
