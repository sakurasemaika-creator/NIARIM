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

import '../../../l10n/app_localizations.dart';

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

  // Generate missing covers in a serial queue so large libraries do not
  // start multiple FFmpeg decoders at the same time.
  static final Map<String, Future<Map<String, dynamic>>> _pending = {};
  static Future<void> _serialGeneration = Future<void>.value();
  static final Set<String> _failedInSession = {};

  static bool _isRaster(File file) => const {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
    'gif',
  }.contains(file.path.split('.').last.toLowerCase());

  static bool _isVideo(File file) => const {
    'mp4',
    'm4v',
    'mov',
    'webm',
    'mkv',
    'avi',
    '3gp',
  }.contains(file.path.split('.').last.toLowerCase());

  static Future<File> _newCacheFile(String prefix, String extension) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/exported_covers');
    await dir.create(recursive: true);
    return File(
      '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
  }

  static Future<String> storeCompressedImage(
    Uint8List sourceBytes, {
    bool preferJpeg = false,
  }) async {
    final source = image_codec.decodeImage(sourceBytes);
    if (source == null || source.width <= 0 || source.height <= 0) {
      throw const FormatException('Unsupported thumbnail image');
    }
    const maxEdge = 420;
    final largest = math.max(source.width, source.height);
    final scale = largest > maxEdge ? maxEdge / largest : 1.0;
    final result = scale < 1
        ? image_codec.copyResize(
            source,
            width: math.max(1, (source.width * scale).round()),
            height: math.max(1, (source.height * scale).round()),
            interpolation: image_codec.Interpolation.average,
          )
        : source;
    // JPEG exports stay JPEG; preserving their lossy compression avoids
    // converting a small photo into a much larger lossless PNG.
    final optimized = preferJpeg
        ? image_codec.encodeJpg(result, quality: 82)
        : image_codec.encodePng(result, level: 6);
    final output = await _newCacheFile('custom', preferJpeg ? 'jpg' : 'png');
    await output.writeAsBytes(optimized, flush: true);
    return output.path;
  }

  static String _quote(String path) =>
      '"' + path.replaceAll('\\', '\\\\').replaceAll('"', '\\"') + '"';

  static Future<String> extractVideoFrame(File file, int frame) async {
    // Opaque video frames: compact JPEG. WebM/GIF: PNG retains possible alpha.
    final suffix = file.path.split('.').last.toLowerCase();
    final preserveAlpha = suffix == 'webm' || suffix == 'gif';
    final output = await _newCacheFile('export', preserveAlpha ? 'png' : 'jpg');
    final filter =
        'select=eq(n\\,$frame),'
        'scale=420:420:force_original_aspect_ratio=decrease:flags=lanczos';
    final quality = preserveAlpha ? '-compression_level 9' : '-q:v 4';
    final session = await FFmpegKit.execute(
      '-hide_banner -loglevel error -y -i ${_quote(file.path)} '
      '-vf "$filter" -vsync 0 -frames:v 1 $quality ${_quote(output.path)}',
    );
    final exitCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(exitCode) ||
        !await output.exists() ||
        await output.length() == 0) {
      if (await output.exists()) await output.delete();
      throw const FileSystemException('Thumbnail extraction failed');
    }
    return output.path;
  }

  static Future<int> _lastVideoFrame(File file) async {
    final session = await FFprobeKit.getMediaInformation(file.path);
    final info = session.getMediaInformation();
    if (info == null) return 0;
    var rate = 0.0;
    for (final stream in info.getStreams()) {
      if (stream.getType() != 'video') continue;
      final parts =
          (stream.getAverageFrameRate() ?? stream.getRealFrameRate() ?? '0')
              .split('/');
      final numerator = double.tryParse(parts[0]) ?? 0;
      final denominator = parts.length > 1 ? double.tryParse(parts[1]) ?? 0 : 1;
      rate = denominator == 0 ? 0 : numerator / denominator;
      final reported = int.tryParse(
        stream.getStringProperty('nb_frames') ?? '',
      );
      if (reported != null && reported > 0) return reported - 1;
      break;
    }
    final duration = double.tryParse(info.getDuration() ?? '') ?? 0;
    if (duration <= 0 || rate <= 0 || !rate.isFinite) return 0;
    return math.max(0, (duration * rate).round() - 1);
  }

  static Future<Map<String, dynamic>> ensureCached(File file) {
    final existing = _pending[file.path];
    if (existing != null) return existing;
    final completer = Completer<Map<String, dynamic>>();
    final task = completer.future;
    _pending[file.path] = task;
    _serialGeneration = _serialGeneration
        .then((_) async {
          try {
            completer.complete(await _ensureCachedNow(file));
          } catch (_) {
            _failedInSession.add(file.path);
            try {
              completer.complete(await read(file));
            } catch (_) {
              completer.complete(const {'mode': 'latest'});
            }
          } finally {
            _pending.remove(file.path);
          }
        })
        .catchError((_) {});
    return task;
  }

  static Future<Map<String, dynamic>> _ensureCachedNow(File file) async {
    final current = await read(file);
    if (current['mode'] == 'none' ||
        current['mode'] == 'custom' ||
        _failedInSession.contains(file.path))
      return current;
    final previous = current['imagePath'];
    if (previous is String &&
        previous.isNotEmpty &&
        await File(previous).exists())
      return current;
    if (!_isRaster(file) && !_isVideo(file)) return current;
    final original = await file.stat();
    String? generated;
    try {
      var frame = 0;
      if (_isVideo(file)) {
        frame = current['mode'] == 'frame' && current['frameIndex'] is int
            ? math.max(0, current['frameIndex'] as int)
            : await _lastVideoFrame(file);
        generated = await extractVideoFrame(file, frame);
      } else {
        generated = await storeCompressedImage(
          await file.readAsBytes(),
          preferJpeg: const {
            'jpg',
            'jpeg',
          }.contains(file.path.split('.').last.toLowerCase()),
        );
      }
      final after = await file.stat();
      if (after.size != original.size || after.modified != original.modified) {
        if (await File(generated).exists()) {
          await File(generated).delete();
        }
        return await read(file);
      }
      await write(
        file,
        mode: current['mode'] == 'frame' ? 'frame' : 'latest',
        imagePath: generated,
        frameIndex: _isVideo(file) ? frame : 0,
      );
      return await read(file);
    } catch (_) {
      if (generated != null && await File(generated).exists()) {
        await File(generated).delete();
      }
      rethrow;
    }
  }

  static Future<void> write(
    File file, {
    required String mode,
    String? imagePath,
    int? frameIndex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _decode(prefs.getString(prefsKey));
    final previous = current[file.path];
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
    // Only managed cached images are removed, and only after persistence.
    final oldPath = previous is Map ? previous['imagePath'] : null;
    if (oldPath is String &&
        oldPath != imagePath &&
        !current.values.any(
          (entry) => entry is Map && entry['imagePath'] == oldPath,
        )) {
      try {
        final support = await getApplicationSupportDirectory();
        final cache = Directory('${support.path}/exported_covers');
        final candidate = File(oldPath);
        final name = candidate.uri.pathSegments.last;
        if (candidate.parent.path == cache.path &&
            (name.startsWith('export_') || name.startsWith('custom_')) &&
            await candidate.exists()) {
          await candidate.delete();
        }
      } on FileSystemException {
        // Missing cache is harmless after the new metadata is committed.
      }
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
    if (const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}.contains(suffix))
      return file.path;
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
    builder: (_) =>
        _ExportedWorkThumbnailDialog(file: file, onApplied: onApplied),
  );
}

class _ExportedWorkThumbnailDialog extends StatefulWidget {
  const _ExportedWorkThumbnailDialog({required this.file, this.onApplied});
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

  bool get isImage => const {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'bmp',
    'webp',
  }.contains(widget.file.path.split('.').last.toLowerCase());

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
      if (choice is String &&
          const {'latest', 'frame', 'custom', 'none'}.contains(choice))
        mode = choice;
      existingCover = setting['imagePath'] is String
          ? setting['imagePath'] as String
          : null;
      if (!isImage) {
        // Probe the media rather than assuming all exports are 30fps.
        final session = await FFprobeKit.getMediaInformation(widget.file.path);
        final info = session.getMediaInformation();
        if (info != null) {
          final streams = info.getStreams();
          for (final stream in streams) {
            if (stream.getType() != 'video') continue;
            final rate = _rate(
              stream.getAverageFrameRate() ?? stream.getRealFrameRate() ?? '0',
            );
            if (rate > 0 && rate.isFinite) fps = rate;
            final number = int.tryParse(
              stream.getStringProperty('nb_frames') ?? '',
            );
            if (number != null && number > 0) totalFrames = number;
            break;
          }
          final duration = double.tryParse(info.getDuration() ?? '');
          if (totalFrames <= 1 && duration != null && duration > 0 && fps > 0) {
            totalFrames = math.max(1, (duration * fps).round());
          }
        }
      }
      supportedFrames = totalFrames > 1;
      frameIndex =
          (setting['frameIndex'] is int ? setting['frameIndex'] as int : 0)
              .clamp(0, totalFrames - 1);
      if (!isImage) {
        final player = VideoPlayerController.file(widget.file);
        controller = player;
        await player.initialize();
        if (mode == 'frame') await _seek(frameIndex);
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted)
        setState(() {
          ready = true;
          supportedFrames = false;
          failure = l10n.thumbnailVideoInfoFailed;
        });
    }
  }

  Future<void> _seek(int target) async {
    final next = target.clamp(0, totalFrames - 1);
    setState(() => frameIndex = next);
    final player = controller;
    if (player == null || !player.value.isInitialized) return;
    await player.seekTo(Duration(microseconds: (next / fps * 1000000).round()));
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
            .round()
            .clamp(0, totalFrames - 1);
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
        type: FileType.image,
        withData: true,
      );
      if (selected == null || selected.files.isEmpty) return;
      final file = selected.files.first;
      final bytes =
          file.bytes ??
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
      if (mounted) setState(() => failure = l10n.thumbnailImageLoadFailed);
    }
  }

  Future<String> _extract(int frame) =>
      ExportedWorkCoverStore.extractVideoFrame(widget.file, frame);

  Future<void> _apply() async {
    _stop();
    setState(() => busy = true);
    String? generated;
    var committed = false;
    try {
      String? imagePath;
      if (mode == 'custom') {
        if (customBytes == null) {
          imagePath = existingCover;
        } else {
          generated = await ExportedWorkCoverStore.storeCompressedImage(
            customBytes!,
          );
          imagePath = generated;
        }
      } else if (!isImage && (mode == 'frame' || mode == 'latest')) {
        generated = await _extract(
          mode == 'latest' ? totalFrames - 1 : frameIndex,
        );
        imagePath = generated;
      } else if (isImage && mode != 'none') {
        generated = await ExportedWorkCoverStore.storeCompressedImage(
          await widget.file.readAsBytes(),
          preferJpeg: const {
            'jpg',
            'jpeg',
          }.contains(widget.file.path.split('.').last.toLowerCase()),
        );
        imagePath = generated;
      }
      await ExportedWorkCoverStore.write(
        widget.file,
        mode: mode,
        imagePath: imagePath,
        frameIndex: mode == 'frame'
            ? frameIndex
            : mode == 'latest'
            ? (isImage ? 0 : totalFrames - 1)
            : null,
      );
      committed = true;
      widget.onApplied?.call();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!committed && generated != null) {
        try {
          final file = File(generated);
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // The previous cover is still referenced by persisted settings.
        }
      }
      if (mounted)
        setState(() {
          busy = false;
          failure = l10n.thumbnailSaveFailed;
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
          aspectRatio:
              player?.value.isInitialized == true &&
                  player!.value.aspectRatio > 0
              ? player.value.aspectRatio
              : 16 / 9,
          child: Container(
            key: const Key('exportCoverPreview'),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: player != null && player.value.isInitialized
                ? VideoPlayer(player)
                : Image.file(
                    widget.file,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
                  ),
          ),
        ),
        Text(
          l10n.thumbnailCurrentFrame(frameIndex + 1, totalFrames),
          key: const Key('exportCoverFrameCount'),
          textAlign: TextAlign.center,
        ),
        Slider(
          key: const Key('exportCoverSeek'),
          value: frameIndex.toDouble(),
          min: 0,
          max: math.max(1, totalFrames - 1).toDouble(),
          onChanged: busy || totalFrames < 2
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
              key: const Key('exportCoverFirst'),
              tooltip: l10n.projectDetailFirstFrameTooltip,
              onPressed: busy
                  ? null
                  : () {
                      _stop();
                      _seek(0);
                    },
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              key: const Key('exportCoverPrevious'),
              tooltip: l10n.projectDetailPrevFrameTooltip,
              onPressed: busy
                  ? null
                  : () {
                      _stop();
                      _seek(frameIndex - 1);
                    },
              icon: const Icon(Icons.fast_rewind),
            ),
            IconButton(
              key: const Key('exportCoverPlayback'),
              tooltip: (playing ? l10n.commonPause : l10n.commonPlay),
              onPressed: player == null || totalFrames < 2 ? null : _playPause,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              key: const Key('exportCoverNext'),
              tooltip: l10n.projectDetailNextFrameTooltip,
              onPressed: busy
                  ? null
                  : () {
                      _stop();
                      _seek(frameIndex + 1);
                    },
              icon: const Icon(Icons.fast_forward),
            ),
            IconButton(
              key: const Key('exportCoverLast'),
              tooltip: l10n.projectDetailLastFrameTooltip,
              onPressed: busy
                  ? null
                  : () {
                      _stop();
                      _seek(totalFrames - 1);
                    },
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
        if (isImage) Text(l10n.thumbnailStillImageOneFrame),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
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
              if (busy) return;
              _stop();
              if (value != null) setState(() => mode = value);
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  key: const Key('exportCoverLatest'),
                  value: 'latest',
                  title: Text(l10n.thumbnailLastSavedFrame),
                ),
                RadioListTile<String>(
                  key: const Key('exportCoverFrame'),
                  value: 'frame',
                  title: Text(l10n.thumbnailSelectFrame),
                ),
                RadioListTile<String>(
                  key: const Key('exportCoverCustom'),
                  value: 'custom',
                  title: Text(l10n.thumbnailChooseDeviceImage),
                ),
                RadioListTile<String>(
                  key: const Key('exportCoverNone'),
                  value: 'none',
                  title: Text(l10n.thumbnailHide),
                ),
              ],
            ),
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
                        label: Text(l10n.thumbnailPickImage),
                      ),
                      if (customName != null) Text(customName!),
                      if (customBytes != null)
                        Image.memory(
                          customBytes!,
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          if (!ready) const LinearProgressIndicator(),
          if (failure != null)
            Text(
              failure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy
            ? null
            : () {
                _stop();
                Navigator.pop(context);
              },
        child: Text(l10n.commonCancel),
      ),
      FilledButton(
        key: const Key('exportCoverApply'),
        onPressed:
            !ready ||
                busy ||
                (mode == 'frame' && !supportedFrames && !isImage) ||
                (mode == 'custom' &&
                    customBytes == null &&
                    existingCover == null)
            ? null
            : _apply,
        child: Text(l10n.commonApply),
      ),
    ],
  );
}
