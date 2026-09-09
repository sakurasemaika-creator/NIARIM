import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/custom-automation');
  final appDocs = Directory(
    '${Directory.systemTemp.path}/niarim_custom_automation_audit_docs',
  );
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const automationName = 'visual-audit-automation';

  setUpAll(() {
    out.createSync(recursive: true);
    appDocs.createSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => appDocs.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'Canvas automation: start -> real action -> stop -> edit -> save -> execute, with PNG evidence',
    (tester) async {
      tester.view.physicalSize = const Size(960, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);

      final providers = await tester.runAsync(buildAppProviders);
      ProjectService? ps;
      StateSetter? rebuildHost;
      String? projectId;
      final rootKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MultiProvider(
            providers: providers!,
            child: Builder(
              builder: (themeContext) => MaterialApp(
                theme: themeContext.watch<ThemeService>().themeData,
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: StatefulBuilder(
                  builder: (context, setState) {
                    ps ??= context.read<ProjectService>();
                    rebuildHost = setState;
                    if (projectId == null) return const SizedBox.expand();
                    return CanvasScreen(projectId: projectId);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final project = (await tester.runAsync(
        () => ps!.createProject(
          name: 'custom-automation-visual-audit',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 320,
          exportHeight: 320,
        ),
      ))!;
      projectId = project.id;
      rebuildHost!(() {});
      await tester.pump(const Duration(milliseconds: 1400));

      void stage(String value) =>
          debugPrint('AUTOMATION_VISUAL_AUDIT_STAGE=$value');

      Future<void> capture(String name) async {
        stage('capture:$name:begin');
        await tester.pump(const Duration(milliseconds: 200));
        final boundary =
            rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        stage('capture:$name:toByteData');
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        stage('capture:$name:write');
        File(
          '${out.path}/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
        stage('capture:$name:done');
      }

      Future<void> openCanvasSettings() async {
        final settingsButton = find.byWidgetPredicate(
          (widget) => widget is CanvasIconButton && widget.icon == Icons.settings,
          description: 'Canvas production settings button',
        );
        expect(settingsButton, findsOneWidget);
        // Calling the production CanvasIconButton callback avoids a flutter_test
        // InkResponse gesture-arena stall seen on the headless Linux runner while
        // still entering the menu through the exact production Canvas UI action.
        tester.widget<CanvasIconButton>(settingsButton).onPressed!();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await capture('00_canvas_before');

      stage('settings:open');
      await openCanvasSettings();
      await capture('01_settings_open');

      final l10n = AppLocalizations.of(tester.element(find.byType(CanvasScreen)))!;
      final automationEntry = find.text(l10n.customAutomationTitle);
      expect(
        automationEntry,
        findsWidgets,
        reason: 'Canvas settings exposes custom automation',
      );
      stage('manager:ensure-entry');
      await tester.ensureVisible(automationEntry.last);
      stage('manager:tap-entry');
      await tester.tap(automationEntry.last);
      await tester.pump(const Duration(milliseconds: 500));
      await capture('02_manager_open');

      final add = find.text(l10n.customAutomationAdd);
      expect(add, findsOneWidget, reason: 'automation manager exposes Add');
      stage('record:add');
      await tester.tap(add);
      await tester.pump(const Duration(milliseconds: 300));
      final nameField = find.byType(TextField);
      expect(
        nameField,
        findsOneWidget,
        reason: 'new automation dialog asks for a name',
      );
      await tester.enterText(nameField, automationName);
      final start = find.text(l10n.customAutomationStartRecording);
      expect(start, findsOneWidget);
      stage('record:start');
      await tester.tap(start);
      await tester.pump(const Duration(milliseconds: 500));
      await capture('03_recording_started');

      stage('action:brush-panel');
      await tester.tap(find.byIcon(Icons.tune).first);
      await tester.pump(const Duration(milliseconds: 400));
      final sliders = find.byType(Slider);
      expect(
        sliders,
        findsWidgets,
        reason: 'Brush panel exposes at least one real adjustable control',
      );
      stage('action:slider');
      await tester.drag(sliders.first, const Offset(70, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await capture('04_real_canvas_action_recorded');

      final stop = find.text(l10n.customAutomationStopRecording);
      expect(stop, findsWidgets, reason: 'recording stop control is visible');
      stage('record:stop');
      await tester.tap(stop.last);
      await tester.pump(const Duration(milliseconds: 500));
      await capture('05_recording_stopped_draft');

      expect(
        find.byIcon(Icons.delete_outline),
        findsWidgets,
        reason: 'draft editor opened with recorded steps',
      );
      await capture('06_draft_edit');

      final save = find.text(l10n.commonSave);
      expect(save, findsWidgets);
      stage('draft:save');
      await tester.tap(save.last);
      await tester.pump(const Duration(milliseconds: 600));
      await capture('07_saved');

      stage('reopen:settings');
      await openCanvasSettings();
      final entryAgain = find.text(l10n.customAutomationTitle);
      await tester.ensureVisible(entryAgain.last);
      await tester.tap(entryAgain.last);
      await tester.pump(const Duration(milliseconds: 500));
      await capture('08_manager_saved_item');

      final savedItem = find.text(automationName);
      expect(
        savedItem,
        findsOneWidget,
        reason: 'saved automation is listed in the manager',
      );
      stage('execute:row');
      await tester.tap(savedItem);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.customAutomationRunConfirmTitle), findsOneWidget);
      final yes = find.text(l10n.customAutomationYes);
      expect(yes, findsOneWidget);
      stage('execute:confirm');
      await tester.tap(yes);
      await tester.pump(const Duration(milliseconds: 700));
      await capture('09_reexecuted');

      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
