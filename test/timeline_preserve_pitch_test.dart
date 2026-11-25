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

/// Writes the screen to build/timeline-preserve-pitch/[name].png for a look.
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
  final directory = Directory('build/timeline-preserve-pitch')
    ..createSync(recursive: true);
  File('${directory.path}/$name.png').writeAsBytesSync(bytes!);
}

/// 音の高さを保つ in the real screen: the switch of a sped-up video (shown
/// only while its sound follows the speed; one Undo) and of an audio clip
/// (kept with OK, put back with Cancel).
void main() {
  testWidgets('the pitch switch of a video and of an audio clip', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-pitch-');
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
        name: 'pitch',
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
          sourceTrimEnd: 15,
          playbackRate: 2,
        ),
      );
      ps.addAudioClip(
        project.id,
        sceneId,
        const AudioClip(
          id: 'a',
          label: 'A',
          startFrame: 2,
          lengthFrames: 6,
          playbackRate: 1.5,
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

    Future<void> tapSwitch(String key) async {
      await tester.ensureVisible(
        find.byKey(ValueKey(key), skipOffstage: false),
      );
      await tester.pump();
      final found = find.byKey(ValueKey(key));
      await tester.pump();
      await tester.tap(found);
      await settle();
    }

    // The panel scrolls: a switch may be built but outside its view.
    bool switchOn(String key) => tester
        .widget<SwitchListTile>(find.byKey(ValueKey(key), skipOffstage: false))
        .value;

    // ── The video: 2x, its sound following the speed, the pitch kept.
    final clip = find.byKey(ValueKey('timelineClip-$videoId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final chip = find.widgetWithIcon(ChoiceChip, Icons.timelapse);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settle();
    expect(find.text(l10n.timelinePreservePitch), findsOneWidget);
    expect(switchOn('videoPreservePitch'), isTrue);
    await tapSwitch('videoPreservePitch');
    expect(video().videoPreservePitch, isFalse);
    await _capture(tester, '1_video_pitch_off');
    // One Undo.
    await tester.tap(find.byIcon(Icons.undo).first);
    await settle();
    expect(video().videoPreservePitch, isTrue);
    expect(switchOn('videoPreservePitch'), isTrue);
    // A sound at the normal speed has no pitch to change: no switch.
    await tapSwitch('videoSoundFollowsSpeed');
    expect(video().videoSoundFollowsSpeed, isFalse);
    expect(
      find.byKey(const ValueKey('videoPreservePitch'), skipOffstage: false),
      findsNothing,
    );
    await tester.tap(find.byIcon(Icons.check).first);
    await settle();

    // ── The audio clip at 1.5x.
    final audioClip = find.byKey(const ValueKey('timelineClip-a'));
    Future<void> openAudio() async {
      await tester.ensureVisible(audioClip);
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(audioClip) + const Offset(30, 20));
      await settle();
    }

    await openAudio();
    expect(switchOn('audioPreservePitch'), isTrue);
    await tapSwitch('audioPreservePitch');
    expect(switchOn('audioPreservePitch'), isFalse);
    await _capture(tester, '2_audio_pitch_off');
    // Cancel puts it back.
    await tester.tap(find.byTooltip(l10n.commonCancel));
    await settle();
    expect(audio().preservePitch, isTrue);
    // OK keeps it.
    await openAudio();
    await tapSwitch('audioPreservePitch');
    await tester.tap(find.byTooltip(l10n.commonOk));
    await settle();
    expect(audio().preservePitch, isFalse);
    expect(audio().playbackRate, 1.5);
  });
}
