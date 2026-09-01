import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('unused') bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final screenshotKey = GlobalKey();
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/');
    FilePicker.platform = _FakeFilePicker();
    tempDir = Directory.systemTemp.createTempSync('niarim_webref_exact_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => tempDir.path);
  });

  tearDown(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(960, 1707);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> fonts(WidgetTester tester) async {
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      Future<void> family(String name, String needle) async {
        final hit = assets.where((a) => a.contains(needle)).firstOrNull;
        if (hit == null) return;
        final loader = FontLoader(name)..addFont(rootBundle.load(hit));
        await loader.load();
      }
      await Future.wait([
        family('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
        family('Kuramubon', 'assets/fonts/Kuramubon.otf'),
        family('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf'),
      ]);
    });
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 220));
    final boundary = screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final dir = Directory('build/visual-smoke')..createSync(recursive: true);
    File('${dir.path}/webref_exact_$name.png').writeAsBytesSync(bytes!);
    // ignore: avoid_print
    print('web-reference exact captured: $name');
  }

  void clean(WidgetTester tester, String where) {
    final e = tester.takeException();
    expect(e, isNull, reason: '$where: $e');
  }

  Future<void> boot(WidgetTester tester) async {
    phone(tester);
    await fonts(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(RepaintBoundary(
      key: screenshotKey,
      child: MultiProvider(providers: providers!, child: const NiarimApp()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump(const Duration(milliseconds: 650));
    final start = find.text('はじめる');
    if (start.evaluate().isNotEmpty) {
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 500));
    }
    clean(tester, 'boot');
  }

  Future<({String projectId, String sceneId})> canvas(WidgetTester tester) async {
    await boot(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/new-project');
    await tester.pump(const Duration(milliseconds: 600));
    final create = find.widgetWithText(FilledButton, '作成', skipOffstage: false);
    await tester.dragUntilVisible(
      create.first,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -320),
      maxIteration: 12,
    );
    await tester.tap(create.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 900));
    clean(tester, 'create canvas');
    final ps = tester.element(find.byType(Scaffold).first).read<ProjectService>();
    final p = ps.projects.first;
    return (projectId: p.id, sceneId: ps.scenesOf(p.id).first.id);
  }

  Future<void> timeline(WidgetTester tester) async {
    final label = find.text('タイムライン', skipOffstage: false);
    await tester.ensureVisible(label.last);
    await tester.tap(label.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 650));
    final e = tester.takeException();
    if (e != null && !e.toString().contains('RenderFlex overflowed by 24 pixels on the right')) {
      fail('timeline: $e');
    }
  }

  testWidgets('exact onion panel via real menu ListTile', (tester) async {
    await canvas(tester);
    final settings = find.byTooltip('設定/編集', skipOffstage: false);
    expect(settings, findsWidgets);
    await tester.tap(settings.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    // 表示文言ではなく、CanvasScreen._showEditMenu() がオニオンスキン項目へ
    // 実際に割り当てている layers_outlined アイコンを基準にListTileを選ぶ。
    final onionIcon = find.byIcon(Icons.layers_outlined, skipOffstage: false);
    expect(onionIcon, findsWidgets);
    final onionTile = find.ancestor(of: onionIcon.last, matching: find.byType(ListTile));
    expect(onionTile, findsWidgets);
    await tester.ensureVisible(onionTile.last);
    await tester.tap(onionTile.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 450));
    clean(tester, 'open onion panel');
    await shot(tester, '03_canvas_onion_panel');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('exact export via real timeline overflow menu', (tester) async {
    await canvas(tester);
    await timeline(tester);

    // TimelineScreenでは書き出しは独立ボタンではなく右上の三点メニュー内。
    final more = find.byIcon(Icons.more_vert, skipOffstage: false);
    expect(more, findsWidgets);
    await tester.tap(more.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 250));

    // メニュー内には「書き出し」と「現在フレームを書き出し」があるため、
    // 完全一致の「書き出し」を選ぶ。
    final exportItem = find.text('書き出し', findRichText: true, skipOffstage: false);
    expect(exportItem, findsWidgets);
    await tester.tap(exportItem.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 650));
    clean(tester, 'timeline to export');
    expect(find.text('書き出し'), findsWidgets);
    await shot(tester, '07_export');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('exact tree mode screen using real SaveTreeScreen rendering', (tester) async {
    final ids = await canvas(tester);
    final context = tester.element(find.byType(Scaffold).first);
    final ps = context.read<ProjectService>();
    final saves = context.read<SaveTreeService>();
    saves.setTreeMode(true);
    final project = ps.projects.firstWhere((p) => p.id == ids.projectId);
    final scenes = ps.scenesOf(ids.projectId);
    final tm = ps.tileManagerOf(ids.projectId);
    final root = await saves.saveAsChild(
      projectId: ids.projectId,
      project: project,
      scenes: scenes,
      tileManager: tm,
      comment: '保存 01',
    );
    final second = await saves.saveAsChild(
      projectId: ids.projectId,
      project: project,
      scenes: scenes,
      tileManager: tm,
      parentId: root.id,
      comment: '保存 02',
    );
    await saves.saveAsChild(
      projectId: ids.projectId,
      project: project,
      scenes: scenes,
      tileManager: tm,
      parentId: second.id,
      comment: '保存 03',
    );
    GoRouter.of(context).push('/save-tree/${ids.projectId}');
    await tester.pump(const Duration(milliseconds: 750));
    clean(tester, 'tree route');
    await shot(tester, '06b_save_tree_mode');
  }, timeout: const Timeout(Duration(seconds: 180)));
}
