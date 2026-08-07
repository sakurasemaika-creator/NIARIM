import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../engine/layer_compositor.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../models/save_node.dart';
import '../../widgets/responsive.dart';

/// 保存ノードのサムネイルを生成する（先頭シーン・先頭フレームを縮小合成）。
/// 生成できない場合（シーン・フレームが存在しない等）はnullを返す。
Future<Uint8List?> _generateSaveNodeThumbnail(
    ProjectService ps, String projectId) async {
  final scenes = ps.scenesOf(projectId);
  if (scenes.isEmpty) return null;
  final scene = scenes.first;
  if (scene.frames.isEmpty) return null;
  final frame = scene.frames.first;
  final tileManager = ps.tileManagerOf(projectId);
  final w = tileManager.canvasWidth;
  final h = tileManager.canvasHeight;
  if (w <= 0 || h <= 0) return null;

  const thumbMax = 200;
  final scale = thumbMax / math.max(w, h);
  final tw = (w * scale).round().clamp(1, thumbMax);
  final th = (h * scale).round().clamp(1, thumbMax);

  final fullImage = await LayerCompositor.composite(
    tileManager,
    ps.layersOf(projectId, scene.id, frame.index),
    (l) => ps.tileKeyFor(projectId, scene.id, frame.index, l.id),
    w,
    h,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    fullImage,
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
    ui.Paint(),
  );
  fullImage.dispose();
  final picture = recorder.endRecording();
  final thumbImage = await picture.toImage(tw, th);
  final byteData = await thumbImage.toByteData(format: ui.ImageByteFormat.png);
  thumbImage.dispose();
  return byteData?.buffer.asUint8List();
}

class SaveTreeScreen extends StatefulWidget {
  final String projectId;
  const SaveTreeScreen({super.key, required this.projectId});

  @override
  State<SaveTreeScreen> createState() => _SaveTreeScreenState();
}

class _SaveTreeScreenState extends State<SaveTreeScreen> {
  String? _selectedNodeId;

  @override
  Widget build(BuildContext context) {
    final saveService = context.watch<SaveTreeService>();
    final isTreeMode = saveService.isTreeMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTreeMode ? 'セーブ（ツリー方式）' : 'セーブ（スロット方式）'),
        actions: [
          if (isTreeMode)
            FilledButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('保存'),
              onPressed: () =>
                  _showTreeSaveDialog(context, saveService, _selectedNodeId),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: isTreeMode
          ? _TreeView(
              projectId: widget.projectId,
              nodes: saveService.getNodes(widget.projectId),
              saveService: saveService,
              selectedNodeId: _selectedNodeId,
              onNodeSelected: (id) => setState(() => _selectedNodeId = id),
            )
          : desktopCentered(
              context,
              _SlotView(
                projectId: widget.projectId,
                saveService: saveService,
              ),
            ),
    );
  }

  void _showTreeSaveDialog(
      BuildContext context, SaveTreeService service, String? parentId) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                parentId != null ? '選択中のノードの子として保存します。' : 'ルートノードとして保存します。',
                style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
            ),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'コメント（任意）',
                hintText: '例：背景完成',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final ps = context.read<ProjectService>();
              final project =
                  ps.projects.where((p) => p.id == widget.projectId).firstOrNull;
              if (project == null) {
                Navigator.pop(ctx);
                return;
              }
              final thumb = await _generateSaveNodeThumbnail(ps, widget.projectId);
              await service.saveAsChild(
                projectId: widget.projectId,
                project: project,
                scenes: ps.scenesOf(widget.projectId),
                tileManager: ps.tileManagerOf(widget.projectId),
                parentId: parentId,
                comment: commentController.text.isEmpty
                    ? null
                    : commentController.text,
                thumbnailPngBytes: thumb,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).then((_) => commentController.dispose());
  }
}

// ─────────────────────────────────────────────
// スロット方式ビュー
// ─────────────────────────────────────────────
class _SlotView extends StatelessWidget {
  final String projectId;
  final SaveTreeService saveService;

  const _SlotView({required this.projectId, required this.saveService});

  @override
  Widget build(BuildContext context) {
    final nodes = saveService.getNodes(projectId);
    return ListView.builder(
      itemCount: saveService.slotMax,
      itemBuilder: (context, slotIndex) {
        final node = nodes.cast<SaveNode?>().firstWhere(
              (n) => n!.slotIndex == slotIndex,
              orElse: () => null,
            );
        return _SlotTile(
          slotIndex: slotIndex,
          node: node,
          onSave: () => _showSlotSaveDialog(context, slotIndex, node),
          onRestore: node != null ? () => _restore(context, node) : null,
          onDelete: node != null
              ? () => saveService.deleteNode(projectId, node.id)
              : null,
        );
      },
    );
  }

  void _showSlotSaveDialog(
      BuildContext context, int slotIndex, SaveNode? existing) {
    final commentController =
        TextEditingController(text: existing?.comment ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('スロット ${slotIndex + 1} に保存'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '既存データ（${_formatDate(existing.savedAt)}）を上書きします。',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'コメント（任意）',
                hintText: '例：背景完成',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final ps = context.read<ProjectService>();
              final project =
                  ps.projects.where((p) => p.id == projectId).firstOrNull;
              if (project == null) {
                Navigator.pop(ctx);
                return;
              }
              final thumb = await _generateSaveNodeThumbnail(ps, projectId);
              await saveService.saveToSlot(
                projectId: projectId,
                slotIndex: slotIndex,
                project: project,
                scenes: ps.scenesOf(projectId),
                tileManager: ps.tileManagerOf(projectId),
                comment: commentController.text.isEmpty
                    ? null
                    : commentController.text,
                thumbnailPngBytes: thumb,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).then((_) => commentController.dispose());
  }

  Future<void> _restore(BuildContext context, SaveNode node) async {
    final data = await saveService.loadNode(projectId, node.id);
    if (!context.mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存データの読み込みに失敗しました')),
      );
      return;
    }
    context.read<ProjectService>().restoreFromAutosave(projectId, data);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${node.comment ?? 'スロット ${node.slotIndex + 1}'}を復元しました')),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// セーブノードのサムネイル画像。thumbnailPathが無い・読み込めない場合は
/// プレースホルダーアイコンを表示する。
class _SaveNodeThumbnail extends StatelessWidget {
  final SaveNode? node;
  final double size;

  const _SaveNodeThumbnail({required this.node, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final path = node?.thumbnailPath;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: path != null
          ? Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholderIcon(context),
            )
          : _placeholderIcon(context),
    );
  }

  Widget _placeholderIcon(BuildContext context) => Center(
        child: Icon(
          node != null ? Icons.image : Icons.add,
          size: size / 2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

class _SlotTile extends StatelessWidget {
  final int slotIndex;
  final SaveNode? node;
  final VoidCallback onSave;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  const _SlotTile({
    required this.slotIndex,
    required this.node,
    required this.onSave,
    this.onRestore,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _SaveNodeThumbnail(node: node),
      title: Text('スロット${slotIndex + 1}${node?.comment != null ? '　${node!.comment}' : ''}'),
      subtitle: node != null
          ? Text(_formatDate(node!.savedAt))
          : const Text('保存データなし'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.save, size: 20),
            onPressed: onSave,
            tooltip: '保存',
          ),
          if (onRestore != null)
            IconButton(
              icon: const Icon(Icons.restore, size: 20),
              onPressed: onRestore,
              tooltip: '復元',
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: onDelete,
              tooltip: '削除',
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────
// ツリー方式ビュー
// ─────────────────────────────────────────────
class _TreeView extends StatelessWidget {
  final String projectId;
  final List<SaveNode> nodes;
  final SaveTreeService saveService;
  final String? selectedNodeId;
  final ValueChanged<String?> onNodeSelected;

  const _TreeView({
    required this.projectId,
    required this.nodes,
    required this.saveService,
    required this.selectedNodeId,
    required this.onNodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final roots = nodes.where((n) => n.parentId == null).toList();
    if (roots.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.account_tree_outlined, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text('保存データがありません',
                style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text('上部の「保存」ボタンで最初のノードを作成できます',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView(
      children: roots.map((root) => _buildTreeNode(context, root, 0)).toList(),
    );
  }

  Widget _buildTreeNode(BuildContext context, SaveNode node, int depth) {
    final children = saveService.getChildren(projectId, node.id);
    final isSelected = selectedNodeId == node.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 24.0),
          child: ListTile(
            selected: isSelected,
            selectedTileColor: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3),
            leading: node.thumbnailPath != null
                ? _SaveNodeThumbnail(node: node, size: 40)
                : Icon(
                    Icons.commit,
                    size: 20,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
            title: Text(node.comment ?? '保存'),
            subtitle: Text(_formatDate(node.savedAt)),
            onTap: () => onNodeSelected(isSelected ? null : node.id),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, action, node),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'restore', child: Text('復元')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('削除', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ),
        ...children.map((child) => _buildTreeNode(context, child, depth + 1)),
      ],
    );
  }

  Future<void> _handleAction(
      BuildContext context, String action, SaveNode node) async {
    switch (action) {
      case 'restore':
        final data = await saveService.loadNode(projectId, node.id);
        if (!context.mounted) return;
        if (data == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存データの読み込みに失敗しました')),
          );
          return;
        }
        context.read<ProjectService>().restoreFromAutosave(projectId, data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${node.comment ?? '保存データ'}を復元しました')),
        );
        break;
      case 'delete':
        await saveService.deleteNode(projectId, node.id);
        break;
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────
// 保存データ変更画面（保存方式変更・スロット数削減時に表示）
// ─────────────────────────────────────────────

/// 保存方式変更が必要かどうかを判定し、必要なら変更フローを開始する
/// 設定画面からは呼ばない。SaveTreeScreenから呼ぶ。
/// [newIsTreeMode] 変更後のモード
/// [newSlotMax] スロット方式の場合の新スロット数（ツリー方式ならnull）
Future<void> showSaveModeChangeFlowIfNeeded({
  required BuildContext context,
  required String projectId,
  required SaveTreeService saveService,
  required bool newIsTreeMode,
  int? newSlotMax,
  // 設定画面から複数プロジェクトへ順番に適用する場合、どのプロジェクトの
  // 変更画面かを示すために使う（仕様書23）。単一プロジェクト文脈からの
  // 呼び出しでは省略可能。
  String? projectName,
}) async {
  final nodes = saveService.getNodes(projectId);
  final currentIsTree = saveService.isTreeMode;

  // 同じモード内でスロット数増加のみ→即時適用して終了
  if (!currentIsTree && !newIsTreeMode) {
    final nextMax = newSlotMax ?? saveService.slotMax;
    if (nextMax >= saveService.slotMax) {
      saveService.setSlotMax(nextMax);
      return;
    }
  }

  // ツリー方式への変更は保存数無制限なので変更画面不要。
  // スロット→ツリーの場合はアーカイブを復元する。
  // ツリー→ツリー（変更なし）の場合は復元しない。
  if (newIsTreeMode) {
    if (!currentIsTree) {
      saveService.restoreArchive(projectId);
    }
    saveService.setTreeMode(true);
    return;
  }

  // スロット方式への変更（ツリー→スロット、またはスロット数削減）
  final limit = newSlotMax ?? saveService.slotMax;
  final needsSelection = nodes.length > limit;

  if (!needsSelection) {
    saveService.setSlotMax(limit);
    saveService.setTreeMode(false);
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _SaveModeChangeScreen(
      projectId: projectId,
      saveService: saveService,
      newIsTreeMode: false,
      newSlotMax: limit,
      projectName: projectName,
    ),
  ));
}

class _SaveModeChangeScreen extends StatefulWidget {
  final String projectId;
  final SaveTreeService saveService;
  final bool newIsTreeMode;
  final int? newSlotMax;
  final String? projectName;

  const _SaveModeChangeScreen({
    required this.projectId,
    required this.saveService,
    required this.newIsTreeMode,
    required this.newSlotMax,
    this.projectName,
  });

  @override
  State<_SaveModeChangeScreen> createState() => _SaveModeChangeScreenState();
}

class _SaveModeChangeScreenState extends State<_SaveModeChangeScreen> {
  final Set<String> _selectedIds = {};
  bool _showSelectionList = false;
  late final bool _initialIsTreeMode;
  int get _limit => widget.newSlotMax ?? widget.saveService.getNodes(widget.projectId).length;
  int _effectiveLimit(int nodeCount) => nodeCount < _limit ? nodeCount : _limit;

  @override
  void initState() {
    super.initState();
    _initialIsTreeMode = widget.saveService.isTreeMode;
  }

  @override
  Widget build(BuildContext context) {
    final nodes = widget.saveService.getNodes(widget.projectId);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName == null ? '保存データ変更' : '保存データ変更（${widget.projectName}）'),
        leading: _showSelectionList
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showSelectionList = false),
              )
            : null,
      ),
      body: _showSelectionList
          ? _buildSelectionBody(context, nodes)
          : _buildButtonBody(context, nodes),
    );
  }

  Widget _buildButtonBody(BuildContext context, List<SaveNode> nodes) {
    return desktopCentered(
      context,
      Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '現在の保存データ数が\n新しい保存可能数を超えています。\n\n保持する保存データを選択してください。',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text('保持できる保存数：$_limit件',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              _autoSelectLatest(nodes);
              _showDiscardDialog(context, nodes);
            },
            child: Text('最新$_limit件を保存'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _showSelectionList = true),
            child: const Text('保存データを選択'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSelectionBody(BuildContext context, List<SaveNode> nodes) {
    final limitReached = _selectedIds.length >= _limit;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '選択中：${_selectedIds.length} / $_limit件',
            style: TextStyle(
              fontSize: 12,
              color: limitReached ? Colors.orange : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: _initialIsTreeMode
              ? _SelectableTreeView(
                  projectId: widget.projectId,
                  nodes: nodes,
                  saveService: widget.saveService,
                  selectedIds: _selectedIds,
                  limitReached: limitReached,
                  onToggle: _toggleNode,
                )
              : _SelectableSlotView(
                  nodes: nodes,
                  slotMax: widget.saveService.slotMax,
                  selectedIds: _selectedIds,
                  limitReached: limitReached,
                  onToggle: _toggleNode,
                ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showSelectionList = false),
                  child: const Text('戻る'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedIds.length >= _effectiveLimit(nodes.length)
                      ? () => _showDiscardDialog(context, nodes)
                      : null,
                  child: const Text('次へ'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleNode(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < _limit) {
        _selectedIds.add(id);
      }
    });
  }

  void _autoSelectLatest(List<SaveNode> nodes) {
    final sorted = [...nodes]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(sorted.take(_limit).map((n) => n.id));
    });
  }

  void _showDiscardDialog(BuildContext context, List<SaveNode> nodes) {
    final discardCount = nodes.length - _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => _DiscardChoiceDialog(
        discardCount: discardCount,
        onConfirm: (archive) {
          widget.saveService.applyModeChange(
            projectId: widget.projectId,
            keepIds: _selectedIds.toList(),
            archive: archive,
            newIsTreeMode: widget.newIsTreeMode,
            newSlotMax: widget.newSlotMax,
          );
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
        onBack: () => Navigator.pop(ctx),
      ),
    );
  }
}

// ─── 選択可能スロットビュー ───
class _SelectableSlotView extends StatelessWidget {
  final List<SaveNode> nodes;
  final int slotMax;
  final Set<String> selectedIds;
  final bool limitReached;
  final ValueChanged<String> onToggle;

  const _SelectableSlotView({
    required this.nodes,
    required this.slotMax,
    required this.selectedIds,
    required this.limitReached,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: slotMax,
      itemBuilder: (context, slotIndex) {
        final node = nodes.cast<SaveNode?>().firstWhere(
              (n) => n!.slotIndex == slotIndex,
              orElse: () => null,
            );
        if (node == null) return const SizedBox.shrink();
        final isSelected = selectedIds.contains(node.id);
        final isDisabled = limitReached && !isSelected;
        return ListTile(
          enabled: !isDisabled,
          leading: Checkbox(
            value: isSelected,
            onChanged: isDisabled ? null : (_) => onToggle(node.id),
          ),
          title: Text(
            node.comment ?? 'スロット ${slotIndex + 1}',
            style: TextStyle(color: isDisabled ? Theme.of(context).colorScheme.onSurfaceVariant : null),
          ),
          subtitle: Text(_formatDate(node.savedAt)),
          onTap: isDisabled ? null : () => onToggle(node.id),
        );
      },
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─── 選択可能ツリービュー ───
class _SelectableTreeView extends StatelessWidget {
  final String projectId;
  final List<SaveNode> nodes;
  final SaveTreeService saveService;
  final Set<String> selectedIds;
  final bool limitReached;
  final ValueChanged<String> onToggle;

  const _SelectableTreeView({
    required this.projectId,
    required this.nodes,
    required this.saveService,
    required this.selectedIds,
    required this.limitReached,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final roots = nodes.where((n) => n.parentId == null).toList();
    if (roots.isEmpty) {
      return const Center(child: Text('保存データがありません'));
    }
    return ListView(
      children:
          roots.map((root) => _buildNode(context, root, 0)).toList(),
    );
  }

  Widget _buildNode(BuildContext context, SaveNode node, int depth) {
    final children = saveService.getChildren(projectId, node.id);
    final isSelected = selectedIds.contains(node.id);
    final isDisabled = limitReached && !isSelected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 24.0),
          child: ListTile(
            enabled: !isDisabled,
            leading: Checkbox(
              value: isSelected,
              onChanged: isDisabled ? null : (_) => onToggle(node.id),
            ),
            title: Text(
              node.comment ?? '保存',
              style: TextStyle(color: isDisabled ? Theme.of(context).colorScheme.onSurfaceVariant : null),
            ),
            subtitle: Text(_formatDate(node.savedAt)),
            onTap: isDisabled ? null : () => onToggle(node.id),
          ),
        ),
        ...children.map((child) => _buildNode(context, child, depth + 1)),
      ],
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─── 未選択データの処理選択ダイアログ ───
class _DiscardChoiceDialog extends StatefulWidget {
  final int discardCount;
  final ValueChanged<bool> onConfirm; // true=アーカイブ、false=削除
  final VoidCallback onBack;

  const _DiscardChoiceDialog({
    required this.discardCount,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  State<_DiscardChoiceDialog> createState() => _DiscardChoiceDialogState();
}

class _DiscardChoiceDialogState extends State<_DiscardChoiceDialog> {
  bool _archive = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('選択されなかった保存データ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<bool>(
            value: true,
            groupValue: _archive,
            onChanged: (v) => setState(() => _archive = v!),
            title: const Text('アーカイブとして保持する（推奨）'),
            subtitle: const Text(
              'セーブツリー方式へ戻したときに自動で復元されます。\nストレージ容量を使用します。',
              style: TextStyle(fontSize: 11),
            ),
          ),
          RadioListTile<bool>(
            value: false,
            groupValue: _archive,
            onChanged: (v) => setState(() => _archive = v!),
            title: const Text('完全に削除する'),
            subtitle: Text(
              '選択されなかった${widget.discardCount}件を完全に削除します。\nストレージ容量を節約できます。\n※削除したデータは元に戻せません。',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onBack, child: const Text('戻る')),
        FilledButton(
          onPressed: () => widget.onConfirm(_archive),
          child: const Text('変更する'),
        ),
      ],
    );
  }
}
