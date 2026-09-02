import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/export_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/stepped_slider.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/progress_dialog.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../config/font_fallback.dart';

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportScreenTitle), actions: const [HelpButton(topic: '動画書き出し（MP4）')]),
      body: _buildSettings(l10n),
    );
  }

  Widget _buildSettings(AppLocalizations l10n) {
    return desktopCentered(
      context,
      SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Text(l10n.exportPresetSection, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback)),
          const SizedBox(height: 8),
          SegmentedButton<ExportPreset>(
            segments: [
              ButtonSegment(value: ExportPreset.standard, label: Text(l10n.exportPresetStandard)),
              ButtonSegment(value: ExportPreset.highQuality, label: Text(l10n.exportPresetHighQuality)),
              ButtonSegment(value: ExportPreset.custom, label: Text(l10n.exportPresetCustom)),
            ],
            selected: {_preset},
            onSelectionChanged: (v) => setState(() => _preset = v.first),
          ),
          // 「カスタム」選択時のみ詳細設定を展開表示する（初心者はプリセットを
          // 選ぶだけで書き出しが完了する。詳細設定は「カスタム」タップ時のみ表示）。
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _preset != ExportPreset.custom
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.exportAdvancedSettings, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(l10n.exportFpsLabel),
                                Expanded(
                                  child: SteppedSlider(
                                    value: _customFps.toDouble(),
                                    min: 12, max: 60, divisions: 48,
                                    label: '$_customFps',
                                    onChanged: (v) => setState(() => _customFps = v.round()),
                                  ),
                                ),
                                SizedBox(
                                  width: 36,
                                  child: EditableSliderValue(
                                    text: '$_customFps', textAlign: TextAlign.center,
                                    value: _customFps, min: 12, max: 60,
                                    onChanged: (v) => setState(() => _customFps = v.round()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text(l10n.exportFormatSection, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback)),
          const SizedBox(height: 8),
          RadioGroup<ExportFormat>(
            groupValue: _format,
            onChanged: (v) => setState(() => _format = v!),
            child: Column(
              children: [
                RadioListTile(title: Text(l10n.exportFormatMp4), subtitle: Text(l10n.exportFormatMp4Subtitle), value: ExportFormat.mp4),
                RadioListTile(title: Text(l10n.exportFormatGif), subtitle: Text(l10n.exportFormatGifSubtitle), value: ExportFormat.gif),
                RadioListTile(title: Text(l10n.helpTransparentWebmTitle), subtitle: Text(l10n.exportFormatWebmSubtitle), value: ExportFormat.webm),
                RadioListTile(title: Text(l10n.exportFormatAvi), subtitle: Text(l10n.exportFormatAviSubtitle), value: ExportFormat.avi),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isExporting ? null : _startExport,
            icon: const Icon(Icons.file_download),
            label: Text(l10n.exportStartButton),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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

    // 自動塗り未更新警告（書き出し前の未更新警告）
    if (projectService.hasOutdatedAutofillLayers(widget.projectId)) {
      final proceed = await _confirmOutdatedAutofill();
      if (proceed != true) return;
    }

    // 無料版の最大動画尺チェック
    if (!premiumService.isPremium) {
      final scenesPreview = projectService.scenesOf(widget.projectId);
      final totalFramesPreview = scenesPreview.fold(0, (sum, s) => sum + s.frames.length);
      final seconds = totalFramesPreview / _fps;
      if (seconds > premiumService.maxProjectDurationSeconds) {
        final proceed = await _confirmDurationExceeded(seconds, premiumService.maxProjectDurationSeconds);
        if (proceed != true) return;
      }
    }

    final cancelToken = ExportCancelToken();
    _cancelToken = cancelToken;
    setState(() { _isExporting = true; _error = null; _progress = 0; });
    _showProgressDialog();

    try {
      final project = projectService.projects.where((p) => p.id == widget.projectId).firstOrNull;
      if (project == null) throw Exception(l10n.exportProjectNotFoundError);

      final scenes = projectService.scenesOf(widget.projectId);
      final tileManager = projectService.tileManagerOf(widget.projectId);
      final engine = ExportEngine();

      final totalFrames = scenes.fold(0, (sum, s) => sum + s.frames.length);

      void onProgress(int current, int total) {
        if (!mounted) return;
        _progress = current / total;
        _progressDialogSetState?.call(() {});
      }

      // 無料版：書き出し時にエンドカード（NIARIMロゴ・約5秒）を本編末尾へ
      // 自動追加する。mp4/webmとも、動画の結合ではなく
      // フレーム生成の段階で末尾へ焼き込む（endcard_frame参照）。
      final shouldAppendEndCard = !premiumService.isPremium &&
          (_format == ExportFormat.mp4 ||
              _format == ExportFormat.webm ||
              _format == ExportFormat.avi);

      String outputPath;
      switch (_format) {
        case ExportFormat.mp4:
          outputPath = await engine.exportMp4(
            scenes: scenes,
            tileManager: tileManager,
            fps: _fps,
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
            fps: _fps,
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
            fps: _fps,
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
            fps: _fps,
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
      setState(() { _isExporting = false; _cancelToken = null; });
      if (cancelToken.isCancelled) {
        // 最終エンコード段階でキャンセルされていた場合：処理自体は完了して
        // いるが、キャンセル操作の意図に沿って出力ファイルを破棄する
        // （最終エンコードは安全に中断する手段がないため事後処理となる）。
        try { File(outputPath).deleteSync(); } catch (_) {}
        _showCancelledSnackBar();
        return;
      }
      _showCompleteDialog(outputPath, totalFrames);
    } on ExportCancelledException {
      _closeProgressDialog();
      if (!mounted) return;
      setState(() { _isExporting = false; _cancelToken = null; });
      _showCancelledSnackBar();
    } catch (e) {
      _closeProgressDialog();
      if (mounted) setState(() { _isExporting = false; _cancelToken = null; _error = l10n.exportFailedError(e.toString()); });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.exportCancelledSnackbar)),
    );
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.exportContinueButton)),
        ],
      ),
    );
  }

  Future<bool?> _confirmDurationExceeded(double seconds, int maxSeconds) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exportDurationExceededTitle),
        content: Text(l10n.exportDurationExceededBody(maxSeconds, seconds.round())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              showPremiumBanner(context);
            },
            child: Text(l10n.exportViewPremiumButton),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.exportContinueAnywayButton)),
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
            Text(l10n.exportSaveLocationLabel(fileName),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback)),
            const SizedBox(height: 4),
            Text(l10n.exportSaveLocationHint,
                style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); context.go('/home'); },
            child: Text(l10n.exportBackToProjectsButton),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); context.go('/canvas/${widget.projectId}'); },
            child: Text(l10n.exportBackToCanvasButton),
          ),
          FilledButton.icon(
            onPressed: () { Navigator.pop(ctx); SharePlus.instance.share(ShareParams(files: [XFile(outputPath)])); },
            icon: const Icon(Icons.share),
            label: Text(l10n.homeShareOpenWith),
          ),
        ],
      ),
    );
  }
}

enum ExportFormat { mp4, gif, webm, avi }
enum ExportPreset { standard, highQuality, custom }
