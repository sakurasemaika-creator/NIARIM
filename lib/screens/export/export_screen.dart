import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../widgets/premium_lock_widget.dart';
import '../../engine/export_audio.dart';
import '../../engine/export_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../services/material_service.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import 'widgets/export_complete_dialog.dart';
import '../../widgets/labeled_slider.dart';
import '../../widgets/progress_dialog.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/accent_text_theme.dart';
import '../../config/font_fallback.dart';
import '../home/widgets/exported_work_thumbnail_dialog.dart';
import 'widgets/export_preset_selector.dart';
import '../../models/export_preset.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/grouped_sheet.dart';
import '../../utils/file_failure_reason.dart';
import '../../widgets/icon_notice.dart';
export '../../models/export_preset.dart';

class ExportScreen extends StatefulWidget {
  final String projectId;
  const ExportScreen({super.key, required this.projectId});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  ExportFormat _format = ExportFormat.mp4;
  ExportPreset _preset = ExportPreset.standard;
  bool _isExporting = false;
  bool _startingExport = false;
  double _progress = 0;
  String? _error;
  final _errorKey = GlobalKey();
  DialogRoute<void>? _progressRoute;
  VoidCallback? _refreshProgressDialog;
  // 誤タップ対応のキャンセルボタン。フレーム生成中のみ
  // 実際に中断できる（最終エンコード処理自体は安全に中断する手段がない
  // ため、その段階でのキャンセルは処理完了後に出力ファイルを破棄する形で
  // 反映される）。
  ExportCancelToken? _cancelToken;
  // 「カスタム」選択時のみ編集可能なFPS（「カスタム」タップで
  // アコーディオン展開して詳細設定を表示する）
  int _customFps = 30;
  static const int _minCustomFps = 12;
  static const int _maxCustomFps = 60;

  int get _fps => switch (_preset) {
    ExportPreset.standard => 30,
    ExportPreset.highQuality => 60,
    ExportPreset.custom => _customFps,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<PremiumService>().refreshBenefits());
    });
  }

  bool _appendEndCard(
    PremiumService premium,
    bool? projectHidden,
    bool defaultHidden,
  ) =>
      _format != ExportFormat.gif &&
      premium.shouldAppendOfficialEndCard(
        projectHidden: projectHidden,
        defaultHidden: defaultHidden,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final premium = context.watch<PremiumService>();
    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(l10n.exportScreenTitle),
        actions: const [HelpButton(topic: '動画書き出し（MP4）')],
      ),
      body: _buildSettings(l10n, premium),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            heightFactor: 1,
            child: SizedBox(
              width: 720,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  onPressed:
                      _isExporting ||
                          _startingExport ||
                          premium.isCheckingBenefits
                      ? null
                      : _startExport,
                  icon: const Icon(Icons.file_download),
                  label: Text(
                    premium.benefitsVerificationUnavailable
                        ? l10n.exportCurrentConditions
                        : l10n.exportStartButton,
                    textAlign: TextAlign.center,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettings(AppLocalizations l10n, PremiumService premium) {
    final projects = context.watch<ProjectService>();
    final settings = context.watch<SettingsService?>();
    final project = projects.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final scenes = projects.scenesOf(widget.projectId);
    final sourceFps = project?.fps ?? _fps;
    final needsLongExport =
        ExportTiming.sourceFrames(scenes) > 90 * sourceFps &&
        !premium.isFeatureAvailable(PremiumFeature.unlimitedDuration);
    final timing = ExportTiming(
      sourceFps: sourceFps,
      outputFps: _fps,
      maxSeconds: needsLongExport ? 90 : null,
    );
    final wholeSeconds = timing.outputFrames(scenes) ~/ _fps;
    final time = MaterialLocalizations.of(context);
    final duration = [
      if (wholeSeconds >= 3600) time.formatDecimal(wholeSeconds ~/ 3600),
      time.formatDecimal(wholeSeconds ~/ 60 % 60).padLeft(2, '0'),
      time.formatDecimal(wholeSeconds % 60).padLeft(2, '0'),
    ].join(':');
    final appendEndCard = _appendEndCard(
      premium,
      project?.hideEndCard,
      settings?.endCardDefaultHiddenForPremium ?? true,
    );
    final verificationUnavailable = premium.benefitsVerificationUnavailable;
    final locale = Localizations.localeOf(context);
    final colors = Theme.of(context).colorScheme;
    final formats = [
      (ExportFormat.mp4, l10n.exportFormatMp4, l10n.exportFormatMp4Subtitle),
      (ExportFormat.gif, l10n.exportFormatGif, l10n.exportFormatGifSubtitle),
      (
        ExportFormat.webm,
        l10n.helpTransparentWebmTitle,
        l10n.exportFormatWebmSubtitle,
      ),
      (ExportFormat.avi, l10n.exportFormatAvi, l10n.exportFormatAviSubtitle),
    ];
    // 見出しは中身（選ぶもの）より控えめな小さい見出しにし、下の面の文字の
    // 始まりにそろえる（以前は15pxの太字で、選ぶものより目立っていた）。
    // 位置と書式は下の面（GroupedSheet）のまとまりの名前と同じ。
    Widget sectionLabel(String text) => Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: GroupedSheet.rowInset,
          bottom: 8,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: colors.onSurfaceVariant,
            fontFamily: headingFontFamilyFor(locale),
            fontFamilyFallback: headingFontFallbackFor(locale),
          ),
        ),
      ),
    );
    final presetSection = <Widget>[
      sectionLabel(l10n.exportPresetSection),
      ExportPresetSelector(
        value: _preset,
        onChanged: (value) => setState(() => _preset = value),
      ),
      // 「カスタム」選択時のみ詳細設定を展開表示する（初心者はプリセットを
      // 選ぶだけで書き出しが完了する。詳細設定は「カスタム」タップ時のみ表示）。
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: _preset != ExportPreset.custom
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: GroupedSheet(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.exportAdvancedSettings,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: headingFontFamilyFor(locale),
                              fontFamilyFallback: headingFontFallbackFor(
                                locale,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          LabeledSlider(
                            label: l10n.exportFpsLabel,
                            value: _customFps.toDouble(),
                            min: _minCustomFps.toDouble(),
                            max: _maxCustomFps.toDouble(),
                            divisions: _maxCustomFps - _minCustomFps,
                            sliderLabel: '$_customFps',
                            valueText: '$_customFps',
                            onChanged: (v) =>
                                setState(() => _customFps = v.round()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    ];
    // 形式は1枚の面に並べ、行の間は細い線で分ける（以前は1つずつ枠の付いた
    // カードを7pxずつ空けて積み、選んだ形式は灰色の塗り＋差し色の枠で、
    // 画面の主役の「書き出し開始」と同じ強さで目立っていた）。選んだ形式は
    // 丸の印と、題の差し色で示す。
    final accentText = AccentTextTheme.of(context);
    final formatSection = <Widget>[
      RadioGroup<ExportFormat>(
        groupValue: _format,
        onChanged: (v) => setState(() => _format = v!),
        child: GroupedSheet(
          title: l10n.exportFormatSection,
          children: [
            for (final (format, title, description) in formats)
              RadioListTile<ExportFormat>(
                value: format,
                selected: _format == format,
                // 選んだ行も面の色のまま（塗りで選んだと示さない）。
                selectedTileColor: Colors.transparent,
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 8,
                  end: 16,
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    color: _format == format ? accentText : colors.onSurface,
                    fontFamily: headingFontFamilyFor(locale),
                    fontFamilyFallback: headingFontFallbackFor(locale),
                  ),
                ),
                subtitle: Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                    fontFamily: bodyFontFamilyFor(locale),
                    fontFamilyFallback: bodyFontFallbackFor(locale),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
    final outputDetails = <Widget>[
      DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          height: 1.45,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 3,
          children: [
            if (project != null)
              Text(
                '${project.exportWidth} × ${project.exportHeight} px · ${l10n.pcStatusFps(_fps)}',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              appendEndCard
                  ? l10n.exportOutputWithEndCard(duration)
                  : l10n.exportOutputWithoutEndCard(duration),
            ),
            Text(l10n.exportKeepsPlaybackTime),
            // The output frame rate is not applied silently: the preview
            // plays at the work's own rate, or at this one when asked.
            if (project != null && project.fps != _fps) ...[
              Text(
                l10n.exportFpsDiffersNote(project.fps, _fps),
                key: const ValueKey('exportFpsDiffersNote'),
              ),
              if (project.fps >= _minCustomFps && project.fps <= _maxCustomFps)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const ValueKey('exportUseWorkFps'),
                    onPressed: _isExporting
                        ? null
                        : () => setState(() {
                            _preset = ExportPreset.custom;
                            _customFps = project.fps;
                          }),
                    child: Text(l10n.exportUseWorkFps(project.fps)),
                  ),
                ),
              // Or see the export's frames at its rate: back on the
              // timeline, whose preview then plays at this rate.
              if (GoRouter.of(context).canPop())
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const ValueKey('exportPreviewAtFps'),
                    onPressed: _isExporting
                        ? null
                        : () => context.pop<int>(_fps),
                    child: Text(l10n.exportPreviewAtFps(_fps)),
                  ),
                ),
            ],
          ],
        ),
      ),
      if (needsLongExport) ...[
        Text(l10n.exportLongProjectNote),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => context.push(
              '/help?topic=${Uri.encodeComponent('特典の期限が切れたら')}',
            ),
            child: Text(l10n.helpPremiumExpiryTitle),
          ),
        ),
      ],
      if (premium.isCheckingBenefits)
        Text(l10n.exportBenefitsChecking)
      else if (verificationUnavailable) ...[
        Text(l10n.exportBenefitsUnavailable),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _isExporting ? null : premium.refreshBenefits,
            child: Text(l10n.exportRetryBenefits),
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (_error != null)
        Semantics(
          key: _errorKey,
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IconNotice(_error!),
          ),
        ),
    ];
    return desktopCentered(
      context,
      LayoutBuilder(
        builder: (context, constraints) {
          const padding = EdgeInsets.fromLTRB(16, 16, 16, 20);
          const columnGap = 20.0;
          final columnWidth =
              (constraints.maxWidth - padding.horizontal - columnGap) / 2;
          // When the preset column gets too narrow for a scaled label, keep
          // both controls in the full-width layout.
          final minColumnWidth =
              MediaQuery.textScalerOf(context).scale(14) * 8 + 24;
          final sideBySide =
              constraints.maxWidth >= 560 &&
              columnWidth >= minColumnWidth &&
              constraints.maxHeight < 380;
          return SingleChildScrollView(
            padding: padding,
            child: sideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: columnGap,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...presetSection,
                            const SizedBox(height: 20),
                            ...outputDetails,
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: formatSection,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...presetSection,
                      const SizedBox(height: 24),
                      ...formatSection,
                      const SizedBox(height: 20),
                      ...outputDetails,
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _revealError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _errorKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 1,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  Future<void> _startExport() async {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.read<ProjectService>();
    final premiumService = context.read<PremiumService>();

    if (_startingExport || _isExporting || premiumService.isCheckingBenefits) {
      return;
    }
    if (projectService.hasOutdatedAutofillLayers(widget.projectId)) {
      setState(() => _startingExport = true);
      final proceed = await _confirmOutdatedAutofill();
      if (!mounted) return;
      setState(() => _startingExport = false);
      if (proceed != true || premiumService.isCheckingBenefits) return;
    }

    final project = projectService.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null) {
      setState(() => _error = l10n.exportProjectNotFoundError);
      _revealError();
      return;
    }
    final scenes = projectService.scenesOf(widget.projectId);
    final needsLongExport =
        ExportTiming.sourceFrames(scenes) > 90 * project.fps &&
        !premiumService.isFeatureAvailable(PremiumFeature.unlimitedDuration);
    if (needsLongExport) {
      setState(() => _startingExport = true);
      final proceed = await showPremiumBanner(
        context,
        feature: PremiumFeature.unlimitedDuration,
        title: l10n.premiumBannerFullExportTitle,
        reason: l10n.exportLongProjectNote,
        continueLabel: l10n.exportFirst90Seconds,
      );
      if (!mounted) return;
      setState(() => _startingExport = false);
      if (!proceed) return;
    }
    final maxSeconds = needsLongExport ? 90 : null;
    final format = _format;
    final fps = _fps;
    final defaultHidden =
        context.read<SettingsService?>()?.endCardDefaultHiddenForPremium ??
        true;
    final cancelToken = ExportCancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _isExporting = true;
      _error = null;
      _progress = 0;
    });
    _showProgressDialog();

    try {
      final tileManager = projectService.tileManagerOf(widget.projectId);
      final engine = ExportEngine();

      final totalFrames = ExportTiming(
        sourceFps: project.fps,
        outputFps: fps,
        maxSeconds: maxSeconds,
      ).outputFrames(scenes);

      void onProgress(int current, int total) {
        if (!mounted) return;
        _progress = current / total;
        _refreshProgressDialog?.call();
      }

      // Capture the output conditions once before rendering the first frame.
      final shouldAppendEndCard = _appendEndCard(
        premiumService,
        project.hideEndCard,
        defaultHidden,
      );

      // The timeline's sounds (audio clips and the sound of video
      // materials), placed as the timeline plays them. A GIF has no sound.
      final materials = context.read<MaterialService>();
      final audio = format == ExportFormat.gif
          ? ExportAudioPlan.empty
          : await buildExportAudioPlan(
              scenes: scenes,
              sourceFps: project.fps,
              maxSeconds: maxSeconds,
              pathOf: (id) => materials.pathOf(widget.projectId, id),
            );
      // The video materials this job reads, fixed before the first frame so
      // a material changed during the export does not change what it shows.
      final videoMaterials = await materials.videoSnapshotOf(widget.projectId);

      String outputPath;
      switch (format) {
        case ExportFormat.mp4:
          outputPath = await engine.exportMp4(
            projectName: project.name,
            scenes: scenes,
            tileManager: tileManager,
            fps: fps,
            sourceFps: project.fps,
            maxSeconds: maxSeconds,
            drawingWidth: project.drawingWidth,
            drawingHeight: project.drawingHeight,
            width: project.exportWidth,
            height: project.exportHeight,
            backgroundColor: project.backgroundColor,
            appendEndCard: shouldAppendEndCard,
            audio: audio,
            onProgress: onProgress,
            cancelToken: cancelToken,
            videoMaterials: videoMaterials,
          );
        case ExportFormat.gif:
          outputPath = await engine.exportGif(
            projectName: project.name,
            scenes: scenes,
            tileManager: tileManager,
            fps: fps,
            sourceFps: project.fps,
            maxSeconds: maxSeconds,
            drawingWidth: project.drawingWidth,
            drawingHeight: project.drawingHeight,
            width: project.exportWidth,
            height: project.exportHeight,
            backgroundColor: project.backgroundColor,
            onProgress: onProgress,
            cancelToken: cancelToken,
            videoMaterials: videoMaterials,
          );
        case ExportFormat.webm:
          outputPath = await engine.exportWebm(
            projectName: project.name,
            scenes: scenes,
            tileManager: tileManager,
            fps: fps,
            sourceFps: project.fps,
            maxSeconds: maxSeconds,
            drawingWidth: project.drawingWidth,
            drawingHeight: project.drawingHeight,
            width: project.exportWidth,
            height: project.exportHeight,
            backgroundColor: project.backgroundColor,
            appendEndCard: shouldAppendEndCard,
            audio: audio,
            onProgress: onProgress,
            cancelToken: cancelToken,
            videoMaterials: videoMaterials,
          );
        case ExportFormat.avi:
          outputPath = await engine.exportAvi(
            projectName: project.name,
            scenes: scenes,
            tileManager: tileManager,
            fps: fps,
            sourceFps: project.fps,
            maxSeconds: maxSeconds,
            drawingWidth: project.drawingWidth,
            drawingHeight: project.drawingHeight,
            width: project.exportWidth,
            height: project.exportHeight,
            backgroundColor: project.backgroundColor,
            appendEndCard: shouldAppendEndCard,
            audio: audio,
            onProgress: onProgress,
            cancelToken: cancelToken,
            videoMaterials: videoMaterials,
          );
      }

      _closeProgressDialog();
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _cancelToken = null;
      });
      if (cancelToken.isCancelled) {
        // 最終エンコード段階でキャンセルされていた場合：処理自体は完了して
        // いるが、キャンセル操作の意図に沿って出力ファイルを破棄する
        // （最終エンコードは安全に中断する手段がないため事後処理となる）。
        try {
          File(outputPath).deleteSync();
        } catch (_) {}
        _showCancelledSnackBar();
        return;
      }
      // The completed file is unchanged. Generate only a small standalone
      // cover in the background so the completion dialog appears immediately;
      // the saved-work list also retries when an app is relaunched mid-cache.
      unawaited(ExportedWorkCoverStore.ensureCached(File(outputPath)));
      await _showCompleteDialog(
        outputPath,
        totalFrames,
        soundsLeftOut: engine.audioLeftOut,
        videosLeftOut: engine.videoLeftOut,
      );
    } on ExportCancelledException {
      _closeProgressDialog();
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _cancelToken = null;
      });
      _showCancelledSnackBar();
    } catch (e) {
      _closeProgressDialog();
      if (mounted) {
        setState(() {
          _isExporting = false;
          _cancelToken = null;
          _error = l10n.exportFailedError(fileFailureReason(l10n, e));
        });
        _revealError();
      }
    }
  }

  /// 処理中ダイアログ（動画書き出し・GIF生成・透過WebM生成時に
  /// プログレスバー下部へ正方形広告を表示、処理完了時に自動消去）。
  void _showProgressDialog() {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          _refreshProgressDialog = () {
            if (ctx.mounted) setDialogState(() {});
          };
          return PopScope<void>(
            canPop: false,
            child: ProgressDialog(
              title: l10n.exportInProgressTitle,
              progress: _progress,
              subtitle: _format == ExportFormat.gif && _progress >= 1
                  ? l10n.exportGifEncoding
                  : _format.name.toUpperCase(),
              onCancel: () {
                _cancelToken?.cancel();
                _refreshProgressDialog?.call();
              },
              cancelHint: _cancelToken?.isCancelled == true
                  ? l10n.exportCancelHint
                  : null,
            ),
          );
        },
      ),
    );
    _progressRoute = route;
    unawaited(
      navigator.push(route).whenComplete(() {
        if (identical(_progressRoute, route)) {
          _progressRoute = null;
          _refreshProgressDialog = null;
        }
      }),
    );
  }

  void _showCancelledSnackBar() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exportCancelledSnackbar)));
  }

  void _closeProgressDialog() {
    final route = _progressRoute;
    _progressRoute = null;
    _refreshProgressDialog = null;
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  Future<bool?> _confirmOutdatedAutofill() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l10n.exportOutdatedAutofillTitle),
        content: Text(l10n.exportOutdatedAutofillBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.exportContinueButton),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompleteDialog(
    String outputPath,
    int totalFrames, {
    int soundsLeftOut = 0,
    int videosLeftOut = 0,
  }) async {
    final destination = await showDialog<ExportDestination>(
      context: context,
      builder: (_) => ExportCompleteDialog(
        file: File(outputPath),
        frames: totalFrames,
        soundsLeftOut: soundsLeftOut,
        videosLeftOut: videosLeftOut,
      ),
    );
    if (!mounted || destination == null) return;
    switch (destination) {
      case ExportDestination.works:
        context.go('/home?tab=works');
      case ExportDestination.projects:
        context.go('/home');
      case ExportDestination.canvas:
        context.go('/canvas/${widget.projectId}');
    }
  }
}

enum ExportFormat { mp4, gif, webm, avi }
