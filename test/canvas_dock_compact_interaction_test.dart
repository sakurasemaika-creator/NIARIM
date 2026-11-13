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

  testWidgets('PC dock panels are flush and have no free-position option', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'force_pc_mode': 1,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tmp = Directory.systemTemp.createTempSync('canvas-compact-dock-');
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
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (providerContext) => MaterialApp(
            theme: providerContext.watch<ThemeService>().themeData,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, setState) {
                projects ??= context.read<ProjectService>();
                settings ??= context.read<SettingsService>();
                refresh = setState;
                return projectId == null
                    ? const SizedBox.expand()
                    : CanvasScreen(projectId: projectId);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final project = (await tester.runAsync(
      () => projects!.createProject(
        name: 'compact-dock-test',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFBCE3F4,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    projectId = project.id;
    refresh!(() {});
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byType(CanvasScreen), findsOneWidget);

    // Move picker into the same left dock as brush, not to a floating window.
    await settings!.moveDesktopDockPanel(
      CanvasDockPanel.colorPicker,
      toRight: false,
      before: CanvasDockPanel.brush,
    );
    await tester.pump(const Duration(milliseconds: 200));
    final picker = find.byKey(const ValueKey('dockTarget-colorPicker'));
    final brush = find.byKey(const ValueKey('dockTarget-brush'));
    expect(picker, findsOneWidget);
    expect(brush, findsOneWidget);
    // Adjacent edges touch exactly: no 8px spacer remains between panels.
    expect(
      tester.getBottomLeft(picker).dy,
      closeTo(tester.getTopLeft(brush).dy, 0.1),
    );
    expect(find.byKey(const ValueKey('freeDockWindow-brush')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dockMenu-brush')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('自由配置'), findsNothing);
    expect(find.byType(CanvasScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
