import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

/// The selection tool's options on the real canvas screen: the lasso's
/// "snap to lines" checkbox and the reference (working layer or all visible
/// layers) reach the canvas, and both are remembered: when the canvas is
/// opened again, and after the app restarts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lasso snap and the selection reference are remembered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tempDir = Directory.systemTemp.createTempSync('niarim_sel_opts_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null),
    );
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final providers = (await tester.runAsync(buildAppProviders))!;
    BuildContext? providerContext;
    final activeProject = ValueNotifier<String?>(null);
    addTearDown(activeProject.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            providerContext = context;
            return ValueListenableBuilder<String?>(
              valueListenable: activeProject,
              builder: (context, id, _) => MaterialApp(
                theme: context.watch<ThemeService>().themeData,
                scrollBehavior: const AppScrollBehavior(),
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: id == null
                    ? const Scaffold(body: SizedBox.expand())
                    : CanvasScreen(projectId: id),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final context = providerContext!;
    final ps = context.read<ProjectService>();
    final settings = context.read<SettingsService>();
    expect(settings.lassoSnapToLines, isFalse);
    expect(settings.lassoGapTolerancePx, 6);
    expect(settings.selectionReferenceAllVisible, isFalse);

    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'Selection options',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 128,
        exportHeight: 128,
      ),
    ))!;

    Future<void> openCanvas() async {
      activeProject.value = project.id;
      await pumpRealAsync(tester, const Duration(milliseconds: 600));
      final selectTool = find.byIcon(Icons.highlight_alt);
      await tester.ensureVisible(selectTool.first);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(selectTool.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    CanvasArea canvas() => tester.widget<CanvasArea>(find.byType(CanvasArea));
    final snap = find.byKey(const ValueKey('lasso-snap-to-lines'));
    bool snapChecked() => tester
        .widget<Checkbox>(
          find.descendant(of: snap, matching: find.byType(Checkbox)),
        )
        .value!;

    await openCanvas();
    final l10n = AppLocalizations.of(tester.element(find.byType(CanvasArea)))!;
    expect(snap, findsOneWidget, reason: 'shown with the lasso');
    expect(snapChecked(), isFalse);
    expect(find.text(l10n.canvasLassoGapTolerance), findsNothing);
    expect(canvas().lassoSnapToLines, isFalse);
    expect(canvas().selectionReferenceAllVisible, isFalse);

    await tester.tap(snap);
    await tester.pump();
    expect(snapChecked(), isTrue);
    expect(find.byKey(const ValueKey('lasso-gap-tolerance')), findsOneWidget);
    expect(find.text(l10n.canvasLassoGapTolerance), findsOneWidget);
    await tester.runAsync(() => settings.setLassoGapTolerancePx(9));
    await tester.pump();
    expect(settings.lassoGapTolerancePx, 9);
    expect(canvas().lassoSnapToLines, isTrue);
    await tester.tap(find.text(l10n.canvasSelectionReferenceVisibleLayers));
    await tester.pump();
    expect(canvas().selectionReferenceAllVisible, isTrue);
    expect(settings.lassoSnapToLines, isTrue);
    expect(settings.selectionReferenceAllVisible, isTrue);

    // Closing the canvas and opening it again keeps both.
    activeProject.value = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(find.byType(CanvasScreen), findsNothing);
    await openCanvas();
    expect(snapChecked(), isTrue);
    expect(canvas().lassoSnapToLines, isTrue);
    expect(canvas().lassoGapTolerancePx, 9);
    expect(canvas().selectionReferenceAllVisible, isTrue);

    // So does a restart: a fresh settings service reads them back.
    final restarted = SettingsService();
    await tester.runAsync(restarted.init);
    expect(restarted.lassoSnapToLines, isTrue);
    expect(restarted.lassoGapTolerancePx, 9);
    expect(restarted.selectionReferenceAllVisible, isTrue);

    // And turning them off is remembered too.
    await tester.tap(snap);
    await tester.tap(find.text(l10n.canvasSelectionReferenceWorkingLayer));
    await tester.pump();
    expect(canvas().lassoSnapToLines, isFalse);
    expect(canvas().selectionReferenceAllVisible, isFalse);
    final again = SettingsService();
    await tester.runAsync(again.init);
    expect(again.lassoSnapToLines, isFalse);
    expect(again.selectionReferenceAllVisible, isFalse);
    expect(tester.takeException(), isNull);
  });
}
