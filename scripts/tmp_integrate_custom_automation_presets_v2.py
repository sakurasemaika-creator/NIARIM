from pathlib import Path

# 1) Retire Aurora/Hologram from the drawing-filter picker while preserving legacy data.
p = Path('lib/services/filter_service.dart')
s = p.read_text()
if 'legacyAuroraHologramFilterId' not in s:
    s = s.replace(
        "  static const prismFilterId = 'Filter0022';\n",
        "  static const prismFilterId = 'Filter0022';\n  static const legacyAuroraHologramFilterId = 'Filter0019';\n",
    )
if "if (f.id == legacyAuroraHologramFilterId) return false;" not in s:
    s = s.replace(
        "    return _filters.where((f) {\n      if (_favoritesOnly",
        "    return _filters.where((f) {\n      // Legacy Aurora remains executable from old automation/project data only.\n      if (f.id == legacyAuroraHologramFilterId) return false;\n      if (_favoritesOnly",
    )
aurora_block = """    FilterDef(\n      id: 'Filter0019',\n      name: 'オーロラホログラム',\n      kind: FilterKind.auroraHologram,\n      strength: 60,\n    ),\n"""
s = s.replace(aurora_block, '')
s = s.replace("    _currentFilterId = _filters.firstOrNull?.id;", "    _currentFilterId = visibleFilters.firstOrNull?.id;")
if "if (id == legacyAuroraHologramFilterId) return;" not in s:
    s = s.replace(
        "  void selectFilter(String id) {\n    _currentFilterId = id;",
        "  void selectFilter(String id) {\n    if (id == legacyAuroraHologramFilterId) return;\n    _currentFilterId = id;",
    )
s = s.replace(
    "if (_currentFilterId == id) _currentFilterId = _filters.firstOrNull?.id;",
    "if (_currentFilterId == id) _currentFilterId = visibleFilters.firstOrNull?.id;",
)
p.write_text(s)

# 2) Seed official semantic automation presets, preserving any user-edited preset with same ID.
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

# 3) Extend the semantic executor with layer operations used by official recipes.
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
if "case 'canvas.visibleCompositeToNewTop':" not in s:
    old = """            case 'canvas.tool':\n            case 'canvas.brushSize':\n            case 'canvas.brushOpacity':\n            case 'canvas.color':\n            case 'canvas.autofillRun':\n              await handleCanvasStateCommand(step.command, step.args);\n"""
    new = """            case 'canvas.visibleCompositeToNewTop':\n              activeLayerId = await _visibleCompositeToNewTop(\n                projectService: projectService,\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n              );\n            case 'canvas.layerDuplicate':\n              if (activeLayerId == null) throw StateError('No active layer');\n              final duplicate = projectService.duplicateLayer(\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n                layerId: activeLayerId,\n              );\n              if (duplicate == null) throw StateError('Could not duplicate layer');\n              activeLayerId = duplicate.id;\n            case 'canvas.mergeDown':\n              if (activeLayerId == null) throw StateError('No active layer');\n              activeLayerId = await _mergeDown(\n                projectService: projectService,\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n                activeLayerId: activeLayerId,\n              );\n            case 'canvas.brightnessToAlpha':\n              if (activeLayerId == null) throw StateError('No active layer');\n              await _transformActivePixels(\n                projectService: projectService,\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n                layerId: activeLayerId,\n                transform: (pixels) => applyBrightnessToAlpha(\n                  pixels,\n                  grayMode: step.args['grayMode'] as bool? ?? true,\n                ),\n              );\n            case 'canvas.colorTraceAdjust':\n              if (activeLayerId == null) throw StateError('No active layer');\n              await _transformActivePixels(\n                projectService: projectService,\n                projectId: projectId,\n                sceneId: sceneId,\n                frameIndex: frameIndex,\n                layerId: activeLayerId,\n                transform: (pixels) => applyColorTraceAdjust(\n                  pixels,\n                  hueShift: (step.args['hue'] as num?)?.toDouble() ?? -10,\n                  saturationShift: (step.args['saturation'] as num?)?.toDouble() ?? 60,\n                  lightnessShift: (step.args['lightness'] as num?)?.toDouble() ?? -50,\n                ),\n              );\n            case 'canvas.tool':\n            case 'canvas.brushSize':\n            case 'canvas.brushOpacity':\n            case 'canvas.color':\n            case 'canvas.autofillRun':\n              await handleCanvasStateCommand(step.command, step.args);\n"""
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
      (layer) => projectService.tileKeyFor(
        projectId,
        sceneId,
        frameIndex,
        layer.id,
      ),
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
    final key = projectService.tileKeyFor(
      projectId,
      sceneId,
      frameIndex,
      created.id,
    );
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
    final key = projectService.tileKeyFor(
      projectId,
      sceneId,
      frameIndex,
      layerId,
    );
    final image = await tm.compositeLayerToImage(key);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bytes == null) throw StateError('Could not read layer pixels');
    final output = transform(bytes.buffer.asUint8List());
    tm.replaceLayerPixels(key, output);
    final layer = projectService
        .layersOf(projectId, sceneId, frameIndex)
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
