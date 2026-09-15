from pathlib import Path

p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()


def one(old: str, new: str, label: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, got {count}')
    s = s.replace(old, new, 1)


one(
    "import '../../services/watermark_service.dart';\n",
    "import '../../services/watermark_service.dart';\nimport '../../utils/timeline_clip_split.dart';\n",
    'import',
)
state_anchor = "  ({String sourceSceneId, List<_TrackClip> clips, bool isCut})? _clipClipboard;\n"
one(
    state_anchor,
    state_anchor
    + "\n  _TrackClip? _clipCutTarget;\n"
    + "  int? _clipSplitCursorFrame;\n"
    + "  int? _clipRangeCutStartFrame;\n"
    + "  int? _clipRangeCutEndFrameExclusive;\n",
    'state',
)
marker = "  // ─── クリップの複数選択・コピー・切り取り・貼り付け ─────────\n"
methods = '''  void _startClipSplitCut(_TrackClip clip) {
    final frame = clampSplitCutCursorFrame(
      candidateFrame: _currentFrame,
      clipStartFrame: clip.startFrame,
      lengthFrames: clip.lengthFrames,
    );
    setState(() {
      _clipCutTarget = clip;
      _clipSplitCursorFrame = frame;
      _clipRangeCutStartFrame = null;
      _clipRangeCutEndFrameExclusive = null;
    });
  }

  void _startClipRangeCut(_TrackClip clip) {
    if (clip.lengthFrames < 2) return;
    final start = clip.startFrame + 1;
    final end = (start + 1).clamp(
      start + 1,
      clip.startFrame + clip.lengthFrames,
    );
    setState(() {
      _clipCutTarget = clip;
      _clipSplitCursorFrame = null;
      _clipRangeCutStartFrame = start;
      _clipRangeCutEndFrameExclusive = end;
    });
  }

  int _clipCutPreviewFrame(_TrackClip clip, double boundaryFrame) =>
      cutPreviewFrame(
        boundaryFrame: boundaryFrame - clip.startFrame + clip.useStart,
        totalFrames: (clip.useEnd - clip.useStart + 1).clamp(1, 1 << 30),
      );

  Future<void> _confirmClipSplitCut() async {
    final clip = _clipCutTarget;
    final cursor = _clipSplitCursorFrame;
    final sceneId = _selectedSceneId;
    if (clip == null || cursor == null || sceneId == null) return;
    final split = splitTimelineClip(
      clipStartFrame: clip.startFrame,
      lengthFrames: clip.lengthFrames,
      splitFrame: cursor,
      sourceStartFrame: clip.useStart,
    );
    if (split == null) return;
    final originalEnd = clip.useEnd;
    clip.lengthFrames = split.leftLengthFrames;
    clip.useEnd = split.leftSourceEndFrame;
    _persistClipUpdate(clip, sceneId);
    final right = _TrackClip(
      id: clip.id,
      label: clip.label,
      startFrame: split.rightStartFrame,
      lengthFrames: split.rightLengthFrames,
      color: clip.color,
      trackType: clip.trackType,
      filePath: clip.filePath,
      materialId: clip.materialId,
      volume: clip.volume,
      fadeIn: clip.fadeIn,
      fadeOut: clip.fadeOut,
      useStart: split.rightSourceStartFrame,
      useEnd: originalEnd,
      videoOpacity: clip.videoOpacity,
      trackRow: clip.trackRow,
    );
    await _duplicateClipAt(right, split.rightStartFrame);
    if (!mounted) return;
    setState(() {
      _clipCutTarget = null;
      _clipSplitCursorFrame = null;
    });
  }

  Future<void> _confirmClipRangeCut() async {
    final clip = _clipCutTarget;
    final start = _clipRangeCutStartFrame;
    final end = _clipRangeCutEndFrameExclusive;
    final sceneId = _selectedSceneId;
    if (clip == null || start == null || end == null || sceneId == null) return;
    final cut = cutTimelineClipRange(
      clipStartFrame: clip.startFrame,
      lengthFrames: clip.lengthFrames,
      cutStartFrame: start,
      cutEndFrameExclusive: end,
      sourceStartFrame: clip.useStart,
    );
    if (cut == null) return;
    final original = _snapshotClip(clip);
    setState(() {
      _audioClips.remove(clip);
      _videoClips.remove(clip);
      _imageClips.remove(clip);
    });
    _deletePersistedClip(clip, sceneId);
    if (cut.leftLengthFrames > 0) {
      final left = _TrackClip(
        id: original.id,
        label: original.label,
        startFrame: cut.leftStartFrame,
        lengthFrames: cut.leftLengthFrames,
        color: original.color,
        trackType: original.trackType,
        filePath: original.filePath,
        materialId: original.materialId,
        volume: original.volume,
        fadeIn: original.fadeIn,
        fadeOut: original.fadeOut,
        useStart: cut.leftSourceStartFrame,
        useEnd: cut.leftSourceEndFrame,
        videoOpacity: original.videoOpacity,
        trackRow: original.trackRow,
      );
      await _duplicateClipAt(left, cut.leftStartFrame);
    }
    if (cut.rightLengthFrames > 0) {
      final right = _TrackClip(
        id: original.id,
        label: original.label,
        startFrame: cut.rightStartFrame,
        lengthFrames: cut.rightLengthFrames,
        color: original.color,
        trackType: original.trackType,
        filePath: original.filePath,
        materialId: original.materialId,
        volume: original.volume,
        fadeIn: original.fadeIn,
        fadeOut: original.fadeOut,
        useStart: cut.rightSourceStartFrame,
        useEnd: cut.rightSourceEndFrame,
        videoOpacity: original.videoOpacity,
        trackRow: original.trackRow,
      );
      await _duplicateClipAt(right, cut.rightStartFrame);
    }
    if (!mounted) return;
    setState(() {
      _clipCutTarget = null;
      _clipRangeCutStartFrame = null;
      _clipRangeCutEndFrameExclusive = null;
    });
  }

'''
one(marker, methods + marker, 'methods')
p.write_text(s)
