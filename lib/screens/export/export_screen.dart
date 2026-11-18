import 'package:niarim/services/theme_service.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../widgets/premium_lock_widget.dart';
import '../../engine/export_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/export_share_feedback.dart';
import '../../widgets/labeled_slider.dart';
import '../../widgets/progress_dialog.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';
import '../home/widgets/exported_work_thumbnail_dialog.dart';
import 'widgets/export_preset_selector.dart';
import '../../models/export_preset.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/menu_card.dart';
import '../../utils/file_failure_reason.dart';
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
  void Function(void Function())? _progressDialogSetState;
  // 誤タップ対応のキャンセルボタン。フレーム生成中のみ
  // 実際に中断できる（最終エンコード処理自体は安全に中断する手段がない
  // ため、その段階でのキャンセルは処理完了後に出力ファイルを破棄する形で
  // 反映される）。
  ExportCancelToken? _cancelToken;
  // 「カスタム」選択時のみ編集可能なFPS（「カスタム」タップで
  // アコーディオン展開して詳細設定を表示する）
  int _customFps = 30;

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
    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(l10n.exportScreenTitle),
        actions: const [HelpButton(topic: '特典の期限が切れたら')],
      ),
      body: _buildSettings(l10n),
    );
  }

  Widget _buildSettings(AppLocalizations l10n) {
    final premium = context.watch<PremiumService>();
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
    return desktopCentered(
      context,
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: ThemeService.activeColorScheme.error),
                ),
              ),
            Text(
              l10n.exportPresetSection,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const SizedBox(height: 8),
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
                      child: MenuCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.exportAdvancedSettings,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Kuramubon',
                                  fontFamilyFallback: kHeadingFontFallback,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LabeledSlider(
                                label: l10n.exportFpsLabel,
                                value: _customFps.toDouble(),
                                min: 12,
                                max: 60,
                                divisions: 48,
                                sliderLabel: '$_customFps',
                                valueText: '$_customFps',
                                onChanged: (v) =>
                                    setState(() => _customFps = v.round()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.exportFormatSection,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<ExportFormat>(
              groupValue: _format,
              onChanged: (v) => setState(() => _format = v!),
              child: Column(
                children: [
                  RadioListTile(
                    title: Text(
                      l10n.exportFormatMp4,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    subtitle: Text(
                      l10n.exportFormatMp4Subtitle,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    value: ExportFormat.mp4,
                  ),
                  RadioListTile(
                    title: Text(
                      l10n.exportFormatGif,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    subtitle: Text(
                      l10n.exportFormatGifSubtitle,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    value: ExportFormat.gif,
                  ),
                  RadioListTile(
                    title: Text(
                      l10n.helpTransparentWebmTitle,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    subtitle: Text(
                      l10n.exportFormatWebmSubtitle,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    value: ExportFormat.webm,
                  ),
                  RadioListTile(
                    title: Text(
                      l10n.exportFormatAvi,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    subtitle: Text(
                      l10n.exportFormatAviSubtitle,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    value: ExportFormat.avi,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              appendEndCard
                  ? l10n.exportOutputWithEndCard(duration)
                  : l10n.exportOutputWithoutEndCard(duration),
            ),
            Text(l10n.exportKeepsPlaybackTime),
            if (needsLongExport) Text(l10n.exportLongProjectNote),
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
            FilledButton.icon(
              onPressed:
                  _isExporting || _startingExport || premium.isCheckingBenefits
                  ? null
                  : _startExport,
              icon: const Icon(Icons.file_download),
              label: Text(
                verificationUnavailable
                    ? l10n.exportCurrentConditions
                    : l10n.exportStartButton,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
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
        _progressDialogSetState?.call(() {});
      }

      // Capture the output conditions once before rendering the first frame.
      final shouldAppendEndCard = _appendEndCard(
        premiumService,
        project.hideEndCard,
        defaultHidden,
      );

      String outputPath;
      switch (format) {
        case ExportFormat.mp4:
          outputPath = await engine.exportMp4(
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
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        case ExportFormat.gif:
          outputPath = await engine.exportGif(
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
          );
        case ExportFormat.webm:
          outputPath = await engine.exportWebm(
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
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
        case ExportFormat.avi:
          outputPath = await engine.exportAvi(
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
            onProgress: onProgress,
            cancelToken: cancelToken,
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
      _showCompleteDialog(outputPath, totalFrames);
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
      }
    }
  }

  /// 処理中ダイアログ（動画書き出し・GIF生成・透過WebM生成時に
  /// プログレスバー下部へ正方形広告を表示、処理完了時に自動消去）。
  void _showProgressDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          _progressDialogSetState = setDialogState;
          return ProgressDialog(
            title: l10n.exportInProgressTitle,
            progress: _progress,
            subtitle: _format.name.toUpperCase(),
            onCancel: () {
              _cancelToken?.cancel();
              setDialogState(() {});
            },
            cancelHint: _cancelToken?.isCancelled == true
                ? l10n.exportCancelHint
                : null,
          );
        },
      ),
    ).whenComplete(() => _progressDialogSetState = null);
  }

  void _showCancelledSnackBar() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exportCancelledSnackbar)));
  }

  void _closeProgressDialog() {
    _progressDialogSetState = null;
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<bool?> _confirmOutdatedAutofill() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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

  void _showCompleteDialog(String outputPath, int totalFrames) {
    final l10n = AppLocalizations.of(context)!;
    final fileName = outputPath.split('/').last;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exportCompleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.exportCompleteFramesBody(totalFrames)),
            const SizedBox(height: 12),
            // 保存先はアプリ内の永続領域（他端末のファイルアプリ等からは
            // 直接見えないアプリ専用領域）。端末の「写真」アプリや
            // ファイルアプリで見つけたい場合は「共有」から保存先を選ぶ
            // 必要があることを明示する。
            Text(
              l10n.exportSaveLocationLabel(fileName),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.exportSaveLocationHint,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: Text(l10n.exportBackToProjectsButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/canvas/${widget.projectId}');
            },
            child: Text(l10n.exportBackToCanvasButton),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // 共有できない端末・失敗は、この画面の通知で知らせる
              // （以前は結果を待たず、失敗が未処理の例外になった）。
              shareExportedFileWithNotice(context, File(outputPath));
            },
            icon: const Icon(Icons.share),
            label: Text(l10n.homeShareOpenWith),
          ),
        ],
      ),
    );
  }
}

enum ExportFormat { mp4, gif, webm, avi }
