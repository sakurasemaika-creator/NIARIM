import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/material_asset.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/save_tree/save_management_screen.dart';
import 'package:niarim/screens/save_tree/widgets/autosave_list.dart';
import 'package:niarim/screens/save_tree/widgets/save_restore_dialog.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/autosave_service.dart';
import 'package:niarim/services/material_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/widgets/project_not_found_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// キャンバス（A010）を開く・閉じるとき：存在しないIDでは空のキャンバスを
/// 出さず一覧へ戻せること、不足素材の通知が時間で消え次の画面へ付いて
/// こないこと、「保存して戻る」で保存せずに戻ったらキャンバス（タイムライン
/// も同じ）に残ること。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_canvas_open_exit_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ファイルの読み書きのような本物の非同期の処理を実時間で待つ。
  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String location() => appRouter.routerDelegate.currentConfiguration.uri.path;

  // 作品を変える（取り消しの履歴に1手積む）。開いて何も変えずに戻るときは、
  // 「保存して戻る」を聞かずに一覧へ戻る。
  Future<void> change(WidgetTester tester, ProjectService service, String id) =>
      tester
          .runAsync(() => service.setProjectTags(id, ['changed']))
          .then((_) {});

  Future<({ProjectService service, String id})> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    final service = tester
        .element(find.byType(HomeScreen))
        .read<ProjectService>();
    late String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'キャンバス',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
      id = project.id;
    });
    return (service: service, id: id);
  }

  testWidgets('leaving the shared layer range targets the visible layer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 1,
    });
    final (service: projects, :id) = await open(
      tester,
      size: const Size(1280, 800),
    );
    final sceneId = projects.scenesOf(id).single.id;
    final common = projects.addLayer(
      projectId: id,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.common,
      name: 'Shared stroke',
    );
    projects.updateLayer(
      projectId: id,
      sceneId: sceneId,
      frameIndex: 0,
      layer: common.copyWith(
        rangeMode: LayerRangeMode.frameRange,
        rangeStart: 1,
        rangeEnd: 1,
      ),
    );
    final nextLayer = projects.layersOf(id, sceneId, 1).single;
    appRouter.go('/canvas/$id');
    await settleIo(tester);
    final area = find.byType(CanvasArea);
    if (find.byType(LayerPanel).evaluate().isEmpty) {
      await tester.tap(find.byTooltip('レイヤー').first);
      await settleIo(tester, 2);
    }
    await tester.tap(find.text(common.name));
    await tester.pump();
    expect(tester.widget<CanvasArea>(area).currentLayerId, common.id);

    await tester.tap(find.byKey(const ValueKey('frameStripCell1')));
    await settleIo(tester, 2);
    expect(find.byType(LayerPanel), findsOneWidget);
    expect(find.text(common.name), findsNothing);
    expect(tester.widget<CanvasArea>(area).currentLayerId, nextLayer.id);

    final tiles = projects.tileManagerOf(id);
    final commonKey = projects.tileKeyFor(id, sceneId, 0, common.id);
    final nextKey = projects.tileKeyFor(id, sceneId, 1, nextLayer.id);
    final center = tester.getCenter(area);
    final stroke = await tester.startGesture(
      center - const Offset(30, 0),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    for (var x = -20.0; x <= 30; x += 10) {
      await stroke.moveTo(center + Offset(x, 0));
      await settleIo(tester, 1);
    }
    await stroke.up();
    await settleIo(tester, 2);
    expect(tiles.exportAll()[commonKey], isNull);
    expect(tiles.exportAll()[nextKey], isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DISC524: history jumps publish only the new frame layers', (
    tester,
  ) async {
    final (service: projects, :id) = await open(
      tester,
      size: const Size(1280, 800),
    );
    final sceneId = projects.scenesOf(id).single.id;
    final tiles = projects.tileManagerOf(id);
    final history = tester.element(find.byType(HomeScreen)).read<UndoManager>();
    final l10n = lookupAppLocalizations(const Locale('ja'));
    const colors = [
      [220, 30, 40, 255],
      [30, 60, 220, 255],
    ];
    for (var frame = 0; frame < colors.length; frame++) {
      final below = projects.addLayer(
        projectId: id,
        sceneId: sceneId,
        frameIndex: frame,
        type: LayerType.normal,
        name: 'Color $frame',
        insertIndex: 1,
      );
      final key = projects.tileKeyFor(id, sceneId, frame, below.id);
      tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, colors[frame]);
      tiles.markDirty(key, 0, 0);
    }
    history.push(
      ProjectEditUndoAction(
        'Edit across frames',
        () {},
        () {},
        undoFrame: (sceneId: sceneId, frameIndex: 1),
        redoFrame: (sceneId: sceneId, frameIndex: 0),
      ),
      projectId: id,
    );
    appRouter.go('/canvas/$id');
    await settleIo(tester);

    final area = find.byType(CanvasArea);
    Future<int?> displayedColor() async {
      final dynamic painter = tester
          .widgetList<CustomPaint>(
            find.descendant(of: area, matching: find.byType(CustomPaint)),
          )
          .map((widget) => widget.painter)
          .firstWhere(
            (painter) => painter.runtimeType.toString() == '_CanvasPainter',
          );
      final image = (painter.belowImage as ui.Image?)?.clone();
      if (image == null) return null;
      return tester.runAsync(() async {
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          return bytes.getUint32(0);
        } finally {
          image.dispose();
        }
      });
    }

    expect(await displayedColor(), 0xdc1e28ff);
    for (final (button, frame, color, previous) in [
      (l10n.commonUndo, 1, 0x1e3cdcff, 0xdc1e28ff),
      (l10n.commonRedo, 0, 0xdc1e28ff, 0x1e3cdcff),
    ]) {
      await tester.tap(find.byTooltip(button));
      await tester.pump();
      expect(tester.widget<CanvasArea>(area).currentFrame, frame);
      expect(await displayedColor(), isNot(previous));
      await settleIo(tester, 3);
      expect(await displayedColor(), color);
    }

    // Switch back while the intermediate frame is still compositing.
    await tester.tap(find.byTooltip(l10n.commonUndo));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.commonRedo));
    await tester.pump();
    await settleIo(tester, 3);
    expect(tester.widget<CanvasArea>(area).currentFrame, 0);
    expect(await displayedColor(), 0xdc1e28ff);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DISC574: opening uses the newer autosave without asking or '
      'telling, once per launch', (tester) async {
    final (service: projects, :id) = await open(tester);
    final home = tester.element(find.byType(HomeScreen));
    final autosaves = home.read<AutosaveService>();
    final scene = projects.scenesOf(id).single;
    final key = projects.tileKeyFor(
      id,
      scene.id,
      0,
      scene.frames.first.layers.first.id,
    );
    final tiles = projects.tileManagerOf(id);
    const drawn = [30, 60, 220, 255];
    await tester.runAsync(() async {
      tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, drawn);
      await autosaves.save(id, projects);
      // The work file was not written after the stroke (forced quit), and
      // the app is opened again.
      tiles.importAll(const {});
      autosaves.debugTreatSlotsAsFromEarlierLaunch();
    });
    appRouter.go('/canvas/$id');
    await settleIo(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tiles.getTile(key, 0, 0)?.take(4), drawn);
    // The newest content is what anyone expects: no notice about it (owner's
    // request, 2026-11-27).
    expect(find.byType(SnackBar), findsNothing);
    // Looked for once per launch: a later change is not taken back.
    tiles.importAll(const {});
    appRouter.go('/home');
    await settleIo(tester);
    appRouter.go('/canvas/$id');
    await settleIo(tester);
    expect(tiles.getTile(key, 0, 0), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a work changed while the newer autosave is being read is not '
      'replaced by it', (tester) async {
    final (service: projects, :id) = await open(tester);
    final home = tester.element(find.byType(HomeScreen));
    final autosaves = home.read<AutosaveService>();
    final scene = projects.scenesOf(id).single;
    final key = projects.tileKeyFor(
      id,
      scene.id,
      0,
      scene.frames.first.layers.first.id,
    );
    final tiles = projects.tileManagerOf(id);
    await tester.runAsync(() async {
      tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, [30, 60, 220, 255]);
      await autosaves.save(id, projects);
      // The work file was not written after the stroke: the autosave is from
      // the last launch and newer than the work file.
      tiles.importAll(const {});
      autosaves.debugTreatSlotsAsFromEarlierLaunch();
    });
    appRouter.go('/canvas/$id');
    await tester.pump();
    await tester.pump();
    // Drawn on before the autosave was read and compared.
    const drawn = [200, 10, 10, 255];
    tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, drawn);
    await settleIo(tester);
    expect(tiles.getTile(key, 0, 0)?.take(4), drawn);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an autosave older than the work file is not offered', (
    tester,
  ) async {
    final (service: projects, :id) = await open(tester);
    final home = tester.element(find.byType(HomeScreen));
    final autosaves = home.read<AutosaveService>();
    final scene = projects.scenesOf(id).single;
    final key = projects.tileKeyFor(
      id,
      scene.id,
      0,
      scene.frames.first.layers.first.id,
    );
    final tiles = projects.tileManagerOf(id);
    await tester.runAsync(() async {
      tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, [210, 60, 20, 255]);
      await autosaves.save(id, projects);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Later strokes reached the work file but not yet an autosave.
      tiles.getTile(key, 0, 0)!.setRange(0, 4, [30, 60, 220, 255]);
      await projects.saveProject(id);
      autosaves.debugTreatSlotsAsFromEarlierLaunch();
    });
    appRouter.go('/canvas/$id');
    await settleIo(tester);
    expect(tiles.getTile(key, 0, 0)?.take(4), [30, 60, 220, 255]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an autosave written during this launch is not offered', (
    tester,
  ) async {
    final (service: projects, :id) = await open(tester);
    final home = tester.element(find.byType(HomeScreen));
    final autosaves = home.read<AutosaveService>();
    final scene = projects.scenesOf(id).single;
    final key = projects.tileKeyFor(
      id,
      scene.id,
      0,
      scene.frames.first.layers.first.id,
    );
    final tiles = projects.tileManagerOf(id);
    await tester.runAsync(() async {
      tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, [30, 60, 220, 255]);
      await autosaves.save(id, projects);
      // Undone in this session (e.g. on the timeline) before the canvas opens.
      tiles.importAll(const {});
    });
    appRouter.go('/canvas/$id');
    await settleIo(tester);
    expect(tiles.getTile(key, 0, 0), isNull);
    expect(tester.takeException(), isNull);
  });

  for (final tree in [false, true]) {
    testWidgets('a newer autosave opens without asking; the list can still '
        'load the other versions (tree: $tree)', (tester) async {
      if (tree) {
        SharedPreferences.setMockInitialValues({
          firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
          'first_launch': false,
          'language': 'ja',
          'force_pc_mode': 1,
        });
      }
      final (service: projects, :id) = await open(
        tester,
        size: tree ? const Size(1280, 800) : const Size(390, 844),
      );
      final home = tester.element(find.byType(HomeScreen));
      final autosaves = home.read<AutosaveService>();
      final saves = home.read<SaveTreeService>()..setTreeMode(tree);
      final l10n = AppLocalizations.of(home)!;
      final scene = projects.scenesOf(id).single;
      final key = projects.tileKeyFor(
        id,
        scene.id,
        0,
        scene.frames.first.layers.first.id,
      );
      final tiles = projects.tileManagerOf(id);
      final work = projects.projects.single;
      const manual = [20, 140, 60, 255];
      const older = [210, 60, 20, 255];
      const latest = [30, 60, 220, 255];

      await tester.runAsync(() async {
        tiles.getOrCreateTile(key, 0, 0).setRange(0, 4, manual);
        if (tree) {
          await saves.saveAsChild(
            projectId: id,
            project: work,
            scenes: [scene],
            tileManager: tiles,
            comment: '手動テスト',
          );
        } else {
          await saves.saveToSlot(
            projectId: id,
            slotIndex: 0,
            project: work,
            scenes: [scene],
            tileManager: tiles,
            comment: '手動テスト',
          );
        }
        tiles.getTile(key, 0, 0)!.setRange(0, 4, older);
        await autosaves.save(id, projects);
        tiles.getTile(key, 0, 0)!.setRange(0, 4, latest);
        await autosaves.save(id, projects);
        tiles.importAll(const {});
        // The app is opened again after it was closed.
        autosaves.debugTreatSlotsAsFromEarlierLaunch();
      });

      appRouter.go('/project/$id');
      await settleIo(tester);
      await tester.ensureVisible(find.text(l10n.projectDetailStartEditButton));
      await tester.tap(find.text(l10n.projectDetailStartEditButton));
      await settleIo(tester);
      expect(find.byType(CanvasScreen), findsOneWidget);
      // The autosaves are newer than the work file and differ from it (the
      // app closed before the file caught up): the work opens with the newest
      // without asking.
      expect(find.byType(AlertDialog), findsNothing);
      expect(tiles.getTile(key, 0, 0)?.take(4), latest);

      appRouter.push('/save-tree/$id');
      await settleIo(tester);
      final autoSelector = find.widgetWithText(
        ChoiceChip,
        l10n.helpAutoSaveTitle,
      );
      final manualSelector = find.widgetWithText(
        ChoiceChip,
        l10n.saveDataManualTab,
      );
      expect(tester.widget<ChoiceChip>(manualSelector).selected, isTrue);
      await tester.tap(autoSelector);
      await settleIo(tester);
      final autoItems = find.descendant(
        of: find.byType(AutosaveList),
        matching: find.byType(ListTile),
      );
      expect(autoItems, findsNWidgets(2));
      await settleIo(tester, 16);
      final thumbnails = find.descendant(
        of: find.byType(AutosaveList),
        matching: find.byType(SavedThumbnail),
      );
      final first = tester.widget<SavedThumbnail>(thumbnails.first).bytes;
      final second = tester.widget<SavedThumbnail>(thumbnails.last).bytes;
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first, isNot(orderedEquals(second!)));
      await tester.tap(autoItems.at(1));
      await settleIo(tester, 16);
      final preview = find.byKey(const ValueKey('saveRestorePreview'));
      expect(
        tester.widget<SavedThumbnail>(preview).bytes,
        orderedEquals(second),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.saveTreeRestoreAction),
      );
      await settleIo(tester);
      expect(tiles.getTile(key, 0, 0)?.take(4), older);
      // The confirmation temporarily overlays the bottom row of the tree.
      await tester.pump(const Duration(seconds: 5));
      await settleIo(tester);

      await tester.tap(manualSelector);
      await settleIo(tester);
      if (tree) {
        final node = find.ancestor(
          of: find.text('手動テスト'),
          matching: find.byType(ListTile),
        );
        await tester.tap(
          find.descendant(
            of: node,
            matching: find.byType(PopupMenuButton<String>),
          ),
          kind: PointerDeviceKind.mouse,
        );
        await settleIo(tester);
        await tester.tap(find.text(l10n.saveTreeRestoreAction));
      } else {
        await tester.tap(find.byTooltip(l10n.saveTreeSlotLoadTooltip).first);
      }
      await settleIo(tester, 16);
      expect(tester.widget<SavedThumbnail>(preview).bytes, isNotNull);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.saveTreeRestoreAction),
      );
      await settleIo(tester);
      expect(tiles.getTile(key, 0, 0)?.take(4), manual);
      if (tree) {
        appRouter.pop();
        await settleIo(tester);
        await tester.tap(
          find
              .byTooltip(l10n.timelineBackToProjectListTooltip)
              .hitTestable()
              .first,
          kind: PointerDeviceKind.mouse,
        );
        await settleIo(tester, 3);
        expect(
          find.text(l10n.timelineBackToProjectListDialogBody),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('editor switches stay above the canvas at ${size.width}px', (
      tester,
    ) async {
      final project = await open(tester, size: size);
      appRouter.go('/canvas/${project.id}');
      await settleIo(tester);

      final button = find.byKey(const Key('canvasTimelineModeButton'));
      final frame = find.byKey(const ValueKey('frameStripCell0'));
      expect(button, findsOneWidget);
      expect(tester.getCenter(button).dy, lessThan(tester.getCenter(frame).dy));
      expect(tester.getCenter(frame).dx, closeTo(size.width / 2, .5));
      expect(
        find.byKey(const ValueKey('frameStripTimelineButton')),
        findsNothing,
      );

      await tester.tap(button);
      await settleIo(tester);
      expect(find.byType(TimelineScreen), findsOneWidget);
      final canvasButton = find.ancestor(
        of: find.byIcon(Icons.palette_outlined),
        matching: find.byType(IconButton),
      );
      expect(canvasButton, findsOneWidget);
      expect(tester.getCenter(canvasButton).dx, lessThan(size.width / 2));
      expect(tester.getCenter(canvasButton).dy, lessThan(size.height / 2));
      await tester.tap(canvasButton);
      await settleIo(tester);
      expect(find.byType(CanvasScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unknown id offers the way back instead of a blank canvas', (
    tester,
  ) async {
    await open(tester);
    appRouter.push('/canvas/does-not-exist');
    await settleIo(tester);
    expect(find.byType(ProjectNotFoundView), findsOneWidget);
    expect(find.text('プロジェクトが見つかりません'), findsOneWidget);
    await tester.tap(find.byKey(const Key('canvasNotFoundHome')));
    await settleIo(tester, 4);
    expect(location(), '/home');
    expect(tester.takeException(), isNull);
  });

  // 一番長い仏語の文言・文字2倍・320pxでも、一覧へ戻るボタンの文字は
  // ボタンの中に収まり（折り返した見出しの書体の下の出っ張りがボタンの外へ
  // はみ出していた）、各行がボタンの中央にそろう。
  testWidgets('the way back fits in French at twice the text size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'fr',
    });
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    appRouter.push('/canvas/does-not-exist');
    await settleIo(tester);
    final button = find.byKey(const Key('canvasNotFoundHome'));
    final label = find.descendant(
      of: button,
      matching: find.text('Aller aux projets'),
    );
    expect(label, findsOneWidget);
    final buttonRect = tester.getRect(button);
    final paragraph = tester.renderObject<RenderParagraph>(label);
    final origin = paragraph.localToGlobal(Offset.zero);
    // 字の箱（行末の空白は中央そろえで数えないので除く）。
    const text = 'Aller aux projets';
    final lines = [
      for (var i = 0; i < text.length; i++)
        if (text[i] != ' ')
          ...paragraph.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          ),
    ];
    // 折り返して2行になる大きさで確かめる。
    expect(lines.map((b) => b.top).toSet().length, greaterThanOrEqualTo(2));
    // 上下とも、書体の出っ張りが収まるだけの余白がボタンの中にある。
    final textTop = origin.dy + lines.map((b) => b.top).reduce(math.min);
    final textBottom = origin.dy + lines.map((b) => b.bottom).reduce(math.max);
    expect(textTop - buttonRect.top, greaterThanOrEqualTo(8));
    expect(buttonRect.bottom - textBottom, greaterThanOrEqualTo(8));
    // 各行がボタンの中央にそろう（左寄せにならない）。
    final byLine = <double, Rect>{};
    for (final box in lines) {
      final rect = box.toRect().shift(origin);
      byLine.update(
        box.top,
        (r) => r.expandToInclude(rect),
        ifAbsent: () => rect,
      );
    }
    for (final line in byLine.values) {
      expect(
        (line.left - buttonRect.left) - (buttonRect.right - line.right),
        moreOrLessEquals(0, epsilon: 2),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the missing-materials notice times out and stays behind', (
    tester,
  ) async {
    final s = await open(tester);
    final materials = tester
        .element(find.byType(HomeScreen))
        .read<MaterialService>();
    await tester.runAsync(() async {
      final source = File('${tempDir.path}/source.png')
        ..writeAsBytesSync([1, 2, 3]);
      final asset = await materials.addMaterial(
        projectId: s.id,
        sourcePath: source.path,
        type: MaterialType.image,
      );
      // 素材のファイルだけが無くなった状態にする。
      for (final file in tempDir.listSync(recursive: true).whereType<File>()) {
        if (file.path.endsWith(asset.storageName)) file.deleteSync();
      }
    });
    appRouter.push('/canvas/${s.id}');
    await settleIo(tester, 12);
    expect(find.text('不足素材があります'), findsOneWidget);
    // 6秒で消える（操作ボタン付きは既定では消えなかった）。
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('不足素材があります'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // 開いて何も変えずに家のボタンを押すと、聞かずに一覧へ戻る（以前は開いて
  // 閉じただけ・再生しただけでも「保存してから戻りますか？」と聞いた）。
  for (final path in ['canvas', 'timeline']) {
    testWidgets('going back from the $path without changes does not ask', (
      tester,
    ) async {
      final s = await open(tester);
      appRouter.push('/$path/${s.id}');
      await settleIo(tester, 10);
      await tester.tap(find.byTooltip('プロジェクト一覧に戻る'));
      await settleIo(tester, 6);
      expect(find.text('保存して戻る'), findsNothing);
      expect(location(), '/home');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('save-and-return stays on the canvas when nothing was saved', (
    tester,
  ) async {
    final s = await open(tester);
    appRouter.push('/canvas/${s.id}');
    await settleIo(tester, 10);
    expect(find.byType(CanvasScreen), findsOneWidget);
    await change(tester, s.service, s.id);

    Future<void> chooseSaveAndReturn() async {
      await tester.tap(find.byTooltip('プロジェクト一覧に戻る'));
      await settleIo(tester, 3);
      await tester.tap(find.widgetWithText(FilledButton, '保存して戻る'));
      await settleIo(tester, 6);
      expect(find.byType(SaveManagementScreen), findsOneWidget);
    }

    // 保存の画面から何も保存せずに戻る：取り消しとしてキャンバスに残る。
    await chooseSaveAndReturn();
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await settleIo(tester, 6);
    expect(find.byType(SaveManagementScreen), findsNothing);
    expect(find.byType(CanvasScreen), findsOneWidget);

    // 保存してから戻ると一覧へ移る。
    await chooseSaveAndReturn();
    final saves = tester
        .element(find.byType(Scaffold).last)
        .read<SaveTreeService>();
    await tester.runAsync(
      () => saves.saveToSlot(
        projectId: s.id,
        slotIndex: 0,
        project: s.service.projects.singleWhere((p) => p.id == s.id),
        scenes: s.service.scenesOf(s.id),
        tileManager: s.service.tileManagerOf(s.id),
      ),
    );
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await settleIo(tester, 6);
    expect(location(), '/home');
    expect(find.byType(CanvasScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // タイムラインの「保存して戻る」も同じ：保存の画面から何も保存せずに
  // 戻ったら一覧へ移らず、タイムラインに残る（描きかけを保存したつもりで
  // 一覧へ移ってしまわない）。
  testWidgets('save-and-return stays on the timeline when nothing was saved', (
    tester,
  ) async {
    final s = await open(tester);
    appRouter.push('/timeline/${s.id}');
    await settleIo(tester, 10);
    expect(find.byType(TimelineScreen), findsOneWidget);
    await change(tester, s.service, s.id);

    Future<void> chooseSaveAndReturn() async {
      await tester.tap(find.byTooltip('プロジェクト一覧に戻る'));
      await settleIo(tester, 3);
      await tester.tap(find.widgetWithText(FilledButton, '保存して戻る'));
      await settleIo(tester, 6);
      expect(find.byType(SaveManagementScreen), findsOneWidget);
    }

    await chooseSaveAndReturn();
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await settleIo(tester, 6);
    expect(find.byType(SaveManagementScreen), findsNothing);
    expect(find.byType(TimelineScreen), findsOneWidget);
    // タイムラインが一番上の画面のまま（一覧へ移っていない）。
    expect(
      ModalRoute.of(tester.element(find.byType(TimelineScreen)))!.isCurrent,
      isTrue,
    );

    // 保存してから戻ると一覧へ移る。
    await chooseSaveAndReturn();
    final saves = tester
        .element(find.byType(Scaffold).last)
        .read<SaveTreeService>();
    await tester.runAsync(
      () => saves.saveToSlot(
        projectId: s.id,
        slotIndex: 0,
        project: s.service.projects.singleWhere((p) => p.id == s.id),
        scenes: s.service.scenesOf(s.id),
        tileManager: s.service.tileManagerOf(s.id),
      ),
    );
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await settleIo(tester, 6);
    expect(location(), '/home');
    expect(find.byType(TimelineScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 保存の画面で一番新しい保存を消しただけで戻るのも「保存した」ではない
  // （一番新しい保存の時刻は変わるが、前より新しくはならない）。キャンバスも
  // タイムラインも残る。
  for (final (path, type) in const [
    ('canvas', CanvasScreen),
    ('timeline', TimelineScreen),
  ]) {
    testWidgets('deleting the newest save and going back stays on the $path', (
      tester,
    ) async {
      final s = await open(tester);
      final saves = tester
          .element(find.byType(HomeScreen))
          .read<SaveTreeService>();
      Future<String> saveSlot(int slot) async {
        final node = await tester.runAsync(
          () => saves.saveToSlot(
            projectId: s.id,
            slotIndex: slot,
            project: s.service.projects.singleWhere((p) => p.id == s.id),
            scenes: s.service.scenesOf(s.id),
            tileManager: s.service.tileManagerOf(s.id),
          ),
        );
        return node!.id;
      }

      await saveSlot(0);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      final newest = await saveSlot(1);
      appRouter.push('/$path/${s.id}');
      await settleIo(tester, 10);
      expect(find.byType(type), findsOneWidget);
      await change(tester, s.service, s.id);

      await tester.tap(find.byTooltip('プロジェクト一覧に戻る'));
      await settleIo(tester, 3);
      await tester.tap(find.widgetWithText(FilledButton, '保存して戻る'));
      await settleIo(tester, 6);
      expect(find.byType(SaveManagementScreen), findsOneWidget);
      final before = saves.latestSaveOf(s.id);
      await tester.runAsync(() => saves.deleteNode(s.id, newest));
      // 一番新しい保存の時刻は前の保存の時刻へ戻った。
      expect(saves.latestSaveOf(s.id)!.isBefore(before!), isTrue);
      GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
      await settleIo(tester, 6);
      expect(find.byType(SaveManagementScreen), findsNothing);
      expect(find.byType(type), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(type)))!.isCurrent,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
