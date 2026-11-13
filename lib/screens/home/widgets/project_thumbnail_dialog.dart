import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_codec;

import '../../../l10n/app_localizations.dart';
import '../../../models/project.dart';
import '../../../models/scene.dart';
import '../../../services/frame_thumbnail_renderer.dart';
import '../../../services/project_service.dart';

/// A four-choice project thumbnail editor shared by owned and received
/// projects. The selected frame is previewed with the same scene compositor
/// as the editor; Apply is the only operation that changes stored metadata.
Future<void> showProjectThumbnailDialog(
  BuildContext context, {
  required Project project,
  required ProjectService service,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ProjectThumbnailDialog(project: project, service: service),
);

class _ProjectThumbnailDialog extends StatefulWidget {
  const _ProjectThumbnailDialog({required this.project, required this.service});
  final Project project;
  final ProjectService service;

  @override
  State<_ProjectThumbnailDialog> createState() =>
      _ProjectThumbnailDialogState();
}

class _ProjectThumbnailDialogState extends State<_ProjectThumbnailDialog> {
  late String mode;
  String? sceneId;
  int frameIndex = 0;
  Uint8List? customBytes;
  String? customName;
  bool saving = false;
  bool playing = false;
  String? error;
  ui.Image? preview;
  Timer? timer;
  int renderSequence = 0;

  List<Scene> get scenes => widget.service.scenesOf(widget.project.id);
  Scene? get scene =>
      scenes.where((s) => s.id == sceneId).firstOrNull ??
      (scenes.isNotEmpty ? scenes.first : null);
  int get total => scene?.frames.length ?? 0;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    mode = widget.project.thumbnailMode;
    final selected =
        widget.project.thumbnailFrameSceneId ??
        widget.project.thumbnailLastSceneId;
    final all = scenes;
    sceneId = all.any((s) => s.id == selected)
        ? selected
        : (all.isNotEmpty ? all.first.id : null);
    final count = scene?.frames.length ?? 0;
    frameIndex = count == 0
        ? 0
        : (widget.project.thumbnailFrameIndex ??
                  widget.project.thumbnailLastFrameIndex ??
                  0)
              .clamp(0, count - 1);
    if (mode == 'frame') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _render());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    preview?.dispose();
    super.dispose();
  }

  Future<void> _render() async {
    final selectedScene = scene;
    if (selectedScene == null || selectedScene.frames.isEmpty) return;
    final sequence = ++renderSequence;
    try {
      final rendered = await compositeFrameThumbnail(
        widget.service,
        projectId: widget.project.id,
        sceneId: selectedScene.id,
        frameIndex: frameIndex,
        maxSize: 420,
      );
      if (!mounted || sequence != renderSequence) {
        rendered?.dispose();
        return;
      }
      setState(() {
        preview?.dispose();
        preview = rendered;
        error = null;
      });
    } catch (_) {
      if (mounted && sequence == renderSequence) {
        setState(() => error = l10n.thumbnailPreviewFailed);
      }
    }
  }

  void _seek(int index) {
    if (total <= 0) return;
    setState(() => frameIndex = index.clamp(0, total - 1));
    _render();
  }

  void _stop() {
    timer?.cancel();
    timer = null;
    if (mounted && playing) setState(() => playing = false);
  }

  void _togglePlayback() {
    if (playing) {
      _stop();
      return;
    }
    if (total < 2) return;
    setState(() => playing = true);
    final fps = widget.project.fps.clamp(1, 60);
    timer = Timer.periodic(Duration(milliseconds: (1000 / fps).round()), (_) {
      if (!mounted || mode != 'frame') {
        _stop();
        return;
      }
      _seek((frameIndex + 1) % total);
    });
  }

  void _setMode(String? next) {
    if (next == null) return;
    _stop();
    setState(() {
      mode = next;
      error = null;
    });
    if (mode == 'frame') _render();
  }

  Future<void> _chooseImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.first;
      final bytes =
          selected.bytes ??
          (selected.path == null
              ? null
              : await File(selected.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('Invalid image');
      }
      // The on-disk project thumbnail format is PNG. Converting here also
      // validates file contents rather than trusting the user extension.
      final decoded = image_codec.decodeImage(bytes);
      if (decoded == null) throw const FormatException('Unsupported image');
      final png = Uint8List.fromList(image_codec.encodePng(decoded));
      if (!mounted) return;
      setState(() {
        customBytes = png;
        customName = selected.name;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = l10n.thumbnailImageLoadFailed);
      }
    }
  }

  Future<void> _apply() async {
    _stop();
    setState(() => saving = true);
    try {
      await widget.service.setProjectThumbnail(
        widget.project.id,
        mode: mode,
        sceneId: mode == 'frame' ? scene?.id : null,
        frameIndex: mode == 'frame' ? frameIndex : null,
        customBytes: mode == 'custom' ? customBytes : null,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = l10n.thumbnailSaveFailed;
        });
      }
    }
  }

  Widget _framePanel() => Column(
    key: const Key('projectThumbnailFramePanel'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 10),
      if (scenes.length > 1)
        DropdownButtonFormField<String>(
          key: const Key('projectThumbnailScene'),
          initialValue: sceneId,
          isExpanded: true,
          items: [
            for (final s in scenes)
              DropdownMenuItem(value: s.id, child: Text(s.displayName)),
          ],
          onChanged: (value) {
            _stop();
            setState(() {
              sceneId = value;
              frameIndex = 0;
            });
            _render();
          },
        ),
      AspectRatio(
        aspectRatio:
            widget.project.exportWidth /
            widget.project.exportHeight.clamp(1, 100000),
        child: Container(
          key: const Key('projectThumbnailFramePreview'),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: preview == null
              ? const Center(child: Icon(Icons.image_outlined))
              : RawImage(image: preview, fit: BoxFit.contain),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        l10n.thumbnailCurrentFrame(total == 0 ? 0 : frameIndex + 1, total),
        key: const Key('projectThumbnailFrameCount'),
        textAlign: TextAlign.center,
      ),
      Slider(
        key: const Key('projectThumbnailSeek'),
        value: total > 0 ? frameIndex.toDouble() : 0,
        min: 0,
        max: (total > 1 ? total - 1 : 1).toDouble(),
        divisions: total > 1 ? total - 1 : 1,
        onChanged: total < 2 || saving
            ? null
            : (value) {
                _stop();
                _seek(value.round());
              },
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            key: const Key('projectThumbnailFirstFrame'),
            tooltip: l10n.projectDetailFirstFrameTooltip,
            icon: const Icon(Icons.skip_previous),
            onPressed: total == 0
                ? null
                : () {
                    _stop();
                    _seek(0);
                  },
          ),
          IconButton(
            key: const Key('projectThumbnailPreviousFrame'),
            tooltip: l10n.projectDetailPrevFrameTooltip,
            icon: const Icon(Icons.fast_rewind),
            onPressed: total == 0
                ? null
                : () {
                    _stop();
                    _seek(frameIndex - 1);
                  },
          ),
          IconButton(
            key: const Key('projectThumbnailPlayPause'),
            tooltip: playing ? l10n.commonPause : l10n.commonPlay,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: total < 2 ? null : _togglePlayback,
          ),
          IconButton(
            key: const Key('projectThumbnailNextFrame'),
            tooltip: l10n.projectDetailNextFrameTooltip,
            icon: const Icon(Icons.fast_forward),
            onPressed: total == 0
                ? null
                : () {
                    _stop();
                    _seek(frameIndex + 1);
                  },
          ),
          IconButton(
            key: const Key('projectThumbnailLastFrame'),
            tooltip: l10n.projectDetailLastFrameTooltip,
            icon: const Icon(Icons.skip_next),
            onPressed: total == 0
                ? null
                : () {
                    _stop();
                    _seek(total - 1);
                  },
          ),
        ],
      ),
    ],
  );

  Widget _customPanel() => Column(
    key: const Key('projectThumbnailCustomPanel'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const Key('projectThumbnailChooseImage'),
        onPressed: saving ? null : _chooseImage,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(l10n.thumbnailChooseDeviceImage),
      ),
      if (customName != null) ...[
        Text(customName!, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
      ],
      if (customBytes != null)
        Image.memory(
          customBytes!,
          key: const Key('projectThumbnailCustomPreview'),
          height: 120,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.thumbnailChangeAction),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<String>(
              groupValue: mode,
              onChanged: (value) {
                if (!saving) _setMode(value);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    key: const Key('projectThumbnailLatest'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.thumbnailLastSavedFrame),
                    value: 'latest',
                  ),
                  RadioListTile<String>(
                    key: const Key('projectThumbnailFrame'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.thumbnailSelectFrame),
                    value: 'frame',
                  ),
                  RadioListTile<String>(
                    key: const Key('projectThumbnailCustom'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.thumbnailChooseDeviceImage),
                    value: 'custom',
                  ),
                  RadioListTile<String>(
                    key: const Key('projectThumbnailNone'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.thumbnailHide),
                    value: 'none',
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.topCenter,
              child: switch (mode) {
                'frame' => _framePanel(),
                'custom' => _customPanel(),
                _ => const SizedBox.shrink(),
              },
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () {
                  _stop();
                  Navigator.pop(context);
                },
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('projectThumbnailApply'),
          onPressed:
              saving ||
                  (mode == 'frame' && total == 0) ||
                  (mode == 'custom' && customBytes == null)
              ? null
              : _apply,
          child: Text(l10n.commonApply),
        ),
      ],
    );
  }
}
