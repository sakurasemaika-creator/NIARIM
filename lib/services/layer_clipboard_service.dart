import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/layer.dart';
import 'project_service.dart';

class _LayerClipboardSnapshot {
  final Layer layer;
  final String sourceProjectId;
  final int sourceFrameIndex;
  final Uint8List? pixels;

  const _LayerClipboardSnapshot({
    required this.layer,
    required this.sourceProjectId,
    required this.sourceFrameIndex,
    required this.pixels,
  });
}

/// Session-scoped layer clipboard shared by every LayerPanel instance.
///
/// Pixels and metadata are snapshotted at copy time, so later edits or deletion
/// of the source layer cannot change what will be pasted.
class LayerClipboardService {
  LayerClipboardService._();

  static final LayerClipboardService instance = LayerClipboardService._();

  _LayerClipboardSnapshot? _snapshot;

  bool get hasLayer => _snapshot != null;

  Future<bool> copy({
    required ProjectService projectService,
    required String projectId,
    required String sceneId,
    required int frameIndex,
    required String layerId,
  }) async {
    final layer = projectService
        .layersOf(projectId, sceneId, frameIndex)
        .where((candidate) => candidate.id == layerId)
        .firstOrNull;
    if (layer == null) return false;

    Uint8List? pixels;
    if (layer.type != LayerType.folder) {
      final tileManager = projectService.tileManagerOf(projectId);
      final image = await tileManager.compositeLayerToImage(
        projectService.tileKeyFor(projectId, sceneId, frameIndex, layer.id),
      );
      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (byteData != null) {
          pixels = Uint8List.fromList(
            byteData.buffer.asUint8List(
              byteData.offsetInBytes,
              byteData.lengthInBytes,
            ),
          );
        }
      } finally {
        image.dispose();
      }
    }

    _snapshot = _LayerClipboardSnapshot(
      layer: layer.copyWith(keyframes: List.of(layer.keyframes)),
      sourceProjectId: projectId,
      sourceFrameIndex: frameIndex,
      pixels: pixels,
    );
    return true;
  }

  Layer? pasteBefore({
    required ProjectService projectService,
    required String projectId,
    required String targetSceneId,
    required int targetFrameIndex,
    required String beforeLayerId,
  }) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.sourceProjectId != projectId) return null;
    final scene = projectService.sceneOf(projectId, targetSceneId);
    if (scene == null ||
        targetFrameIndex < 0 ||
        targetFrameIndex >= scene.frames.length) {
      return null;
    }

    final physicalLayers = scene.frames[targetFrameIndex].layers;
    var insertIndex = physicalLayers.indexWhere(
      (layer) => layer.id == beforeLayerId,
    );
    if (insertIndex < 0) insertIndex = physicalLayers.length;

    final displayedTarget = projectService
        .layersOf(projectId, targetSceneId, targetFrameIndex)
        .where((layer) => layer.id == beforeLayerId)
        .firstOrNull;
    final candidateParent = displayedTarget?.parentFolderId;
    final targetParentFolderId =
        candidateParent != null &&
            physicalLayers.any((layer) => layer.id == candidateParent)
        ? candidateParent
        : null;

    final relocated = _relocateRangeForPaste(
      snapshot.layer,
      sourceFrameIndex: snapshot.sourceFrameIndex,
      targetSceneFrameCount: scene.frames.length,
      targetSceneId: targetSceneId,
      targetFrameIndex: targetFrameIndex,
    );

    return projectService.insertLayerSnapshot(
      projectId: projectId,
      sceneId: targetSceneId,
      frameIndex: targetFrameIndex,
      source: relocated,
      insertIndex: insertIndex,
      parentFolderId: targetParentFolderId,
      pixels: snapshot.pixels,
    );
  }

  Layer _relocateRangeForPaste(
    Layer source, {
    required int sourceFrameIndex,
    required int targetSceneFrameCount,
    required String targetSceneId,
    required int targetFrameIndex,
  }) {
    if (!isRangeLayerType(source.type)) return source;
    switch (source.rangeMode) {
      case LayerRangeMode.allFrames:
      case LayerRangeMode.currentScene:
        return source;
      case LayerRangeMode.sceneRange:
        return source.copyWith(rangeSceneId: targetSceneId);
      case LayerRangeMode.frameRange:
        final total = math.max(1, targetSceneFrameCount);
        final sourceStart = math.max(
          0,
          (source.rangeStart ?? sourceFrameIndex + 1) - 1,
        );
        final sourceEnd = math.max(
          sourceStart,
          (source.rangeEnd ?? sourceStart + 1) - 1,
        );
        final length = math.max(1, sourceEnd - sourceStart + 1);
        final anchorOffset = (sourceFrameIndex - sourceStart).clamp(
          0,
          length - 1,
        );
        final maxStart = math.max(0, total - math.min(length, total));
        final targetStart = (targetFrameIndex - anchorOffset).clamp(
          0,
          maxStart,
        );
        final targetEnd = math.min(total - 1, targetStart + length - 1);
        return source.copyWith(
          rangeStart: targetStart + 1,
          rangeEnd: targetEnd + 1,
          rangeSceneId: null,
        );
    }
  }
}
