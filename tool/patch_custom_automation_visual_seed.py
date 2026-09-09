from pathlib import Path

p = Path('test/custom_automation_production_visual_test.dart')
s = p.read_text()

old_seed = """    final tile = tm.getOrCreateTile(key, 0, 0);
    tile.fillRange(0, tile.length, 0);
    for (var y = 36; y < 284; y++) {
      for (var x = 36; x < 284; x++) {
        final i = (y * TileManager.tileSize + x) * 4;
        var shade = 20 + ((x - 36) * 225 ~/ 247);
        if ((x > 92 && x < 118) || (y > 148 && y < 174)) {
          shade = 18;
        }
        if (x > 188 && x < 242 && y > 78 && y < 132) {
          shade = 235;
        }
        tile[i] = shade;
        tile[i + 1] = shade;
        tile[i + 2] = shade;
        tile[i + 3] = 255;
      }
    }
    tm.invalidateTile(key, 0, 0);
"""
new_seed = """    for (var ty = 0; ty < tm.tilesY; ty++) {
      for (var tx = 0; tx < tm.tilesX; tx++) {
        final tile = tm.getOrCreateTile(key, tx, ty);
        tile.fillRange(0, tile.length, 0);
        for (var localY = 0; localY < TileManager.tileSize; localY++) {
          final y = ty * TileManager.tileSize + localY;
          if (y >= tm.canvasHeight) continue;
          for (var localX = 0; localX < TileManager.tileSize; localX++) {
            final x = tx * TileManager.tileSize + localX;
            if (x >= tm.canvasWidth) continue;
            if (x < 36 || x >= 284 || y < 36 || y >= 284) continue;
            final i = (localY * TileManager.tileSize + localX) * 4;
            var shade = 20 + ((x - 36) * 225 ~/ 247);
            if ((x > 92 && x < 118) || (y > 148 && y < 174)) {
              shade = 18;
            }
            if (x > 188 && x < 242 && y > 78 && y < 132) {
              shade = 235;
            }
            tile[i] = shade;
            tile[i + 1] = shade;
            tile[i + 2] = shade;
            tile[i + 3] = 255;
          }
        }
        tm.invalidateTile(key, tx, ty);
      }
    }
"""
if old_seed in s:
    s = s.replace(old_seed, new_seed, 1)
elif new_seed not in s:
    raise SystemExit('canvas seed anchor changed')

old_manager = """  void showManager() {
    final context = canvasContext;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CustomAutomationManagerSheet(
          surface: CustomAutomationSurface.canvas,
          recordingStartFrame: canvasWidget.currentFrame,
          frameCount: projectService.frameCount(
            projectId,
            canvasWidget.sceneId,
          ),
          onRecordingStarted: () {},
          onExecute: _execute,
        ),
      ),
    );
  }
"""
new_manager = """  void showManager() {
    final context = canvasContext;
    unawaited(
      Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
            body: SafeArea(
              child: CustomAutomationManagerSheet(
                surface: CustomAutomationSurface.canvas,
                recordingStartFrame: canvasWidget.currentFrame,
                frameCount: projectService.frameCount(
                  projectId,
                  canvasWidget.sceneId,
                ),
                onRecordingStarted: () {},
                onExecute: _execute,
              ),
            ),
          ),
        ),
      ),
    );
  }
"""
if old_manager not in s:
    raise SystemExit('manager route anchor changed')
s = s.replace(old_manager, new_manager, 1)

old_filter = """  void showFilterPanel() {
    final context = canvasContext;
    final canvas = canvasWidget;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Center(
          child: FilterPanel(
            projectId: projectId,
            sceneId: canvas.sceneId,
            layerId: canvas.currentLayerId,
            frameIndex: canvas.currentFrame,
            onClose: () => Navigator.pop(sheetContext),
          ),
        ),
      ),
    );
  }
"""
new_filter = """  void showFilterPanel() {
    final context = canvasContext;
    final canvas = canvasWidget;
    unawaited(
      Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (routeContext, animation, secondaryAnimation) => Scaffold(
            body: SafeArea(
              child: FilterPanel(
                projectId: projectId,
                sceneId: canvas.sceneId,
                layerId: canvas.currentLayerId,
                frameIndex: canvas.currentFrame,
                onClose: () => Navigator.pop(routeContext),
              ),
            ),
          ),
        ),
      ),
    );
  }
"""
if old_filter not in s:
    raise SystemExit('filter route anchor changed')
s = s.replace(old_filter, new_filter, 1)

old_stop = """  void showRecordingStop() {
    final context = canvasContext;
    final service = automationService;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => CustomAutomationRecordingStopButton(
          onStop: () {
            service.stopRecording();
            Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }
"""
new_stop = """  void showRecordingStop() {
    final context = canvasContext;
    final service = automationService;
    unawaited(
      Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (routeContext, animation, secondaryAnimation) => Scaffold(
            body: SafeArea(
              child: Center(
                child: CustomAutomationRecordingStopButton(
                  onStop: () {
                    service.stopRecording();
                    Navigator.pop(routeContext);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
"""
if old_stop not in s:
    raise SystemExit('stop route anchor changed')
s = s.replace(old_stop, new_stop, 1)

old_draft = """  void showDraftEditor() {
    final context = canvasContext;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CustomAutomationDraftEditorSheet(
          surface: CustomAutomationSurface.canvas,
          onResumeRecording: () {},
          onSaved: () {},
        ),
      ),
    );
  }
"""
new_draft = """  void showDraftEditor() {
    final context = canvasContext;
    unawaited(
      Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => const Scaffold(
            body: SafeArea(
              child: CustomAutomationDraftEditorSheet(
                surface: CustomAutomationSurface.canvas,
                onResumeRecording: _noop,
                onSaved: _noop,
              ),
            ),
          ),
        ),
      ),
    );
  }
"""
# Const callbacks cannot refer to a top-level function through this generated
# replacement without introducing another anchor; keep the page non-const.
new_draft = new_draft.replace('=> const Scaffold(', '=> Scaffold(').replace('onResumeRecording: _noop,', 'onResumeRecording: () {},').replace('onSaved: _noop,', 'onSaved: () {},')
if old_draft not in s:
    raise SystemExit('draft route anchor changed')
s = s.replace(old_draft, new_draft, 1)

s = s.replace("import 'dart:typed_data';\n", '')
s = s.replace('handleCanvasStateCommand: (_, __) async {},', 'handleCanvasStateCommand: (_, _) async {},')

# Stage markers make future hangs attributable to one production UI action.
s = s.replace("      await harness.capture('00_canvas_before_recording');", "      debugPrint('AUTOMATION_PROD_STAGE=00_before_capture');\n      await harness.capture('00_canvas_before_recording');\n      debugPrint('AUTOMATION_PROD_STAGE=01_open_manager');")
s = s.replace("      await harness.capture('01_manager_open');", "      await harness.capture('01_manager_open');\n      debugPrint('AUTOMATION_PROD_STAGE=02_manager_captured');")
s = s.replace("      await harness.capture('02_recording_started');", "      await harness.capture('02_recording_started');\n      debugPrint('AUTOMATION_PROD_STAGE=03_recording_started');")
s = s.replace("      await harness.capture('03_aurora_filter_panel_during_recording');", "      await harness.capture('03_aurora_filter_panel_during_recording');\n      debugPrint('AUTOMATION_PROD_STAGE=04_filter_panel_captured');")
s = s.replace("      await harness.capture('04_real_aurora_applied_and_recorded');", "      await harness.capture('04_real_aurora_applied_and_recorded');\n      debugPrint('AUTOMATION_PROD_STAGE=05_filter_recorded');")

p.write_text(s)
