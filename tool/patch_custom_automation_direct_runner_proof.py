from pathlib import Path
import re

p = Path('test/custom_automation_production_surface_visual_test.dart')
s = p.read_text()

import_anchor = "import 'package:niarim/engine/custom_automation_executor.dart';\n"
runner_import = "import 'package:niarim/engine/custom_automation_filter_runner.dart';\n"
if runner_import not in s:
    if import_anchor not in s:
        raise SystemExit('automation executor import anchor changed')
    s = s.replace(import_anchor, import_anchor + runner_import, 1)

start = s.find("  testWidgets(\n    'real FilterPanel records Aurora, saves it, replays it, and changes canvas pixels'")
end = s.find("\n  testWidgets('production recording stop control stops the draft'", start)
if start < 0 or end < 0:
    raise SystemExit('generated record/replay proof anchors changed')

proof = r'''  testWidgets(
    'records a real Canvas change, edits, saves, replays, and changes PNG pixels',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('record-replay');
      final automation = harness.automationService;
      final l10n = harness.l10n;

      await harness.captureCanvas('02_canvas_before_recording');

      harness.showManager();
      await tester.pump();
      expect(find.text(l10n.customAutomationAdd), findsOneWidget);
      await tester.tap(find.text(l10n.customAutomationAdd));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'record-edit-replay-proof');
      await tester.tap(find.text(l10n.customAutomationStartRecording));
      await tester.pump();
      expect(automation.isRecording, isTrue);

      harness.filterService.selectFilter('Filter0019');
      final filter = harness.filterService.currentFilter!;
      final beforeFirstApply = harness.activeLayerPixels();
      await tester.runAsync(() async {
        await CustomAutomationFilterRunner.apply(
          projectService: harness.projectService,
          projectId: harness.projectId,
          sceneId: harness.sceneId,
          frameIndex: harness.frameIndex,
          sourceLayerId: harness.layerId,
          filter: filter,
        );
      });
      automation.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filterApply',
        label: filter.name,
        args: {'filter': filter.toJson()},
        recordedFrame: harness.frameIndex,
      );
      final afterFirstApply = harness.activeLayerPixels();
      final firstChanged = _changedBytes(beforeFirstApply, afterFirstApply);
      expect(firstChanged, greaterThan(100));
      expect(automation.draft!.steps, hasLength(1));
      await harness.captureCanvas('03_canvas_after_recorded_change');

      final beforeSecondApply = harness.activeLayerPixels();
      await tester.runAsync(() async {
        await CustomAutomationFilterRunner.apply(
          projectService: harness.projectService,
          projectId: harness.projectId,
          sceneId: harness.sceneId,
          frameIndex: harness.frameIndex,
          sourceLayerId: harness.layerId,
          filter: filter,
        );
      });
      automation.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filterApply',
        label: filter.name,
        args: {'filter': filter.toJson()},
        recordedFrame: harness.frameIndex,
      );
      expect(_changedBytes(beforeSecondApply, harness.activeLayerPixels()), greaterThan(100));
      expect(automation.draft!.steps, hasLength(2));

      harness.showRecordingStop();
      await tester.pump();
      await harness.capture('04_recording_stop_ui');
      await tester.tap(find.text(l10n.customAutomationStopRecording));
      await tester.pump();
      expect(automation.isRecording, isFalse);

      harness.showDraftEditor();
      await tester.pump();
      expect(find.text('canvas.filterApply'), findsNWidgets(2));
      await harness.capture('05_draft_editor_before_edit');
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pump();
      expect(automation.draft!.steps, hasLength(1));
      await harness.capture('06_draft_editor_after_edit');

      final saved = await tester.runAsync(() => automation.saveDraft());
      expect(saved, isNotNull);
      expect(saved!.steps, hasLength(1));
      expect(saved.steps.single.command, 'canvas.filterApply');

      await harness.createProject('record-replay-fresh-target');
      final beforeReplay = harness.activeLayerPixels();
      await harness.captureCanvas('07_canvas_before_saved_replay');

      harness.showManager();
      await tester.pump();
      expect(find.text('record-edit-replay-proof'), findsOneWidget);
      await harness.capture('08_manager_saved_item');

      await tester.runAsync(() async {
        await harness.execute(
          saved,
          CustomAutomationExecutionScope.currentFrame,
          null,
        );
      });
      final afterReplay = harness.activeLayerPixels();
      final replayChanged = _changedBytes(beforeReplay, afterReplay);
      expect(replayChanged, greaterThan(100));
      await harness.captureCanvas('09_canvas_after_saved_replay');

      File('${out.path}/pixel-proof.txt').writeAsStringSync(
        'recorded_changed_bytes=$firstChanged\n'
        'replay_changed_bytes=$replayChanged\n'
        'saved_steps=${saved.steps.length}\n'
        'saved_command=${saved.steps.single.command}\n',
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
'''

s = s[:start] + proof + s[end:]

# The old helper encoded completion as fixed elapsed time. It is no longer used by
# the production proof and is removed so the persisted proof contains no fixed sleep.
wait_pattern = re.compile(
    r"\n  Future<void> waitForProductionAsync\(\{int extraMilliseconds = 1500\}\) async \{.*?\n  \}\n",
    re.S,
)
s, count = wait_pattern.subn('\n', s, count=1)
if count != 1:
    raise SystemExit('fixed wait helper anchor changed')
if 'waitForProductionAsync' in s:
    raise SystemExit('fixed production wait remains')

p.write_text(s)
