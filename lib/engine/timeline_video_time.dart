/// Maps a timeline frame to the source-video timestamp for preview and
/// future offline rendering. Both paths can call this pure evaluator. Source trim bounds are inclusive frame indices,
/// matching Layer.sourceTrimStart/sourceTrimEnd and the existing timeline UI.
class TimelineVideoTimeMapper {
  const TimelineVideoTimeMapper._();

  /// Returns the source frame position (fractional frames are retained) or
  /// null when the timeline frame is outside the clip or the inputs are invalid.
  static double? sourceFrameAt({
    required int timelineFrame,
    required int clipStartFrame,
    required int clipLengthFrames,
    required int sourceTrimStartFrame,
    required int sourceTrimEndFrame,
    required double playbackRate,
  }) {
    if (clipLengthFrames <= 0 ||
        sourceTrimStartFrame < 0 ||
        sourceTrimEndFrame < sourceTrimStartFrame ||
        !playbackRate.isFinite ||
        playbackRate <= 0) {
      return null;
    }
    final elapsed = timelineFrame - clipStartFrame;
    if (elapsed < 0 || elapsed >= clipLengthFrames) return null;
    final source = sourceTrimStartFrame + elapsed * playbackRate;
    return source
        .clamp(sourceTrimStartFrame.toDouble(), sourceTrimEndFrame.toDouble())
        .toDouble();
  }

  /// Converts a mapped source-frame position to the player timestamp.
  /// [framesPerSecond] is the project's timeline FPS, matching the current
  /// preview contract (source trim frame indices are interpreted at this FPS).
  static Duration? sourcePositionAt({
    required int timelineFrame,
    required int clipStartFrame,
    required int clipLengthFrames,
    required int sourceTrimStartFrame,
    required int sourceTrimEndFrame,
    required double framesPerSecond,
    double playbackRate = 1,
  }) {
    if (!framesPerSecond.isFinite || framesPerSecond <= 0) return null;
    final sourceFrame = sourceFrameAt(
      timelineFrame: timelineFrame,
      clipStartFrame: clipStartFrame,
      clipLengthFrames: clipLengthFrames,
      sourceTrimStartFrame: sourceTrimStartFrame,
      sourceTrimEndFrame: sourceTrimEndFrame,
      playbackRate: playbackRate,
    );
    if (sourceFrame == null) return null;
    return Duration(
      milliseconds: (sourceFrame / framesPerSecond * 1000).round(),
    );
  }

  /// The source timestamp used to choose a decoded video frame, at
  /// microsecond precision. Preview compositing and offline export both
  /// pass this value to the shared frame selection rule
  /// (`VideoFrameTimeline.frameIndexAt`), so neither path rounds to the
  /// millisecond grid of [sourcePositionAt] (which is only for player seeks).
  static Duration? sourceTimeAt({
    required int timelineFrame,
    required int clipStartFrame,
    required int clipLengthFrames,
    required int sourceTrimStartFrame,
    required int sourceTrimEndFrame,
    required double framesPerSecond,
    double playbackRate = 1,
  }) {
    if (!framesPerSecond.isFinite || framesPerSecond <= 0) return null;
    final sourceFrame = sourceFrameAt(
      timelineFrame: timelineFrame,
      clipStartFrame: clipStartFrame,
      clipLengthFrames: clipLengthFrames,
      sourceTrimStartFrame: sourceTrimStartFrame,
      sourceTrimEndFrame: sourceTrimEndFrame,
      playbackRate: playbackRate,
    );
    if (sourceFrame == null) return null;
    return Duration(
      microseconds: (sourceFrame / framesPerSecond * 1000000).round(),
    );
  }
}
