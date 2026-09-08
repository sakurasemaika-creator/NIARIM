import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:niarim/widgets/stepped_slider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VHSノイズを実キャンバスUIから操作し実画面PNGを保存する', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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

    await loadAppFonts(tester);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );

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
      await settle(3);
      final exception = tester.takeException();
      expect(exception, isNull, reason: '$name emitted a Flutter exception');
      final boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final file = File('${out.path}/$name.png');
      await tester.runAsync(() => file.writeAsBytes(bytes!));
      expect(await file.length(), greaterThan(10000));
    }

    await settle();
    final appContext = tester.element(find.byType(MaterialApp).first);
    final ps = appContext.read<ProjectService>();
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
    expect(project, isNotNull);
    appRouter.go('/canvas/${project!.id}');
    await settle(10);

    // 実キャンバス上をポインタ操作して、VHSのノイズ・走査線・色にじみを
    // 目視しやすい太めの線群を作る。フィルター操作自体はこの後すべてUI経由。
    appContext.read<BrushService>().updateCurrentBrushSize(34);
    final canvasFinder = find.byType(CanvasArea);
    expect(canvasFinder, findsOneWidget);
    final canvasRect = tester.getRect(canvasFinder);
    final left = canvasRect.left + canvasRect.width * 0.24;
    final right = canvasRect.left + canvasRect.width * 0.76;
    for (var i = 0; i < 5; i++) {
      final y = canvasRect.top + canvasRect.height * (0.32 + i * 0.09);
      await tester.dragFrom(Offset(left, y), Offset(right - left, i.isEven ? 18 : -18));
      await tester.pump();
    }
    await settle(5);
    await capture('00_before_vhs');

    // 設定/編集 → フィルターを、ユーザーと同じUI導線で開く。
    await tester.tap(find.byIcon(Icons.settings).first);
    await settle(3);
    final l10n = AppLocalizations.of(tester.element(find.byType(MaterialApp).first))!;
    await tester.tap(find.text(l10n.filterPanelTitle).last);
    await settle(6);
    expect(find.byType(FilterPanel), findsOneWidget);
    await capture('01_filter_panel_open');

    // 検索UIを実際に操作し、VHSノイズを選択する。
    final panel = find.byType(FilterPanel);
    await tester.tap(
      find.descendant(of: panel, matching: find.byIcon(Icons.search)).first,
    );
    await tester.pump();
    final searchField = find.descendant(of: panel, matching: find.byType(TextField));
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'VHS');
    await settle(3);
    expect(find.text(l10n.filterNameVhsNoise), findsOneWidget);
    await tester.tap(find.text(l10n.filterNameVhsNoise));
    await settle(8);

    expect(appContext.read<FilterService>().currentFilter?.id, FilterService.vhsNoiseFilterId);
    await capture('02_vhs_selected_default');

    // 4本のVHS専用スライダーを実UIで操作する。各Sliderのレールを直接タップし、
    // ノイズ/走査線/色にじみ/トラッキングを目視しやすい強さへ上げる。
    final sliders = find.descendant(of: panel, matching: find.byType(Slider));
    expect(sliders, findsNWidgets(4));
    const ratios = [0.72, 0.64, 0.58, 0.66];
    for (var i = 0; i < 4; i++) {
      final rect = tester.getRect(sliders.at(i));
      await tester.tapAt(Offset(rect.left + rect.width * ratios[i], rect.center.dy));
      await settle(2);
    }
    final tuned = appContext.read<FilterService>().currentFilter!;
    expect(tuned.strength, greaterThan(55));
    expect(tuned.caSaturation, greaterThan(50));
    expect(tuned.caBrightness, greaterThan(45));
    expect(tuned.caContrast, greaterThan(50));
    await capture('03_vhs_tuned_preview');

    // 適用ボタンも実UIから押し、処理後のキャンバスを実キャプチャする。
    await tester.tap(find.text(l10n.filterApplyButton));
    await settle(14);
    await capture('04_vhs_applied_canvas');

    // Apply後にパネルが残る実装でもキャンバスの確認面積を確保できるよう閉じる。
    final close = find.descendant(of: panel, matching: find.byIcon(Icons.close));
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await settle(4);
    }
    await capture('05_vhs_applied_canvas_clean');

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
