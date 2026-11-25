import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/engine/clip_speed.dart';
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

/// Writes the screen to build/timeline-pitch/[name].png for a look.
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
  final directory = Directory('build/timeline-pitch')
    ..createSync(recursive: true);
  File('${directory.path}/$name.png').writeAsBytesSync(bytes!);
}

/// 音の高さ in the real screen: the pitch of a sped-up video's sound (in the
/// video section: 速度に合わせる, the + button, 元の高さ, a typed value, one
/// Undo each; a value out of the range refused) and of
/// an audio clip (in its sheet: kept with OK, put back with Cancel). The
/// speed keeps the pitch; the pitch is changed only here.
void main() {
  testWidgets('the pitch of a video\'s sound and of an audio clip', (
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

    Future<void> tapIn(String key, Finder target) async {
      await tester.ensureVisible(
        find.byKey(ValueKey(key), skipOffstage: false),
      );
      await tester.pump();
      await tester.tap(target);
      await settle();
    }

    Future<void> tapKey(String key) => tapIn(key, find.byKey(ValueKey(key)));

    Future<void> plusOne() => tapIn(
      'pitchSlider',
      find.descendant(
        of: find.byKey(const ValueKey('pitchSlider')),
        matching: find.byIcon(Icons.add_circle_outline),
      ),
    );

    bool enabled(String key) =>
        tester
            .widget<ButtonStyleButton>(
              find.byKey(ValueKey(key), skipOffstage: false),
            )
            .onPressed !=
        null;

    Future<void> undo() async {
      await tester.tap(find.byIcon(Icons.undo).first);
      await settle();
    }

    // ── The video: 2x, its sound following the speed, its own pitch.
    final clip = find.byKey(ValueKey('timelineClip-$videoId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final chip = find.widgetWithIcon(ChoiceChip, Icons.videocam);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settle();
    expect(find.text(l10n.timelinePitchLabel), findsOneWidget);
    expect(enabled('pitchReset'), isFalse);
    // Matching its 2x speed: an octave up, like a tape.
    await tapKey('pitchMatchSpeed');
    expect(video().videoPitchSemitones, closeTo(12, 1e-9));
    expect(video().playbackRate, 2);
    expect(enabled('pitchMatchSpeed'), isFalse);
    await _capture(tester, '1_video_pitch_matched');
    await undo();
    expect(video().videoPitchSemitones, 0);
    // A semitone up with +, then back with 元の高さ: one Undo each.
    await plusOne();
    expect(video().videoPitchSemitones, 1);
    await tapKey('pitchReset');
    expect(video().videoPitchSemitones, 0);
    await undo();
    expect(video().videoPitchSemitones, 1);
    await undo();
    expect(video().videoPitchSemitones, 0);
    // Any value typed: -3.5 (one Undo); out of the range, refused.
    Future<void> type(String value) async {
      final field = find.byKey(const ValueKey('pitchField'));
      await tester.ensureVisible(field);
      await tester.pump();
      await tester.enterText(field, value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
    }

    await type('-3.5');
    expect(video().videoPitchSemitones, -3.5);
    expect(find.text('−3.5'), findsOneWidget);
    await _capture(tester, '3_video_pitch_typed');
    await type('30');
    expect(find.text(l10n.timelinePitchInvalid), findsOneWidget);
    expect(video().videoPitchSemitones, -3.5);
    await undo();
    expect(video().videoPitchSemitones, 0);
    // The field shows the value after Undo.
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('pitchField'), skipOffstage: false),
    );
    expect(field.controller!.text, '0');
    // Its sound at the normal speed: nothing to match.
    final durationChip = find.widgetWithIcon(ChoiceChip, Icons.timelapse);
    await tester.ensureVisible(durationChip);
    await tester.tap(durationChip);
    await settle();
    await tapKey('videoSoundFollowsSpeed');
    expect(video().videoSoundFollowsSpeed, isFalse);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settle();
    expect(enabled('pitchMatchSpeed'), isFalse);
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
    await tapKey('pitchMatchSpeed');
    await _capture(tester, '2_audio_pitch_matched');
    // Cancel puts it back.
    await tester.tap(find.byTooltip(l10n.commonCancel));
    await settle();
    expect(audio().pitchSemitones, 0);
    // OK keeps it: about a fifth up for 1.5x, and the speed stays.
    await openAudio();
    await tapKey('pitchMatchSpeed');
    await plusOne();
    await tester.tap(find.byTooltip(l10n.commonOk));
    await settle();
    expect(audio().pitchSemitones, closeTo(pitchMatchingSpeed(1.5) + 1, 1e-9));
    expect(audio().playbackRate, 1.5);
  });
}
