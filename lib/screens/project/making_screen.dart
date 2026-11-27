import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/signal_colors.dart';
import '../../engine/export_engine.dart';
import '../../engine/making_export.dart';
import '../../engine/making_player.dart';
import '../../l10n/app_localizations.dart';
import '../../models/layer.dart';
import '../../models/project.dart';
import '../../services/export_storage.dart';
import '../../services/making_service.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../utils/app_error_reporter.dart';
import '../../utils/clock_duration_label.dart';
import '../../utils/file_size_label.dart';
import '../../utils/making_strings.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/icon_notice.dart';
import '../../widgets/menu_surface.dart';

class MakingScreen extends StatefulWidget {
  const MakingScreen({
    super.key,
    required this.projectId,
    this.playOnOpen = false,
  });

  final String projectId;

  /// Opened with 「メイキング再生」: play the recording as soon as it is read.
  final bool playOnOpen;

  @override
  State<MakingScreen> createState() => _MakingScreenState();
}

class _MakingScreenState extends State<MakingScreen> {
  MakingPlayer? _player;
  bool _loading = true;

  /// The picture of the recorded step shown last, made by the player.
  ui.Image? _picture;
  bool _rendering = false;

  /// How far the export has got (0〜1), while it makes the pictures.
  double? _exportProgress;

  /// 記録を読めなかった。読めていない間は「記録はありません」と言わず、
  /// 知らせと「再試行」を出す。
  bool _loadFailed = false;
  bool _playing = false;
  bool _exporting = false;
  int _index = 0;
  MakingExportFormat _format = MakingExportFormat.mp4;
  Timer? _playTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // The end mark follows the verified benefits, like the work's export.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final premium = context.read<PremiumService?>();
      if (premium != null) unawaited(premium.refreshBenefits());
    });
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _picture?.dispose();
    _player?.dispose();
    super.dispose();
  }

  int get _length => _player?.length ?? 0;

  Future<void> _load() async {
    try {
      final player = await MakingPlayer.open(widget.projectId);
      if (!mounted) {
        player.dispose();
        return;
      }
      _player?.dispose();
      setState(() {
        _player = player;
        _index = 0;
        _loading = false;
        _loadFailed = false;
      });
      await _show(0);
      if (widget.playOnOpen && !_playing) _togglePlayback();
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    _load();
  }

  /// Shows the picture at [index]: a picture record as it is, a recorded
  /// step once the player has made its picture.
  Future<void> _show(int index) async {
    final player = _player;
    if (player == null || index < 0 || index >= player.length) return;
    setState(() => _index = index);
    if (player.picturePath(index) != null) return;
    _rendering = true;
    try {
      final picture = await player.render(index);
      if (!mounted || !identical(player, _player)) {
        picture.dispose();
        return;
      }
      setState(() {
        _picture?.dispose();
        _picture = picture;
      });
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
    } finally {
      _rendering = false;
    }
  }

  void _togglePlayback() {
    if (_length < 2) return;
    if (_playing) {
      _playTimer?.cancel();
      setState(() => _playing = false);
      return;
    }
    if (_index >= _length - 1) unawaited(_show(0));
    setState(() => _playing = true);
    _playTimer = Timer.periodic(const Duration(milliseconds: 125), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // A step whose picture is still being made holds the playback.
      if (_rendering) return;
      if (_index >= _length - 1) {
        timer.cancel();
        setState(() => _playing = false);
      } else {
        unawaited(_show(_index + 1));
      }
    });
  }

  Future<void> _deleteHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(MakingStrings.deleteHistory(context)),
        content: Text(MakingStrings.deleteHistoryConfirm(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: warningFilledButtonStyle(dialogContext),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _playTimer?.cancel();
    try {
      await MakingService.deleteHistory(widget.projectId);
      if (!mounted) return;
      _player?.dispose();
      _picture?.dispose();
      setState(() {
        _player = MakingPlayer.empty();
        _picture = null;
        _index = 0;
        _playing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MakingStrings.historyDeleted(context))),
      );
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MakingStrings.deleteFailed(context))),
      );
    }
  }

  /// この書き出しにNIARIMの公式の印（MP4・WebM・AVIはエンドマーク、GIFは
  /// 隅のロゴ）を付けるか。作品の書き出しと同じ決まり（プレミアム会員・
  /// エンドマークの特典を使っている間は作品の設定と既定の設定に従い、それ
  /// 以外は付ける）。
  bool _officialMarkDue(
    PremiumService? premium,
    Project? project,
    SettingsService? settings,
  ) {
    if (premium == null) return true;
    return premium.shouldAppendOfficialEndCard(
      projectHidden: project?.hideEndCard,
      defaultHidden: settings?.endCardDefaultHiddenForPremium ?? true,
    );
  }

  /// 作品の自分のウォーターマークが描かれている所（キャンバスに対する0〜1の
  /// 割合）。メイキング動画の記録はキャンバス全体を写すので、GIFの隅の
  /// ロゴはここを避ける。
  List<ui.Rect> _watermarkAreas(ProjectService projects) {
    final keys = <String>{};
    for (final scene in projects.scenesOf(widget.projectId)) {
      for (final frame in scene.frames) {
        for (final layer in projects.layersOf(
          widget.projectId,
          scene.id,
          frame.index,
        )) {
          if (layer.type != LayerType.watermark) continue;
          keys.add(
            projects.tileKeyFor(
              widget.projectId,
              scene.id,
              frame.index,
              layer.id,
            ),
          );
        }
      }
    }
    if (keys.isEmpty) return const [];
    final tiles = projects.tileManagerOf(widget.projectId);
    final width = tiles.canvasWidth.toDouble();
    final height = tiles.canvasHeight.toDouble();
    return [
      for (final key in keys)
        if (tiles.contentBounds(key) case final bounds?)
          ui.Rect.fromLTRB(
            bounds.left / width,
            bounds.top / height,
            bounds.right / width,
            bounds.bottom / height,
          ),
    ];
  }

  Project? _project(ProjectService projects) =>
      projects.projects.where((p) => p.id == widget.projectId).firstOrNull;

  Future<void> _export() async {
    final player = _player;
    if (player == null || player.length < 2 || _exporting) return;
    // The output conditions are fixed before the first frame is encoded.
    final projects = context.read<ProjectService>();
    final officialMark = _officialMarkDue(
      context.read<PremiumService?>(),
      _project(projects),
      context.read<SettingsService?>(),
    );
    final format = _format;
    final projectName = _project(projects)?.name;
    final watermarkAreas = officialMark && format == MakingExportFormat.gif
        ? _watermarkAreas(projects)
        : const <ui.Rect>[];
    setState(() {
      _exporting = true;
      _exportProgress = 0;
      _playing = false;
    });
    _playTimer?.cancel();
    String? partialOutput;
    try {
      final exportDirectory = await ExportEngine.exportsDir();
      // The work's name, like the work's own exports (it was the project's
      // id, so a search by the work's name in the Works list missed it).
      final outputPath = ExportEngine.freshMakingOutputPath(
        exportDirectory,
        projectName,
        format.name,
      );
      partialOutput = outputPath;
      // The pictures of the recorded steps are made now (nothing was drawn
      // while recording); the steps already turned into video are used as
      // they are.
      await MakingExport.export(
        frames: player,
        format: format,
        outputPath: outputPath,
        officialMark: officialMark,
        watermarkAreas: watermarkAreas,
        onProgress: (done, total) {
          if (mounted) setState(() => _exportProgress = done / total);
        },
      );
      if (mounted) setState(() => _exportProgress = null);

      final outputFile = File(outputPath);
      if (!await outputFile.exists() || await outputFile.length() == 0) {
        throw StateError('The making export produced no output file.');
      }
      partialOutput = null;
      ExportStorage.invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MakingStrings.exportComplete(context))),
      );
    } catch (error, stackTrace) {
      AppErrorReporter.record(error, stackTrace);
      if (partialOutput != null) {
        try {
          final partial = File(partialOutput);
          if (await partial.exists()) await partial.delete();
          ExportStorage.invalidate();
        } catch (cleanupError) {
          debugPrint('Could not remove partial making export: $cleanupError');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MakingStrings.exportFailed(context))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportProgress = null;
        });
      }
    }
  }

  /// 書き出す動画の長さと、公式エンドマーク（GIFは隅のロゴ）が付くか
  /// （作品の書き出しの画面と同じ文）。
  String _outputSummary(AppLocalizations l10n, int count, bool officialMark) {
    final duration = clockDurationLabel(
      MaterialLocalizations.of(context),
      MakingExport.bodySeconds(count, _format),
    );
    if (!officialMark) return l10n.exportOutputWithoutEndCard(duration);
    return MakingExport.carriesOfficialEndCard(_format)
        ? l10n.exportOutputWithEndCard(duration)
        : l10n.exportOutputWithCornerLogo(duration);
  }

  String _formatName(AppLocalizations l10n, MakingExportFormat format) =>
      switch (format) {
        MakingExportFormat.mp4 => l10n.exportFormatMp4,
        MakingExportFormat.gif => l10n.exportFormatGif,
        MakingExportFormat.webm => MakingStrings.formatWebm(context),
        MakingExportFormat.avi => l10n.exportFormatAvi,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final project = _project(context.watch<ProjectService>());
    final premium = context.watch<PremiumService?>();
    final settings = context.watch<SettingsService?>();
    final player = _player;
    final length = _length;
    final index = length == 0 ? 0 : _index.clamp(0, length - 1).toInt();
    final picturePath = player?.picturePath(index);
    return Scaffold(
      appBar: AppBar(title: FitOrHideTitle(MakingStrings.makingTitle(context))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconNotice.caution(
                      MakingStrings.loadFailed(context),
                      liveRegion: true,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      key: const Key('makingRetryLoadButton'),
                      onPressed: _retryLoad,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.communityRetry),
                    ),
                  ],
                ),
              ),
            )
          : length == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 空の表示の印は補助の文字色・台や枠なし（ほかの一覧と同じ）。
                    const EmptyStateIcon(icon: Icons.movie_outlined),
                    const SizedBox(height: 16),
                    Text(
                      project?.makingEnabled == true
                          ? MakingStrings.makingEmptyRecordingOn(context)
                          : MakingStrings.makingEmpty(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (project != null)
                      SwitchListTile(
                        title: Text(MakingStrings.recordProject(context)),
                        value: project.makingEnabled,
                        onChanged: (value) => context
                            .read<ProjectService>()
                            .setMakingEnabled(project.id, value),
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
                    child: picturePath != null
                        ? Image.file(
                            File(picturePath),
                            key: ValueKey(picturePath),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white,
                                  size: 48,
                                ),
                          )
                        : _picture != null
                        // The last picture made stays until the next one is
                        // ready (no blink while a step is being made).
                        ? RawImage(
                            key: const Key('makingStepPicture'),
                            image: _picture,
                            fit: BoxFit.contain,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      Text(
                        MakingStrings.frameCounter(context, index + 1, length),
                      ),
                      Slider(
                        value: index.toDouble(),
                        min: 0,
                        max: (length - 1).toDouble(),
                        divisions: length > 1 ? length - 1 : null,
                        onChanged: _playing || length < 2
                            ? null
                            : (value) => unawaited(_show(value.round())),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _playing ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: _exporting || length < 2
                                ? null
                                : _togglePlayback,
                            tooltip: _playing
                                ? l10n.commonPause
                                : l10n.commonPlay,
                          ),
                          const Spacer(),
                          // 言語ごとの書き方（fr「1,4 Ko」等）で、数と単位を
                          // 改行しない空白でつなぐ。
                          Text(fileSizeLabel(l10n, player!.sizeBytes)),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _outputSummary(
                              l10n,
                              length,
                              _officialMarkDue(premium, project, settings),
                            ),
                            key: const Key('makingExportOutputSummary'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                      if (_exportProgress != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(
                            key: const Key('makingExportProgress'),
                            value: _exportProgress,
                          ),
                        ),
                      if (player.limitReached)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          // その場の知らせはエラーの赤にせず、面の文字色と印で。
                          child: IconNotice.caution(
                            MakingStrings.storageLimit(context),
                            liveRegion: true,
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            // 塗った欄の下地はメニューの背景色なので、選んだ値も
                            // メニューの文字色で描く。
                            child: MenuSurface(
                              child:
                                  DropdownButtonFormField<MakingExportFormat>(
                                    initialValue: _format,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: l10n.exportFormatSection,
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      for (final format
                                          in MakingExportFormat.values)
                                        DropdownMenuItem(
                                          value: format,
                                          child: Text(
                                            _formatName(l10n, format),
                                          ),
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
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _exporting || length < 2
                                ? null
                                : _export,
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('makingDeleteHistoryButton'),
                    onPressed: _exporting ? null : _deleteHistory,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(MakingStrings.deleteHistory(context)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}
