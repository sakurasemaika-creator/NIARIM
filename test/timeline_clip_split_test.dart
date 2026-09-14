import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/utils/timeline_clip_split.dart';

void main() {
  group('splitTimelineClip', () {
    test('splits a clip at an interior timeline frame', () {
      final result = splitTimelineClip(
        clipStartFrame: 10,
        lengthFrames: 12,
        splitFrame: 15,
        sourceStartFrame: 0,
      );

      expect(result, isNotNull);
      expect(result!.leftLengthFrames, 5);
      expect(result.rightStartFrame, 15);
      expect(result.rightLengthFrames, 7);
      expect(result.leftSourceStartFrame, 0);
      expect(result.leftSourceEndFrame, 4);
      expect(result.rightSourceStartFrame, 5);
      expect(result.rightSourceEndFrame, 11);
    });

    test('preserves a non-zero source trim offset', () {
      final result = splitTimelineClip(
        clipStartFrame: 20,
        lengthFrames: 8,
        splitFrame: 23,
        sourceStartFrame: 40,
      );

      expect(result, isNotNull);
      expect(result!.leftSourceStartFrame, 40);
      expect(result.leftSourceEndFrame, 42);
      expect(result.rightSourceStartFrame, 43);
      expect(result.rightSourceEndFrame, 47);
    });

    test('rejects split points at or outside clip boundaries', () {
      expect(
        splitTimelineClip(
          clipStartFrame: 10,
          lengthFrames: 6,
          splitFrame: 10,
          sourceStartFrame: 0,
        ),
        isNull,
      );
      expect(
        splitTimelineClip(
          clipStartFrame: 10,
          lengthFrames: 6,
          splitFrame: 16,
          sourceStartFrame: 0,
        ),
        isNull,
      );
      expect(
        splitTimelineClip(
          clipStartFrame: 10,
          lengthFrames: 6,
          splitFrame: 9,
          sourceStartFrame: 0,
        ),
        isNull,
      );
    });
  });
}
