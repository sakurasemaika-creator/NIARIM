import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/app.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/premium_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/ad_banner_widget.dart';
import 'package:niarim/screens/export/export_screen.dart';
import 'package:niarim/screens/export/widgets/export_complete_dialog.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';

import 'helpers/load_app_fonts.dart';

class _CaptureAccount implements GoogleSignInAccount {
  @override
  String get id => 'export-capture';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CaptureAuth extends GoogleAuthService {
  @override
  final GoogleSignInAccount account = _CaptureAccount();
}

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

  Future<void> capture(
    WidgetTester tester, {
    String name = 'webref_exact_07_export.png',
  }) async {
    await tester.pump(const Duration(milliseconds: 250));
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
    File('${dir.path}/$name').writeAsBytesSync(bytes!);
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
    final premium = tester
        .element(find.byType(NiarimApp))
        .read<PremiumService>();
    final auth = _CaptureAuth();
    addTearDown(auth.dispose);
    premium.bindGoogleAuth(auth);
    premium.applyServerCoinPremiumExpiry(
      DateTime.now().add(const Duration(hours: 1)),
      accountId: auth.account.id,
    );

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump(const Duration(milliseconds: 650));
    final firstLaunch = find.byKey(const Key('tutorialSkip'));
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
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(timelineRoot))!;
    await tester.tap(find.byKey(const Key('timelineAddMaterialMenu')));
    await tester.pumpAndSettle();
    for (final label in [
      l10n.timelineAddTextTooltip,
      l10n.timelineAddImageTooltip,
      l10n.timelineAddVideoTooltip,
      l10n.timelineAddAudioTooltip,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('timelineAddWatermarkMenuItem')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.timelineWatermarkNotRegisteredTitle), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final exportButton = find.descendant(
      of: timelineRoot,
      matching: find.byKey(
        const Key('timelineExportButton'),
        skipOffstage: false,
      ),
    );
    expect(exportButton, findsOneWidget);
    expect(
      tester.getRect(exportButton).right,
      lessThanOrEqualTo(320),
      reason: 'Export must be visible without guessing a horizontal scroll',
    );
    expect(exportButton.hitTestable(), findsOneWidget);
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
    expect(find.byType(AdBannerWidget, skipOffstage: false), findsNothing);
    await capture(tester);
    final gif = find.widgetWithText(
      RadioListTile<ExportFormat>,
      l10n.exportFormatGif,
    );
    await tester.ensureVisible(gif);
    await tester.tap(gif);
    await tester.pumpAndSettle();
    expect(tester.widget<RadioListTile<ExportFormat>>(gif).selected, isTrue);
    expect(find.text(l10n.exportFormatGifSubtitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip(l10n.layerPanelHelpTooltip));
    await tester.pumpAndSettle();
    expect(find.text(l10n.helpVideoExportDesc), findsOneWidget);
    appRouter.pop();
    await tester.pumpAndSettle();
    final tiny = await tester.runAsync(
      () => projectService.createProject(
        name: '月明かりの谷',
        fps: 6,
        durationSeconds: 1,
        backgroundColor: 0xff39254a,
        exportWidth: 64,
        exportHeight: 64,
      ),
    );
    appRouter.go('/export/${tiny!.id}');
    await tester.pumpAndSettle();
    await tester.ensureVisible(gif);
    await tester.tap(gif);
    await tester.pumpAndSettle();
    final start = find.byIcon(Icons.file_download);
    await tester.ensureVisible(start);
    await tester.runAsync(() async {
      await tester.tap(start);
      for (
        var i = 0;
        i < 160 && find.byType(ExportCompleteDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 60));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      find.byType(ExportCompleteDialog),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.bySubtype<Text>())
          .map((t) => t.data)
          .join(' / '),
    );
    final exported = tester
        .widget<ExportCompleteDialog>(find.byType(ExportCompleteDialog))
        .file;
    expect(
      exported.uri.pathSegments.last,
      matches(RegExp(r'^月明かりの谷 \d{8}-\d{6}\.gif$')),
    );
    expect(exported.readAsBytesSync().take(3), [
      71,
      73,
      70,
    ], reason: 'GIF signature');
    expect(find.byType(AdBannerWidget, skipOffstage: false), findsNothing);
    await capture(tester, name: 'webref_export_complete.png');
    final openWorks = find.widgetWithText(FilledButton, l10n.exportOpenWorks);
    await tester.ensureVisible(openWorks);
    await tester.tap(openWorks);
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && find.byType(TabBar).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(
      appRouter.routeInformationProvider.value.uri.toString(),
      '/home?tab=works',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester.widget<TabBar>(find.byType(TabBar).first).controller!.index,
      1,
    );
    final savedWork = find.byWidgetPredicate(
      (widget) =>
          widget is ExportedWorkCard &&
          widget.name == exported.uri.pathSegments.last,
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && savedWork.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(savedWork, findsOneWidget);
    final welcome = find.text(l10n.homeFirstLaunchStart);
    if (welcome.evaluate().isNotEmpty) {
      await tester.ensureVisible(welcome);
      await tester.tap(welcome);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    final search = find.byKey(const Key('homeSearchButton'));
    expect(search.hitTestable(), findsOneWidget);
    await tester.tap(search);
    await tester.pump();
    final input = find.byKey(const Key('homeSearchInput'));
    await tester.enterText(input, 'よその作品');
    await tester.pump(const Duration(milliseconds: 400));
    expect(savedWork, findsNothing);
    await tester.enterText(input, '月明かり');
    await tester.pump(const Duration(milliseconds: 400));
    expect(savedWork, findsOneWidget);
    await capture(tester, name: 'webref_project_export_search.png');
    appRouter.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester.widget<TabBar>(find.byType(TabBar).first).controller!.index,
      0,
    );
    expect(tester.takeException(), isNull);
    premium.applyServerCoinPremiumExpiry(null);
  }, timeout: const Timeout(Duration(seconds: 180)));
}
