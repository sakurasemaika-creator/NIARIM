import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/export_engine.dart';
import '../../services/project_service.dart';

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

  int get _fps => _preset == ExportPreset.highQuality ? 60 : 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('書き出し')),
      body: _isExporting ? _buildProgress() : _buildSettings(),
    );
  }

  Widget _buildSettings() {
    return SingleChildScrollView(
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
            onPressed: _startExport,
            icon: const Icon(Icons.file_download),
            label: const Text('書き出し開始'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('書き出し中... ${(_progress * 100).round()}%'),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: LinearProgressIndicator(value: _progress),
          ),
        ],
      ),
    );
  }

  Future<void> _startExport() async {
    setState(() { _isExporting = true; _error = null; _progress = 0; });

    try {
      final projectService = context.read<ProjectService>();
      final project = projectService.projects.where((p) => p.id == widget.projectId).firstOrNull;
      if (project == null) throw Exception('プロジェクトが見つかりません');

      final scenes = projectService.scenesOf(widget.projectId);
      final tileManager = projectService.tileManagerOf(widget.projectId);
      final engine = ExportEngine();

      final totalFrames = scenes.fold(0, (sum, s) => sum + s.frames.length);

      void onProgress(int current, int total) {
        if (mounted) setState(() => _progress = current / total);
      }

      String outputPath;
      switch (_format) {
        case ExportFormat.mp4:
          outputPath = await engine.exportMp4(
            scenes: scenes,
            tileManager: tileManager,
            fps: _fps,
            width: project.exportWidth,
            height: project.exportHeight,
            backgroundColor: project.backgroundColor,
            onProgress: onProgress,
          );
        case ExportFormat.gif:
          outputPath = await engine.exportGif(
            scenes: scenes,
            tileManager: tileManager,
            fps: _fps,
            width: project.exportWidth,
            height: project.exportHeight,
            backgroundColor: project.backgroundColor,
            onProgress: onProgress,
          );
        case ExportFormat.webm:
          outputPath = await engine.exportWebm(
            scenes: scenes,
            tileManager: tileManager,
            fps: _fps,
            width: project.exportWidth,
            height: project.exportHeight,
            backgroundColor: project.backgroundColor,
            onProgress: onProgress,
          );
      }

      if (!mounted) return;
      setState(() => _isExporting = false);
      _showCompleteDialog(outputPath, totalFrames);
    } catch (e) {
      if (mounted) setState(() { _isExporting = false; _error = '書き出し失敗: $e'; });
    }
  }

  void _showCompleteDialog(String outputPath, int totalFrames) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('書き出し完了'),
        content: Text('$totalFrames フレームの書き出しが完了しました。'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); context.go('/canvas/${widget.projectId}'); },
            child: const Text('キャンバスへ戻る'),
          ),
          FilledButton.icon(
            onPressed: () { Navigator.pop(ctx); Share.shareXFiles([XFile(outputPath)]); },
            icon: const Icon(Icons.share),
            label: const Text('共有'),
          ),
        ],
      ),
    );
  }
}

enum ExportFormat { mp4, gif, webm }
enum ExportPreset { standard, highQuality, custom }
