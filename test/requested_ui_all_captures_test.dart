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
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/widgets/labeled_slider.dart';
import 'package:niarim/screens/canvas/widgets/mesh_transform_panel.dart';
import 'package:niarim/screens/canvas/widgets/reference_window.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/settings/pc_workspace_layout_settings_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/filter_service.dart';
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
  testWidgets('Capture every requested post-fix real Flutter screen', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MultiProvider(providers: providers, child: const NiarimApp()),
      ),
    );
    final out = Directory('build/requested-ui-all-captures')
      ..createSync(recursive: true);
    final errors = <String>[];
    Future<void> settle() async {
      for (var round = 0; round < 9; round++) {
        await tester.pump(const Duration(milliseconds: 120));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 70)),
        );
      }
    }

    Future<void> shot(String name) async {
      await settle();
      final exception = tester.takeException();
      if (exception != null) errors.add('$name: $exception');
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final b = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return b!.buffer.asUint8List();
      });
      await tester.runAsync(
        () => File('${out.path}/$name.png').writeAsBytes(bytes!),
      );
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
    final transparent = (await tester.runAsync(
      () => ps.createProject(
        name: '透明背景テスト作品',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    final colored = (await tester.runAsync(
      () => ps.createProject(
        name: '色付き背景テスト作品',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFB8CEDA,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    await tester.runAsync(() => ps.toggleFavorite(transparent.id));
    await navigate('/home');
    await shot('01_project_favorite_bottom_left');
    await shot('02_thumbnail_transparent_clipping');

    await navigate('/project/${colored.id}');
    await shot('03_project_detail_loop_label');

    await navigate('/timeline/${colored.id}');
    await shot('04_timeline_preview_edges_without_duplicate_loop');

    // Portrait artwork is narrower than the preview viewport: the controls
    // must remain at the full viewport's extreme edges rather than moving
    // toward the center with the fitted artwork.
    final portrait = (await tester.runAsync(
      () => ps.createProject(
        name: '縦長プレビュー端配置テスト',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFB8CEDA,
        exportWidth: 180,
        exportHeight: 320,
      ),
    ))!;
    await navigate('/timeline/${portrait.id}');
    final viewport = tester.getRect(
      find.byKey(const Key('timelinePreviewArea')),
    );
    final frameCounter = tester.getRect(
      find.byKey(const Key('timelinePreviewFrameCount')),
    );
    final fullscreenButton = tester.getRect(
      find.byKey(const Key('timelinePreviewFullscreenButton')),
    );
    expect(
      (frameCounter.left - viewport.left).abs(),
      lessThan(1),
      reason: 'Counter must track the preview viewport, not artwork.',
    );
    expect((frameCounter.bottom - viewport.bottom).abs(), lessThan(1));
    expect(
      (fullscreenButton.right - viewport.right).abs(),
      lessThan(1),
      reason: 'Fullscreen control must track the preview viewport edge.',
    );
    expect((fullscreenButton.top - viewport.top).abs(), lessThan(1));
    await shot('04b_timeline_portrait_artwork_controls_at_viewport_edges');

    await navigate('/canvas/${colored.id}');
    await shot('05_canvas_timeline_button_alignment');
    final gear = find.byIcon(Icons.settings);
    if (gear.evaluate().isNotEmpty) {
      await tester.tap(gear.first);
      await settle();
      final l = AppLocalizations.of(
        tester.element(find.byType(Scaffold).last),
      )!;
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
      final l = AppLocalizations.of(
        tester.element(find.byType(Scaffold).last),
      )!;
      final filter = find.text(l.filterPanelTitle);
      if (filter.evaluate().isNotEmpty) {
        await tester.ensureVisible(filter.last);
        await tester.tap(filter.last);
        await settle();
        if (find.byType(FilterPanel).evaluate().isNotEmpty) {
          await shot('07_filter_preview_colored_background');
          final gallery = find.byKey(const ValueKey('filter-tile-grid'));
          expect(gallery, findsOneWidget);
          expect(
            tester.widget<GridView>(gallery).scrollDirection,
            Axis.vertical,
          );
          await shot('07a_vertical_filter_tile_gallery');
          final service = tester
              .element(find.byType(FilterPanel).first)
              .read<FilterService>();
          final candidates = service.filters.take(2).toList();
          expect(candidates, hasLength(2));
          await tester.tap(
            find.byKey(ValueKey('filter-card-${candidates.first.id}')),
          );
          await settle();
          expect(service.currentFilter?.id, candidates.first.id);
          expect(
            find.byKey(const ValueKey('filter-cancel-button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('filter-apply-button')),
            findsOneWidget,
          );
          expect(gallery, findsNothing);
          await shot('07b_filter_canvas_temporary_preview');
          await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
          await settle();
          expect(service.currentFilter, isNull);
          expect(gallery, findsOneWidget);
          await shot('07c_cancel_returns_to_filter_tiles');
          await tester.tap(
            find.byKey(ValueKey('filter-card-${candidates.last.id}')),
          );
          await settle();
          expect(service.currentFilter?.id, candidates.last.id);
          expect(gallery, findsNothing);
          await shot('07d_second_filter_preview_without_first_applied');
          await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
          await settle();
          expect(service.currentFilter, isNull);
          expect(gallery, findsOneWidget);
        } else {
          errors.add('07_filter_preview_colored_background: panel not found');
        }
      } else {
        errors.add('07_filter_preview_colored_background: menu not found');
      }
    } else {
      errors.add('07_filter_preview_colored_background: settings not found');
    }

    // The selection action bar uses the same borderless transparent
    // Material strategy as the mesh action bar. Capture it in the real
    // canvas to document both requested black-outline fixes.
    await navigate('/home');
    await navigate('/canvas/${colored.id}');
    await tester.tap(find.byIcon(Icons.highlight_alt).first);
    await settle();
    final selectionActionBar = find.byKey(
      const ValueKey('selection-tool-action-bar'),
    );
    expect(selectionActionBar, findsOneWidget);
    final selectionMaterial = tester.widget<Material>(selectionActionBar);
    expect(selectionMaterial.type, MaterialType.transparency);
    expect(selectionMaterial.elevation, 0);
    await shot('07e_selection_action_bar_without_black_frame');

    // Stacking example: draw visible pixels, bake one filter into the pixels
    // via Apply, then open another filter. These are genuine render captures,
    // not a mockup of the expected cumulative result.
    final filterDemo = (await tester.runAsync(
      () => ps.createProject(
        name: 'フィルター重ね掛け実画面テスト',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 256,
        exportHeight: 256,
      ),
    ))!;
    final demoScene = ps.scenesOf(filterDemo.id).first;
    final demoLayer = demoScene.frames.first.layers.first;
    final pixelArt = Uint8List(256 * 256 * 4);
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        final p = (y * 256 + x) * 4;
        pixelArt[p] = (x ~/ 16).isEven ? 230 : 35;
        pixelArt[p + 1] = (y ~/ 16).isEven ? 75 : 200;
        pixelArt[p + 2] = (x ~/ 24).isEven ? 45 : 215;
        pixelArt[p + 3] = 255;
      }
    }
    ps.replaceLayerPixels(
      projectId: filterDemo.id,
      sceneId: demoScene.id,
      frameIndex: 0,
      layerId: demoLayer.id,
      pixels: pixelArt,
    );
    await navigate('/home');
    await navigate('/canvas/${filterDemo.id}');
    final originalFrame = find.byType(Scaffold);
    await shot('07f_filter_sample_before_apply');
    await tester.tap(find.byIcon(Icons.settings).first);
    await settle();
    final filterL10n = AppLocalizations.of(tester.element(originalFrame.last))!;
    await tester.tap(find.text(filterL10n.filterPanelTitle).last);
    await settle();
    expect(find.byType(FilterPanel), findsOneWidget);
    final demoService = tester
        .element(find.byType(FilterPanel))
        .read<FilterService>();
    demoService.selectFilter('Filter0025'); // Invert colors.
    await settle();
    expect(demoService.currentFilter?.id, 'Filter0025');
    await shot('07g_first_filter_temporary_inversion_preview');
    expect(find.byKey(const ValueKey('tone-curve-editor-0')), findsNothing);
    expect(
      find.byKey(const ValueKey('tone-curve-channel-selector')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('filter-apply-button')));
    await settle();
    expect(find.byType(FilterPanel), findsOneWidget);
    expect(demoService.currentFilter, isNull);
    expect(find.byKey(const ValueKey('filter-tile-grid')), findsOneWidget);
    final canvasPixelsAfterApply = await tester.runAsync(() async {
      final tm = ps.tileManagerOf(filterDemo.id);
      final image = await tm.compositeLayerToImage(
        ps.tileKeyFor(filterDemo.id, demoScene.id, 0, demoLayer.id),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
    expect(
      canvasPixelsAfterApply!.sublist(0, 3),
      isNot(equals(pixelArt.sublist(0, 3))),
      reason: 'Apply must bake the first filter into the saved pixel buffer.',
    );
    await shot('07h_first_filter_applied_pixels');
    // Apply keeps the gallery open and the next effect uses reloaded pixels.
    demoService.selectFilter('Filter0001'); // Blur the inverted pixels.
    await settle();
    expect(demoService.currentFilter?.id, 'Filter0001');
    await shot('07i_second_filter_preview_after_first_applied');
    await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
    await settle();

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
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
      CanvasDockPanel.canvasPreview,
    });
    await navigate('/home');
    await navigate('/canvas/${colored.id}');
    expect(
      find.byType(MenuBar),
      findsOneWidget,
      reason: 'The desktop canvas must show File/Layer/View/Settings menus.',
    );
    expect(find.byKey(const Key('canvasTimelineModeButton')), findsOneWidget);
    // The panel body previously cast an 8dp solid-looking black shadow
    // inside each PC dock window. Docked panels fill their window without a
    // card; any card left inside must stay flat.
    expect(find.byType(BrushPanel), findsOneWidget);
    expect(find.byType(ColorPickerPanel), findsOneWidget);
    for (final panel in [BrushPanel, ColorPickerPanel]) {
      for (final card
          in find
              .descendant(of: find.byType(panel), matching: find.byType(Card))
              .evaluate()) {
        expect((card.widget as Card).elevation ?? 0, 0);
      }
    }
    await shot('10a_desktop_docks_without_black_outlines');
    await shot('10_desktop_multiple_dock_windows');

    // Shared picker: verify the exact controls rendered in PC/DeX and used
    // by the canvas and other dialogs, not an illustration of the design.
    expect(
      find.byKey(const ValueKey('pc-color-picker-current-chip')),
      findsOneWidget,
    );
    final colorPanel = find.byType(ColorPickerPanel);
    expect(
      find.descendant(of: colorPanel, matching: find.text('HSV')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: colorPanel, matching: find.text('RGB')),
      findsOneWidget,
    );
    final hueSlider = find.ancestor(
      of: find.descendant(of: colorPanel, matching: find.text('H')),
      matching: find.byType(LabeledSlider),
    );
    expect(hueSlider, findsOneWidget);
    final beforeHue = tester.widget<LabeledSlider>(hueSlider).value;
    await tester.ensureVisible(hueSlider);
    await settle();
    await shot('10b_color_picker_hsv_sliders_and_current_color_chip');
    await tester.tap(
      find.descendant(
        of: hueSlider,
        matching: find.byIcon(Icons.add_circle_outline),
      ),
    );
    await settle();
    final afterHue = tester.widget<LabeledSlider>(hueSlider).value;
    expect(afterHue, beforeHue + 1, reason: 'HSV stepper must add 1');
    await shot('10c_color_picker_hsv_after_plus_one');
    final rgbPill = find.byKey(const ValueKey('color-slider-mode-rgb'));
    final hsvPill = find.byKey(const ValueKey('color-slider-mode-hsv'));
    expect(rgbPill, findsOneWidget);
    expect(hsvPill, findsOneWidget);
    await tester.ensureVisible(rgbPill);
    await tester.tap(rgbPill);
    await settle();
    expect(hueSlider, findsNothing);
    final rgbSlider = find.ancestor(
      of: find.descendant(of: colorPanel, matching: find.text('R')),
      matching: find.byType(LabeledSlider),
    );
    expect(rgbSlider, findsOneWidget);
    await tester.ensureVisible(rgbSlider);
    await settle();
    await shot('10d_color_picker_rgb_sliders');
    await tester.ensureVisible(hsvPill);
    await tester.tap(hsvPill);
    await settle();
    expect(hueSlider, findsOneWidget);

    final resize = find.byKey(const ValueKey('dockResize-canvasPreview'));
    if (resize.evaluate().isNotEmpty) {
      await tester.drag(resize.first, const Offset(0, 80));
      await settle();
      await shot('11_desktop_window_resized');
      final widthHandle = find.byKey(const ValueKey('dockColumnResize-right'));
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
      await tester.pump();
      await settle();
      await shot('12_desktop_window_visibility_menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      // Reposition a real open navigator window and capture the new dock.
      await settings.moveDesktopDockPanel(
        CanvasDockPanel.canvasPreview,
        toRight: false,
      );
      await settle();
      final moved = find.byKey(const ValueKey('dockDrag-canvasPreview'));
      if (moved.evaluate().isNotEmpty) {
        expect(
          tester.getCenter(moved).dx,
          lessThan(tester.getCenter(find.byType(ColorPickerPanel)).dx),
        );
        await shot('12b_desktop_navigator_moved_to_left_dock');
      } else {
        // Keep collecting the independent requested captures. Preserve a
        // failure marker instead of claiming this dock move was verified.
        errors.add('12b_desktop_navigator_moved_to_left_dock: grip missing');
      }
    } else {
      errors.add('12_desktop_window_visibility_menu: menu not found');
    }

    await navigate('/settings/workspace');
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold).last))!;
    final pcLayout = find.text(l.workspacePcLayoutButton);
    await tester.scrollUntilVisible(
      pcLayout,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    if (pcLayout.evaluate().isNotEmpty) {
      await tester.ensureVisible(pcLayout.last);
      await tester.tap(pcLayout.last);
      await settle();
      expect(find.byType(PcWorkspaceLayoutSettingsScreen), findsOneWidget);
      expect(
        find.byKey(const Key('pcWorkspaceInteractivePreview')),
        findsOneWidget,
      );
      expect(
        find.byType(Slider),
        findsNothing,
        reason: 'PC layout must be edited directly in the workspace preview.',
      );
      await shot('13_global_pc_layout_settings');
      final brushWidthBefore = settings.desktopDockWidth(
        CanvasDockPanel.brush,
        right: false,
      );
      final brushWidthGrip = find.byKey(
        const ValueKey('pcPreviewToolColumnResize'),
      );
      if (brushWidthGrip.evaluate().isNotEmpty) {
        await tester.drag(brushWidthGrip, const Offset(32, 0));
        await settle();
        expect(
          settings.desktopDockWidth(CanvasDockPanel.brush, right: false),
          greaterThan(brushWidthBefore),
          reason: 'The preview grip must save real desktop dock dimensions.',
        );
        await shot('14_global_panel_resized_by_preview_drag');
      } else {
        errors.add('14_global_panel_resized_by_preview_drag: grip missing');
      }
    } else {
      errors.add('13_global_pc_layout_settings: navigation button missing');
    }

    // Capture every popup-appearance fix in the *real* Flutter canvas.
    // Desktop panels use the same widgets as the smartphone popups, so these
    // captures prove the exact revised Card/Material styling is rendered.
    final affectedDocks = <CanvasDockPanel>[
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.tone,
      CanvasDockPanel.stamp,
      CanvasDockPanel.penSubTool,
      CanvasDockPanel.onionSkin,
      CanvasDockPanel.filter,
      CanvasDockPanel.quickTool,
      CanvasDockPanel.ruler,
    ];
    for (final panel in affectedDocks) {
      await navigate('/home');
      await settings.setDefaultDockedPanels({panel});
      await settings.setDesktopDockHeight(panel, 520);
      await navigate('/canvas/${colored.id}');
      final grip = find.byKey(ValueKey('dockDrag-${panel.name}'));
      if (grip.evaluate().isNotEmpty) {
        await shot('popup_fix_${panel.name}');
      } else {
        errors.add('popup_fix_${panel.name}: grip missing');
      }
    }

    // The global popup menu theme was also changed to flat/no border.
    final dockMenu = find.byKey(const Key('desktopWindowVisibilityMenu'));
    expect(dockMenu, findsOneWidget);
    await tester.tap(dockMenu);
    await shot('popup_fix_global_menu');

    // Mesh transform and the floating reference window are not configurable
    // dock panels; open them through the same settings/edit menu as users do.
    await navigate('/home');
    await settings.setDefaultDockedPanels(<CanvasDockPanel>{});
    await navigate('/canvas/${colored.id}');
    final topSettings = find.byIcon(Icons.settings).first;
    await tester.tap(topSettings);
    await settle();
    final canvasL10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).last),
    )!;
    final meshEntry = find.text(canvasL10n.canvasEditMenuMeshTransform);
    await tester.ensureVisible(meshEntry.last);
    await tester.tap(meshEntry.last);
    await settle();
    expect(find.byType(MeshTransformPanel), findsOneWidget);
    // Regressions: the bottom floating mesh action bar must not draw
    // a black shadow or an opaque enclosing rectangle.
    final meshBar = find.byKey(const ValueKey('mesh-transform-action-bar'));
    expect(meshBar, findsOneWidget);
    final meshMaterial = tester.widget<Material>(meshBar);
    expect(meshMaterial.type, MaterialType.transparency);
    expect(meshMaterial.elevation, 0);
    await shot('popup_fix_mesh_transform');

    await navigate('/home');
    await navigate('/canvas/${colored.id}');
    await tester.tap(find.byIcon(Icons.settings).first);
    await settle();
    final referenceEntry = find.text(
      AppLocalizations.of(tester.element(find.byType(Scaffold).last))!
          .canvasEditMenuReferenceWindow,
    );
    await tester.ensureVisible(referenceEntry.last);
    await tester.tap(referenceEntry.last);
    await settle();
    expect(find.byType(ReferenceWindow), findsOneWidget);
    await shot('popup_fix_reference_window');

    // Inject real raster content. Hide the layer on the canvas while its
    // private thumbnail and zoomable preview must still show the artwork.
    final proofScene = ps.scenesOf(colored.id).first;
    final proofLayer = proofScene.frames.first.layers.first;
    final proofPixels = Uint8List(320 * 180 * 4);
    for (var y = 25; y < 155; y++) {
      for (var x = 35; x < 285; x++) {
        final i = (y * 320 + x) * 4;
        proofPixels[i] = 225;
        proofPixels[i + 1] = x.isEven ? 40 : 90;
        proofPixels[i + 2] = 50;
        proofPixels[i + 3] = 255;
      }
    }
    ps.replaceLayerPixels(
      projectId: colored.id,
      sceneId: proofScene.id,
      frameIndex: 0,
      layerId: proofLayer.id,
      pixels: proofPixels,
    );
    ps.updateLayer(
      projectId: colored.id,
      sceneId: proofScene.id,
      frameIndex: 0,
      layer: proofLayer.copyWith(isVisible: false),
    );
    await settings.setDefaultDockedPanels({CanvasDockPanel.layer});
    await navigate('/home');
    await navigate('/canvas/${colored.id}');
    expect(find.byType(LayerPanel), findsOneWidget);
    final layerThumbnail = find.byKey(
      ValueKey('layer-preview-tap-${proofLayer.id}'),
    );
    expect(layerThumbnail, findsOneWidget);
    await shot('15_hidden_layer_thumbnail_keeps_artwork');
    await tester.tap(layerThumbnail);
    await settle();
    final fullPreview = find.byKey(const ValueKey('layer-preview-interactive'));
    expect(fullPreview, findsOneWidget);
    expect(tester.widget<InteractiveViewer>(fullPreview).scaleEnabled, isTrue);
    await shot('16_hidden_layer_fullscreen_preview');
    final center = tester.getCenter(fullPreview);
    final left = await tester.startGesture(center + const Offset(-60, 0));
    final right = await tester.startGesture(center + const Offset(60, 0));
    await left.moveBy(const Offset(-40, 0));
    await right.moveBy(const Offset(40, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await settle();
    await shot('17_hidden_layer_preview_pinch_zoom');
    await tester.drag(fullPreview, const Offset(45, 25));
    await settle();
    await shot('18_hidden_layer_preview_drag_pan');
    await tester.tap(find.byKey(const ValueKey('layer-preview-close')));
    await settle();
    expect(fullPreview, findsNothing);

    // Free positioning is removed: desktop tools share the regular docks.
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
    });
    await navigate('/home');
    await navigate('/canvas/${colored.id}');
    expect(find.byKey(const ValueKey('dockTarget-brush')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dockTarget-colorPicker')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('freeDockWindow-brush')), findsNothing);
    await shot('19_pc_dex_compact_dock_panels');
    await tester.tap(find.byKey(const ValueKey('dockMenu-brush')));
    await settle();
    expect(find.text('自由配置'), findsNothing);
    await shot('20_pc_dex_dock_menu_without_free_position');

    await tester.runAsync(
      () =>
          File('${out.path}/capture_status.txt')
              .writeAsString(errors.isEmpty ? 'PASS' : errors.join('\n')),
    );
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 12)));
}
