from pathlib import Path

p = Path('test/custom_automation_production_surface_visual_test.dart')
s = p.read_text()

start_marker = "  testWidgets(\n    'production automation surfaces record a real Aurora filter and replay it',"
end_marker = "\n}\n\nclass _SurfaceHarness"

if "production automation records a real Aurora filter and replays pixels" not in s:
    start = s.find(start_marker)
    if start < 0:
        raise SystemExit('test section start anchor changed')
    end = s.find(end_marker, start)
    if end < 0:
        raise SystemExit('test section end anchor changed')

    tests = r'''  testWidgets(
    'manager surface shows all three starter automations',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('manager-evidence');
      harness.showManager();
      await tester.pump();
      expect(find.text('オーロラホログラム'), findsOneWidget);
      expect(find.text('線画抽出'), findsOneWidget);
      expect(find.text('線画作成'), findsOneWidget);
      await harness.capture('01_manager_open');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recording stop surface is visible while automation is recording',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('recording-evidence');
      harness.automationService.beginDraft(
        name: 'visual-audit-automation',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      harness.showRecordingStop();
      await tester.pump();
      expect(find.byType(CustomAutomationRecordingStopButton), findsOneWidget);
      await harness.capture('02_recording_started');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'production automation records a real Aurora filter and replays pixels',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('record-replay');
      final automation = harness.automationService;
      final l10n = harness.l10n;

      await harness.captureLayer('03_canvas_before_real_aurora_apply');
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
      await harness.capture('04_aurora_filter_panel_during_recording');

      final beforeApply = harness.activeLayerPixels();
      await tester.tap(find.text(l10n.filterApplyButton));
      await harness.waitForProductionAsync();
      final afterApply = harness.activeLayerPixels();
      expect(
        _changedBytes(beforeApply, afterApply),
        greaterThan(100),
        reason: 'The production FilterPanel Apply action must change real pixels',
      );
      expect(automation.draft, isNotNull);
      expect(automation.draft!.steps, hasLength(1));
      expect(automation.draft!.steps.single.command, 'canvas.filterApply');
      await harness.captureLayer('05_canvas_after_real_aurora_apply');

      automation.stopRecording();
      expect(automation.isRecording, isFalse);
      final saved = await automation.saveDraft();
      expect(saved, isNotNull);
      expect(automation.draft, isNull);
      expect(
        automation.items.any((item) => item.name == 'visual-audit-automation'),
        isTrue,
      );

      final beforeReplay = harness.activeLayerPixels();
      await harness.execute(
        saved!,
        CustomAutomationExecutionScope.currentFrame,
        null,
      );
      await harness.waitForProductionAsync();
      final afterReplay = harness.activeLayerPixels();
      expect(
        _changedBytes(beforeReplay, afterReplay),
        greaterThan(100),
        reason: 'Saved automation replay must change real pixels again',
      );
      await harness.captureLayer('08_canvas_after_replay');
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'draft editor renders the recorded filter step',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('editor-evidence');
      final automation = harness.automationService;
      automation.beginDraft(
        name: 'visual-audit-automation',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      automation.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filterApply',
        label: 'オーロラホログラム',
      );
      automation.stopRecording();
      harness.showDraftEditor();
      await tester.pump();
      expect(find.text('canvas.filterApply'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
      await harness.capture('06_draft_editor');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved automation is visible in the production manager',
    (tester) async {
      final harness = await _SurfaceHarness.create(tester, out);
      await harness.createProject('saved-manager-evidence');
      final automation = harness.automationService;
      automation.beginDraft(
        name: 'visual-audit-automation',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: harness.frameIndex,
      );
      automation.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filterApply',
        label: 'オーロラホログラム',
      );
      automation.stopRecording();
      final saved = await automation.saveDraft();
      expect(saved, isNotNull);
      harness.showManager();
      await tester.pump();
      expect(find.text('visual-audit-automation'), findsOneWidget);
      await harness.capture('07_manager_saved_item');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'three starter automations visibly change production canvas output',
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
        await harness.captureLayer('preset_${entry.$2}_00_before');

        final preset = harness.automationService.items
            .where((item) => item.name == entry.$1)
            .single;
        await harness.execute(
          preset,
          CustomAutomationExecutionScope.currentFrame,
          null,
        );
        await harness.waitForProductionAsync(extraMilliseconds: 2200);

        if (!entry.$3) {
          expect(
            _changedBytes(beforePixels, harness.activeLayerPixels()),
            greaterThan(100),
            reason: '${entry.$1} must visibly change source pixels',
          );
          await harness.captureLayer('preset_${entry.$2}_01_after');
        } else {
          final afterLayers = harness.normalLayerIds();
          final generated = afterLayers.difference(beforeLayers);
          expect(
            generated,
            isNotEmpty,
            reason: '${entry.$1} must create an output layer',
          );
          final layers = harness.projectService.layersOf(
            harness.projectId,
            harness.sceneId,
            harness.frameIndex,
          );
          final normalLayers = layers
              .where((layer) => layer.type == model.LayerType.normal)
              .toList();
          expect(normalLayers.first.id, generated.first);
          expect(
            _nonTransparentPixels(harness.layerPixels(generated.first)),
            greaterThan(50),
            reason: '${entry.$1} output layer must contain visible pixels',
          );
          await harness.captureLayer(
            'preset_${entry.$2}_01_after',
            layerId: generated.first,
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );'''

    s = s[:start] + tests + end_marker + s[end + len(end_marker):]

if 'Future<void> captureLayer(' not in s:
    anchor = '  Future<void> capture(String name) async {'
    if anchor not in s:
        raise SystemExit('capture anchor changed')
    method = r'''  Future<void> captureLayer(String name, {String? layerId}) async {
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(
      projectId,
      sceneId,
      frameIndex,
      layerId ?? this.layerId,
    );
    final bytes = await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final result = data!.buffer.asUint8List();
      image.dispose();
      return result;
    });
    File('${out.path}/$name.png').writeAsBytesSync(bytes!);
  }

'''
    s = s.replace(anchor, method + anchor, 1)

p.write_text(s)
