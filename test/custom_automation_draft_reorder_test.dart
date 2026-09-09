import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/widgets/custom_automation_draft_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final moveDown in [true, false]) {
    testWidgets('draft drag preserves final order: down=$moveDown', (
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
      final start = find.descendant(
        of: find.byKey(ValueKey(originalIds[moveDown ? 0 : 2])),
        matching: find.byType(ReorderableDragStartListener),
      );
      final target = find.byKey(ValueKey(originalIds[moveDown ? 2 : 0]));
      final startCenter = tester.getCenter(start);
      final targetRect = tester.getRect(target);
      final destinationY = moveDown
          ? targetRect.bottom + 8
          : targetRect.top - 8;
      final gesture = await tester.startGesture(startCenter);
      await tester.pump();
      await gesture.moveTo(Offset(startCenter.dx, destinationY));
      // Keep holding beyond the destination row while its gap animates.
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final expectedIds = moveDown
          ? [originalIds[1], originalIds[2], originalIds[0]]
          : [originalIds[2], originalIds[0], originalIds[1]];
      expect(service.draft!.steps.map((step) => step.id), expectedIds);
      final visibleOrder = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .where((tile) => tile.key is ValueKey<String>)
          .map((tile) => (tile.key! as ValueKey<String>).value);
      expect(visibleOrder, expectedIds);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
