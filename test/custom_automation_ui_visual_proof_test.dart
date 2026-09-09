import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/widgets/custom_automation_draft_sheet.dart';
import 'package:niarim/widgets/custom_automation_manager_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/custom-automation-ui-proof');

  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('record -> stop/review -> edit -> save -> manager execute UI proof', (tester) async {
    tester.view.physicalSize = const Size(960, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await loadAppFonts(tester);

    final service = CustomAutomationService();
    await service.init();
    final rootKey = GlobalKey();
    var executed = false;

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 100));
      final boundary = rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    }

    Widget host() => ChangeNotifierProvider.value(
          value: service,
          child: RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                appBar: AppBar(title: const Text('自動操作 UI proof')),
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      FilledButton(
                        onPressed: () {
                          service.beginDraft(
                            name: 'UI監査',
                            surface: CustomAutomationSurface.canvas,
                            recordingStartFrame: 3,
                          );
                        },
                        child: const Text('記録開始'),
                      ),
                      FilledButton(
                        onPressed: () {
                          service.recordStep(
                            surface: CustomAutomationSurface.canvas,
                            command: 'canvas.tool',
                            label: 'ブラシ操作',
                            args: const {'tool': 'brush'},
                            recordedFrame: 3,
                          );
                        },
                        child: const Text('実操作を記録'),
                      ),
                      FilledButton(
                        onPressed: () {
                          service.stopRecording();
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => ChangeNotifierProvider.value(
                              value: service,
                              child: CustomAutomationDraftSheet(
                                surface: CustomAutomationSurface.canvas,
                                onResumeRecording: () {},
                              ),
                            ),
                          );
                        },
                        child: const Text('停止して編集'),
                      ),
                      FilledButton(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => ChangeNotifierProvider.value(
                              value: service,
                              child: CustomAutomationManagerSheet(
                                surface: CustomAutomationSurface.canvas,
                                recordingStartFrame: 3,
                                frameCount: 6,
                                onRecordingStarted: () {},
                                onExecute: (automation, scope, targetFrames) async {
                                  executed = automation.steps.isNotEmpty;
                                },
                              ),
                            ),
                          );
                        },
                        child: const Text('保存済み自動操作を開く'),
                      ),
                      Text(executed ? '再実行済み' : '未実行'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(host());
    await capture('00_idle');

    await tester.tap(find.text('記録開始'));
    await tester.pump();
    expect(service.isRecording, isTrue);
    await capture('01_recording_started');

    await tester.tap(find.text('実操作を記録'));
    await tester.pump();
    expect(service.draft?.steps.length, 1);
    await capture('02_operation_recorded');

    await tester.tap(find.text('停止して編集'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomAutomationDraftSheet), findsOneWidget);
    await capture('03_review_edit');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(service.draft?.steps, isEmpty);
    await capture('04_step_deleted');

    await tester.tap(find.byIcon(Icons.fiber_manual_record));
    await tester.pumpAndSettle();
    expect(service.isRecording, isTrue);
    await capture('05_recording_resumed');

    await tester.tap(find.text('実操作を記録'));
    await tester.pump();
    await tester.tap(find.text('停止して編集'));
    await tester.pumpAndSettle();
    expect(service.draft?.steps.length, 1);

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    expect(service.items, isNotEmpty);
    await capture('06_saved');

    await tester.tap(find.text('保存済み自動操作を開く'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomAutomationManagerSheet), findsOneWidget);
    await capture('07_manager_saved_item');

    await tester.tap(find.text('UI監査'));
    await tester.pumpAndSettle();
    await capture('08_execute_confirm');

    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await tester.tap(find.text(l10n.customAutomationYes));
    await tester.pumpAndSettle();
    expect(executed, isTrue);
    await capture('09_reexecuted');
  });
}
