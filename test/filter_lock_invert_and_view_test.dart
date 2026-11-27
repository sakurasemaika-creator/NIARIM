// 判断カード（所有者の判断、2026-11-27）のJ6・J8・J10。
//
// * J8 ロックしたレイヤーでは、フィルターを開いた時点で知らせる（以前は値を
//   調整して「適用」を押してから断っていた）。
// * J10 「色反転」は無料（トーンカーブは有料のまま）。範囲を選んでいる間は
//   フィルターのパネルに「選択範囲を反転」を出す。
// * J6 PCの作業画面からスマホの画面へ移ったら、キャンバスを全体表示に戻す。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The canvas of a new 64×48 work in the PC workspace (1440×900).
  Future<({ProjectService ps, FilterService filters, String id})> openCanvas(
    WidgetTester tester,
  ) async {
    tempDir = Directory.systemTemp.createTempSync('niarim_filter_cards_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 1,
    });
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final ps = home.read<ProjectService>();
    final filters = home.read<FilterService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'cards',
        fps: 4,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 48,
      ),
    ))!;
    appRouter.push('/canvas/${project.id}');
    await settle(tester, 12);
    return (ps: ps, filters: filters, id: project.id);
  }

  Future<AppLocalizations> openFilters(WidgetTester tester) async {
    final l10n = AppLocalizations.of(tester.element(find.byType(CanvasArea)))!;
    await tester.tap(find.byIcon(Icons.settings).first);
    await settle(tester, 3);
    await tester.tap(find.text(l10n.filterPanelTitle).last);
    await settle(tester, 4);
    expect(find.byType(FilterPanel), findsOneWidget);
    return l10n;
  }

  Future<void> chooseInvert(WidgetTester tester, AppLocalizations l10n) async {
    final grid = find.byKey(const ValueKey('filter-tile-grid'));
    final tile = find.descendant(
      of: grid,
      matching: find.text(l10n.filterNameInvert),
    );
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.descendant(of: grid, matching: find.byType(Scrollable)),
    );
    // The dock column around the filter window scrolls too.
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile, warnIfMissed: false);
    await settle(tester, 4);
  }

  testWidgets('a locked layer is told when a filter is opened', (tester) async {
    final (:ps, :filters, :id) = await openCanvas(tester);
    final scene = ps.scenesOf(id).first.id;
    final layer = tester.widget<CanvasArea>(find.byType(CanvasArea));
    final current = ps
        .layersOf(id, scene, 0)
        .singleWhere((l) => l.id == layer.currentLayerId);
    ps.updateLayer(
      projectId: id,
      sceneId: scene,
      frameIndex: 0,
      layer: current.copyWith(isLocked: true),
      recordUndo: false,
    );
    final l10n = await openFilters(tester);
    await chooseInvert(tester, l10n);
    expect(filters.currentFilter, isNull, reason: 'not opened');
    expect(find.text(l10n.canvasLayerLockedNotice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invert is free and the selection can be inverted from it', (
    tester,
  ) async {
    final (:ps, :filters, :id) = await openCanvas(tester);
    final scene = ps.scenesOf(id).first.id;
    final layerId = tester
        .widget<CanvasArea>(find.byType(CanvasArea))
        .currentLayerId!;
    // A white layer: inverted it is black.
    final white = Uint8List(64 * 48 * 4)..fillRange(0, 64 * 48 * 4, 255);
    ps
        .tileManagerOf(id)
        .replaceLayerPixels(ps.tileKeyFor(id, scene, 0, layerId), white);

    // Select everything with the selection tool.
    await tester.tap(find.byIcon(Icons.highlight_alt).first);
    await settle(tester, 3);
    await tester.tap(find.byIcon(Icons.select_all).hitTestable().first);
    await settle(tester, 4);
    final l10n = await openFilters(tester);
    await chooseInvert(tester, l10n);
    expect(filters.currentFilter?.id, 'Filter0025');
    FilterPanel panel() => tester.widget<FilterPanel>(find.byType(FilterPanel));
    expect(panel().selectionMask, isNotNull);
    expect(panel().selectionMask!.every((v) => v != 0), isTrue);

    final invertSelection = find.byKey(const ValueKey('filterInvertSelection'));
    expect(invertSelection, findsOneWidget);
    await tester.tap(invertSelection);
    await settle(tester, 3);
    expect(panel().selectionMask!.every((v) => v == 0), isTrue);
    // Back to everything, then apply (no premium banner on the free tile).
    await tester.tap(invertSelection);
    await settle(tester, 3);
    expect(panel().selectionMask!.every((v) => v != 0), isTrue);
    await tester.tap(find.byKey(const ValueKey('filter-apply-button')));
    await settle(tester, 8);
    expect(filters.currentFilter, isNull, reason: 'applied');
    final pixel = ps
        .tileManagerOf(id)
        .getPixelColorAt(ps.tileKeyFor(id, scene, 0, layerId), 10, 10);
    expect(pixel, isNotNull);
    expect([pixel!.r, pixel.g, pixel.b], everyElement(lessThan(0.02)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone layout starts from the whole picture', (tester) async {
    await openCanvas(tester);
    CanvasArea area() => tester.widget<CanvasArea>(find.byType(CanvasArea));
    final before = area().viewRequest?.serial ?? 0;
    tester.view.physicalSize = const Size(390, 844);
    await settle(tester, 4);
    expect(area().viewRequest?.action, CanvasViewAction.fit);
    expect(area().viewRequest!.serial, greaterThan(before));
    expect(tester.takeException(), isNull);
  });
}
