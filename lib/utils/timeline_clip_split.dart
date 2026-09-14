/// タイムライン素材クリップを再生ヘッド位置で左右2つへ分割したときの
/// フレーム範囲を表す純粋な計算結果。
class TimelineClipSplit {
  final int leftLengthFrames;
  final int rightStartFrame;
  final int rightLengthFrames;
  final int leftSourceStartFrame;
  final int leftSourceEndFrame;
  final int rightSourceStartFrame;
  final int rightSourceEndFrame;

  const TimelineClipSplit({
    required this.leftLengthFrames,
    required this.rightStartFrame,
    required this.rightLengthFrames,
    required this.leftSourceStartFrame,
    required this.leftSourceEndFrame,
    required this.rightSourceStartFrame,
    required this.rightSourceEndFrame,
  });
}

/// 範囲カットで削除範囲の左右に残るクリップのフレーム情報。
class TimelineClipRangeCut {
  final int leftStartFrame;
  final int leftLengthFrames;
  final int leftSourceStartFrame;
  final int leftSourceEndFrame;
  final int rightStartFrame;
  final int rightLengthFrames;
  final int rightSourceStartFrame;
  final int rightSourceEndFrame;

  const TimelineClipRangeCut({
    required this.leftStartFrame,
    required this.leftLengthFrames,
    required this.leftSourceStartFrame,
    required this.leftSourceEndFrame,
    required this.rightStartFrame,
    required this.rightLengthFrames,
    required this.rightSourceStartFrame,
    required this.rightSourceEndFrame,
  });
}

/// 固定された分割カーソルに対してタイムライン側を左右へ動かすとき、
/// カーソル位置として扱うフレームを選択クリップの先頭〜末尾境界へ制限する。
/// 先頭・末尾そのものまでは移動できるが、そこより外側へは進めない。
int clampSplitCutCursorFrame({
  required int candidateFrame,
  required int clipStartFrame,
  required int lengthFrames,
}) {
  final clipEndFrame = clipStartFrame + lengthFrames;
  return candidateFrame.clamp(clipStartFrame, clipEndFrame);
}

/// 固定カーソルがクリップ内部の境界にある場合だけ分割を確定できる。
/// 先頭・末尾では片側が0フレームになるため、ハサミボタンは無効化する。
bool canConfirmSplitCut({
  required int cursorFrame,
  required int clipStartFrame,
  required int lengthFrames,
}) {
  if (lengthFrames < 2) return false;
  final clipEndFrame = clipStartFrame + lengthFrames;
  return cursorFrame > clipStartFrame && cursorFrame < clipEndFrame;
}

/// [splitFrame]を右側クリップの先頭フレームとして、1本のクリップを左右へ
/// 分割する。クリップの先頭・末尾（または範囲外）では片側が0フレームに
/// なるため分割不可としてnullを返す。
///
/// [sourceStartFrame]は素材ファイル内で元クリップが使い始めるフレーム。
/// 動画のsourceTrimStartと、分割後の音声オフセットの双方に利用できる。
TimelineClipSplit? splitTimelineClip({
  required int clipStartFrame,
  required int lengthFrames,
  required int splitFrame,
  int sourceStartFrame = 0,
}) {
  if (lengthFrames < 2) return null;
  final clipEndFrame = clipStartFrame + lengthFrames;
  if (splitFrame <= clipStartFrame || splitFrame >= clipEndFrame) return null;

  final leftLengthFrames = splitFrame - clipStartFrame;
  final rightLengthFrames = clipEndFrame - splitFrame;
  final rightSourceStartFrame = sourceStartFrame + leftLengthFrames;

  return TimelineClipSplit(
    leftLengthFrames: leftLengthFrames,
    rightStartFrame: splitFrame,
    rightLengthFrames: rightLengthFrames,
    leftSourceStartFrame: sourceStartFrame,
    leftSourceEndFrame: rightSourceStartFrame - 1,
    rightSourceStartFrame: rightSourceStartFrame,
    rightSourceEndFrame: sourceStartFrame + lengthFrames - 1,
  );
}

/// [cutStartFrame]（含む）〜[cutEndFrameExclusive]（含まない）を削除し、
/// その左右に残る範囲を返す。選択範囲は必ず元クリップの内側に収まる必要が
/// あり、空範囲・逆転範囲・クリップ全体の削除はnullにする。
TimelineClipRangeCut? cutTimelineClipRange({
  required int clipStartFrame,
  required int lengthFrames,
  required int cutStartFrame,
  required int cutEndFrameExclusive,
  int sourceStartFrame = 0,
}) {
  if (lengthFrames < 2) return null;
  final clipEndFrame = clipStartFrame + lengthFrames;
  if (cutStartFrame < clipStartFrame ||
      cutEndFrameExclusive > clipEndFrame ||
      cutStartFrame >= cutEndFrameExclusive) {
    return null;
  }
  if (cutStartFrame == clipStartFrame && cutEndFrameExclusive == clipEndFrame) {
    return null;
  }

  final leftLengthFrames = cutStartFrame - clipStartFrame;
  final rightLengthFrames = clipEndFrame - cutEndFrameExclusive;
  final cutOffsetEnd = cutEndFrameExclusive - clipStartFrame;

  return TimelineClipRangeCut(
    leftStartFrame: clipStartFrame,
    leftLengthFrames: leftLengthFrames,
    leftSourceStartFrame: sourceStartFrame,
    leftSourceEndFrame: sourceStartFrame + leftLengthFrames - 1,
    rightStartFrame: cutEndFrameExclusive,
    rightLengthFrames: rightLengthFrames,
    rightSourceStartFrame: sourceStartFrame + cutOffsetEnd,
    rightSourceEndFrame: sourceStartFrame + lengthFrames - 1,
  );
}
