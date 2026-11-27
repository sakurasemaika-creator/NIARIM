import 'dart:io';
import 'dart:math' as math;
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
import 'package:niarim/screens/canvas/widgets/mesh_transform_panel.dart';
import 'package:niarim/screens/canvas/widgets/pen_sub_tool_panel.dart';
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
          () => File('${out.path}/$name.png').writeAsBytes(bytes!),
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
        final ring = find.descendant(
          of: wheelFinder,
          matching: find.byKey(const ValueKey('color-picker-hue-ring')),
        );
        final bounds = tester.getRect(ring);
        final center = bounds.center;
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
            greaterThanOrEqualTo(bounds.width / 2 - 0.5),
            reason: '$key must not overlap the circular hue ring',
          );
        }
      }

      await settings.setForcePcMode(true);
      await settings.setDefaultDockedPanels({CanvasDockPanel.colorPicker});
      await navigate('/home');
      await navigate('/canvas/${demo.id}');
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
      await navigate('/canvas/${demo.id}');
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

      await settings.setDefaultDockedPanels({CanvasDockPanel.filter});
      await navigate('/home');
      await navigate('/canvas/${demo.id}');
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
      expect(
        find.byKey(const ValueKey('filter-focus-menu-actions')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('focus-mode-menu-surface')),
          matching: find.byKey(const ValueKey('focus-mode-menu-title')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('filter-cancel-button')));
      await settle();
      expect(find.byType(MenuBar), findsNothing);
      expect(find.byType(ToolbarWidget), findsOneWidget);
      await shot('05_pc_filter_returns_to_workspace');

      await settings.setDefaultDockedPanels({CanvasDockPanel.colorAdjust});
      await navigate('/home');
      await navigate('/canvas/${demo.id}');
      expect(find.byType(ColorAdjustSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('color-adjust-focus-menu')),
        findsOneWidget,
      );
      expect(find.byType(MenuBar), findsNothing);
      expect(find.byType(ToolbarWidget), findsNothing);
      expect(
        find.byKey(const ValueKey('color-adjust-bottom-bar')),
        findsOneWidget,
      );
      await shot('06_pc_color_adjust_immersive_canvas');

      final focusSurface = find.byKey(
        const ValueKey('focus-mode-menu-surface'),
      );
      final focusSurfaceBeforeResize = tester.getRect(focusSurface);
      final resizeHandle = find.byKey(
        const ValueKey('focus-mode-menu-resize-handle'),
      );
      final focusClose = find.descendant(
        of: focusSurface,
        matching: find.byIcon(Icons.close),
      ).first;
      expect(find.byKey(const ValueKey('color-adjust-save-menu')), findsOneWidget);
      expect(
        find.text(
          AppLocalizations.of(tester.element(find.byType(Scaffold).last))!
              .canvasColorAdjustTitle,
        ),
        findsOneWidget,
      );
      expect(tester.getRect(resizeHandle).left,
          closeTo(focusSurfaceBeforeResize.left, 0.1));
      expect(tester.getRect(focusClose).right,
          closeTo(focusSurfaceBeforeResize.right, 0.1));
      await tester.drag(resizeHandle, const Offset(-28, -20));
      await tester.pumpAndSettle();
      final focusSurfaceResized = tester.getRect(focusSurface);
      expect(focusSurfaceResized.width,
          closeTo(focusSurfaceBeforeResize.width + 28, 0.1));
      expect(focusSurfaceResized.height,
          closeTo(focusSurfaceBeforeResize.height + 20, 0.1));
      expect(focusSurfaceResized.right,
          closeTo(focusSurfaceBeforeResize.right, 0.1));
      expect(focusSurfaceResized.bottom,
          closeTo(focusSurfaceBeforeResize.bottom, 0.1));
      await shot('06a_pc_color_adjust_menu_resized');

      final sliders = find.descendant(
        of: find.byType(ColorAdjustSheet),
        matching: find.byType(Slider),
      );
      expect(sliders, findsNWidgets(3));
      await tester.drag(sliders.first, const Offset(65, 0));
      await shot('07_pc_color_adjust_live_change');
      final adjustedSaturation = tester.widget<Slider>(sliders.first).value;

      final colorFocusToggle = find.byKey(
        const ValueKey('focus-mode-menu-toggle'),
      );
      await tester.tap(colorFocusToggle);
      await tester.pumpAndSettle();
      expect(find.byType(ColorAdjustSheet), findsNothing);
      await shot('08_pc_color_adjust_menu_minimized');

      await tester.tap(colorFocusToggle);
      await tester.pumpAndSettle();
      expect(find.byType(ColorAdjustSheet), findsOneWidget);
      expect(
        tester.widget<Slider>(sliders.first).value,
        closeTo(adjustedSaturation, 0.01),
        reason: 'minimizing the common menu must retain color-adjust edits',
      );
      await tester.drag(
        find.byKey(const ValueKey('focus-mode-menu-drag-handle')),
        const Offset(34, -42),
      );
      await shot('09_pc_color_adjust_menu_moved');

      await settings.setDefaultDockedPanels(<CanvasDockPanel>{});
      await navigate('/home');
      await navigate('/canvas/${demo.id}');
      await tester.tap(find.byIcon(Icons.settings).first);
      await settle();
      final meshL10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).last),
      )!;
      await tester.tap(
        find.text(meshL10n.canvasEditMenuMeshTransform).last,
      );
      await settle();
      expect(find.byType(MeshTransformPanel), findsOneWidget);
      final focusSurface = find.byKey(
        const ValueKey('focus-mode-menu-surface'),
      );
      expect(
        find.descendant(
          of: focusSurface,
          matching: find.byType(MeshTransformPanel),
        ),
        findsOneWidget,
        reason: 'PC/DeX mesh-transform controls must live inside FocusModeMenu',
      );
      await shot('10_pc_mesh_transform_focus_menu_expanded');
      final meshMenuToggle = find.byKey(
        const ValueKey('focus-mode-menu-toggle'),
      );
      await tester.tap(meshMenuToggle);
      await tester.pumpAndSettle();
      expect(find.byType(MeshTransformPanel), findsNothing);
      await shot('11_pc_mesh_transform_focus_menu_minimized');
      await tester.tap(meshMenuToggle);
      await tester.pumpAndSettle();
      expect(find.byType(MeshTransformPanel), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('focus-mode-menu-drag-handle')),
        const Offset(24, -40),
      );
      await shot('12_pc_mesh_transform_focus_menu_moved');

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await settings.setForcePcMode(false);
      await settings.setDefaultDockedPanels(<CanvasDockPanel>{});
      await navigate('/home');
      await navigate('/canvas/${demo.id}');
      final swatch = find.byKey(const ValueKey('canvasColorSwatch'));
      expect(swatch, findsOneWidget);
      // The toolbar is horizontally scrollable at phone widths. Bring the
      // color target into view before tapping it, just as a user would scroll.
      await tester.ensureVisible(swatch);
      await tester.pumpAndSettle();
      expect(swatch.hitTestable(), findsOneWidget);
      await tester.tap(swatch);
      await settle();
      expect(find.byType(ColorPickerPanel), findsOneWidget);
      assertColorWheelControlsClear();
      await shot('08_mobile_color_wheel_hsv_edge_controls');
      await tester.tap(find.byKey(const ValueKey('color-slider-mode-rgb')));
      await shot('09_mobile_color_wheel_rgb_edge_controls');

      await navigate('/home');
      await navigate('/canvas/${demo.id}');
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
      final focusMenuToggle = find.byKey(
        const ValueKey('focus-mode-menu-toggle'),
      );
      await tester.tap(focusMenuToggle);
      await shot('11_mobile_filter_menu_minimized');
      await tester.tap(focusMenuToggle);
      await settle();
      await tester.drag(
        find.byKey(const ValueKey('focus-mode-menu-drag-handle')),
        const Offset(0, -84),
      );
      await shot('12_mobile_filter_menu_moved');

      await navigate('/home');
      await navigate('/canvas/${demo.id}');
      await tester.tap(find.byIcon(Icons.settings).first);
      await settle();
      final mobileL10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).last),
      )!;
      await tester.tap(find.text(mobileL10n.canvasColorAdjustMenuTitle).last);
      await settle();
      expect(find.byType(ColorAdjustSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('color-adjust-focus-menu')),
        findsOneWidget,
      );
      final colorAdjustSliders = find.descendant(
        of: find.byType(ColorAdjustSheet),
        matching: find.byType(Slider),
      );
      expect(colorAdjustSliders, findsNWidgets(3));
      await tester.drag(colorAdjustSliders.first, const Offset(48, 0));
      await shot('13_mobile_color_adjust_menu_expanded');
      expect(find.byKey(const ValueKey('color-adjust-save-menu')), findsOneWidget);
      expect(
        find.text(mobileL10n.canvasColorAdjustTitle),
        findsOneWidget,
      );
      final mobileFocusSurface = tester.getRect(
        find.byKey(const ValueKey('focus-mode-menu-surface')),
      );
      expect(
        tester.getRect(
          find.byKey(const ValueKey('focus-mode-menu-resize-handle')),
        ).left,
        closeTo(mobileFocusSurface.left, 0.1),
      );
      final saturationAfterEdit = tester
          .widget<Slider>(colorAdjustSliders.first)
          .value;
      final colorMenuToggle = find.byKey(
        const ValueKey('focus-mode-menu-toggle'),
      );
      await tester.tap(colorMenuToggle);
      await tester.pumpAndSettle();
      expect(find.byType(ColorAdjustSheet), findsNothing);
      await shot('14_mobile_color_adjust_menu_minimized');
      await tester.tap(colorMenuToggle);
      await tester.pumpAndSettle();
      expect(find.byType(ColorAdjustSheet), findsOneWidget);
      expect(
        tester.widget<Slider>(colorAdjustSliders.first).value,
        closeTo(saturationAfterEdit, 0.01),
      );
      await tester.drag(
        find.byKey(const ValueKey('focus-mode-menu-drag-handle')),
        const Offset(0, -52),
      );
      await shot('15_mobile_color_adjust_menu_moved');
    },
  );
}
