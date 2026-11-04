import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/timeline/widgets/stack_order_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/pc_workspace.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// PC/DeXモードのタイムラインは、スマホと同じボタン（上部バー・ツールバー・
/// 三点メニュー）を1段の上部バーに並べ、［シーン・素材｜プレビュー｜詳細］の
/// 段と、横幅いっぱいのタイムラインで区切る。他のソフトのメニューの分類は
/// 持ち込まない。各段階を`build/timeline-pc-workspace/`へ撮る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final out = Directory('build/timeline-pc-workspace');
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

  Future<void> openTimeline(
    WidgetTester tester, {
    required Size size,
    String language = 'ja',
  }) async {
    tempDir = Directory.systemTemp.createTempSync('niarim_pc_timeline_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': language,
      'force_pc_mode': 1,
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
        name: 'PCのタイムライン',
        fps: 4,
        durationSeconds: 2,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 160,
        exportHeight: 90,
      );
      id = project.id;
    });
    appRouter.push('/timeline/$id');
    await settle(tester, 12);
  }

  Future<void> window(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const ValueKey('pcTimelineWindowMenu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ValueKey('pcWindow.$item')));
    await settle(tester, 3);
  }

  String statusFrame(WidgetTester tester) => tester
      .widget<PcStatusItem>(find.byKey(const ValueKey('pcStatusFrame')))
      .text;

  testWidgets('the PC timeline lays out monitor, bin, inspector and tracks', (
    tester,
  ) async {
    await openTimeline(tester, size: const Size(1440, 900));
    await capture(tester, '01_default');
    expect(tester.takeException(), isNull);

    expect(find.byType(MenuBar), findsNothing);
    final topBar = tester.getRect(find.byKey(const ValueKey('pcTopBar')));
    final status = tester.getRect(find.byType(PcStatusBar));
    final bin = tester.getRect(find.byKey(const ValueKey('pcTimelineBin')));
    final monitor = tester.getRect(
      find.byKey(const ValueKey('pcProgramMonitor')),
    );
    final inspector = tester.getRect(
      find.byKey(const ValueKey('pcTimelineInspector')),
    );
    final tracks = tester.getRect(
      find.byKey(const ValueKey('pcTimelineTracks')),
    );
    expect(topBar.top, 0);
    expect(status.bottom, 900);
    // 上の段：左にシーン・素材、中央にプレビュー、右に詳細。
    expect(bin.right, lessThanOrEqualTo(monitor.left));
    expect(inspector.left, greaterThanOrEqualTo(monitor.right));
    // 下の段：タイムラインは横幅いっぱい。
    expect(tracks.top, greaterThanOrEqualTo(monitor.bottom));
    expect(tracks.width, 1440);
    // スマホのツールバー・上部バーのボタンは上部バーへ（素材を追加・三点
    // メニュー・書き出しはスマホと同じもの）。
    expect(find.byKey(const Key('timelineExportButton')), findsNothing);
    expect(find.byKey(const Key('timelineAddMaterialMenu')), findsOneWidget);
    expect(find.byKey(const ValueKey('timelineMoreMenu')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcCommandExport')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcCommandBackToCanvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcInspectorProject')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcTimecode')), findsOneWidget);
    // 借りた呼び名（プログラム・インスペクター）は使わない。
    expect(find.text('プレビュー'), findsWidgets);
    expect(find.text('詳細'), findsOneWidget);
    expect(find.text('インスペクター'), findsNothing);
    expect(find.text('プログラム'), findsNothing);

    // プレビューの下の再生の操作の「1フレーム進む」で時刻とステータスバーが
    // 進む。
    expect(statusFrame(tester), contains('1/8'));
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('pcProgramMonitor')),
        matching: find.byIcon(Icons.fast_forward),
      ),
    );
    await settle(tester, 2);
    expect(statusFrame(tester), contains('2/8'));

    // 重なり順は右の「詳細」に出て、見出しの×で戻る。タイムラインは隠れない。
    await tester.tap(find.byKey(const ValueKey('pcCommandStackOrder')));
    await settle(tester, 3);
    expect(find.byType(TimelineStackOrderPanel), findsOneWidget);
    expect(find.byKey(const ValueKey('pcTimelineTracks')), findsOneWidget);
    await capture(tester, '02_stack_order');
    await tester.tap(find.byKey(const ValueKey('pcPaneClose.inspector')));
    await settle(tester, 3);
    expect(find.byType(TimelineStackOrderPanel), findsNothing);
    expect(find.byKey(const ValueKey('pcInspectorProject')), findsOneWidget);

    // 素材のタブ：まだ素材が無い案内と、種類ごとの追加ボタン。
    await tester.tap(find.byKey(const ValueKey('pcPaneTab.materials')));
    await settle(tester, 2);
    expect(find.text('素材はまだありません'), findsOneWidget);
    expect(find.byKey(const ValueKey('pcMaterialBinAdd.text')), findsOneWidget);

    // 上部バーの区画の一覧で左右の区画を隠すと、プレビューが広がる。
    await window(tester, 'bin');
    await window(tester, 'inspector');
    expect(find.byKey(const ValueKey('pcTimelineBin')), findsNothing);
    expect(
      tester.getRect(find.byKey(const ValueKey('pcProgramMonitor'))).width,
      greaterThan(monitor.width + 400),
    );
    await capture(tester, '03_monitor_only');
    expect(tester.takeException(), isNull);

    // 上部バーの左端（スマホと同じ「キャンバスへ戻る」）でキャンバスへ。
    await tester.tap(find.byKey(const ValueKey('pcCommandBackToCanvas')));
    await settle(tester, 12);
    expect(find.byType(CanvasScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl + wheel zooms the timeline, the wheel alone scrolls', (
    tester,
  ) async {
    await openTimeline(tester, size: const Size(1280, 800));
    // フレーム一覧の真ん中の赤枠（今のフレーム）はフレームと同じ幅。
    final marker = find.byKey(const ValueKey('timelineCurrentFrameMarker'));
    final at = tester.getCenter(marker) + const Offset(60, 0);
    double frameWidth() => tester.getSize(marker).width;
    final before = frameWidth();
    Future<void> scroll(Offset delta, {LogicalKeyboardKey? holding}) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(at));
      await tester.sendEventToBinding(pointer.scroll(delta));
      if (holding != null) await tester.sendKeyUpEvent(holding);
      await settle(tester, 2);
    }

    await scroll(
      const Offset(0, -100),
      holding: LogicalKeyboardKey.controlLeft,
    );
    final zoomed = frameWidth();
    expect(zoomed, greaterThan(before));
    await scroll(const Offset(0, 100), holding: LogicalKeyboardKey.controlLeft);
    expect(frameWidth(), lessThan(zoomed));
    // Ctrlを押さないホイールでは大きさは変わらない。
    final unchanged = frameWidth();
    await scroll(const Offset(0, 100));
    expect(frameWidth(), unchanged);
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, language) in [
    ('narrow_1024x700', const Size(1024, 700), 'ja'),
    ('small_900x600', const Size(900, 600), 'ja'),
    ('fr_1280x800', const Size(1280, 800), 'fr'),
  ]) {
    testWidgets('the PC timeline fits at $name', (tester) async {
      await openTimeline(tester, size: size, language: language);
      await capture(tester, name);
      expect(tester.takeException(), isNull);
      final monitor = tester.getRect(
        find.byKey(const ValueKey('pcProgramMonitor')),
      );
      expect(monitor.width, greaterThanOrEqualTo(300));
      expect(
        tester.getRect(find.byKey(const ValueKey('pcTimelineTracks'))).width,
        size.width,
      );
    });
  }
}
