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
import 'package:niarim/models/audio_clip.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/project_service.dart';

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
    tempDir = Directory.systemTemp.createTempSync('niarim_web_reference_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
  });

  tearDown(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void useReferencePhone(WidgetTester tester) {
    // 既存Visual Smokeと同じ「一般的な小型Android端末相当」の基準。
    // 960/3=320 logical px, 2160/3=720 logical px（4:9）。
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> loadFonts(WidgetTester tester) async {
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      Future<void> loadFamily(String family, String needle) async {
        final matches = assets.where((a) => a.contains(needle)).toList();
        if (matches.isEmpty) return;
        final loader = FontLoader(family)..addFont(rootBundle.load(matches.first));
        await loader.load();
      }

      Future<void> loadSdkMaterialIcons() async {
        final flutterRoot = Platform.environment['FLUTTER_ROOT'];
        if (flutterRoot == null) return;
        final file = File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
        if (!file.existsSync()) return;
        final bytes = await file.readAsBytes();
        final data = ByteData.sublistView(Uint8List.fromList(bytes));
        final loader = FontLoader('MaterialIcons')
          ..addFont(Future<ByteData>.value(data));
        await loader.load();
      }

      await Future.wait([
        loadFamily('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
        loadFamily('Kuramubon', 'assets/fonts/Kuramubon.otf'),
        loadFamily('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf'),
        loadFamily('FontAwesomeSolid', 'fa-solid-900.ttf'),
        loadFamily('FontAwesomeRegular', 'fa-regular-400.ttf'),
        loadFamily('FontAwesomeBrands', 'fa-brands-400.ttf'),
        loadSdkMaterialIcons(),
      ]);
    });
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 180));
    final boundary = screenshotKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final dir = Directory('build/visual-smoke');
    dir.createSync(recursive: true);
    File('${dir.path}/webref_$name.png').writeAsBytesSync(bytes!);
    // ignore: avoid_print
    print('web-reference captured: $name');
  }

  void expectClean(WidgetTester tester, String operation) {
    final exception = tester.takeException();
    if (exception != null) {
      // ignore: avoid_print
      print('WEBREF EXCEPTION [$operation]: $exception');
      if (exception is FlutterError) {
        // ignore: avoid_print
        print(exception.toStringDeep());
      }
    }
    expect(exception, isNull, reason: '$operation でFlutter例外/overflow');
  }

  Future<void> tapReachable(WidgetTester tester, Finder finder) async {
    expect(finder, findsWidgets);
    final target = finder.first;
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 160));
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> scrollCanvasToolbarToIcon(
    WidgetTester tester,
    IconData icon,
  ) async {
    final toolbar = find.byType(ToolbarWidget);
    expect(toolbar, findsOneWidget);
    final scroll = find.descendant(
      of: toolbar,
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    final target = find.byIcon(icon, skipOffstage: false);
    expect(target, findsWidgets);

    for (var i = 0; i < 4; i++) {
      final rect = tester.getRect(target.first);
      final viewWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      if (rect.left >= 0 && rect.right <= viewWidth) return;
      final dx = rect.right > viewWidth ? -180.0 : 180.0;
      await tester.drag(scroll, Offset(dx, 0), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 220));
    }
  }

  Future<void> tapCanvasToolbarIcon(
    WidgetTester tester,
    IconData icon,
  ) async {
    await scrollCanvasToolbarToIcon(tester, icon);
    final target = find.byIcon(icon, skipOffstage: false);
    expect(target, findsWidgets);
    await tester.tap(target.first);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> bootToHome(WidgetTester tester) async {
    useReferencePhone(tester);
    await loadFonts(tester);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expectClean(tester, '起動');

    final createHome = find.byIcon(Icons.brush_outlined);
    expect(createHome, findsOneWidget);
    await tester.tap(createHome);
    await tester.pump(const Duration(milliseconds: 700));
    expectClean(tester, '作品をつくる→ホーム');

    final firstLaunch = find.text('はじめる');
    if (firstLaunch.evaluate().isNotEmpty) {
      await tester.tap(firstLaunch);
      await tester.pump(const Duration(milliseconds: 700));
      expectClean(tester, '初回案内を閉じる');
    }
  }

  Future<(String, String)> createProjectAndOpenCanvas(
    WidgetTester tester,
  ) async {
    await bootToHome(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/new-project');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '新規プロジェクト画面');

    final create = find.text('作成', skipOffstage: false);
    await tapReachable(tester, create);
    await tester.pump(const Duration(milliseconds: 550));
    expectClean(tester, '作成→キャンバス');

    final ps = tester.element(find.byType(Scaffold).first).read<ProjectService>();
    final project = ps.projects.first;
    final scene = ps.scenesOf(project.id).first;
    return (project.id, scene.id);
  }

  Future<void> closeOverlayPanel(WidgetTester tester) async {
    final close = find.byIcon(Icons.close, skipOffstage: false);
    await tapReachable(tester, close);
    expectClean(tester, 'オーバーレイを閉じる');
  }

  Future<void> openTimelineFromCanvas(WidgetTester tester) async {
    final timeline = find.text('タイムライン', skipOffstage: false);
    await tapReachable(tester, timeline);
    await tester.pump(const Duration(milliseconds: 550));
    expectClean(tester, 'Canvas→Timeline');
  }

  testWidgets('Web比較基準: Canvas / Layer / OnionSkin を実操作で撮影',
      (tester) async {
    await createProjectAndOpenCanvas(tester);
    await capture(tester, '01_canvas_default');

    await tapCanvasToolbarIcon(tester, Icons.layers);
    expectClean(tester, 'レイヤーパネルを開く');
    await capture(tester, '02_canvas_layer_panel');
    await closeOverlayPanel(tester);

    final editMenu = find.byTooltip('設定/編集', skipOffstage: false);
    await tapReachable(tester, editMenu);
    final onion = find.text('オニオンスキン', skipOffstage: false);
    await tapReachable(tester, onion);
    expectClean(tester, 'オニオンスキンを開く');
    await capture(tester, '03_canvas_onion_skin');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準: Timeline / Audio編集を実操作で撮影',
      (tester) async {
    final ids = await createProjectAndOpenCanvas(tester);
    await openTimelineFromCanvas(tester);
    await capture(tester, '04_timeline_default');

    final ps = tester.element(find.byType(Scaffold).first).read<ProjectService>();
    ps.addAudioClip(
      ids.$1,
      ids.$2,
      const AudioClip(
        id: 'webref_audio',
        label: '比較用音声',
        startFrame: 0,
        lengthFrames: 24,
        volume: 0.72,
        fadeIn: 0.0,
        fadeOut: 0.0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/canvas/${ids.$1}');
    await tester.pump(const Duration(milliseconds: 700));
    await openTimelineFromCanvas(tester);

    final audioClip = find.text('比較用音声', skipOffstage: false);
    await tapReachable(tester, audioClip);
    expectClean(tester, '音声クリップ編集を開く');
    await capture(tester, '05_timeline_audio_editor');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準: SaveTree / Export を実操作で撮影',
      (tester) async {
    final ids = await createProjectAndOpenCanvas(tester);

    await tapCanvasToolbarIcon(tester, Icons.save_outlined);
    await tester.pump(const Duration(milliseconds: 500));
    expectClean(tester, 'Canvas→SaveTree');
    await capture(tester, '06_save_tree');

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/canvas/${ids.$1}');
    await tester.pump(const Duration(milliseconds: 700));
    await openTimelineFromCanvas(tester);

    final export = find.byIcon(Icons.upload_file, skipOffstage: false);
    await tapReachable(tester, export);
    await tester.pump(const Duration(milliseconds: 500));
    expectClean(tester, 'Timeline→Export');
    await capture(tester, '07_export');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準: Workspace設定を実アプリ経路で撮影',
      (tester) async {
    await bootToHome(tester);
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/settings');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '設定画面');

    final workspace = find.text('ワークスペース', skipOffstage: false);
    if (workspace.evaluate().isNotEmpty) {
      await tapReachable(tester, workspace);
    } else {
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push('/settings/workspace');
      await tester.pump(const Duration(milliseconds: 500));
    }
    expectClean(tester, '設定→ワークスペース');
    await capture(tester, '08_workspace');
  }, timeout: const Timeout(Duration(seconds: 180)));
}
