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
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/ad_banner_widget.dart';
import 'package:niarim/screens/export/export_screen.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'helpers/load_app_fonts.dart';

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
    SharedPreferences.setMockInitialValues({'is_premium': true});
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

  Future<void> capture(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(AdBannerWidget, skipOffstage: false), findsNothing);
    final boundary =
        screenshotKey.currentContext!.findRenderObject()
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

  testWidgets('exact export via real timeline toolbar tap', (tester) async {
    tester.view.physicalSize = const Size(960, 1707);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await loadAppFonts(tester);
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

    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/new-project');
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

    final projectService = tester
        .element(find.byType(Scaffold).first)
        .read<ProjectService>();
    final project = projectService.projects.first;
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('/canvas/${project.id}');
    await tester.pump(const Duration(milliseconds: 700));

    final canvas = find.byType(CanvasScreen);
    expect(canvas, findsOneWidget);
    final timelineModeButton = find.descendant(
      of: canvas,
      matching: find.byKey(const Key('canvasTimelineModeButton')),
    );
    expect(timelineModeButton, findsOneWidget);
    expect(
      tester.widget<CanvasIconButton>(timelineModeButton).onPressed,
      isNotNull,
    );
    await tester.tap(timelineModeButton);
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester.takeException(),
      isNull,
      reason: 'timeline must render without overflow',
    );

    final timelineRoot = find.byType(TimelineScreen, skipOffstage: false);
    expect(timelineRoot, findsOneWidget);
    final exportButton = find.descendant(
      of: timelineRoot,
      matching: find.byKey(
        const Key('timelineExportButton'),
        skipOffstage: false,
      ),
    );
    expect(exportButton, findsOneWidget);
    await tester.ensureVisible(exportButton);
    await tester.pumpAndSettle();
    expect(tester.getSize(exportButton).height, greaterThanOrEqualTo(48));
    expect(exportButton.hitTestable(), findsOneWidget);
    final button = tester.widget<IconButton>(exportButton);
    expect(button.onPressed, isNotNull);
    await tester.tap(exportButton);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(
      tester.takeException(),
      isNull,
      reason: 'export transition must not hide layout errors',
    );
    expect(find.byType(ExportScreen), findsOneWidget);

    tester.view.physicalSize = const Size(960, 1707);
    await tester.pump(const Duration(milliseconds: 500));
    await capture(tester);
  }, timeout: const Timeout(Duration(seconds: 180)));
}
