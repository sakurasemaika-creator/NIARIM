import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../../engine/export_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export_storage.dart';
import '../../services/hw_video_encoder.dart';
import '../../services/making_service.dart';
import '../../services/project_service.dart';
import '../../utils/making_strings.dart';

enum _MakingFormat { mp4, gif, webm, avi }

class MakingScreen extends StatefulWidget {
  const MakingScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<MakingScreen> createState() => _MakingScreenState();
}

class _MakingScreenState extends State<MakingScreen> {
  MakingHistory? _history;
  bool _loading = true;
  bool _playing = false;
  bool _exporting = false;
  int _index = 0;
  _MakingFormat _format = _MakingFormat.mp4;
  Timer? _playTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final history = await MakingService.history(widget.projectId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _index = 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _togglePlayback() {
    final snapshots = _history?.snapshots ?? const <MakingSnapshot>[];
    if (snapshots.length < 2) return;
    if (_playing) {
      _playTimer?.cancel();
      setState(() => _playing = false);
      return;
    }
    if (_index >= snapshots.length - 1) setState(() => _index = 0);
    setState(() => _playing = true);
    _playTimer = Timer.periodic(const Duration(milliseconds: 125), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_index >= snapshots.length - 1) {
        timer.cancel();
        setState(() => _playing = false);
      } else {
        setState(() => _index++);
      }
    });
  }

  String _extension(_MakingFormat format) => switch (format) {
    _MakingFormat.mp4 => 'mp4',
    _MakingFormat.gif => 'gif',
    _MakingFormat.webm => 'webm',
    _MakingFormat.avi => 'avi',
  };

  Future<void> _export() async {
    final snapshots = _history?.snapshots ?? const <MakingSnapshot>[];
    if (snapshots.length < 2 || _exporting) return;
    setState(() {
      _exporting = true;
      _playing = false;
    });
    _playTimer?.cancel();
    Directory? staging;
    try {
      final firstBytes = await File(snapshots.first.path).readAsBytes();
      final firstImage = img.decodeImage(firstBytes);
      if (firstImage == null) {
        throw StateError('Making snapshot image is unreadable.');
      }
      final width = firstImage.width;
      final height = firstImage.height;
      const fps = 8;
      final exportDirectory = await ExportEngine.exportsDir();
      final outputPath = exportDirectory.path +
          '/Making_' + widget.projectId + '_' +
          DateTime.now().millisecondsSinceEpoch.toString() + '.' +
          _extension(_format);

      switch (_format) {
        case _MakingFormat.mp4:
          await HardwareVideoEncoder.encodeMp4(
            framePaths: snapshots.map((snapshot) => snapshot.path).toList(),
            fps: fps,
            width: width,
            height: height,
            outputPath: outputPath,
          );
        case _MakingFormat.gif:
          final encoder = newExportGifEncoder();
          for (final snapshot in snapshots) {
            final bytes = await File(snapshot.path).readAsBytes();
            final image = img.decodeImage(bytes);
            if (image == null) continue;
            encoder.addFrame(image, duration: 100 ~/ fps);
          }
          final gif = encoder.finish();
          if (gif == null || gif.isEmpty) {
            throw StateError('GIF encoder returned no data.');
          }
          await File(outputPath).writeAsBytes(gif, flush: true);
        case _MakingFormat.webm:
        case _MakingFormat.avi:
          final temp = await getTemporaryDirectory();
          staging = Directory(
            temp.path + '/niarim_making_export_' +
                DateTime.now().microsecondsSinceEpoch.toString(),
          );
          await staging.create(recursive: true);
          for (var i = 0; i < snapshots.length; i++) {
            final target = File(
              staging.path + '/frame_' +
                  i.toString().padLeft(6, '0') + '.jpg',
            );
            await File(snapshots[i].path).copy(target.path);
          }
          final args = <String>[
            '-y',
            '-framerate',
            fps.toString(),
            '-i',
            staging.path + '/frame_%06d.jpg',
          ];
          if (_format == _MakingFormat.webm) {
            args.addAll([
              '-c:v', 'libvpx-vp9',
              '-pix_fmt', 'yuv420p',
              '-b:v', '2M',
            ]);
          } else {
            args.addAll([
              '-c:v', 'mjpeg',
              '-q:v', '3',
              '-pix_fmt', 'yuvj420p',
            ]);
          }
          args.add(outputPath);
          final session = await FFmpegKit.executeWithArguments(args);
          if (!ReturnCode.isSuccess(await session.getReturnCode())) {
            throw StateError('Video encoder failed: ' + (await session.getOutput() ?? ''));
          }
      }

      ExportStorage.invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MakingStrings.exportComplete(context))),
      );
    } catch (error, stackTrace) {
      debugPrint('Making export failed: ' + error.toString() + '\n' + stackTrace.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MakingStrings.exportFailed(context))),
      );
    } finally {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _formatName(AppLocalizations l10n, _MakingFormat format) =>
      switch (format) {
        _MakingFormat.mp4 => l10n.exportFormatMp4,
        _MakingFormat.gif => l10n.exportFormatGif,
        _MakingFormat.webm => l10n.exportFormatWebm,
        _MakingFormat.avi => l10n.exportFormatAvi,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final project = context.watch<ProjectService>().projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final snapshots = _history?.snapshots ?? const <MakingSnapshot>[];
    return Scaffold(
      appBar: AppBar(title: Text(MakingStrings.makingTitle(context))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : snapshots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.movie_outlined, size: 44),
                        const SizedBox(height: 16),
                        Text(
                          MakingStrings.makingEmpty(context),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (project != null)
                          SwitchListTile(
                            title: Text(MakingStrings.recordProject(context)),
                            value: project.makingEnabled,
                            onChanged: (value) =>
                                context.read<ProjectService>().setMakingEnabled(
                                  project.id,
                                  value,
                                ),
                          ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: Image.file(
                          File(snapshots[_index.clamp(0, snapshots.length - 1)].path),
                          key: ValueKey(
                            snapshots[_index.clamp(0, snapshots.length - 1)].path,
                          ),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white,
                                size: 48,
                              ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        children: [
                          Text(
                            MakingStrings.frameCounter(
                              context,
                              _index + 1,
                              snapshots.length,
                            ),
                          ),
                          Slider(
                            value: _index.toDouble(),
                            min: 0,
                            max: (snapshots.length - 1).toDouble(),
                            divisions: snapshots.length - 1,
                            onChanged: _playing
                                ? null
                                : (value) => setState(
                                    () => _index = value.round(),
                                  ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _playing ? Icons.pause : Icons.play_arrow,
                                ),
                                onPressed: _exporting ? null : _togglePlayback,
                                tooltip: _playing
                                    ? l10n.commonPause
                                    : l10n.commonPlay,
                              ),
                              const Spacer(),
                              Text(
                                _history!.sizeBytes < 1024 * 1024
                                    ? (_history!.sizeBytes / 1024).round().toString() + ' KB'
                                    : (_history!.sizeBytes / (1024 * 1024))
                                        .toStringAsFixed(1) + ' MB',
                              ),
                            ],
                          ),
                          if (_history?.limitReached == true)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                MakingStrings.storageLimit(context),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<_MakingFormat>(
                                  value: _format,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: l10n.exportFormatSection,
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    for (final format in _MakingFormat.values)
                                      DropdownMenuItem(
                                        value: format,
                                        child: Text(_formatName(l10n, format)),
                                      ),
                                  ],
                                  onChanged: _exporting
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(() => _format = value);
                                          }
                                        },
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _exporting ? null : _export,
                                icon: _exporting
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.file_download_outlined),
                                label: Text(MakingStrings.exportLabel(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}
