// タイムラインに足した4つ（所有者の判断、2026-11-27、全部入りの作品づくりの
// 判断カードJ17）。
//
// * シーンの︙に「長さ変更」（長さ・秒・fpsを添える）。以前はタイムラインの
//   三点メニューから、選んでいるシーンの長さしか変えられなかった。
// * 素材・カメラのキーフレームのつなぎ方（レイヤーのキーフレームと同じ5種）。
//   素材はデータにはあったが選ぶ所が無く、カメラはデータにも無かった。
// * シーンをまたいで素材を貼り付け（以前は同じシーンの中だけ）。
// * タイムスタンプを別のコマへ動かす（以前は消して作り直すしかなかった）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/camera_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/models/timeline_row_kind.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

void main() {
  test(
    'a camera keyframe eases on to the next, and keeps it in the file',
    () async {
      const keys = [
        CameraKeyframe(frameIndex: 0, easing: LayerKeyframeEasing.easeIn),
        CameraKeyframe(frameIndex: 10, x: 100),
      ];
      // Ease in: a quarter of the way at half the time.
      expect(CameraEngine().valueAt(keys, 5).x, closeTo(25, 1e-9));
      expect(
        CameraEngine().valueAt([
          keys.first.copyWith(easing: LayerKeyframeEasing.linear),
          keys.last,
        ], 5).x,
        closeTo(50, 1e-9),
      );

      final dir = await Directory.systemTemp.createTemp('niarim-camera-ease-');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 1, 1);
      final path = '${dir.path}/ease.niapro';
      await NiaproSerializer.saveToPath(
        filePath: path,
        project: Project(
          id: 'ease',
          name: 'Ease',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          createdAt: now,
          updatedAt: now,
          totalWorkSeconds: 0,
        ),
        scenes: [
          const Scene(
            id: 'Scene0001',
            index: 0,
            frames: [Frame(index: 0, layers: [])],
            cameraKeyframes: keys,
          ),
        ],
        tileManager: TileManager(canvasWidth: 4, canvasHeight: 4),
      );
      final loaded = (await NiaproSerializer.load(
        path,
      )).scenes.single.cameraKeyframes;
      expect(loaded.map((k) => k.easing), [
        LayerKeyframeEasing.easeIn,
        LayerKeyframeEasing.linear,
      ]);
    },
  );

  testWidgets('scene length, easing, pasting into another scene and moving '
      'a timestamp', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('timeline-j17-');
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

    late String first;
    late String second;
    late String imageId;
    final created = await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'j17',
        fps: 10,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      first = ps.scenesOf(project.id).first.id;
      second = ps.addScene(project.id).id;
      // A picture on the first scene's second image row, moving F1 → F5.
      ps.addTrackRow(project.id, first, TimelineRowKind.image);
      final layer = ps.addLayer(
        projectId: project.id,
        sceneId: first,
        frameIndex: 0,
        type: LayerType.timelineImage,
        name: 'picture',
      );
      imageId = layer.id;
      ps.updateLayer(
        projectId: project.id,
        sceneId: first,
        frameIndex: 0,
        layer: layer.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 6,
          trackRow: 1,
          keyframes: const [
            LayerKeyframe(frameIndex: 0),
            LayerKeyframe(frameIndex: 4, x: 20),
          ],
        ),
      );
      ps.addCameraKeyframe(
        project.id,
        first,
        const CameraKeyframe(frameIndex: 0),
      );
      ps.addCameraKeyframe(
        project.id,
        first,
        const CameraKeyframe(frameIndex: 8, x: 40),
      );
      ps.addTimelineMarker(project.id, first, 1, 'hello');
      return project.id;
    });
    final projectId = created!;
    Future<void> settle() =>
        pumpRealAsync(tester, const Duration(milliseconds: 300));
    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimelineScreen)),
    )!;
    final firstFrames = ps.frameCount(projectId, first);

    // ── The second scene's ︙: its length, with the frame rate ──
    final menu = find.byKey(ValueKey('timelineSceneMenu_$second'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await settle();
    final lengthItem = find.byKey(ValueKey('sceneMenuDuration-$second'));
    expect(
      find.descendant(
        of: lengthItem,
        matching: find.textContaining(l10n.pcStatusFps(10)),
      ),
      findsOneWidget,
    );
    await tester.tap(lengthItem);
    await settle();
    expect(find.byKey(const ValueKey('durationDialogFps')), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.timelineDurationFramesLabel),
      '7',
    );
    await tester.tap(find.text(l10n.commonOk));
    await settle();
    expect(ps.frameCount(projectId, second), 7);
    expect(ps.frameCount(projectId, first), firstFrames, reason: 'not shown');

    // ── The camera keyframe sheet: the way on to the next key ──
    final cameraKey = find.byKey(const ValueKey('cameraKfMarker_0'));
    await tester.ensureVisible(cameraKey);
    await tester.tap(cameraKey);
    await settle();
    final cameraEasing = find.descendant(
      of: find.byKey(const ValueKey('cameraKfEasing')),
      matching: find.byKey(const ValueKey('keyframeEasing-easeOut')),
    );
    // Below the sliders: scroll the list up, as a person would.
    for (var i = 0; i < 2; i++) {
      await tester.dragFrom(
        tester.getTopLeft(find.text(l10n.timelineCameraZoomLabel).last) -
            const Offset(12, 0),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(cameraEasing);
    await tester.pump();
    await tester.tap(find.text(l10n.commonApply));
    await settle();
    expect(
      ps.cameraKeyframesOf(projectId, first).first.easing,
      LayerKeyframeEasing.easeOut,
    );

    // ── The picture's keyframe at F1: the same choices ──
    final clip = find.byKey(ValueKey('timelineClip-$imageId'));
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
    await settle();
    final transformChip = find.widgetWithIcon(ChoiceChip, Icons.open_with);
    if (transformChip.evaluate().isNotEmpty) {
      await tester.ensureVisible(transformChip);
      await tester.tap(transformChip);
      await tester.pump();
    }
    final materialEasing = find.descendant(
      of: find.byKey(const ValueKey('materialKfEasing')),
      matching: find.byKey(const ValueKey('keyframeEasing-bounceOut')),
    );
    await tester.ensureVisible(materialEasing);
    await tester.tap(materialEasing);
    await settle();
    Layer picture() => ps
        .storedLayersOf(projectId, first, 0)
        .singleWhere((l) => l.id == imageId);
    expect(picture().keyframes.first.easing, LayerKeyframeEasing.bounceOut);
    expect(picture().keyframes.last.easing, LayerKeyframeEasing.linear);
    await tester.tap(find.byTooltip(l10n.commonClose).last);
    await settle();

    // ── Copy the picture and paste it into the second scene ──
    await tester.tap(find.byKey(const Key('timelineSelectionMenu')));
    await settle();
    await tester.tap(find.text(l10n.timelineSelectionClips).last);
    await settle();
    await tester.ensureVisible(clip);
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(clip) + const Offset(30, 20));
    await settle();
    await tester.tap(find.byTooltip(l10n.commonCopy).last);
    await settle();
    final secondChip = find.widgetWithText(
      ChoiceChip,
      ps.scenesOf(projectId).singleWhere((s) => s.id == second).displayName,
    );
    await tester.ensureVisible(secondChip);
    await tester.tap(secondChip);
    await settle();
    await tester.tap(find.byKey(const Key('timelinePasteButton')).first);
    await settle();
    final pasted = [
      for (final l in ps.storedLayersOf(projectId, second, 0))
        if (l.type == LayerType.timelineImage) l,
    ];
    expect(pasted, hasLength(1));
    expect(pasted.single.trackRow, 1);
    expect(
      ps.rowNamesOf(projectId, second, TimelineRowKind.image).length,
      greaterThanOrEqualTo(2),
      reason: 'the row it goes on is shown',
    );
    expect(
      pasted.single.keyframes.map((k) => k.easing).first,
      LayerKeyframeEasing.bounceOut,
    );
    expect(
      find.byKey(ValueKey('timelineClip-${pasted.single.id}')),
      findsOneWidget,
    );
    // The first scene keeps its picture.
    expect(picture().rangeStart, 1);

    // ── Back in the first scene, the timestamp moves from F2 to F6 ──
    final firstChip = find.widgetWithText(
      ChoiceChip,
      ps.scenesOf(projectId).singleWhere((s) => s.id == first).displayName,
    );
    await tester.ensureVisible(firstChip);
    await tester.tap(firstChip);
    await settle();
    final pin = find.byKey(const ValueKey('timelineTimestamp-1'));
    await tester.ensureVisible(pin);
    await tester.longPress(pin);
    await settle();
    final slider = find.descendant(
      of: find.byKey(const ValueKey('timelineTimestampFrame')),
      matching: find.byType(Slider),
    );
    tester.widget<Slider>(slider).onChanged!(6);
    await tester.pump();
    expect(find.text(l10n.timelineMarkerEditDialogTitle(6)), findsOneWidget);
    await tester.tap(find.text(l10n.commonSave));
    await settle();
    final marker = ps.timelineMarkersOf(projectId, first).single;
    expect(marker.frameIndex, 5);
    expect(marker.comment, 'hello');
    expect(tester.takeException(), isNull);
  });
}
