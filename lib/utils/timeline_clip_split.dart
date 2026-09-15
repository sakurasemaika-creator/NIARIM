class TimelineClipSplit {
  final int leftLengthFrames;
  final int rightStartFrame;
  final int rightLengthFrames;
  final int leftSourceStartFrame;
  final int leftSourceEndFrame;
  final int rightSourceStartFrame;
  final int rightSourceEndFrame;
  const TimelineClipSplit({required this.leftLengthFrames, required this.rightStartFrame, required this.rightLengthFrames, required this.leftSourceStartFrame, required this.leftSourceEndFrame, required this.rightSourceStartFrame, required this.rightSourceEndFrame});
}

class TimelineClipRangeCut {
  final int leftStartFrame;
  final int leftLengthFrames;
  final int leftSourceStartFrame;
  final int leftSourceEndFrame;
  final int rightStartFrame;
  final int rightLengthFrames;
  final int rightSourceStartFrame;
  final int rightSourceEndFrame;
  const TimelineClipRangeCut({required this.leftStartFrame, required this.leftLengthFrames, required this.leftSourceStartFrame, required this.leftSourceEndFrame, required this.rightStartFrame, required this.rightLengthFrames, required this.rightSourceStartFrame, required this.rightSourceEndFrame});
}

int clampSplitCutCursorFrame({required int candidateFrame, required int clipStartFrame, required int lengthFrames}) {
  return candidateFrame.clamp(clipStartFrame, clipStartFrame + lengthFrames);
}

bool canConfirmSplitCut({required int cursorFrame, required int clipStartFrame, required int lengthFrames}) {
  if (lengthFrames < 2) return false;
  return cursorFrame > clipStartFrame && cursorFrame < clipStartFrame + lengthFrames;
}

int cutPreviewFrame({required double boundaryFrame, required int totalFrames}) {
  if (totalFrames <= 1) return 0;
  return boundaryFrame.round().clamp(0, totalFrames - 1);
}

TimelineClipSplit? splitTimelineClip({required int clipStartFrame, required int lengthFrames, required int splitFrame, int sourceStartFrame = 0}) {
  if (lengthFrames < 2) return null;
  final end = clipStartFrame + lengthFrames;
  if (splitFrame <= clipStartFrame || splitFrame >= end) return null;
  final left = splitFrame - clipStartFrame;
  final right = end - splitFrame;
  final rightSource = sourceStartFrame + left;
  return TimelineClipSplit(leftLengthFrames: left, rightStartFrame: splitFrame, rightLengthFrames: right, leftSourceStartFrame: sourceStartFrame, leftSourceEndFrame: rightSource - 1, rightSourceStartFrame: rightSource, rightSourceEndFrame: sourceStartFrame + lengthFrames - 1);
}

TimelineClipRangeCut? cutTimelineClipRange({required int clipStartFrame, required int lengthFrames, required int cutStartFrame, required int cutEndFrameExclusive, int sourceStartFrame = 0}) {
  if (lengthFrames < 2) return null;
  final end = clipStartFrame + lengthFrames;
  if (cutStartFrame < clipStartFrame || cutEndFrameExclusive > end || cutStartFrame >= cutEndFrameExclusive) return null;
  if (cutStartFrame == clipStartFrame && cutEndFrameExclusive == end) return null;
  final left = cutStartFrame - clipStartFrame;
  final right = end - cutEndFrameExclusive;
  final offsetEnd = cutEndFrameExclusive - clipStartFrame;
  return TimelineClipRangeCut(leftStartFrame: clipStartFrame, leftLengthFrames: left, leftSourceStartFrame: sourceStartFrame, leftSourceEndFrame: sourceStartFrame + left - 1, rightStartFrame: cutEndFrameExclusive, rightLengthFrames: right, rightSourceStartFrame: sourceStartFrame + offsetEnd, rightSourceEndFrame: sourceStartFrame + lengthFrames - 1);
}
