import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;

import '../models/filter_def.dart';
import '../models/layer.dart' as model;
import '../services/filter_service.dart';
import '../services/project_service.dart';
import 'filter_engine.dart';
import 'layer_compositor.dart';
import 'prism_filter_engine.dart';

/// Applies a recorded drawing-filter snapshot without driving FilterPanel UI.
///
/// The return value is the layer that subsequent automation steps should treat as
/// active. Generated-layer filters (outline/ink-pool/auto-lineart) return their new
/// normal layer; destructive filters return [sourceLayerId]. This makes chains such
/// as Auto Lineart -> Ink Pool deterministic and lets all-frame execution repeat the
/// same semantic sequence independently on every frame.
class CustomAutomationFilterRunner {
  static Future<String> apply({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String sourceLayerId,
    required FilterDef filter,
  }) async {
    final tm = projectService.tileManagerOf(projectId);
    final key = projectService.tileKeyFor(
      projectId,
      sceneId,
      frameIndex,
      sourceLayerId,
    );
    final image = await tm.compositeLayerToImage(key);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) {
      throw StateError('Could not read source pixels for recorded filter');
    }
    final data = byteData.buffer.asUint8List();

    Uint8List result;
    if (filter.id == FilterService.prismFilterId) {
      result = await compute(applyPrismFilterInIsolate, (
        data,
        tm.canvasWidth,
        tm.canvasHeight,
        filter.prismBlurPx,
        filter.prismDirectionDegrees,
      ));
    } else {
      Uint8List? auxiliary;
      if (filter.kind == FilterKind.lensDistortion) {
        final selectionLayer = projectService
            .layersOf(projectId, sceneId, frameIndex)
            .where((layer) => layer.type == model.LayerType.selection)
            .firstOrNull;
        if (selectionLayer != null) {
          final maskImage = await tm.compositeLayerToImage(
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
          auxiliary = maskBytes?.buffer.asUint8List();
        }
      } else if (filter.kind == FilterKind.backgroundBlend) {
        final layers = projectService.layersOf(projectId, sceneId, frameIndex);
        final background = await LayerCompositor.composite(
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
          shouldRender: (layer, _) => layer.id != sourceLayerId,
        );
        final backgroundBytes = await background.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        background.dispose();
        auxiliary = backgroundBytes?.buffer.asUint8List();
      }
      result = await compute(applyDrawFilterInIsolate, (
        data,
        tm.canvasWidth,
        tm.canvasHeight,
        filter,
        auxiliary,
      ));
    }

    if (_createsLayer(filter)) {
      return _writeGeneratedLayer(
        projectService: projectService,
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        sourceLayerId: sourceLayerId,
        pixels: result,
        filter: filter,
      );
    }

    tm.replaceLayerPixels(key, result);
    final sourceLayer = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .where((layer) => layer.id == sourceLayerId)
        .firstOrNull;
    if (sourceLayer == null) {
      throw StateError('Recorded filter source layer disappeared');
    }
    projectService.updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layer: sourceLayer,
    );
    return sourceLayerId;
  }

  static bool _createsLayer(FilterDef filter) =>
      filter.id != FilterService.prismFilterId &&
      (filter.kind == FilterKind.outline ||
          filter.kind == FilterKind.inkPool ||
          filter.kind == FilterKind.autoLineart);

  static String _generatedLayerName(String sourceName, FilterDef filter) {
    final suffix = switch (filter.kind) {
      FilterKind.outline => '縁取り',
      FilterKind.inkPool => '墨溜まり',
      FilterKind.autoLineart => '自動線画',
      _ => filter.name,
    };
    return '$sourceName $suffix';
  }

  static String _writeGeneratedLayer({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String sourceLayerId,
    required Uint8List pixels,
    required FilterDef filter,
  }) {
    final source = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .where((layer) => layer.id == sourceLayerId)
        .firstOrNull;
    if (source == null) {
      throw StateError('Recorded filter source layer disappeared');
    }
    final created = projectService.addLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name: _generatedLayerName(source.name, filter),
    );

    final layers = projectService.layersOf(projectId, sceneId, frameIndex);
    final createdIndex = layers.indexWhere((layer) => layer.id == created.id);
    final sourceIndex = layers.indexWhere((layer) => layer.id == sourceLayerId);
    final targetIndex = sourceIndex < 0 ? createdIndex : sourceIndex + 1;
    if (createdIndex >= 0 && targetIndex >= 0 && createdIndex != targetIndex) {
      projectService.reorderLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
        oldIndex: createdIndex,
        newIndex: targetIndex,
      );
    }

    final key = projectService.tileKeyFor(
      projectId,
      sceneId,
      frameIndex,
      created.id,
    );
    projectService.tileManagerOf(projectId).replaceLayerPixels(key, pixels);
    projectService.updateLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: frameIndex,
      layer: created,
    );
    return created.id;
  }
}
