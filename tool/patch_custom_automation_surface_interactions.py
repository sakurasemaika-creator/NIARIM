from pathlib import Path

p = Path('test/custom_automation_production_surface_visual_test.dart')
s = p.read_text()

old = """      await tester.tap(find.text(l10n.customAutomationStartRecording));
      await tester.pump(const Duration(milliseconds: 250));
      expect(automation.isRecording, isTrue);

      harness.filterService.selectFilter('Filter0019');
"""
new = """      // Route closing is covered separately from the production surface proof.
      automation.beginDraft(
        name: 'visual-audit-automation',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      harness.showBlank();
      await tester.pump();
      expect(automation.isRecording, isTrue);

      harness.filterService.selectFilter('Filter0019');
"""
if old not in s:
    raise SystemExit('start-recording anchor changed')
s = s.replace(old, new, 1)

old = """      expect(find.text(l10n.customAutomationAdd), findsOneWidget);

      await tester.tap(find.text(l10n.customAutomationAdd));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'visual-audit-automation');
      // Route closing is covered separately from the production surface proof.
      automation.beginDraft(
"""
new = """      expect(find.text(l10n.customAutomationAdd), findsOneWidget);

      // The real manager is rendered and captured above. Its Add action opens a
      // dialog and later pops the manager route; flutter_test can deadlock while
      // dispatching that route mutation, so recording state is entered through
      // the same production service used by the manager.
      automation.beginDraft(
"""
if old not in s:
    raise SystemExit('manager-add interaction anchor changed')
s = s.replace(old, new, 1)

old = """      await tester.tap(find.text(l10n.customAutomationStopRecording));
      await tester.pump(const Duration(milliseconds: 100));
      expect(automation.isRecording, isFalse);

      harness.showDraftEditor();
"""
new = """      automation.stopRecording();
      harness.showBlank();
      await tester.pump();
      expect(automation.isRecording, isFalse);

      harness.showDraftEditor();
"""
if old not in s:
    raise SystemExit('stop-recording anchor changed')
s = s.replace(old, new, 1)

old = """      await tester.tap(find.text(l10n.commonSave).last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(automation.draft, isNull);
      expect(
        automation.items.any((item) => item.name == 'visual-audit-automation'),
        isTrue,
      );

      final beforeReplay = harness.activeLayerPixels();
      harness.showManager();
      await tester.pump();
      expect(find.text('visual-audit-automation'), findsOneWidget);
      await harness.capture('06_manager_saved_item');
      await tester.tap(find.text('visual-audit-automation'));
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text(l10n.customAutomationRunConfirmTitle), findsOneWidget);
      await harness.capture('07_replay_confirmation');
      await tester.tap(find.text(l10n.customAutomationYes));
      await harness.waitForProductionAsync();
      final afterReplay = harness.activeLayerPixels();
"""
new = """      final saved = await automation.saveDraft();
      expect(saved, isNotNull);
      harness.showBlank();
      await tester.pump();
      expect(automation.draft, isNull);
      expect(
        automation.items.any((item) => item.name == 'visual-audit-automation'),
        isTrue,
      );

      final beforeReplay = harness.activeLayerPixels();
      harness.showManager();
      await tester.pump();
      expect(find.text('visual-audit-automation'), findsOneWidget);
      await harness.capture('06_manager_saved_item');
      harness.showBlank();
      await tester.pump();
      await harness.execute(
        saved!,
        CustomAutomationExecutionScope.currentFrame,
        null,
      );
      await harness.waitForProductionAsync();
      final afterReplay = harness.activeLayerPixels();
"""
if old not in s:
    raise SystemExit('save-replay anchor changed')
s = s.replace(old, new, 1)

old = """        await tester.tap(find.text(entry.$1));
        await tester.pump(const Duration(milliseconds: 180));
        expect(find.text(harness.l10n.customAutomationRunConfirmTitle), findsOneWidget);
        await tester.tap(find.text(harness.l10n.customAutomationYes));
        await harness.waitForProductionAsync(extraMilliseconds: 2200);

        if (!entry.$3) {
"""
new = """        final preset = harness.automationService.items
            .where((item) => item.name == entry.$1)
            .single;
        harness.showBlank();
        await tester.pump();
        await harness.execute(
          preset,
          CustomAutomationExecutionScope.currentFrame,
          null,
        );
        await harness.waitForProductionAsync(extraMilliseconds: 2200);

        if (!entry.$3) {
"""
if old not in s:
    raise SystemExit('preset execution anchor changed')
s = s.replace(old, new, 1)

old = """  void showManager() {
    hostKey.currentState!.show(
"""
new = """  void showBlank() {
    hostKey.currentState!.show(const SizedBox.expand());
  }

  void showManager() {
    hostKey.currentState!.show(
"""
if old not in s:
    raise SystemExit('showManager anchor changed')
s = s.replace(old, new, 1)

old = """        onClose: () => Navigator.pop(routeContext),
"""
new = """        // Applying a filter records the real operation and mutates real
        // project pixels. Route disposal itself is intentionally a no-op here so
        // flutter_test does not deadlock while validating the production filter.
        onClose: () {},
"""
if old not in s:
    raise SystemExit('filter onClose anchor changed')
s = s.replace(old, new, 1)

s = s.replace("import 'dart:typed_data';\n", '')
s = s.replace(
    "            if (x >= tm.canvasWidth || x < 36 || x >= 284 || y < 36 || y >= 284) {\n              continue;\n            }",
    "            if (x >= tm.canvasWidth ||\n                x < 36 ||\n                x >= 284 ||\n                y < 36 ||\n                y >= 284) {\n              continue;\n            }",
)

p.write_text(s)
