// キャンバスに足した4つ（所有者の判断、2026-11-27、全部入りの作品づくりの
// 判断カードJ16）。
//
// * キャンバスプレビューをスマホのメニューにも（以前はPCの窓だけ）。スマホでは
//   動かせる小窓。
// * 複数のコマを選んで複製・削除（以前は選んでできるのはフィルターの適用だけ）。
// * 共通レイヤーのキーフレームをレイヤーパネルで編集（以前はタイムラインだけ）。
// * オニオンスキンの色を自由に選ぶ（以前は8色だけ）。枚数が品質の設定で
//   決まっているときは、変える場所を案内する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/onion_skin_panel.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

void main() {
  Future<({ProjectService ps, String id, String scene, AppLocalizations l10n})>
  openCanvas(WidgetTester tester, {String? commonLayerName}) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('canvas-j16-');
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
    appRouter.go('/home');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'j16',
        fps: 4,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 48,
      ),
    ))!;
    final scene = ps.scenesOf(project.id).first.id;
    if (commonLayerName != null) {
      final common = ps.addLayer(
        projectId: project.id,
        sceneId: scene,
        frameIndex: 0,
        type: LayerType.common,
        name: commonLayerName,
      );
      ps.updateLayer(
        projectId: project.id,
        sceneId: scene,
        frameIndex: 0,
        layer: common.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 4,
        ),
        recordUndo: false,
      );
    }
    appRouter.push('/canvas/${project.id}');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CanvasScreen)),
    )!;
    return (ps: ps, id: project.id, scene: scene, l10n: l10n);
  }

  Future<void> settle(WidgetTester tester) =>
      pumpRealAsync(tester, const Duration(milliseconds: 300));

  Future<void> openMenuItem(WidgetTester tester, Finder item) async {
    await tester.tap(find.byIcon(Icons.settings).first);
    await settle(tester);
    await tester.scrollUntilVisible(
      item,
      200,
      scrollable: find
          .ancestor(of: item, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(item);
    await settle(tester);
  }

  testWidgets('the phone menu opens the canvas preview as a window', (
    tester,
  ) async {
    final (:ps, :id, :scene, :l10n) = await openCanvas(tester);
    await tester.tap(find.byIcon(Icons.settings).first);
    await settle(tester);
    final item = find.byKey(const ValueKey('canvasEditMenuPreviewNavigator'));
    expect(item, findsOneWidget, reason: 'on the phone too');
    await tester.tap(item);
    await settle(tester);
    final window = find.byKey(const ValueKey('canvasPreviewFloatingWindow'));
    expect(window, findsOneWidget);
    final before = tester.getTopLeft(window);
    await tester.drag(
      find.byKey(const ValueKey('canvasPreviewNavigatorTitle')),
      const Offset(-120, 200),
    );
    await tester.pump();
    final after = tester.getTopLeft(window);
    expect(after.dx, lessThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
    // It stays on the screen.
    await tester.drag(
      find.byKey(const ValueKey('canvasPreviewNavigatorTitle')),
      const Offset(-2000, -2000),
    );
    await tester.pump();
    expect(tester.getTopLeft(window), Offset.zero);
    await tester.tap(find.byKey(const ValueKey('canvasPreviewNavigatorClose')));
    await settle(tester);
    expect(window, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chosen frames are duplicated and removed, one undo each', (
    tester,
  ) async {
    final (:ps, :id, :scene, :l10n) = await openCanvas(tester);
    final undo = tester.element(find.byType(CanvasScreen)).read<UndoManager>();
    expect(ps.frameCount(id, scene), 4);
    Future<void> choose(List<int> frames) async {
      await openMenuItem(
        tester,
        find.text(l10n.canvasEditMenuFrameMultiSelect).last,
      );
      for (final frame in frames) {
        final cell = find.byKey(ValueKey('frameStripCell$frame'));
        await tester.ensureVisible(cell);
        await tester.tap(cell);
        await tester.pump();
      }
    }

    Future<void> press(String name) async {
      // The bar shows the words where they fit, the icons otherwise.
      final words = find.byKey(ValueKey('frameMultiSelect$name'));
      final icon = find.byKey(ValueKey('frameMultiSelect${name}Icon'));
      await tester.tap(words.evaluate().isNotEmpty ? words : icon);
      await settle(tester);
    }

    await choose([1, 2]);
    await press('Duplicate');
    expect(ps.frameCount(id, scene), 6);
    expect(find.byKey(const ValueKey('frameMultiSelectBar')), findsNothing);
    undo.undo(projectId: id);
    await settle(tester);
    expect(ps.frameCount(id, scene), 4, reason: 'one undo step');

    await choose([0, 3]);
    await press('Delete');
    expect(ps.frameCount(id, scene), 2);
    undo.undo(projectId: id);
    await settle(tester);
    expect(ps.frameCount(id, scene), 4, reason: 'one undo step');

    // Every frame chosen: one has to stay, so it can't be pressed.
    await choose([0, 1, 2, 3]);
    final words = find.byKey(const ValueKey('frameMultiSelectDelete'));
    final icon = find.byKey(const ValueKey('frameMultiSelectDeleteIcon'));
    final button = words.evaluate().isNotEmpty
        ? tester.widget<ButtonStyleButton>(words).onPressed
        : tester.widget<IconButton>(icon).onPressed;
    expect(button, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a common layer\'s keyframes from the layer panel', (
    tester,
  ) async {
    final (:ps, :id, :scene, :l10n) = await openCanvas(
      tester,
      commonLayerName: 'Sky',
    );
    // The layer panel, then the common layer's menu.
    tester.widget<ToolbarWidget>(find.byType(ToolbarWidget)).onLayerTap();
    await settle(tester);
    final common = ps
        .storedLayersOf(id, scene, 0)
        .singleWhere((l) => l.type == LayerType.common);
    final menu = find.byKey(ValueKey('canvasLayerMenu_${common.id}'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('commonLayerKeyframes')));
    await settle(tester);
    expect(find.text(l10n.layerKeyframeSheetTitle('Sky')), findsOneWidget);
    await tester.tap(find.text(l10n.layerKeyframeAddAtCurrentFrame(1)));
    await settle(tester);
    final save = find.text(l10n.commonSave).last;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
    final stored = ps
        .storedLayersOf(id, scene, 0)
        .singleWhere((l) => l.id == common.id);
    expect(stored.keyframes.map((k) => k.frameIndex), [0]);
    expect(stored.type, LayerType.common);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onion skin: any colour, and where the frame count is set', (
    tester,
  ) async {
    final (:ps, :id, :scene, :l10n) = await openCanvas(tester);
    await openMenuItem(tester, find.text(l10n.onionSkinTitle).last);
    expect(find.byType(OnionSkinPanel), findsOneWidget);
    // Turn it on to see the settings.
    await tester.tap(
      find
          .descendant(
            of: find.byType(OnionSkinPanel),
            matching: find.byType(Switch),
          )
          .first,
    );
    await settle(tester);
    // The default quality fixes the count: say where to change it.
    expect(
      find.byKey(const ValueKey('onionSkinFrameCountHint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onionSkinOpenPerformance')),
      findsOneWidget,
    );

    final colourRow = find.text(l10n.onionSkinColorLabel).first;
    await tester.ensureVisible(colourRow);
    await tester.tap(colourRow);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('onionSkinMoreColors')));
    await settle(tester);
    expect(find.byType(ColorPickerPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
