import '../models/custom_automation.dart';
import '../models/filter_def.dart';
import '../models/layer.dart' as model;
import '../services/project_service.dart';
import 'custom_automation_filter_runner.dart';

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
  static Future<void> executeCanvas({
    required CustomAutomation automation,
    required CustomAutomationExecutionScope scope,
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int currentFrame,
    required String? currentLayerId,
    required AutomationToolHandler handleCanvasStateCommand,
  }) async {
    if (!automation.isCanvasOnly) {
      throw const CustomAutomationExecutionException(
        'Timeline steps cannot be executed by the Canvas executor',
      );
    }
    if (scope == CustomAutomationExecutionScope.allFrames &&
        !automation.supportsFrameScopeChoice) {
      throw const CustomAutomationExecutionException(
        'This automation was not recorded entirely in one Canvas frame',
      );
    }

    final frames = scope == CustomAutomationExecutionScope.allFrames
        ? List<int>.generate(
            projectService.frameCount(projectId, sceneId),
            (index) => index,
          )
        : <int>[currentFrame];

    final sourceAnchor = _LayerAnchor.capture(
      projectService: projectService,
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: currentFrame,
      layerId: currentLayerId,
    );

    for (final frameIndex in frames) {
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
            case 'canvas.filterApply':
              if (activeLayerId == null) {
                throw StateError('No normal source layer is available');
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
    }
  }
}

class _LayerAnchor {
  final String? id;
  final String? name;
  final int? normalIndex;

  const _LayerAnchor({this.id, this.name, this.normalIndex});

  factory _LayerAnchor.capture({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String? layerId,
  }) {
    final normal = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .where((layer) => layer.type == model.LayerType.normal)
        .toList();
    final index = normal.indexWhere((layer) => layer.id == layerId);
    if (index >= 0) {
      return _LayerAnchor(
        id: normal[index].id,
        name: normal[index].name,
        normalIndex: index,
      );
    }
    if (normal.isNotEmpty) {
      return _LayerAnchor(
        id: normal.first.id,
        name: normal.first.name,
        normalIndex: 0,
      );
    }
    return const _LayerAnchor();
  }

  String? resolve({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
  }) {
    final normal = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .where((layer) => layer.type == model.LayerType.normal)
        .toList();
    if (normal.isEmpty) return null;
    if (id != null) {
      final byId = normal.where((layer) => layer.id == id).firstOrNull;
      if (byId != null) return byId.id;
    }
    if (name != null) {
      final byName = normal.where((layer) => layer.name == name).firstOrNull;
      if (byName != null) return byName.id;
    }
    if (normalIndex != null && normalIndex! < normal.length) {
      return normal[normalIndex!].id;
    }
    return normal.first.id;
  }
}
