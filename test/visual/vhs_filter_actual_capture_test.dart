import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/load_app_fonts.dart';

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

  testWidgets('VHSノイズを実キャンバスUIから操作し実画面PNGを保存する', (tester) async {
    void stage(String value) => debugPrint('VHS_CAPTURE_STAGE:$value');

    SharedPreferences.setMockInitialValues({});
    FilePicker.platform = _FakeFilePicker();
    final tempDir = Directory.systemTemp.createTempSync('niarim_vhs_capture_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    stage('fonts:start');
    await loadAppFonts(tester);
    stage('fonts:done');
    appRouter.go('/');
    stage('providers:start');
    final providers = await tester.runAsync(buildAppProviders);
    stage('providers:done');
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    stage('app:pumped');

    Future<void> settle([int rounds = 8]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    final out = Directory('build/vhs_visual')..createSync(recursive: true);
    Future<void> capture(String name) async {
      stage('capture:$name:start');
      await settle(3);
      final exception = tester.takeException();
      expect(exception, isNull, reason: '$name emitted a Flutter exception');
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final file = File('${out.path}/$name.png');
      await tester.runAsync(() => file.writeAsBytes(bytes!));
      expect(file.lengthSync(), greaterThan(10000));
      stage('capture:$name:done');
    }

    await settle();
    stage('launch:settled');
    final appContext = tester.element(find.byType(MaterialApp).first);
    final ps = appContext.read<ProjectService>();
    stage('project:create:start');
    final project = await tester.runAsync(
      () => ps.createProject(
        name: 'vhs-visual-audit',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 480,
        exportHeight: 270,
      ),
    );
    stage('project:create:done');
    expect(project, isNotNull);
    appRouter.go('/canvas/${project!.id}');
    await settle(10);
    stage('canvas:ready');

    appContext.read<BrushService>().updateCurrentBrushSize(34);
    final canvasFinder = find.byType(CanvasArea);
    expect(canvasFinder, findsOneWidget);
    final canvasRect = tester.getRect(canvasFinder);
    final left = canvasRect.left + canvasRect.width * 0.24;
    final right = canvasRect.left + canvasRect.width * 0.76;
    for (var i = 0; i < 5; i++) {
      final y = canvasRect.top + canvasRect.height * (0.32 + i * 0.09);
      await tester.dragFrom(
        Offset(left, y),
        Offset(right - left, i.isEven ? 18 : -18),
      );
      await tester.pump();
    }
    await settle(5);
    stage('drawing:done');
    await capture('00_before_vhs');

    await tester.tap(find.byIcon(Icons.settings).first);
    await settle(3);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MaterialApp).first),
    )!;
    await tester.tap(find.text(l10n.filterPanelTitle).last);
    await settle(6);
    expect(find.byType(FilterPanel), findsOneWidget);
    stage('panel:open');
    await capture('01_filter_panel_open');

    final panel = find.byType(FilterPanel);
    await tester.tap(
      find.descendant(of: panel, matching: find.byIcon(Icons.search)).first,
    );
    await tester.pump();
    final searchField = find.descendant(
      of: panel,
      matching: find.byType(TextField),
    );
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'VHS');
    await settle(3);
    expect(find.text(l10n.filterNameVhsNoise), findsOneWidget);
    await tester.tap(find.text(l10n.filterNameVhsNoise));
    await settle(8);
    expect(
      appContext.read<FilterService>().currentFilter?.id,
      FilterService.vhsNoiseFilterId,
    );
    stage('vhs:selected');
    await capture('02_vhs_selected_default');

    final sliders = find.descendant(of: panel, matching: find.byType(Slider));
    expect(sliders, findsNWidgets(4));
    const ratios = [0.72, 0.64, 0.58, 0.66];
    for (var i = 0; i < 4; i++) {
      final rect = tester.getRect(sliders.at(i));
      await tester.tapAt(
        Offset(rect.left + rect.width * ratios[i], rect.center.dy),
      );
      await settle(2);
      stage('slider:$i:done');
    }
    final tuned = appContext.read<FilterService>().currentFilter!;
    expect(tuned.strength, greaterThan(55));
    expect(tuned.caSaturation, greaterThan(50));
    expect(tuned.caBrightness, greaterThan(45));
    expect(tuned.caContrast, greaterThan(50));
    await capture('03_vhs_tuned_preview');

    stage('apply:start');
    await tester.tap(find.text(l10n.filterApplyButton));
    await settle(14);
    stage('apply:settled');
    await capture('04_vhs_applied_canvas');

    final close = find.descendant(
      of: panel,
      matching: find.byIcon(Icons.close),
    );
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await settle(4);
    }
    await capture('05_vhs_applied_canvas_clean');

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    stage('done');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
