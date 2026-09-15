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
      expect(result!.leftSourceStartFrame, 40);
      expect(result.leftSourceEndFrame, 42);
      expect(result.rightSourceStartFrame, 43);
      expect(result.rightSourceEndFrame, 47);
    });

    test('rejects split points at clip boundaries', () {
      expect(splitTimelineClip(clipStartFrame: 10, lengthFrames: 6, splitFrame: 10), isNull);
      expect(splitTimelineClip(clipStartFrame: 10, lengthFrames: 6, splitFrame: 16), isNull);
    });
  });

  group('fixed split cursor', () {
    test('clamps movement to selected clip edges', () {
      expect(clampSplitCutCursorFrame(candidateFrame: 5, clipStartFrame: 10, lengthFrames: 8), 10);
      expect(clampSplitCutCursorFrame(candidateFrame: 14, clipStartFrame: 10, lengthFrames: 8), 14);
      expect(clampSplitCutCursorFrame(candidateFrame: 30, clipStartFrame: 10, lengthFrames: 8), 18);
    });

    test('confirms only inside the clip', () {
      expect(canConfirmSplitCut(cursorFrame: 10, clipStartFrame: 10, lengthFrames: 8), isFalse);
      expect(canConfirmSplitCut(cursorFrame: 14, clipStartFrame: 10, lengthFrames: 8), isTrue);
      expect(canConfirmSplitCut(cursorFrame: 18, clipStartFrame: 10, lengthFrames: 8), isFalse);
    });
  });

  test('cut preview frame is playable', () {
    expect(cutPreviewFrame(boundaryFrame: 13.6, totalFrames: 24), 14);
    expect(cutPreviewFrame(boundaryFrame: -3, totalFrames: 24), 0);
    expect(cutPreviewFrame(boundaryFrame: 100, totalFrames: 24), 23);
  });

  test('range cut preserves remaining source ranges', () {
    final result = cutTimelineClipRange(
      clipStartFrame: 10,
      lengthFrames: 12,
      cutStartFrame: 13,
      cutEndFrameExclusive: 18,
      sourceStartFrame: 40,
    );
    expect(result, isNotNull);
    expect(result!.leftLengthFrames, 3);
    expect(result.leftSourceEndFrame, 42);
    expect(result.rightStartFrame, 18);
    expect(result.rightLengthFrames, 4);
    expect(result.rightSourceStartFrame, 48);
    expect(result.rightSourceEndFrame, 51);
  });
}
