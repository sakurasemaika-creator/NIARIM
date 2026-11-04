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
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/widgets/pc_workspace.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// PC/DeXモードのキャンバスは、スマホと同じボタン（上部バー・ツールバー・
/// 設定/編集メニュー）のまま、浮かぶパネルの代わりにドックの窓・フレーム
/// 一覧・ステータスバーで区切ったPC専用の作業画面になる。他のソフトの
/// メニューの分類（ファイル・編集・選択範囲…）は持ち込まない。
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

  /// 上部バーの窓の一覧から、[item]の窓を開く・閉じる。
  Future<void> window(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const Key('desktopWindowVisibilityMenu')));
    // メニューが開き終わってから押す（1回目のpumpでは開く動きが始まるだけ）。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ValueKey('pcWindow.$item')));
    await settle(tester, 3);
  }

  String statusZoom(WidgetTester tester) => tester
      .widget<PcStatusItem>(find.byKey(const ValueKey('pcStatusZoom')))
      .text;

  Matrix4 view(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(CanvasArea),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;

  Future<void> wheel(
    WidgetTester tester,
    Offset at,
    Offset delta, {
    LogicalKeyboardKey? holding,
  }) async {
    if (holding != null) await tester.sendKeyDownEvent(holding);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(delta));
    if (holding != null) await tester.sendKeyUpEvent(holding);
    await settle(tester, 2);
  }

  testWidgets('the PC workspace keeps the phone buttons around the docks', (
    tester,
  ) async {
    await openCanvas(tester, size: const Size(1440, 900));
    await capture(tester, '01_default');
    expect(tester.takeException(), isNull);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CanvasScreen)),
    )!;

    // 他のソフトのメニューバーは置かない。上部バーが上、ステータスバーが
    // 下、ツールバーが左端。キャンバスはその間に収まる。
    expect(find.byType(MenuBar), findsNothing);
    final topBar = tester.getRect(find.byKey(const ValueKey('pcTopBar')));
    final status = tester.getRect(find.byType(PcStatusBar));
    final palette = tester.getRect(find.byKey(const ValueKey('pcToolPalette')));
    final canvas = tester.getRect(find.byType(CanvasArea));
    expect(topBar.top, 0);
    expect(status.bottom, 900);
    expect(palette.left, 0);
    expect(canvas.top, greaterThanOrEqualTo(topBar.bottom));
    expect(canvas.bottom, lessThanOrEqualTo(status.top));
    // 上部バーはスマホの上部バーと同じボタン（取り消し・やり直し・設定/編集・
    // ホーム・タイムラインへ）。
    for (final key in const [
      'pcCommandUndo',
      'pcCommandRedo',
      'pcCommandEditMenu',
      'pcCommandHome',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.byKey(const Key('canvasTimelineModeButton')), findsOneWidget);
    // ツールバーはスマホのツールバーと同じボタン（ブラシ設定・レイヤー・
    // 保存・ヘルプも）。
    for (final tooltip in [
      l10n.toolbarBrushSettingsTooltip,
      l10n.toolbarLayerTooltip,
      l10n.toolbarSaveTooltip,
      l10n.toolbarQuickToolTooltip,
      l10n.canvasRulerTooltip,
    ]) {
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pcToolPalette')),
          matching: find.byTooltip(tooltip),
        ),
        findsOneWidget,
        reason: tooltip,
      );
    }
    // 既定で開くブラシ・カラー・レイヤーはドックの窓の中。スマホの
    // 太さ・不透明度のスライダーは出さず、「ツールの設定」に入る。
    expect(find.byType(BrushPanel), findsOneWidget);
    expect(find.byType(ColorPickerPanel), findsOneWidget);
    expect(find.byType(LayerPanel), findsOneWidget);
    expect(find.byType(BrushSizeSlider), findsNothing);
    expect(find.byKey(const ValueKey('pcBrushSize')), findsOneWidget);
    expect(find.text(l10n.pcPaneToolProperty), findsOneWidget);
    expect(
      tester.getRect(find.byType(BrushPanel)).right,
      lessThan(canvas.left),
    );
    expect(
      tester.getRect(find.byType(LayerPanel)).left,
      greaterThan(canvas.right),
    );
    // 浮かぶパネルの影（黒い縁取りのように見えた）は付けない。
    for (final card
        in find
            .descendant(
              of: find.byType(BrushPanel),
              matching: find.byType(Card),
            )
            .evaluate()) {
      expect((card.widget as Card).elevation ?? 0, 0);
    }

    // 上部バーの拡大・回転がキャンバスに効き、ステータスバーへ倍率と角度が
    // 出る。倍率の表示を押すと全体表示へ戻る。
    final before = statusZoom(tester);
    await tester.tap(find.byKey(const ValueKey('pcCommandZoomIn')));
    await settle(tester, 3);
    expect(statusZoom(tester), isNot(before));
    await tester.tap(find.byKey(const ValueKey('pcCommandRotateLeft')));
    await settle(tester, 3);
    expect(statusZoom(tester), endsWith('-15°'));
    await capture(tester, '02_zoom_rotate');
    await tester.tap(find.byKey(const ValueKey('pcCommandZoomValue')));
    await settle(tester, 3);
    expect(statusZoom(tester), before);

    // 窓の一覧で開いた窓はドックに入る。設定/編集メニュー（スマホと同じ）の
    // フィルターもドックの窓として開く。
    await window(tester, 'canvasPreview');
    expect(find.byType(CanvasPreviewNavigator), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcCommandEditMenu')));
    await tester.pump();
    await settle(tester, 4);
    await capture(tester, '03_edit_menu');
    await tester.tap(find.text(l10n.filterPanelTitle).last);
    await settle(tester, 3);
    expect(find.byType(FilterPanel), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPaneTab.filter')), findsOneWidget);
    await capture(tester, '04_windows');
    expect(tester.takeException(), isNull);
    // 見出しの×でその窓だけ閉じる。
    await tester.tap(find.byKey(const ValueKey('pcPaneClose.filter')));
    await settle(tester, 2);
    expect(find.byType(FilterPanel), findsNothing);

    // 窓は見出しの矢印でたためる（見出しだけ残る）。
    await tester.tap(find.byKey(const ValueKey('pcPaneCollapse.brush')));
    await settle(tester, 2);
    expect(find.byType(BrushPanel), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pcPaneCollapse.brush')));
    await settle(tester, 2);
    expect(find.byType(BrushPanel), findsOneWidget);

    // 窓の見出しをつかんで反対側の列の窓の上へ落とすと、その列へ移り、
    // PCレイアウト設定（同じ設定）にも残る。
    final settings = tester
        .element(find.byType(CanvasScreen))
        .read<SettingsService>();
    final grip = tester.getCenter(
      find.byKey(const ValueKey('pcPaneDrag.brush')),
    );
    final drag = await tester.startGesture(grip, kind: PointerDeviceKind.mouse);
    await tester.pump();
    final layerHeader = tester.getRect(
      find.byKey(const ValueKey('pcPaneHeader.layer')),
    );
    final target = layerHeader.center + const Offset(0, 4);
    for (var i = 1; i <= 8; i++) {
      await drag.moveTo(Offset.lerp(grip, target, i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await settle(tester, 3);
    expect(settings.rightDockOrder, contains(CanvasDockPanel.brush));
    expect(
      settings.toolOptionDockOrder,
      isNot(contains(CanvasDockPanel.brush)),
    );
    expect(
      tester.getRect(find.byType(BrushPanel)).left,
      greaterThan(tester.getRect(find.byType(CanvasArea)).right),
    );
    await capture(tester, '05_window_moved');
    await settings.moveDesktopDockPanel(CanvasDockPanel.brush, toRight: false);
    await settle(tester, 3);

    // 窓の一覧の「パネルを隠す」でキャンバスが広がり、もう一度で戻る。
    final wide = tester.getRect(find.byType(CanvasArea)).width;
    await window(tester, 'hidePanels');
    expect(find.byType(LayerPanel), findsNothing);
    expect(tester.getRect(find.byType(CanvasArea)).width, greaterThan(wide));
    await capture(tester, '06_panels_hidden');
    await window(tester, 'hidePanels');
    expect(find.byType(LayerPanel), findsOneWidget);

    // ツールバーで消しゴムを選ぶと、ツールの設定とステータスバーが
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

  testWidgets('the mouse wheel scrolls, Shift scrolls sideways, Ctrl zooms', (
    tester,
  ) async {
    await openCanvas(tester, size: const Size(1280, 800));
    final center = tester.getCenter(find.byType(CanvasArea));
    final fit = statusZoom(tester);

    // Ctrl＋ホイール（上）で拡大する。動かせる余地ができる。
    await wheel(
      tester,
      center,
      const Offset(0, -120),
      holding: LogicalKeyboardKey.controlLeft,
    );
    await wheel(
      tester,
      center,
      const Offset(0, -120),
      holding: LogicalKeyboardKey.controlLeft,
    );
    final zoomed = statusZoom(tester);
    expect(zoomed, isNot(fit));
    final start = view(tester).getTranslation();

    // ホイールだけなら上下に動かす（倍率は変えない）。
    await wheel(tester, center, const Offset(0, 40));
    final down = view(tester).getTranslation();
    expect(down.y, lessThan(start.y));
    expect(down.x, closeTo(start.x, 0.01));
    expect(statusZoom(tester), zoomed);

    // Shift＋ホイールなら左右に動かす。
    await wheel(
      tester,
      center,
      const Offset(0, 40),
      holding: LogicalKeyboardKey.shiftLeft,
    );
    final side = view(tester).getTranslation();
    expect(side.x, lessThan(down.x));
    expect(side.y, closeTo(down.y, 0.01));
    expect(statusZoom(tester), zoomed);

    // Ctrl＋ホイール（下）で縮小する。
    await wheel(
      tester,
      center,
      const Offset(0, 120),
      holding: LogicalKeyboardKey.controlLeft,
    );
    expect(statusZoom(tester), isNot(zoomed));
    expect(tester.takeException(), isNull);
  });

  testWidgets('folded windows stay folded; a fully folded column is a strip', (
    tester,
  ) async {
    await openCanvas(tester, size: const Size(1280, 800));
    final settings = tester
        .element(find.byType(CanvasScreen))
        .read<SettingsService>();
    final right = settings.rightDockOrder
        .where(
          (p) => find
              .byKey(ValueKey('pcPaneCollapse.${p.name}'))
              .evaluate()
              .isNotEmpty,
        )
        .toList();
    expect(right, isNotEmpty);
    final canvasBefore = tester.getSize(find.byType(CanvasArea)).width;

    // 右の列の窓を1つずつたたむ。たたんだことは設定に残る（PCレイアウト
    // 設定のプレビューと同じ値）。
    for (final panel in right) {
      await tester.tap(find.byKey(ValueKey('pcPaneCollapse.${panel.name}')));
      await settle(tester, 2);
      expect(
        settings.isDesktopDockCollapsed(panel),
        isTrue,
        reason: panel.name,
      );
    }
    // 全部たたむと列は外側の細い帯になり、キャンバスが広がる。
    expect(find.byKey(const ValueKey('pcDockFolded')), findsOneWidget);
    for (final panel in right) {
      expect(
        find.byKey(ValueKey('pcPaneExpand.${panel.name}')),
        findsOneWidget,
      );
    }
    final canvasFolded = tester.getSize(find.byType(CanvasArea)).width;
    expect(canvasFolded, greaterThan(canvasBefore + 150));
    await capture(tester, 'folded_right_column');

    // 帯のボタンで1つ広げると、列が戻ってその窓だけ開く。
    await tester.tap(find.byKey(ValueKey('pcPaneExpand.${right.first.name}')));
    await settle(tester, 2);
    expect(settings.isDesktopDockCollapsed(right.first), isFalse);
    expect(find.byKey(const ValueKey('pcDockFolded')), findsNothing);
    for (final panel in right.skip(1)) {
      expect(settings.isDesktopDockCollapsed(panel), isTrue);
    }
    for (final panel in right.skip(1)) {
      await settings.setDesktopDockCollapsed(panel, false);
    }
    await settle(tester, 2);
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
      await window(tester, 'canvasPreview');
      await capture(tester, name);
      expect(tester.takeException(), isNull);
      final canvas = tester.getRect(find.byType(CanvasArea));
      final palette = tester.getRect(
        find.byKey(const ValueKey('pcToolPalette')),
      );
      final layers = tester.getRect(find.byType(LayerPanel));
      expect(canvas.width, greaterThanOrEqualTo(200));
      // 上部バーの右端のボタン（タイムラインへ）は窓の中に収まる。
      expect(
        tester.getRect(find.byKey(const Key('canvasTimelineModeButton'))).right,
        lessThanOrEqualTo(size.width),
      );
      if (leftHanded) {
        // 左利きは鏡映し：ツールバーが右端、色・レイヤーが左。
        expect(palette.right, size.width);
        expect(layers.right, lessThanOrEqualTo(canvas.left));
      } else {
        expect(palette.left, 0);
        expect(layers.left, greaterThanOrEqualTo(canvas.right));
      }
    });
  }
}
