import 'dart:io';
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

  void useInteractionPhone(WidgetTester tester) {
    // 操作中は既存Visual Smokeと同じ320x720 logical pxを使い、
    // フォームやダイアログの操作領域を実機相当で確保する。
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> switchToReferenceRatio(WidgetTester tester) async {
    // 撮影時だけWeb画面再現図と同じ9:16（320x569 logical px）へ変更。
    tester.view.physicalSize = const Size(960, 1707);
    tester.view.devicePixelRatio = 3.0;
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> switchToInteractionRatio(WidgetTester tester) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3.0;
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> loadFonts(WidgetTester tester) async {
    await tester.runAsync(() async {
      final hakkou = FontLoader('HakkouMincho')
        ..addFont(rootBundle.load('assets/fonts/HakkouMincho.ttf'));
      final kuramubon = FontLoader('Kuramubon')
        ..addFont(rootBundle.load('assets/fonts/Kuramubon.otf'));
      final noto = FontLoader('NotoSerifJP')
        ..addFont(rootBundle.load('assets/fonts/NotoSerifJP.ttf'));
      await Future.wait([hakkou.load(), kuramubon.load(), noto.load()]);
    });
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await switchToReferenceRatio(tester);
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
    expect(tester.takeException(), isNull,
        reason: '$operation でFlutter例外/overflow');
  }

  Future<void> bootToHome(WidgetTester tester) async {
    useInteractionPhone(tester);
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

    final create = find.text('作成');
    expect(create, findsOneWidget);
    await tester.ensureVisible(create);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(create);
    await tester.pump(const Duration(milliseconds: 850));
    expectClean(tester, '作成→キャンバス');

    final ps = tester.element(find.byType(Scaffold).first).read<ProjectService>();
    final project = ps.projects.first;
    final scene = ps.scenesOf(project.id).first;
    return (project.id, scene.id);
  }

  Future<void> closeOverlayPanel(WidgetTester tester) async {
    final close = find.byIcon(Icons.close);
    expect(close, findsWidgets);
    await tester.tap(close.last);
    await tester.pump(const Duration(milliseconds: 350));
    expectClean(tester, 'オーバーレイを閉じる');
  }

  testWidgets('Web比較基準: Canvas / Layer / OnionSkin を実操作で撮影',
      (tester) async {
    await createProjectAndOpenCanvas(tester);
    await capture(tester, '01_canvas_default');
    await switchToInteractionRatio(tester);

    final layer = find.byTooltip('レイヤー');
    expect(layer, findsOneWidget);
    await tester.tap(layer);
    await tester.pump(const Duration(milliseconds: 350));
    expectClean(tester, 'レイヤーパネルを開く');
    await capture(tester, '02_canvas_layer_panel');
    await switchToInteractionRatio(tester);
    await closeOverlayPanel(tester);

    final editMenu = find.byTooltip('設定/編集');
    expect(editMenu, findsOneWidget);
    await tester.tap(editMenu);
    await tester.pump(const Duration(milliseconds: 250));
    final onion = find.text('オニオンスキン');
    expect(onion, findsOneWidget);
    await tester.ensureVisible(onion);
    await tester.tap(onion);
    await tester.pump(const Duration(milliseconds: 350));
    expectClean(tester, 'オニオンスキンを開く');
    await capture(tester, '03_canvas_onion_skin');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準: Timeline / Audio編集を実操作で撮影',
      (tester) async {
    final ids = await createProjectAndOpenCanvas(tester);

    final timelineToggle = find.text('タイムライン');
    expect(timelineToggle, findsOneWidget);
    await tester.tap(timelineToggle);
    await tester.pump(const Duration(milliseconds: 850));
    expectClean(tester, 'Canvas→Timeline');
    await capture(tester, '04_timeline_default');
    await switchToInteractionRatio(tester);

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
    final timelineAgain = find.text('タイムライン');
    expect(timelineAgain, findsOneWidget);
    await tester.tap(timelineAgain);
    await tester.pump(const Duration(milliseconds: 850));
    expectClean(tester, '音声登録後Timelineを再表示');

    final audioClip = find.text('比較用音声');
    expect(audioClip, findsOneWidget);
    await tester.ensureVisible(audioClip);
    await tester.tap(audioClip);
    await tester.pump(const Duration(milliseconds: 350));
    expectClean(tester, '音声クリップ編集を開く');
    await capture(tester, '05_timeline_audio_editor');
  }, timeout: const Timeout(Duration(seconds: 180)));

  testWidgets('Web比較基準: SaveTree / Export を実操作で撮影',
      (tester) async {
    final ids = await createProjectAndOpenCanvas(tester);

    final save = find.byIcon(Icons.save_outlined);
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 800));
    expectClean(tester, 'Canvas→SaveTree');
    await capture(tester, '06_save_tree');
    await switchToInteractionRatio(tester);

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/canvas/${ids.$1}');
    await tester.pump(const Duration(milliseconds: 700));
    final timeline = find.text('タイムライン');
    expect(timeline, findsOneWidget);
    await tester.tap(timeline);
    await tester.pump(const Duration(milliseconds: 800));
    expectClean(tester, 'Canvas→Timeline');

    final export = find.byIcon(Icons.upload_file);
    expect(export, findsOneWidget);
    await tester.tap(export);
    await tester.pump(const Duration(milliseconds: 800));
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

    final workspace = find.text('ワークスペース');
    if (workspace.evaluate().isNotEmpty) {
      await tester.ensureVisible(workspace.first);
      await tester.tap(workspace.first);
    } else {
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push('/settings/workspace');
    }
    await tester.pump(const Duration(milliseconds: 700));
    expectClean(tester, '設定→ワークスペース');
    await capture(tester, '08_workspace');
  }, timeout: const Timeout(Duration(seconds: 180)));
}
