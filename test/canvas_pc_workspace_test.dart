import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/brush_panel.dart';
import 'package:niarim/screens/canvas/widgets/brush_size_slider.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/canvas_preview_navigator.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/pc_workspace.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// PC/DeXモードのキャンバスは、スマホの浮かぶパネルを横へ並べ直したもの
/// ではなく、メニューバー・コマンドバー・ツールパレット・ドックのペイン・
/// フレーム一覧・ステータスバーで区切ったPC専用の作業画面になる。
/// 各段階を`build/canvas-pc-workspace/`へ撮る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final out = Directory('build/canvas-pc-workspace');
  late Directory tempDir;
  final rootKey = GlobalKey();

  setUpAll(() => out.createSync(recursive: true));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

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

  Future<void> openCanvas(
    WidgetTester tester, {
    required Size size,
    String language = 'ja',
    bool leftHanded = false,
  }) async {
    tempDir = Directory.systemTemp.createTempSync('niarim_pc_workspace_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': language,
      'force_pc_mode': 1,
      'is_left_handed': leftHanded,
    });
    tester.view.physicalSize = size;
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
        name: 'PCの作業画面',
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
  }

  Future<void> menu(WidgetTester tester, String menu, Key item) async {
    await tester.tap(find.byKey(ValueKey('pcMenu.$menu')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(item));
    await settle(tester, 3);
  }

  String statusZoom(WidgetTester tester) => tester
      .widget<PcStatusItem>(find.byKey(const ValueKey('pcStatusZoom')))
      .text;

  testWidgets('the PC workspace frames the canvas with bars and docks', (
    tester,
  ) async {
    await openCanvas(tester, size: const Size(1440, 900));
    await capture(tester, '01_default');
    expect(tester.takeException(), isNull);

    // メニューバー・コマンドバーが上、ステータスバーが下、ツールパレットが
    // 左端。キャンバスはその間に収まる。
    final menuBar = tester.getRect(find.byType(PcMenuBar));
    final commandBar = tester.getRect(find.byType(PcCommandBar));
    final status = tester.getRect(find.byType(PcStatusBar));
    final palette = tester.getRect(find.byKey(const ValueKey('pcToolPalette')));
    final canvas = tester.getRect(find.byType(CanvasArea));
    expect(menuBar.top, 0);
    expect(commandBar.top, menuBar.bottom);
    expect(status.bottom, 900);
    expect(palette.left, 0);
    expect(canvas.top, greaterThanOrEqualTo(commandBar.bottom));
    expect(canvas.bottom, lessThanOrEqualTo(status.top));
    // 既定で開くブラシ・カラー・レイヤーはドックのペインの中。スマホの
    // 太さ・不透明度のスライダーは出さず、ツールプロパティに入る。
    expect(find.byType(BrushPanel), findsOneWidget);
    expect(find.byType(ColorPickerPanel), findsOneWidget);
    expect(find.byType(LayerPanel), findsOneWidget);
    expect(find.byType(BrushSizeSlider), findsNothing);
    expect(find.byKey(const ValueKey('pcBrushSize')), findsOneWidget);
    expect(
      tester.getRect(find.byType(BrushPanel)).right,
      lessThan(canvas.left),
    );
    expect(
      tester.getRect(find.byType(LayerPanel)).left,
      greaterThan(canvas.right),
    );

    // 表示メニューの拡大・コマンドバーの回転がキャンバスに効き、
    // ステータスバーへ倍率と角度が出る。
    final before = statusZoom(tester);
    await menu(tester, 'view', const ValueKey('pcMenuZoomIn'));
    expect(statusZoom(tester), isNot(before));
    await tester.tap(find.byKey(const ValueKey('pcCommandRotateLeft')));
    await settle(tester, 3);
    expect(statusZoom(tester), endsWith('-15°'));
    await capture(tester, '02_zoom_rotate');
    await tester.tap(find.byKey(const ValueKey('pcCommandZoomValue')));
    await settle(tester, 3);
    expect(statusZoom(tester), before);

    // ウィンドウメニューで開いたパネルはドックのタブになり、前に出る。
    await menu(tester, 'window', const ValueKey('pcMenuWindow.canvasPreview'));
    expect(find.byType(CanvasPreviewNavigator), findsOneWidget);
    await menu(tester, 'filter', const ValueKey('pcMenuFilter'));
    expect(find.byType(FilterPanel), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPaneTab.filter')), findsOneWidget);
    await menu(tester, 'window', const ValueKey('pcMenuWindow.onionSkin'));
    expect(find.byKey(const ValueKey('pcPaneTab.onionSkin')), findsOneWidget);
    await capture(tester, '03_tabs');
    expect(tester.takeException(), isNull);
    // タブを押すと切り替わり、見出しの×でそのタブだけ閉じる。
    await tester.tap(find.byKey(const ValueKey('pcPaneTab.filter')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const ValueKey('pcPaneClose.filter')));
    await settle(tester, 2);
    expect(find.byType(FilterPanel), findsNothing);
    expect(find.byKey(const ValueKey('pcPaneTab.onionSkin')), findsOneWidget);

    // ペインはたためる（見出しだけ残る）。
    await tester.tap(find.byKey(const ValueKey('pcPaneCollapse.subTool')));
    await settle(tester, 2);
    expect(find.byType(BrushPanel), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pcPaneCollapse.subTool')));
    await settle(tester, 2);
    expect(find.byType(BrushPanel), findsOneWidget);

    // パネルを隠すとキャンバスが広がり、もう一度押すと戻る。
    final wide = tester.getRect(find.byType(CanvasArea)).width;
    await tester.tap(find.byKey(const ValueKey('pcCommandHidePanels')));
    await settle(tester, 3);
    expect(find.byType(LayerPanel), findsNothing);
    expect(tester.getRect(find.byType(CanvasArea)).width, greaterThan(wide));
    await capture(tester, '04_panels_hidden');
    await tester.tap(find.byKey(const ValueKey('pcCommandHidePanels')));
    await settle(tester, 3);
    expect(find.byType(LayerPanel), findsOneWidget);

    // ツールパレットで消しゴムを選ぶと、ツールプロパティとステータスバーが
    // 消しゴムになる（消しゴムはダブルタップで説明を出すので、タップは
    // ダブルタップの判定時間の後に届く）。
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('pcToolPalette')),
        matching: find.byTooltip('消しゴム'),
      ),
    );
    await tester.pump(kDoubleTapTimeout);
    await settle(tester, 2);
    expect(
      find.descendant(
        of: find.byType(PcStatusBar),
        matching: find.text('消しゴム'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menus open with every entry inside the window', (
    tester,
  ) async {
    await openCanvas(tester, size: const Size(1280, 800));
    for (final name in [
      'file',
      'edit',
      'selection',
      'layer',
      'filter',
      'view',
      'window',
      'help',
    ]) {
      await tester.tap(find.byKey(ValueKey('pcMenu.$name')));
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, 'menu_$name');
      for (final item in find.byType(MenuItemButton).evaluate()) {
        final rect = tester.getRect(find.byWidget(item.widget));
        expect(rect.bottom, lessThanOrEqualTo(800), reason: name);
        expect(rect.right, lessThanOrEqualTo(1280), reason: name);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
    }
    // レイヤーメニューの「新規レイヤー」で描く先が新しいレイヤーになる。
    final canvas = tester.state<State<CanvasScreen>>(find.byType(CanvasScreen));
    final projects = canvas.context.read<ProjectService>();
    final project = projects.projects.single;
    final scene = projects.scenesOf(project.id).first;
    final before = projects.layersOf(project.id, scene.id, 0).length;
    await menu(tester, 'layer', const ValueKey('pcMenuNewLayer'));
    expect(projects.layersOf(project.id, scene.id, 0).length, before + 1);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, language, leftHanded) in [
    ('left_1280x800', const Size(1280, 800), 'ja', true),
    ('narrow_1024x700', const Size(1024, 700), 'ja', false),
    ('small_900x600', const Size(900, 600), 'ja', false),
    ('fr_1280x800', const Size(1280, 800), 'fr', false),
  ]) {
    testWidgets('the workspace fits at $name', (tester) async {
      await openCanvas(
        tester,
        size: size,
        language: language,
        leftHanded: leftHanded,
      );
      await menu(
        tester,
        'window',
        const ValueKey('pcMenuWindow.canvasPreview'),
      );
      await capture(tester, name);
      expect(tester.takeException(), isNull);
      final canvas = tester.getRect(find.byType(CanvasArea));
      final palette = tester.getRect(
        find.byKey(const ValueKey('pcToolPalette')),
      );
      final layers = tester.getRect(find.byType(LayerPanel));
      expect(canvas.width, greaterThanOrEqualTo(200));
      if (leftHanded) {
        // 左利きは鏡映し：ツールパレットが右端、色・レイヤーが左。
        expect(palette.right, size.width);
        expect(layers.right, lessThanOrEqualTo(canvas.left));
      } else {
        expect(palette.left, 0);
        expect(layers.left, greaterThanOrEqualTo(canvas.right));
      }
    });
  }
}
