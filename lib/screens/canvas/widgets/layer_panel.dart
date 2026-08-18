import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../engine/autofill_batch_runner.dart';
import '../../../engine/autofill_engine.dart' as autofill;
import '../../../engine/tile_manager.dart' show frameLayerKey;
import '../../../engine/undo_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/layer.dart' as model;
import '../../../services/autofill_preset_service.dart';
import '../../../services/project_service.dart';
import '../../../services/tone_service.dart';
import '../../../widgets/confirm_delete.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/first_use_tooltip.dart';

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

  // レイヤーサムネイル更新用（仕様書16：「サムネイルはペンを離した瞬間に
  // 現在レイヤーのみ更新する（全レイヤー一括更新はしない）」）。
  // UndoManagerはストローク確定（push）・Undo・Redoのたびに必ず
  // notifyListeners()するため、これを「ペンが離れた（＝描画内容が変わり
  // 得た）」タイミングの検知に利用する。undoCountの値そのものは増減する
  // （Undo時は減る）が、値が変化したこと自体が「内容が変わった」ことの
  // 十分条件になる。
  int _lastUndoCount = -1;
  final Map<String, int> _thumbRevision = {};

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
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.watch<ProjectService>();
    final allLayers = projectService.layersOf(
        widget.projectId, widget.sceneId, widget.frameIndex);
    final layers = _visibleLayers(allLayers);

    // ストロークが確定した（＝ペンが離れた）タイミングを検知し、現在
    // 選択中のレイヤーのサムネイルだけを再生成対象とする（仕様書16）。
    final undoCount = context.watch<UndoManager>().undoCount;
    if (_lastUndoCount != undoCount) {
      _lastUndoCount = undoCount;
      if (_selectedIndex >= 0 && _selectedIndex < layers.length) {
        final id = layers[_selectedIndex].id;
        _thumbRevision[id] = (_thumbRevision[id] ?? 0) + 1;
      }
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Text(l10n.layerPanelTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 18),
                  onPressed: () => _showHelp(context),
                  tooltip: l10n.layerPanelHelpTooltip,
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
                  tooltip: l10n.creativePanelSearchTooltip,
                ),
                if (!widget.dockedMode)
                  IconButton(icon: const Icon(Icons.close, size: 18), tooltip: l10n.commonClose, onPressed: widget.onClose),
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
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.layerPanelSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 16),
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
                    child: Text(l10n.layerPanelSelectAll, style: const TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedIds.clear();
                      _isSelectionMode = false;
                      _selectionBaseType = null;
                    }),
                    child: Text(l10n.layerPanelDeselectAll, style: const TextStyle(fontSize: 12)),
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
                    label: Text(l10n.layerPanelNewLayerButton, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _addLayer(context, model.LayerType.normal,
                        (n) => l10n.layerPanelDefaultLayerName(n)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.folder, size: 14),
                    label: Text(l10n.layerPanelNewFolderButton, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _addLayer(context, model.LayerType.folder,
                        (n) => l10n.layerPanelDefaultFolderName(n)),
                  ),
                ),
                // 「追加」ボタン（共通レイヤー・自動塗り線画・自動塗りレイヤー等の
                // その他種別）。ユーザー指示により新規フォルダと画像読み込みの間に
                // 配置。新規レイヤーボタンとアイコンが被らないようlibrary_addを使用。
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.library_add, size: 14),
                    label: Text(l10n.layerPanelAddTooltip, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _showAddLayerMenu(context),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.photo, size: 14),
                    label: Text(l10n.layerPanelImportImageButton, style: const TextStyle(fontSize: 11)),
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
                      _LayerThumbnail(
                        key: ValueKey('${layer.id}-${_thumbRevision[layer.id] ?? 0}'),
                        projectId: widget.projectId,
                        sceneId: widget.sceneId,
                        frameIndex: widget.frameIndex,
                        layerId: layer.id,
                      ),
                    ],
                  ),
                  title: Text(layer.name, style: const TextStyle(fontSize: 12)),
                  subtitle: layer.type == model.LayerType.common
                      ? Text(_rangeSummary(l10n, layer), style: const TextStyle(fontSize: 9, color: Colors.blue))
                      : layer.hasClipping
                          ? Text(l10n.layerPanelClippingBadge,
                              style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.primary))
                          : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 自動塗り更新マーク：初回使用時の吹き出し説明（仕様書04・11：
                      // 「自動塗り：初回使用時に吹き出し説明」）
                      if (layer.needsAutofillUpdate)
                        FirstUseTooltip(
                          tooltipKey: 'autofill_mark',
                          message: l10n.layerPanelAutofillMarkTooltip,
                          child: GestureDetector(
                            onTap: () => _showAutofillDialog(context, layer),
                            onLongPress: () => _showAutofillUpdateHelp(context),
                            child: const Icon(Icons.error, color: Colors.orange, size: 14),
                          ),
                        ),
                      if (layer.opacityLocked)
                        Icon(Icons.opacity, size: 14, color: Theme.of(context).colorScheme.primary),
                      if (layer.isLocked)
                        const Icon(Icons.lock, size: 14),
                      // 三点メニュー・ゴミ箱：以前はパネル下部にまとめて配置していたが
                      // ユーザー指示により各レイヤーの右側へ移動した（対象レイヤーが
                      // 常に明確になり、選択状態に依存しなくなる）。
                      GestureDetector(
                        onTap: () => _isTimelineMaterial(layer.type) ||
                                layer.type == model.LayerType.common ||
                                layer.type == model.LayerType.autoFillLineart
                            ? _showTimelineLayerMenu(context, layer)
                            : _showLayerOptions(context, layer),
                        child: const Icon(Icons.more_vert, size: 16),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _canDeleteLayerRow(layer, layers)
                            ? () => _deleteLayerRow(context, layer, layers)
                            : null,
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: _canDeleteLayerRow(layer, layers)
                              ? Colors.red[300]
                              : Theme.of(context).disabledColor,
                        ),
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
          // パネル下部の三点メニュー・ゴミ箱は各レイヤー右側へ移動したため削除した
          // （ユーザー指示）。「追加」ボタンも上部ショートカット行へ移動済み。
          // 下部バーは複数選択モード時の一括操作（結合・一括削除）専用として残す。
          if (_isSelectionMode) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: _canDeleteSelected(layers) ? () => _deleteSelectedLayer(context, layers) : null,
                    tooltip: l10n.commonDelete,
                  ),
                  IconButton(
                    icon: const Icon(Icons.merge_type, size: 18),
                    onPressed: _canMergeSelected() ? () => _mergeSelectedLayers(context) : null,
                    tooltip: l10n.layerPanelMergeTooltip,
                  ),
                ],
              ),
            ),
          ],
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

  /// [layer]を各レイヤー行のゴミ箱アイコンから単体削除できるかどうか
  /// （最後の1枚の通常レイヤーは削除不可、という既存の制約を踏襲）。
  bool _canDeleteLayerRow(model.Layer layer, List<model.Layer> layers) {
    if (layer.type == model.LayerType.normal) {
      return layers.where((l) => l.type == model.LayerType.normal).length > 1;
    }
    return true;
  }

  /// 各レイヤー行のゴミ箱アイコンからの単体削除（ユーザー指示：三点メニュー・
  /// ゴミ箱を各レイヤーの右側へ）。タイムライン素材は既存通り確認ダイアログ
  /// を経由し、それ以外は即時削除する。
  Future<void> _deleteLayerRow(BuildContext context, model.Layer layer, List<model.Layer> layers) async {
    if (_isTimelineMaterial(layer.type)) {
      _showTimelineDeleteConfirm(context, layer);
      return;
    }
    if (!await confirmDelete(context, itemName: layer.name)) return;
    if (!context.mounted) return;
    context.read<ProjectService>().removeLayer(
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

  Future<void> _deleteSelectedLayer(BuildContext context, List<model.Layer> layers) async {
    if (layers.isEmpty) return;
    final service = context.read<ProjectService>();
    if (_isSelectionMode) {
      if (_selectionBaseType != null && _isTimelineMaterial(_selectionBaseType!)) {
        _showMultiTimelineDeleteConfirm(context, layers);
      } else {
        if (!await confirmDelete(context)) return;
        if (!context.mounted) return;
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
      if (!await confirmDelete(context, itemName: layer.name)) return;
      if (!context.mounted) return;
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
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.layerPanelMultiDeleteConfirmTitle(count)),
        content: Text(l10n.layerPanelMultiDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _showTimelineDeleteConfirm(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.layerPanelDeleteConfirmTitle(layer.name)),
        content: Text(l10n.layerPanelDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  /// 共通レイヤーの表示範囲を「🔗 名前（開始〜終了）」の形式で要約する（仕様書16）
  String _rangeSummary(AppLocalizations l10n, model.Layer layer) {
    switch (layer.rangeMode) {
      case model.LayerRangeMode.allFrames:
        return l10n.layerPanelRangeAllFrames;
      case model.LayerRangeMode.currentScene:
        return l10n.layerPanelRangeCurrentScene;
      case model.LayerRangeMode.sceneRange:
        if (layer.rangeSceneId == null) return l10n.layerPanelRangeSceneSpecified;
        final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
        final scene = scenes.where((s) => s.id == layer.rangeSceneId).firstOrNull;
        return scene != null ? scene.displayName : l10n.layerPanelRangeSceneSpecified;
      case model.LayerRangeMode.frameRange:
        final s = layer.rangeStart ?? 1;
        final e = layer.rangeEnd ?? s;
        return l10n.layerPanelRangeFrameSpan(s, e);
    }
  }

  void _showTimelineLayerMenu(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    final isCommon = layer.type == model.LayerType.common;
    final isLineart = layer.type == model.LayerType.autoFillLineart;
    // 対応する線画レイヤーを持たない自動塗りレイヤー（仕様書04：線画レイヤーを
    // 削除した後に残った状態）かどうかを判定する。
    final allLayers = context.read<ProjectService>().layersOf(
        widget.projectId, widget.sceneId, widget.frameIndex);
    final isOrphanedAutofill = isOrphanedAutofillLayer(allLayers, layer);
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
                title: Text(isCommon ? l10n.layerPanelMenuFrameRangeChange : l10n.layerPanelMenuRangeChange),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRangeChangeDialog(context, layer);
                },
              ),
            if (isLineart)
              ListTile(
                leading: const Icon(Icons.category),
                title: Text(l10n.layerPanelMenuPartAssign),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPartAssignDialog(context, layer);
                },
              ),
            if (isLineart)
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: Text(l10n.layerPanelMenuRunAutofill),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAutofillDialog(context, layer, isLineartLayer: true);
                },
              ),
            // 線画レイヤーを削除して残った孤立した自動塗りレイヤー（仕様書04）：
            // 領域再判定はできないため、不透明度ロック＋最新色での塗りつぶしのみ実行
            if (isOrphanedAutofill)
              ListTile(
                leading: const Icon(Icons.format_color_fill),
                title: Text(l10n.layerPanelMenuOrphanFill),
                subtitle: Text(l10n.layerPanelMenuOrphanFillSubtitle, style: const TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _runOrphanedAutofill(context, layer);
                },
              ),
            if (!isCommon && !isLineart)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(l10n.layerPanelMenuReplaceMaterial),
                onTap: () {
                  Navigator.pop(ctx);
                  _replaceMaterial(context, layer);
                },
              ),
            if (isCommon)
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.themeDuplicateAction),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<ProjectService>().addLayer(
                    projectId: widget.projectId,
                    sceneId: widget.sceneId,
                    frameIndex: widget.frameIndex,
                    type: model.LayerType.common,
                    name: l10n.layerPanelCopySuffix(layer.name),
                  );
                },
              ),
            if (isCommon)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.commonRename),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context, layer);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
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
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: layer.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonRename),
        content: TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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
            child: Text(l10n.commonChange),
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
    String? confirmLabel,
    void Function(model.LayerRangeMode mode, int start, int end, String? rangeSceneId)? onConfirm,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final resolvedConfirmLabel = confirmLabel ?? l10n.commonOk;
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
          title: Text(title ?? l10n.layerPanelRangeDialogTitle),
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
                        decoration: InputDecoration(labelText: l10n.layerPanelRangeStartFrameLabel, border: const OutlineInputBorder()),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(l10n.layerPanelRangeTilde)),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.layerPanelRangeEndFrameLabel, border: const OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setS(() {
                    startCtrl.text = '1';
                    endCtrl.text = totalFrames > 0 ? totalFrames.toString() : '1';
                  }),
                  child: Text(l10n.layerPanelRangeUseCurrentButton),
                ),
                const Divider(),
                RadioListTile<model.LayerRangeMode>(
                  dense: true,
                  title: Text(l10n.layerPanelRangeAllFrames),
                  value: model.LayerRangeMode.allFrames,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
                RadioListTile<model.LayerRangeMode>(
                  dense: true,
                  title: Text(l10n.layerPanelRangeCurrentScene),
                  value: model.LayerRangeMode.currentScene,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
                RadioListTile<model.LayerRangeMode>(
                  dense: true,
                  title: Text(l10n.layerPanelRangeSceneSpecified),
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
                      decoration: InputDecoration(labelText: l10n.layerPanelRangeTargetSceneLabel, isDense: true),
                      items: scenes
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName)))
                          .toList(),
                      onChanged: (v) => setS(() => sceneId = v),
                    ),
                  ),
                RadioListTile<model.LayerRangeMode>(
                  dense: true,
                  title: Text(l10n.layerPanelRangeFrameRangeLabel),
                  value: model.LayerRangeMode.frameRange,
                  groupValue: mode,
                  onChanged: (v) => setS(() => mode = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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
              child: Text(resolvedConfirmLabel),
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
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.layers),
              title: Text(l10n.layerPanelMenuNormalLayer),
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.normal,
                  (n) => l10n.layerPanelDefaultLayerName(n)); },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: Text(l10n.layerPanelMenuCommonLayer),
              onTap: () { Navigator.pop(ctx); _addCommonLayer(context); },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(l10n.creativePanelFolderButton),
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.folder,
                  (n) => l10n.layerPanelDefaultFolderName(n)); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: Text(l10n.layerPanelMenuLineartLayer),
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.autoFillLineart,
                  (n) => l10n.layerPanelDefaultLineartName(n)); },
            ),
            ListTile(
              leading: const Icon(Icons.palette, color: Colors.green),
              title: Text(l10n.layerPanelMenuAutofillLayer),
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.autoFill,
                  (n) => l10n.layerPanelDefaultAutofillName(n)); },
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
    final l10n = AppLocalizations.of(context)!;
    final layers = context.read<ProjectService>().layersOf(
        widget.projectId, widget.sceneId, widget.frameIndex);
    final visible = _visibleLayers(layers);
    final placeholder = model.Layer(
      id: '', name: '', type: model.LayerType.common,
    );
    _showRangeChangeDialog(
      context,
      placeholder,
      title: l10n.layerPanelCommonRangeTitle,
      confirmLabel: l10n.commonCreate,
      onConfirm: (mode, start, end, rangeSceneId) {
        final ps = context.read<ProjectService>();
        final created = ps.addLayer(
          projectId: widget.projectId,
          sceneId: widget.sceneId,
          frameIndex: widget.frameIndex,
          type: model.LayerType.common,
          name: l10n.layerPanelDefaultCommonName(visible.length + 1),
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

  void _addLayer(BuildContext context, model.LayerType type, String Function(int n) nameBuilder) {
    final layers = context.read<ProjectService>().layersOf(
        widget.projectId, widget.sceneId, widget.frameIndex);
    final visible = _visibleLayers(layers);
    context.read<ProjectService>().addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      type: type,
      name: nameBuilder(visible.length + 1),
    );
    setState(() => _selectedIndex = 0);
  }

  /// レイヤー詳細設定（不透明度・ブレンドモード・ロック・クリッピング等）。
  /// 以前は`_selectedIndex`（パネル下部の共通ボタンからの呼び出し）にのみ
  /// 対応していたが、各レイヤー行の三点メニューから直接[layer]を渡せる
  /// ようにした（ユーザー指示：三点メニューを各レイヤーの右側へ）。
  void _showLayerOptions(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
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
                    Text(l10n.layerPanelOpacityLabel, style: const TextStyle(fontSize: 13)),
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
                    EditableSliderValue(
                      text: '${layer.opacity}%',
                      style: const TextStyle(fontSize: 12),
                      value: layer.opacity, min: 0, max: 100,
                      onChanged: (v) => update((l) => l.copyWith(opacity: v.round())),
                    ),
                  ],
                ),
              ),
              // ブレンドモード
              ListTile(
                title: Text(l10n.autofillPartBlendModeLabel),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _blendModeName(l10n, layer.blendMode),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                  ),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                ]),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlendModeDialog(context, layer, update);
                },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelLockLabel),
                value: layer.isLocked,
                onChanged: (v) { update((l) => l.copyWith(isLocked: v)); Navigator.pop(ctx); },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelOpacityLockLabel),
                value: layer.opacityLocked,
                onChanged: (v) { update((l) => l.copyWith(opacityLocked: v)); Navigator.pop(ctx); },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelClippingBadge),
                subtitle: Text(l10n.layerPanelClippingDescription, style: const TextStyle(fontSize: 11)),
                value: layer.hasClipping,
                onChanged: (v) { update((l) => l.copyWith(hasClipping: v)); Navigator.pop(ctx); },
              ),
              if (layer.type == model.LayerType.normal)
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.blue),
                  title: Text(l10n.layerPanelConvertToCommonLabel),
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
    final l10n = AppLocalizations.of(context)!;
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.layerPanelConvertToCommonLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: Text(l10n.layerPanelConvertOption1Title),
                subtitle: Text(l10n.layerPanelConvertOption1Subtitle, style: const TextStyle(fontSize: 11)),
                value: 0,
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
              ),
              RadioListTile<int>(
                title: Text(l10n.layerPanelConvertOption2Title),
                subtitle: Text(l10n.layerPanelConvertOption2Subtitle, style: const TextStyle(fontSize: 11)),
                value: 1,
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final placeholder = model.Layer(id: '', name: '', type: model.LayerType.common);
                _showRangeChangeDialog(
                  context,
                  placeholder,
                  title: l10n.layerPanelCommonRangeTitle,
                  confirmLabel: l10n.commonCreate,
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
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlendModeDialog(BuildContext context, model.Layer layer,
      void Function(model.Layer Function(model.Layer)) update) {
    final l10n = AppLocalizations.of(context)!;
    const modes = model.LayerBlendMode.values;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillPartBlendModeLabel),
        content: SizedBox(
          width: 280,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: modes.length,
            itemBuilder: (ctx, i) => ListTile(
              dense: true,
              title: Text(_blendModeName(l10n, modes[i]), style: const TextStyle(fontSize: 13)),
              selected: layer.blendMode == modes[i],
              onTap: () {
                update((l) => l.copyWith(blendMode: modes[i]));
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  String _blendModeName(AppLocalizations l10n, model.LayerBlendMode mode) => switch (mode) {
    model.LayerBlendMode.normal      => l10n.blendModeNormal,
    model.LayerBlendMode.multiply    => l10n.blendModeMultiply,
    model.LayerBlendMode.screen      => l10n.blendModeScreen,
    model.LayerBlendMode.overlay     => l10n.blendModeOverlay,
    model.LayerBlendMode.addition    => l10n.blendModeAddition,
    model.LayerBlendMode.subtract    => l10n.blendModeSubtract,
    model.LayerBlendMode.darken      => l10n.blendModeDarken,
    model.LayerBlendMode.lighten     => l10n.blendModeLighten,
    model.LayerBlendMode.colorBurn   => l10n.blendModeColorBurn,
    model.LayerBlendMode.colorDodge  => l10n.blendModeColorDodge,
    model.LayerBlendMode.hardLight   => l10n.blendModeHardLight,
    model.LayerBlendMode.softLight   => l10n.blendModeSoftLight,
    model.LayerBlendMode.difference  => l10n.blendModeDifference,
    model.LayerBlendMode.hue         => l10n.blendModeHue,
    model.LayerBlendMode.saturation  => l10n.blendModeSaturation,
    model.LayerBlendMode.color       => l10n.blendModeColor,
    model.LayerBlendMode.luminosity  => l10n.blendModeLuminosity,
  };

  void _showHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.layerPanelHelpDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.autofillPartBlendModeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.layerPanelHelpBlendModeBody),
              const SizedBox(height: 8),
              Text(l10n.layerPanelClippingBadge, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.layerPanelHelpClippingBody),
              const SizedBox(height: 8),
              Text(l10n.layerPanelCommonLayerLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.layerPanelHelpCommonLayerBody),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  /// [layer] は❗マークが表示された自動塗りレイヤー、または三点メニューから起動した場合は
  /// 自動塗り用線画レイヤー（[isLineartLayer]=true）。実行対象の線画レイヤーを特定してから
  /// ダイアログを表示する。
  void _showAutofillDialog(BuildContext context, model.Layer layer, {bool isLineartLayer = false}) {
    final l10n = AppLocalizations.of(context)!;
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
      // 線画レイヤーを削除して自動塗りレイヤーのみが残っている場合（仕様書04：
      // 「線画レイヤーなし・塗りレイヤーあり」の行）は、参照する線画が無いため
      // 領域の再判定はできない。不透明度ロック＋最新色での塗りつぶしのみを行う。
      if (layer.type == model.LayerType.autoFill && layer.partId != null) {
        _runOrphanedAutofill(context, layer);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.layerPanelAutofillNoLineartSnackbar)),
      );
      return;
    }
    final resolvedLineart = lineartLayer;
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.layerPanelAutofillMethodTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.layerPanelAutofillNote1,
                  style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(l10n.layerPanelAutofillNote2,
                  style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              RadioListTile<int>(
                title: Text(l10n.layerPanelAutofillRepaintTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.layerPanelAutofillRepaintHint, style: const TextStyle(fontSize: 11)),
                    Text(l10n.layerPanelAutofillRepaintNote, style: const TextStyle(fontSize: 11)),
                  ],
                ),
                value: 0, groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
                dense: true,
              ),
              RadioListTile<int>(
                title: Text(l10n.layerPanelAutofillColorUpdateTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.layerPanelAutofillColorUpdateHint, style: const TextStyle(fontSize: 11)),
                    Text(l10n.layerPanelAutofillColorUpdateNote, style: const TextStyle(fontSize: 11)),
                  ],
                ),
                value: 1, groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeAutofill(
                  context,
                  resolvedLineart,
                  selected == 0 ? autofill.AutofillMode.repaint : autofill.AutofillMode.colorUpdate,
                );
              },
              child: Text(l10n.layerPanelExecuteButton),
            ),
          ],
        ),
      ),
    );
  }

  /// 自動塗りエンジンを実行し、結果を対象自動塗りレイヤーのタイルへ書き戻す
  /// （仕様書04）。本処理自体はautofill_batch_runner.dart（タイムラインの
  /// 一括実行とも共通）に集約し、ここではUI固有のエラー案内のみ行う。
  Future<void> _executeAutofill(
      BuildContext context, model.Layer lineartLayer, autofill.AutofillMode mode) async {
    final l10n = AppLocalizations.of(context)!;
    if (lineartLayer.partId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.layerPanelAutofillPartMissingSnackbar)),
      );
      return;
    }
    if (context.read<AutofillPresetService>().findPart(lineartLayer.partId!) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.layerPanelAutofillPresetMissingSnackbar)),
      );
      return;
    }
    await runAutofillForLayer(
      projectService: context.read<ProjectService>(),
      presetService: context.read<AutofillPresetService>(),
      toneService: context.read<ToneService>(),
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      lineartLayer: lineartLayer,
      mode: mode,
    );
    setState(() {});
  }

  /// 対応する自動塗り用線画レイヤーが存在しない自動塗りレイヤー（線画レイヤーを
  /// 削除した後に残った状態）を処理する（仕様書04「4パターンまとめ」：
  /// 「線画レイヤーなし・塗りレイヤーあり」の行）。参照する線画が無いため
  /// 領域の再判定はできず、不透明度ロック＋最新色での塗りつぶしのみを行う
  /// （モード選択の余地がないため確認ダイアログは出さず直接実行する）。
  Future<void> _runOrphanedAutofill(BuildContext context, model.Layer autofillLayer) async {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.read<ProjectService>();
    final presetService = context.read<AutofillPresetService>();
    final result = await runAutofillForOrphanedLayer(
      projectService: projectService,
      presetService: presetService,
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      autofillLayer: autofillLayer,
    );
    if (!context.mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        result == AutofillBatchResult.applied
            ? l10n.layerPanelOrphanFillSuccessSnackbar
            : l10n.layerPanelOrphanFillFailSnackbar)));
  }

  /// 自動塗り用線画レイヤーへプリセットパーツを割り当てるダイアログ（仕様書04：パーツID管理）。
  void _showPartAssignDialog(BuildContext context, model.Layer lineartLayer) {
    final l10n = AppLocalizations.of(context)!;
    final allPresets = context.read<AutofillPresetService>().presets;
    // プロジェクトごとに使用するプリセットが絞り込まれている場合は、その
    // プリセットのみを表示する（ユーザー指示：プリセットが増えるほど
    // パーツ割り当て時の一覧が長くなるため）。未設定（null）の場合は従来
    // 通りすべて表示する。
    final project = context.read<ProjectService>().projects
        .where((p) => p.id == widget.projectId).firstOrNull;
    final enabledIds = project?.enabledAutofillPresetIds;
    final presets = enabledIds == null
        ? allPresets
        : allPresets.where((p) => enabledIds.contains(p.id)).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 400,
          child: presets.isEmpty
              ? Center(child: Text(l10n.autofillPresetEmpty))
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.layerPanelAutofillUpdateHelpTitle),
        content: Text(l10n.layerPanelAutofillUpdateHelpBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
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
    final l10n = AppLocalizations.of(context)!;
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
      SnackBar(content: Text(l10n.layerPanelReplaceMaterialSuccessSnackbar(layer.name))),
    );
  }

  Future<void> _importImage(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
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
      SnackBar(content: Text(l10n.layerPanelImportImageSuccessSnackbar(name))),
    );
  }
}

/// レイヤー一覧の各行に表示するサムネイル（仕様書16：レイヤーパネル）。
///
/// `TileManager.compositeLayerToImage()`は合成結果を内部キャッシュして
/// おり、対象レイヤーのタイルに変更が無ければ再合成せずキャッシュ済み
/// 画像のclone()を返す。そのため呼び出し自体は軽量で、実際に重い
/// フル合成が走るのは対象レイヤーへ描画があった直後のみ。
///
/// 初回表示時に一度だけ生成しキャッシュする。以降の更新は
/// [_LayerPanelState]がストローク確定（UndoManagerのpush）を検知して
/// 現在選択中のレイヤーのみキーを変えて再生成させる仕組みに任せる
/// （「サムネイルはペンを離した瞬間に現在レイヤーのみ更新する」）。
class _LayerThumbnail extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final int frameIndex;
  final String layerId;

  const _LayerThumbnail({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    required this.layerId,
  });

  @override
  State<_LayerThumbnail> createState() => _LayerThumbnailState();
}

class _LayerThumbnailState extends State<_LayerThumbnail> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final ps = context.read<ProjectService>();
    final tileManager = ps.tileManagerOf(widget.projectId);
    final key = ps.tileKeyFor(widget.projectId, widget.sceneId, widget.frameIndex, widget.layerId);
    final full = await tileManager.compositeLayerToImage(key);

    const size = 48; // 24論理px表示・高DPI考慮で2倍解像度
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      full,
      ui.Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint(),
    );
    full.dispose();
    final picture = recorder.endRecording();
    final thumb = await picture.toImage(size, size);
    picture.dispose();

    if (!mounted) {
      thumb.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = thumb);
    old?.dispose();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Container(
      width: 24,
      height: 24,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: image == null ? null : RawImage(image: image, fit: BoxFit.cover),
    );
  }
}
