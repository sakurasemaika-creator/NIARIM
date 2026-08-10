import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/export_engine.dart';
import '../../services/premium_service.dart';
import '../../services/project_service.dart';
import '../../widgets/premium_lock_widget.dart';
import '../../widgets/progress_dialog.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

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
  // 誤タップ対応のキャンセルボタン（仕様書06・13）。フレーム生成中のみ
  // 実際に中断できる（最終エンコード処理自体は安全に中断する手段がない
  // ため、その段階でのキャンセルは処理完了後に出力ファイルを破棄する形で
  // 反映される）。
  ExportCancelToken? _cancelToken;
  // 「カスタム」選択時のみ編集可能なFPS（仕様書06・11：「カスタム」タップで
  // アコーディオン展開して詳細設定を表示する）
  int _customFps = 30;

  int get _fps => switch (_preset) {
        ExportPreset.standard => 30,
        ExportPreset.highQuality => 60,
        ExportPreset.custom => _customFps,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('書き出し'), actions: const [HelpButton(topic: '動画書き出し（MP4）')]),
      body: _buildSettings(),
    );
  }

  Widget _buildSettings() {
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
          const Text('プリセット', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<ExportPreset>(
            segments: const [
              ButtonSegment(value: ExportPreset.standard, label: Text('標準')),
              ButtonSegment(value: ExportPreset.highQuality, label: Text('高画質')),
              ButtonSegment(value: ExportPreset.custom, label: Text('カスタム')),
            ],
            selected: {_preset},
            onSelectionChanged: (v) => setState(() => _preset = v.first),
          ),
          // 「カスタム」選択時のみ詳細設定を展開表示する（仕様書06・11：
          // 「初心者はプリセットを選ぶだけで書き出しが完了する。詳細設定は
          // 「カスタム」タップ時のみ表示」）。
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
                            const Text('詳細設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('FPS'),
                                Expanded(
                                  child: Slider(
                                    value: _customFps.toDouble(),
                                    min: 12, max: 60, divisions: 48,
                                    label: '$_customFps',
                                    onChanged: (v) => setState(() => _customFps = v.round()),
                                  ),
                                ),
                                SizedBox(width: 36, child: Text('$_customFps', textAlign: TextAlign.center)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          const Text('形式', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RadioGroup<ExportFormat>(
            groupValue: _format,
            onChanged: (v) => setState(() => _format = v!),
            child: Column(
              children: [
                RadioListTile(title: const Text('MP4'), subtitle: const Text('汎用動画形式'), value: ExportFormat.mp4),
                RadioListTile(title: const Text('GIF'), subtitle: const Text('アニメーションGIF'), value: ExportFormat.gif),
                RadioListTile(title: const Text('透過WebM'), subtitle: const Text('透明背景動画'), value: ExportFormat.webm),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isExporting ? null : _startExport,
            icon: const Icon(Icons.file_download),
            label: const Text('書き出し開始'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _startExport() async {
    final projectService = context.read<ProjectService>();
    final premiumService = context.read<PremiumService>();

    // 自動塗り未更新警告（仕様書04・06：書き出し前の未更新警告）
    if (projectService.hasOutdatedAutofillLayers(widget.projectId)) {
      final proceed = await _confirmOutdatedAutofill();
      if (proceed != true) return;
    }

    // 無料版の最大動画尺チェック（仕様書13・19）
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
      if (project == null) throw Exception('プロジェクトが見つかりません');

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
      // 自動追加する（仕様書06・13）。mp4/webmとも、動画の結合ではなく
      // フレーム生成の段階で末尾へ焼き込む（endcard_frame参照）。
      final shouldAppendEndCard = !premiumService.isPremium &&
          (_format == ExportFormat.mp4 || _format == ExportFormat.webm);

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
      }

      _closeProgressDialog();
      if (!mounted) return;
      setState(() { _isExporting = false; _cancelToken = null; });
      if (cancelToken.isCancelled) {
        // 最終エンコード段階でキャンセルされていた場合：処理自体は完了して
        // いるが、ユーザーの意図はキャンセルのため出力ファイルを破棄する
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
      if (mounted) setState(() { _isExporting = false; _cancelToken = null; _error = '書き出し失敗: $e'; });
    }
  }

  /// 処理中ダイアログ（仕様書13：動画書き出し・GIF生成・透過WebM生成時に
  /// プログレスバー下部へ正方形広告を表示、処理完了時に自動消去）。
  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          _progressDialogSetState = setDialogState;
          return ProgressDialog(
            title: '書き出し中',
            progress: _progress,
            subtitle: _format.name.toUpperCase(),
            onCancel: () {
              _cancelToken?.cancel();
              setDialogState(() {});
            },
            cancelHint: _cancelToken?.isCancelled == true
                ? '最終処理中のため、完了後にキャンセルを反映します'
                : null,
          );
        },
      ),
    ).whenComplete(() => _progressDialogSetState = null);
  }

  void _showCancelledSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('書き出しをキャンセルしました')),
    );
  }

  void _closeProgressDialog() {
    _progressDialogSetState = null;
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<bool?> _confirmOutdatedAutofill() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自動塗りが最新ではありません'),
        content: const Text('更新されていない自動塗りレイヤーがあります。このまま書き出しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('続行')),
        ],
      ),
    );
  }

  Future<bool?> _confirmDurationExceeded(double seconds, int maxSeconds) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('動画尺の上限を超えています'),
        content: Text(
            '無料版の最大動画尺は$maxSeconds秒です。\n現在のプロジェクトは約${seconds.round()}秒あります。\nPremiumにアップグレードすると尺の制限がなくなります。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              showPremiumBanner(context);
            },
            child: const Text('Premiumを見る'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('このまま続行')),
        ],
      ),
    );
  }

  void _showCompleteDialog(String outputPath, int totalFrames) {
    final fileName = outputPath.split('/').last;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('書き出し完了'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$totalFrames フレームの書き出しが完了しました。'),
            const SizedBox(height: 12),
            // 保存先はアプリ内の永続領域（他端末のファイルアプリ等からは
            // 直接見えないアプリ専用領域）。端末の「写真」アプリや
            // ファイルアプリで見つけたい場合は「共有」から保存先を選ぶ
            // 必要があることを明示する（従来は保存先が一切表示されず
            // 分かりにくいという指摘があった）。
            Text('保存先：アプリ内（$fileName）',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('端末の「写真」アプリやファイルアプリで開くには、下の「共有」から保存先アプリを選んでください。',
                style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); context.go('/home'); },
            child: const Text('プロジェクト一覧へ戻る'),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); context.go('/canvas/${widget.projectId}'); },
            child: const Text('キャンバスへ戻る'),
          ),
          FilledButton.icon(
            onPressed: () { Navigator.pop(ctx); SharePlus.instance.share(ShareParams(files: [XFile(outputPath)])); },
            icon: const Icon(Icons.share),
            label: const Text('共有・写真アプリ等で開く'),
          ),
        ],
      ),
    );
  }
}

enum ExportFormat { mp4, gif, webm }
enum ExportPreset { standard, highQuality, custom }
