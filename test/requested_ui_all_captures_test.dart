import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/color_adjust_sheet.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/settings/pc_workspace_layout_settings_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/first_use_tooltips.dart';

class _NoPicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Capture every requested post-fix real Flutter screen', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    FilePicker.platform = _NoPicker();
    final tempDir = Directory.systemTemp.createTempSync('niarim_requested_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (_) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = (await tester.runAsync(buildAppProviders))!;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key,
      child: MultiProvider(providers: providers, child: const NiarimApp())));
    final out = Directory('build/requested-ui-all-captures')..createSync(recursive:true);
    final errors = <String>[];
    Future<void> settle() async {
      for (var round = 0; round < 9; round++) {
        await tester.pump(const Duration(milliseconds: 120));
        await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 70)));
      }
    }
    Future<void> shot(String name) async {
      await settle();
      final exception = tester.takeException();
      if (exception != null) errors.add('$name: $exception');
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final b = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return b!.buffer.asUint8List();
      });
      await tester.runAsync(() =>
        File('${out.path}/$name.png').writeAsBytes(bytes!));
    }
    Future<void> navigate(String route) async {
      appRouter.go(route);
      await settle();
    }
    await settle();
    final context = tester.element(find.byType(MaterialApp).first);
    final ps = context.read<ProjectService>();
    final settings = context.read<SettingsService>();
    await settings.markFirstLaunchDone();
    final transparent = (await tester.runAsync(() => ps.createProject(
      name: '透明背景テスト作品',
      fps: 12, durationSeconds: 1, backgroundColor: 0x00000000,
      exportWidth: 320, exportHeight: 180,
    )))!;
    final colored = (await tester.runAsync(() => ps.createProject(
      name: '色付き背景テスト作品',
      fps: 12, durationSeconds: 1, backgroundColor: 0xFFB8CEDA,
      exportWidth: 320, exportHeight: 180,
    )))!;
    await tester.runAsync(() => ps.toggleFavorite(transparent.id));
    await navigate('/home');
    await shot('01_project_favorite_bottom_left');
    await shot('02_thumbnail_transparent_clipping');

    await navigate('/project/${colored.id}');
    await shot('03_project_detail_loop_label');

    await navigate('/timeline/${colored.id}');
    await shot('04_timeline_preview_edges_without_duplicate_loop');

    await navigate('/canvas/${colored.id}');
    await shot('05_canvas_timeline_button_alignment');
    final gear = find.byIcon(Icons.settings);
    if (gear.evaluate().isNotEmpty) {
      await tester.tap(gear.first);
      await settle();
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold).last))!;
      final adjust = find.text(l.canvasColorAdjustMenuTitle);
      if (adjust.evaluate().isNotEmpty) {
        await tester.ensureVisible(adjust.last);
        await tester.tap(adjust.last);
        await settle();
        expect(find.byType(ColorAdjustSheet), findsWidgets);
        await shot('06_color_adjust_colored_background');
      } else {
        errors.add('06_color_adjust_colored_background: menu not found');
      }
    }
    // Rebuild the route, since an existing adjustment popup otherwise
    // remains on the same Navigator when going to the same URI.
    await navigate('/home');
    await navigate('/canvas/${colored.id}');
    if (find.byIcon(Icons.settings).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.settings).first);
      await settle();
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold).last))!;
      final filter = find.text(l.filterPanelTitle);
      if (filter.evaluate().isNotEmpty) {
        await tester.ensureVisible(filter.last);
        await tester.tap(filter.last);
        await settle();
        if (find.byType(FilterPanel).evaluate().isNotEmpty) {
          await shot('07_filter_preview_colored_background');
        } else {
          errors.add('07_filter_preview_colored_background: panel not found');
        }
      } else {
        errors.add('07_filter_preview_colored_background: menu not found');
      }
    } else {
      errors.add('07_filter_preview_colored_background: settings not found');
    }

    await navigate('/settings/workspace');
    await settings.setToolbarSizeLevel(1);
    await shot('08_toolbar_size_1_preview');
    await settings.setToolbarSizeLevel(5);
    await shot('09_toolbar_size_5_preview');

    // Desktop (1500 logical pixels): all docks use a global shared layout.
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    await settings.setForcePcMode(true);
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush, CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer, CanvasDockPanel.canvasPreview,
    });
    await navigate('/home');
    await navigate('/canvas/${colored.id}');
    await shot('10_desktop_multiple_dock_windows');
    final resize = find.byKey(const ValueKey('dockResize-canvasPreview'));
    if (resize.evaluate().isNotEmpty) {
      await tester.drag(resize.first, const Offset(0, 80));
      await settle();
      await shot('11_desktop_window_resized');
      final widthHandle = find.byKey(const ValueKey('dockWidthResize-canvasPreview'));
      expect(widthHandle, findsOneWidget);
      await tester.drag(widthHandle.first, const Offset(-35, 0));
      await settle();
      await shot('11b_desktop_window_width_resized');
    } else {
      errors.add('11_desktop_window_resized: resize handle not found');
    }
    final menu = find.byKey(const Key('desktopWindowVisibilityMenu'));
    if (menu.evaluate().isNotEmpty) {
      await tester.tap(menu.first);
      await shot('12_desktop_window_visibility_menu');
      // Reposition a real open navigator window and capture the new dock.
      await tester.tapAt(const Offset(760, 550));
      await settle();
      await settings.moveDesktopDockPanel(
        CanvasDockPanel.canvasPreview, toRight: false);
      await settle();
      final moved = find.byKey(const ValueKey('dockDrag-canvasPreview'));
      expect(moved, findsOneWidget);
      await shot('12b_desktop_navigator_moved_to_left_dock');
    } else {
      errors.add('12_desktop_window_visibility_menu: menu not found');
    }

    await navigate('/settings/workspace');
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).last))!;
    final pcLayout = find.text(l.workspacePcLayoutButton);
    await tester.scrollUntilVisible(pcLayout, 220,
      scrollable: find.byType(Scrollable).first);
    if (pcLayout.evaluate().isNotEmpty) {
      await tester.ensureVisible(pcLayout.last);
      await tester.tap(pcLayout.last);
      await settle();
      expect(find.byType(PcWorkspaceLayoutSettingsScreen), findsOneWidget);
      await shot('13_global_pc_layout_settings');
      final widthSlider = find.byKey(const ValueKey('workspaceDockWidth-canvasPreview'));
      await tester.scrollUntilVisible(
        widthSlider, 220, scrollable: find.byType(Scrollable).first);
      await shot('14_global_panel_width_controls');
    } else {
      errors.add('13_global_pc_layout_settings: navigation button missing');
    }

    await tester.runAsync(() => File('${out.path}/capture_status.txt')
      .writeAsString(errors.isEmpty ? 'PASS' : errors.join('\n')));
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 12)));
}
