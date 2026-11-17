import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

class _ReferencePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    expect(type, FileType.image);
    expect(withData, isTrue);
    final bytes = File('assets/stamps/Stamp0001.png').readAsBytesSync();
    return FilePickerResult([
      PlatformFile(name: 'reference.png', size: bytes.length, bytes: bytes),
    ]);
  }
}

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

    // Move picker into the same left dock as the pen sub-tool.
    await settings!.moveDesktopDockPanel(
      CanvasDockPanel.colorPicker,
      toRight: false,
      before: CanvasDockPanel.penSubTool,
    );
    await tester.pump(const Duration(milliseconds: 200));
    final picker = find.byKey(const ValueKey('dockTarget-colorPicker'));
    final penSubTool = find.byKey(const ValueKey('dockTarget-penSubTool'));
    expect(picker, findsOneWidget);
    expect(penSubTool, findsOneWidget);
    // Adjacent edges touch exactly: no 8px spacer remains between panels.
    expect(
      tester.getBottomLeft(picker).dy,
      closeTo(tester.getTopLeft(penSubTool).dy, 0.1),
    );
    expect(
      find.byKey(const ValueKey('freeDockWindow-penSubTool')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('dockMenu-penSubTool')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('自由配置'), findsNothing);
    expect(find.byType(CanvasScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    const reference = CanvasDockPanel.reference;
    final dock = find.byKey(const ValueKey('dockTarget-reference'));
    final floating = find.byKey(const ValueKey('referenceFloatingWindow'));
    final image = find.byKey(const ValueKey('referenceImage'));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CanvasScreen)),
    )!;
    await tester.tap(find.byKey(const Key('desktopWindowVisibilityMenu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        CheckedPopupMenuItem<CanvasDockPanel>,
        l10n.referenceWindowTitle,
      ),
    );
    await tester.pumpAndSettle();
    expect(dock, findsOneWidget);
    expect(floating, findsNothing);
    expect(tester.getCenter(dock).dx, greaterThan(640));
    expect(settings!.defaultDockedPanels, contains(reference));

    FilePicker.platform = _ReferencePicker();
    await tester.tap(find.text(l10n.referenceWindowSelectImageButton));
    await tester.pumpAndSettle();
    expect(find.descendant(of: dock, matching: image), findsOneWidget);
    final original = tester.widget<Image>(image).image;

    await tester.tap(find.byKey(const ValueKey('dockCollapse-reference')));
    await tester.pumpAndSettle();
    expect(image, findsNothing);
    await tester.tap(find.byKey(const ValueKey('dockExpand-reference')));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(image).image, original);

    final drag = find.byKey(const ValueKey('dockDrag-reference'));
    await tester.drag(drag, tester.getCenter(picker) - tester.getCenter(drag));
    await tester.pumpAndSettle();
    expect(settings!.toolOptionDockOrder, contains(reference));
    expect(settings!.rightDockOrder, isNot(contains(reference)));
    expect(tester.getCenter(dock).dx, lessThan(640));
    expect(tester.widget<Image>(image).image, original);

    tester.view.physicalSize = const Size(390, 844);
    await settings!.setForcePcMode(false);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.canvasSettingsMenuTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.canvasEditMenuReferenceWindow));
    await tester.pumpAndSettle();
    expect(dock, findsNothing);
    expect(find.descendant(of: floating, matching: image), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
