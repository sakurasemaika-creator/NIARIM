import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../models/project.dart';
import '../../../services/project_service.dart';
import '../home_screen.dart';

class ProjectListWidget extends StatelessWidget {
  final ProjectViewMode viewMode;
  final ProjectSortMode sortMode;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final VoidCallback onLongPress;
  final ValueChanged<String> onSelectionChanged;
  final List<Project>? projects; // nullの場合はServiceから取得
  final bool showFavoritesOnly;

  const ProjectListWidget({
    super.key,
    required this.viewMode,
    required this.sortMode,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onLongPress,
    required this.onSelectionChanged,
    this.projects,
    this.showFavoritesOnly = false,
  });

  List<Project> _sorted(List<Project> src) {
    final list = List<Project>.from(src);
    switch (sortMode) {
      case ProjectSortMode.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case ProjectSortMode.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
      case ProjectSortMode.updatedAsc:
        list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case ProjectSortMode.updatedDesc:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final source = projects ?? context.watch<ProjectService>().projects;
    final filtered = showFavoritesOnly ? source.where((p) => p.isFavorite).toList() : source;
    final sorted = _sorted(filtered);

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_creation_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('プロジェクトがありません', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            const SizedBox(height: 8),
            Text('＋ ボタンから新規作成', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    if (viewMode == ProjectViewMode.detail) {
      return ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, index) => _detailTile(context, sorted[index]),
      );
    }

    final crossAxisCount = switch (viewMode) {
      ProjectViewMode.large => 2,
      ProjectViewMode.medium => 3,
      ProjectViewMode.small => 4,
      ProjectViewMode.detail => 1,
    };

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 12,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) => _gridCard(context, sorted[index]),
    );
  }

  Widget _detailTile(BuildContext context, Project project) {
    final isSelected = selectedIds.contains(project.id);
    return ListTile(
      leading: isSelectionMode
          ? Checkbox(value: isSelected, onChanged: (_) => onSelectionChanged(project.id))
          : Container(width: 48, height: 48, color: Color(project.backgroundColor)),
      title: Text(project.name),
      subtitle: Text('${project.fps}fps · ${project.durationSeconds}秒'),
      trailing: isSelectionMode
          ? null
          : _projectMenu(context, project),
      onTap: isSelectionMode
          ? () => onSelectionChanged(project.id)
          : () => context.push('/project/${project.id}'),
      onLongPress: onLongPress,
    );
  }

  Widget _gridCard(BuildContext context, Project project) {
    final isSelected = selectedIds.contains(project.id);
    return GestureDetector(
      onTap: isSelectionMode
          ? () => onSelectionChanged(project.id)
          : () => context.push('/project/${project.id}'),
      onDoubleTap: isSelectionMode ? null : () => context.push('/canvas/${project.id}'),
      onLongPress: onLongPress,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: isSelected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.blue, width: 2),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: Color(project.backgroundColor),
                    child: const Center(child: Icon(Icons.image, color: Colors.white38)),
                  ),
                  if (project.isFavorite)
                    const Positioned(top: 4, right: 4, child: Icon(Icons.star, color: Colors.amber, size: 16)),
                  if (isSelectionMode)
                    Positioned(
                      top: 4, left: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue),
                        ),
                        child: Icon(isSelected ? Icons.check : null, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(project.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectMenu(BuildContext context, Project project) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) => _handleAction(context, action, project),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'open', child: Text('開く')),
        const PopupMenuItem(value: 'rename', child: Text('名前変更')),
        const PopupMenuItem(value: 'duplicate', child: Text('複製')),
        PopupMenuItem(
          value: 'favorite',
          child: Text(project.isFavorite ? 'お気に入り解除' : 'お気に入り'),
        ),
        const PopupMenuItem(value: 'move', child: Text('フォルダへ移動')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('ゴミ箱へ移動', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, String action, Project project) {
    final service = context.read<ProjectService>();
    switch (action) {
      case 'open':
        context.push('/canvas/${project.id}');
      case 'rename':
        _showRenameDialog(context, project);
      case 'duplicate':
        service.duplicateProject(project.id);
      case 'favorite':
        service.toggleFavorite(project.id);
      case 'move':
        _showMoveToFolderDialog(context, project);
      case 'delete':
        service.deleteProject(project.id);
    }
  }

  void _showRenameDialog(BuildContext context, Project project) {
    final controller = TextEditingController(text: project.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('名前変更'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>().renameProject(project.id, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }

  void _showMoveToFolderDialog(BuildContext context, Project project) {
    final folders = context.read<ProjectService>().folders;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('フォルダへ移動', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('フォルダなし'),
              onTap: () {
                context.read<ProjectService>().moveToFolder(project.id, null);
                Navigator.pop(ctx);
              },
            ),
            ...folders.map((folder) => ListTile(
              leading: const Icon(Icons.folder),
              title: Text(folder.name),
              onTap: () {
                context.read<ProjectService>().moveToFolder(project.id, folder.id);
                Navigator.pop(ctx);
              },
            )),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('新規フォルダを作成'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateFolderDialog(context, project);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, Project project) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規フォルダ'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'フォルダ名', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final service = context.read<ProjectService>();
              final folder = await service.createFolder(controller.text);
              await service.moveToFolder(project.id, folder.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }
}
