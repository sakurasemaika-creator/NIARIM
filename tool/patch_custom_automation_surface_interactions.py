from pathlib import Path
import re

p = Path('test/custom_automation_production_surface_visual_test.dart')
s = p.read_text()

start = s.find("  testWidgets(\n    'production automation surfaces record a real Aurora filter and replay it'")
end = s.find('\nclass _SurfaceHarness {', start)
if start < 0 or end < 0:
    raise SystemExit('visual proof test block anchors changed')

proofs = r'''  testWidgets(
    'production manager visibly contains the three starter automations',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('manager-starters');
      harness.showManager();
      await tester.pump();
      expect(find.text('オーロラホログラム'), findsOneWidget);
      expect(find.text('線画抽出'), findsOneWidget);
      expect(find.text('線画作成'), findsOneWidget);
      await harness.capture('01_manager_three_starters');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real FilterPanel records Aurora, saves it, replays it, and changes canvas pixels',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('record-replay');
      final automation = harness.automationService;
      final l10n = harness.l10n;

      await harness.captureCanvas('02_canvas_before_recording');
      automation.beginDraft(
        name: 'visual-audit-automation',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      expect(automation.isRecording, isTrue);

      harness.filterService.selectFilter('Filter0019');
      harness.showFilterPanel();
      await tester.pump();
      await harness.waitForProductionAsync();
      expect(find.byType(FilterPanel), findsOneWidget);
      await harness.capture('03_recording_aurora_filter_panel');

      final beforeApply = harness.activeLayerPixels();
      await tester.tap(find.text(l10n.filterApplyButton));
      await harness.waitForProductionAsync();
      final afterApply = harness.activeLayerPixels();
      expect(_changedBytes(beforeApply, afterApply), greaterThan(100));
      expect(automation.draft, isNotNull);
      expect(automation.draft!.steps, hasLength(1));
      expect(automation.draft!.steps.single.command, 'canvas.filterApply');
      await harness.captureCanvas('04_canvas_after_recorded_aurora');

      automation.stopRecording();
      expect(automation.isRecording, isFalse);
      final saved = await automation.saveDraft();
      expect(saved, isNotNull);
      expect(saved!.steps.single.command, 'canvas.filterApply');

      final beforeReplay = harness.activeLayerPixels();
      await harness.execute(
        saved,
        CustomAutomationExecutionScope.currentFrame,
        null,
      );
      final afterReplay = harness.activeLayerPixels();
      expect(_changedBytes(beforeReplay, afterReplay), greaterThan(100));
      await harness.captureCanvas('09_canvas_after_saved_replay');
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets('production recording stop control stops the draft', (tester) async {
    final harness = await _SurfaceHarness.create(tester, out);
    await harness.createProject('stop-ui');
    harness.automationService.beginDraft(
      name: 'visual-audit-automation',
      surface: CustomAutomationSurface.canvas,
      recordingStartFrame: harness.frameIndex,
    );
    harness.showRecordingStop();
    await tester.pump();
    expect(find.byType(CustomAutomationRecordingStopButton), findsOneWidget);
    await harness.capture('05_recording_stop_ui');
    await tester.tap(find.text(harness.l10n.customAutomationStopRecording));
    await tester.pump();
    expect(harness.automationService.isRecording, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production draft editor visibly edits recorded steps', (tester) async {
    final harness = await _SurfaceHarness.create(tester, out);
    await harness.createProject('editor-ui');
    final automation = harness.automationService;
    automation.beginDraft(
      name: 'visual-audit-automation',
      surface: CustomAutomationSurface.canvas,
      recordingStartFrame: harness.frameIndex,
    );
    final starter = automation.items
        .where((item) => item.name == 'オーロラホログラム')
        .single;
    final step = starter.steps.single;
    for (var i = 0; i < 2; i++) {
      automation.recordStep(
        surface: step.surface,
        command: step.command,
        label: step.label,
        args: step.args,
        changesFrame: step.changesFrame,
        recordedFrame: step.recordedFrame,
      );
    }
    automation.stopRecording();
    expect(automation.draft!.steps, hasLength(2));
    harness.showDraftEditor();
    await tester.pump();
    expect(find.text('canvas.filterApply'), findsNWidgets(2));
    await harness.capture('06_draft_editor_before_edit');
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pump();
    expect(automation.draft!.steps, hasLength(1));
    await harness.capture('07_draft_editor_after_edit');
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved automation is visible and opens production replay confirmation',
      (tester) async {
    final harness = await _SurfaceHarness.create(tester, out);
    await harness.createProject('saved-manager');
    final automation = harness.automationService;
    final starter = automation.items
        .where((item) => item.name == 'オーロラホログラム')
        .single;
    final step = starter.steps.single;
    automation.beginDraft(
      name: 'visual-audit-automation',
      surface: CustomAutomationSurface.canvas,
      recordingStartFrame: harness.frameIndex,
    );
    automation.recordStep(
      surface: step.surface,
      command: step.command,
      label: step.label,
      args: step.args,
      changesFrame: step.changesFrame,
      recordedFrame: step.recordedFrame,
    );
    automation.stopRecording();
    final saved = await automation.saveDraft();
    expect(saved, isNotNull);

    harness.showManager();
    await tester.pump();
    expect(find.text('visual-audit-automation'), findsOneWidget);
    await harness.capture('08_manager_saved_item');
    await tester.tap(find.text('visual-audit-automation'));
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text(harness.l10n.customAutomationRunConfirmTitle), findsOneWidget);
    await harness.capture('08b_replay_confirmation');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'three starter automations change real canvas output through the production executor',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      final cases = <(String, String, bool)>[
        ('オーロラホログラム', 'aurora_hologram', false),
        ('線画抽出', 'line_extraction', true),
        ('線画作成', 'line_creation', true),
      ];

      for (final entry in cases) {
        await harness.createProject('preset-${entry.$2}');
        final beforePixels = harness.activeLayerPixels();
        final beforeLayers = harness.normalLayerIds();
        await harness.captureCanvas('preset_${entry.$2}_01_before');
        final preset = harness.automationService.items
            .where((item) => item.name == entry.$1)
            .single;
        await harness.execute(
          preset,
          CustomAutomationExecutionScope.currentFrame,
          null,
        );

        if (!entry.$3) {
          expect(
            _changedBytes(beforePixels, harness.activeLayerPixels()),
            greaterThan(100),
            reason: '${entry.$1} must visibly change source pixels',
          );
          await harness.captureCanvas('preset_${entry.$2}_02_after');
        } else {
          final generated = harness.normalLayerIds().difference(beforeLayers);
          expect(generated, isNotEmpty,
              reason: '${entry.$1} must create an output layer');
          final generatedId = generated.first;
          expect(
            _nonTransparentPixels(harness.layerPixels(generatedId)),
            greaterThan(50),
            reason: '${entry.$1} output layer must contain visible pixels',
          );
          await harness.captureCanvas(
            'preset_${entry.$2}_02_after',
            targetLayerId: generatedId,
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
'''

s = s[:start] + proofs + s[end:]

capture_anchor = '''  Future<void> capture(String name) async {
'''
if 'Future<void> captureCanvas(' not in s:
    if capture_anchor not in s:
        raise SystemExit('capture anchor changed')
    canvas_method = r'''  Future<void> captureCanvas(
    String name, {
    String? targetLayerId,
  }) async {
    final id = targetLayerId ?? layerId;
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, id);
    final png = await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    File('${out.path}/$name.png').writeAsBytesSync(png!);
  }

'''
    s = s.replace(capture_anchor, canvas_method + capture_anchor, 1)

# Keep production widgets, but remove route-pop side effects from the test-only host callbacks.
s = s.replace(
    '        onClose: () => Navigator.pop(routeContext),',
    '        onClose: () {},',
    1,
)
s = s.replace(
    '''              onStop: () {
                automationService.stopRecording();
                Navigator.pop(routeContext);
              },''',
    '''              onStop: () {
                automationService.stopRecording();
              },''',
    1,
)

# Each test mounts one production surface only. A direct keyed host avoids introducing
# a nested Navigator that is unrelated to the feature under proof.
host_pattern = re.compile(
    r"class _SurfaceHostState extends State<_SurfaceHost> \{.*?\n\}\n\nint _changedBytes",
    re.S,
)
host_replacement = '''class _SurfaceHostState extends State<_SurfaceHost> {
  WidgetBuilder? _builder;
  int _generation = 0;

  void show(Widget widget) => showBuilder((_) => widget);

  void showBuilder(WidgetBuilder builder) {
    setState(() {
      _builder = builder;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final builder = _builder;
    if (builder == null) return const Scaffold(body: SizedBox.expand());
    return KeyedSubtree(
      key: ValueKey(_generation),
      child: Scaffold(body: SafeArea(child: builder(context))),
    );
  }
}

int _changedBytes'''
s, n = host_pattern.subn(host_replacement, s, count=1)
if n != 1:
    raise SystemExit('surface host anchor changed')

p.write_text(s)
