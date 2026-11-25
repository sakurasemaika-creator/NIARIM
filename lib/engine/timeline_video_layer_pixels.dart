import 'dart:ui' as ui;

import '../models/layer.dart';
import 'layer_compositor.dart';
import 'timeline_video_time.dart';
import 'video_frame_provider.dart';

/// A timeline video layer whose frame could not be shown, and why.
typedef VideoLayerProblem = ({
  String layerId,
  String? materialId,
  VideoFrameUnavailableReason reason,
});

/// Supplies decoded video frames as the pixels of timeline video layers in
/// [LayerCompositor.composite], so a video frame goes through the same
/// opacity, blend modes (including the CPU-only ones), clipping, masks,
/// folders and transforms as any other layer. Every other layer keeps its
/// stored pixels.
///
/// The timeline preview and the export both build their composites through
/// this class with the same [VideoFrameProvider] rules, so the same layer at
/// the same frame shows the same decoded frame in both.
class TimelineVideoLayerPixels {
  TimelineVideoLayerPixels({
    required this.frames,
    required this.framesPerSecond,
    required this.canvasWidth,
    required this.canvasHeight,
    this.isCancelled,
    this.onProblem,
  });

  final VideoFrameProvider frames;

  /// The project frame rate the timeline's frame numbers count in.
  final double framesPerSecond;
  final int canvasWidth;
  final int canvasHeight;
  final bool Function()? isCancelled;

  /// Told about each layer whose frame could not be shown (missing or
  /// unreadable file, failed decode), so the caller can report it. The layer
  /// then draws nothing; its placeholder pixels are never shown instead.
  final void Function(VideoLayerProblem problem)? onProblem;

  /// The pixel source for one composite of scene frame [frameIndex].
  LayerPixelSource atFrame(int frameIndex) =>
      (layer, rasterSize) => pixelsOf(layer, frameIndex, rasterSize);

  Future<LayerPixels> pixelsOf(
    Layer layer,
    int frameIndex,
    ui.Size? rasterSize,
  ) async {
    if (layer.type != LayerType.timelineVideo) {
      return const LayerPixelsFromTiles();
    }
    final materialId = layer.materialId;
    if (materialId == null) {
      onProblem?.call((
        layerId: layer.id,
        materialId: null,
        reason: VideoFrameUnavailableReason.unknownMaterial,
      ));
      return const LayerPixelsEmpty();
    }
    final time = TimelineVideoTimeMapper.layerSourceTimeAt(
      layer,
      frameIndex,
      framesPerSecond,
    );
    if (time == null) return const LayerPixelsEmpty();
    final width = rasterSize?.width.round() ?? canvasWidth;
    final height = rasterSize?.height.round() ?? canvasHeight;
    if (width <= 0 || height <= 0) return const LayerPixelsEmpty();
    final result = await frames.frameAt(
      materialId: materialId,
      sourceTime: time,
      width: width,
      height: height,
      isCancelled: isCancelled,
    );
    switch (result) {
      case VideoFrameReady(:final image):
        return LayerPixelsImage(image);
      case VideoFrameUnavailable(:final reason):
        if (reason.isFailure) {
          onProblem?.call((
            layerId: layer.id,
            materialId: materialId,
            reason: reason,
          ));
        }
        return const LayerPixelsEmpty();
    }
  }
}
