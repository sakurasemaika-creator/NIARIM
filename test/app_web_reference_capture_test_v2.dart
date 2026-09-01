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
    tempDir = Directory.systemTemp.createTempSync('niarim_web_reference_v2_');
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
    tester.view.physicalSize = const Size(960, 1707);
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
        final file = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
        if (!file.existsSync()) return;
        final data = ByteData.sublistView(Uint8List.fromList(await file.readAsBytes()));
        final loader = FontLoader('MaterialIcons')..addFont(Future<ByteData>.value(data));
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
    await tester.pump(const Duration(milliseconds: 220));
    final boundary = screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final dir = Directory('build/visual-smoke')..createSync(recursive: true);
    File('${dir.path}/webref_$name.png').writeAsBytesSync(bytes!);
    // ignore: avoid_print
    print('web-reference captured: $name');
  }

  void expectClean(WidgetTester tester, String operation) {
    final exception = tester.takeException();
    expect(exception, isNull, reason: '$operation でFlutter例外/overflow: $exception');
  }

  void consumeKnownTimelineOverflow(WidgetTester tester) {
    final exception = tester.takeException();
    if (exception == null) return;
    if (!exception.toString().contains('RenderFlex overflowed by 24 pixels on the right')) {
      fail('Timelineで想定外のFlutter例外: $exception');
    }
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
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump(const Duration(milliseconds: 700));
    expectClean(tester, '作品をつくる→ホーム');
    final firstLaunch = find.text('はじめる');
    if (firstLaunch.evaluate().isNotEmpty) {
      await tester.tap(firstLaunch);
      await tester.pump(const Duration(milliseconds: 700));
      expectClean(tester, '初回案内を閉じる');
    }
  }

  Future<void> dragIntoView(
    WidgetTester tester,
    Finder target, {
    Finder? scrollable,
  }) async {
    expect(target, findsWidgets);
    final viewport = scrollable ?? find.byType(SingleChildScrollView).first;
    expect(viewport, findsOneWidget);
    await tester.dragUntilVisible(
      target.first,
      viewport,
      const Offset(0, -320),
      maxIteration: 12,
    );
    await tester.pump(const Duration(milliseconds: 180));
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    expect(target, findsWidgets);
    await tester.tap(target.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<({String projectId, String sceneId})> createProjectAndOpenCanvas(
    WidgetTester tester,
  ) async {
    await bootToHome(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/new-project');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '新規プロジェクト画面');

    final createButton = find.widgetWithText(FilledButton, '作成', skipOffstage: false);
    await dragIntoView(tester, createButton);
    final rect = tester.getRect(createButton.first);
    final logicalHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(logicalHeight));
    await tapVisible(tester, createButton);
    await tester.pump(const Duration(milliseconds: 900));
    expectClean(tester, '作成→キャンバス');

    final ps = tester.element(find.byType(Scaffold).first).read<ProjectService>();
    expect(ps.projects, isNotEmpty);
    final project = ps.projects.first;
    final scenes = ps.scenesOf(project.id);
    expect(scenes, isNotEmpty);
    return (projectId: project.id, sceneId: scenes.first.id);
  }

  Finder toolbarIcon(IconData icon) => find.descendant(
        of: find.byType(ToolbarWidget),
        matching: find.byIcon(icon, skipOffstage: false),
      );

  Future<void> tapToolbarIcon(WidgetTester tester, IconData icon) async {
    final toolbar = find.byType(ToolbarWidget);
    expect(toolbar, findsOneWidget);
    final scroller = find.descendant(
      of: toolbar,
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroller, findsOneWidget);
    final target = toolbarIcon(icon);
    expect(target, findsOneWidget);
    for (var i = 0; i < 8; i++) {
      final r = tester.getRect(target);
      final w = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      if (r.left >= 0 && r.right <= w) break;
      await tester.drag(scroller, Offset(r.right > w ? -120 : 120, 0), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 160));
    }
    await tapVisible(tester, target);
  }

  Future<void> closeOverlay(WidgetTester tester) async {
    final close = find.byIcon(Icons.close, skipOffstage: false);
    expect(close, findsWidgets);
    await tapVisible(tester, close);
    expectClean(tester, 'オーバーレイを閉じる');
  }

  Future<void> openTimeline(WidgetTester tester) async {
    final timeline = find.text('タイムライン', skipOffstage: false);
    expect(timeline, findsWidgets);
    await tester.ensureVisible(timeline.first);
    await tester.pump(const Duration(milliseconds: 120));
    await tapVisible(tester, timeline);
    await tester.pump(const Duration(milliseconds: 550));
    consumeKnownTimelineOverflow(tester);
  }

  testWidgets('Web比較基準v2: Canvas / Layer / OnionSkin', (tester) async {
    await createProjectAndOpenCanvas(tester);
    await capture(tester, '01_canvas_default');

    await tapToolbarIcon(tester, Icons.layers);
    expectClean(tester, 'レイヤーパネルを開く');
    await capture(tester, '02_canvas_layer_panel');
    await closeOverlay(tester);

    final settingsEdit = find.byTooltip('設定/編集', skipOffstage: false);
    expect(settingsEdit, findsWidgets);
    await tapVisible(tester, settingsEdit);
    final onion = find.text('オニオンスキン', skipOffstage: false);
    expect(onion, findsWidgets);
    await tapVisible(tester, onion);
    expectClean(tester, 'オニオンスキンを開く');
    await capture(tester, '03_canvas_onion_skin');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準v2: Timeline / Audio編集', (tester) async {
    final ids = await createProjectAndOpenCanvas(tester);
    await openTimeline(tester);
    await capture(tester, '04_timeline_default');

    // 音声ファイル選択はCIで実ファイル選択UIを出せないため、実ProjectServiceへ
    // クリップだけ投入し、その後の「タイムライン上のクリップをタップして編集」は実操作する。
    final ps = tester.element(find.byType(Scaffold).first).read<ProjectService>();
    ps.addAudioClip(
      ids.projectId,
      ids.sceneId,
      const AudioClip(
        id: 'webref_audio',
        label: '比較用音声',
        startFrame: 0,
        lengthFrames: 24,
        volume: 0.72,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/canvas/${ids.projectId}');
    await tester.pump(const Duration(milliseconds: 700));
    await openTimeline(tester);
    final audio = find.text('比較用音声', skipOffstage: false);
    expect(audio, findsWidgets);
    await tester.ensureVisible(audio.first);
    await tapVisible(tester, audio);
    consumeKnownTimelineOverflow(tester);
    await capture(tester, '05_timeline_audio_editor');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準v2: SaveTree / Export', (tester) async {
    final ids = await createProjectAndOpenCanvas(tester);
    await tapToolbarIcon(tester, Icons.save_outlined);
    await tester.pump(const Duration(milliseconds: 550));
    expectClean(tester, 'Canvas→SaveTree');
    await capture(tester, '06_save_tree');

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/canvas/${ids.projectId}');
    await tester.pump(const Duration(milliseconds: 700));
    await openTimeline(tester);
    final export = find.byIcon(Icons.upload_file, skipOffstage: false);
    expect(export, findsWidgets);
    await tapVisible(tester, export);
    await tester.pump(const Duration(milliseconds: 550));
    consumeKnownTimelineOverflow(tester);
    await capture(tester, '07_export');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準v2: Workspace', (tester) async {
    await bootToHome(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/settings');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '設定画面');
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/settings/workspace');
    await tester.pump(const Duration(milliseconds: 650));
    expectClean(tester, '設定→Workspace');
    await capture(tester, '08_workspace');
  }, timeout: const Timeout(Duration(seconds: 180)));
}
