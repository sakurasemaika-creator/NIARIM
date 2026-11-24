import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/timeline_video_time.dart';

void main() {
  group('TimelineVideoTimeMapper', () {
    test('maps clip-relative frames onto the source trim', () {
      expect(
        TimelineVideoTimeMapper.sourceFrameAt(
          timelineFrame: 14,
          clipStartFrame: 10,
          clipLengthFrames: 8,
          sourceTrimStartFrame: 24,
          sourceTrimEndFrame: 31,
          playbackRate: 1,
        ),
        28,
      );
    });

    test('keeps fractional source frames for non-integer playback rates', () {
      expect(
        TimelineVideoTimeMapper.sourceFrameAt(
          timelineFrame: 11,
          clipStartFrame: 10,
          clipLengthFrames: 8,
          sourceTrimStartFrame: 3,
          sourceTrimEndFrame: 20,
          playbackRate: 1.5,
        ),
        4.5,
      );
    });

    test('clamps the source position to the inclusive trim end', () {
      expect(
        TimelineVideoTimeMapper.sourceFrameAt(
          timelineFrame: 17,
          clipStartFrame: 10,
          clipLengthFrames: 8,
          sourceTrimStartFrame: 5,
          sourceTrimEndFrame: 7,
          playbackRate: 2,
        ),
        7,
      );
    });

    test('returns null outside the clip and for invalid rates or trims', () {
      double? map(int frame, {double rate = 1, int end = 10}) =>
          TimelineVideoTimeMapper.sourceFrameAt(
            timelineFrame: frame,
            clipStartFrame: 4,
            clipLengthFrames: 3,
            sourceTrimStartFrame: 0,
            sourceTrimEndFrame: end,
            playbackRate: rate,
          );

      expect(map(3), isNull);
      expect(map(7), isNull);
      expect(map(4, rate: 0), isNull);
      expect(map(4, rate: double.nan), isNull);
      expect(map(4, end: -1), isNull);
    });

    test('converts source frames to rounded player timestamps', () {
      expect(
        TimelineVideoTimeMapper.sourcePositionAt(
          timelineFrame: 12,
          clipStartFrame: 10,
          clipLengthFrames: 6,
          sourceTrimStartFrame: 20,
          sourceTrimEndFrame: 25,
          framesPerSecond: 24,
        ),
        const Duration(milliseconds: 917),
      );
    });

    test('rejects invalid project FPS', () {
      expect(
        TimelineVideoTimeMapper.sourcePositionAt(
          timelineFrame: 10,
          clipStartFrame: 10,
          clipLengthFrames: 2,
          sourceTrimStartFrame: 0,
          sourceTrimEndFrame: 1,
          framesPerSecond: 0,
        ),
        isNull,
      );
    });
  });
}
