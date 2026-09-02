import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/canvas/widgets/mesh_transform_panel.dart';
import 'package:niarim/screens/canvas/widgets/onion_skin_panel.dart';
import 'package:niarim/screens/canvas/widgets/quick_tool_panel.dart';
import 'package:niarim/screens/canvas/widgets/ruler_panel.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/canvas-panels');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('実CanvasScreenの主要オーバーレイパネルを実操作で開いてPNG保存する', (tester) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      final loaders = <FontLoader>[
        FontLoader('HakkouMincho')..addFont(rootBundle.load('assets/fonts/HakkouMincho.ttf')),
        FontLoader('Kuramubon')..addFont(rootBundle.load('assets/fonts/Kuramubon.otf')),
        FontLoader('NotoSerifJP')..addFont(rootBundle.load('assets/fonts/NotoSerifJP.ttf')),
      ];
      await Future.wait(loaders.map((e) => e.load()));
    });

    final ps = ProjectService();
    final undo = app_undo.UndoManager();
    ps.setUndoManager(undo);
    final project = (await tester.runAsync(() => ps.createProject(
      name: 'panel-visual-audit',
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 320,
      exportHeight: 320,
    )))!;

    final providers = await tester.runAsync(buildAppProviders);
    final rootKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MultiProvider(
          providers: [
            ...providers!,
            ChangeNotifierProvider<ProjectService>.value(value: ps),
            ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
          ],
          child: MaterialApp(home: CanvasScreen(projectId: project.id)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1400));
    _expectNoException(tester, 'CanvasScreen initial');
    await _capture(rootKey, '${out.path}/00_canvas_default.png');

    Future<void> tapPanel({
      required Finder control,
      required Type panelType,
      required String file,
      bool longPress = false,
    }) async {
      expect(control, findsWidgets, reason: '$file control exists');
      if (longPress) {
        await tester.longPress(control.first);
      } else {
        await tester.tap(control.first);
      }
      await tester.pump(const Duration(milliseconds: 500));
      _expectNoException(tester, file);
      expect(find.byType(panelType), findsOneWidget, reason: '$file panel opened from real CanvasScreen control');
      await _capture(rootKey, '${out.path}/$file.png');
    }

    final colorStack = find.descendant(
      of: find.byType(ToolbarWidget),
      matching: find.byType(Stack),
    );
    expect(colorStack, findsWidgets);
    await tester.tap(colorStack.first);
    await tester.pump(const Duration(milliseconds: 500));
    _expectNoException(tester, 'color_picker');
    expect(find.byType(ColorPickerPanel), findsOneWidget);
    await _capture(rootKey, '${out.path}/01_color_picker.png');

    await tapPanel(
      control: find.byIcon(Icons.tune),
      panelType: BrushPanel,
      file: '02_brush_panel',
    );
    expect(find.byType(ColorPickerPanel), findsNothing);

    await tapPanel(
      control: find.byIcon(Icons.layers),
      panelType: LayerPanel,
      file: '03_layer_panel',
    );

    await tapPanel(
      control: find.byIcon(Icons.straighten),
      panelType: RulerPanel,
      file: '04_ruler_panel',
    );

    await tapPanel(
      control: find.byIcon(Icons.loop),
      panelType: QuickToolPanel,
      file: '05_quick_tool_panel',
      longPress: true,
    );

    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pump(const Duration(milliseconds: 400));
    _expectNoException(tester, 'settings_edit_sheet');
    expect(find.byType(BottomSheet), findsWidgets);
    await _capture(rootKey, '${out.path}/06_settings_edit_sheet.png');

    await tester.tap(find.byIcon(Icons.layers_outlined).last);
    await tester.pump(const Duration(milliseconds: 500));
    _expectNoException(tester, 'onion_skin_panel');
    expect(find.byType(OnionSkinPanel), findsOneWidget);
    await _capture(rootKey, '${out.path}/07_onion_skin_panel.png');

    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byIcon(Icons.blur_on).last);
    await tester.pump(const Duration(milliseconds: 500));
    _expectNoException(tester, 'filter_panel');
    expect(find.byType(FilterPanel), findsOneWidget);
    await _capture(rootKey, '${out.path}/08_filter_panel.png');

    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pump(const Duration(milliseconds: 350));
    final cropFree = find.byIcon(Icons.crop_free);
    expect(cropFree, findsWidgets);
    await tester.tap(cropFree.last);
    await tester.pump(const Duration(milliseconds: 500));
    _expectNoException(tester, 'mesh_transform_panel');
    expect(find.byType(MeshTransformPanel), findsOneWidget);
    await _capture(rootKey, '${out.path}/09_mesh_transform_panel.png');
  }, timeout: const Timeout(Duration(minutes: 4)));
}

void _expectNoException(WidgetTester tester, String operation) {
  final error = tester.takeException();
  expect(error, isNull, reason: '$operation visual panel must not overflow/throw');
}

Future<void> _capture(GlobalKey key, String path) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
}
