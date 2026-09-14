from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


# AudioClip: persist source offset so the right side of a split resumes from the
# correct position after save/reload.
p = Path("lib/models/audio_clip.dart")
s = p.read_text()
s = replace_once(
    s,
    "  final double fadeOut; // フェードアウト秒数\n  // 音声タイムラインの表示行番号",
    "  final double fadeOut; // フェードアウト秒数\n"
    "  // 素材ファイル内の使用開始フレーム。分割後の右側クリップが元素材の\n"
    "  // 途中から再生を継続できるよう保持する。旧データは0扱い。\n"
    "  final int sourceStartFrame;\n"
    "  // 音声タイムラインの表示行番号",
    "audio field",
)
s = replace_once(
    s,
    "    this.fadeOut = 0.0,\n    this.trackRow = 0,",
    "    this.fadeOut = 0.0,\n    this.sourceStartFrame = 0,\n    this.trackRow = 0,",
    "audio ctor",
)
s = replace_once(
    s,
    "    double? fadeOut,\n    int? trackRow,",
    "    double? fadeOut,\n    int? sourceStartFrame,\n    int? trackRow,",
    "audio copy args",
)
s = replace_once(
    s,
    "      fadeOut: fadeOut ?? this.fadeOut,\n      trackRow: trackRow ?? this.trackRow,",
    "      fadeOut: fadeOut ?? this.fadeOut,\n"
    "      sourceStartFrame: sourceStartFrame ?? this.sourceStartFrame,\n"
    "      trackRow: trackRow ?? this.trackRow,",
    "audio copy body",
)
p.write_text(s)

# Serializer: optional field keeps old projects compatible.
p = Path("lib/engine/niapro_serializer.dart")
s = p.read_text()
s = replace_once(
    s,
    "            'fadeOut': a.fadeOut,\n            'trackRow': a.trackRow,",
    "            'fadeOut': a.fadeOut,\n"
    "            'sourceStartFrame': a.sourceStartFrame,\n"
    "            'trackRow': a.trackRow,",
    "serialize audio offset",
)
s = replace_once(
    s,
    "          fadeOut: (m['fadeOut'] as num?)?.toDouble() ?? 0.0,\n"
    "          trackRow: m['trackRow'] as int? ?? 0,",
    "          fadeOut: (m['fadeOut'] as num?)?.toDouble() ?? 0.0,\n"
    "          sourceStartFrame: m['sourceStartFrame'] as int? ?? 0,\n"
    "          trackRow: m['trackRow'] as int? ?? 0,",
    "deserialize audio offset",
)
p.write_text(s)

p = Path("lib/screens/timeline/timeline_screen.dart")
s = p.read_text()
s = replace_once(
    s,
    "import '../../utils/reorder_index.dart';",
    "import '../../utils/reorder_index.dart';\nimport '../../utils/timeline_clip_split.dart';",
    "split import",
)
s = replace_once(
    s,
    "enum _ClipDragMode { move, resizeLeft, resizeRight }",
    "enum _ClipDragMode { move, resizeLeft, resizeRight }\n\n"
    "// 動画クリップのタイムライン内表示だけを切り替える。書き出しや素材自体には\n"
    "// 影響しない。音声は常に波形表示なのでこのenumは動画専用。\n"
    "enum _VideoClipVisualMode { waveform, preview }",
    "video mode enum",
)

marker = "class TimelineScreen extends StatefulWidget {"
if s.count(marker) != 1:
    raise SystemExit("timeline class marker missing")
video_widget = r'''class _VideoFrameThumb extends StatefulWidget {
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
      if (!mounted || !identical(_controller, controller)) return;
      final millis = (widget.sourceFrame / widget.fps * 1000).round();
      await controller.seekTo(Duration(milliseconds: millis));
      await controller.pause();
      if (mounted && identical(_controller, controller)) {
        setState(() => _ready = true);
      }
    } catch (_) {
      if (identical(_controller, controller)) {
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
s = s.replace(marker, video_widget + marker, 1)

s = replace_once(
    s,
    "  final List<_TrackClip> _imageClips = [];",
    "  final List<_TrackClip> _imageClips = [];\n"
    "  // 動画クリップごとのタイムライン表示方式。未指定時は画面プレビュー。\n"
    "  // 素材の内容や書き出し結果には影響しないUI状態。\n"
    "  final Map<String, _VideoClipVisualMode> _videoClipVisualModes = {};",
    "video visual state",
)

# Audio persistence/load/duplicate now preserves source offset.
s = replace_once(
    s,
    "          fadeOut: clip.fadeOut,\n        ),\n      );",
    "          fadeOut: clip.fadeOut,\n"
    "          sourceStartFrame: clip.useStart,\n"
    "          trackRow: clip.trackRow,\n"
    "        ),\n      );",
    "persist audio",
)
s = replace_once(
    s,
    "          fadeOut: a.fadeOut,\n          useEnd: a.lengthFrames - 1,",
    "          fadeOut: a.fadeOut,\n"
    "          useStart: a.sourceStartFrame,\n"
    "          useEnd: a.sourceStartFrame + a.lengthFrames - 1,",
    "load audio offset",
)
s = replace_once(
    s,
    "          fadeOut: clip.fadeOut,\n          trackRow: targetRow,\n        ),",
    "          fadeOut: clip.fadeOut,\n"
    "          sourceStartFrame: clip.useStart,\n"
    "          trackRow: targetRow,\n        ),",
    "duplicate audio model",
)
s = replace_once(
    s,
    "              fadeOut: clip.fadeOut,\n              useEnd: clip.lengthFrames - 1,",
    "              fadeOut: clip.fadeOut,\n"
    "              useStart: clip.useStart,\n"
    "              useEnd: clip.useStart + clip.lengthFrames - 1,",
    "duplicate audio ui",
)

old = """                        if (clip.trackType == _ClipTrackType.audio &&
                            clip.filePath != null)
                          _AudioWaveformThumb(
                            key: ValueKey('wf_${clip.id}'),
                            filePath: clip.filePath!,
                            cacheKey: clip.materialId,
                          ),
                        Padding("""
new = """                        if (clip.filePath != null &&
                            (clip.trackType == _ClipTrackType.audio ||
                                (clip.trackType == _ClipTrackType.video &&
                                    (_videoClipVisualModes[clip.id] ??
                                            _VideoClipVisualMode.preview) ==
                                        _VideoClipVisualMode.waveform)))
                          _AudioWaveformThumb(
                            key: ValueKey('wf_${clip.id}'),
                            filePath: clip.filePath!,
                            cacheKey: clip.materialId,
                          ),
                        if (clip.trackType == _ClipTrackType.video &&
                            clip.filePath != null &&
                            (_videoClipVisualModes[clip.id] ??
                                    _VideoClipVisualMode.preview) ==
                                _VideoClipVisualMode.preview)
                          _VideoFrameThumb(
                            key: ValueKey('video_thumb_${clip.id}_${clip.useStart}'),
                            filePath: clip.filePath!,
                            sourceFrame: clip.useStart,
                            fps: _projectFps,
                          ),
                        Padding("""
s = replace_once(s, old, new, "clip visual overlay")

s = replace_once(
    s,
    "  bool _clipInRange(_TrackClip clip) =>",
    "  double get _projectFps {\n"
    "    final project = _projectService.projects\n"
    "        .where((p) => p.id == widget.projectId)\n"
    "        .firstOrNull;\n"
    "    return (project?.fps ?? 24).toDouble();\n"
    "  }\n\n"
    "  bool _clipInRange(_TrackClip clip) =>",
    "fps getter",
)

anchor = "  void _showEditClipDialog(_TrackClip clip) {"
if s.count(anchor) != 1:
    raise SystemExit(f"edit clip anchor count={s.count(anchor)}")
split_impl = r'''  Future<void> _splitClipAtCurrentFrame(_TrackClip clip) async {
    if (clip.trackType == _ClipTrackType.image) return;
    final sceneId = _selectedSceneId;
    if (sceneId == null) return;
    final split = splitTimelineClip(
      clipStartFrame: clip.startFrame,
      lengthFrames: clip.lengthFrames,
      splitFrame: _currentFrame,
      sourceStartFrame: clip.useStart,
    );
    if (split == null) return;

    final oldFadeOut = clip.fadeOut;
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
      fadeIn: 0,
      fadeOut: oldFadeOut,
      useStart: split.rightSourceStartFrame,
      useEnd: split.rightSourceEndFrame,
      videoOpacity: clip.videoOpacity,
      trackRow: clip.trackRow,
    );

    clip.lengthFrames = split.leftLengthFrames;
    clip.useStart = split.leftSourceStartFrame;
    clip.useEnd = split.leftSourceEndFrame;
    if (clip.trackType == _ClipTrackType.audio) clip.fadeOut = 0;
    _persistClipUpdate(clip, sceneId);

    if (clip.trackType == _ClipTrackType.audio) {
      final id = 'audio_${DateTime.now().microsecondsSinceEpoch}';
      _projectService.addAudioClip(
        widget.projectId,
        sceneId,
        AudioClip(
          id: id,
          label: right.label,
          materialId: right.materialId,
          startFrame: right.startFrame,
          lengthFrames: right.lengthFrames,
          volume: right.volume,
          fadeIn: right.fadeIn,
          fadeOut: right.fadeOut,
          sourceStartFrame: right.useStart,
          trackRow: right.trackRow,
        ),
      );
      final rightClip = _TrackClip(
        id: id,
        label: right.label,
        startFrame: right.startFrame,
        lengthFrames: right.lengthFrames,
        color: right.color,
        trackType: right.trackType,
        filePath: right.filePath,
        materialId: right.materialId,
        volume: right.volume,
        fadeIn: right.fadeIn,
        fadeOut: right.fadeOut,
        useStart: right.useStart,
        useEnd: right.useEnd,
        trackRow: right.trackRow,
      );
      final player = _audioPlayers.remove(clip.id);
      if (player != null) unawaited(player.dispose());
      if (mounted) setState(() => _audioClips.add(rightClip));
      return;
    }

    final controller = _videoControllers.remove(clip.id);
    if (controller != null) unawaited(controller.dispose());
    await _duplicateClipAt(
      right,
      right.startFrame,
      overrideTrackRow: right.trackRow,
    );
  }

'''
s = s.replace(anchor, split_impl + anchor, 1)

s = replace_once(
    s,
    "        totalFrames: _totalFrames,\n        onDelete: () {",
    "        totalFrames: _totalFrames,\n"
    "        currentFrame: _currentFrame,\n"
    "        videoVisualMode: _videoClipVisualModes[clip.id] ??\n"
    "            _VideoClipVisualMode.preview,\n"
    "        onVideoVisualModeChanged: (mode) => setState(() {\n"
    "          _videoClipVisualModes[clip.id] = mode;\n"
    "        }),\n"
    "        onSplit: () async {\n"
    "          Navigator.pop(ctx);\n"
    "          await _splitClipAtCurrentFrame(clip);\n"
    "        },\n"
    "        onDelete: () {",
    "sheet call args",
)
s = replace_once(
    s,
    "  final int totalFrames;\n  final VoidCallback onDelete;",
    "  final int totalFrames;\n"
    "  final int currentFrame;\n"
    "  final _VideoClipVisualMode videoVisualMode;\n"
    "  final ValueChanged<_VideoClipVisualMode> onVideoVisualModeChanged;\n"
    "  final Future<void> Function() onSplit;\n"
    "  final VoidCallback onDelete;",
    "sheet fields",
)
s = replace_once(
    s,
    "    required this.totalFrames,\n    required this.onDelete,",
    "    required this.totalFrames,\n"
    "    required this.currentFrame,\n"
    "    required this.videoVisualMode,\n"
    "    required this.onVideoVisualModeChanged,\n"
    "    required this.onSplit,\n"
    "    required this.onDelete,",
    "sheet ctor args",
)
s = replace_once(
    s,
    "                IconButton(\n                  icon: const Icon(Icons.copy),",
    "                if (_c.trackType != _ClipTrackType.image)\n"
    "                  IconButton(\n"
    "                    key: const ValueKey('timeline_clip_split'),\n"
    "                    icon: const Icon(Icons.content_cut),\n"
    "                    tooltip: 'カット',\n"
    "                    onPressed: widget.currentFrame > _c.startFrame &&\n"
    "                            widget.currentFrame <\n"
    "                                _c.startFrame + _c.lengthFrames\n"
    "                        ? () => widget.onSplit()\n"
    "                        : null,\n"
    "                  ),\n"
    "                IconButton(\n                  icon: const Icon(Icons.copy),",
    "split button",
)
s = replace_once(
    s,
    "                if (_c.trackType == _ClipTrackType.video) ...[\n                  _row(",
    "                if (_c.trackType == _ClipTrackType.video) ...[\n"
    "                  SegmentedButton<_VideoClipVisualMode>(\n"
    "                    segments: const [\n"
    "                      ButtonSegment(\n"
    "                        value: _VideoClipVisualMode.waveform,\n"
    "                        icon: Icon(Icons.graphic_eq),\n"
    "                        label: Text('波形'),\n"
    "                      ),\n"
    "                      ButtonSegment(\n"
    "                        value: _VideoClipVisualMode.preview,\n"
    "                        icon: Icon(Icons.movie_outlined),\n"
    "                        label: Text('画面プレビュー'),\n"
    "                      ),\n"
    "                    ],\n"
    "                    selected: {widget.videoVisualMode},\n"
    "                    onSelectionChanged: (value) {\n"
    "                      if (value.isEmpty) return;\n"
    "                      widget.onVideoVisualModeChanged(value.first);\n"
    "                      setState(() {});\n"
    "                    },\n"
    "                  ),\n"
    "                  const SizedBox(height: 8),\n"
    "                  _row(",
    "video visual selector",
)
p.write_text(s)
