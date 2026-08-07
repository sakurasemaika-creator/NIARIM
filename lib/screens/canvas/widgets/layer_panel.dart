import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../engine/autofill_engine.dart' as autofill;
import '../../../engine/tile_manager.dart' show frameLayerKey;
import '../../../models/layer.dart' as model;
import '../../../services/autofill_preset_service.dart';
import '../../../services/project_service.dart';

class LayerPanel extends StatefulWidget {
  final VoidCallback onClose;
  final String projectId;
  final String sceneId;
  final int frameIndex;
  // PC/DeXモードの常時ドッキング表示時はtrue。閉じるボタンを非表示にする。
  final bool dockedMode;
  // テキストレイヤーをタップした時の編集入口（仕様書15：既存テキストを
  // タップすると編集開始）。nullの場合はテキストレイヤーも通常選択のみ行う。
  final void Function(model.Layer layer)? onEditTextLayer;

  const LayerPanel({
    super.key,
    required this.onClose,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    this.dockedMode = false,
    this.onEditTextLayer,
  });

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  int _selectedIndex = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  model.LayerType? _selectionBaseType;
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<model.Layer> _visibleLayers(List<model.Layer> layers) {
    final base = layers.where((l) => l.type != model.LayerType.selection).toList();
    final visible = base.where((l) => !_isHiddenByCollapsedFolder(l, base)).toList();
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return visible;
    // 検索中は名前が一致するレイヤーと、その祖先フォルダ（階層表示を保つため）のみ表示する。
    final byId = {for (final l in base) l.id: l};
    bool isAncestorOfMatch(model.Layer folder) {
      return base.any((l) {
        if (!l.name.toLowerCase().contains(query)) return false;
        String? pid = l.parentFolderId;
        while (pid != null) {
          if (pid == folder.id) return true;
          pid = byId[pid]?.parentFolderId;
        }
        return false;
      });
    }
    return visible
        .where((l) => l.name.toLowerCase().contains(query) || isAncestorOfMatch(l))
        .toList();
  }

  /// フォルダの折りたたみ状態に基づき、祖先フォルダが折りたたまれている場合はtrue（仕様書16）
  bool _isHiddenByCollapsedFolder(model.Layer layer, List<model.Layer> all) {
    final byId = {for (final l in all) l.id: l};
    String? pid = layer.parentFolderId;
    while (pid != null) {
      final parent = byId[pid];
      if (parent == null) break;
      if (!parent.isExpanded) return true;
      pid = parent.parentFolderId;
    }
    return false;
  }

  int _depthOf(model.Layer layer, List<model.Layer> all) {
    final byId = {for (final l in all) l.id: l};
    int depth = 0;
    String? pid = layer.parentFolderId;
    while (pid != null) {
      depth++;
      final parent = byId[pid];
      pid = parent?.parentFolderId;
    }
    return depth;
  }

  @override
  Widget build(BuildContext context) {
    final projectService = context.watch<ProjectService>();
    final allLayers = projectService.layersOf(
        widget.projectId, widget.sceneId, widget.frameIndex);
    final layers = _visibleLayers(allLayers);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Text('レイヤー', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 18),
                  onPressed: () => _showHelp(context),
                  tooltip: 'ヘルプ',
                ),
                IconButton(
                  icon: Icon(_showSearch ? Icons.search_off : Icons.search, size: 18),
                  onPressed: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  }),
                  tooltip: '名前で検索',
                ),
                if (!widget.dockedMode)
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onClose),
              ],
            ),
          ),
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'レイヤー名で検索',
                  prefixIcon: Icon(Icons.search, size: 16),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          // 選択モードバー
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      final base = _selectionBaseType;
                      if (base == null) return;
                      _selectedIds.addAll(
                        layers.where((l) => l.type == base).map((l) => l.id),
                      );
                    }),
                    child: const Text('全選択', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedIds.clear();
                      _isSelectionMode = false;
                      _selectionBaseType = null;
                    }),
                    child: const Text('全解除', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // 上部ショートカットボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('新規レイヤー', style: TextStyle(fontSize: 11)),
                    onPressed: () => _addLayer(context, model.LayerType.normal, 'レイヤー'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.folder, size: 14),
                    label: const Text('新規フォルダ', style: TextStyle(fontSize: 11)),
                    onPressed: () => _addLayer(context, model.LayerType.folder, 'フォルダ'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.photo, size: 14),
                    label: const Text('画像読み込み', style: TextStyle(fontSize: 11)),
                    onPressed: () => _importImage(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: layers.length,
              onReorder: (oldIdx, newIdx) {
                if (_searchQuery.trim().isNotEmpty) return; // 検索中はフィルタ表示のため並び替え不可
                context.read<ProjectService>().reorderLayer(
                  projectId: widget.projectId,
                  sceneId: widget.sceneId,
                  frameIndex: widget.frameIndex,
                  oldIndex: oldIdx,
                  newIndex: newIdx,
                );
              },
              itemBuilder: (context, index) {
                final layer = layers[index];
                final isSelected = index == _selectedIndex;
                final isChecked = _selectedIds.contains(layer.id);
                final depth = _depthOf(layer, layers);
                return ListTile(
                  key: ValueKey(layer.id),
                  selected: isSelected,
                  dense: true,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (depth > 0) SizedBox(width: depth * 12.0),
                      if (layer.type == model.LayerType.folder)
                        GestureDetector(
                          onTap: () => context.read<ProjectService>().updateLayer(
                            projectId: widget.projectId,
                            sceneId: widget.sceneId,
                            frameIndex: widget.frameIndex,
                            layer: layer.copyWith(isExpanded: !layer.isExpanded),
                          ),
                          child: Icon(
                            layer.isExpanded ? Icons.expand_more : Icons.chevron_right,
                            size: 16,
                          ),
                        )
                      else if (depth > 0)
                        const SizedBox(width: 16),
                      if (_isSelectionMode)
                        Checkbox(
                          value: isChecked,
                          onChanged: layer.type == _selectionBaseType
                              ? (_) => setState(() {
                                  if (isChecked) {
                                    _selectedIds.remove(layer.id);
                                    if (_selectedIds.isEmpty) {
                                      _isSelectionMode = false;
                                      _selectionBaseType = null;
                                    }
                                  } else {
                                    _selectedIds.add(layer.id);
                                  }
                                })
                              : null,
                        )
                      else
                        GestureDetector(
                          onTap: () => context.read<ProjectService>().updateLayer(
                            projectId: widget.projectId,
                            sceneId: widget.sceneId,
                            frameIndex: widget.frameIndex,
                            layer: layer.copyWith(isVisible: !layer.isVisible),
                          ),
                          child: Icon(
                            layer.isVisible ? Icons.visibility : Icons.visibility_off,
                            size: 16,
                          ),
                        ),
                      const SizedBox(width: 4),
                      _layerTypeIcon(layer.type),
                      const SizedBox(width: 4),
                      Container(width: 24, height: 24, color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    ],
                  ),
                  title: Text(layer.name, style: const TextStyle(fontSize: 12)),
                  subtitle: layer.type == model.LayerType.common
                      ? Text(_rangeSummary(layer), style: const TextStyle(fontSize: 9, color: Colors.blue))
                      : layer.hasClipping
                          ? Text('クリッピング',
                              style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.primary))
                          : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (layer.needsAutofillUpdate)
                        GestureDetector(
                          onTap: () => _showAutofillDialog(context, layer),
                          onLongPress: () => _showAutofillUpdateHelp(context),
                          child: const Icon(Icons.error, color: Colors.orange, size: 14),
                        ),
                      if (layer.opacityLocked)
                        Icon(Icons.opacity, size: 14, color: Theme.of(context).colorScheme.primary),
                      if (layer.isLocked)
                        const Icon(Icons.lock, size: 14),
                      if (_isTimelineMaterial(layer.type) ||
                          layer.type == model.LayerType.common ||
                          layer.type == model.LayerType.autoFillLineart)
                        GestureDetector(
                          onTap: () => _showTimelineLayerMenu(context, layer),
                          child: const Icon(Icons.more_vert, size: 16),
                        ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      if (_isSelectionMode) {
                        if (layer.type != _selectionBaseType) return;
                        if (_selectedIds.contains(layer.id)) {
                          _selectedIds.remove(layer.id);
                          if (_selectedIds.isEmpty) {
                            _isSelectionMode = false;
                            _selectionBaseType = null;
                          }
                        } else {
                          _selectedIds.add(layer.id);
                        }
                      } else {
                        _selectedIndex = index;
                      }
                    });
                    if (!_isSelectionMode &&
                        layer.type == model.LayerType.text &&
                        widget.onEditTextLayer != null) {
                      widget.onEditTextLayer!(layer);
                    }
                  },
                  onLongPress: () => setState(() {
                    if (!_isSelectionMode) {
                      _isSelectionMode = true;
                      _selectionBaseType = layer.type;
                      _selectedIds.add(layer.id);
                    }
                  }),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => _showAddLayerMenu(context),
                  tooltip: '追加',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: _canDeleteSelected(layers) ? () => _deleteSelectedLayer(context, layers) : null,
                  tooltip: '削除',
                ),
                if (_isSelectionMode)
                  IconButton(
                    icon: const Icon(Icons.merge_type, size: 18),
                    onPressed: _canMergeSelected() ? () => _mergeSelectedLayers(context) : null,
                    tooltip: '結合',
                  ),
                if (_selectedIndex >= 0 &&
                    _selectedIndex < layers.length &&
                    !_isTimelineMaterial(layers[_selectedIndex].type)) ...[
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 18),
                    onPressed: () => _showLayerOptions(context, layers),
                    tooltip: 'レイヤー設定',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _layerTypeIcon(model.LayerType type) {
    return switch (type) {
      model.LayerType.autoFillLineart => const Icon(Icons.edit, size: 12, color: Colors.orange),
      model.LayerType.autoFill        => const Icon(Icons.palette, size: 12, color: Colors.green),
      model.LayerType.common          => const Icon(Icons.link, size: 12, color: Colors.blue),
      model.LayerType.folder          => const Icon(Icons.folder, size: 12, color: Colors.amber),
      model.LayerType.text            => const Icon(Icons.text_fields, size: 12, color: Colors.purple),
      model.LayerType.timelineImage   => const Icon(Icons.image, size: 12, color: Colors.teal),
      model.LayerType.timelineVideo   => const Icon(Icons.videocam, size: 12, color: Colors.indigo),
      model.LayerType.watermark       => const Icon(Icons.branding_watermark, size: 12, color: Colors.pink),
      _ => const SizedBox(width: 12),
    };
  }

  /// 結合可能な選択状態か（仕様書16：共通レイヤー・フォルダ・タイムライン
  /// 素材は結合不可、2枚以上選択している必要がある）。
  bool _canMergeSelected() {
    if (!_isSelectionMode || _selectedIds.length < 2) return false;
    final type = _selectionBaseType;
    if (type == null) return false;
    const mergeable = {
      model.LayerType.normal,
      model.LayerType.autoFillLineart,
      model.LayerType.autoFill,
    };
    return mergeable.contains(type);
  }

  Future<void> _mergeSelectedLayers(BuildContext context) async {
    if (!_canMergeSelected()) return;
    final service = context.read<ProjectService>();
    final ids = _selectedIds.toList();
    await service.mergeLayers(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerIds: ids,
    );
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
      _selectionBaseType = null;
      _selectedIndex = 0;
    });
  }

  bool _isTimelineMaterial(model.LayerType type) =>
      type == model.LayerType.timelineImage ||
      type == model.LayerType.timelineVideo ||
      type == model.LayerType.watermark;

  bool _canDeleteSelected(List<model.Layer> layers) {
    if (layers.isEmpty) return false;
    if (_isSelectionMode) {
      if (_selectedIds.isEmpty) return false;
      if (_selectionBaseType != null && _isTimelineMaterial(_selectionBaseType!)) return true;
      if (_selectionBaseType == model.LayerType.normal) {
        final normalCount = layers.where((l) => l.type == model.LayerType.normal).length;
        return normalCount - _selectedIds.length >= 1;
      }
      return true;
    }
    if (_selectedIndex < 0 || _selectedIndex >= layers.length) return false;
    final layer = layers[_selectedIndex];
    if (_isTimelineMaterial(layer.type)) return true;
    if (layer.type == model.LayerType.normal) {
      return layers.where((l) => l.type == model.LayerType.normal).length > 1;
    }
    return true;
  }

  void _deleteSelectedLayer(BuildContext context, List<model.Layer> layers) {
    if (layers.isEmpty) return;
    final service = context.read<ProjectService>();
    if (_isSelectionMode) {
      if (_selectionBaseType != null && _isTimelineMaterial(_selectionBaseType!)) {
        _showMultiTimelineDeleteConfirm(context, layers);
      } else {
        for (final id in _selectedIds) {
          service.removeLayer(
            projectId: widget.projectId,
            sceneId: widget.sceneId,
            frameIndex: widget.frameIndex,
            layerId: id,
          );
        }
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
          _selectionBaseType = null;
          _selectedIndex = 0;
        });
      }
      return;
    }
    if (_selectedIndex < 0 || _selectedIndex >= layers.length) return;
    final layer = layers[_selectedIndex];
    if (_isTimelineMaterial(layer.type)) {
      _showTimelineDeleteConfirm(context, layer);
    } else {
      service.removeLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layerId: layer.id,
      );
      setState(() {
        if (_selectedIndex >= layers.length - 1) _selectedIndex = layers.length - 2;
        if (_selectedIndex < 0) _selectedIndex = 0;
      });
    }
  }

  void _showMultiTimelineDeleteConfirm(BuildContext context, List<model.Layer> layers) {
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('選択中の$count件を削除しますか？'),
        content: const Text('タイムライン素材の表示範囲内のすべてのフレームから削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              final service = context.read<ProjectService>();
              for (final id in _selectedIds) {
                service.removeLayer(
                  projectId: widget.projectId,
                  sceneId: widget.sceneId,
                  frameIndex: widget.frameIndex,
                  layerId: id,
                );
              }
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
                _selectionBaseType = null;
                _selectedIndex = 0;
              });
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showTimelineDeleteConfirm(BuildContext context, model.Layer layer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${layer.name}を削除しますか？'),
        content: const Text('この素材の表示範囲内のすべてのフレームから削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProjectService>().removeLayer(
                projectId: widget.projectId,
                sceneId: widget.sceneId,
                frameIndex: widget.frameIndex,
                layerId: layer.id,
              );
              setState(() => _selectedIndex = 0);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  /// 共通レイヤーの表示範囲を「🔗 名前（開始〜終了）」の形式で要約する（仕様書16）
  String _rangeSummary(model.Layer layer) {
    switch (layer.rangeMode) {
      case model.LayerRangeMode.allFrames:
        return '全フレーム';
      case model.LayerRangeMode.currentScene:
        return '現在シーン';
      case model.LayerRangeMode.sceneRange:
        if (layer.rangeSceneId == null) return 'シーン指定';
        final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
        final scene = scenes.where((s) => s.id == layer.rangeSceneId).firstOrNull;
        return scene != null ? scene.displayName : 'シーン指定';
      case model.LayerRangeMode.frameRange:
        final s = layer.rangeStart ?? 1;
        final e = layer.rangeEnd ?? s;
        return '$s〜$e';
    }
  }

  void _showTimelineLayerMenu(BuildContext context, model.Layer layer) {
    final isCommon = layer.type == model.LayerType.common;
    final isLineart = layer.type == model.LayerType.autoFillLineart;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(layer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (!isLineart)
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(isCommon ? '表示フレーム範囲変更' : '表示範囲変更'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRangeChangeDialog(context, layer);
                },
              ),
            if (isLineart)
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('パーツ設定'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPartAssignDialog(context, layer);
                },
              ),
            if (isLineart)
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: const Text('自動塗り実行'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAutofillDialog(context, layer, isLineartLayer: true);
                },
              ),
            if (!isCommon && !isLineart)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('素材差し替え'),
                onTap: () {
                  Navigator.pop(ctx);
                  _replaceMaterial(context, layer);
                },
              ),
            if (isCommon)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('複製'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ProjectService>().addLayer(
                    projectId: widget.projectId,
                    sceneId: widget.sceneId,
                    frameIndex: widget.frameIndex,
                    type: model.LayerType.common,
                    name: '${layer.name}のコピー',
                  );
                },
              ),
            if (isCommon)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('名前変更'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context, layer);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('削除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _showTimelineDeleteConfirm(context, layer);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, model.Layer layer) {
    final nameCtrl = TextEditingController(text: layer.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('名前変更'),
        content: TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<ProjectService>().updateLayer(
                  projectId: widget.projectId,
                  sceneId: widget.sceneId,
                  frameIndex: widget.frameIndex,
                  layer: layer.copyWith(name: nameCtrl.text),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    ).then((_) => nameCtrl.dispose());
  }

  /// 表示範囲設定ダイアログ（仕様書16：共通レイヤー・タイムライン素材レイヤー）。
  /// 既存レイヤーの変更（[onConfirm]省略時はupdateLayerを直接呼ぶ）・新規作成時の
  /// 設定（[onConfirm]を渡すとその関数へ結果を渡すのみで自動更新しない）の両方に使う。
  void _showRangeChangeDialog(
    BuildContext context,
    model.Layer layer, {
    String? title,
    String confirmLabel = 'OK',
    void Function(model.LayerRangeMode mode, int start, int end, String? rangeSceneId)? onConfirm,
  }) {
    final ps = context.read<ProjectService>();
    final totalFrames = ps.frameCount(widget.projectId, widget.sceneId);
    final scenes = ps.scenesOf(widget.projectId);
    final startCtrl = TextEditingController(
        text: (layer.rangeStart ?? 1).toString());
    final endCtrl = TextEditingController(
        text: (layer.rangeEnd ?? (totalFrames > 0 ? totalFrames : 1)).toString());
    model.LayerRangeMode mode = layer.rangeMode;
    String? sceneId = layer.rangeSceneId ?? widget.sceneId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(title ?? '表示範囲'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '開始フレーム', border: OutlineInputBorder()),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('〜')),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '終了フレーム', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setS(() {
                    startCtrl.text = '1';
                    endCtrl.text = totalFrames > 0 ? totalFrames.toString() : '1';
                  }),
                  child: const Text('現在範囲を使用'),
                ),
                const Divider(),
                RadioListTile<model.LayerRangeMode>(
                  dense: true,
                  title: const Text('全フレーム'),
                  value: model.LayerRangeMode.allFrames,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
                RadioListTile<model.LayerRangeMode>(
                  dense: true,
                  title: const Text('現在シーン'),
                  value: model.LayerRangeMode.currentScene,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
                RadioListTile<model.LayerRangeMode>(
                  dense: true,
                  title: const Text('シーン指定'),
                  value: model.LayerRangeMode.sceneRange,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
                if (mode == model.LayerRangeMode.sceneRange)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
                    child: DropdownButtonFormField<String>(
                      initialValue: scenes.any((s) => s.id == sceneId) ? sceneId : scenes.firstOrNull?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '対象シーン', isDense: true),
                      items: scenes
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName)))
                          .toList(),
                      onChanged: (v) => setS(() => sceneId = v),
                    ),
                  ),
                RadioListTile<model.LayerRangeMode>(
                  dense: true,
                  title: const Text('フレーム範囲指定'),
                  value: model.LayerRangeMode.frameRange,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                final start = int.tryParse(startCtrl.text) ?? 1;
                final end = int.tryParse(endCtrl.text) ?? start;
                final resolvedSceneId = mode == model.LayerRangeMode.sceneRange ? sceneId : null;
                if (onConfirm != null) {
                  onConfirm(mode, start, end, resolvedSceneId);
                } else {
                  context.read<ProjectService>().updateLayer(
                    projectId: widget.projectId,
                    sceneId: widget.sceneId,
                    frameIndex: widget.frameIndex,
                    layer: layer.copyWith(
                      rangeMode: mode,
                      rangeStart: start,
                      rangeEnd: end,
                      rangeSceneId: resolvedSceneId,
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    ).then((_) {
      startCtrl.dispose();
      endCtrl.dispose();
    });
  }

  void _showAddLayerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.layers),
              title: const Text('通常レイヤー'),
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.normal, 'レイヤー'); },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: const Text('共通レイヤー'),
              onTap: () { Navigator.pop(ctx); _addCommonLayer(context); },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('フォルダ'),
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.folder, 'フォルダ'); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('自動塗り用線画レイヤー'),
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.autoFillLineart, '線画'); },
            ),
            ListTile(
              leading: const Icon(Icons.palette, color: Colors.green),
              title: const Text('自動塗りレイヤー'),
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.autoFill, '自動塗り'); },
            ),
            // テキストレイヤーはテキストツールからキャンバスタップで自動生成するため追加しない（仕様書16）
          ],
        ),
      ),
    );
  }

  /// 共通レイヤーの新規追加（仕様書16「追加時の設定」）。追加前に表示範囲
  /// （共通レイヤー範囲）を設定するダイアログを表示してから作成する。
  void _addCommonLayer(BuildContext context) {
    final layers = context.read<ProjectService>().layersOf(
        widget.projectId, widget.sceneId, widget.frameIndex);
    final visible = _visibleLayers(layers);
    final placeholder = model.Layer(
      id: '', name: '', type: model.LayerType.common,
    );
    _showRangeChangeDialog(
      context,
      placeholder,
      title: '共通レイヤー範囲',
      confirmLabel: '作成',
      onConfirm: (mode, start, end, rangeSceneId) {
        final ps = context.read<ProjectService>();
        final created = ps.addLayer(
          projectId: widget.projectId,
          sceneId: widget.sceneId,
          frameIndex: widget.frameIndex,
          type: model.LayerType.common,
          name: '共通${visible.length + 1}',
        );
        ps.updateLayer(
          projectId: widget.projectId,
          sceneId: widget.sceneId,
          frameIndex: widget.frameIndex,
          layer: created.copyWith(
            rangeMode: mode, rangeStart: start, rangeEnd: end, rangeSceneId: rangeSceneId),
        );
        setState(() => _selectedIndex = 0);
      },
    );
  }

  void _addLayer(BuildContext context, model.LayerType type, String prefix) {
    final layers = context.read<ProjectService>().layersOf(
        widget.projectId, widget.sceneId, widget.frameIndex);
    final visible = _visibleLayers(layers);
    context.read<ProjectService>().addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      type: type,
      name: '$prefix${visible.length + 1}',
    );
    setState(() => _selectedIndex = 0);
  }

  void _showLayerOptions(BuildContext context, List<model.Layer> layers) {
    if (_selectedIndex < 0 || _selectedIndex >= layers.length) return;
    final layer = layers[_selectedIndex];
    void update(model.Layer Function(model.Layer) updater) {
      context.read<ProjectService>().updateLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layer: updater(layer),
      );
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(layer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              // 不透明度スライダー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text('不透明度', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (ctx, setS) => Slider(
                          value: layer.opacity.toDouble(),
                          min: 0, max: 100, divisions: 100,
                          label: '${layer.opacity}%',
                          onChanged: (v) {
                            setS(() {});
                            update((l) => l.copyWith(opacity: v.round()));
                          },
                        ),
                      ),
                    ),
                    Text('${layer.opacity}%', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              // ブレンドモード
              ListTile(
                title: const Text('ブレンドモード'),
                trailing: Text(
                  _blendModeName(layer.blendMode),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlendModeDialog(context, layer, update);
                },
              ),
              SwitchListTile(
                title: const Text('ロック'),
                value: layer.isLocked,
                onChanged: (v) { update((l) => l.copyWith(isLocked: v)); Navigator.pop(ctx); },
              ),
              SwitchListTile(
                title: const Text('不透明度ロック'),
                value: layer.opacityLocked,
                onChanged: (v) { update((l) => l.copyWith(opacityLocked: v)); Navigator.pop(ctx); },
              ),
              SwitchListTile(
                title: const Text('クリッピング'),
                subtitle: const Text('下のレイヤーの不透明範囲内のみ描画', style: TextStyle(fontSize: 11)),
                value: layer.hasClipping,
                onChanged: (v) { update((l) => l.copyWith(hasClipping: v)); Navigator.pop(ctx); },
              ),
              SwitchListTile(
                title: const Text('マスク'),
                subtitle: const Text('白=表示・黒=非表示で描画範囲を制御', style: TextStyle(fontSize: 11)),
                value: layer.hasMask,
                onChanged: (v) { update((l) => l.copyWith(hasMask: v)); Navigator.pop(ctx); },
              ),
              if (layer.type == model.LayerType.normal)
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.blue),
                  title: const Text('共通レイヤーへ変更'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showConvertToCommonDialog(context, layer);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 共通レイヤー化ダイアログ（仕様書16）。「現在レイヤーを共通化」／
  /// 「表示中レイヤーを複製して全統合して共通化」の2択→表示範囲設定→変換実行。
  void _showConvertToCommonDialog(BuildContext context, model.Layer layer) {
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('共通レイヤーへ変更'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('現在レイヤーを共通化'),
                subtitle: const Text('このレイヤーのみを共通レイヤーとして設定します', style: TextStyle(fontSize: 11)),
                value: 0,
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
              ),
              RadioListTile<int>(
                title: const Text('表示中レイヤーを複製して全統合して共通化'),
                subtitle: const Text('表示中のすべてのレイヤーを統合した結果を共通レイヤーとして作成します', style: TextStyle(fontSize: 11)),
                value: 1,
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final placeholder = model.Layer(id: '', name: '', type: model.LayerType.common);
                _showRangeChangeDialog(
                  context,
                  placeholder,
                  title: '共通レイヤー範囲',
                  confirmLabel: '作成',
                  onConfirm: (mode, start, end, rangeSceneId) {
                    final ps = context.read<ProjectService>();
                    if (selected == 0) {
                      ps.convertLayerToCommon(
                        projectId: widget.projectId,
                        sceneId: widget.sceneId,
                        frameIndex: widget.frameIndex,
                        layer: layer,
                        rangeMode: mode,
                        rangeStart: start,
                        rangeEnd: end,
                        rangeSceneId: rangeSceneId,
                      );
                    } else {
                      ps.addFlattenedCommonLayer(
                        projectId: widget.projectId,
                        sceneId: widget.sceneId,
                        frameIndex: widget.frameIndex,
                        rangeMode: mode,
                        rangeStart: start,
                        rangeEnd: end,
                        rangeSceneId: rangeSceneId,
                      );
                    }
                    setState(() => _selectedIndex = 0);
                  },
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlendModeDialog(BuildContext context, model.Layer layer,
      void Function(model.Layer Function(model.Layer)) update) {
    const modes = model.LayerBlendMode.values;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ブレンドモード'),
        content: SizedBox(
          width: 280,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: modes.length,
            itemBuilder: (ctx, i) => ListTile(
              dense: true,
              title: Text(_blendModeName(modes[i]), style: const TextStyle(fontSize: 13)),
              selected: layer.blendMode == modes[i],
              onTap: () {
                update((l) => l.copyWith(blendMode: modes[i]));
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  String _blendModeName(model.LayerBlendMode mode) => switch (mode) {
    model.LayerBlendMode.normal      => '通常',
    model.LayerBlendMode.multiply    => '乗算',
    model.LayerBlendMode.screen      => 'スクリーン',
    model.LayerBlendMode.overlay     => 'オーバーレイ',
    model.LayerBlendMode.addition    => '加算',
    model.LayerBlendMode.subtract    => '減算',
    model.LayerBlendMode.darken      => '比較（暗）',
    model.LayerBlendMode.lighten     => '比較（明）',
    model.LayerBlendMode.colorBurn   => '焼き込みカラー',
    model.LayerBlendMode.colorDodge  => '覆い焼きカラー',
    model.LayerBlendMode.hardLight   => 'ハードライト',
    model.LayerBlendMode.softLight   => 'ソフトライト',
    model.LayerBlendMode.difference  => '差の絶対値',
    model.LayerBlendMode.hue         => '色相',
    model.LayerBlendMode.saturation  => '彩度',
    model.LayerBlendMode.color       => 'カラー',
    model.LayerBlendMode.luminosity  => '輝度',
  };

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('レイヤーについて'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ブレンドモード', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('レイヤーの合成方法を変更します。乗算・スクリーン・オーバーレイなどがあります。'),
              SizedBox(height: 8),
              Text('クリッピング', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('下のレイヤーの不透明ピクセル範囲内のみ描画します。'),
              SizedBox(height: 8),
              Text('マスク', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('マスクで描画範囲を制御します。白い部分が表示、黒い部分が非表示になります。'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  /// [layer] は❗マークが表示された自動塗りレイヤー、または三点メニューから起動した場合は
  /// 自動塗り用線画レイヤー（[isLineartLayer]=true）。実行対象の線画レイヤーを特定してから
  /// ダイアログを表示する。
  void _showAutofillDialog(BuildContext context, model.Layer layer, {bool isLineartLayer = false}) {
    final projectService = context.read<ProjectService>();
    final allLayers = projectService.layersOf(widget.projectId, widget.sceneId, widget.frameIndex);
    model.Layer? lineartLayer;
    if (isLineartLayer) {
      lineartLayer = layer;
    } else {
      final idx = allLayers.indexWhere((l) => l.id == layer.id);
      if (idx > 0 && allLayers[idx - 1].type == model.LayerType.autoFillLineart) {
        lineartLayer = allLayers[idx - 1];
      }
    }
    if (lineartLayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('対応する自動塗り用線画レイヤーが見つかりません。')),
      );
      return;
    }
    final resolvedLineart = lineartLayer;
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('自動塗り方法'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('※ プロジェクト内で自動塗りを初回実行する場合はどちらを選んでも問題ありません。',
                  style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('※ 自動塗りレイヤーが存在しない場合は、一から領域を判定して自動塗りします。',
                  style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              RadioListTile<int>(
                title: const Text('塗りなおし'),
                subtitle: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('誤って自動塗りの形状を変えてしまった場合におすすめ', style: TextStyle(fontSize: 11)),
                    Text('※ 一から領域を判定して塗りなおします。現在の自動塗りレイヤーの形状は破棄されます。', style: TextStyle(fontSize: 11)),
                  ],
                ),
                value: 0, groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
                dense: true,
              ),
              RadioListTile<int>(
                title: const Text('色更新'),
                subtitle: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('自動塗りの形状を手動で調整した場合におすすめ', style: TextStyle(fontSize: 11)),
                    Text('※ 不透明度ロックをして最新の色で塗りつぶします。現在の自動塗りレイヤーの形状は維持されます。', style: TextStyle(fontSize: 11)),
                  ],
                ),
                value: 1, groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeAutofill(
                  context,
                  resolvedLineart,
                  selected == 0 ? autofill.AutofillMode.repaint : autofill.AutofillMode.colorUpdate,
                );
              },
              child: const Text('実行'),
            ),
          ],
        ),
      ),
    );
  }

  /// 自動塗りエンジンを実行し、結果を対象自動塗りレイヤーのタイルへ書き戻す（仕様書04）。
  Future<void> _executeAutofill(
      BuildContext context, model.Layer lineartLayer, autofill.AutofillMode mode) async {
    final partId = lineartLayer.partId;
    if (partId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パーツが未設定です。「パーツ設定」から設定してください。')),
      );
      return;
    }
    final part = context.read<AutofillPresetService>().findPart(partId);
    if (part == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('対応するプリセットパーツが見つかりません。')),
      );
      return;
    }
    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;

    final lineartImg = await tileManager.compositeLayerToImage(
        frameLayerKey(widget.sceneId, widget.frameIndex, lineartLayer.id));
    final lineartBytes =
        (await lineartImg.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    lineartImg.dispose();

    var layers = projectService.layersOf(widget.projectId, widget.sceneId, widget.frameIndex);
    final lineartIdx = layers.indexWhere((l) => l.id == lineartLayer.id);
    model.Layer? autofillLayer = (lineartIdx >= 0 &&
            lineartIdx + 1 < layers.length &&
            layers[lineartIdx + 1].type == model.LayerType.autoFill)
        ? layers[lineartIdx + 1]
        : null;

    final autofillKey = autofillLayer == null
        ? null
        : frameLayerKey(widget.sceneId, widget.frameIndex, autofillLayer.id);
    final hasExisting = autofillKey != null && tileManager.hasLayer(autofillKey);
    Uint8List? existingBytes;
    if (hasExisting) {
      final img = await tileManager.compositeLayerToImage(autofillKey);
      existingBytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      img.dispose();
    }

    final engine = autofill.AutofillEngine();
    // 新規生成時（対応する自動塗りレイヤーが存在しない場合）は色更新選択時でも必ず一から塗る
    final effectiveMode = hasExisting ? mode : autofill.AutofillMode.repaint;
    final result = engine.execute(
      mode: effectiveMode,
      lineartData: lineartBytes,
      existingData: hasExisting ? existingBytes : null,
      width: w,
      height: h,
      part: part,
    );
    if (result == null) return;
    if (!context.mounted) return;

    if (autofillLayer == null) {
      final created = projectService.addLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        type: model.LayerType.autoFill,
        name: '${part.name}（自動塗り）',
      );
      // 線画レイヤーの直下へ移動する
      layers = projectService.layersOf(widget.projectId, widget.sceneId, widget.frameIndex);
      final createdIdx = layers.indexWhere((l) => l.id == created.id);
      final targetIdx = layers.indexWhere((l) => l.id == lineartLayer.id) + 1;
      if (createdIdx >= 0 && targetIdx >= 0 && createdIdx != targetIdx) {
        projectService.reorderLayer(
          projectId: widget.projectId,
          sceneId: widget.sceneId,
          frameIndex: widget.frameIndex,
          oldIndex: createdIdx,
          newIndex: targetIdx,
        );
      }
      autofillLayer = created.copyWith(partId: part.id);
    }

    tileManager.replaceLayerPixels(
        frameLayerKey(widget.sceneId, widget.frameIndex, autofillLayer.id), result);
    projectService.updateLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layer: autofillLayer.copyWith(
        partId: part.id,
        needsAutofillUpdate: false,
        opacityLocked: effectiveMode == autofill.AutofillMode.colorUpdate ? true : autofillLayer.opacityLocked,
      ),
    );
    setState(() {});
  }

  /// 自動塗り用線画レイヤーへプリセットパーツを割り当てるダイアログ（仕様書04：パーツID管理）。
  void _showPartAssignDialog(BuildContext context, model.Layer lineartLayer) {
    final presets = context.read<AutofillPresetService>().presets;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 400,
          child: presets.isEmpty
              ? const Center(child: Text('プリセットがありません'))
              : ListView(
                  children: [
                    for (final preset in presets) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      for (final part in preset.parts)
                        ListTile(
                          dense: true,
                          leading: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: Color(part.color),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                          title: Text(part.name),
                          selected: lineartLayer.partId == part.id,
                          onTap: () {
                            context.read<ProjectService>().assignAutofillPart(
                              projectId: widget.projectId,
                              sceneId: widget.sceneId,
                              frameIndex: widget.frameIndex,
                              lineartLayerId: lineartLayer.id,
                              partId: part.id,
                              partName: part.name,
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  void _showAutofillUpdateHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自動塗り更新マーク'),
        content: const Text('現在の自動塗りは最新ではありません。タップすると更新できます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  /// 画像を選択し、キャンバスサイズへアスペクト比維持で中央フィットさせて
  /// ラスタライズし、通常レイヤーとして追加する（仕様書16：画像読み込みは
  /// タイムライン素材ではなく描画レイヤーとして扱う）。
  /// レイヤーのピクセル内容を新しい画像で丸ごと差し替える（位置・トランスフォームは
  /// 維持したまま、キャンバス全体に収まるよう中央寄せ・アスペクト比維持で描き直す）。
  Future<void> _replaceMaterial(BuildContext context, model.Layer layer) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (!context.mounted) {
      image.dispose();
      return;
    }

    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;

    final scale = math.min(w / image.width, h / image.height);
    final drawW = image.width * scale;
    final drawH = image.height * scale;
    final dx = (w - drawW) / 2;
    final dy = (h - drawH) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(dx, dy, drawW, drawH),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    image.dispose();
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered.dispose();
    if (byteData == null || !context.mounted) return;

    tileManager.replaceLayerPixels(
      projectService.tileKeyFor(widget.projectId, widget.sceneId, widget.frameIndex, layer.id),
      byteData.buffer.asUint8List(),
    );
    projectService.updateLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layer: layer,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('素材を差し替えました: ${layer.name}')),
    );
  }

  Future<void> _importImage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) return;
    final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (!context.mounted) {
      image.dispose();
      return;
    }

    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    final w = tileManager.canvasWidth;
    final h = tileManager.canvasHeight;

    final scale = math.min(w / image.width, h / image.height);
    final drawW = image.width * scale;
    final drawH = image.height * scale;
    final dx = (w - drawW) / 2;
    final dy = (h - drawH) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(dx, dy, drawW, drawH),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w, h);
    image.dispose();
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered.dispose();
    if (byteData == null || !context.mounted) return;

    final layer = projectService.addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      type: model.LayerType.normal,
      name: name,
    );
    tileManager.replaceLayerPixels(
      frameLayerKey(widget.sceneId, widget.frameIndex, layer.id),
      byteData.buffer.asUint8List(),
    );
    // addLayer時点のnotifyListenersはピクセル書き込み前のため、書き込み後に
    // 再度更新を通知してキャンバス側の合成表示を最新化する（自動塗り適用と同じ手順）。
    projectService.updateLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layer: layer,
    );
    setState(() => _selectedIndex = 0);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('画像を読み込みました: $name')),
    );
  }
}
