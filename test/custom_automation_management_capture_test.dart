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

  Future<CustomAutomationService> serviceWithDraft() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'custom_automations_v1': <String>[],
      'custom_automation_favorites_v1': <String>[],
    });
    final service = CustomAutomationService();
    await service.init();
    service.beginDraft(
      name: '操作キャプチャ',
      surface: CustomAutomationSurface.canvas,
      recordingStartFrame: 0,
    );
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
    service.stopRecording();
    return service;
  }

  Future<void> capture(
    WidgetTester tester,
    GlobalKey captureKey,
    Directory out,
    String name,
  ) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('PNG encoding returned null');
        await File('${out.path}/$name.png')
            .writeAsBytes(data.buffer.asUint8List(), flush: true);
      } finally {
        image.dispose();
      }
    });
  }

  Widget app(CustomAutomationService service, Widget home, GlobalKey key) {
    return RepaintBoundary(
      key: key,
      child: ChangeNotifierProvider<CustomAutomationService>.value(
        value: service,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home),
        ),
      ),
    );
  }

  testWidgets('capture literal drag reorder and step edit', (tester) async {
    final out = Directory('build/visual-reaudit/custom-automation-management');
    out.createSync(recursive: true);
    final service = await serviceWithDraft();
    final key = GlobalKey();

    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        service,
        CustomAutomationDraftEditorSheet(
          surface: CustomAutomationSurface.canvas,
          onResumeRecording: () {},
          onSaved: () {},
        ),
        key,
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, out, '01_reorder_before');

    final originalFirst = service.draft!.steps.first.id;
    final lastHandle = find.byIcon(Icons.drag_handle).last;
    await tester.drag(lastHandle, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(service.draft!.steps.first.id, isNot(originalFirst));
    await capture(tester, key, out, '02_reorder_after_drag');

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(service.draft!.steps, hasLength(2));
    await capture(tester, key, out, '03_edit_after_step_delete');
  });

  testWidgets('capture favorite filter unfavorite and delete interactions', (
    tester,
  ) async {
    final out = Directory('build/visual-reaudit/custom-automation-management');
    out.createSync(recursive: true);
    final service = await serviceWithDraft();
    final saved = await service.saveDraft();
    expect(saved, isNotNull);
    final savedId = saved!.id;
    final key = GlobalKey();

    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        service,
        CustomAutomationManagerSheet(
          surface: CustomAutomationSurface.canvas,
          recordingStartFrame: 0,
          frameCount: 1,
          onExecute: (_, _, _) async {},
          onRecordingStarted: () {},
        ),
        key,
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, out, '04_saved_item');

    await tester.tap(
      find.byKey(ValueKey('custom-automation-favorite-$savedId')),
    );
    await tester.pumpAndSettle();
    expect(service.isFavorite(savedId), isTrue);
    await capture(tester, key, out, '05_favorite_registered');

    await tester.tap(
      find.byKey(const ValueKey('custom-automation-favorites-only')),
    );
    await tester.pumpAndSettle();
    expect(service.favoritesOnly, isTrue);
    expect(service.visibleItems, hasLength(1));
    await capture(tester, key, out, '06_favorites_only');

    await tester.tap(
      find.byKey(ValueKey('custom-automation-favorite-$savedId')),
    );
    await tester.pumpAndSettle();
    expect(service.isFavorite(savedId), isFalse);
    expect(service.visibleItems, isEmpty);
    await capture(tester, key, out, '07_favorite_removed_filtered');

    await tester.tap(
      find.byKey(const ValueKey('custom-automation-favorites-only')),
    );
    await tester.pumpAndSettle();
    expect(service.favoritesOnly, isFalse);
    expect(service.visibleItems, hasLength(1));
    await capture(tester, key, out, '08_all_items_after_unfavorite');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await capture(tester, key, out, '09_delete_confirmation');

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(service.items, isEmpty);
    await capture(tester, key, out, '10_after_delete');
  });
}
