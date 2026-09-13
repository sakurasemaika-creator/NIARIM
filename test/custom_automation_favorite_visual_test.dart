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
  final out = Directory('build/visual-reaudit/custom-automation-favorites');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    out.createSync(recursive: true);
  });

  testWidgets(
    'register edit reorder rename favorite filter unfavorite delete with screenshots',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = CustomAutomationService();
      await service.init();
      final rootKey = GlobalKey();

      Widget manager() => CustomAutomationManagerSheet(
        surface: CustomAutomationSurface.canvas,
        onExecute: (_, _, _) async {},
        onRecordingStarted: () {},
        recordingStartFrame: 0,
        frameCount: 1,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: manager()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> capture(String name) async {
        await tester.pump(const Duration(milliseconds: 100));
        final boundary =
            rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File('${out.path}/$name.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }

      service.beginDraft(
        name: '登録した自動操作',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: 0,
      );
      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.tool',
        label: 'ペン',
        args: const {'tool': 'pen'},
        recordedFrame: 0,
      );
      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.brushSize',
        label: 'サイズ',
        args: const {'value': 12.0},
        recordedFrame: 0,
      );
      service.stopRecording();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: CustomAutomationDraftEditorSheet(
                  surface: CustomAutomationSurface.canvas,
                  onResumeRecording: () {},
                  onSaved: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture('01_registered_and_editing');

      service.reorderDraftStep(1, 0);
      await tester.pump();
      expect(service.draft!.steps.first.command, 'canvas.brushSize');
      await capture('02_reordered');

      final saved = await service.saveDraft();
      expect(saved, isNotNull);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: service,
          child: RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: manager()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final itemId = saved!.id;
      final row = find.byKey(ValueKey(itemId));
      expect(row, findsOneWidget);
      await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.edit)));
      await tester.pumpAndSettle();
      final renameField = find.byType(TextField);
      await tester.enterText(renameField, 'お気に入り自動操作');
      final l10n = AppLocalizations.of(tester.element(renameField))!;
      await tester.tap(find.text(l10n.commonSave));
      await tester.pumpAndSettle();
      expect(find.text('お気に入り自動操作'), findsOneWidget);
      await capture('03_renamed');

      await tester.tap(
        find.byKey(ValueKey('custom-automation-favorite-$itemId')),
      );
      await tester.pumpAndSettle();
      expect(service.isFavorite(itemId), isTrue);
      await capture('04_favorited');

      await tester.tap(
        find.byKey(const ValueKey('custom-automation-favorites-only')),
      );
      await tester.pumpAndSettle();
      expect(service.favoritesOnly, isTrue);
      expect(service.visibleItems.map((item) => item.id), [itemId]);
      await capture('05_favorites_only');

      await tester.tap(
        find.byKey(ValueKey('custom-automation-favorite-$itemId')),
      );
      await tester.pumpAndSettle();
      expect(service.isFavorite(itemId), isFalse);
      expect(service.visibleItems, isEmpty);
      await capture('06_unfavorited_empty');

      await tester.tap(
        find.byKey(const ValueKey('custom-automation-favorites-only')),
      );
      await tester.pumpAndSettle();
      final restoredRow = find.byKey(ValueKey(itemId));
      await tester.tap(
        find.descendant(of: restoredRow, matching: find.byIcon(Icons.delete_outline)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();
      expect(service.items.any((item) => item.id == itemId), isFalse);
      await capture('07_deleted');
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
