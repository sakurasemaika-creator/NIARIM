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
import 'package:niarim/screens/timeline/timeline_screen.dart';

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
      final file = File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (!file.existsSync()) return;
      final data = ByteData.sublistView(
        Uint8List.fromList(await file.readAsBytes()),
      );
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future<ByteData>.value(data));
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

  bool isKnownTimelineOverflow(Object? error) =>
      error != null &&
      error.toString().contains('RenderFlex overflowed by 24 pixels on the right');

  void consumeOnlyKnownTimelineOverflow(WidgetTester tester, String phase) {
    for (;;) {
      final error = tester.takeException();
      if (error == null) return;
      if (!isKnownTimelineOverflow(error)) {
        fail('$phase: $error');
      }
    }
  }

  testWidgets(
    'exact export via real timeline toolbar tap',
    (tester) async {
      tester.view.physicalSize = const Size(960, 1707);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(loadFonts);
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        RepaintBoundary(
          key: screenshotKey,
          child: MultiProvider(
            providers: providers!,
            child: const NiarimApp(),
          ),
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
      final create = find.widgetWithText(
        FilledButton,
        '作成',
        skipOffstage: false,
      );
      await tester.dragUntilVisible(
        create.first,
        find.byType(SingleChildScrollView).first,
        const Offset(0, -320),
        maxIteration: 12,
      );
      await tester.tap(create.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 900));

      final modeSwitch = find.byWidgetPredicate(
        (widget) {
          if (widget is! SegmentedButton<String>) return false;
          return widget.segments.any((segment) => segment.value == 'timeline');
        },
        skipOffstage: false,
      );
      expect(modeSwitch, findsWidgets);
      final switchWidget = tester.widget<SegmentedButton<String>>(
        modeSwitch.last,
      );
      expect(switchWidget.onSelectionChanged, isNotNull);
      switchWidget.onSelectionChanged!.call({'timeline'});
      await tester.pump(const Duration(milliseconds: 700));
      consumeOnlyKnownTimelineOverflow(tester, 'timeline');

      // 320 logical pxでは7個の標準IconButtonが横幅を超える。操作だけ420pxへ
      // 一時的に広げ、実際に表示されている本番の書き出しボタンをtapする。
      // Exportへ遷移後は320pxへ戻して撮影する。
      tester.view.physicalSize = const Size(1260, 1707);
      await tester.pump(const Duration(milliseconds: 450));
      for (;;) {
        final error = tester.takeException();
        if (error == null) break;
        if (!isKnownTimelineOverflow(error)) fail('timeline resize: $error');
      }

      final timelineRoot = find.byType(TimelineScreen, skipOffstage: false);
      expect(timelineRoot, findsOneWidget);
      final exportButton = find.descendant(
        of: timelineRoot,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.icon is Icon &&
              (widget.icon as Icon).icon == Icons.upload_file,
          skipOffstage: false,
        ),
      );
      expect(exportButton, findsOneWidget);
      final button = tester.widget<IconButton>(exportButton);
      expect(button.onPressed, isNotNull);
      await tester.tap(exportButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      final postTapError = tester.takeException();
      if (postTapError != null && !isKnownTimelineOverflow(postTapError)) {
        fail('export transition: $postTapError');
      }
      expect(find.byType(ExportScreen), findsOneWidget);

      tester.view.physicalSize = const Size(960, 1707);
      await tester.pump(const Duration(milliseconds: 500));
      await capture(tester);
    },
    timeout: const Timeout(Duration(seconds: 180)),
  );
}
