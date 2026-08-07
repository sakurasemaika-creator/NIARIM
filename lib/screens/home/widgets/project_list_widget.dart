import 'dart:io';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../engine/mirapro_serializer.dart';
import '../../../models/material_asset.dart';
import '../../../models/project.dart';
import '../../../services/material_service.dart';
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
  final String searchQuery;

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
    this.searchQuery = '',
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
    var filtered = showFavoritesOnly ? source.where((p) => p.isFavorite) : source;
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(query));
    }
    final sorted = _sorted(filtered.toList());

    if (sorted.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.movie_creation_outlined, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text('プロジェクトがありません',
                style: TextStyle(color: scheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('＋ ボタンから新規作成',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
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

    // カード基準サイズ（大/中/小）を軸に、画面幅に応じて列数が自然に増減する
    // グリッドを使う（PC/DeXモードの広い画面でも余白だらけにならないように）。
    final targetExtent = switch (viewMode) {
      ProjectViewMode.large => 240.0,
      ProjectViewMode.medium => 170.0,
      ProjectViewMode.small => 130.0,
      ProjectViewMode.detail => double.infinity,
    };

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: targetExtent,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 12,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) => _gridCard(context, sorted[index]),
    );
  }

  /// プロジェクトカードのサムネイル（仕様書19）。生成済みのPNGがあればそれを表示し、
  /// 未生成・読み込み失敗の場合は背景色のプレースホルダーへフォールバックする。
  Widget _thumbnail(Project project) {
    final placeholder = Container(
      color: Color(project.backgroundColor),
      child: const Center(child: Icon(Icons.image, color: Colors.white38)),
    );
    final path = project.thumbnailPath;
    if (path == null) return placeholder;
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _detailTile(BuildContext context, Project project) {
    final isSelected = selectedIds.contains(project.id);
    return ListTile(
      leading: isSelectionMode
          ? Checkbox(value: isSelected, onChanged: (_) => onSelectionChanged(project.id))
          : SizedBox(
              width: 48,
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _thumbnail(project),
              ),
            ),
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
    final primary = Theme.of(context).colorScheme.primary;
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
                side: BorderSide(color: primary, width: 2),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumbnail(project),
                  if (project.isFavorite)
                    const Positioned(top: 4, right: 4, child: Icon(Icons.star, color: Colors.amber, size: 16)),
                  if (isSelectionMode)
                    Positioned(
                      top: 4, left: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? primary : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: primary),
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
        const PopupMenuItem(value: 'share', child: Text('.mirashareを作成')),
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
      case 'share':
        _createMirashare(context, project);
      case 'favorite':
        service.toggleFavorite(project.id);
      case 'move':
        _showMoveToFolderDialog(context, project);
      case 'delete':
        service.deleteProject(project.id);
    }
  }

  /// .mirashare（共有用ファイル）を作成し、共有シートを表示する（仕様書06・21）。
  Future<void> _createMirashare(BuildContext context, Project project) async {
    final includeTypes = await showMaterialIncludeDialog(context);
    if (includeTypes == null || !context.mounted) return; // キャンセル
    final service = context.read<ProjectService>();
    final materialService = context.read<MaterialService>();
    final scenes = service.scenesOf(project.id);
    final tileManager = service.tileManagerOf(project.id);
    try {
      final bundle = await materialService.buildShareBundle(project.id, includeTypes);
      final file = await MiraproSerializer.saveShare(
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        materialFiles: bundle.files.isEmpty ? null : bundle.files,
        materialsManifest: bundle.manifest,
      );
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('.mirashareの作成に失敗しました: $e')),
      );
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
              leading: Icon(Icons.folder, color: folder.color != null ? Color(folder.color!) : null),
              title: Text(folder.name),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'フォルダを編集',
                onPressed: () => _showEditFolderDialog(context, folder),
              ),
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

  // フォルダ名変更・色変更・削除（仕様書02・19：フォルダ管理）
  static const _folderColors = [
    0xFFFF5C7A, 0xFFFFB020, 0xFFFFE066, 0xFF3DDC97,
    0xFF3AA6FF, 0xFFB15CFF, 0xFF9E9E9E,
  ];

  void _showEditFolderDialog(BuildContext context, ProjectFolder folder) {
    final controller = TextEditingController(text: folder.name);
    int? selectedColor = folder.color;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('フォルダを編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'フォルダ名', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('フォルダ色', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _colorDot(null, selectedColor, (v) => setS(() => selectedColor = v)),
                  ..._folderColors.map((c) => _colorDot(c, selectedColor, (v) => setS(() => selectedColor = v))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                context.read<ProjectService>().deleteFolder(folder.id);
                Navigator.pop(ctx);
              },
              child: const Text('削除'),
            ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                final service = context.read<ProjectService>();
                if (controller.text.isNotEmpty && controller.text != folder.name) {
                  service.renameFolder(folder.id, controller.text);
                }
                if (selectedColor != folder.color) {
                  service.setFolderColor(folder.id, selectedColor);
                }
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(int? color, int? selected, ValueChanged<int?> onTap) {
    final isSelected = color == selected;
    return GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color != null ? Color(color) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: color == null ? const Icon(Icons.block, size: 16, color: Colors.grey) : null,
      ),
    );
  }
}

/// .mirashare作成時の素材同梱選択ダイアログ（仕様書06・21：画像/動画/音声を
/// 種類ごとに選択できる。デフォルトは全種類ON）。キャンセル時はnullを返す。
Future<Set<MaterialType>?> showMaterialIncludeDialog(BuildContext context) {
  final selected = <MaterialType>{MaterialType.image, MaterialType.video, MaterialType.audio};
  return showDialog<Set<MaterialType>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('素材の同梱'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('同梱しない場合、受信側で不足素材の警告が表示されます。',
                style: TextStyle(fontSize: 12)),
            CheckboxListTile(
              value: selected.contains(MaterialType.image),
              title: const Text('画像'),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                  () => v == true ? selected.add(MaterialType.image) : selected.remove(MaterialType.image)),
            ),
            CheckboxListTile(
              value: selected.contains(MaterialType.video),
              title: const Text('動画'),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                  () => v == true ? selected.add(MaterialType.video) : selected.remove(MaterialType.video)),
            ),
            CheckboxListTile(
              value: selected.contains(MaterialType.audio),
              title: const Text('音声'),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                  () => v == true ? selected.add(MaterialType.audio) : selected.remove(MaterialType.audio)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('作成')),
        ],
      ),
    ),
  );
}
