from pathlib import Path

util = Path('lib/utils/timeline_clip_split.dart')
s = util.read_text()
helper = '''

/// カット位置をプレビュー再生ヘッドとして使える実フレームへ丸めて制限する。
/// タイムラインの有効範囲は0〜totalFrames-1。空/不正な総フレーム数でも0を返す。
int cutPreviewFrame({required double boundaryFrame, required int totalFrames}) {
  if (totalFrames <= 1) return 0;
  return boundaryFrame.round().clamp(0, totalFrames - 1);
}
'''
if 'int cutPreviewFrame(' not in s:
    util.write_text(s.rstrip() + helper)

p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()

cancel_anchor = '''  void _cancelClipCut() {
    setState(() {
      _clipCutMode = null;
      _cutClipId = null;
    });
  }
'''
preview_helper = '''  void _cancelClipCut() {
    setState(() {
      _clipCutMode = null;
      _cutClipId = null;
    });
  }

  /// カット候補位置へ再生ヘッドを合わせる。位置調整中に再生していた場合は
  /// 一度停止し、通常の再生ボタンからその候補位置を起点に音声/動画を
  /// すぐ確認できるようにする。カットモード自体は解除しない。
  void _setCutPreviewFrame(double boundaryFrame) {
    final nextFrame = cutPreviewFrame(
      boundaryFrame: boundaryFrame,
      totalFrames: _totalFrames,
    );
    final wasPlaying = _isPlaying;
    if (wasPlaying) {
      _playTimer?.cancel();
      _pauseAllMedia();
    }
    setState(() {
      _currentFrame = nextFrame;
      if (wasPlaying) _isPlaying = false;
    });
    _syncMediaPlayback();
  }
'''
if '_setCutPreviewFrame(' not in s:
    if cancel_anchor not in s:
        raise SystemExit('cancel anchor not found')
    s = s.replace(cancel_anchor, preview_helper, 1)

split_start_old = '''  void _startSplitCut(_TrackClip clip) {
    if (clip.lengthFrames < 2) return;
    setState(() {
      _clipCutMode = _ClipCutMode.split;
      _cutClipId = clip.id;
      _splitCutPositionFrame = clip.startFrame + (clip.lengthFrames / 2.0);
    });
  }
'''
split_start_new = '''  void _startSplitCut(_TrackClip clip) {
    if (clip.lengthFrames < 2) return;
    setState(() {
      _clipCutMode = _ClipCutMode.split;
      _cutClipId = clip.id;
      _splitCutPositionFrame = clip.startFrame + (clip.lengthFrames / 2.0);
    });
    _setCutPreviewFrame(_splitCutPositionFrame);
  }
'''
if split_start_old in s:
    s = s.replace(split_start_old, split_start_new, 1)
elif '_setCutPreviewFrame(_splitCutPositionFrame);' not in s:
    raise SystemExit('split start anchor not found')

split_drag_old = '''            onHorizontalDragUpdate: isSplitTarget
                ? (details) {
                    final candidate =
                        _splitCutPositionFrame - details.delta.dx / _cellW;
                    setState(() {
                      _splitCutPositionFrame = clampSplitCutCursorFrame(
                        candidateFrame: candidate.round(),
                        clipStartFrame: clip.startFrame,
                        lengthFrames: clip.lengthFrames,
                      ).toDouble();
                    });
                  }
                : null,
'''
split_drag_new = '''            onHorizontalDragUpdate: isSplitTarget
                ? (details) {
                    final candidate =
                        _splitCutPositionFrame - details.delta.dx / _cellW;
                    final nextFrame = clampSplitCutCursorFrame(
                      candidateFrame: candidate.round(),
                      clipStartFrame: clip.startFrame,
                      lengthFrames: clip.lengthFrames,
                    );
                    setState(() {
                      _splitCutPositionFrame = nextFrame.toDouble();
                    });
                    _setCutPreviewFrame(_splitCutPositionFrame);
                  }
                : null,
'''
if split_drag_old in s:
    s = s.replace(split_drag_old, split_drag_new, 1)
elif 'final nextFrame = clampSplitCutCursorFrame(' not in s:
    raise SystemExit('split drag block not found')

range_old = '''        onHorizontalDragUpdate: (details) {
          setState(() {
            if (isStart) {
              _rangeCutStartPositionFrame =
                  (_rangeCutStartPositionFrame + details.delta.dx / _cellW)
                      .clamp(
                        clip.startFrame.toDouble(),
                        _rangeCutEndPositionFrame - 1,
                      );
            } else {
              _rangeCutEndPositionFrame =
                  (_rangeCutEndPositionFrame + details.delta.dx / _cellW).clamp(
                    _rangeCutStartPositionFrame + 1,
                    (clip.startFrame + clip.lengthFrames).toDouble(),
                  );
            }
          });
        },
'''
range_new = '''        onHorizontalDragUpdate: (details) {
          setState(() {
            if (isStart) {
              _rangeCutStartPositionFrame =
                  (_rangeCutStartPositionFrame + details.delta.dx / _cellW)
                      .clamp(
                        clip.startFrame.toDouble(),
                        _rangeCutEndPositionFrame - 1,
                      );
            } else {
              _rangeCutEndPositionFrame =
                  (_rangeCutEndPositionFrame + details.delta.dx / _cellW).clamp(
                    _rangeCutStartPositionFrame + 1,
                    (clip.startFrame + clip.lengthFrames).toDouble(),
                  );
            }
          });
          _setCutPreviewFrame(
            isStart ? _rangeCutStartPositionFrame : _rangeCutEndPositionFrame,
          );
        },
'''
if range_old in s:
    s = s.replace(range_old, range_new, 1)
elif 'isStart ? _rangeCutStartPositionFrame : _rangeCutEndPositionFrame' not in s:
    raise SystemExit('range drag block not found')

p.write_text(s)
