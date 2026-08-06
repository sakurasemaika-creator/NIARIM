import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/project_service.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final projectService = context.watch<ProjectService>();
    final project = projectService.projects.where((p) => p.id == projectId).firstOrNull;

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('プロジェクト')),
        body: const Center(child: Text('プロジェクトが見つかりません')),
      );
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
                case 'duplicate': projectService.duplicateProject(projectId);
                case 'delete': projectService.deleteProject(projectId); context.pop();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(color: Color(project.backgroundColor), borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white38)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.skip_previous)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.fast_rewind)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.play_arrow)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.fast_forward)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next)),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/canvas/$projectId'),
              icon: const Icon(Icons.edit),
              label: const Text('編集開始'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 24),
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
              onPressed: () => context.push('/save-tree/$projectId'),
              icon: const Icon(Icons.account_tree),
              label: const Text('セーブツリー'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value)],
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
    return '${h}時間${m}分';
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
              context.read<ProjectService>().renameProject(projectId, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}
