import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../engine/layer_compositor.dart';
import '../../engine/niapro_serializer.dart';
import '../../l10n/app_localizations.dart';
import '../../services/project_service.dart';
import '../../services/save_tree_service.dart';
import '../../models/save_node.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

/// セーブツリー（SaveTree/）の合計容量がこれを超えた場合にユーザーへ通知する
/// 閾値（仕様書23：「容量が大きくなる場合はユーザーへ通知」）。ツリー方式は
/// 各ノードが差分でなく完全なアーカイブとして保存され保存件数に比例して
/// 増え続けるため、スロット方式（件数上限あり）と異なり自然には頭打ちにならない。
const int _saveTreeSizeWarningThresholdBytes = 300 * 1024 * 1024; // 300MB

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
    final l10n = AppLocalizations.of(context)!;
    final saveService = context.watch<SaveTreeService>();
    final isTreeMode = saveService.isTreeMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTreeMode ? l10n.saveTreeScreenTitleTree : l10n.saveTreeScreenTitleSlot),
        actions: [
          const HelpButton(topic: 'セーブツリー'),
          if (isTreeMode)
            FilledButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: Text(l10n.commonSave),
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
    final l10n = AppLocalizations.of(context)!;
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonSave),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                parentId != null ? l10n.saveTreeSaveAsChildHint : l10n.saveTreeSaveAsRootHint,
                style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
            ),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: l10n.saveTreeCommentLabel,
                hintText: l10n.saveTreeCommentHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel)),
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
              await _warnIfSaveTreeSizeLarge(context, widget.projectId);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ).then((_) => commentController.dispose());
  }
}

/// セーブツリーの合計容量が閾値を超えている場合に通知する
/// （仕様書23：「容量が大きくなる場合はユーザーへ通知」）。
Future<void> _warnIfSaveTreeSizeLarge(BuildContext context, String projectId) async {
  final sizeBytes = await NiaproSerializer.saveTreeSizeBytes(projectId);
  if (sizeBytes < _saveTreeSizeWarningThresholdBytes) return;
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(0);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.saveTreeSizeWarningSnackbar(mb)),
      duration: const Duration(seconds: 5),
    ),
  );
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
    final l10n = AppLocalizations.of(context)!;
    final commentController =
        TextEditingController(text: existing?.comment ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveTreeSlotSaveDialogTitle(slotIndex + 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.saveTreeSlotOverwriteWarning(_formatDate(existing.savedAt)),
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                labelText: l10n.saveTreeCommentLabel,
                hintText: l10n.saveTreeCommentHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel)),
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
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ).then((_) => commentController.dispose());
  }

  Future<void> _restore(BuildContext context, SaveNode node) async {
    final l10n = AppLocalizations.of(context)!;
    final data = await saveService.loadNode(projectId, node.id);
    if (!context.mounted) return;
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)),
      );
      return;
    }
    context.read<ProjectService>().restoreFromAutosave(projectId, data);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(l10n.saveTreeRestoredSnackbar(
              node.comment ?? l10n.saveTreeSlotFallbackName(node.slotIndex + 1)))),
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
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: _SaveNodeThumbnail(node: node),
      title: Text('${l10n.saveTreeSlotLabel(slotIndex + 1)}${node?.comment != null ? '　${node!.comment}' : ''}'),
      subtitle: node != null
          ? Text(_formatDate(node!.savedAt))
          : Text(l10n.saveTreeNoDataLabel),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.save, size: 20),
            onPressed: onSave,
            tooltip: l10n.commonSave,
          ),
          if (onRestore != null)
            IconButton(
              icon: const Icon(Icons.restore, size: 20),
              onPressed: onRestore,
              tooltip: l10n.saveTreeRestoreAction,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: onDelete,
              tooltip: l10n.commonDelete,
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
    final l10n = AppLocalizations.of(context)!;
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
            Text(l10n.saveTreeEmptyTitle,
                style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text(l10n.saveTreeEmptyHint,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    // 画面下から上へ伸びる木のような見た目にする（ユーザー指示）。
    // フラット化した行リストをDFS順（root→子→孫…）で構築し、reverse:trueで
    // 表示することで、rootが画面最下部・深い子孫ほど上に積み上がる形になる。
    // 各行には祖先の分岐が下（reverse後は下方向）へ続くかを示す接続線を
    // 添える（一般的なツリーコマンドの罫線と同じアルゴリズム）。
    final rows = <Widget>[];
    for (int i = 0; i < roots.length; i++) {
      _flattenTreeRows(context, l10n, roots, i, 0, const [], rows);
    }
    return ListView(reverse: true, children: rows);
  }

  void _flattenTreeRows(
    BuildContext context,
    AppLocalizations l10n,
    List<SaveNode> siblings,
    int index,
    int depth,
    List<bool> ancestorContinues,
    List<Widget> out,
  ) {
    final node = siblings[index];
    final hasNext = index < siblings.length - 1;
    final continues = [...ancestorContinues, hasNext];
    out.add(_buildTreeRow(context, l10n, node, depth, continues));
    final children = saveService.getChildren(projectId, node.id);
    for (int i = 0; i < children.length; i++) {
      _flattenTreeRows(context, l10n, children, i, depth + 1, continues, out);
    }
  }

  Widget _buildTreeRow(
    BuildContext context,
    AppLocalizations l10n,
    SaveNode node,
    int depth,
    List<bool> continues,
  ) {
    final isSelected = selectedNodeId == node.id;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (depth > 0)
          SizedBox(
            width: depth * 20.0,
            child: CustomPaint(
              painter: _TreeConnectorPainter(
                continues: continues,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        Expanded(
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
            title: Text(node.comment ?? l10n.saveTreeNodeDefaultTitle),
            subtitle: Text(_formatDate(node.savedAt)),
            onTap: () => onNodeSelected(isSelected ? null : node.id),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleAction(context, action, node),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'restore', child: Text(l10n.saveTreeRestoreAction)),
                PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
      BuildContext context, String action, SaveNode node) async {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case 'restore':
        final data = await saveService.loadNode(projectId, node.id);
        if (!context.mounted) return;
        if (data == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.saveTreeLoadFailedSnackbar)),
          );
          return;
        }
        context.read<ProjectService>().restoreFromAutosave(projectId, data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveTreeRestoredSnackbar(node.comment ?? l10n.saveTreeNodeDefaultName))),
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

/// セーブツリーの分岐線を描画する（一般的なツリー表示コマンドと同じ
/// アルゴリズム）。[continues]は自身を含む各祖先深さでの「まだ次の兄弟が
/// 続くか」を表すリスト（末尾＝自分自身）。ListViewをreverse:trueで
/// 表示しているため、「続く」方向は画面上では上向きになる（木が下から
/// 上へ伸びる見た目、ユーザー指示）。
class _TreeConnectorPainter extends CustomPainter {
  final List<bool> continues;
  final Color color;

  _TreeConnectorPainter({required this.continues, required this.color});

  static const double _colW = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    // 祖先列（自分より浅い深さ）：まだ枝分かれが続く列のみ全高の縦線を引く
    for (int i = 0; i < continues.length - 1; i++) {
      if (!continues[i]) continue;
      final x = _colW * i + _colW / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // 自分の列：上半分は常に線（親側との接続）、下半分は自分に続く兄弟が
    // いる場合のみ延長する。あわせて右側のタイルへ向かう横線を引く。
    final selfX = _colW * (continues.length - 1) + _colW / 2;
    canvas.drawLine(Offset(selfX, 0), Offset(selfX, size.height / 2), paint);
    if (continues.last) {
      canvas.drawLine(Offset(selfX, size.height / 2), Offset(selfX, size.height), paint);
    }
    canvas.drawLine(Offset(selfX, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant _TreeConnectorPainter oldDelegate) =>
      oldDelegate.continues != continues || oldDelegate.color != color;
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
    final l10n = AppLocalizations.of(context)!;
    final nodes = widget.saveService.getNodes(widget.projectId);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName == null
            ? l10n.saveTreeChangeDataTitle
            : l10n.saveTreeChangeDataTitleWithProject(widget.projectName!)),
        leading: _showSelectionList
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showSelectionList = false),
              )
            : null,
      ),
      body: _showSelectionList
          ? _buildSelectionBody(context, l10n, nodes)
          : _buildButtonBody(context, l10n, nodes),
    );
  }

  Widget _buildButtonBody(BuildContext context, AppLocalizations l10n, List<SaveNode> nodes) {
    return desktopCentered(
      context,
      Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.saveTreeChangeExceedMessage,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(l10n.saveTreeKeepableCountLabel(_limit),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              _autoSelectLatest(nodes);
              _showDiscardDialog(context, nodes);
            },
            child: Text(l10n.saveTreeKeepLatestButton(_limit)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _showSelectionList = true),
            child: Text(l10n.saveTreeSelectDataButton),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSelectionBody(BuildContext context, AppLocalizations l10n, List<SaveNode> nodes) {
    final limitReached = _selectedIds.length >= _limit;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.saveTreeSelectedCountLabel(_selectedIds.length, _limit),
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
                  child: Text(l10n.saveTreeBackButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedIds.length >= _effectiveLimit(nodes.length)
                      ? () => _showDiscardDialog(context, nodes)
                      : null,
                  child: Text(l10n.saveTreeNextButton),
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
    final l10n = AppLocalizations.of(context)!;
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
            node.comment ?? l10n.saveTreeSlotFallbackName(slotIndex + 1),
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
    final l10n = AppLocalizations.of(context)!;
    final roots = nodes.where((n) => n.parentId == null).toList();
    if (roots.isEmpty) {
      return Center(child: Text(l10n.saveTreeEmptyTitle));
    }
    return ListView(
      children:
          roots.map((root) => _buildNode(context, l10n, root, 0)).toList(),
    );
  }

  Widget _buildNode(BuildContext context, AppLocalizations l10n, SaveNode node, int depth) {
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
              node.comment ?? l10n.saveTreeNodeDefaultTitle,
              style: TextStyle(color: isDisabled ? Theme.of(context).colorScheme.onSurfaceVariant : null),
            ),
            subtitle: Text(_formatDate(node.savedAt)),
            onTap: isDisabled ? null : () => onToggle(node.id),
          ),
        ),
        ...children.map((child) => _buildNode(context, l10n, child, depth + 1)),
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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.saveTreeDiscardDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<bool>(
            value: true,
            groupValue: _archive,
            onChanged: (v) => setState(() => _archive = v!),
            title: Text(l10n.saveTreeArchiveOptionTitle),
            subtitle: Text(
              l10n.saveTreeArchiveOptionSubtitle,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          RadioListTile<bool>(
            value: false,
            groupValue: _archive,
            onChanged: (v) => setState(() => _archive = v!),
            title: Text(l10n.saveTreeDeleteOptionTitle),
            subtitle: Text(
              l10n.saveTreeDeleteOptionSubtitle(widget.discardCount),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onBack, child: Text(l10n.saveTreeBackButton)),
        FilledButton(
          onPressed: () => widget.onConfirm(_archive),
          child: Text(l10n.saveTreeApplyChangeButton),
        ),
      ],
    );
  }
}
