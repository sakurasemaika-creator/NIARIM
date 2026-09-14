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
