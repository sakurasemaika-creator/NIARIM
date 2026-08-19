import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../engine/layer_compositor.dart';
import '../../engine/niapro_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/project.dart';
import '../../services/font_service.dart';
import '../../services/material_service.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../widgets/autofill_preset_selection_sheet.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../home/widgets/project_list_widget.dart'
    show showMaterialIncludeDialog, buildFontShareBundle;

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
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final project = projectService.projects.where((p) => p.id == widget.projectId).firstOrNull;

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.projectDetailNotFoundTitle)),
        body: Center(child: Text(l10n.projectDetailNotFoundBody)),
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
          const HelpButton(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case 'rename': _showRenameDialog(context, project.name);
                case 'duplicate': projectService.duplicateProject(widget.projectId);
                case 'move': _showMoveToFolderDialog(context, projectService);
                case 'materials': context.push('/materials/${widget.projectId}');
                case 'delete':
                  // お気に入り登録中は削除できない。
                  if (project.isFavorite) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
                  } else {
                    projectService.deleteProject(widget.projectId);
                    context.pop();
                  }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
              PopupMenuItem(value: 'duplicate', child: Text(l10n.themeDuplicateAction)),
              PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
              PopupMenuItem(value: 'materials', child: Text(l10n.materialListTitle)),
              PopupMenuItem(value: 'delete', child: Text(l10n.projectDetailTrashMenuItem, style: const TextStyle(color: Colors.red))),
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
                    tooltip: l10n.projectDetailFirstFrameTooltip,
                  ),
                  IconButton(
                    onPressed: flat.isEmpty ? null : () => _seekTo(projectService, flat, _frameIndex - 1),
                    icon: const Icon(Icons.fast_rewind),
                    tooltip: l10n.projectDetailPrevFrameTooltip,
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
                      tooltip: _isPlaying ? l10n.projectDetailPauseTooltip : l10n.projectDetailPlayTooltip,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: flat.isEmpty ? null : () => _seekTo(projectService, flat, _frameIndex + 1),
                    icon: const Icon(Icons.fast_forward),
                    tooltip: l10n.projectDetailNextFrameTooltip,
                  ),
                  IconButton(
                    onPressed: flat.isEmpty ? null : () => _seekTo(projectService, flat, flat.length - 1),
                    icon: const Icon(Icons.skip_next),
                    tooltip: l10n.projectDetailLastFrameTooltip,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/canvas/${widget.projectId}'),
              icon: const Icon(Icons.edit),
              label: Text(l10n.projectDetailStartEditButton),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            const SizedBox(height: 16),
            // フォルダ・タグ・お気に入り・共有のクイックアクセス（仕様書19の詳細画面モックアップ）
            Row(
              children: [
                Expanded(
                  child: _quickAction(
                    icon: Icons.folder_outlined,
                    label: l10n.creativePanelFolderButton,
                    onTap: () => _showMoveToFolderDialog(context, projectService),
                  ),
                ),
                Expanded(
                  child: _quickAction(
                    icon: Icons.sell_outlined,
                    label: l10n.projectDetailTagsQuickAction,
                    onTap: () => _showTagsDialog(context, projectService, project),
                  ),
                ),
                Expanded(
                  child: _quickAction(
                    icon: project.isFavorite ? Icons.star : Icons.star_border,
                    label: l10n.homeFavoritesOnly,
                    iconColor: project.isFavorite ? Colors.amber : null,
                    onTap: () => projectService.toggleFavorite(widget.projectId),
                  ),
                ),
                Expanded(
                  child: _quickAction(
                    icon: Icons.ios_share,
                    label: l10n.projectDetailShareQuickAction,
                    onTap: () => _createNiashare(context, projectService, project),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(l10n.projectDetailInfoSectionTitle,
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
                    _infoRow(l10n.projectDetailInfoExportSize, '${project.exportWidth}×${project.exportHeight}'),
                    if (project.hasExtendedDrawingArea)
                      _infoRow(l10n.projectDetailInfoDrawingArea, l10n.projectDetailInfoDrawingAreaValue(
                          '${project.drawingWidth}×${project.drawingHeight}',
                          l10n.newProjectScaleValue(project.drawingAreaScale.toStringAsFixed(1)))),
                    _infoRow(l10n.projectDetailInfoTotalFrames, '${project.totalFrames}'),
                    _infoRow(l10n.projectDetailInfoWorkTime, l10n.newProjectDurationHm(
                        project.totalWorkSeconds ~/ 3600, (project.totalWorkSeconds % 3600) ~/ 60)),
                    _infoRow(l10n.projectDetailInfoLastSaved, _formatDateTime(project.updatedAt)),
                    _infoRow(l10n.projectDetailInfoSize, _formatSize(project.sizeBytes)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ボタンの文言は、パフォーマンス設定で選んでいるセーブ方式
            // （セーブツリー／セーブスロット）に合わせて切り替える。押した先の
            // 画面（SaveTreeScreen）のタイトルと表示内容が一致しない
            // （「セーブツリー」ボタンなのにスロット画面が開く）不具合の対策。
            Builder(builder: (context) {
              final isTreeMode = context.watch<SaveTreeService>().isTreeMode;
              return OutlinedButton.icon(
                onPressed: () => context.push('/save-tree/${widget.projectId}'),
                icon: Icon(isTreeMode ? Icons.account_tree : Icons.save_outlined),
                label: Text(isTreeMode ? l10n.saveTreeScreenTitleTree : l10n.saveTreeScreenTitleSlot),
              );
            }),
            const SizedBox(height: 8),
            // このプロジェクトで使う自動塗りプリセットの選択。
            // プリセットは増えていくため、プロジェクト設定内でも選び直せる
            // ようにする。
            OutlinedButton.icon(
              onPressed: () => _showPresetSelection(context, projectService, project),
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: Text(project.enabledAutofillPresetIds == null
                  ? l10n.autofillPresetSelectionButton
                  : l10n.autofillPresetSelectionCountLabel(project.enabledAutofillPresetIds!.length)),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _showPresetSelection(
      BuildContext context, ProjectService projectService, Project project) async {
    final allPresets = context.read<AutofillPresetService>().presets;
    final result = await showAutofillPresetSelectionSheet(
      context,
      allPresets: allPresets,
      initiallyEnabledIds: project.enabledAutofillPresetIds?.toSet(),
    );
    if (result.cancelled) return;
    await projectService.setEnabledAutofillPresetIds(widget.projectId, result.ids);
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showMoveToFolderDialog(BuildContext context, ProjectService service) {
    final l10n = AppLocalizations.of(context)!;
    final folders = service.folders;
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
              title: Text(l10n.folderNone),
              onTap: () {
                service.moveToFolder(widget.projectId, null);
                Navigator.pop(ctx);
              },
            ),
            ...folders.map((folder) => ListTile(
                  leading: Icon(Icons.folder, color: folder.color != null ? Color(folder.color!) : null),
                  title: Text(folder.name),
                  onTap: () {
                    service.moveToFolder(widget.projectId, folder.id);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showTagsDialog(BuildContext context, ProjectService service, Project project) {
    final l10n = AppLocalizations.of(context)!;
    final tags = List<String>.from(project.tags);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.projectDetailTagsQuickAction),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            onDeleted: () => setDialogState(() => tags.remove(tag)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.projectDetailAddTagHint,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    final t = value.trim();
                    if (t.isNotEmpty && !tags.contains(t)) {
                      setDialogState(() => tags.add(t));
                    }
                    controller.clear();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                service.setProjectTags(widget.projectId, tags);
                Navigator.pop(ctx);
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  /// .niashare（共有用ファイル）を作成し、共有シートを表示する（仕様書06・19・21）。
  Future<void> _createNiashare(BuildContext context, ProjectService service, Project project) async {
    final includeOptions = await showMaterialIncludeDialog(context);
    if (includeOptions == null || !context.mounted) return; // キャンセル
    final l10n = AppLocalizations.of(context)!;
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

  String _formatDateTime(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  void _showRenameDialog(BuildContext context, String currentName) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonRename),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              context.read<ProjectService>().renameProject(widget.projectId, controller.text);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}
