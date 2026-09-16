import 'dart:ui' as ui;

import '../models/custom_automation.dart';
import '../models/filter_def.dart';
import '../models/layer.dart' as model;
import '../services/project_service.dart';
import 'custom_automation_filter_runner.dart';
import 'color_trace_adjust_engine.dart';
import 'layer_compositor.dart';

class CustomAutomationExecutionException implements Exception {
  final String message;
  final int? stepIndex;

  const CustomAutomationExecutionException(this.message, {this.stepIndex});

  @override
  String toString() => stepIndex == null
      ? 'CustomAutomationExecutionException: $message'
      : 'CustomAutomationExecutionException(step ${stepIndex! + 1}): $message';
}

typedef AutomationToolHandler =
    Future<void> Function(String command, Map<String, Object?> args);

/// Executes semantic automation commands rather than replaying screen coordinates.
/// This keeps imported/shared automations stable across screen sizes and layouts.
class CustomAutomationExecutor {
  /// Returns the resulting active layer on the originally selected frame.
  /// Canvas callers use this to keep selection on a generated output layer.
  static Future<String?> executeCanvas({
    required CustomAutomation automation,
    required CustomAutomationExecutionScope scope,
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int currentFrame,
    List<int>? targetFrames,
    required String? currentLayerId,
    required AutomationToolHandler handleCanvasStateCommand,
  }) => projectService.runWithGroupedUndo(
    description: automation.name,
    operation: () => _executeCanvasSteps(
      automation: automation,
      scope: scope,
      projectService: projectService,
      projectId: projectId,
      sceneId: sceneId,
      currentFrame: currentFrame,
      targetFrames: targetFrames,
      currentLayerId: currentLayerId,
      handleCanvasStateCommand: handleCanvasStateCommand,
    ),
  );

  static Future<String?> _executeCanvasSteps({
    required CustomAutomation automation,
    required CustomAutomationExecutionScope scope,
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int currentFrame,
    List<int>? targetFrames,
    required String? currentLayerId,
    required AutomationToolHandler handleCanvasStateCommand,
  }) async {
    if (!automation.isCanvasOnly) {
      throw const CustomAutomationExecutionException(
        'Timeline steps cannot be executed by the Canvas executor',
      );
    }
    if (scope != CustomAutomationExecutionScope.currentFrame &&
        (!automation.supportsFrameScopeChoice ||
            automation.steps.any(
              (step) => step.command == 'canvas.selectFrame',
            ))) {
      throw const CustomAutomationExecutionException(
        'This automation was not recorded entirely in one Canvas frame',
      );
    }

    final totalFrames = projectService.frameCount(projectId, sceneId);
    final frames = scope == CustomAutomationExecutionScope.allFrames
        ? List<int>.generate(totalFrames, (index) => index)
        : scope == CustomAutomationExecutionScope.specifiedFrames
        ? (targetFrames ?? const <int>[])
              .where((frame) => frame >= 0 && frame < totalFrames)
              .toSet()
              .toList()
        : <int>[currentFrame];

    final sourceAnchor = _LayerAnchor.capture(
      projectService: projectService,
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: currentFrame,
      layerId: currentLayerId,
    );

    String? finalActiveLayerId;
    for (final initialFrameIndex in frames) {
      var frameIndex = initialFrameIndex;
      var activeLayerId = sourceAnchor.resolve(
        projectService: projectService,
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
      );
      for (var i = 0; i < automation.steps.length; i++) {
        final step = automation.steps[i];
        try {
          switch (step.command) {
            // `canvas.filter` is retained for built-in presets and automations
            // persisted before the semantic command was renamed.
            case 'canvas.filter':
            case 'canvas.filterApply':
              if (activeLayerId == null) {
                throw StateError('No source layer is available');
              }
              final raw = step.args['filter'];
              if (raw is! Map) {
                throw const FormatException(
                  'Recorded filter snapshot is missing',
                );
              }
              final filter = FilterDef.fromJson(raw.cast<String, dynamic>());
              activeLayerId = await CustomAutomationFilterRunner.apply(
                projectService: projectService,
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                sourceLayerId: activeLayerId,
                filter: filter,
              );
            case 'canvas.visibleCompositeToNewTop':
              final tm = projectService.tileManagerOf(projectId);
              final image = await LayerCompositor.composite(
                tm,
                projectService.layersOf(projectId, sceneId, frameIndex),
                (layer) => projectService.tileKeyFor(
                  projectId,
                  sceneId,
                  frameIndex,
                  layer.id,
                ),
                tm.canvasWidth,
                tm.canvasHeight,
              );
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              image.dispose();
              if (bytes == null) {
                throw StateError('Could not read visible composite');
              }
              final created = projectService.addLayer(
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                type: model.LayerType.normal,
                name: automation.name,
              );
              activeLayerId = created.id;
              tm.replaceLayerPixels(
                projectService.tileKeyFor(
                  projectId,
                  sceneId,
                  frameIndex,
                  created.id,
                ),
                bytes.buffer.asUint8List(),
              );
              projectService.updateLayer(
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                layer: created,
              );
            case 'canvas.layerDuplicate':
              if (activeLayerId == null) throw StateError('No active layer');
              final copy = projectService.duplicateLayer(
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                layerId: activeLayerId,
              );
              if (copy == null) throw StateError('No active layer');
              activeLayerId = copy.id;
            case 'canvas.mergeDown':
              final layers = projectService.layersOf(
                projectId,
                sceneId,
                frameIndex,
              );
              final index = layers.indexWhere(
                (layer) => layer.id == activeLayerId,
              );
              if (index < 0 || index + 1 >= layers.length) {
                throw StateError('No layer below the active layer');
              }
              final below = layers[index + 1];
              const mergeable = {
                model.LayerType.normal,
                model.LayerType.autoFillLineart,
                model.LayerType.autoFill,
              };
              if (!mergeable.contains(layers[index].type) ||
                  !mergeable.contains(below.type)) {
                throw StateError('Layers cannot be merged');
              }
              await projectService.mergeLayers(
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                layerIds: [activeLayerId!, below.id],
              );
              activeLayerId = below.id;
            case 'canvas.brightnessToAlpha':
            case 'canvas.colorTraceAdjust':
              final layer = projectService
                  .layersOf(projectId, sceneId, frameIndex)
                  .where((layer) => layer.id == activeLayerId)
                  .firstOrNull;
              if (layer == null) throw StateError('No active layer');
              final tm = projectService.tileManagerOf(projectId);
              final key = projectService.tileKeyFor(
                projectId,
                sceneId,
                frameIndex,
                layer.id,
              );
              if (step.command == 'canvas.brightnessToAlpha') {
                await tm.applyBrightnessToAlpha(
                  key,
                  grayMode: step.args['grayMode'] == true,
                );
              } else {
                final image = await tm.compositeLayerToImage(key);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                image.dispose();
                if (bytes == null) {
                  throw StateError('Could not read color trace source');
                }
                tm.replaceLayerPixels(
                  key,
                  applyColorTraceAdjust(
                    bytes.buffer.asUint8List(),
                    hueShift: (step.args['hue'] as num?)?.toDouble() ?? -10,
                    saturationShift:
                        (step.args['saturation'] as num?)?.toDouble() ?? 60,
                    lightnessShift:
                        (step.args['lightness'] as num?)?.toDouble() ?? -50,
                  ),
                );
              }
              projectService.updateLayer(
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
                layer: layer,
              );
            case 'canvas.selectFrame':
              final target = (step.args['frame'] as num?)?.toInt();
              if (target == null || target < 0 || target >= totalFrames) {
                throw StateError('Frame is outside the current scene');
              }
              frameIndex = target;
              activeLayerId = sourceAnchor.resolve(
                projectService: projectService,
                projectId: projectId,
                sceneId: sceneId,
                frameIndex: frameIndex,
              );
              await handleCanvasStateCommand(step.command, step.args);
            case 'canvas.tool':
            case 'canvas.brushSize':
            case 'canvas.brushOpacity':
            case 'canvas.color':
            case 'canvas.autofillRun':
              await handleCanvasStateCommand(step.command, step.args);
            default:
              throw UnsupportedError(
                'Unsupported recorded command: ${step.command}',
              );
          }
        } catch (error) {
          throw CustomAutomationExecutionException(
            error.toString(),
            stepIndex: i,
          );
        }
      }
      if (initialFrameIndex == currentFrame) finalActiveLayerId = activeLayerId;
    }
    return finalActiveLayerId;
  }
}

class _LayerAnchor {
  final String? id;
  final String? name;
  final model.LayerType? type;
  final int? indexWithinType;

  const _LayerAnchor({this.id, this.name, this.type, this.indexWithinType});

  factory _LayerAnchor.capture({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String? layerId,
  }) {
    final eligible = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .where((layer) => pixelLayerTypes.contains(layer.type))
        .toList();
    final selected = layerId == null
        ? eligible.firstOrNull
        : eligible.where((layer) => layer.id == layerId).firstOrNull;
    if (selected == null) return const _LayerAnchor();
    final sameType = eligible
        .where((layer) => layer.type == selected.type)
        .toList();
    return _LayerAnchor(
      id: selected.id,
      name: selected.name,
      type: selected.type,
      indexWithinType: sameType.indexWhere((layer) => layer.id == selected.id),
    );
  }

  String? resolve({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
  }) {
    if (id == null) return null;
    final candidates = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .where((layer) => layer.type == type)
        .toList();
    final byId = candidates.where((layer) => layer.id == id).firstOrNull;
    if (byId != null) return byId.id;
    final byName = candidates.where((layer) => layer.name == name).firstOrNull;
    if (byName != null) return byName.id;
    if (indexWithinType != null && indexWithinType! < candidates.length) {
      return candidates[indexWithinType!].id;
    }
    return candidates.firstOrNull?.id;
  }
}
