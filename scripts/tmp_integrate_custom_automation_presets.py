from pathlib import Path

# CustomAutomationService: replace only untouched legacy built-ins, preserve edits,
# migrate favorites, and seed the new semantic built-ins exactly once.
p = Path('lib/services/custom_automation_service.dart')
s = p.read_text()
if "custom_automation_builtin_presets.dart" not in s:
    s = s.replace(
        "import '../models/custom_automation.dart';\n",
        "import '../models/custom_automation.dart';\nimport '../models/custom_automation_builtin_presets.dart';\n",
    )
old = '''    _items.clear();
    if (raw == null) {
      _items.addAll(builtInCanvasAutomationPresets());
      await _persist();
    } else {
      _items.addAll(
        raw.map((entry) {
          try {
            final decoded = jsonDecode(entry);
            if (decoded is! Map) return null;
            return CustomAutomation.fromJson(decoded.cast<String, Object?>());
          } catch (_) {
            return null;
          }
        }).whereType<CustomAutomation>(),
      );
    }
    _favoriteIds
      ..clear()
      ..addAll(prefs.getStringList(_favoritesPrefsKey) ?? const <String>[]);
    _favoriteIds.removeWhere((id) => _items.every((item) => item.id != id));
    await _persistFavorites();
    notifyListeners();
'''
new = '''    _items.clear();
    _favoriteIds
      ..clear()
      ..addAll(prefs.getStringList(_favoritesPrefsKey) ?? const <String>[]);

    var changed = false;
    if (raw == null) {
      _items.addAll(CustomAutomationBuiltinPresets.all());
      changed = true;
    } else {
      _items.addAll(
        raw.map((entry) {
          try {
            final decoded = jsonDecode(entry);
            if (decoded is! Map) return null;
            return CustomAutomation.fromJson(decoded.cast<String, Object?>());
          } catch (_) {
            return null;
          }
        }).whereType<CustomAutomation>(),
      );

      final legacyDefaults = {
        for (final item in builtInCanvasAutomationPresets()) item.id: item,
      };
      const replacementIds = {
        auroraHologramAutomationPresetId: 'builtin_aurora_hologram',
        lineExtractionAutomationPresetId: 'builtin_analog_lineart_extract',
        lineCreationAutomationPresetId: 'builtin_draft_to_lineart',
      };
      for (var i = _items.length - 1; i >= 0; i--) {
        final item = _items[i];
        final legacyDefault = legacyDefaults[item.id];
        if (legacyDefault == null) continue;
        if (jsonEncode(item.toJson()) != jsonEncode(legacyDefault.toJson())) {
          continue;
        }
        final replacementId = replacementIds[item.id];
        if (replacementId != null && _favoriteIds.remove(item.id)) {
          _favoriteIds.add(replacementId);
        }
        _items.removeAt(i);
        changed = true;
      }

      final existingIds = _items.map((item) => item.id).toSet();
      for (final preset in CustomAutomationBuiltinPresets.all()) {
        if (existingIds.add(preset.id)) {
          _items.add(preset);
          changed = true;
        }
      }
    }

    _favoriteIds.removeWhere((id) => _items.every((item) => item.id != id));
    if (changed) await _persist();
    await _persistFavorites();
    notifyListeners();
'''
if s.count(old) != 1:
    raise SystemExit(f'CustomAutomationService init anchor count={s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s)

# Executor: semantic layer/pixel commands required by official presets.
p = Path('lib/engine/custom_automation_executor.dart')
s = p.read_text()
if "import 'dart:ui' as ui;" not in s:
    s = "import 'dart:typed_data';\nimport 'dart:ui' as ui;\n\n" + s
for line in [
    "import 'brightness_alpha_engine.dart';\n",
    "import 'color_trace_adjust_engine.dart';\n",
    "import 'layer_compositor.dart';\n",
]:
    if line not in s:
        s = s.replace("import 'custom_automation_filter_runner.dart';\n", line + "import 'custom_automation_filter_runner.dart';\n")
old_switch = '''            case 'canvas.tool':
            case 'canvas.brushSize':
            case 'canvas.brushOpacity':
            case 'canvas.color':
            case 'canvas.autofillRun':
              await handleCanvasStateCommand(step.command, step.args);
'''
new_switch = '''            case 'canvas.visibleCompositeToNewTop':
              activeLayerId = await _visibleCompositeToNewTop(
                projectService: projectService,
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
              );
            case 'canvas.layerDuplicate':
              if (activeLayerId == null) throw StateError('No active layer');
              final duplicate = projectService.duplicateLayer(
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                layerId: activeLayerId,
              );
              if (duplicate == null) throw StateError('Could not duplicate layer');
              activeLayerId = duplicate.id;
            case 'canvas.mergeDown':
              if (activeLayerId == null) throw StateError('No active layer');
              activeLayerId = await _mergeDown(
                projectService: projectService,
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                activeLayerId: activeLayerId,
              );
            case 'canvas.brightnessToAlpha':
              if (activeLayerId == null) throw StateError('No active layer');
              await _transformActivePixels(
                projectService: projectService,
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                layerId: activeLayerId,
                transform: (pixels) => applyBrightnessToAlpha(
                  pixels,
                  grayMode: step.args['grayMode'] as bool? ?? true,
                ),
              );
            case 'canvas.colorTraceAdjust':
              if (activeLayerId == null) throw StateError('No active layer');
              await _transformActivePixels(
                projectService: projectService,
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                layerId: activeLayerId,
                transform: (pixels) => applyColorTraceAdjust(
                  pixels,
                  hueShift: (step.args['hue'] as num?)?.toDouble() ?? -10,
                  saturationShift:
                      (step.args['saturation'] as num?)?.toDouble() ?? 60,
                  lightnessShift:
                      (step.args['lightness'] as num?)?.toDouble() ?? -50,
                ),
              );
            case 'canvas.tool':
            case 'canvas.brushSize':
            case 'canvas.brushOpacity':
            case 'canvas.color':
            case 'canvas.autofillRun':
              await handleCanvasStateCommand(step.command, step.args);
'''
if s.count(old_switch) != 1:
    raise SystemExit(f'Executor switch anchor count={s.count(old_switch)}')
s = s.replace(old_switch, new_switch, 1)
anchor = "\nclass _LayerAnchor {"
helpers = r'''

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
    required List<int> Function(Uint8List pixels) transform,
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
    tm.replaceLayerPixels(key, Uint8List.fromList(output));
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
'''
if anchor not in s:
    raise SystemExit('Executor helper anchor not found')
s = s.replace(anchor, helpers + anchor, 1)
p.write_text(s)
