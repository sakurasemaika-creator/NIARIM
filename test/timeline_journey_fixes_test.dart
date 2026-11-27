// タイムラインの作品づくりで見つかった4つ（2026-11-27）。
//
// * シーンを足すボタンの「＋」が見えなかった（見出しの書体の全角の＋が空の字）。
// * 「選択→シーン」でシーンを押すと、選ばれずに選択が終わった。
// * 動画の「使用開始F・使用終了F」を数字で打つと、表示と1ずれた（表示はF1から、
//   打つ数は0から）。
// * 音声の音量を数字で打つと0〜1で、表示は%（50と打つと断られた）。
import 'dart:io';

import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/editable_slider_value.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

void main() {
  Future<
    ({
      ProjectService ps,
      String projectId,
      String sceneId,
      String videoId,
      AppLocalizations l10n,
    })
  >
  openTimeline(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-fixes-');
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
        name: 'fixes',
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
          rangeEnd: 13,
          sourceTrimStart: 0,
          sourceTrimEnd: 12,
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
          volume: 1,
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
    return (
      ps: ps,
      projectId: projectId,
      sceneId: sceneId,
      videoId: videoId,
      l10n: l10n,
    );
  }

  testWidgets('timeline: add scene, choose scenes, typed frame and volume', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId, :videoId, :l10n) = await openTimeline(
      tester,
    );
    Layer video() => ps
        .storedLayersOf(projectId, sceneId, 0)
        .firstWhere((l) => l.id == videoId);
    AudioClip audio() =>
        ps.audioClipsOf(projectId, sceneId).firstWhere((c) => c.id == 'a');
    Future<void> settle() =>
        pumpRealAsync(tester, const Duration(milliseconds: 300));

    Future<void> typeInto(String shown, String typed) async {
      final value = find.widgetWithText(EditableSliderValue, shown);
      await tester.ensureVisible(value.last);
      await tester.pump();
      await tester.tap(value.last);
      await settle();
      await tester.enterText(find.byType(TextField).last, typed);
      await tester.tap(find.widgetWithText(FilledButton, l10n.commonOk).last);
      await settle();
    }

    // ── The video's last used frame, typed as the frame shown.
    final clip = find.byKey(ValueKey('timelineClip-$videoId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final videoChip = find.widgetWithIcon(ChoiceChip, Icons.videocam);
    await tester.ensureVisible(videoChip);
    await tester.tap(videoChip);
    await settle();
    expect(find.widgetWithText(EditableSliderValue, 'F13'), findsOneWidget);
    await typeInto('F13', '10');
    expect(video().sourceTrimEnd, 9, reason: 'F10 is the 10th frame');
    expect(find.widgetWithText(EditableSliderValue, 'F10'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check).first);
    await settle();

    // ── The audio clip's volume, typed in percent.
    final audioClip = find.byKey(const ValueKey('timelineClip-a'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('timelineClip-a'), skipOffstage: false),
    );
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(audioClip) + const Offset(20, 20));
    await settle();
    await tester.scrollUntilVisible(
      find.text(l10n.timelineClipVolumeLabel),
      80,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await settle();
    await typeInto('100%', '50');
    expect(find.widgetWithText(EditableSliderValue, '50%'), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.commonOk));
    await settle();
    expect(audio().volume, closeTo(0.5, 1e-9));

    // ── A scene is added with a visible button.
    final addScene = find.byKey(const ValueKey('timelineAddScene'));
    await tester.ensureVisible(addScene);
    await tester.pump();
    expect(
      find.descendant(of: addScene, matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(find.byTooltip(l10n.timelineAddSceneTooltip), findsOneWidget);
    await tester.tap(addScene);
    await settle();
    expect(ps.scenesOf(projectId), hasLength(2));

    // ── Choosing scenes: a tap adds the scene, and the mode stays.
    await tester.tap(find.byKey(const Key('timelineSelectionMenu')));
    await settle();
    await tester.tap(find.text(l10n.timelineSelectionScenes).last);
    await settle();
    final first = ps.scenesOf(projectId).first;
    final chip = find.widgetWithText(ChoiceChip, first.displayName);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settle();
    expect(
      find.descendant(of: chip, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    // A second tap takes it out again, still choosing.
    await tester.tap(chip);
    await settle();
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a clip edge dragged two frames and held stays two frames', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId, videoId: _, l10n: _) = await openTimeline(
      tester,
    );
    AudioClip audio() =>
        ps.audioClipsOf(projectId, sceneId).firstWhere((c) => c.id == 'a');
    final clip = find.byKey(const ValueKey('timelineClip-a'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('timelineClip-a'), skipOffstage: false),
    );
    await tester.pump();
    final rect = tester.getRect(clip);
    final cell = rect.width / audio().lengthFrames;
    // The left edge (the right one is past the screen) moved two frames
    // right, staying well inside the timeline.
    final edge = await tester.startGesture(
      rect.centerLeft + const Offset(3, 0),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await edge.moveBy(Offset(cell, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await edge.moveBy(Offset(cell, 0));
    // Held still for 1.5 s.
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await edge.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(audio().startFrame, 3, reason: 'started at F1, edge moved by 2');
    expect(audio().lengthFrames, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a clip lists only the keyframes inside it', (tester) async {
    // A right half after a split: its keys at F1 and F12 still shape the
    // motion, but F1 is before the clip (pasted, it read "F-4").
    final (:ps, :projectId, :sceneId, :videoId, :l10n) = await openTimeline(
      tester,
    );
    final layer = ps
        .storedLayersOf(projectId, sceneId, 0)
        .firstWhere((l) => l.id == videoId);
    ps.updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      layer: layer.copyWith(
        rangeStart: 6,
        rangeEnd: 12,
        keyframes: const [
          LayerKeyframe(frameIndex: 0),
          LayerKeyframe(frameIndex: 11, x: 40),
        ],
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final clip = find.byKey(ValueKey('timelineClip-$videoId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(20, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final transform = find.widgetWithIcon(ChoiceChip, Icons.open_with);
    if (transform.evaluate().isNotEmpty) {
      await tester.ensureVisible(transform);
      await tester.tap(transform);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
    }
    expect(find.widgetWithText(ActionChip, 'F12'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'F1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
