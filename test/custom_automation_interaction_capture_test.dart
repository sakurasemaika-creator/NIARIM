import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/widgets/custom_automation_manager_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture real custom automation management interactions', (tester) async {
    final out = Directory('build/visual-reaudit/custom-automation-interactions');
    out.createSync(recursive: true);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'custom_automations_v1': <String>[],
      'custom_automation_favorites_v1': <String>[],
    });

    final service = CustomAutomationService();
    await service.init();
    final captureKey = GlobalKey();

    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: ChangeNotifierProvider<CustomAutomationService>.value(
          value: service,
          child: const _InteractionHost(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) throw StateError('PNG encoding returned null');
          await File('${out.path}/$name.png').writeAsBytes(
            data.buffer.asUint8List(),
            flush: true,
          );
        } finally {
          image.dispose();
        }
      });
    }

    await tester.tap(find.byKey(const ValueKey('open-custom-automation-manager')));
    await tester.pumpAndSettle();
    await capture('01_manager_empty');

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await capture('02_record_name_dialog');
    await tester.enterText(find.byType(TextField).last, '操作キャプチャ');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(service.isRecording, isTrue);
    await capture('03_recording_started');

    service.recordStep(
      surface: CustomAutomationSurface.canvas,
      command: 'canvas.brushSize',
      label: 'ブラシサイズ 12px',
      args: const {'size': 12.0},
      recordedFrame: 0,
    );
    service.recordStep(
      surface: CustomAutomationSurface.canvas,
      command: 'canvas.brushOpacity',
      label: '不透明度 72%',
      args: const {'opacity': 0.72},
      recordedFrame: 0,
    );
    service.recordStep(
      surface: CustomAutomationSurface.canvas,
      command: 'canvas.color',
      label: '描画色 #3366CC',
      args: const {'color': 0xFF3366CC},
      recordedFrame: 0,
    );
    await tester.pump();
    expect(service.draft!.steps, hasLength(3));
    await capture('04_recorded_three_steps');

    service.stopRecording();
    await tester.pumpAndSettle();
    expect(service.isRecording, isFalse);

    await tester.tap(find.byKey(const ValueKey('open-custom-automation-editor')));
    await tester.pumpAndSettle();
    await capture('05_editor_before_reorder');

    final beforeOrder = service.draft!.steps.map((e) => e.label).toList();
    service.reorderDraftStep(2, 0);
    await tester.pumpAndSettle();
    expect(service.draft!.steps.first.label, beforeOrder[2]);
    await capture('06_editor_after_reorder');

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(service.draft!.steps, hasLength(2));
    await capture('07_editor_after_step_edit');

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    expect(service.draft, isNull);
    expect(service.items, hasLength(1));
    final savedId = service.items.single.id;

    await tester.tap(find.byKey(const ValueKey('open-custom-automation-manager')));
    await tester.pumpAndSettle();
    await capture('08_saved_item');
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await capture('09_rename_dialog');
    await tester.enterText(find.byType(TextField).last, '操作キャプチャ・改名済み');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(service.items.single.name, '操作キャプチャ・改名済み');
    await capture('10_after_rename');

    await tester.tap(find.byKey(ValueKey('custom-automation-favorite-$savedId')));
    await tester.pumpAndSettle();
    expect(service.isFavorite(savedId), isTrue);
    await capture('11_favorite_registered');

    await tester.tap(find.byKey(const ValueKey('custom-automation-favorites-only')));
    await tester.pumpAndSettle();
    expect(service.favoritesOnly, isTrue);
    expect(service.visibleItems, hasLength(1));
    await capture('12_favorites_only');

    await tester.tap(find.byKey(ValueKey('custom-automation-favorite-$savedId')));
    await tester.pumpAndSettle();
    expect(service.isFavorite(savedId), isFalse);
    expect(service.visibleItems, isEmpty);
    await capture('13_favorite_removed_while_filtered');

    await tester.tap(find.byKey(const ValueKey('custom-automation-favorites-only')));
    await tester.pumpAndSettle();
    expect(service.favoritesOnly, isFalse);
    expect(service.visibleItems, hasLength(1));
    await capture('14_all_items_after_unfavorite');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await capture('15_delete_confirmation');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(service.items, isEmpty);
    await capture('16_after_delete');

    File('${out.path}/interaction-proof.txt').writeAsStringSync(
      'recorded=true\n'
      'reordered=true\n'
      'edited=true\n'
      'renamed=true\n'
      'favorite_registered=true\n'
      'favorites_only=true\n'
      'favorite_removed=true\n'
      'deleted=true\n',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}

class _InteractionHost extends StatelessWidget {
  const _InteractionHost();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomAutomationService>();
    return MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(title: const Text('自動操作 実操作キャプチャ')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                service.isRecording
                    ? '記録中: ${service.draft?.name ?? ''} / ${service.draft?.steps.length ?? 0} steps'
                    : '記録停止',
                key: const ValueKey('recording-status'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('open-custom-automation-manager'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CustomAutomationManagerSheet(
                    surface: CustomAutomationSurface.canvas,
                    recordingStartFrame: 0,
                    frameCount: 1,
                    onExecute: (_, _, _) async {},
                    onRecordingStarted: () {},
                  ),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('自動操作を開く'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('open-custom-automation-editor'),
                onPressed: service.draft == null || service.isRecording
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CustomAutomationDraftEditorSheet(
                          surface: CustomAutomationSurface.canvas,
                          onResumeRecording: () {},
                          onSaved: () {},
                        ),
                      ),
                icon: const Icon(Icons.edit_note),
                label: const Text('記録内容を編集'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
