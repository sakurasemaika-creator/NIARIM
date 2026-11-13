import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture actual color, hidden layer and magnet UI', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
    });
    final temp = Directory.systemTemp.createTempSync('niarim-focus-captures-');
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
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MultiProvider(providers: providers, child: const NiarimApp()),
      ),
    );
    final output = Directory('build/canvas-color-layer-snap-evidence')
      ..createSync(recursive: true);

    Future<void> settle() async {
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(milliseconds: 130));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
      }
    }

    Future<void> shot(String file) async {
      await settle();
      final repaint =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await repaint.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      await tester.runAsync(
        () => File('${output.path}/$file.png').writeAsBytes(bytes!),
      );
      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Screenshot $file threw a UI error');
    }

    Future<void> navigate(String location) async {
      appRouter.go(location);
      await settle();
    }

    await settle();
    final ps = tester.element(find.byType(MaterialApp)).read<ProjectService>();
    final settings = tester
        .element(find.byType(MaterialApp))
        .read<SettingsService>();
    await settings.markFirstLaunchDone();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'カラー・レイヤー証跡',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFB8CEDA,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    final scene = ps.scenesOf(project.id).first;
    final layer = scene.frames.first.layers.first;
    final pixels = Uint8List(320 * 180 * 4);
    for (var y = 25; y < 155; y++) {
      for (var x = 35; x < 285; x++) {
        final p = (y * 320 + x) * 4;
        pixels[p] = 240;
        pixels[p + 1] = x.isEven ? 45 : 115;
        pixels[p + 2] = 60;
        pixels[p + 3] = 255;
      }
    }
    ps.replaceLayerPixels(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      layerId: layer.id,
      pixels: pixels,
    );

    await settings.setForcePcMode(true);
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
    });
    await navigate('/home');
    await navigate('/canvas/${project.id}');
    expect(find.byType(ColorPickerPanel), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pc-color-picker-current-chip')),
      findsOneWidget,
    );
    await shot('01_color_header_and_wheel');

    final hsv = find.byKey(const ValueKey('color-slider-mode-hsv'));
    final rgb = find.byKey(const ValueKey('color-slider-mode-rgb'));
    expect(hsv, findsOneWidget);
    expect(rgb, findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('R'), findsNothing);
    await tester.ensureVisible(hsv);
    await shot('02_hsv_sliders');
    await tester.tap(rgb);
    await settle();
    expect(find.text('R'), findsOneWidget);
    expect(find.text('H'), findsNothing);
    await shot('03_rgb_sliders');
    await tester.tap(hsv);
    await settle();
    expect(find.text('H'), findsOneWidget);
    expect(find.text('R'), findsNothing);

    // The canvas hides this layer, but the separate layer thumbnail retains
    // the actual raster artwork over the project's paper colour.
    ps.updateLayer(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      layer: layer.copyWith(isVisible: false),
    );
    await settle();
    final thumbnail = find.byKey(ValueKey('layer-preview-tap-${layer.id}'));
    expect(thumbnail, findsOneWidget);
    await shot('04_hidden_layer_thumbnail');
    // The selected hidden layer must not leak through the actual canvas.
    // This sample is inside the painted area in the 1500x900 capture.
    final backgroundPixel = await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = (350 * image.width + 500) * 4;
      final color = Color.fromARGB(
        rgba!.getUint8(offset + 3),
        rgba.getUint8(offset),
        rgba.getUint8(offset + 1),
        rgba.getUint8(offset + 2),
      );
      image.dispose();
      return color;
    });
    expect(
      backgroundPixel,
      const Color(0xFFB8CEDA),
      reason: 'Hidden drawing must not appear on the main canvas',
    );
    await tester.tap(thumbnail);
    await settle();
    final viewer = find.byKey(const ValueKey('layer-preview-interactive'));
    expect(viewer, findsOneWidget);
    await shot('05_hidden_layer_fullscreen');
    final center = tester.getCenter(viewer);
    final a = await tester.startGesture(center + const Offset(-65, 0));
    final b = await tester.startGesture(center + const Offset(65, 0));
    await a.moveBy(const Offset(-45, 0));
    await b.moveBy(const Offset(45, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await shot('06_layer_pinch_zoom');
    await tester.drag(viewer, const Offset(70, 25));
    await shot('07_layer_drag_pan');
    await tester.tap(find.byKey(const ValueKey('layer-preview-close')));
    await settle();
    expect(viewer, findsNothing);

    // Compact dock, not an additional free-positioned window.
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
    });
    await navigate('/home');
    await navigate('/canvas/${project.id}');
    expect(find.byKey(const ValueKey('dockTarget-layer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dockTarget-colorPicker')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('freeDockWindow-layer')), findsNothing);
    await shot('08_docked_tool_windows_touch_without_gaps');
    await tester.tap(find.byKey(const ValueKey('dockMenu-colorPicker')));
    await settle();
    expect(find.text('自由配置'), findsNothing);
    await shot('09_dock_menu_has_no_free_position_option');
    await tester.tapAt(const Offset(750, 400));
    await settle();

    await navigate('/timeline/${project.id}');
    await shot('10_timeline_preview_anchor');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
