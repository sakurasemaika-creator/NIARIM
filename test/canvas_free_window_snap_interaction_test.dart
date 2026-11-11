import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('detach PC dock window, move it freely and snap near another',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'force_pc_mode': 1,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tmp = Directory.systemTemp.createTempSync('canvas-free-snap-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => tmp.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    ProjectService? projects;
    SettingsService? settings;
    StateSetter? refresh;
    String? projectId;
    await tester.pumpWidget(MultiProvider(
      providers: providers,
      child: Builder(builder: (providerContext) => MaterialApp(
        theme: providerContext.watch<ThemeService>().themeData,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(builder: (context, setState) {
          projects ??= context.read<ProjectService>();
          settings ??= context.read<SettingsService>();
          refresh = setState;
          return projectId == null ? const SizedBox.expand()
              : CanvasScreen(projectId: projectId);
        }),
      )),
    ));
    await tester.pump();
    final project = (await tester.runAsync(() =>
        projects!.createProject(
          name: 'free-window-snap-test',
          fps: 12, durationSeconds: 1,
          backgroundColor: 0xFFBCE3F4,
          exportWidth: 320, exportHeight: 320,
        )))!;
    projectId = project.id;
    refresh!(() {});
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byType(CanvasScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('dockMenu-brush')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dockMenu-brush')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('自由配置'), findsWidgets);
    await tester.tap(find.text('自由配置').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('freeDockWindow-brush')), findsOneWidget);
    expect(find.byKey(const ValueKey('dockMenu-brush')), findsNothing);

    // The second floating window is independent, not forced into a dock.
    await settings!.moveDesktopFloatingPanel(
      CanvasDockPanel.brush, const Offset(100, 160),
    );
    await settings!.floatDesktopDockPanel(
      CanvasDockPanel.colorPicker, const Offset(500, 160),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('freeDockWindow-colorPicker')),
        findsOneWidget);

    // After dragging to 9 logical pixels from the second window's edge,
    // the 12px magnet must finish flush at x=200 (300px-wide window).
    await tester.drag(
      find.byKey(const ValueKey('freeDockDrag-brush')),
      const Offset(91, 0),
    );
    await tester.pump(const Duration(milliseconds: 350));
    final snapped = settings!.desktopFloatingPosition(CanvasDockPanel.brush)!;
    expect(snapped.dx, closeTo(200, 1));
    expect(snapped.dy, closeTo(160, 1));

    // Deliberately overlap: edge snap must not force a separated layout.
    await settings!.moveDesktopFloatingPanel(
      CanvasDockPanel.brush, const Offset(450, 180),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(settings!.desktopFloatingPosition(CanvasDockPanel.brush)!.dx, 450);

    // Return to a dock without moving any other window.
    await tester.tap(find.byKey(const ValueKey('freeDockMenu-brush')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('左ドックへ戻す').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(settings!.desktopFloatingPosition(CanvasDockPanel.brush), isNull);
    expect(find.byKey(const ValueKey('freeDockWindow-brush')), findsNothing);
    expect(find.byType(CanvasScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
