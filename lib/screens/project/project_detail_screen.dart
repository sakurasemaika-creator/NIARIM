import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../engine/layer_compositor.dart';
import '../../services/project_service.dart';
import '../../widgets/responsive.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

/// シーンをまたいだ絶対フレーム位置（プレビュー再生用）。
typedef _FlatFrame = ({String sceneId, int frameIndex});

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  int _frameIndex = 0;
  bool _isPlaying = false;
  bool _rendering = false;
  Timer? _timer;
  ui.Image? _previewImage;

  @override
  void dispose() {
    _timer?.cancel();
    _previewImage?.dispose();
    super.dispose();
  }

  List<_FlatFrame> _flatten(ProjectService ps) {
    final result = <_FlatFrame>[];
    for (final scene in ps.scenesOf(widget.projectId)) {
      for (int i = 0; i < scene.frames.length; i++) {
        result.add((sceneId: scene.id, frameIndex: i));
      }
    }
    return result;
  }

  Future<void> _renderFrame(ProjectService ps, List<_FlatFrame> flat) async {
    if (_rendering || flat.isEmpty) return;
    _rendering = true;
    final entry = flat[_frameIndex.clamp(0, flat.length - 1)];
    final tileManager = ps.tileManagerOf(widget.projectId);
    final layers = ps.layersOf(widget.projectId, entry.sceneId, entry.frameIndex);
    final img = await LayerCompositor.composite(
      tileManager,
      layers,
      (l) => ps.tileKeyFor(widget.projectId, entry.sceneId, entry.frameIndex, l.id),
      tileManager.canvasWidth,
      tileManager.canvasHeight,
    );
    _rendering = false;
    if (!mounted) {
      img.dispose();
      return;
    }
    final old = _previewImage;
    setState(() => _previewImage = img);
    old?.dispose();
  }

  void _seekTo(ProjectService ps, List<_FlatFrame> flat, int index) {
    if (flat.isEmpty) return;
    setState(() => _frameIndex = index.clamp(0, flat.length - 1));
    _renderFrame(ps, flat);
  }

  void _togglePlay(ProjectService ps, List<_FlatFrame> flat, int fps) {
    if (flat.isEmpty) return;
    if (_isPlaying) {
      _timer?.cancel();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    final interval = Duration(milliseconds: (1000 / fps).round().clamp(16, 1000));
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() => _frameIndex = (_frameIndex + 1) % flat.length);
      _renderFrame(ps, flat);
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectService = context.watch<ProjectService>();
    final project = projectService.projects.where((p) => p.id == widget.projectId).firstOrNull;

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('プロジェクト')),
        body: const Center(child: Text('プロジェクトが見つかりません')),
      );
    }

    final flat = _flatten(projectService);
    if (_previewImage == null && !_rendering) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _renderFrame(projectService, flat));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case 'rename': _showRenameDialog(context, project.name);
                case 'duplicate': projectService.duplicateProject(widget.projectId);
                case 'delete': projectService.deleteProject(widget.projectId); context.pop();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('名前変更')),
              const PopupMenuItem(value: 'duplicate', child: Text('複製')),
              const PopupMenuItem(value: 'move', child: Text('フォルダへ移動')),
              const PopupMenuItem(value: 'delete', child: Text('ゴミ箱へ移動', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: desktopCentered(
        context,
        SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(color: Color(project.backgroundColor), borderRadius: BorderRadius.circular(8)),
                clipBehavior: Clip.antiAlias,
                child: _previewImage != null
                    ? RawImage(image: _previewImage, fit: BoxFit.contain)
                    : const Center(child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white38)),
              ),
            ),
            const SizedBox(height: 16),
            // メディアプレイヤー風：中央の再生ボタンをテーマカラーの円で強調する
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: flat.isEmpty ? null : () => _seekTo(projectService, flat, 0),
                    icon: const Icon(Icons.skip_previous),
                    tooltip: '先頭フレーム',
                  ),
                  IconButton(
                    onPressed: flat.isEmpty ? null : () => _seekTo(projectService, flat, _frameIndex - 1),
                    icon: const Icon(Icons.fast_rewind),
                    tooltip: '1フレーム戻る',
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: flat.isEmpty
                          ? null
                          : () => _togglePlay(projectService, flat, project.fps),
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Theme.of(context).colorScheme.onPrimary),
                      tooltip: _isPlaying ? '一時停止' : '再生',
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: flat.isEmpty ? null : () => _seekTo(projectService, flat, _frameIndex + 1),
                    icon: const Icon(Icons.fast_forward),
                    tooltip: '1フレーム進む',
                  ),
                  IconButton(
                    onPressed: flat.isEmpty ? null : () => _seekTo(projectService, flat, flat.length - 1),
                    icon: const Icon(Icons.skip_next),
                    tooltip: '最終フレーム',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/canvas/${widget.projectId}'),
              icon: const Icon(Icons.edit),
              label: const Text('編集開始'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('プロジェクト情報',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('FPS', '${project.fps}'),
                    _infoRow('書き出しサイズ', '${project.exportWidth}×${project.exportHeight}'),
                    if (project.hasExtendedDrawingArea)
                      _infoRow('描画領域', '${project.drawingWidth}×${project.drawingHeight}  (${project.drawingAreaScale.toStringAsFixed(1)}倍)'),
                    _infoRow('総フレーム数', '${project.totalFrames}'),
                    _infoRow('制作時間', _formatDuration(project.totalWorkSeconds)),
                    _infoRow('最終保存', _formatDateTime(project.updatedAt)),
                    _infoRow('容量', _formatSize(project.sizeBytes)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/save-tree/${widget.projectId}'),
              icon: const Icon(Icons.account_tree),
              label: const Text('セーブツリー'),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$h時間$m分';
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  void _showRenameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('名前変更'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>().renameProject(widget.projectId, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}
