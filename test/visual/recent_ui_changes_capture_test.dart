import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/screens/canvas/widgets/hsv_color_wheel.dart';
import 'package:niarim/screens/canvas/widgets/frame_strip_widget.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/settings/widgets/pc_workspace_layout_preview.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/load_app_fonts.dart';
import '../helpers/first_use_tooltips.dart';

final _out = Directory('build/recent-ui-changes-captures');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await _settle(tester);
  final error = tester.takeException();
  expect(error, isNull, reason: 'Unexpected Flutter error before $name');
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data!.buffer.asUint8List();
  });
  await tester.runAsync(() =>
      File(_out.path + '/$name.png').writeAsBytes(bytes!));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => _out.createSync(recursive: true));

  testWidgets('capture responsive project and community tile defaults',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final docs = Directory.systemTemp.createTempSync('niarim_tiles_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => docs.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      docs.deleteSync(recursive: true);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = (await tester.runAsync(buildAppProviders))!;
    final root = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: MultiProvider(providers: providers, child: const NiarimApp()),
    ));
    await _settle(tester);
    final context = tester.element(find.byType(MaterialApp).first);
    final ps = context.read<ProjectService>();
    final settings = context.read<SettingsService>();
    await settings.markFirstLaunchDone();
    for (var i = 0; i < 7; i++) {
      await tester.runAsync(() => ps.createProject(
        name: 'タイル表示テスト ' + (i + 1).toString(),
        fps: 12,
        durationSeconds: 1,
        backgroundColor: i.isEven ? 0xFFB8CEDA : 0x00000000,
        exportWidth: 320,
        exportHeight: 180,
      ));
    }
    Future<void> goto(String route) async {
      appRouter.go(route);
      await _settle(tester);
    }
    await goto('/home');
    await _shot(tester, root, '01_projects_phone_default_small');
    tester.view.physicalSize = const Size(820, 1180);
    await _shot(tester, root, '02_projects_tablet_default_medium');
    tester.view.physicalSize = const Size(1500, 900);
    await _shot(tester, root, '03_projects_pc_default_large');
    final modeButton = find.byIcon(Icons.view_module);
    expect(modeButton, findsWidgets);
    await tester.tap(modeButton.first);
    await _settle(tester);
    final homeL10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last))!;
    await tester.tap(find.text(homeL10n.homeViewModeSmall).last);
    await _shot(tester, root, '04_projects_pc_user_override_small');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('home.projectViewMode.v1'), 'small');

    await goto('/community');
    tester.view.physicalSize = const Size(390, 844);
    await _shot(tester, root, '05_community_phone_default_small');
    tester.view.physicalSize = const Size(820, 1180);
    await _shot(tester, root, '06_community_tablet_default_medium');
    tester.view.physicalSize = const Size(1500, 900);
    await _shot(tester, root, '07_community_pc_default_large');
    final tileButton = find.byKey(const Key('communityTileSizeButton'));
    expect(tileButton, findsOneWidget);
    await tester.tap(tileButton);
    await _settle(tester);
    final slider = find.byKey(const Key('communityTileSizeQuickSlider'));
    expect(slider, findsOneWidget);
    tester.widget<Slider>(slider).onChanged!(320);
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last))!;
    await tester.tap(find.text(l10n.commonSave).last);
    await _shot(tester, root, '08_community_pc_user_override_320');
    expect((await SharedPreferences.getInstance())
        .getDouble('community.tileMinWidth.v1'), 320);
    tester.view.physicalSize = const Size(820, 1180);
    await _shot(tester, root, '09_community_tablet_preserves_user_override');
  }, timeout: const Timeout(Duration(minutes: 11)));

  testWidgets('capture desktop canvas dock actions', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final docs = Directory.systemTemp.createTempSync('niarim_docks_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => docs.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      docs.deleteSync(recursive: true);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = (await tester.runAsync(buildAppProviders))!;
    final root = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: MultiProvider(providers: providers, child: const NiarimApp()),
    ));
    await _settle(tester);
    final context = tester.element(find.byType(MaterialApp).first);
    final ps = context.read<ProjectService>();
    final settings = context.read<SettingsService>();
    await settings.markFirstLaunchDone();
    await settings.setForcePcMode(true);
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
      CanvasDockPanel.canvasPreview,
    });
    final project = (await tester.runAsync(() => ps.createProject(
      name: 'PC ドック配置確認',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFB8CEDA,
      exportWidth: 320,
      exportHeight: 180,
    )))!;
    appRouter.go('/canvas/' + project.id);
    await _shot(tester, root, '10_pc_canvas_docks_expanded');

    // Dock windows must start at their column's top, rather than centering
    // vertically when only one window is open on a side.
    final leftDock = tester.getRect(
      find.byKey(const ValueKey('desktopLeftDockScroll')),
    );
    final rightDock = tester.getRect(
      find.byKey(const ValueKey('desktopRightDockScroll')),
    );
    final brushWindow = tester.getRect(
      find.byKey(const ValueKey('dockTarget-brush')),
    );
    final previewWindow = tester.getRect(
      find.byKey(const ValueKey('dockTarget-canvasPreview')),
    );
    final frameStrip = tester.getRect(find.byType(FrameStripWidget));
    // Capture actual bounds to distinguish a vertically centered column
    // from a child panel centered within a full-height column.
    debugPrint('DOCK_GEOMETRY expanded: '
        'left=$leftDock right=$rightDock '
        'brush=$brushWindow preview=$previewWindow frame=$frameStrip');
    expect(brushWindow.top, closeTo(leftDock.top, 2));
    expect(previewWindow.top, closeTo(rightDock.top, 2));
    expect(leftDock.top, closeTo(rightDock.top, 2),
        reason: 'Both side columns must start directly under the top menu');
    expect(leftDock.bottom, lessThanOrEqualTo(frameStrip.top + 1));
    expect(rightDock.bottom, lessThanOrEqualTo(frameStrip.top + 1));
    expect(leftDock.left, greaterThanOrEqualTo(-1));
    expect(rightDock.right, lessThanOrEqualTo(1501));

    // Narrow desktop/DeX viewport: neither column may leave the screen or
    // overlap the frame strip, even with three open windows on the right.
    tester.view.physicalSize = const Size(800, 600);
    await _shot(tester, root, '28_pc_narrow_800x600_docks_fit');
    final narrowLeft =
        tester.getRect(find.byKey(const ValueKey('desktopLeftDockScroll')));
    final narrowRight =
        tester.getRect(find.byKey(const ValueKey('desktopRightDockScroll')));
    final narrowFrames = tester.getRect(find.byType(FrameStripWidget));
    final narrowBrush =
        tester.getRect(find.byKey(const ValueKey('dockTarget-brush')));
    final narrowPreview =
        tester.getRect(find.byKey(const ValueKey('dockTarget-canvasPreview')));
    final narrowColor =
        tester.getRect(find.byKey(const ValueKey('dockTarget-colorPicker')));
    final narrowLayers =
        tester.getRect(find.byKey(const ValueKey('dockTarget-layer')));
    expect(narrowLeft.left, greaterThanOrEqualTo(-1));
    expect(narrowRight.right, lessThanOrEqualTo(801));
    expect(narrowLeft.right, lessThan(narrowRight.left));
    expect(narrowLeft.top, closeTo(narrowRight.top, 2));
    expect(narrowBrush.top, closeTo(narrowLeft.top, 2));
    expect(narrowPreview.top, closeTo(narrowRight.top, 2));
    expect(narrowLeft.bottom, lessThanOrEqualTo(narrowFrames.top + 1));
    expect(narrowRight.bottom, lessThanOrEqualTo(narrowFrames.top + 1));
    expect(narrowColor.width, closeTo(narrowLayers.width, 1));
    expect(narrowPreview.width, closeTo(narrowColor.width, 1));

    tester.view.physicalSize = const Size(1500, 900);
    await _settle(tester);
    final brushFold = find.byKey(const ValueKey('dockCollapse-brush'));
    final layerFold = find.byKey(const ValueKey('dockCollapse-layer'));
    expect(brushFold, findsOneWidget);
    expect(layerFold, findsOneWidget);
    await tester.tap(brushFold);
    await _shot(tester, root, '11_pc_canvas_left_brush_folded');
    await tester.tap(layerFold);
    await _shot(tester, root, '12_pc_canvas_both_sides_partially_folded');

    // A folded icon is directly draggable across dock columns and remains
    // folded. Tap on that same icon expands it.
    final collapsedBrush = find.byKey(
      const ValueKey('dockCollapsedDrag-brush'),
    );
    final rightTarget = find.byKey(
      const ValueKey('dockTarget-canvasPreview'),
    );
    expect(collapsedBrush, findsOneWidget);
    await tester.drag(
      collapsedBrush,
      tester.getCenter(rightTarget) - tester.getCenter(collapsedBrush),
    );
    await _settle(tester);
    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    await _shot(tester, root, '29_pc_collapsed_icon_dragged_to_right');
    await settings.moveDesktopDockPanel(CanvasDockPanel.brush, toRight: false);
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('dockExpand-brush')));
    await _shot(tester, root, '13_pc_canvas_left_brush_expanded');
    final height = find.byKey(const ValueKey('dockResize-canvasPreview'));
    final width = find.byKey(const ValueKey('dockColumnResize-right'));
    expect(height, findsOneWidget);
    expect(width, findsOneWidget);
    await tester.drag(height, const Offset(0, 80));
    await _shot(tester, root, '14_pc_canvas_vertical_resize');
    await tester.drag(width, const Offset(-55, 0));
    await _shot(tester, root, '15_pc_canvas_horizontal_resize');
    await settings.moveDesktopDockPanel(
      CanvasDockPanel.canvasPreview, toRight: false,
    );
    await _shot(tester, root, '16_pc_canvas_moved_between_sides');
    expect(
      tester.getRect(find.byKey(const ValueKey('desktopRightDockScroll'))).top,
      closeTo(
        tester.getRect(find.byKey(const ValueKey('desktopLeftDockScroll'))).top,
        2,
      ),
      reason: 'Moving a window must not re-center the shorter dock column',
    );
    final toolbarRightHanded = tester.getRect(find.byType(ToolbarWidget));
    final leftBefore = tester.getRect(
      find.byKey(const ValueKey('desktopLeftDockScroll')),
    );
    expect(toolbarRightHanded.right, lessThanOrEqualTo(leftBefore.left + 1));
    await settings.setLeftHanded(true);
    await _shot(tester, root, '17_pc_canvas_left_handed_layout');
    final leftAfter = tester.getRect(
      find.byKey(const ValueKey('desktopLeftDockScroll')),
    );
    final rightAfter = tester.getRect(
      find.byKey(const ValueKey('desktopRightDockScroll')),
    );
    final toolbarLeftHanded = tester.getRect(find.byType(ToolbarWidget));
    expect(leftAfter.right, lessThan(rightAfter.left));
    expect(toolbarLeftHanded.left, greaterThanOrEqualTo(rightAfter.right - 1));
    expect(toolbarLeftHanded.right, lessThanOrEqualTo(1501));

    // Explicitly exercise the tiny viewport described in the user report.
    await settings.setLeftHanded(false);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.layer, true);
    await settings.setDesktopDockWidth(CanvasDockPanel.colorPicker, 200);
    await settings.setDesktopDockHeight(CanvasDockPanel.colorPicker, 140);
    await _shot(tester, root, '24_pc_color_picker_200x140_entire_wheel');
    final wheel = tester.getRect(find.byType(HsvColorWheel));
    final dock = tester.getRect(
      find.byKey(const ValueKey('dockViewport-colorPicker')),
    );
    expect(wheel.left, greaterThanOrEqualTo(dock.left - 1));
    expect(wheel.right, lessThanOrEqualTo(dock.right + 1));
    expect(wheel.top, greaterThanOrEqualTo(dock.top - 1));
    expect(wheel.bottom, lessThanOrEqualTo(dock.bottom + 1));
    expect((wheel.width - wheel.height).abs(), lessThan(1.0));

    await settings.setDesktopDockWidth(CanvasDockPanel.colorPicker, 480);
    await settings.setDesktopDockHeight(CanvasDockPanel.colorPicker, 600);
    await _shot(tester, root, '25_pc_color_picker_480x600_full_wheel');

    await settings.setDesktopDockWidth(CanvasDockPanel.brush, 200);
    await settings.setDesktopDockHeight(CanvasDockPanel.brush, 140);
    await _shot(tester, root, '26_pc_brush_short_scrollable');
    await settings.setDesktopDockWidth(CanvasDockPanel.brush, 480);
    await _shot(tester, root, '27_pc_brush_wide_same_height');
  }, timeout: const Timeout(Duration(minutes: 11)));

  testWidgets('capture interactive PC workspace preview', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final settings = SettingsService();
    await settings.init();
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
      CanvasDockPanel.canvasPreview,
    });
    final root = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PcWorkspaceLayoutPreview(labelOf: (panel) => panel.name),
          ),
        ),
      ),
    ));
    await _shot(tester, root, '18_pc_layout_preview_default');
    await tester.tap(
      find.byKey(const ValueKey('pcPreviewCollapse-brush')));
    await _shot(tester, root, '19_pc_layout_preview_left_folded');
    // The right column uses lazy ListView children. The layer can be outside
    // its visible viewport, so change the same persisted setting directly.
    await settings.setDesktopDockCollapsed(CanvasDockPanel.layer, true);
    await _shot(tester, root, '20_pc_layout_preview_both_sides_folded');
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, false);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.layer, false);
    await _settle(tester);
    final width = find.byKey(const ValueKey('pcPreviewToolColumnResize'));
    final height = find.byKey(const ValueKey('pcPreviewHeight-brush'));
    expect(width, findsOneWidget);
    expect(height, findsOneWidget);
    await tester.drag(width, const Offset(36, 0));
    await tester.drag(height, const Offset(0, 70));
    await _shot(tester, root, '21_pc_layout_preview_width_height_resized');
    await settings.moveDesktopDockPanel(
      CanvasDockPanel.canvasPreview, toRight: false,
    );
    await _shot(tester, root, '22_pc_layout_preview_moved_between_sides');
    await settings.setLeftHanded(true);
    await _shot(tester, root, '23_pc_layout_preview_left_handed');
  }, timeout: const Timeout(Duration(minutes: 9)));

  testWidgets('capture empty desktop dock left/right and recovery', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final docs = Directory.systemTemp.createTempSync('niarim_emptydock_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => docs.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      docs.deleteSync(recursive: true);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = (await tester.runAsync(buildAppProviders))!;
    final root = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: MultiProvider(providers: providers, child: const NiarimApp()),
    ));
    await _settle(tester);
    final context = tester.element(find.byType(MaterialApp).first);
    final ps = context.read<ProjectService>();
    final settings = context.read<SettingsService>();
    await settings.markFirstLaunchDone();
    await settings.setForcePcMode(true);
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush, CanvasDockPanel.colorPicker, CanvasDockPanel.layer,
    });
    final project = (await tester.runAsync(() => ps.createProject(
      name: '空ドック検証', fps: 12, durationSeconds: 1,
      backgroundColor: 0xFFB8CEDA, exportWidth: 320, exportHeight: 180,
    )))!;
    appRouter.go('/canvas/' + project.id);
    await _shot(tester, root, '30_canvas_before_move');
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, true);
    await settings.moveDesktopDockPanel(CanvasDockPanel.brush, toRight: true);
    await _shot(tester, root, '31_canvas_left_empty');
    expect(find.byKey(const ValueKey('desktopLeftDockScroll')), findsNothing);
    final toLeft = await tester.startGesture(tester.getCenter(
      find.byKey(const ValueKey('dockCollapsedDrag-brush'))));
    await toLeft.moveBy(const Offset(-60, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('desktopEmptyLeftDockDrop')), findsOneWidget);
    await _shot(tester, root, '32_canvas_left_dropzone');
    await toLeft.moveTo(tester.getCenter(
      find.byKey(const ValueKey('desktopEmptyLeftDockDrop'))));
    await tester.pump();
    await _shot(tester, root, '33_canvas_left_drop_hover');
    await toLeft.up();
    await _shot(tester, root, '34_canvas_left_restored');
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    await settings.moveDesktopDockPanel(CanvasDockPanel.colorPicker, toRight: false);
    await settings.moveDesktopDockPanel(CanvasDockPanel.layer, toRight: false);
    await _shot(tester, root, '35_canvas_right_empty');
    expect(find.byKey(const ValueKey('desktopRightDockScroll')), findsNothing);
    final toRight = await tester.startGesture(tester.getCenter(
      find.byKey(const ValueKey('dockCollapsedDrag-brush'))));
    await toRight.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('desktopEmptyRightDockDrop')), findsOneWidget);
    await _shot(tester, root, '36_canvas_right_dropzone');
    await toRight.moveTo(tester.getCenter(
      find.byKey(const ValueKey('desktopEmptyRightDockDrop'))));
    await tester.pump();
    await _shot(tester, root, '37_canvas_right_drop_hover');
    await toRight.up();
    await _shot(tester, root, '38_canvas_right_restored');
    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 11)));

  testWidgets('capture empty preview dock left/right and recovery', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final settings = SettingsService();
    await settings.init();
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush, CanvasDockPanel.colorPicker, CanvasDockPanel.layer,
    });
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, true);
    final root = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PcWorkspaceLayoutPreview(labelOf: (panel) => panel.name),
          ),
        ),
      ),
    ));
    await _shot(tester, root, '39_preview_before_move');
    await settings.moveDesktopDockPanel(CanvasDockPanel.brush, toRight: true);
    await _shot(tester, root, '40_preview_left_empty');
    expect(tester.getSize(find.byKey(const ValueKey('pcPreviewToolColumn'))).width, 0);
    final toLeft = await tester.startGesture(tester.getCenter(
      find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush'))));
    await toLeft.moveBy(const Offset(-60, 0));
    await tester.pump();
    await _shot(tester, root, '41_preview_left_dropzone');
    await toLeft.moveTo(tester.getCenter(
      find.byKey(const ValueKey('pcPreviewToolColumn'))));
    await tester.pump();
    await _shot(tester, root, '42_preview_left_drop_hover');
    await toLeft.up();
    await _shot(tester, root, '43_preview_left_restored');
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    await settings.moveDesktopDockPanel(CanvasDockPanel.colorPicker, toRight: false);
    await settings.moveDesktopDockPanel(CanvasDockPanel.layer, toRight: false);
    await _shot(tester, root, '44_preview_right_empty');
    expect(tester.getSize(find.byKey(const ValueKey('pcPreviewRightColumn'))).width, 0);
    final toRight = await tester.startGesture(tester.getCenter(
      find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush'))));
    await toRight.moveBy(const Offset(60, 0));
    await tester.pump();
    await _shot(tester, root, '45_preview_right_dropzone');
    await toRight.moveTo(tester.getCenter(
      find.byKey(const ValueKey('pcPreviewRightColumn'))));
    await tester.pump();
    await _shot(tester, root, '46_preview_right_drop_hover');
    await toRight.up();
    await _shot(tester, root, '47_preview_right_restored');
    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 9)));
}
