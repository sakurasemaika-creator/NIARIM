import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../engine/niapro_serializer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/material_asset.dart';
import '../../../models/project.dart';
import '../../../services/font_service.dart';
import '../../../services/material_service.dart';
import '../../../services/project_service.dart';
import '../home_screen.dart';

/// 新規フォルダ作成ダイアログ（フォルダ名入力）。プロジェクト一覧画面の
/// ＋ボタン（新規プロジェクト/新規フォルダ選択）・フォルダ移動ピッカーの
/// 双方から共通で使う（重複実装を避けるためpublicなトップレベル関数として
/// 定義し、home_screen.dartからも呼び出せるようにしている）。
void showCreateFolderNameDialog(BuildContext context, Future<void> Function(String name) onCreate) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.projectListNewFolderTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.folderNameLabel, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          // 同じ作品の複数話数・シリーズ物をまとめる使い方への気づきを促す
          // ヒント（フォルダは複数階層に対応しているため実現可能）。
          Text(
            l10n.projectListFolderHint,
            style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: () async {
            if (controller.text.trim().isEmpty) return;
            await onCreate(controller.text.trim());
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(l10n.commonCreate),
        ),
      ],
    ),
  );
}

/// フォルダ・プロジェクトを同一一覧内で扱うための表示用ラッパー
/// （仕様書19：「フォルダとプロジェクトを同一一覧内で並び替え」）。
class _Entry {
  final ProjectFolder? folder;
  final Project? project;
  const _Entry.folder(ProjectFolder f) : folder = f, project = null;
  const _Entry.project(Project p) : project = p, folder = null;

  bool get isFolder => folder != null;
  String get id => isFolder ? folder!.id : project!.id;
  String get name => isFolder ? folder!.name : project!.name;
  DateTime get sortDate => isFolder ? folder!.createdAt : project!.updatedAt;
  bool get isFavorite => isFolder ? folder!.isFavorite : project!.isFavorite;
}

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
  // 現在開いているフォルダ（nullはルート直下、仕様書19：フォルダ階層）
  final String? currentFolderId;
  final ValueChanged<String> onOpenFolder;

  const ProjectListWidget({
    super.key,
    required this.viewMode,
    required this.sortMode,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onLongPress,
    required this.onSelectionChanged,
    required this.currentFolderId,
    required this.onOpenFolder,
    this.projects,
    this.showFavoritesOnly = false,
    this.searchQuery = '',
  });

  List<_Entry> _sorted(List<_Entry> src) {
    final list = List<_Entry>.from(src);
    switch (sortMode) {
      case ProjectSortMode.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
      case ProjectSortMode.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
      case ProjectSortMode.updatedAsc:
        list.sort((a, b) => a.sortDate.compareTo(b.sortDate));
      case ProjectSortMode.updatedDesc:
        list.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final source = projects ?? projectService.projects;
    final allFolders = projectService.folders;
    final query = searchQuery.trim().toLowerCase();

    List<_Entry> entries;
    if (query.isNotEmpty) {
      // 検索時はフォルダ階層を無視して全体から名前一致するものを表示
      // （仕様書19：「検索対象：プロジェクト名 / フォルダ名」）。
      entries = [
        ...allFolders.where((f) => f.name.toLowerCase().contains(query)).map((f) => _Entry.folder(f)),
        ...source.where((p) => p.name.toLowerCase().contains(query)).map((p) => _Entry.project(p)),
      ];
    } else {
      entries = [
        ...allFolders.where((f) => f.parentFolderId == currentFolderId).map((f) => _Entry.folder(f)),
        ...source.where((p) => p.folderId == currentFolderId).map((p) => _Entry.project(p)),
      ];
    }
    if (showFavoritesOnly) {
      entries = entries.where((e) => e.isFavorite).toList();
    }
    final sorted = _sorted(entries);

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
            Text(l10n.projectListEmptyTitle,
                style: TextStyle(color: scheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(l10n.projectListEmptyHint,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
          ],
        ),
      );
    }

    if (viewMode == ProjectViewMode.detail) {
      return ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, index) => _detailTile(context, l10n, sorted[index]),
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

  Widget _detailTile(BuildContext context, AppLocalizations l10n, _Entry entry) {
    if (entry.isFolder) return _folderDetailTile(context, entry.folder!);
    final project = entry.project!;
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
      subtitle: Text(l10n.homeProjectMeta(project.fps, project.durationSeconds)),
      trailing: isSelectionMode
          ? null
          : _projectMenu(context, project),
      onTap: isSelectionMode
          ? () => onSelectionChanged(project.id)
          : () => context.push('/project/${project.id}'),
      onLongPress: onLongPress,
    );
  }

  Widget _folderDetailTile(BuildContext context, ProjectFolder folder) {
    final isSelected = selectedIds.contains(folder.id);
    final color = folder.color != null ? Color(folder.color!) : null;
    return ListTile(
      leading: isSelectionMode
          ? Checkbox(value: isSelected, onChanged: (_) => onSelectionChanged(folder.id))
          : Icon(Icons.folder, color: color, size: 32),
      title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (folder.isFavorite) const Icon(Icons.star, color: Colors.amber, size: 18),
          if (!isSelectionMode) _folderMenu(context, folder),
        ],
      ),
      onTap: isSelectionMode ? () => onSelectionChanged(folder.id) : () => onOpenFolder(folder.id),
      onLongPress: onLongPress,
    );
  }

  Widget _gridCard(BuildContext context, _Entry entry) {
    if (entry.isFolder) return _folderGridCard(context, entry.folder!);
    final project = entry.project!;
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

  Widget _folderGridCard(BuildContext context, ProjectFolder folder) {
    final isSelected = selectedIds.contains(folder.id);
    final primary = Theme.of(context).colorScheme.primary;
    final color = folder.color != null ? Color(folder.color!) : primary;
    return GestureDetector(
      onTap: isSelectionMode ? () => onSelectionChanged(folder.id) : () => onOpenFolder(folder.id),
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
                  Container(
                    color: color.withValues(alpha: 0.15),
                    child: Center(child: Icon(Icons.folder, color: color, size: 44)),
                  ),
                  if (folder.isFavorite)
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
              child: Text(folder.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectMenu(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) => _handleAction(context, action, project),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
        PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
        PopupMenuItem(value: 'duplicate', child: Text(l10n.themeDuplicateAction)),
        PopupMenuItem(value: 'share', child: Text(l10n.projectListCreateShareAction)),
        PopupMenuItem(
          value: 'favorite',
          child: Text(project.isFavorite ? l10n.colorPickerFavoriteRemove : l10n.homeFavoritesOnly),
        ),
        PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.projectDetailTrashMenuItem, style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _folderMenu(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) => _handleFolderAction(context, action, folder),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'open', child: Text(l10n.projectListOpenAction)),
        PopupMenuItem(value: 'edit', child: Text(l10n.projectListEditFolderAction)),
        PopupMenuItem(
          value: 'favorite',
          child: Text(folder.isFavorite ? l10n.colorPickerFavoriteRemove : l10n.homeFavoritesOnly),
        ),
        PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
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
        _createNiashare(context, project);
      case 'favorite':
        service.toggleFavorite(project.id);
      case 'move':
        _showMoveProjectToFolderDialog(context, project);
      case 'delete':
        _deleteProject(context, service, project);
    }
  }

  /// お気に入り登録中は削除できない。
  void _deleteProject(BuildContext context, ProjectService service, Project project) {
    if (project.isFavorite) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    service.deleteProject(project.id);
  }

  void _handleFolderAction(BuildContext context, String action, ProjectFolder folder) {
    final service = context.read<ProjectService>();
    switch (action) {
      case 'open':
        onOpenFolder(folder.id);
      case 'edit':
        _showEditFolderDialog(context, folder);
      case 'favorite':
        service.toggleFolderFavorite(folder.id);
      case 'move':
        _showMoveFolderToFolderDialog(context, folder);
      case 'delete':
        _confirmDeleteFolder(context, folder);
    }
  }

  /// フォルダ削除時、中のプロジェクト・子フォルダをルートへ戻す旨を確認する
  /// （仕様書19：「フォルダ削除時は中のプロジェクトをルートへ戻すか確認ダイアログを表示する」）。
  void _confirmDeleteFolder(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    // お気に入り登録中は削除できない。
    if (folder.isFavorite) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.projectListDeleteFolderConfirmTitle),
        content: Text(l10n.projectListDeleteFolderConfirmBody(folder.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<ProjectService>().deleteFolder(folder.id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  /// .niashare（共有用ファイル）を作成し、共有シートを表示する（仕様書06・21）。
  Future<void> _createNiashare(BuildContext context, Project project) async {
    final includeOptions = await showMaterialIncludeDialog(context);
    if (includeOptions == null || !context.mounted) return; // キャンセル
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<ProjectService>();
    final materialService = context.read<MaterialService>();
    final fontService = context.read<FontService>();
    final scenes = service.scenesOf(project.id);
    final tileManager = service.tileManagerOf(project.id);
    try {
      final bundle = await materialService.buildShareBundle(
          project.id, includeOptions.materialTypes);
      final fontBundle = includeOptions.includeFonts
          ? await buildFontShareBundle(service, fontService, project.id)
          : (files: <String, Uint8List>{}, manifest: null);
      final file = await NiaproSerializer.saveShare(
        project: project,
        scenes: scenes,
        tileManager: tileManager,
        materialFiles: bundle.files.isEmpty ? null : bundle.files,
        materialsManifest: bundle.manifest,
        fontFiles: fontBundle.files.isEmpty ? null : fontBundle.files,
        fontsManifest: fontBundle.manifest,
      );
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.projectDetailNiashareFailedSnackbar('$e'))),
      );
    }
  }

  void _showRenameDialog(BuildContext context, Project project) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: project.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>().renameProject(project.id, controller.text);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    );
  }

  void _showMoveProjectToFolderDialog(BuildContext context, Project project) {
    _showFolderPickerSheet(
      context,
      excludeFolderId: null,
      onSelect: (folderId) => context.read<ProjectService>().moveToFolder(project.id, folderId),
      onCreateAndSelect: (name) async {
        final service = context.read<ProjectService>();
        final folder = await service.createFolder(name);
        await service.moveToFolder(project.id, folder.id);
      },
    );
  }

  void _showMoveFolderToFolderDialog(BuildContext context, ProjectFolder folder) {
    _showFolderPickerSheet(
      context,
      // 自分自身の直下へは移動できない（循環防止はサービス側でも二重にガードする）
      excludeFolderId: folder.id,
      onSelect: (folderId) => context.read<ProjectService>().moveFolderTo(folder.id, folderId),
      onCreateAndSelect: (name) async {
        final service = context.read<ProjectService>();
        final newFolder = await service.createFolder(name);
        await service.moveFolderTo(folder.id, newFolder.id);
      },
    );
  }

  void _showFolderPickerSheet(
    BuildContext context, {
    required String? excludeFolderId,
    required ValueChanged<String?> onSelect,
    required Future<void> Function(String name) onCreateAndSelect,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final folders = context.read<ProjectService>().folders.where((f) => f.id != excludeFolderId).toList();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.folderMoveToTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(l10n.projectListFolderRootOption),
              onTap: () {
                onSelect(null);
                Navigator.pop(ctx);
              },
            ),
            ...folders.map((folder) => ListTile(
              leading: Icon(Icons.folder, color: folder.color != null ? Color(folder.color!) : null),
              title: Text(folder.name),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: l10n.projectListEditFolderTooltip,
                onPressed: () => _showEditFolderDialog(context, folder),
              ),
              onTap: () {
                onSelect(folder.id);
                Navigator.pop(ctx);
              },
            )),
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: Text(l10n.projectListCreateFolderAction),
              onTap: () {
                Navigator.pop(ctx);
                showCreateFolderNameDialog(context, onCreateAndSelect);
              },
            ),
          ],
        ),
      ),
    );
  }

  // フォルダ名変更・色変更・削除（仕様書02・19：フォルダ管理）
  static const _folderColors = [
    0xFFFF5C7A, 0xFFFFB020, 0xFFFFE066, 0xFF3DDC97,
    0xFF3AA6FF, 0xFFB15CFF, 0xFF9E9E9E,
  ];

  void _showEditFolderDialog(BuildContext context, ProjectFolder folder) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: folder.name);
    int? selectedColor = folder.color;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.projectListEditFolderTooltip),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.folderNameLabel, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Text(l10n.projectListFolderColorLabel, style: const TextStyle(fontSize: 12)),
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
                Navigator.pop(ctx);
                _confirmDeleteFolder(context, folder);
              },
              child: Text(l10n.commonDelete),
            ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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
              child: Text(l10n.commonSave),
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

/// .niashare作成時の同梱選択ダイアログ（仕様書06・15・21：画像/動画/音声を
/// 種類ごとに選択できる。デフォルトは全種類ON。「フォントを含める」を
/// 選択した場合のみユーザー追加フォントも同梱する）。キャンセル時はnullを返す。
Future<({Set<MaterialType> materialTypes, bool includeFonts})?> showMaterialIncludeDialog(
    BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final selected = <MaterialType>{MaterialType.image, MaterialType.video, MaterialType.audio};
  bool includeFonts = true;
  return showDialog<({Set<MaterialType> materialTypes, bool includeFonts})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(l10n.projectListMaterialIncludeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.projectListMaterialIncludeHint,
                style: const TextStyle(fontSize: 12)),
            CheckboxListTile(
              value: selected.contains(MaterialType.image),
              title: Text(l10n.projectListMaterialImage),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                  () => v == true ? selected.add(MaterialType.image) : selected.remove(MaterialType.image)),
            ),
            CheckboxListTile(
              value: selected.contains(MaterialType.video),
              title: Text(l10n.projectListMaterialVideo),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                  () => v == true ? selected.add(MaterialType.video) : selected.remove(MaterialType.video)),
            ),
            CheckboxListTile(
              value: selected.contains(MaterialType.audio),
              title: Text(l10n.projectListMaterialAudio),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(
                  () => v == true ? selected.add(MaterialType.audio) : selected.remove(MaterialType.audio)),
            ),
            const Divider(),
            CheckboxListTile(
              value: includeFonts,
              title: Text(l10n.projectListIncludeFontsTitle),
              subtitle: Text(l10n.projectListIncludeFontsSubtitle, style: const TextStyle(fontSize: 11)),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(() => includeFonts = v ?? true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (materialTypes: selected, includeFonts: includeFonts)),
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    ),
  );
}

/// プロジェクトで使用中のユーザー追加フォントをまとめ、.niashareへ同梱する
/// ためのファイル群とマニフェストを作成する（仕様書15：プロジェクト共有時の
/// 「フォントを含める」）。使用フォントがアプリ標準フォントのみの場合は空を返す。
Future<({Map<String, Uint8List> files, String? manifest})> buildFontShareBundle(
    ProjectService projectService, FontService fontService, String projectId) async {
  final usedFamilies = projectService.usedFontFamiliesOf(projectId);
  final files = <String, Uint8List>{};
  final manifestList = <Map<String, dynamic>>[];
  for (final font in fontService.fonts) {
    if (!usedFamilies.contains(fontService.familyNameOf(font))) continue;
    final bytes = await fontService.readFontBytes(font);
    if (bytes == null) continue;
    files[font.fileName] = bytes;
    manifestList.add({'id': font.id, 'displayName': font.displayName, 'fileName': font.fileName});
  }
  if (files.isEmpty) return (files: <String, Uint8List>{}, manifest: null);
  return (files: files, manifest: jsonEncode(manifestList));
}
