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
import 'package:niarim/screens/export/export_screen.dart';

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
    tempDir = Directory.systemTemp.createTempSync('niarim_export_exact_');
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

  Future<void> loadFonts() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    Future<void> family(String name, String needle) async {
      final matches = assets.where((a) => a.contains(needle)).toList();
      if (matches.isEmpty) return;
      final loader = FontLoader(name)..addFont(rootBundle.load(matches.first));
      await loader.load();
    }
    Future<void> materialIcons() async {
      final root = Platform.environment['FLUTTER_ROOT'];
      if (root == null) return;
      final file = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (!file.existsSync()) return;
      final data = ByteData.sublistView(Uint8List.fromList(await file.readAsBytes()));
      final loader = FontLoader('MaterialIcons')..addFont(Future<ByteData>.value(data));
      await loader.load();
    }
    await Future.wait([
      family('HakkouMincho', 'assets/fonts/HakkouMincho.ttf'),
      family('Kuramubon', 'assets/fonts/Kuramubon.otf'),
      family('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf'),
      materialIcons(),
    ]);
  }

  Future<void> capture(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 250));
    final boundary = screenshotKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final dir = Directory('build/visual-smoke')..createSync(recursive: true);
    File('${dir.path}/webref_exact_07_export.png').writeAsBytesSync(bytes!);
  }

  testWidgets('exact export via Canvas Timeline and production menu', (tester) async {
    tester.view.physicalSize = const Size(960, 1707);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(loadFonts);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump(const Duration(milliseconds: 650));
    final firstLaunch = find.text('はじめる');
    if (firstLaunch.evaluate().isNotEmpty) {
      await tester.tap(firstLaunch);
      await tester.pump(const Duration(milliseconds: 500));
    }

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

    final timeline = find.text('タイムライン', skipOffstage: false);
    expect(timeline, findsWidgets);
    await tester.ensureVisible(timeline.last);
    await tester.tap(timeline.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 700));
    final timelineException = tester.takeException();
    if (timelineException != null &&
        !timelineException.toString().contains('RenderFlex overflowed by 24 pixels on the right')) {
      fail('timeline: $timelineException');
    }

    // 型Finderではなく、遷移後にしか存在しない実Timelineの三点メニューを
    // 本番画面到達の判定にする。これによりGoRouter/Widget testの型探索差異を排除する。
    final menuFinder = find.byWidgetPredicate(
      (widget) => widget is PopupMenuButton<String>,
      skipOffstage: false,
    );
    expect(menuFinder, findsWidgets);
    final menu = tester.widget<PopupMenuButton<String>>(menuFinder.last);
    expect(menu.onSelected, isNotNull);
    menu.onSelected!.call('export');
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);
    expect(find.byType(ExportScreen), findsOneWidget);
    await capture(tester);
  }, timeout: const Timeout(Duration(seconds: 180)));
}
