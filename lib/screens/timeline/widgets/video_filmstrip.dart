import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../engine/timeline_video_time.dart';
import '../../../engine/video_frame_provider.dart';

/// The part of its video a timeline clip plays: where the clip is on the
/// timeline, the source frames it uses and its speed.
typedef VideoFilmstripTiming = ({
  int startFrame,
  int lengthFrames,
  double trimStartFrame,
  int trimEndFrame,
  double playbackRate,
});

/// Frames of a video clip along its length, like a filmstrip. Each slot shows
/// the frame the clip plays at the middle of the slot, chosen and decoded by
/// [frames] with the same rule as the preview and the export.
class VideoFilmstrip extends StatefulWidget {
  const VideoFilmstrip({
    super.key,
    required this.frames,
    required this.materialId,
    required this.timing,
    required this.framesPerSecond,
  });

  /// Null while no frame source is ready (nothing is drawn).
  final VideoFrameProvider? frames;
  final String materialId;
  final VideoFilmstripTiming timing;
  final double framesPerSecond;

  /// The narrowest a slot is drawn, and the most slots one clip has (a long
  /// clip at a high zoom spreads them out instead of decoding hundreds).
  static const double minSlotWidth = 40;
  static const int maxSlots = 32;

  /// How many slots a clip [width] wide holds when a frame is [frameWidth]
  /// wide: at least 1, at most [maxSlots] and the clip's frame count.
  static int slotCountFor({
    required double width,
    required double frameWidth,
    required int lengthFrames,
  }) {
    if (!width.isFinite || width <= 0 || lengthFrames <= 0) return 0;
    final slot = math.max(minSlotWidth, frameWidth);
    return (width / slot).ceil().clamp(1, math.min(maxSlots, lengthFrames));
  }

  /// The timeline frame each of [slots] slots across a clip shows: the
  /// frame under the middle of the slot.
  static List<int> slotFrames({
    required int startFrame,
    required int lengthFrames,
    required int slots,
  }) => [
    for (var i = 0; i < slots; i++)
      startFrame +
          math.min(
            lengthFrames - 1,
            ((i + 0.5) * lengthFrames / slots).floor(),
          ),
  ];

  @override
  State<VideoFilmstrip> createState() => _VideoFilmstripState();
}

class _VideoFilmstripState extends State<VideoFilmstrip> {
  /// Width / height of the video's picture (16:9 until it is read).
  double _aspect = 16 / 9;
  String? _aspectFor;

  List<ui.Image?> _images = const [];
  Object? _requested;
  int _epoch = 0;

  @override
  void didUpdateWidget(covariant VideoFilmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.frames, widget.frames) ||
        oldWidget.materialId != widget.materialId) {
      _aspectFor = null;
    }
  }

  @override
  void dispose() {
    _epoch++;
    for (final image in _images) {
      image?.dispose();
    }
    super.dispose();
  }

  Future<void> _readAspect(VideoFrameProvider frames) async {
    final key = '${identityHashCode(frames)}:${widget.materialId}';
    if (_aspectFor == key) return;
    _aspectFor = key;
    final result = await frames.timelineOf(widget.materialId);
    if (!mounted || _aspectFor != key) return;
    if (result case VideoTimelineReady(:final timeline)) {
      final w = timeline.displayWidth;
      final h = timeline.displayHeight;
      if (w != null && h != null && w > 0 && h > 0 && w / h != _aspect) {
        setState(() => _aspect = w / h);
      }
    }
  }

  /// Asks for the slots' frames when what they show changed.
  void _request({
    required VideoFrameProvider frames,
    required List<int> timelineFrames,
    required int pixelWidth,
    required int pixelHeight,
  }) {
    final timing = widget.timing;
    final key = (
      identityHashCode(frames),
      widget.materialId,
      timing,
      widget.framesPerSecond,
      Object.hashAll(timelineFrames),
      pixelWidth,
      pixelHeight,
    );
    if (key == _requested) return;
    _requested = key;
    final epoch = ++_epoch;
    if (_images.length != timelineFrames.length) {
      for (final image in _images) {
        image?.dispose();
      }
      _images = List<ui.Image?>.filled(timelineFrames.length, null);
    }
    bool stale() => !mounted || epoch != _epoch;
    for (var slot = 0; slot < timelineFrames.length; slot++) {
      final time = TimelineVideoTimeMapper.sourceTimeAt(
        timelineFrame: timelineFrames[slot],
        clipStartFrame: timing.startFrame,
        clipLengthFrames: timing.lengthFrames,
        sourceTrimStartFrame: timing.trimStartFrame,
        sourceTrimEndFrame: timing.trimEndFrame,
        framesPerSecond: widget.framesPerSecond,
        playbackRate: timing.playbackRate,
      );
      if (time == null) continue;
      frames
          .frameAt(
            materialId: widget.materialId,
            sourceTime: time,
            width: pixelWidth,
            height: pixelHeight,
            latestKey: 'filmstrip:${identityHashCode(this)}:$slot',
            isCancelled: stale,
          )
          .then(
            (result) {
              if (result is! VideoFrameReady) return;
              if (stale() || slot >= _images.length) {
                result.image.dispose();
                return;
              }
              setState(() {
                _images[slot]?.dispose();
                _images[slot] = result.image;
              });
            },
            onError: (Object _) {
              // A frame that cannot be read leaves its slot empty.
            },
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.frames;
    if (frames == null) return const SizedBox.shrink();
    _readAspect(frames);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite || !height.isFinite || height <= 0) {
          return const SizedBox.shrink();
        }
        final frameWidth = height * _aspect;
        final count = VideoFilmstrip.slotCountFor(
          width: width,
          frameWidth: frameWidth,
          lengthFrames: widget.timing.lengthFrames,
        );
        if (count == 0) return const SizedBox.shrink();
        final timelineFrames = VideoFilmstrip.slotFrames(
          startFrame: widget.timing.startFrame,
          lengthFrames: widget.timing.lengthFrames,
          slots: count,
        );
        final pixelHeight = (height * dpr).round().clamp(1, 512);
        final pixelWidth = (frameWidth * dpr).round().clamp(1, 912);
        // Not during build: the results call setState.
        Future.microtask(() {
          if (!mounted) return;
          _request(
            frames: frames,
            timelineFrames: timelineFrames,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
          );
        });
        final images = _images.length == count
            ? _images
            : List<ui.Image?>.filled(count, null);
        return ClipRect(
          child: Row(
            children: [
              for (var slot = 0; slot < count; slot++)
                SizedBox(
                  key: ValueKey('filmstripSlot$slot'),
                  width: width / count,
                  height: height,
                  child: images[slot] == null
                      ? null
                      : RawImage(
                          image: images[slot],
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
