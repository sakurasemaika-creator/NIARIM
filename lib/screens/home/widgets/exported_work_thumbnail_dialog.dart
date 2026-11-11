import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_codec;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// Non-destructive display-only thumbnail metadata for exported media.
/// Never rewrites the actual exported .mp4/.webm/.gif/.png file.
class ExportedWorkCoverStore {
  static const prefsKey = 'exported_work_thumbnail_overrides_v1';

  static Future<Map<String, dynamic>> read(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _decode(prefs.getString(prefsKey));
    final entry = map[file.path];
    if (entry is! Map) return const {'mode': 'latest'};
    try {
      final stat = await file.stat();
      if (entry['sourceSize'] != stat.size ||
          entry['sourceModified'] != stat.modified.millisecondsSinceEpoch) {
        return const {'mode': 'latest'};
      }
    } on FileSystemException {
      return const {'mode': 'latest'};
    }
    return Map<String, dynamic>.from(entry);
  }

  static Map<String, dynamic> _decode(String? json) {
    try {
      final value = json == null ? null : jsonDecode(json);
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {}
    return {};
  }

  static Future<void> write(
    File file, {
    required String mode,
    String? imagePath,
    int? frameIndex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _decode(prefs.getString(prefsKey));
    final stat = await file.stat();
    current[file.path] = {
      'mode': mode,
      'imagePath': imagePath,
      'frameIndex': frameIndex,
      'sourceSize': stat.size,
      'sourceModified': stat.modified.millisecondsSinceEpoch,
    };
    if (!await prefs.setString(prefsKey, jsonEncode(current))) {
      throw const FileSystemException('Could not persist thumbnail choice');
    }
  }

  static Future<String?> displayPath(File file) async {
    final setting = await read(file);
    if (setting['mode'] == 'none') return null;
    final path = setting['imagePath'];
    if (path is String && path.isNotEmpty && await File(path).exists()) {
      return path;
    }
    // Image files can always use their original bytes as a cover.
    final suffix = file.path.split('.').last.toLowerCase();
    if (const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}
        .contains(suffix)) return file.path;
    return null;
  }
}

Future<void> showExportedWorkThumbnailDialog(
  BuildContext context, {
  required File file,
  VoidCallback? onApplied,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ExportedWorkThumbnailDialog(
      file: file,
      onApplied: onApplied,
    ),
  );
}

class _ExportedWorkThumbnailDialog extends StatefulWidget {
  const _ExportedWorkThumbnailDialog({
    required this.file,
    this.onApplied,
  });
  final File file;
  final VoidCallback? onApplied;

  @override
  State<_ExportedWorkThumbnailDialog> createState() =>
      _ExportedWorkThumbnailDialogState();
}

class _ExportedWorkThumbnailDialogState
    extends State<_ExportedWorkThumbnailDialog> {
  String mode = 'latest';
  VideoPlayerController? controller;
  bool ready = false;
  bool busy = false;
  bool playing = false;
  bool supportedFrames = false;
  String? failure;
  String? customName;
  Uint8List? customBytes;
  String? existingCover;
  double fps = 1;
  int totalFrames = 1;
  int frameIndex = 0;
  Timer? playbackPoll;
  Future<void>? _loading;

  bool get isImage => const {'png','jpg','jpeg','gif','bmp','webp'}
      .contains(widget.file.path.split('.').last.toLowerCase());

  String tr(String ja, String en) =>
      Localizations.localeOf(context).languageCode == 'ja' ? ja : en;

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  double _rate(String value) {
    final parts = value.split('/');
    final a = double.tryParse(parts.first) ?? 0;
    final b = parts.length > 1 ? (double.tryParse(parts[1]) ?? 0) : 1;
    return b == 0 ? 0 : a / b;
  }

  Future<void> _load() async {
    try {
      final setting = await ExportedWorkCoverStore.read(widget.file);
      final choice = setting['mode'];
      if (choice is String && const {'latest','frame','custom','none'}
          .contains(choice)) mode = choice;
      existingCover = setting['imagePath'] is String
          ? setting['imagePath'] as String
          : null;
      // Probe the media rather than assuming all exports are 30fps.
      final session = await FFprobeKit.getMediaInformation(widget.file.path);
      final info = await session.getMediaInformation();
      if (info != null) {
        final streams = info.getStreams();
        for (final stream in streams) {
          if (stream.getType() != 'video') continue;
          final rate = _rate(stream.getAverageFrameRate() ??
              stream.getRealFrameRate() ?? '0');
          if (rate > 0 && rate.isFinite) fps = rate;
          final number = int.tryParse(
              stream.getStringProperty('nb_frames') ?? '');
          if (number != null && number > 0) totalFrames = number;
          break;
        }
        final duration = double.tryParse(info.getDuration() ?? '');
        if (totalFrames <= 1 && duration != null &&
            duration > 0 && fps > 0) {
          totalFrames = math.max(1, (duration * fps).round());
        }
      }
      supportedFrames = totalFrames > 1;
      frameIndex = (setting['frameIndex'] is int
          ? setting['frameIndex'] as int : 0).clamp(0, totalFrames - 1);
      if (!isImage) {
        final player = VideoPlayerController.file(widget.file);
        controller = player;
        await player.initialize();
        if (mode == 'frame') await _seek(frameIndex);
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) setState(() {
        ready = true;
        supportedFrames = false;
        failure = tr('動画情報を読み取れませんでした',
            'Could not read media information');
      });
    }
  }

  Future<void> _seek(int target) async {
    final next = target.clamp(0, totalFrames - 1);
    setState(() => frameIndex = next);
    final player = controller;
    if (player == null || !player.value.isInitialized) return;
    await player.seekTo(Duration(microseconds:
        (next / fps * 1000000).round()));
  }

  void _stop() {
    playbackPoll?.cancel();
    playbackPoll = null;
    controller?.pause();
    if (mounted) setState(() => playing = false);
  }

  void _playPause() {
    final player = controller;
    if (player == null || !player.value.isInitialized) return;
    if (playing) {
      _stop();
    } else {
      player.play();
      setState(() => playing = true);
      playbackPoll = Timer.periodic(const Duration(milliseconds: 90), (_) {
        if (!mounted) return;
        final index = (player.value.position.inMicroseconds * fps / 1000000)
            .round().clamp(0, totalFrames - 1);
        setState(() {
          frameIndex = index;
          if (!player.value.isPlaying) playing = false;
        });
        if (!player.value.isPlaying) playbackPoll?.cancel();
      });
    }
  }

  Future<void> _chooseCustom() async {
    try {
      final selected = await FilePicker.platform.pickFiles(
          type: FileType.image, withData: true);
      if (selected == null || selected.files.isEmpty) return;
      final file = selected.files.first;
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('Invalid image');
      }
      final decoded = image_codec.decodeImage(bytes);
      if (decoded == null) throw const FormatException('Unsupported image');
      if (!mounted) return;
      setState(() {
        customBytes = Uint8List.fromList(image_codec.encodePng(decoded));
        customName = file.name;
        failure = null;
      });
    } catch (_) {
      if (mounted) setState(() =>
          failure = tr('画像を読み込めませんでした', 'Could not open the image'));
    }
  }

  static String quote(String path) =>
      '"${path.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  Future<String> _extract(int frame) async {
    final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/exported_covers');
    await dir.create(recursive: true);
    final output = File('${dir.path}/export_${DateTime.now().microsecondsSinceEpoch}.png');
    // Exact frame-number selection, not an approximate time seek.
    final filter = 'select=eq(n\\,$frame),scale=420:-2';
    final session = await FFmpegKit.execute(
      '-hide_banner -loglevel error -y -i ${quote(widget.file.path)} '
      '-vf "${filter}" -vsync 0 -frames:v 1 ${quote(output.path)}',
    );
    final exitCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(exitCode) ||
        !await output.exists() || await output.length() == 0) {
      throw const FileSystemException('Frame extraction failed');
    }
    return output.path;
  }

  Future<void> _apply() async {
    _stop();
    setState(() => busy = true);
    try {
      String? imagePath;
      if (mode == 'custom') {
        if (customBytes == null) {
          imagePath = existingCover;
        } else {
          final dir = Directory(
            '${(await getApplicationSupportDirectory()).path}/exported_covers');
          await dir.create(recursive: true);
          final file = File(
              '${dir.path}/custom_${DateTime.now().microsecondsSinceEpoch}.png');
          await file.writeAsBytes(customBytes!, flush: true);
          imagePath = file.path;
        }
      } else if (!isImage && (mode == 'frame' || mode == 'latest')) {
        imagePath = await _extract(
            mode == 'latest' ? totalFrames - 1 : frameIndex);
      } else if (isImage && mode != 'none') {
        imagePath = widget.file.path;
      }
      await ExportedWorkCoverStore.write(
        widget.file,
        mode: mode,
        imagePath: imagePath,
        frameIndex: mode == 'frame' ? frameIndex : null,
      );
      widget.onApplied?.call();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() {
        busy = false;
        failure = tr('サムネイルを保存できませんでした',
            'Could not save thumbnail');
      });
    }
  }

  @override
  void dispose() {
    playbackPoll?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Widget _framePanel() {
    final player = controller;
    return Column(
      key: const Key('exportCoverFramePanel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: player?.value.isInitialized == true &&
                  player!.value.aspectRatio > 0
              ? player.value.aspectRatio
              : 16/9,
          child: Container(
            key: const Key('exportCoverPreview'),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: player != null && player.value.isInitialized
                ? VideoPlayer(player)
                : Image.file(widget.file, fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_outlined)),
          ),
        ),
        Text(
          '${tr('現在のフレーム','Current frame')}: '
          '${frameIndex + 1} / $totalFrames',
          key: const Key('exportCoverFrameCount'),
          textAlign: TextAlign.center,
        ),
        Slider(
          key: const Key('exportCoverSeek'),
          value: frameIndex.toDouble(),
          min: 0,
          max: math.max(1,totalFrames - 1).toDouble(),
          onChanged: busy || totalFrames < 2 ? null : (value) {
            _stop(); _seek(value.round());
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              key: const Key('exportCoverFirst'),
              tooltip: tr('最初のフレーム','First frame'),
              onPressed: busy ? null : () { _stop(); _seek(0); },
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              key: const Key('exportCoverPrevious'),
              tooltip: tr('1フレーム戻る','Previous frame'),
              onPressed: busy ? null : () { _stop(); _seek(frameIndex-1); },
              icon: const Icon(Icons.fast_rewind),
            ),
            IconButton(
              key: const Key('exportCoverPlayback'),
              tooltip: tr('再生・停止','Play / pause'),
              onPressed: player == null || totalFrames < 2 ? null : _playPause,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              key: const Key('exportCoverNext'),
              tooltip: tr('1フレーム進む','Next frame'),
              onPressed: busy ? null : () { _stop(); _seek(frameIndex+1); },
              icon: const Icon(Icons.fast_forward),
            ),
            IconButton(
              key: const Key('exportCoverLast'),
              tooltip: tr('最後のフレーム','Last frame'),
              onPressed: busy ? null : () { _stop(); _seek(totalFrames-1); },
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
        if (isImage)
          Text(tr(
            '静止画像は1フレームとして扱います。',
            'Still images have one frame.',
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(tr('サムネイル変更', 'Change thumbnail')),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<String>(
            groupValue: mode,
            onChanged: (value) {
              if (busy) return;
              _stop();
              if (value != null) setState(() => mode = value);
            },
            child: Column(children: [
              RadioListTile<String>(
                key: const Key('exportCoverLatest'), value: 'latest',
                title: Text(tr('最後に保存したフレーム','Last saved frame')),
              ),
              RadioListTile<String>(
                key: const Key('exportCoverFrame'), value: 'frame',
                title: Text(tr('フレームを指定する','Select a frame')),
              ),
              RadioListTile<String>(
                key: const Key('exportCoverCustom'), value: 'custom',
                title: Text(tr('端末から画像を読み込む','Choose image from device')),
              ),
              RadioListTile<String>(
                key: const Key('exportCoverNone'), value: 'none',
                title: Text(tr('サムネイル表示しない','Do not show thumbnail')),
              ),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            child: mode == 'frame'
                ? _framePanel()
                : mode == 'custom'
                    ? Column(
                        key: const Key('exportCoverCustomPanel'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy ? null : _chooseCustom,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(tr('画像を読み込む','Choose image')),
                          ),
                          if (customName != null) Text(customName!),
                          if (customBytes != null) Image.memory(
                            customBytes!, height: 110, fit: BoxFit.contain,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
          ),
          if (!ready) const LinearProgressIndicator(),
          if (failure != null)
            Text(failure!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () { _stop(); Navigator.pop(context); },
        child: Text(tr('キャンセル','Cancel')),
      ),
      FilledButton(
        key: const Key('exportCoverApply'),
        onPressed: !ready || busy ||
          (mode == 'frame' && !supportedFrames && !isImage) ||
          (mode == 'custom' && customBytes == null && existingCover == null)
            ? null : _apply,
        child: Text(tr('適用','Apply')),
      ),
    ],
  );
}
