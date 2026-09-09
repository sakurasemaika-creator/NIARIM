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
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/custom_automation_draft_sheet.dart';
import 'package:niarim/widgets/custom_automation_manager_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/custom-automation-canvas-proof');
  final appDocs = Directory('${Directory.systemTemp.path}/niarim_automation_canvas_proof_docs');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    out.createSync(recursive: true);
    appDocs.createSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (_) async => appDocs.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'real CanvasScreen: record -> real tool operation -> stop -> edit -> save -> reexecute with staged PNGs',
    (tester) async {
      tester.view.physicalSize = const Size(960, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);

      final providers = await tester.runAsync(buildAppProviders);
      ProjectService? projects;
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
                    projects ??= context.read<ProjectService>();
                    rebuildHost = setState;
                    return projectId == null
                        ? const SizedBox.expand()
                        : CanvasScreen(projectId: projectId!);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final project = (await tester.runAsync(
        () => projects!.createProject(
          name: 'custom-automation-real-proof',
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
      expect(find.byType(CanvasScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      Future<void> capture(String name) async {
        await tester.pump(const Duration(milliseconds: 120));
        await tester.runAsync(() async {
          final boundary = rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }

      Future<void> reveal(Finder finder) async {
        expect(finder, findsWidgets);
        try {
          await tester.ensureVisible(finder.first);
          await tester.pump(const Duration(milliseconds: 100));
        } on StateError {
          // Not all controls are inside Scrollable.
        }
      }

      final canvasContext = tester.element(find.byType(CanvasScreen));
      final l10n = AppLocalizations.of(canvasContext)!;
      final automation = Provider.of<CustomAutomationService>(canvasContext, listen: false);

      await capture('00_canvas_idle');

      // Real Canvas settings -> Custom Automation manager.
      await reveal(find.byIcon(Icons.settings));
      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.customAutomationTitle), findsWidgets);
      await capture('01_canvas_settings');

      await reveal(find.text(l10n.customAutomationTitle));
      await tester.tap(find.text(l10n.customAutomationTitle).last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CustomAutomationManagerSheet), findsOneWidget);
      await capture('02_automation_manager');

      await tester.tap(find.text(l10n.customAutomationAdd));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Canvas実操作監査');
      await capture('03_record_name_dialog');
      await tester.tap(find.text(l10n.customAutomationStartRecording));
      await tester.pump(const Duration(milliseconds: 350));
      expect(automation.isRecording, isTrue);
      expect(find.byType(CustomAutomationRecordingStopButton), findsOneWidget);
      await capture('04_recording_started');

      // Actual Canvas toolbar operation. Select eyedropper and prove the service
      // received the event from CanvasScreen's real onToolSelected callback.
      final eyedropper = find.descendant(
        of: find.byType(ToolbarWidget),
        matching: find.byIcon(Icons.colorize),
      );
      await reveal(eyedropper);
      await tester.tap(eyedropper.first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(automation.draft?.steps.length, 1);
      expect(automation.draft!.steps.single.command, 'canvas.tool');
      expect(automation.draft!.steps.single.args['tool'], 'eyedropper');
      await capture('05_real_operation_recorded');

      await tester.tap(find.text(l10n.customAutomationStopRecording));
      await tester.pump(const Duration(milliseconds: 400));
      expect(automation.isRecording, isFalse);
      expect(find.byType(CustomAutomationDraftSheet), findsOneWidget);
      await capture('06_stopped_review');

      // Prove edit works: delete the step, capture empty state, resume and
      // perform a second genuine Canvas operation.
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(automation.draft?.steps, isEmpty);
      await capture('07_step_deleted_edit');

      await tester.tap(find.text(l10n.customAutomationBackToRecording));
      await tester.pump(const Duration(milliseconds: 300));
      expect(automation.isRecording, isTrue);
      expect(find.byType(CustomAutomationRecordingStopButton), findsOneWidget);
      await capture('08_recording_resumed');

      final bucket = find.descendant(
        of: find.byType(ToolbarWidget),
        matching: find.byIcon(Icons.format_color_fill),
      );
      await reveal(bucket);
      await tester.tap(bucket.first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(automation.draft?.steps.length, 1);
      expect(automation.draft!.steps.single.args['tool'], 'bucket');

      await tester.tap(find.text(l10n.customAutomationStopRecording));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(CustomAutomationDraftSheet), findsOneWidget);
      await capture('09_rerecorded_review');

      await tester.tap(find.byIcon(Icons.save_outlined).last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(automation.items.length, 1);
      expect(automation.items.single.name, 'Canvas実操作監査');
      await capture('10_saved');

      // Change away from the recorded bucket tool while not recording.
      final pen = find.descendant(
        of: find.byType(ToolbarWidget),
        matching: find.byIcon(Icons.brush),
      );
      await reveal(pen);
      await tester.tap(pen.first);
      await tester.pump(const Duration(milliseconds: 200));

      // Re-open actual Canvas settings/manager and execute the saved action.
      await reveal(find.byIcon(Icons.settings));
      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pump(const Duration(milliseconds: 300));
      await reveal(find.text(l10n.customAutomationTitle));
      await tester.tap(find.text(l10n.customAutomationTitle).last);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(CustomAutomationManagerSheet), findsOneWidget);
      expect(find.text('Canvas実操作監査'), findsOneWidget);
      await capture('11_saved_item_in_manager');

      await tester.tap(find.text('Canvas実操作監査'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.customAutomationCurrentFrame), findsOneWidget);
      expect(find.text(l10n.customAutomationAllFrames), findsOneWidget);
      expect(find.text(l10n.customAutomationSpecifiedFrames), findsOneWidget);
      await capture('12_execute_confirm_three_scopes');

      await tester.tap(find.text(l10n.customAutomationYes));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      final bucketButton = tester.widget<CanvasIconButton>(
        find.ancestor(of: bucket, matching: find.byType(CanvasIconButton)).first,
      );
      expect(bucketButton.selected, isTrue, reason: 'saved automation reselects the recorded bucket tool');
      await capture('13_reexecuted_bucket_selected');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
