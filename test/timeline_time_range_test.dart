import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/screens/timeline/widgets/clip_speed_control.dart';
import 'package:niarim/screens/timeline/widgets/clip_time_range_control.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/icon_notice.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

final _captureKey = GlobalKey();

/// Writes the screen to build/timeline-time-range/[name].png for a look.
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
  final directory = Directory('build/timeline-time-range')
    ..createSync(recursive: true);
  File('${directory.path}/$name.png').writeAsBytesSync(bytes!);
}

/// 長さ調整's time range in the real screen: an image's and a video's first
/// and last frame typed in the material panel (one Undo each, overlaps and
/// bad numbers refused, the video's speed beside it), and an audio clip's in
/// its sheet (its sound keeps its timing; Cancel puts it back).
void main() {
  testWidgets('the 長さ調整 time range moves a material\'s and an audio '
      'clip\'s first and last frame', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-range-');
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

    late String sceneId;
    late String imageId;
    late String otherId;
    late String videoId;
    final created = await tester.runAsync(() async {
      // 3 seconds at 10 fps: frames 1–30.
      final project = await ps.createProject(
        name: 'range',
        fps: 10,
        durationSeconds: 3,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      sceneId = ps.scenesOf(project.id).first.id;
      Layer add(LayerType type, String name, int start, int end, int row) {
        final layer = ps.addLayer(
          projectId: project.id,
          sceneId: sceneId,
          frameIndex: 0,
          type: type,
          name: name,
        );
        final placed = layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: start,
          rangeEnd: end,
          trackRow: row,
          sourceTrimStart: type == LayerType.timelineVideo ? 0 : null,
          sourceTrimEnd: type == LayerType.timelineVideo ? end - start : null,
        );
        ps.updateLayer(
          projectId: project.id,
          sceneId: sceneId,
          frameIndex: 0,
          layer: placed,
        );
        return placed;
      }

      imageId = add(LayerType.timelineImage, 'picture', 1, 10, 0).id;
      otherId = add(LayerType.timelineImage, 'other', 21, 25, 0).id;
      videoId = add(LayerType.timelineVideo, 'clip', 1, 8, 0).id;
      ps.addAudioClip(
        project.id,
        sceneId,
        const AudioClip(
          id: 'a',
          label: 'A',
          startFrame: 2,
          lengthFrames: 6,
          sourceStartFrame: 1,
        ),
      );
      return project.id;
    });
    final projectId = created!;
    Layer layer(String id) =>
        ps.storedLayersOf(projectId, sceneId, 0).firstWhere((l) => l.id == id);
    AudioClip audio() =>
        ps.audioClipsOf(projectId, sceneId).firstWhere((c) => c.id == 'a');
    Future<void> settle() =>
        pumpRealAsync(tester, const Duration(milliseconds: 300));

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;

    Future<void> openClip(String id) async {
      final clip = find.byKey(ValueKey('timelineClip-$id'));
      await tester.ensureVisible(clip);
      await tester.pump();
      // Near its start: a long clip runs past the screen's right edge.
      await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
      await pumpRealAsync(tester, const Duration(milliseconds: 400));
    }

    Future<void> openDuration() async {
      final chip = find.widgetWithIcon(ChoiceChip, Icons.timelapse);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await settle();
    }

    Future<void> type(String key, String value) async {
      final field = find.byKey(ValueKey(key));
      await tester.ensureVisible(field);
      await tester.pump();
      await tester.enterText(field, value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
    }

    String? notice(String key) {
      final found = find.byKey(ValueKey(key));
      if (found.evaluate().isEmpty) return null;
      return tester.widget<IconNotice>(found).message;
    }

    // ── An image: frames 1–10.
    await openClip(imageId);
    await openDuration();
    expect(find.byType(ClipTimeRangeControl), findsOneWidget);
    // An image has no speed (spec: only its time range).
    expect(find.byType(ClipSpeedControl), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('clipRangeLength'))).data,
      l10n.timelineDurationLength(10, '1.00'),
    );

    // The end to frame 15: the start stays.
    await type('clipRangeEnd', '15');
    expect(layer(imageId).rangeStart, 1);
    expect(layer(imageId).rangeEnd, 15);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('clipRangeLength'))).data,
      l10n.timelineDurationLength(15, '1.50'),
    );
    // The start to frame 3: the end stays.
    await type('clipRangeStart', '3');
    expect(layer(imageId).rangeStart, 3);
    expect(layer(imageId).rangeEnd, 15);

    // Each change is one Undo.
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle();
    expect(layer(imageId).rangeStart, 1);
    expect(layer(imageId).rangeEnd, 15);
    final startField = tester.widget<TextField>(
      find.byKey(const ValueKey('clipRangeStart')),
    );
    expect(startField.controller!.text, '1');
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle();
    expect(layer(imageId).rangeEnd, 10);

    // Into the other image on the same row (frames 21–25): refused.
    await type('clipRangeEnd', '22');
    expect(notice('clipRangeProblem'), l10n.timelineDurationOverlap);
    await _capture(tester, '1_image_overlap_refused');
    expect(layer(imageId).rangeEnd, 10);
    // Past the scene, after the end, or not a number: not applied.
    for (final (key, value) in [
      ('clipRangeEnd', '31'),
      ('clipRangeStart', '12'),
      ('clipRangeStart', 'x'),
    ]) {
      await type(key, value);
      expect(
        notice('clipRangeInvalid'),
        l10n.timelineDurationInvalid(30),
        reason: '$key=$value',
      );
      expect(layer(imageId).rangeStart, 1, reason: '$key=$value');
      expect(layer(imageId).rangeEnd, 10, reason: '$key=$value');
      // Back to what it is.
      await type(key, key == 'clipRangeEnd' ? '10' : '1');
    }
    expect(layer(otherId).rangeStart, 21);

    // ── A video: the time range and the speed in the one section.
    await tester.tap(find.byIcon(Icons.check).first);
    await settle();
    await openClip(videoId);
    await openDuration();
    expect(find.byType(ClipTimeRangeControl), findsOneWidget);
    expect(find.byType(ClipSpeedControl), findsOneWidget);
    await type('clipRangeEnd', '12');
    await _capture(tester, '2_video_range_and_speed');
    expect(layer(videoId).rangeEnd, 12);
    // Its used part stays: the added frames hold the last used frame.
    expect(layer(videoId).sourceTrimStart, 0);
    expect(layer(videoId).sourceTrimEnd, 7);
    // The speed is no longer in the video section.
    final videoChip = find.widgetWithIcon(ChoiceChip, Icons.videocam);
    await tester.ensureVisible(videoChip);
    await tester.tap(videoChip);
    await settle();
    expect(find.byType(ClipSpeedControl), findsNothing);
    await tester.tap(find.byIcon(Icons.check).first);
    await settle();

    // ── An audio clip: frames 3–8, playing its sound from its frame 2.
    final audioClip = find.byKey(const ValueKey('timelineClip-a'));
    Future<void> openAudio() async {
      await tester.ensureVisible(audioClip);
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(audioClip) + const Offset(30, 20));
      await settle();
    }

    await openAudio();
    expect(find.byType(ClipTimeRangeControl), findsOneWidget);
    // Starting earlier than its sound's beginning is refused.
    await type('clipRangeStart', '1');
    expect(notice('clipRangeProblem'), l10n.timelineDurationBeforeSource);
    await _capture(tester, '3_audio_before_its_sound');
    // Starting a frame earlier plays its sound from a frame earlier.
    await type('clipRangeStart', '2');
    expect(notice('clipRangeProblem'), isNull);
    // Cancel puts it back.
    await tester.tap(find.byTooltip(l10n.commonCancel));
    await settle();
    expect(audio().startFrame, 2);
    expect(audio().sourceStartFrame, 1);
    expect(audio().lengthFrames, 6);

    // Again, kept with OK: frames 2–12 (from 0: 1–11), the sound from its
    // beginning.
    await openAudio();
    await type('clipRangeStart', '2');
    await type('clipRangeEnd', '12');
    await tester.tap(find.byTooltip(l10n.commonOk));
    await settle();
    expect(audio().startFrame, 1);
    expect(audio().sourceStartFrame, 0);
    expect(audio().lengthFrames, 11);
  });
}
