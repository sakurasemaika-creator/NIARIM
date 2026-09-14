from pathlib import Path


def once(s: str, old: str, new: str, label: str) -> str:
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected 1 match, found {n}")
    return s.replace(old, new, 1)


p = Path('lib/screens/timeline/timeline_screen.dart')
s = p.read_text()

s = once(
    s,
    "import '../../utils/reorder_index.dart';",
    "import '../../utils/reorder_index.dart';\nimport '../../utils/timeline_clip_split.dart';",
    'split helper import',
)
s = once(
    s,
    "enum _ClipDragMode { move, resizeLeft, resizeRight }",
    "enum _ClipDragMode { move, resizeLeft, resizeRight }\n\n"
    "enum _ClipCutMode { split, range }",
    'cut mode enum',
)

# A lightweight paused video frame for video-track clips. Video containers that
# are imported through the audio picker remain _ClipTrackType.audio, so they
# never instantiate this widget and show waveform only.
marker = "class TimelineScreen extends StatefulWidget {"
video_thumb = r'''class _VideoFrameThumb extends StatefulWidget {
  final String filePath;
  final int sourceFrame;
  final double fps;

  const _VideoFrameThumb({
    super.key,
    required this.filePath,
    required this.sourceFrame,
    required this.fps,
  });

  @override
  State<_VideoFrameThumb> createState() => _VideoFrameThumbState();
}

class _VideoFrameThumbState extends State<_VideoFrameThumb> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoFrameThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.sourceFrame != widget.sourceFrame ||
        oldWidget.fps != widget.fps) {
      _disposeController();
      _load();
    }
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || !identical(controller, _controller)) return;
      final milliseconds = (widget.sourceFrame / widget.fps * 1000).round();
      await controller.seekTo(Duration(milliseconds: milliseconds));
      await controller.pause();
      if (mounted && identical(controller, _controller)) {
        setState(() => _ready = true);
      }
    } catch (_) {
      if (identical(controller, _controller)) {
        await controller.dispose();
        _controller = null;
      }
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _ready = false;
    if (controller != null) unawaited(controller.dispose());
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

'''
if s.count(marker) != 1:
    raise SystemExit('TimelineScreen marker missing')
s = s.replace(marker, video_thumb + marker, 1)

s = once(
    s,
    "  final List<_TrackClip> _imageClips = [];",
    "  final List<_TrackClip> _imageClips = [];\n\n"
    "  // カットUIは通常の移動・リサイズ操作とは排他。分割はカーソル固定で\n"
    "  // クリップ側を左右へ動かし、範囲カットだけ2本のハンドルを動かす。\n"
    "  _ClipCutMode? _clipCutMode;\n"
    "  String? _cutClipId;\n"
    "  double _splitCutPositionFrame = 0;\n"
    "  double _rangeCutStartPositionFrame = 0;\n"
    "  double _rangeCutEndPositionFrame = 0;",
    'cut state',
)

# While cutting, the normal select/copy toolbar becomes a compact confirm/cancel
# bar. Scissors is disabled at split edges and for an invalid/full range.
old_toolbar_head = '''  Widget _buildClipToolbar() {
    if (_videoClips.isEmpty && _audioClips.isEmpty && _clipClipboard == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;'''
new_toolbar_head = '''  Widget _buildClipToolbar() {
    if (_videoClips.isEmpty && _audioClips.isEmpty && _clipClipboard == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    if (_clipCutMode != null) {
      final clip = _activeCutClip;
      final canConfirm = clip != null &&
          (_clipCutMode == _ClipCutMode.split
              ? canConfirmSplitCut(
                  cursorFrame: _splitCutPositionFrame.round(),
                  clipStartFrame: clip.startFrame,
                  lengthFrames: clip.lengthFrames,
                )
              : cutTimelineClipRange(
                    clipStartFrame: clip.startFrame,
                    lengthFrames: clip.lengthFrames,
                    cutStartFrame: _rangeCutStartPositionFrame.round(),
                    cutEndFrameExclusive: _rangeCutEndPositionFrame.round(),
                    sourceStartFrame: clip.useStart,
                  ) !=
                  null);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              _clipCutMode == _ClipCutMode.split ? '分割' : '範囲カット',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const ValueKey('timeline_cut_confirm'),
              tooltip: l10n.commonCut,
              icon: const Icon(Icons.content_cut),
              onPressed: canConfirm ? _confirmClipCut : null,
            ),
            IconButton(
              key: const ValueKey('timeline_cut_cancel'),
              tooltip: l10n.commonCancel,
              icon: const Icon(Icons.close),
              onPressed: _cancelClipCut,
            ),
          ],
        ),
      );
    }'''
s = once(s, old_toolbar_head, new_toolbar_head, 'cut toolbar')

# Fixed central cursor is owned by the track row, not by the moving clip.
old_clip_map = "                ...clips.map((clip) => _buildClipWidget(clip, scrollCtrl)),"
new_clip_map = '''                ...clips.map((clip) => _buildClipWidget(clip, scrollCtrl)),
                if (_clipCutMode == _ClipCutMode.split &&
                    clips.any((clip) => clip.id == _cutClipId))
                  IgnorePointer(
                    child: Positioned(
                      left: (MediaQuery.sizeOf(context).width - 64) / 2 - 1,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: Container(
                        key: const ValueKey('timeline_fixed_cut_cursor'),
                        color: ThemeService.activeColorScheme.error,
                      ),
                    ),
                  ),'''
s = once(s, old_clip_map, new_clip_map, 'fixed cursor overlay')

# Clip rendering: only the selected split target moves beneath the fixed cursor.
s = once(
    s,
    "        final left = clip.startFrame * _cellW - scrollOffset;\n"
    "        final width = clip.lengthFrames * _cellW - _frameMargin * 2;",
    "        var left = clip.startFrame * _cellW - scrollOffset;\n"
    "        final width = clip.lengthFrames * _cellW - _frameMargin * 2;\n"
    "        final isSplitTarget = _clipCutMode == _ClipCutMode.split &&\n"
    "            _cutClipId == clip.id;\n"
    "        final isRangeTarget = _clipCutMode == _ClipCutMode.range &&\n"
    "            _cutClipId == clip.id;\n"
    "        if (isSplitTarget) {\n"
    "          final fixedCursorX = (MediaQuery.sizeOf(context).width - 64) / 2;\n"
    "          left = fixedCursorX -\n"
    "              (_splitCutPositionFrame - clip.startFrame) * _cellW;\n"
    "        }",
    'cut target position',
)
s = once(
    s,
    "        if (!isDragging &&\n            (left + width < 0 || left > MediaQuery.sizeOf(context).width)) {",
    "        if (!isDragging && !isSplitTarget &&\n"
    "            (left + width < 0 || left > MediaQuery.sizeOf(context).width)) {",
    'cut culling',
)
s = once(
    s,
    "          left: left.clamp(0.0, double.infinity),",
    "          left: isSplitTarget ? left : left.clamp(0.0, double.infinity),",
    'split left unclamped',
)

old_tap = '''            onTap: () {
              if (_isClipMultiSelect) {
                setState(() {
                  if (isSelected) {
                    _selectedClipIds.remove(clip.id);
                  } else {
                    _selectedClipIds.add(clip.id);
                  }
                });
              } else {
                _showEditClipDialog(clip);
              }
            },'''
new_tap = '''            onTap: () {
              if (_clipCutMode != null) return;
              if (_isClipMultiSelect) {
                setState(() {
                  if (isSelected) {
                    _selectedClipIds.remove(clip.id);
                  } else {
                    _selectedClipIds.add(clip.id);
                  }
                });
              } else {
                _showEditClipDialog(clip);
              }
            },
            onHorizontalDragUpdate: isSplitTarget
                ? (details) {
                    final candidate = _splitCutPositionFrame -
                        details.delta.dx / _cellW;
                    setState(() {
                      _splitCutPositionFrame = clampSplitCutCursorFrame(
                        candidateFrame: candidate.round(),
                        clipStartFrame: clip.startFrame,
                        lengthFrames: clip.lengthFrames,
                      ).toDouble();
                    });
                  }
                : null,'''
s = once(s, old_tap, new_tap, 'split drag gesture')

# Normal long-press movement and resize handles are disabled for the active cut.
s = s.replace(
    "            onLongPressStart: _isClipMultiSelect\n                ? null",
    "            onLongPressStart: (_isClipMultiSelect || _clipCutMode != null)\n                ? null",
    1,
)
s = s.replace(
    "            onLongPressMoveUpdate: _isClipMultiSelect\n                ? null",
    "            onLongPressMoveUpdate: (_isClipMultiSelect || _clipCutMode != null)\n                ? null",
    1,
)
s = s.replace(
    "            onLongPressEnd: _isClipMultiSelect\n                ? null",
    "            onLongPressEnd: (_isClipMultiSelect || _clipCutMode != null)\n                ? null",
    1,
)

# Video clips use a paused frame thumbnail only. Audio clips (including video
# containers imported as audio) continue to render waveform only.
old_waveform = '''                        if (clip.trackType == _ClipTrackType.audio &&
                            clip.filePath != null)
                          _AudioWaveformThumb(
                            key: ValueKey('wf_${clip.id}'),
                            filePath: clip.filePath!,
                            cacheKey: clip.materialId,
                          ),'''
new_waveform = '''                        if (clip.trackType == _ClipTrackType.audio &&
                            clip.filePath != null)
                          _AudioWaveformThumb(
                            key: ValueKey('wf_${clip.id}'),
                            filePath: clip.filePath!,
                            cacheKey: clip.materialId,
                          ),
                        if (clip.trackType == _ClipTrackType.video &&
                            clip.filePath != null)
                          _VideoFrameThumb(
                            key: ValueKey('video_thumb_${clip.id}_${clip.useStart}'),
                            filePath: clip.filePath!,
                            sourceFrame: clip.useStart,
                            fps: _projectFps,
                          ),'''
s = once(s, old_waveform, new_waveform, 'video preview')

# Range selection overlay plus two independent draggable handles.
old_handles = '''                if (!_isClipMultiSelect) ...[
                  _buildClipResizeHandle(clip, handleW, isLeft: true),
                  _buildClipResizeHandle(clip, handleW, isLeft: false),
                ],'''
new_handles = '''                if (isRangeTarget) ...[
                  Positioned(
                    left: ((_rangeCutStartPositionFrame - clip.startFrame) * _cellW)
                        .clamp(0.0, width),
                    top: 0,
                    bottom: 0,
                    width: ((_rangeCutEndPositionFrame -
                                _rangeCutStartPositionFrame) *
                            _cellW)
                        .clamp(0.0, width),
                    child: IgnorePointer(
                      child: Container(
                        color: ThemeService.activeColorScheme.error.withValues(
                          alpha: 0.22,
                        ),
                      ),
                    ),
                  ),
                  _buildRangeCutHandle(clip, isStart: true),
                  _buildRangeCutHandle(clip, isStart: false),
                ] else if (!_isClipMultiSelect && _clipCutMode == null) ...[
                  _buildClipResizeHandle(clip, handleW, isLeft: true),
                  _buildClipResizeHandle(clip, handleW, isLeft: false),
                ],'''
s = once(s, old_handles, new_handles, 'range handles')

# Insert cut helpers before normal resize helper.
anchor = "  Widget _buildClipResizeHandle(\n"
if s.count(anchor) != 1:
    raise SystemExit('resize helper anchor missing')
helpers = r'''  _TrackClip? get _activeCutClip => [
        ..._videoClips,
        ..._audioClips,
      ].where((clip) => clip.id == _cutClipId).firstOrNull;

  double get _projectFps {
    final project = _projectService.projects
        .where((project) => project.id == widget.projectId)
        .firstOrNull;
    return (project?.fps ?? 24).toDouble();
  }

  void _startSplitCut(_TrackClip clip) {
    if (clip.lengthFrames < 2) return;
    setState(() {
      _clipCutMode = _ClipCutMode.split;
      _cutClipId = clip.id;
      _splitCutPositionFrame =
          clip.startFrame + (clip.lengthFrames / 2.0);
    });
  }

  void _startRangeCut(_TrackClip clip) {
    if (clip.lengthFrames < 2) return;
    setState(() {
      _clipCutMode = _ClipCutMode.range;
      _cutClipId = clip.id;
      _rangeCutStartPositionFrame = clip.startFrame.toDouble();
      _rangeCutEndPositionFrame =
          (clip.startFrame + clip.lengthFrames).toDouble();
    });
  }

  void _cancelClipCut() {
    setState(() {
      _clipCutMode = null;
      _cutClipId = null;
    });
  }

  Widget _buildRangeCutHandle(_TrackClip clip, {required bool isStart}) {
    final position = isStart
        ? _rangeCutStartPositionFrame
        : _rangeCutEndPositionFrame;
    final x = (position - clip.startFrame) * _cellW;
    return Positioned(
      left: x - 9,
      top: 0,
      bottom: 0,
      width: 18,
      child: GestureDetector(
        key: ValueKey(isStart
            ? 'timeline_range_cut_start'
            : 'timeline_range_cut_end'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
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
                  (_rangeCutEndPositionFrame + details.delta.dx / _cellW)
                      .clamp(
                        _rangeCutStartPositionFrame + 1,
                        (clip.startFrame + clip.lengthFrames).toDouble(),
                      );
            }
          });
        },
        child: Center(
          child: Container(
            width: 3,
            color: ThemeService.activeColorScheme.error,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClipCut() async {
    final clip = _activeCutClip;
    final sceneId = _selectedSceneId;
    final mode = _clipCutMode;
    if (clip == null || sceneId == null || mode == null) return;

    if (mode == _ClipCutMode.split) {
      final splitFrame = _splitCutPositionFrame.round();
      final result = splitTimelineClip(
        clipStartFrame: clip.startFrame,
        lengthFrames: clip.lengthFrames,
        splitFrame: splitFrame,
        sourceStartFrame: clip.useStart,
      );
      if (result == null) return;
      final right = _TrackClip(
        id: clip.id,
        label: clip.label,
        startFrame: result.rightStartFrame,
        lengthFrames: result.rightLengthFrames,
        color: clip.color,
        trackType: clip.trackType,
        filePath: clip.filePath,
        materialId: clip.materialId,
        volume: clip.volume,
        fadeIn: 0,
        fadeOut: clip.fadeOut,
        useStart: result.rightSourceStartFrame,
        useEnd: result.rightSourceEndFrame,
        videoOpacity: clip.videoOpacity,
        trackRow: clip.trackRow,
      );
      clip.lengthFrames = result.leftLengthFrames;
      clip.useStart = result.leftSourceStartFrame;
      clip.useEnd = result.leftSourceEndFrame;
      if (clip.trackType == _ClipTrackType.audio) clip.fadeOut = 0;
      _persistClipUpdate(clip, sceneId);
      await _duplicateClipAt(
        right,
        right.startFrame,
        overrideTrackRow: right.trackRow,
      );
    } else {
      final result = cutTimelineClipRange(
        clipStartFrame: clip.startFrame,
        lengthFrames: clip.lengthFrames,
        cutStartFrame: _rangeCutStartPositionFrame.round(),
        cutEndFrameExclusive: _rangeCutEndPositionFrame.round(),
        sourceStartFrame: clip.useStart,
      );
      if (result == null) return;
      final hadLeft = result.leftLengthFrames > 0;
      final hadRight = result.rightLengthFrames > 0;
      if (hadLeft && hadRight) {
        final right = _TrackClip(
          id: clip.id,
          label: clip.label,
          startFrame: result.rightStartFrame,
          lengthFrames: result.rightLengthFrames,
          color: clip.color,
          trackType: clip.trackType,
          filePath: clip.filePath,
          materialId: clip.materialId,
          volume: clip.volume,
          fadeIn: 0,
          fadeOut: clip.fadeOut,
          useStart: result.rightSourceStartFrame,
          useEnd: result.rightSourceEndFrame,
          videoOpacity: clip.videoOpacity,
          trackRow: clip.trackRow,
        );
        clip.lengthFrames = result.leftLengthFrames;
        clip.useStart = result.leftSourceStartFrame;
        clip.useEnd = result.leftSourceEndFrame;
        if (clip.trackType == _ClipTrackType.audio) clip.fadeOut = 0;
        _persistClipUpdate(clip, sceneId);
        await _duplicateClipAt(
          right,
          right.startFrame,
          overrideTrackRow: right.trackRow,
        );
      } else if (hadLeft) {
        clip.lengthFrames = result.leftLengthFrames;
        clip.useStart = result.leftSourceStartFrame;
        clip.useEnd = result.leftSourceEndFrame;
        if (clip.trackType == _ClipTrackType.audio) clip.fadeOut = 0;
        _persistClipUpdate(clip, sceneId);
      } else if (hadRight) {
        clip.startFrame = result.rightStartFrame;
        clip.lengthFrames = result.rightLengthFrames;
        clip.useStart = result.rightSourceStartFrame;
        clip.useEnd = result.rightSourceEndFrame;
        if (clip.trackType == _ClipTrackType.audio) clip.fadeIn = 0;
        _persistClipUpdate(clip, sceneId);
      }
    }

    if (!mounted) return;
    _cancelClipCut();
  }

'''
s = s.replace(anchor, helpers + anchor, 1)

# Add cut choices to the clip sheet and wire callbacks.
s = once(
    s,
    "        totalFrames: _totalFrames,\n        onDelete: () {",
    "        totalFrames: _totalFrames,\n"
    "        onStartSplit: () => _startSplitCut(clip),\n"
    "        onStartRangeCut: () => _startRangeCut(clip),\n"
    "        onDelete: () {",
    'sheet cut callbacks',
)
s = once(
    s,
    "  final int totalFrames;\n  final VoidCallback onDelete;",
    "  final int totalFrames;\n"
    "  final VoidCallback onStartSplit;\n"
    "  final VoidCallback onStartRangeCut;\n"
    "  final VoidCallback onDelete;",
    'sheet cut fields',
)
s = once(
    s,
    "    required this.totalFrames,\n    required this.onDelete,",
    "    required this.totalFrames,\n"
    "    required this.onStartSplit,\n"
    "    required this.onStartRangeCut,\n"
    "    required this.onDelete,",
    'sheet cut ctor',
)
old_list_children = '''              children: [
                if (_c.trackType == _ClipTrackType.audio) ...['''
new_list_children = '''              children: [
                if (_c.trackType != _ClipTrackType.image) ...[
                  ListTile(
                    key: const ValueKey('timeline_split_cut_action'),
                    leading: const Icon(Icons.vertical_split),
                    title: const Text('分割'),
                    subtitle: const Text('中央の固定カーソルに素材を合わせて分割'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onStartSplit();
                    },
                  ),
                  ListTile(
                    key: const ValueKey('timeline_range_cut_action'),
                    leading: const Icon(Icons.content_cut),
                    title: const Text('範囲カット'),
                    subtitle: const Text('2本のカーソルで削除する範囲を選択'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onStartRangeCut();
                    },
                  ),
                  const Divider(),
                ],
                if (_c.trackType == _ClipTrackType.audio) ...['''
s = once(s, old_list_children, new_list_children, 'sheet cut choices')

p.write_text(s)
