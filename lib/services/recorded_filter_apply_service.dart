import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;

import '../engine/filter_engine.dart';
import '../engine/layer_compositor.dart';
import '../engine/prism_filter_engine.dart';
import '../models/filter_def.dart';
import '../models/layer.dart' as model;
import 'project_service.dart';

/// Replays a filter from the immutable parameter snapshot stored in a custom
/// automation step. The current FilterService state is deliberately ignored so
/// changing sliders after recording cannot change the automation result.
class RecordedFilterApplyService {
  const RecordedFilterApplyService._();

  static FilterDef parseSnapshot(Map<String, Object?> json) {
    return FilterDef.fromJson(Map<String, dynamic>.from(json));
  }

  static Future<String?> apply({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required String layerId,
    required int frameIndex,
    required Map<String, Object?> filterSnapshot,
    GeneratedLayerNamer? layerName,
  }) async {
    final filter = parseSnapshot(filterSnapshot);
    final tileManager = projectService.tileManagerOf(projectId);
    final sourceLayer = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .where((layer) => layer.id == layerId)
        .firstOrNull;
    if (sourceLayer == null) {
      throw StateError('Recorded filter source layer is unavailable');
    }

    final key = projectService.tileKeyFor(
      projectId,
      sceneId,
      frameIndex,
      layerId,
    );
    final image = await tileManager.compositeLayerToImage(key);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) {
      throw StateError('Recorded filter source pixels are unavailable');
    }
    final data = byteData.buffer.asUint8List();

    final Uint8List result;
    if (filter.kind == FilterKind.prism) {
      result = await compute(applyPrismFilterInIsolate, (
        data,
        tileManager.canvasWidth,
        tileManager.canvasHeight,
        filter.prismBlurPx,
        filter.prismDirectionDegrees,
      ));
    } else {
      Uint8List? auxiliaryData;
      if (filterUsesSelectionMask(filter.kind)) {
        final selectionLayer = projectService
            .layersOf(projectId, sceneId, frameIndex)
            .where((layer) => layer.type == model.LayerType.selection)
            .firstOrNull;
        if (selectionLayer != null) {
          final maskImage = await tileManager.compositeLayerToImage(
            projectService.tileKeyFor(
              projectId,
              sceneId,
              frameIndex,
              selectionLayer.id,
            ),
          );
          final maskBytes = await maskImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          maskImage.dispose();
          auxiliaryData = maskBytes?.buffer.asUint8List();
        }
      } else if (filter.kind == FilterKind.backgroundBlend) {
        final layers = projectService.layersOf(projectId, sceneId, frameIndex);
        final otherImage = await LayerCompositor.composite(
          tileManager,
          layers,
          (layer) => projectService.tileKeyFor(
            projectId,
            sceneId,
            frameIndex,
            layer.id,
          ),
          tileManager.canvasWidth,
          tileManager.canvasHeight,
          shouldRender: (layer, _) => layer.id != layerId,
        );
        final otherBytes = await otherImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        otherImage.dispose();
        auxiliaryData = otherBytes?.buffer.asUint8List();
      }
      result = await compute(applyDrawFilterForFrameInIsolate, (
        data,
        tileManager.canvasWidth,
        tileManager.canvasHeight,
        filter,
        auxiliaryData,
        frameIndex,
      ));
    }

    if (filter.kind != FilterKind.prism &&
        (filter.kind == FilterKind.outline ||
            filter.kind == FilterKind.inkPool ||
            filter.kind == FilterKind.autoLineart)) {
      return _writeGeneratedLayer(
        projectService: projectService,
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        sourceLayerId: layerId,
        sourceName: sourceLayer.name,
        filter: filter,
        pixels: result,
        layerName: layerName,
      );
    }

    projectService.replaceLayerPixels(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layerId: layerId,
      pixels: result,
      updatedLayer: filter.kind == FilterKind.prism
          ? sourceLayer.copyWith(blendMode: model.LayerBlendMode.linearDodge)
          : null,
    );
    return null;
  }

  static String _generatedLayerName(String sourceName, FilterDef filter) {
    final suffix = filter.name.trim().isEmpty ? filter.kind.name : filter.name;
    return '$sourceName - $suffix';
  }

  static String _writeGeneratedLayer({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String sourceLayerId,
    required String sourceName,
    required FilterDef filter,
    required Uint8List pixels,
    GeneratedLayerNamer? layerName,
  }) {
    final tileManager = projectService.tileManagerOf(projectId);
    final before = projectService.layersOf(projectId, sceneId, frameIndex);
    final sourceIndex = before.indexWhere((layer) => layer.id == sourceLayerId);
    final insertIndex = generatedLayerInsertIndex(filter.kind, sourceIndex);
    final created = projectService.addLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name:
          layerName?.call(sourceName, filter) ??
          _generatedLayerName(sourceName, filter),
      insertIndex: insertIndex,
    );
    final key = projectService.tileKeyFor(
      projectId,
      sceneId,
      frameIndex,
      created.id,
    );
    tileManager.replaceLayerPixels(key, pixels);
    projectService.updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layer: sourceIndex < 0
          ? created
          : generatedLayerFitted(
              created,
              before[sourceIndex],
              before,
              insertIndex,
            ),
    );
    return created.id;
  }
}
