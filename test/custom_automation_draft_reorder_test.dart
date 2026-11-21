import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/widgets/custom_automation_draft_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('final reorder index converts to the service pre-removal contract', () {
    expect(customAutomationDraftPreRemovalIndex(0, 2), 3);
    expect(customAutomationDraftPreRemovalIndex(2, 0), 0);
    expect(customAutomationDraftPreRemovalIndex(1, 1), 1);
  });

  for (final moveDown in [true, false]) {
    testWidgets('draft reorder preserves final order: down=$moveDown', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomAutomationService();
      await tester.runAsync(service.init);
      addTearDown(service.dispose);
      service.beginDraft(
        name: 'Reorder audit',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: 0,
      );
      for (final label in ['First', 'Second', 'Third']) {
        service.recordStep(
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.addLayer',
          label: label,
          recordedFrame: 0,
        );
      }
      service.stopRecording();
      final originalIds = service.draft!.steps.map((step) => step.id).toList();
      await tester.pumpWidget(
        ChangeNotifierProvider<CustomAutomationService>.value(
          value: service,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomAutomationDraftSheet(
                surface: CustomAutomationSurface.canvas,
                onResumeRecording: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ReorderableListViewのpointer/gap animation自体はFlutter側の責務。
      // NIARIMが担う最終index→service index変換と、その結果を直接検証する。
      final oldIndex = moveDown ? 0 : 2;
      final finalIndex = moveDown ? 2 : 0;
      service.reorderDraftStep(
        oldIndex,
        customAutomationDraftPreRemovalIndex(oldIndex, finalIndex),
      );
      await tester.pump();

      final expectedIds = moveDown
          ? [originalIds[1], originalIds[2], originalIds[0]]
          : [originalIds[2], originalIds[0], originalIds[1]];
      expect(service.draft!.steps.map((step) => step.id), expectedIds);
      final visibleOrder = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .where((tile) => tile.key is ValueKey<String>)
          .map((tile) => (tile.key! as ValueKey<String>).value);
      expect(visibleOrder, expectedIds);
      expect(
        find.descendant(
          of: find.byKey(ValueKey(expectedIds.first)),
          matching: find.byType(ReorderableDragStartListener),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
