import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'video_frame_decoder.dart';
import 'video_frame_timeline.dart';
import 'video_material_snapshot.dart';

/// The outcome of asking a [VideoFrameProvider] for a frame.
sealed class VideoFrameResult {
  const VideoFrameResult(this.materialId);

  final String materialId;
}

/// A decoded frame. The caller owns [image] and must dispose it; the
/// provider's cache keeps its own handle, so evicting the cache never
/// invalidates an image already returned.
final class VideoFrameReady extends VideoFrameResult {
  const VideoFrameReady(
    super.materialId, {
    required this.image,
    required this.frameIndex,
    required this.presentationTime,
  });

  final ui.Image image;
  final int frameIndex;
  final Duration presentationTime;
}

enum VideoFrameUnavailableReason {
  /// The material is not in the job's snapshot.
  unknownMaterial,

  /// The material is registered but its file is missing.
  missingFile,

  /// The file could not be probed or has no video frames.
  unreadable,

  /// The selected frame could not be decoded.
  decodeFailed,

  /// A newer request with the same latest key replaced this one.
  superseded,

  /// The caller's cancellation check became true.
  cancelled,

  /// The provider was disposed.
  disposed;

  /// Whether the material itself has a problem the user should be told
  /// about, as opposed to a request that was simply no longer wanted.
  bool get isFailure => switch (this) {
    unknownMaterial || missingFile || unreadable || decodeFailed => true,
    superseded || cancelled || disposed => false,
  };
}

/// No frame. Callers must not substitute a placeholder or another frame
/// for a failure ([VideoFrameUnavailableReason.isFailure]).
final class VideoFrameUnavailable extends VideoFrameResult {
  const VideoFrameUnavailable(super.materialId, this.reason, {this.error});

  final VideoFrameUnavailableReason reason;
  final Object? error;
}

/// The outcome of reading a material's frame table.
sealed class VideoTimelineResult {
  const VideoTimelineResult();
}

final class VideoTimelineReady extends VideoTimelineResult {
  const VideoTimelineReady(this.timeline);

  final VideoFrameTimeline timeline;
}

final class VideoTimelineUnavailable extends VideoTimelineResult {
  const VideoTimelineUnavailable(this.reason, {this.error});

  final VideoFrameUnavailableReason reason;
  final Object? error;
}

/// Supplies decoded video material frames to one preview session or one
/// export job.
///
/// - Material files come only from the immutable [snapshot] taken when the
///   session or job started.
/// - A source time selects a frame with [VideoFrameTimeline.frameIndexAt],
///   the rule shared by preview and export; times that select the same frame
///   share one decode.
/// - Decoded images live in an LRU cache bounded by [cacheBudgetBytes]; at
///   most [maxConcurrentDecodes] decodes run at once.
/// - Requests sharing a `latestKey` (e.g. one preview layer while
///   scrubbing) are latest-wins: an older request returns
///   [VideoFrameUnavailableReason.superseded], and if it has not started
///   decoding yet it never decodes.
/// - [dispose] releases every cached image; decodes that finish afterwards
///   release their images instead of caching them.
class VideoFrameProvider {
  VideoFrameProvider({
    required this.snapshot,
    required this.decoder,
    this.cacheBudgetBytes = defaultCacheBudgetBytes,
    int maxConcurrentDecodes = 2,
  }) : assert(cacheBudgetBytes >= 0),
       _slots = _DecodeSlots(maxConcurrentDecodes);

  /// About eleven 1920×1080 frames.
  static const defaultCacheBudgetBytes = 96 * 1024 * 1024;

  final VideoMaterialSnapshot snapshot;
  final VideoFrameDecoder decoder;
  final int cacheBudgetBytes;
  final _DecodeSlots _slots;

  final Map<String, Future<VideoTimelineResult>> _timelines = {};
  final LinkedHashMap<_FrameKey, ui.Image> _cache = LinkedHashMap();
  final Map<_FrameKey, _PendingDecode> _inFlight = {};
  final Map<String, int> _latestGeneration = {};
  int _cachedBytes = 0;
  int _decodeCount = 0;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Decodes actually run (not served from the cache or skipped).
  int get decodeCount => _decodeCount;

  int get cachedFrameCount => _cache.length;

  int get cachedBytes => _cachedBytes;

  int get inFlightCount => _inFlight.length;

  /// The frame table of [materialId], read once per provider.
  Future<VideoTimelineResult> timelineOf(String materialId) async {
    if (_disposed) {
      return const VideoTimelineUnavailable(
        VideoFrameUnavailableReason.disposed,
      );
    }
    final source = snapshot[materialId];
    if (source == null) {
      return const VideoTimelineUnavailable(
        VideoFrameUnavailableReason.unknownMaterial,
      );
    }
    final path = source.path;
    if (path == null) {
      return const VideoTimelineUnavailable(
        VideoFrameUnavailableReason.missingFile,
      );
    }
    return _timelines[materialId] ??= _probe(path);
  }

  Future<VideoTimelineResult> _probe(String path) async {
    try {
      return VideoTimelineReady(await decoder.probe(path));
    } catch (error) {
      return VideoTimelineUnavailable(
        VideoFrameUnavailableReason.unreadable,
        error: error,
      );
    }
  }

  /// The frame of [materialId] shown at [sourceTime], at [width]×[height]
  /// (see [DecodedVideoFrame] for the placement).
  Future<VideoFrameResult> frameAt({
    required String materialId,
    required Duration sourceTime,
    required int width,
    required int height,
    String? latestKey,
    bool Function()? isCancelled,
  }) async {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Frame size must be positive: ${width}x$height');
    }
    final generation = latestKey == null ? null : _nextGeneration(latestKey);
    VideoFrameUnavailableReason? discarded() {
      if (_disposed) return VideoFrameUnavailableReason.disposed;
      if (latestKey != null && _latestGeneration[latestKey] != generation) {
        return VideoFrameUnavailableReason.superseded;
      }
      if (isCancelled?.call() == true) {
        return VideoFrameUnavailableReason.cancelled;
      }
      return null;
    }

    final early = discarded();
    if (early != null) return VideoFrameUnavailable(materialId, early);

    final timelineResult = await timelineOf(materialId);
    final VideoFrameTimeline timeline;
    switch (timelineResult) {
      case VideoTimelineUnavailable(:final reason, :final error):
        return VideoFrameUnavailable(materialId, reason, error: error);
      case VideoTimelineReady(timeline: final ready):
        timeline = ready;
    }
    final afterProbe = discarded();
    if (afterProbe != null) {
      return VideoFrameUnavailable(materialId, afterProbe);
    }

    final index = timeline.frameIndexAt(sourceTime);
    if (index == null) {
      return VideoFrameUnavailable(
        materialId,
        VideoFrameUnavailableReason.unreadable,
      );
    }
    final key = _FrameKey(materialId, index, width, height);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // Most recently used.
      return VideoFrameReady(
        materialId,
        image: cached.clone(),
        frameIndex: index,
        presentationTime: timeline.presentationTimeOf(index),
      );
    }

    final waiter = _Waiter(() => discarded() == null);
    final pending = _inFlight[key];
    if (pending != null) {
      pending.waiters.add(waiter);
    } else {
      final started = _PendingDecode()..waiters.add(waiter);
      _inFlight[key] = started;
      unawaited(
        _runDecode(key, started, snapshot[materialId]!.path!, timeline),
      );
    }

    final ui.Image? image;
    try {
      image = await waiter.completer.future;
    } catch (error) {
      final reason = discarded();
      return VideoFrameUnavailable(
        materialId,
        reason ?? VideoFrameUnavailableReason.decodeFailed,
        error: reason == null ? error : null,
      );
    }
    final afterDecode = discarded();
    if (image == null || afterDecode != null) {
      image?.dispose();
      return VideoFrameUnavailable(
        materialId,
        afterDecode ?? VideoFrameUnavailableReason.superseded,
      );
    }
    return VideoFrameReady(
      materialId,
      image: image,
      frameIndex: index,
      presentationTime: timeline.presentationTimeOf(index),
    );
  }

  int _nextGeneration(String latestKey) =>
      _latestGeneration[latestKey] = (_latestGeneration[latestKey] ?? 0) + 1;

  Future<void> _runDecode(
    _FrameKey key,
    _PendingDecode pending,
    String path,
    VideoFrameTimeline timeline,
  ) async {
    await _slots.acquire();
    var released = false;
    void release() {
      if (!released) {
        released = true;
        _slots.release();
      }
    }

    try {
      // Nobody waiting still wants the frame (scrubbed past, cancelled,
      // disposed): skip the decode entirely.
      if (_disposed || !pending.waiters.any((w) => w.stillWanted())) {
        _inFlight.remove(key);
        for (final waiter in pending.waiters) {
          waiter.completer.complete(null);
        }
        return;
      }
      _decodeCount++;
      final ui.Image image;
      try {
        final frame = await decoder.decode(
          path: path,
          timeline: timeline,
          frameIndex: key.frameIndex,
          width: key.width,
          height: key.height,
        );
        release();
        image = await _imageFromRgba(frame.rgba, frame.width, frame.height);
      } catch (error, stackTrace) {
        _inFlight.remove(key);
        for (final waiter in pending.waiters) {
          waiter.completer.completeError(error, stackTrace);
        }
        return;
      }
      _inFlight.remove(key);
      // Every waiter, and the cache, gets its own handle; the original is
      // released once they have been handed out.
      for (final waiter in pending.waiters) {
        waiter.completer.complete(_disposed ? null : image.clone());
      }
      if (!_disposed) _store(key, image.clone());
      image.dispose();
    } finally {
      release();
    }
  }

  void _store(_FrameKey key, ui.Image image) {
    final bytes = key.byteSize;
    if (bytes > cacheBudgetBytes) {
      image.dispose();
      return;
    }
    _cache[key] = image;
    _cachedBytes += bytes;
    while (_cachedBytes > cacheBudgetBytes && _cache.isNotEmpty) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest)!.dispose();
      _cachedBytes -= oldest.byteSize;
    }
  }

  /// Releases every cached image. Decodes still running release their
  /// results when they finish; all later requests return
  /// [VideoFrameUnavailableReason.disposed].
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _cachedBytes = 0;
    _timelines.clear();
  }

  static Future<ui.Image> _imageFromRgba(
    Uint8List rgba,
    int width,
    int height,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    try {
      final codec = await descriptor.instantiateCodec();
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

class _FrameKey {
  const _FrameKey(this.materialId, this.frameIndex, this.width, this.height);

  final String materialId;
  final int frameIndex;
  final int width;
  final int height;

  int get byteSize => width * height * 4;

  @override
  bool operator ==(Object other) =>
      other is _FrameKey &&
      other.materialId == materialId &&
      other.frameIndex == frameIndex &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(materialId, frameIndex, width, height);
}

class _Waiter {
  _Waiter(this.stillWanted);

  final bool Function() stillWanted;
  final Completer<ui.Image?> completer = Completer<ui.Image?>();
}

class _PendingDecode {
  final List<_Waiter> waiters = [];
}

class _DecodeSlots {
  _DecodeSlots(this.max) : assert(max > 0);

  final int max;
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue();

  Future<void> acquire() {
    if (_active < max) {
      _active++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _active--;
    }
  }
}
