import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// PC/DeXモードの左右のドックは、窓を狭めてもキャンバスの幅を残す。
/// 以前は保存した幅のまま並べたので、右のドックを広げてから窓を狭めると
/// キャンバスが細い帯になり、さらに狭めると行がはみ出してキャンバスが
/// 消えた。各大きさを`build/canvas-dock-fit/`へ撮る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final out = Directory('build/canvas-dock-fit');
  late Directory tempDir;

  setUpAll(() => out.createSync(recursive: true));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final rootKey = GlobalKey();

  Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary =
          rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${out.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
      image.dispose();
    });
  }

  for (final (width, height, leftHanded, toolWidth, rightWidth) in [
    (1280.0, 800.0, false, 280.0, 436.0),
    (900.0, 650.0, false, 280.0, 436.0),
    (700.0, 560.0, false, 280.0, 436.0),
    (700.0, 560.0, true, 280.0, 436.0),
    (1280.0, 800.0, true, 280.0, 436.0),
    (600.0, 900.0, false, 280.0, 436.0),
    // 以前の版で下限（200）まで狭めて保存した幅：パネルが崩れない下限で出す。
    (1280.0, 800.0, false, 200.0, 200.0),
  ]) {
    final name =
        '${width.toInt()}x${height.toInt()}${leftHanded ? '_left' : ''}'
        '_${toolWidth.toInt()}_${rightWidth.toInt()}';
    testWidgets('docks leave the canvas room at $name', (tester) async {
      tempDir = Directory.systemTemp.createTempSync('niarim_dock_fit_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
      appRouter.go('/home');
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
        'language': 'ja',
        'force_pc_mode': 1,
        'is_left_handed': leftHanded,
        // 右のドックを広げ、左のドック（ブラシ）も既定で開く状態。
        'desktop_panel_width': rightWidth,
        'desktop_tool_panel_width': toolWidth,
      });
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      await settle(tester, 4);
      final service = tester
          .element(find.byType(HomeScreen))
          .read<ProjectService>();
      late String id;
      await tester.runAsync(() async {
        final project = await service.createProject(
          name: 'ドック',
          fps: 2,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 160,
          exportHeight: 90,
        );
        id = project.id;
      });
      appRouter.push('/canvas/$id');
      await settle(tester, 12);
      await capture(tester, name);
      expect(tester.takeException(), isNull);
      final canvas = tester.getRect(find.byType(CanvasArea));
      // 2つのドックをパネルが崩れない幅（左260・右240）まで狭めれば、
      // 800px幅からはキャンバスに240pxが残る。それより狭い窓では残りすべて。
      expect(
        canvas.width,
        greaterThanOrEqualTo(
          width >= 800 ? 240 : width - 40 - 16 - 260 - 240 - 1,
        ),
        reason: 'the canvas keeps room beside the docks',
      );
      expect(canvas.right, lessThanOrEqualTo(width));
      // 左のドックはブラシの名前が1行に収まる幅より狭くしない（狭いと
      // 1文字ずつ縦に並んだ）。
      final pen = find.descendant(
        of: find.byType(BrushPanel),
        matching: find.text('ペン'),
      );
      expect(tester.getSize(pen).height, lessThan(24));
      // 色・レイヤーのドックは右利きでは右、左利きでは左（鏡映し）。
      final layers = tester.getRect(find.byType(LayerPanel));
      if (leftHanded) {
        expect(layers.right, lessThanOrEqualTo(canvas.left));
      } else {
        expect(layers.left, greaterThanOrEqualTo(canvas.right));
      }

      // つまみを外側へ引くと色・レイヤーのドックが広がる（左利きでは
      // 向きが逆になっていて、引くと狭まった）。
      if (width == 1280 && rightWidth == 436) {
        final handle = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ResizeHandle',
        );
        final before = layers.width;
        // 色・レイヤーのドックに一番近いつまみ。
        final nearest =
            [
              for (var i = 0; i < handle.evaluate().length; i++)
                tester.getRect(handle.at(i)),
            ].reduce(
              (a, b) =>
                  (a.center.dx - layers.center.dx).abs() <
                      (b.center.dx - layers.center.dx).abs()
                  ? a
                  : b,
            );
        final gesture = await tester.startGesture(nearest.center);
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(Offset(leftHanded ? 10 : -10, 0));
          await tester.pump();
        }
        await gesture.up();
        await settle(tester, 2);
        final after = tester.getRect(find.byType(LayerPanel)).width;
        expect(after, greaterThan(before + 30));
        expect(tester.takeException(), isNull);
      }
    });
  }

  // 向きが変わってPC/DeXモードからスマホ表示へ移ったら、ドックのパネルは
  // 閉じる（開いたままだと浮かぶパネルが重なってキャンバスを覆った）。
  // PC/DeXモードへ戻ったら同じパネルがまた開く。
  testWidgets('docked panels close on the phone layout and come back', (
    tester,
  ) async {
    tempDir = Directory.systemTemp.createTempSync('niarim_dock_switch_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 1,
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MultiProvider(providers: providers, child: const NiarimApp()),
      ),
    );
    await settle(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final service = home.read<ProjectService>();
    final settings = home.read<SettingsService>();
    late String id;
    await tester.runAsync(() async {
      final project = await service.createProject(
        name: 'ドック',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      id = project.id;
    });
    appRouter.push('/canvas/$id');
    await settle(tester, 12);

    void expectDocked(Matcher matcher) {
      expect(find.byType(BrushPanel), matcher);
      expect(find.byType(ColorPickerPanel), matcher);
      expect(find.byType(LayerPanel), matcher);
    }

    expectDocked(findsOneWidget);
    await tester.runAsync(() => settings.setForcePcMode(false));
    tester.view.physicalSize = const Size(800, 1280);
    await settle(tester, 4);
    await capture(tester, 'switch_phone');
    expectDocked(findsNothing);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() => settings.setForcePcMode(true));
    tester.view.physicalSize = const Size(1280, 800);
    await settle(tester, 4);
    expectDocked(findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
