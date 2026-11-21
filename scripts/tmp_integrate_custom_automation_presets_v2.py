from pathlib import Path

# Keep Aurora/Hologram as a drawing filter. The user-selectable color/preset state
# makes it a poor fixed automation recipe, so do not retire Filter0019 here.

# 1) Seed official automation presets once, preserving user-edited copies.
p = Path('lib/services/custom_automation_service.dart')
s = p.read_text()
if "custom_automation_builtin_presets.dart" not in s:
    s = s.replace(
        "import '../models/custom_automation.dart';\n",
        "import '../models/custom_automation.dart';\nimport '../models/custom_automation_builtin_presets.dart';\n",
    )
if 'CustomAutomationBuiltinPresets.all()' not in s:
    needle = """      );\n    notifyListeners();\n  }\n\n  Future<void> _persist() async {"""
    replacement = """      );\n    var addedBuiltin = false;\n    final existingIds = _items.map((item) => item.id).toSet();\n    for (final preset in CustomAutomationBuiltinPresets.all()) {\n      if (existingIds.add(preset.id)) {\n        _items.add(preset);\n        addedBuiltin = true;\n      }\n    }\n    if (addedBuiltin) await _persist();\n    notifyListeners();\n  }\n\n  Future<void> _persist() async {"""
    if needle not in s:
        raise SystemExit('CustomAutomationService init anchor not found')
    s = s.replace(needle, replacement, 1)
p.write_text(s)

# 2) Fix the three official recipes to match the requested names/order/values.
p = Path('lib/models/custom_automation_builtin_presets.dart')
s = p.read_text()
s = s.replace("    _auroraHologram(),\n", "")
s = s.replace("name: '下書きから線画',", "name: '線画作成（デジタル）',")
s = s.replace("name: 'アナログ線画抽出',", "name: '線画抽出（アナログ）',")
# Analog extraction must be color-adjust -> threshold -> brightness-to-alpha.
old_analog = """    steps: [\n      _filterStep(\n        '1',\n        const FilterDef(\n          id: 'Filter0014',\n          name: '二値化',\n          kind: FilterKind.threshold,\n          thresholdValue: 128,\n        ),\n        '二値化',\n      ),\n      _filterStep(\n        '2',\n        const FilterDef(\n          id: 'builtin_color_adjust',\n          name: '色調補正',\n          kind: FilterKind.colorAdjust,\n          caSaturation: -100,\n          caBrightness: 0,\n          caContrast: 20,\n        ),\n        '色調補正',\n      ),"""
new_analog = """    steps: [\n      _filterStep(\n        '1',\n        const FilterDef(\n          id: 'builtin_color_adjust',\n          name: '色調補正',\n          kind: FilterKind.colorAdjust,\n          caSaturation: -100,\n          caBrightness: 0,\n          caContrast: 20,\n        ),\n        '色調補正',\n      ),\n      _filterStep(\n        '2',\n        const FilterDef(\n          id: 'Filter0014',\n          name: '二値化',\n          kind: FilterKind.threshold,\n          thresholdValue: 128,\n        ),\n        '二値化',\n      ),"""
if old_analog in s:
    s = s.replace(old_analog, new_analog, 1)
s = s.replace("'lightness': -50.0,", "'lightness': -70.0,")
# Aurora remains available only as a drawing filter, not an official automation.
start = s.find("  static CustomAutomation _auroraHologram()")
if start >= 0:
    end = s.find("  static CustomAutomationStep _filterStep", start)
    if end < 0:
        raise SystemExit('Aurora preset end anchor not found')
    s = s[:start] + s[end:]
p.write_text(s)

# 3) Match the documented Autofill color-trace defaults (-10 / 60 / -70).
p = Path('lib/engine/color_trace_adjust_engine.dart')
s = p.read_text().replace("double lightnessShift = -50,", "double lightnessShift = -70,")
p.write_text(s)

# 4) Extend semantic execution with the layer operations used by the official recipes.
p = Path('lib/engine/custom_automation_executor.dart')
s = p.read_text()
if "import 'dart:typed_data';" not in s:
    s = "import 'dart:typed_data';\nimport 'dart:ui' as ui;\n\n" + s
elif "import 'dart:ui' as ui;" not in s:
    s = s.replace("import 'dart:typed_data';\n", "import 'dart:typed_data';\nimport 'dart:ui' as ui;\n")
if "brightness_alpha_engine.dart" not in s:
    s = s.replace(
        "import 'custom_automation_filter_runner.dart';\n",
        "import 'brightness_alpha_engine.dart';\nimport 'color_trace_adjust_engine.dart';\nimport 'custom_automation_filter_runner.dart';\nimport 'layer_compositor.dart';\n",
    )
# Add optional explicit frame selection so Canvas' specified-frames UI remains valid.
s = s.replace(
    "    required AutomationToolHandler handleCanvasStateCommand,\n  }) async {",
    "    required AutomationToolHandler handleCanvasStateCommand,\n    List<int>? targetFrames,\n  }) async {",
)
old_frames = """    final frames = scope == CustomAutomationExecutionScope.allFrames\n        ? List<int>.generate(\n            projectService.frameCount(projectId, sceneId),\n            (index) => index,\n          )\n        : <int>[currentFrame];"""
new_frames = """    final totalFrames = projectService.frameCount(projectId, sceneId);\n    final frames = scope == CustomAutomationExecutionScope.allFrames\n        ? List<int>.generate(totalFrames, (index) => index)\n        : scope == CustomAutomationExecutionScope.specifiedFrames\n        ? (targetFrames ?? const <int>[])\n              .where((frame) => frame >= 0 && frame < totalFrames)\n              .toList(growable: false)\n        : <int>[currentFrame];"""
if old_frames in s:
    s = s.replace(old_frames, new_frames, 1)

if "case 'canvas.visibleCompositeToNewTop':" not in s:
    old = """            case 'canvas.tool':\n            case 'canvas.brushSize':\n            case 'canvas.brushOpacity':\n            case 'canvas.color':\n            case 'canvas.autofillRun':\n              await handleCanvasStateCommand(step.command, step.args);\n"""
    new = """            case 'canvas.visibleCompositeToNewTop':\n              activeLayerId = await _visibleCompositeToNewTop(\n                projectService: projectService,\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n              );\n            case 'canvas.layerDuplicate':\n              if (activeLayerId == null) {\n                throw StateError('No active layer');\n              }\n              final duplicate = projectService.duplicateLayer(\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n                layerId: activeLayerId,\n              );\n              if (duplicate == null) {\n                throw StateError('Could not duplicate layer');\n              }\n              activeLayerId = duplicate.id;\n            case 'canvas.mergeDown':\n              if (activeLayerId == null) {\n                throw StateError('No active layer');\n              }\n              activeLayerId = await _mergeDown(\n                projectService: projectService,\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n                activeLayerId: activeLayerId,\n              );\n            case 'canvas.brightnessToAlpha':\n              if (activeLayerId == null) {\n                throw StateError('No active layer');\n              }\n              await _transformActivePixels(\n                projectService: projectService,\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n                layerId: activeLayerId,\n                transform: (pixels) => applyBrightnessToAlpha(\n                  pixels,\n                  grayMode: step.args['grayMode'] as bool? ?? true,\n                ),\n              );\n            case 'canvas.colorTraceAdjust':\n              if (activeLayerId == null) {\n                throw StateError('No active layer');\n              }\n              await _transformActivePixels(\n                projectService: projectService,\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n                layerId: activeLayerId,\n                transform: (pixels) => applyColorTraceAdjust(\n                  pixels,\n                  hueShift: (step.args['hue'] as num?)?.toDouble() ?? -10,\n                  saturationShift: (step.args['saturation'] as num?)?.toDouble() ?? 60,\n                  lightnessShift: (step.args['lightness'] as num?)?.toDouble() ?? -70,\n                ),\n              );\n            case 'canvas.tool':\n            case 'canvas.brushSize':\n            case 'canvas.brushOpacity':\n            case 'canvas.color':\n            case 'canvas.autofillRun':\n              await handleCanvasStateCommand(step.command, step.args);\n"""
    if old not in s:
        raise SystemExit('Executor switch anchor not found')
    s = s.replace(old, new, 1)

if "static Future<String> _visibleCompositeToNewTop" not in s:
    close_anchor = """    }\n  }\n}\n\nclass _LayerAnchor {"""
    helpers = r'''    }
  }

  static Future<String> _visibleCompositeToNewTop({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
  }) async {
    final tm = projectService.tileManagerOf(projectId);
    final layers = projectService.layersOf(projectId, sceneId, frameIndex);
    final image = await LayerCompositor.composite(
      tm,
      layers,
      (layer) => projectService.tileKeyFor(projectId, sceneId, frameIndex, layer.id),
      tm.canvasWidth,
      tm.canvasHeight,
      shouldRender: (layer, _) => layer.isVisible,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) throw StateError('Could not composite visible layers');
    final created = projectService.addLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name: '表示中レイヤー統合',
    );
    final current = projectService.layersOf(projectId, sceneId, frameIndex);
    final oldIndex = current.indexWhere((layer) => layer.id == created.id);
    if (oldIndex > 0) {
      projectService.reorderLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        oldIndex: oldIndex,
        newIndex: 0,
      );
    }
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, created.id);
    tm.replaceLayerPixels(key, bytes.buffer.asUint8List());
    projectService.updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layer: created,
    );
    return created.id;
  }

  static Future<String> _mergeDown({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String activeLayerId,
  }) async {
    final layers = projectService.layersOf(projectId, sceneId, frameIndex);
    final index = layers.indexWhere((layer) => layer.id == activeLayerId);
    if (index < 0 || index + 1 >= layers.length) {
      throw StateError('No lower layer to merge');
    }
    final lower = layers[index + 1];
    await projectService.mergeLayers(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layerIds: [activeLayerId, lower.id],
    );
    return lower.id;
  }

  static Future<void> _transformActivePixels({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
    required Uint8List Function(Uint8List pixels) transform,
  }) async {
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(projectId, sceneId, frameIndex, layerId);
    final image = await tm.compositeLayerToImage(key);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) throw StateError('Could not read layer pixels');
    tm.replaceLayerPixels(key, transform(bytes.buffer.asUint8List()));
    final layer = projectService.layersOf(projectId, sceneId, frameIndex)
        .where((item) => item.id == layerId)
        .firstOrNull;
    if (layer != null) {
      projectService.updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        layer: layer,
      );
    }
  }
}

class _LayerAnchor {'''
    if close_anchor not in s:
        raise SystemExit('Executor class close anchor not found')
    s = s.replace(close_anchor, helpers, 1)
p.write_text(s)

# 5) Route only official semantic presets through the semantic executor. User-recorded
# legacy automations continue through CanvasScreen's existing replay path.
p = Path('lib/screens/canvas/canvas_screen.dart')
s = p.read_text()
if "custom_automation_executor.dart" not in s:
    s = s.replace(
        "import '../../engine/undo_manager.dart';\n",
        "import '../../engine/undo_manager.dart';\nimport '../../engine/custom_automation_executor.dart';\n",
    )
needle = """  Future<void> _executeCustomAutomation(\n    CustomAutomation automation,\n    CustomAutomationExecutionScope scope,\n    List<int>? targetFrames,\n  ) async {\n    final total = context.read<ProjectService>().frameCount("""
if needle in s and "automation.id.startsWith('builtin_')" not in s:
    insertion = """  Future<void> _executeCustomAutomation(\n    CustomAutomation automation,\n    CustomAutomationExecutionScope scope,\n    List<int>? targetFrames,\n  ) async {\n    if (automation.id.startsWith('builtin_')) {\n      await CustomAutomationExecutor.executeCanvas(\n        automation: automation,\n        scope: scope,\n        projectService: context.read<ProjectService>(),\n        projectId: widget.projectId,\n        sceneId: _currentSceneId,\n        currentFrame: _currentFrame,\n        currentLayerId: _currentLayerId,\n        targetFrames: targetFrames,\n        handleCanvasStateCommand: (command, args) async {\n          if (command == 'canvas.tool') {\n            final toolName = args['tool'] as String?;\n            final tool = DrawingTool.values\n                .where((value) => value.name == toolName)\n                .firstOrNull;\n            if (tool != null) setState(() => _currentTool = tool);\n          }\n        },\n      );\n      return;\n    }\n    final total = context.read<ProjectService>().frameCount("""
    s = s.replace(needle, insertion, 1)
p.write_text(s)

# 6) Add focused regression assertions for the official presets and trace values.
p = Path('test/custom_automation_service_test.dart')
s = p.read_text()
if "custom_automation_builtin_presets.dart" not in s:
    s = s.replace(
        "import 'package:niarim/models/custom_automation.dart';\n",
        "import 'package:niarim/models/custom_automation.dart';\nimport 'package:niarim/models/custom_automation_builtin_presets.dart';\n",
    )
if "official presets match requested recipes" not in s:
    insert_at = s.rfind("}\n")
    test_block = r'''

  test('official presets match requested recipes', () {
    final presets = CustomAutomationBuiltinPresets.all();
    expect(presets.map((p) => p.name), containsAll([
      '線画作成（デジタル）',
      '線画抽出（アナログ）',
      '線画色トレス',
    ]));
    expect(presets.any((p) => p.name == 'オーロラホログラム'), isFalse);

    final digital = presets.firstWhere((p) => p.id == 'builtin_draft_to_lineart');
    expect(digital.steps.map((s) => s.label).toList(), ['自動線画', '墨溜まり']);

    final analog = presets.firstWhere((p) => p.id == 'builtin_analog_lineart_extract');
    expect(analog.steps.map((s) => s.label).toList(), [
      '色調補正',
      '二値化',
      '明度で透過（グレー）',
    ]);

    final trace = presets.firstWhere((p) => p.id == 'builtin_lineart_color_trace');
    expect(trace.steps.map((s) => s.command).toList(), [
      'canvas.visibleCompositeToNewTop',
      'canvas.filterApply',
      'canvas.layerDuplicate',
      'canvas.layerDuplicate',
      'canvas.mergeDown',
      'canvas.mergeDown',
      'canvas.colorTraceAdjust',
    ]);
    expect(trace.steps.last.args['hue'], -10.0);
    expect(trace.steps.last.args['saturation'], 60.0);
    expect(trace.steps.last.args['lightness'], -70.0);
  });
'''
    s = s[:insert_at] + test_block + s[insert_at:]
p.write_text(s)
