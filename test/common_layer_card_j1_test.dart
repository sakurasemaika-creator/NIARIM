// 共通レイヤーの置き場所と、このフレームだけの削除・複製（所有者の判断、
// 2026-11-27、全部入りの作品づくりの判断カードJ1）：
//
// 「どのフレームでも追加時は全ておなじレイヤー位置(上から数えた位置)に揃えて
// ください。ただし、各フレームごとにあとから個別でレイヤー順を入れ替えられる
// ようにしてください。また、削除や複製をする時はこのフレームだけを対象にするか
// 同一の共通フレーム全てを対象にするかチェックボックス用意しておいて下さい」
//
// 以前は、共通レイヤーは置いたフレーム以外ではいつもそのフレームのレイヤーの
// 一番下に入り、ほかのフレームでは並べ替えられず、途中のフレームだけから
// 消すことはできなかった（前か後を残す選択になった）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('service', () {
    useTemporaryProjectStorage();

    late ProjectService ps;
    late UndoManager undo;
    late String id;
    late String scene;

    List<String> names(int frame) => [
      for (final l in ps.layersOf(id, scene, frame)) l.name,
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ps = ProjectService();
      await ps.init();
      undo = UndoManager();
      ps.setUndoManager(undo);
      final project = await ps.createProject(
        name: 'j1',
        fps: 4,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 32,
        exportHeight: 32,
      );
      id = project.id;
      scene = ps.scenesOf(id).first.id;
      // Every frame: "Line" over "Colour" (and the starter layer below).
      for (var f = 0; f < 4; f++) {
        for (final name in ['Colour', 'Line']) {
          ps.addLayer(
            projectId: id,
            sceneId: scene,
            frameIndex: f,
            type: LayerType.normal,
            name: name,
          );
        }
      }
    });

    Layer addCommon(String name, int index) => ps.addLayer(
      projectId: id,
      sceneId: scene,
      frameIndex: 0,
      type: LayerType.common,
      name: name,
      insertIndex: index,
    );

    test('a common layer is at the same place from the top in every frame', () {
      addCommon('Sky', 1);
      for (var f = 0; f < 4; f++) {
        expect(names(f).indexOf('Sky'), 1, reason: 'frame $f');
        expect(names(f).first, 'Line');
      }
    });

    test('a frame moves it, the others keep their place; one undo', () {
      final sky = addCommon('Sky', 0);
      ps.setCommonLayerSlot(
        projectId: id,
        sceneId: scene,
        frameIndex: 2,
        layerId: sky.id,
        slot: 2,
      );
      expect(names(2).indexOf('Sky'), 2);
      expect(names(1).indexOf('Sky'), 0);
      expect(names(3).indexOf('Sky'), 0);
      undo.undo(projectId: id);
      expect(names(2).indexOf('Sky'), 0);
    });

    test('taken out of one frame in the middle, the others keep it', () {
      final sky = addCommon('Sky', 0);
      ps.hideCommonLayerInFrame(
        projectId: id,
        sceneId: scene,
        frameIndex: 2,
        layerId: sky.id,
      );
      expect(names(2), isNot(contains('Sky')));
      for (final f in [0, 1, 3]) {
        expect(names(f), contains('Sky'), reason: 'frame $f');
      }
      undo.undo(projectId: id);
      expect(names(2), contains('Sky'));
    });

    test('duplicated into one frame: a normal layer with the picture', () {
      final sky = addCommon('Sky', 0);
      final pixels = Uint8List(32 * 32 * 4)..fillRange(0, 32 * 32 * 4, 200);
      ps
          .tileManagerOf(id)
          .replaceLayerPixels(ps.tileKeyFor(id, scene, 0, sky.id), pixels);
      final copy = ps.duplicateCommonIntoFrame(
        projectId: id,
        sceneId: scene,
        frameIndex: 2,
        layerId: sky.id,
        name: 'Sky copy',
      )!;
      expect(copy.type, LayerType.normal);
      expect(names(2), containsAllInOrder(['Sky copy', 'Sky']));
      expect(names(1), isNot(contains('Sky copy')));
      final colour = ps
          .tileManagerOf(id)
          .getPixelColorAt(ps.tileKeyFor(id, scene, 2, copy.id), 4, 4);
      expect(colour!.a, closeTo(200 / 255, 0.01));
    });

    test('the places are saved, and a duplicated frame keeps them', () async {
      final sky = addCommon('Sky', 1);
      ps.setCommonLayerSlot(
        projectId: id,
        sceneId: scene,
        frameIndex: 2,
        layerId: sky.id,
        slot: 0,
      );
      ps.hideCommonLayerInFrame(
        projectId: id,
        sceneId: scene,
        frameIndex: 3,
        layerId: sky.id,
      );
      ps.duplicateFrame(id, scene, 2);
      expect(names(3).indexOf('Sky'), 0, reason: 'the copy of frame 3');
      expect(names(4), isNot(contains('Sky')), reason: 'frame 4 hid it');

      final dir = await Directory.systemTemp.createTemp('j1-save-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/j1.niapro';
      await NiaproSerializer.saveToPath(
        filePath: path,
        project: ps.projects.firstWhere((p) => p.id == id),
        scenes: ps.scenesOf(id),
        tileManager: ps.tileManagerOf(id),
      );
      final data = await NiaproSerializer.load(path);
      final frames = data.scenes.first.frames;
      expect(frames[0].layers.singleWhere((l) => l.id == sky.id).commonSlot, 1);
      expect(frames[2].commonSlots, {sky.id: 0});
      expect(frames[4].hiddenCommon, {sky.id});
    });

    test('a common layer from before keeps going below', () {
      final old = addCommon('Old', 0);
      ps.updateLayer(
        projectId: id,
        sceneId: scene,
        frameIndex: 0,
        layer: old.copyWith(commonSlot: null),
        recordUndo: false,
      );
      expect(names(2).last, 'Old');
    });
  });

  group('layer panel', () {
    late Directory directory;

    testWidgets('a frame reorders and deletes its common layer alone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': 1,
        'default_docked_panels': ['layer'],
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      });
      directory = Directory.systemTemp.createTempSync('common-j1-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      appRouter.go('/home');
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      final ps = tester
          .element(find.byType(MaterialApp).first)
          .read<ProjectService>();
      final project = (await tester.runAsync(
        () => ps.createProject(
          name: 'j1 panel',
          fps: 4,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64,
          exportHeight: 48,
        ),
      ))!;
      final scene = ps.scenesOf(project.id).first.id;
      for (var f = 0; f < 4; f++) {
        ps.addLayer(
          projectId: project.id,
          sceneId: scene,
          frameIndex: f,
          type: LayerType.normal,
          name: 'Line $f',
        );
      }
      final sky = ps.addLayer(
        projectId: project.id,
        sceneId: scene,
        frameIndex: 0,
        type: LayerType.common,
        name: 'Sky',
      );
      await tester.runAsync(() => ps.saveProject(project.id));
      appRouter.push('/canvas/${project.id}');
      await pumpRealAsync(tester, const Duration(milliseconds: 500));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CanvasScreen)),
      )!;
      // Frame 3, where "Sky" is not kept.
      await tester.tap(find.byKey(const ValueKey('frameStripCell2')));
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      List<String> names(int frame) => [
        for (final l in ps.layersOf(project.id, scene, frame)) l.name,
      ];
      expect(names(2).first, 'Sky');

      // Dragged below "Line 2" in this frame only.
      tester
          .widget<ReorderableListView>(
            find.descendant(
              of: find.byType(LayerPanel),
              matching: find.byType(ReorderableListView),
            ),
          )
          .onReorderItem!(0, 1);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      expect(names(2).indexOf('Sky'), 1);
      expect(names(1).first, 'Sky', reason: 'the other frames keep it');

      // Deleted from this frame only, with the box ticked.
      final menu = find.byKey(ValueKey('canvasLayerMenu_${sky.id}'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text(l10n.commonDelete).last);
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      final box = find.byKey(const ValueKey('commonDeleteThisFrameOnly'));
      expect(tester.widget<CheckboxListTile>(box).value, isFalse);
      await tester.tap(box);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('commonDeleteConfirm')));
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      expect(names(2), isNot(contains('Sky')));
      for (final f in [0, 1, 3]) {
        expect(names(f), contains('Sky'), reason: 'frame $f');
      }
      expect(tester.takeException(), isNull);
    });
  });
}
