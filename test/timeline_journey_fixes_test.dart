// タイムラインの作品づくりで見つかった4つ（2026-11-27）。
//
// * シーンを足すボタンの「＋」が見えなかった（見出しの書体の全角の＋が空の字）。
// * 「選択→シーン」でシーンを押すと、選ばれずに選択が終わった。
// * 動画の「使用開始F・使用終了F」を数字で打つと、表示と1ずれた（表示はF1から、
//   打つ数は0から）。
// * 音声の音量を数字で打つと0〜1で、表示は%（50と打つと断られた）。
// * スマホでプレビューを縮めると、トラックの一覧は広がらず下に空白が残った。
// * 全画面表示のボタンの最初の説明に、キャンバスのツールバーの「基本の操作」が
//   付いていた。
// * 分割のボタンの吹き出しと分割モードの文が、日本語と英語の手書きだった。
// * 選んでいる素材の枠とつまみが、全画面表示にも出て、プレビューの外（上部
//   バー・シークバー）にもはみ出していた。
// * PCの「詳細」は題が作品名なのに、総フレーム数・秒数は選んでいるシーンの数
//   だった。
// * 「長さ変更」のスライダーが1〜43万コマで、少し動かすと数千コマ跳んだ。
// * 素材の編集の「配置・長さ調整…」のチップの上下が切れていた（デスクトップの
//   既定で押せる所が縮み、外側に描く縁取り線を横スクロールの欄が切った）。
import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'package:niarim/screens/timeline/widgets/material_gizmo.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/editable_slider_value.dart';
import 'package:niarim/widgets/stepped_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/cut_controls.dart';
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
  openTimeline(
    WidgetTester tester, {
    double previewFraction = 0.42,
    String language = 'ja',
    List<String> unseenTips = const [],
    bool pc = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'timeline_preview_height_fraction': previewFraction,
      'first_launch': false,
      'language': language,
      'force_pc_mode': pc ? 1 : 0,
      firstUseTooltipsSeenKey: [
        for (final key in kAllFirstUseTooltipKeys)
          if (!unseenTips.contains(key)) key,
      ],
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
    tester.view.physicalSize = pc
        ? const Size(1280, 800)
        : const Size(390, 844);
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

  testWidgets('a duplicate never lies over the next clip', (tester) async {
    final (:ps, :projectId, :sceneId, videoId: _, l10n: _) = await openTimeline(
      tester,
    );
    // The next place on clip A's row is taken by clip B.
    ps.addAudioClip(
      projectId,
      sceneId,
      const AudioClip(id: 'b', label: 'B', startFrame: 7, lengthFrames: 6),
    );
    appRouter.go('/home');
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(
      find.byKey(const ValueKey('timelineClip-b'), skipOffstage: false),
      findsOneWidget,
    );
    final clip = find.byKey(const ValueKey('timelineClip-a'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('timelineClip-a'), skipOffstage: false),
    );
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(20, 20));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('複製').last);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final clips = ps.audioClipsOf(projectId, sceneId);
    expect(clips, hasLength(3));
    final copy = clips.singleWhere((c) => c.id != 'a' && c.id != 'b');
    expect(copy.startFrame, 7);
    final b = clips.singleWhere((c) => c.id == 'b');
    expect(copy.trackRow, isNot(b.trackRow), reason: 'not over clip B');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a smaller preview gives its height to the tracks', (
    tester,
  ) async {
    Rect tracksAt() => tester.getRect(
      find
          .descendant(
            of: find.byType(TimelineScreen),
            matching: find.byType(SingleChildScrollView),
          )
          .last,
    );
    double gripTop() => tester
        .getRect(find.byKey(const Key('timelinePreviewResizeHandle')))
        .top;
    await openTimeline(tester, previewFraction: 0.42);
    final tall = tracksAt();
    final tallGrip = gripTop();
    final screenBottom = tester.getRect(find.byType(TimelineScreen)).bottom;
    expect(tall.bottom, closeTo(screenBottom, 1));

    await tester.pumpWidget(const SizedBox());
    await openTimeline(tester, previewFraction: 0.18);
    final small = tracksAt();
    expect(
      small.bottom,
      closeTo(screenBottom, 1),
      reason: 'no blank band under the tracks',
    );
    final shrunk = tallGrip - gripTop();
    expect(shrunk, greaterThan(100));
    expect(small.height - tall.height, closeTo(shrunk, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the fullscreen button explains only the preview', (
    tester,
  ) async {
    final (
      ps: _,
      projectId: _,
      sceneId: _,
      videoId: _,
      :l10n,
    ) = await openTimeline(
      tester,
      unseenTips: const ['timeline_preview_fullscreen'],
    );
    await tester.tap(find.byKey(const Key('timelinePreviewFullscreenButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.timelinePreviewFullscreenTip), findsOneWidget);
    expect(find.text(l10n.firstUseTipOperationGuideTitle), findsNothing);
    expect(find.text(l10n.firstUseTipOperationGuideBody), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('split is named in the chosen language', (tester) async {
    final (ps: _, projectId: _, sceneId: _, videoId: _, :l10n) =
        await openTimeline(tester, language: 'fr');
    expect(l10n.timelineSplitTooltip, 'Scinder');
    final split = find.byKey(const Key('timelineSplitModeButton'));
    expect(tester.widget<IconButton>(split).tooltip, 'Scinder');
    await tester.tap(split);
    await tester.pump();
    expect(find.text(l10n.timelineSplitModeHint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the material frame stays in the preview, not in fullscreen', (
    tester,
  ) async {
    final (ps: _, projectId: _, sceneId: _, :videoId, l10n: _) =
        await openTimeline(tester);
    final clip = find.byKey(ValueKey('timelineClip-$videoId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(20, 10));
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    final gizmo = find.byType(MaterialTransformGizmo);
    expect(gizmo, findsOneWidget);
    // Drawn handles are cut at the edge of the preview band.
    final band = find.byKey(const Key('timelinePreviewArea'));
    final clip0 = find.ancestor(of: band, matching: find.byType(ClipRect));
    expect(clip0, findsWidgets);
    expect(
      tester.getRect(clip0.first),
      tester.getRect(band),
      reason: 'the clip is the preview band itself',
    );

    await tester.tap(find.byKey(const Key('timelinePreviewFullscreenButton')));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(gizmo, findsNothing);
    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(gizmo, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the PC details give the work\'s totals and the scene\'s own', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId, videoId: _, :l10n) = await openTimeline(
      tester,
      pc: true,
    );
    // A second scene: the work has more frames than the chosen scene.
    await tester.runAsync(() async {
      ps.addScene(projectId);
    });
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final details = find.byKey(const ValueKey('pcInspectorProject'));
    expect(details, findsOneWidget);
    String valueOf(String label, {int at = 0}) {
      final row = find
          .ancestor(
            of: find.descendant(of: details, matching: find.text(label)).at(at),
            matching: find.byType(Row),
          )
          .first;
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: row, matching: find.byType(Text)),
          )
          .map((t) => t.data)
          .toList();
      return texts.last!;
    }

    final sceneFrames = ps.frameCount(projectId, sceneId);
    final allFrames = ps
        .scenesOf(projectId)
        .fold<int>(0, (n, s) => n + ps.frameCount(projectId, s.id));
    expect(allFrames, greaterThan(sceneFrames));
    expect(valueOf(l10n.projectDetailInfoTotalFrames), '$allFrames');
    expect(
      find.descendant(
        of: details,
        matching: find.byKey(const ValueKey('pcInspectorSceneName')),
      ),
      findsOneWidget,
    );
    expect(valueOf(l10n.timelineDurationFramesLabel), '$sceneFrames');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the length slider covers lengths near the scene\'s', (
    tester,
  ) async {
    final (:ps, :projectId, :sceneId, videoId: _, :l10n) = await openTimeline(
      tester,
    );
    final more = find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuButton<String> &&
          widget.icon is Icon &&
          (widget.icon! as Icon).icon == Icons.more_vert,
    );
    await tester.tap(more.first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text(l10n.timelineDurationChangeMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    final slider = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(SteppedSlider),
    );
    // 30 frames at 10 fps: up to a minute (600), not 432,000.
    expect(ps.frameCount(projectId, sceneId), 30);
    expect(tester.widget<SteppedSlider>(slider).max, 600);
    // Typing a longer length still works and widens the slider with it.
    await tester.enterText(
      find.widgetWithText(TextField, l10n.timelineDurationFramesLabel),
      '5000',
    );
    await tester.pump();
    expect(tester.widget<SteppedSlider>(slider).max, 5000);
    expect(tester.widget<SteppedSlider>(slider).value, 5000);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('the material panel\'s buttons are not cut ($platform)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final (ps: _, projectId: _, sceneId: _, :videoId, l10n: _) =
            await openTimeline(tester);
        expect(cutControls(tester), isEmpty, reason: 'the timeline');
        final clip = find.byKey(ValueKey('timelineClip-$videoId'));
        await tester.ensureVisible(clip);
        await tester.pump();
        await tester.tapAt(tester.getTopLeft(clip) + const Offset(20, 10));
        await pumpRealAsync(tester, const Duration(milliseconds: 400));
        expect(find.byType(ChoiceChip), findsWidgets);
        expect(cutControls(tester), isEmpty, reason: 'the material panel');
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
