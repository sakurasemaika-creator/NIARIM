import 'dart:io';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_crop.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/layer_region_edit.dart';
import 'package:niarim/models/video_track_display.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

const _crop = LayerCrop(left: 0.1, top: 0, right: 0.9, bottom: 1);

final _regions = [
  LayerRegionEdit(
    id: 'r1',
    kind: RegionEditKind.move,
    region: RegionSelection.box(
      RegionShape.ellipse,
      const Rect.fromLTRB(0.2, 0.2, 0.5, 0.6),
    ),
    dx: 0.1,
    rotation: 20,
  ),
  LayerRegionEdit(
    id: 'r2',
    kind: RegionEditKind.erase,
    region: RegionSelection.freehand(const [
      Offset(0.6, 0.6),
      Offset(0.9, 0.7),
      Offset(0.7, 0.9),
    ]),
  ),
];

/// The edit settings of a sped-up, cropped, region-edited video and a
/// sped-up audio clip (spec 26 §5, §6).
void _expectSettingsKept(Layer layer, {required String reason}) {
  expect(layer.playbackRate, 2, reason: reason);
  expect(layer.sourceTrimStart, 1, reason: reason);
  expect(layer.sourceTrimStartFraction, 0.25, reason: reason);
  expect(layer.sourceTrimEnd, 20, reason: reason);
  expect(layer.videoSoundFollowsSpeed, isFalse, reason: reason);
  expect(layer.videoVolume, 0.6, reason: reason);
  expect(layer.crop, _crop, reason: reason);
  expect(layer.regionEdits, _regions, reason: reason);
}

/// A clip's edit settings go with it when it is cut and pasted, copied and
/// pasted, duplicated, auto-saved and its project duplicated. Cutting takes
/// the clip away at once and pasting brings it back from the clipboard, one
/// Undo each; copy-and-paste and duplicate are one Undo each.
void main() {
  testWidgets('cut, copy, paste and duplicate keep a clip\'s speed, crop, '
      'region edits and pixels, one Undo each; autosave and a duplicated '
      'project keep them too', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-kept-');
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
    late String videoId;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'kept',
        fps: 10,
        durationSeconds: 4,
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
          rangeEnd: 8,
          sourceTrimStart: 1,
          sourceTrimStartFraction: 0.25,
          sourceTrimEnd: 20,
          playbackRate: 2,
          videoSoundFollowsSpeed: false,
          videoVolume: 0.6,
          crop: _crop,
          regionEdits: _regions,
          keyframes: const [
            LayerKeyframe(frameIndex: 0),
            LayerKeyframe(frameIndex: 7, x: 30),
          ],
        ),
      );
      ps.setVideoRowDisplay(project.id, sceneId, 0, VideoTrackDisplay.waveform);
      ps.addAudioClip(
        project.id,
        sceneId,
        const AudioClip(
          id: 'a',
          label: 'A',
          startFrame: 0,
          lengthFrames: 6,
          sourceStartFrame: 2,
          sourceStartFraction: 0.5,
          playbackRate: 1.5,
          volume: 0.7,
          fadeIn: 0.2,
        ),
      );
      return project.id;
    });
    final projectId = created!;
    // The video's pixels, which pasting carries to the new layer.
    final pixels = Uint8List(TileManager.tileSize * TileManager.tileSize * 4)
      ..fillRange(0, 4096, 200);
    ps.tileManagerOf(projectId).putLayerTiles(
      ps.tileKeyFor(projectId, sceneId, 0, videoId),
      {'0,0': pixels},
    );
    Map<String, Uint8List>? tilesOf(String layerId) => ps
        .tileManagerOf(projectId)
        .shareLayerTiles(ps.tileKeyFor(projectId, sceneId, 0, layerId));
    List<Layer> videos() => [
      for (final l in ps.storedLayersOf(projectId, sceneId, 0))
        if (l.type == LayerType.timelineVideo) l,
    ]..sort((a, b) => (a.rangeStart ?? 0).compareTo(b.rangeStart ?? 0));
    Future<void> settle() =>
        pumpRealAsync(tester, const Duration(milliseconds: 300));

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    Future<void> undo() async {
      await tester.tap(find.byIcon(Icons.undo).first);
      await settle();
    }

    Future<void> redo() async {
      await tester.tap(find.byIcon(Icons.redo).first);
      await settle();
    }

    // Pasted clips go to the playhead: frame 16 (from 0: 15).
    Future<void> playheadTo16() async {
      for (var i = 0; i < 15; i++) {
        await tester.tap(find.byTooltip(l10n.timelineStepForward).first);
        await tester.pump();
      }
      await settle();
    }

    Future<void> playheadToStart() async {
      await tester.tap(find.byTooltip(l10n.timelineSkipToStart).first);
      await settle();
    }

    Future<void> paste() async {
      await playheadTo16();
      await tester.tap(find.byKey(const Key('timelinePasteButton')).first);
      await settle();
      await playheadToStart();
    }

    Future<void> selectClip(String id) async {
      await tester.tap(find.byKey(const Key('timelineSelectionMenu')));
      await settle();
      await tester.tap(find.text(l10n.timelineSelectionClips).last);
      await settle();
      final clip = find.byKey(ValueKey('timelineClip-$id'));
      await tester.ensureVisible(clip);
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
      await settle();
    }

    // ── Cut: the video goes at once (spec 26 §5), one Undo of its own.
    await selectClip(videoId);
    await tester.tap(find.byTooltip(l10n.commonCut).last);
    await settle();
    expect(videos(), isEmpty);
    await undo();
    expect(videos().single.id, videoId);
    expect(videos().single.rangeStart, 1);
    _expectSettingsKept(videos().single, reason: 'cut undone');
    await redo();
    expect(videos(), isEmpty);

    // ── Paste: the cut video, gone from the scene, comes back at frame 16
    // with all its settings and its pixels.
    await paste();
    final moved = videos().single;
    expect(moved.id, isNot(videoId));
    expect([moved.rangeStart, moved.rangeEnd], [16, 23]);
    _expectSettingsKept(moved, reason: 'cut and pasted');
    // Its keyframes move with it.
    expect(moved.keyframes.map((k) => k.frameIndex), [15, 22]);
    expect(tilesOf(moved.id), tilesOf(videoId), reason: 'its pixels');
    // Pasting is its own Undo: the first takes the pasted video away, the
    // next undoes the cut.
    await undo();
    expect(videos(), isEmpty);
    await redo();
    expect(videos().single.rangeStart, 16);
    await undo();
    await undo();
    expect(videos().single.id, videoId);
    expect(videos().single.rangeStart, 1);

    // ── Copy and paste: a second video at frame 16, the first stays.
    await selectClip(videoId);
    await tester.tap(find.byTooltip(l10n.commonCopy).last);
    await settle();
    await paste();
    expect(videos().map((l) => l.rangeStart), [1, 16]);
    _expectSettingsKept(videos()[1], reason: 'copied and pasted');
    await undo();
    expect(videos().map((l) => l.id), [videoId]);

    // ── The audio clip copied and pasted keeps its speed and fraction.
    await selectClip('a');
    await tester.tap(find.byTooltip(l10n.commonCopy).last);
    await settle();
    await paste();
    final copies = ps.audioClipsOf(projectId, sceneId).toList()
      ..sort((x, y) => x.startFrame.compareTo(y.startFrame));
    expect(copies, hasLength(2));
    expect(copies[1].startFrame, 15);
    expect(copies[1].playbackRate, 1.5);
    expect(copies[1].sourceStartFrame, 2);
    expect(copies[1].sourceStartFraction, 0.5);
    expect([copies[1].volume, copies[1].fadeIn], [0.7, 0.2]);
    await undo();
    expect(ps.audioClipsOf(projectId, sceneId), hasLength(1));

    // ── Duplicate from the material panel: right after the original.
    final clip = find.byKey(ValueKey('timelineClip-$videoId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
    await settle();
    await tester.tap(find.byTooltip(l10n.commonDuplicate).first);
    await settle();
    expect(videos().map((l) => l.rangeStart), [1, 9]);
    _expectSettingsKept(videos()[1], reason: 'duplicated');
    await undo();
    expect(videos().map((l) => l.id), [videoId]);

    // ── Autosave and a duplicated project.
    final project = ps.projects.firstWhere((p) => p.id == projectId);
    await tester.runAsync(() async {
      await NiaproSerializer.saveAutosave(
        project: project,
        scenes: ps.scenesOf(projectId),
        tileManager: ps.tileManagerOf(projectId),
        slotIndex: 0,
      );
      final restored = await NiaproSerializer.loadAutosave(projectId, 0);
      final scene = restored.scenes.firstWhere((s) => s.id == sceneId);
      final layer = scene.frames
          .expand((f) => f.layers)
          .firstWhere((l) => l.id == videoId);
      _expectSettingsKept(layer, reason: 'autosaved');
      expect(scene.videoRowDisplays.first, VideoTrackDisplay.waveform);
      final sound = scene.audioClips.single;
      expect(sound.playbackRate, 1.5);
      expect(sound.sourceStartFraction, 0.5);

      final before = ps.projects.map((p) => p.id).toSet();
      expect(await ps.duplicateProject(projectId), isTrue);
      final copyId = ps.projects
          .map((p) => p.id)
          .firstWhere((id) => !before.contains(id));
      final copied = ps.scenesOf(copyId).single;
      final copiedVideo = copied.frames
          .expand((f) => f.layers)
          .firstWhere((l) => l.type == LayerType.timelineVideo);
      _expectSettingsKept(copiedVideo, reason: 'project duplicated');
      expect(copied.videoRowDisplays.first, VideoTrackDisplay.waveform);
      expect(copied.audioClips.single.playbackRate, 1.5);
      expect(copied.audioClips.single.sourceStartFraction, 0.5);
    });
  });
}
