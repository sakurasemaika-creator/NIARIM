import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// PC/DeXモードのタイムラインは、動画編集ソフトのように［シーン・素材｜
/// プログラムモニター｜インスペクター］の段と、横幅いっぱいのタイムラインで
/// 区切る。各段階を`build/timeline-pc-workspace/`へ撮る。
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

  Future<void> menu(WidgetTester tester, String menu, Finder item) async {
    await tester.tap(find.byKey(ValueKey('pcMenu.$menu')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(item);
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

    final menuBar = tester.getRect(find.byType(PcMenuBar));
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
    expect(menuBar.top, 0);
    expect(status.bottom, 900);
    // 上の段：左にシーン・素材、中央にモニター、右にインスペクター。
    expect(bin.right, lessThanOrEqualTo(monitor.left));
    expect(inspector.left, greaterThanOrEqualTo(monitor.right));
    // 下の段：タイムラインは横幅いっぱい。
    expect(tracks.top, greaterThanOrEqualTo(monitor.bottom));
    expect(tracks.width, 1440);
    // スマホのツールバー（素材の追加・書き出し）はコマンドバーへ移した。
    expect(find.byKey(const Key('timelineExportButton')), findsNothing);
    expect(find.byKey(const ValueKey('pcCommandExport')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcInspectorProject')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcTimecode')), findsOneWidget);

    // 再生メニューの「1フレーム進む」で時刻とステータスバーが進む。
    expect(statusFrame(tester), contains('1/8'));
    await menu(tester, 'playback', find.text('1フレーム進む'));
    expect(statusFrame(tester), contains('2/8'));

    // 重なり順はインスペクターに出て、見出しの×で戻る。タイムラインは隠れない。
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

    // ウィンドウメニューで左右の区画を隠すと、モニターが広がる。
    await menu(
      tester,
      'window',
      find.byKey(const ValueKey('pcMenuWindow.bin')),
    );
    await menu(
      tester,
      'window',
      find.byKey(const ValueKey('pcMenuWindow.inspector')),
    );
    expect(find.byKey(const ValueKey('pcTimelineBin')), findsNothing);
    expect(
      tester.getRect(find.byKey(const ValueKey('pcProgramMonitor'))).width,
      greaterThan(monitor.width + 400),
    );
    await capture(tester, '03_monitor_only');
    expect(tester.takeException(), isNull);

    // メニューバーの右端の切り替えでキャンバスへ。
    await tester.tap(find.byKey(const ValueKey('pcModeSwitch.0')));
    await settle(tester, 12);
    expect(find.byType(CanvasScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the timeline menus open inside the window', (tester) async {
    await openTimeline(tester, size: const Size(1280, 800));
    for (final name in [
      'file',
      'edit',
      'material',
      'playback',
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
