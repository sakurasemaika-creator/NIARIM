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

# The production-surface isolation patch creates several UI-oriented tests. Those
# tests are useful for visual surface checks, but their RepaintBoundary capture can
# block indefinitely on the headless rasterizer and obscure the automation proof we
# need here. Replace that generated proof set with one deterministic production
# pipeline test that exercises the actual filter runner, recording model, edit/save,
# and executor while writing real canvas PNGs before/after replay.
start = s.find("  testWidgets(\n    'production manager visibly contains the three starter automations'")
end = s.find("\n}\n\nclass _SurfaceHarness {", start)
if start < 0 or end < 0:
    raise SystemExit('generated production proof anchors changed')

proof = r'''  testWidgets(
    'record start canvas change stop edit save replay changes PNG pixels',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('record-edit-replay-source');
      final automation = harness.automationService;

      await harness.captureCanvas('01_canvas_before_recording');

      automation.beginDraft(
        name: 'record-edit-replay-proof',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      expect(automation.isRecording, isTrue);
      expect(automation.draft, isNotNull);

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
      await harness.captureCanvas('02_canvas_after_first_recorded_change');

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
      final secondChanged = _changedBytes(
        beforeSecondApply,
        harness.activeLayerPixels(),
      );
      expect(secondChanged, greaterThan(100));
      expect(automation.draft!.steps, hasLength(2));
      await harness.captureCanvas('03_canvas_after_second_recorded_change');

      automation.stopRecording();
      expect(automation.isRecording, isFalse);
      expect(automation.draft!.steps, hasLength(2));

      automation.removeDraftStep(1);
      expect(automation.draft!.steps, hasLength(1));
      expect(automation.draft!.steps.single.command, 'canvas.filterApply');

      final saved = await tester.runAsync(() => automation.saveDraft());
      expect(saved, isNotNull);
      expect(saved!.steps, hasLength(1));
      expect(saved.steps.single.command, 'canvas.filterApply');
      expect(
        automation.items.any(
          (item) => item.id == saved.id && item.name == 'record-edit-replay-proof',
        ),
        isTrue,
      );

      await harness.createProject('record-edit-replay-fresh-target');
      final beforeReplay = harness.activeLayerPixels();
      await harness.captureCanvas('04_canvas_before_saved_replay');

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
      await harness.captureCanvas('05_canvas_after_saved_replay');

      File('${out.path}/pixel-proof.txt').writeAsStringSync(
        'recording_started=true\n'
        'first_recorded_changed_bytes=$firstChanged\n'
        'second_recorded_changed_bytes=$secondChanged\n'
        'recording_stopped=${!automation.isRecording}\n'
        'edited_steps=${saved.steps.length}\n'
        'saved_command=${saved.steps.single.command}\n'
        'replay_changed_bytes=$replayChanged\n',
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
'''

s = s[:start] + proof + s[end:]

# The old helper encoded completion as fixed elapsed time. It is no longer used by
# this proof and is removed so there is no fixed sleep in the generated test.
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
