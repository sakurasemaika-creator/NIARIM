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
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pump_real_async.dart';

final _captureKey = GlobalKey();

/// Writes the screen to build/timeline-speed-mute/[name].png for a look.
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
  final directory = Directory('build/timeline-speed-mute')
    ..createSync(recursive: true);
  File('${directory.path}/$name.png').writeAsBytesSync(bytes!);
}

/// At high speeds the sound is hard to follow: the speed control says so
/// and offers to mute it (spec 26 2.2), for a video (one Undo) and an audio
/// clip (kept with OK).
void main() {
  testWidgets('a fast clip offers to mute its sound', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-mute-');
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
    late String videoId;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'mute',
        fps: 10,
        durationSeconds: 3,
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
          sourceTrimStart: 0,
          sourceTrimEnd: 60,
          playbackRate: 8,
          videoVolume: 0.8,
        ),
      );
      ps.addAudioClip(
        project.id,
        sceneId,
        const AudioClip(
          id: 'a',
          label: 'A',
          startFrame: 1,
          lengthFrames: 6,
          playbackRate: 4,
          volume: 0.7,
        ),
      );
      return project.id;
    });
    final projectId = created!;
    Layer video() => ps
        .storedLayersOf(projectId, sceneId, 0)
        .firstWhere((l) => l.id == videoId);
    AudioClip audio() =>
        ps.audioClipsOf(projectId, sceneId).firstWhere((c) => c.id == 'a');
    Future<void> settle() =>
        pumpRealAsync(tester, const Duration(milliseconds: 300));

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    final mute = find.byKey(const ValueKey('clipSpeedMute'));
    Future<void> tapMute() async {
      await tester.ensureVisible(mute);
      await tester.pump();
      await tester.tap(mute);
      await settle();
    }

    // ── The video at 8x: the note and the mute button.
    final clip = find.byKey(ValueKey('timelineClip-$videoId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final chip = find.widgetWithIcon(ChoiceChip, Icons.timelapse);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settle();
    expect(find.text(l10n.timelineClipSpeedSoundNote), findsOneWidget);
    await _capture(tester, '1_video_fast_note');
    await tapMute();
    expect(video().videoVolume, 0);
    // Muted: nothing left to say.
    expect(mute, findsNothing);
    expect(find.text(l10n.timelineClipSpeedSoundNote), findsNothing);
    // One Undo brings the sound back.
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle();
    expect(video().videoVolume, 0.8);
    await tester.tap(find.byIcon(Icons.check).first);
    await settle();

    // ── The audio clip at 4x.
    final audioClip = find.byKey(const ValueKey('timelineClip-a'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('timelineClip-a'), skipOffstage: false),
    );
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(audioClip) + const Offset(20, 20));
    await settle();
    await tapMute();
    expect(mute, findsNothing);
    await tester.tap(find.byTooltip(l10n.commonOk));
    await settle();
    expect(audio().volume, 0);
    expect(audio().playbackRate, 4);
  });
}
