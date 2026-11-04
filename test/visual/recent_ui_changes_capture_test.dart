import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
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
      File('${_out.path}/$name.png').writeAsBytes(bytes!));
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
        name: 'タイル表示テスト ${i + 1}',
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
    // このブランチの表示サイズのメニューは、ボタンのアイコンが今の表示を表す。
    final modeButton = find.byType(ProjectViewModeMenu);
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
    appRouter.go('/canvas/${project.id}');
    await _shot(tester, root, '10_pc_canvas_docks_expanded');
    // このブランチのPC/DeXモードの作業画面の窓（PcDockColumn）。窓の見出しの
    // 矢印でたたみ、もう一度押すと広げる。たたんだことは設定に残る。
    final brushFold = find.byKey(const ValueKey('pcPaneCollapse.brush'));
    final layerFold = find.byKey(const ValueKey('pcPaneCollapse.layer'));
    expect(brushFold, findsOneWidget);
    expect(layerFold, findsOneWidget);
    await tester.tap(brushFold);
    await _shot(tester, root, '11_pc_canvas_left_brush_folded');
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    await tester.tap(layerFold);
    await _shot(tester, root, '12_pc_canvas_both_sides_partially_folded');
    await tester.tap(find.byKey(const ValueKey('pcPaneCollapse.brush')));
    await _shot(tester, root, '13_pc_canvas_left_brush_expanded');
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isFalse);
    await tester.tap(find.byKey(const ValueKey('pcPaneCollapse.layer')));
    await _settle(tester);
    final height = find.byKey(const ValueKey('pcPaneResize.canvasPreview'));
    final width = find.byKey(const ValueKey('pcRightDockSplitter'));
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
    await settings.setLeftHanded(true);
    await _shot(tester, root, '17_pc_canvas_left_handed_layout');
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
    final width = find.byKey(const ValueKey('pcPreviewWidth-brush'));
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
}
