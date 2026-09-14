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

  group('fixed split cursor', () {
    test(
      'timeline may move only until the selected clip edges reach the cursor',
      () {
        expect(
          clampSplitCutCursorFrame(
            candidateFrame: 5,
            clipStartFrame: 10,
            lengthFrames: 8,
          ),
          10,
        );
        expect(
          clampSplitCutCursorFrame(
            candidateFrame: 14,
            clipStartFrame: 10,
            lengthFrames: 8,
          ),
          14,
        );
        expect(
          clampSplitCutCursorFrame(
            candidateFrame: 30,
            clipStartFrame: 10,
            lengthFrames: 8,
          ),
          18,
        );
      },
    );

    test(
      'cut can be confirmed only when the fixed cursor is inside the clip',
      () {
        expect(
          canConfirmSplitCut(
            cursorFrame: 10,
            clipStartFrame: 10,
            lengthFrames: 8,
          ),
          isFalse,
        );
        expect(
          canConfirmSplitCut(
            cursorFrame: 14,
            clipStartFrame: 10,
            lengthFrames: 8,
          ),
          isTrue,
        );
        expect(
          canConfirmSplitCut(
            cursorFrame: 18,
            clipStartFrame: 10,
            lengthFrames: 8,
          ),
          isFalse,
        );
      },
    );
  });

  group('cutTimelineClipRange', () {
    test(
      'removes a middle range and preserves both remaining source ranges',
      () {
        final result = cutTimelineClipRange(
          clipStartFrame: 10,
          lengthFrames: 12,
          cutStartFrame: 13,
          cutEndFrameExclusive: 18,
          sourceStartFrame: 40,
        );

        expect(result, isNotNull);
        expect(result!.leftStartFrame, 10);
        expect(result.leftLengthFrames, 3);
        expect(result.leftSourceStartFrame, 40);
        expect(result.leftSourceEndFrame, 42);
        expect(result.rightStartFrame, 18);
        expect(result.rightLengthFrames, 4);
        expect(result.rightSourceStartFrame, 48);
        expect(result.rightSourceEndFrame, 51);
      },
    );

    test('allows cutting from the clip start leaving only the right side', () {
      final result = cutTimelineClipRange(
        clipStartFrame: 10,
        lengthFrames: 8,
        cutStartFrame: 10,
        cutEndFrameExclusive: 13,
        sourceStartFrame: 20,
      );

      expect(result, isNotNull);
      expect(result!.leftLengthFrames, 0);
      expect(result.rightStartFrame, 13);
      expect(result.rightLengthFrames, 5);
      expect(result.rightSourceStartFrame, 23);
    });

    test('allows cutting through the clip end leaving only the left side', () {
      final result = cutTimelineClipRange(
        clipStartFrame: 10,
        lengthFrames: 8,
        cutStartFrame: 15,
        cutEndFrameExclusive: 18,
        sourceStartFrame: 20,
      );

      expect(result, isNotNull);
      expect(result!.leftLengthFrames, 5);
      expect(result.rightLengthFrames, 0);
      expect(result.leftSourceEndFrame, 24);
    });

    test('rejects empty, reversed, outside, and full-clip ranges', () {
      final ranges = <(int, int)>[
        (12, 12),
        (14, 13),
        (9, 12),
        (12, 19),
        (10, 18),
      ];
      for (final range in ranges) {
        expect(
          cutTimelineClipRange(
            clipStartFrame: 10,
            lengthFrames: 8,
            cutStartFrame: range.$1,
            cutEndFrameExclusive: range.$2,
          ),
          isNull,
          reason: 'range=$range',
        );
      }
    });
  });
}
