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
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/first_use_tooltips.dart';
import '../helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Changed color controls and immersive filters render from the app', (tester) async {
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
    await tester.pumpWidget(RepaintBoundary(
      key: capture,
      child: MultiProvider(providers: providers, child: const NiarimApp()),
    ));
    final out = Directory('build/unified-pen-assets-screens')
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
        final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
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
    final demo = (await tester.runAsync(() => projects.createProject(
      name: '色調・描画プレビュー検証作品',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 320,
      exportHeight: 180,
    )))!;
    final scene = projects.scenesOf(demo.id).first;
    final layer = scene.frames.first.layers.first;
    final art = Uint8List(320 * 180 * 4);
    for (var y = 0; y < 180; y++) {
      for (var x = 0; x < 320; x++) {
        final i = (y * 320 + x) * 4;
        final ellipse = ((x - 160) * (x - 160) / 10000.0) +
            ((y - 90) * (y - 90) / 4200.0) < 1.0;
        art[i] = ellipse ? 220 : (x ~/ 14).isEven ? 50 : 110;
        art[i + 1] = ellipse ? (y ~/ 8).isEven ? 70 : 100 : 145;
        art[i + 2] = ellipse ? 115 : (y ~/ 13).isEven ? 230 : 180;
        art[i + 3] = 255;
      }
    }
    projects.replaceLayerPixels(
      projectId: demo.id, sceneId: scene.id, frameIndex: 0,
      layerId: layer.id, pixels: art,
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
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.penSubTool, CanvasDockPanel.colorPicker,
    });
    await navigate('/home');
    await navigate('/canvas/' + demo.id);
    expect(find.byType(PenSubToolPanel), findsOneWidget);
    expect(find.byType(BrushPanel), findsOneWidget);
    await shot('01_pc_unified_full_brush_management');
    final subtool = find.byType(PenSubToolPanel);
    await tester.tap(find.descendant(
      of: subtool, matching: find.text('トーン'),
    ).first);
    await settle();
    expect(find.byType(TonePanel), findsOneWidget);
    final toneCatalog = context.read<ToneService>().tones;
    expect(toneCatalog.any((tone) => tone.id == 'Tone0009'), isTrue);
    expect(toneCatalog.any((tone) => tone.id == 'Tone0063'), isFalse);
    expect(toneCatalog.any((tone) => tone.id == 'Tone0064'), isFalse);
    await shot('02_pc_unified_full_tone_management');
    await tester.tap(find.descendant(
      of: subtool, matching: find.text('スタンプ'),
    ).first);
    await settle();
    expect(find.byType(StampPanel), findsOneWidget);
    await shot('03_pc_unified_full_stamp_management');
    await shot('04_pc_color_wheel_small_sv_square');

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await settings.setForcePcMode(false);
    await settings.setDefaultDockedPanels(<CanvasDockPanel>{});
    await navigate('/home');
    await navigate('/canvas/' + demo.id);
    await tester.tap(find.byKey(const ValueKey('canvasColorSwatch')));
    await settle();
    expect(find.byType(ColorPickerPanel), findsOneWidget);
    final swatch = find.byKey(const ValueKey('selected-color-preview-chip'));
    expect(swatch, findsOneWidget);
    final swatchRect = tester.getRect(swatch);
    expect(swatchRect.width, closeTo(108, 0.1),
        reason: 'The current-color preview must not collapse to zero width');
    expect(
      tester.getRect(find.byType(HsvColorWheel)).top - swatchRect.bottom,
      greaterThanOrEqualTo(7.5),
      reason: 'The requested 8px gap above the color wheel must remain',
    );
    await shot('05_sp_shorter_color_chip_more_gap');
  });
}
