import 'dart:io';
import 'dart:math' as math;
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
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/color_adjust_sheet.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/hsv_color_wheel.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/pen_sub_tool_panel.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/tone_panel.dart';
import 'package:niarim/screens/canvas/widgets/stamp_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/first_use_tooltips.dart';
import '../helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Changed color controls and immersive filters render from the app',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
      });
      final temp = Directory.systemTemp.createTempSync('niarim_scope_capture_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => temp.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);
      appRouter.go('/');
      final providers = (await tester.runAsync(buildAppProviders))!;
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      final out = Directory('build/modified-canvas-scope')
        ..createSync(recursive: true);

      Future<void> settle() async {
        for (var i = 0; i < 9; i++) {
          await tester.pump(const Duration(milliseconds: 140));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 65)),
          );
        }
      }

      Future<void> shot(String name) async {
        await settle();
        expect(tester.takeException(), isNull, reason: name);
        final boundary =
            capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final encoded = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          image.dispose();
          return encoded!.buffer.asUint8List();
        });
        await tester.runAsync(
          () => File(out.path + '/' + name + '.png').writeAsBytes(bytes!),
        );
      }

      Future<void> navigate(String route) async {
        appRouter.go(route);
        await settle();
      }

      final context = tester.element(find.byType(MaterialApp).first);
      final projects = context.read<ProjectService>();
      final settings = context.read<SettingsService>();
      await settings.markFirstLaunchDone();
      final demo = (await tester.runAsync(
        () => projects.createProject(
          name: '色調・描画プレビュー検証作品',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 180,
        ),
      ))!;
      final scene = projects.scenesOf(demo.id).first;
      final layer = scene.frames.first.layers.first;
      final art = Uint8List(320 * 180 * 4);
      for (var y = 0; y < 180; y++) {
        for (var x = 0; x < 320; x++) {
          final i = (y * 320 + x) * 4;
          final ellipse =
              ((x - 160) * (x - 160) / 10000.0) +
                  ((y - 90) * (y - 90) / 4200.0) <
              1.0;
          art[i] = ellipse
              ? 220
              : (x ~/ 14).isEven
              ? 50
              : 110;
          art[i + 1] = ellipse
              ? (y ~/ 8).isEven
                    ? 70
                    : 100
              : 145;
          art[i + 2] = ellipse
              ? 115
              : (y ~/ 13).isEven
              ? 230
              : 180;
          art[i + 3] = 255;
        }
      }
      projects.replaceLayerPixels(
        projectId: demo.id,
        sceneId: scene.id,
        frameIndex: 0,
        layerId: layer.id,
        pixels: art,
      );

      // Controls live in the unused corners of the wheel square. A touch
      // target must never intersect the visible circular hue ring.
      void assertColorWheelControlsClear() {
        final wheelFinder = find.byType(HsvColorWheel);
        expect(wheelFinder, findsOneWidget);
        final wheel = tester.widget<HsvColorWheel>(wheelFinder);
        final bounds = tester.getRect(wheelFinder);
        final center = Offset(bounds.center.dx, bounds.top + wheel.size / 2);
        for (final key in [
          'color-picker-eyedropper',
          'color-picker-transparent-toggle',
          'color-slider-mode-hsv',
          'color-slider-mode-rgb',
        ]) {
          final target = find.byKey(ValueKey(key));
          if (target.evaluate().isEmpty) continue;
          final rect = tester.getRect(target);
          final nearest = Offset(
            math.max(rect.left, math.min(center.dx, rect.right)),
            math.max(rect.top, math.min(center.dy, rect.bottom)),
          );
          expect(
            (nearest - center).distance,
            greaterThanOrEqualTo(wheel.size / 2 - 2),
            reason: '$key must not overlap the circular hue ring',
          );
        }
      }

      await settings.setForcePcMode(true);
      await settings.setDefaultDockedPanels({CanvasDockPanel.colorPicker});
      await navigate('/home');
      await navigate('/canvas/' + demo.id);
      expect(find.byType(ColorPickerPanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey('color-slider-mode-hsv')),
        findsOneWidget,
      );
      assertColorWheelControlsClear();
      await shot('01_pc_large_color_wheel_hsv_edge_controls');
      await tester.tap(find.byKey(const ValueKey('color-slider-mode-rgb')));
      await shot('02_pc_large_color_wheel_rgb_edge_controls');

      // Capture every tab of the shared two-row subtool chooser.
      await settings.setDefaultDockedPanels({CanvasDockPanel.penSubTool});
      await navigate('/home');
      await navigate('/canvas/' + demo.id);
      expect(find.byType(PenSubToolPanel), findsOneWidget);
      await shot('02a_pc_pen_subtool_brush_tab_waves');
      final subtool = find.byType(PenSubToolPanel);
      await tester.tap(
        find.descendant(of: subtool, matching: find.text('トーン')).first,
      );
      await shot('02b_pc_pen_subtool_tone_tab_waves');
      await tester.tap(
        find.descendant(of: subtool, matching: find.text('スタンプ')).first,
      );
      await shot('02c_pc_pen_subtool_stamp_tab_waves');

      // Real desktop tool management panels: two-row names/waves and the
      // favorite / overflow / drag controls at the right of every row.
      for (final caseItem in [
        (
          panel: CanvasDockPanel.brush,
          file: '11_pc_brush_management_all_controls',
        ),
        (
          panel: CanvasDockPanel.tone,
          file: '12_pc_tone_management_all_controls',
        ),
        (
          panel: CanvasDockPanel.stamp,
          file: '13_pc_stamp_management_all_controls',
        ),
      ]) {
        await settings.setDefaultDockedPanels({caseItem.panel});
        await settings.setDesktopDockHeight(caseItem.panel, 620);
        await navigate('/home');
        await navigate('/canvas/' + demo.id);
        final managed = switch (caseItem.panel) {
          CanvasDockPanel.brush => find.byType(BrushPanel),
          CanvasDockPanel.tone => find.byType(TonePanel),
          _ => find.byType(StampPanel),
        };
        expect(
          managed,
          findsOneWidget,
          reason: 'Management palette must be real production UI',
        );
        await shot(caseItem.file);
      }

      // The mini preview of an individual raster layer opens an actual
      // fullscreen layer-only viewer, with pan/zoom and close controls.
      await settings.setDefaultDockedPanels({CanvasDockPanel.layer});
      await settings.setDesktopDockHeight(CanvasDockPanel.layer, 600);
      await navigate('/home');
      await navigate('/canvas/' + demo.id);
      expect(find.byType(LayerPanel), findsOneWidget);
      final thumb = find.byKey(ValueKey('layer-preview-tap-' + layer.id));
      expect(thumb, findsOneWidget);
      await shot('14_pc_layer_palette_thumbnail');
      await tester.tap(thumb);
      await settle();
      expect(
        find.byKey(const ValueKey('layer-preview-interactive')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('layer-preview-close')), findsOneWidget);
      await shot('15_pc_layer_only_fullscreen_preview');
      await tester.tap(find.byKey(const ValueKey('layer-preview-close')));
      await settle();
      await shot('16_pc_layer_palette_after_preview');

      await settings.setDefaultDockedPanels({CanvasDockPanel.filter});
      await navigate('/home');
      await navigate('/canvas/' + demo.id);
      expect(find.byType(FilterPanel), findsOneWidget);
      await shot('03_pc_filter_gallery_before_editing');
      final filters = tester
          .element(find.byType(FilterPanel))
          .read<FilterService>();
      filters.selectFilter('Filter0025');
      await settle();
      expect(find.byType(FilterPanel), findsOneWidget);
      expect(find.byType(MenuBar), findsNothing);
      expect(find.byType(ToolbarWidget), findsNothing);
      expect(find.byKey(const ValueKey('filter-bottom-bar')), findsOneWidget);
      await shot('04_pc_filter_immersive_live_preview');
      await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
      await settle();
      expect(find.byType(MenuBar), findsOneWidget);
      await shot('05_pc_filter_returns_to_workspace');
      // Multiple distinct filter families use the identical immersive
      // editing chrome and restoration behavior; catalog already shows all
      // built-in and custom filter tiles.
      for (final caseItem in [
        (id: 'Filter0001', label: '17_pc_gaussian_blur_immersive'),
        (id: 'Filter0003', label: '18_pc_anime_effect_immersive'),
        (id: 'Filter0004', label: '19_pc_tone_curve_immersive'),
      ]) {
        filters.selectFilter(caseItem.id);
        await settle();
        expect(find.byKey(const ValueKey('filter-bottom-bar')), findsOneWidget);
        expect(find.byType(MenuBar), findsNothing);
        await shot(caseItem.label);
        await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
        await settle();
        expect(find.byType(MenuBar), findsOneWidget);
      }

      await settings.setDefaultDockedPanels({CanvasDockPanel.colorAdjust});
      await navigate('/home');
      await navigate('/canvas/' + demo.id);
      expect(find.byType(ColorAdjustSheet), findsOneWidget);
      expect(find.byType(MenuBar), findsNothing);
      expect(find.byType(ToolbarWidget), findsNothing);
      expect(
        find.byKey(const ValueKey('color-adjust-bottom-bar')),
        findsOneWidget,
      );
      await shot('06_pc_color_adjust_immersive_canvas');
      final sliders = find.descendant(
        of: find.byType(ColorAdjustSheet),
        matching: find.byType(Slider),
      );
      if (sliders.evaluate().isNotEmpty) {
        await tester.drag(sliders.first, const Offset(65, 0));
        await shot('07_pc_color_adjust_live_change');
      }

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await settings.setForcePcMode(false);
      await settings.setDefaultDockedPanels(<CanvasDockPanel>{});
      await navigate('/home');
      await navigate('/canvas/' + demo.id);
      final swatch = find.byKey(const ValueKey('canvasColorSwatch'));
      expect(swatch, findsOneWidget);
      await tester.tap(swatch);
      await settle();
      expect(find.byType(ColorPickerPanel), findsOneWidget);
      assertColorWheelControlsClear();
      await shot('08_mobile_color_wheel_hsv_edge_controls');
      await tester.tap(find.byKey(const ValueKey('color-slider-mode-rgb')));
      await shot('09_mobile_color_wheel_rgb_edge_controls');
      // The same preset layout is used in the phone's quick pen tool.
      await navigate('/home');
      await navigate('/canvas/' + demo.id);
      final quickPanel = find.byType(PenSubToolPanel);
      if (quickPanel.evaluate().isNotEmpty) {
        await shot('20_phone_pen_subtool_stroke_wave');
      }

      await navigate('/home');
      await navigate('/canvas/' + demo.id);
      await tester.tap(find.byIcon(Icons.settings).first);
      await settle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).last),
      )!;
      await tester.tap(find.text(l10n.filterPanelTitle).last);
      await settle();
      expect(find.byType(FilterPanel), findsOneWidget);
      final mobileFilter = tester
          .element(find.byType(FilterPanel))
          .read<FilterService>();
      mobileFilter.selectFilter('Filter0025');
      await settle();
      expect(find.byType(ToolbarWidget), findsNothing);
      expect(find.byKey(const ValueKey('filter-bottom-bar')), findsOneWidget);
      await shot('10_mobile_filter_immersive_live_preview');
    },
  );
}
