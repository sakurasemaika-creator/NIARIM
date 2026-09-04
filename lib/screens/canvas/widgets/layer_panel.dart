import 'package:niarim/services/theme_service.dart';

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../engine/autofill_batch_runner.dart';
import '../../../engine/autofill_engine.dart' as autofill;
import '../../../engine/layer_keyframe_engine.dart';
import '../../../engine/tile_manager.dart' show frameLayerKey;
import '../../../engine/undo_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/layer.dart' as model;
import '../../../models/layer_keyframe.dart';
import '../../../services/autofill_preset_service.dart';
import '../../../services/project_service.dart';
import '../../../services/tone_service.dart';
import '../../../widgets/confirm_delete.dart';
import '../../../widgets/dispose_on_unmount.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/first_use_tooltip.dart';
import '../../../widgets/stepped_slider.dart';
import 'layer_keyframe_sheet.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/reorder_index.dart';

class LayerPanel extends StatefulWidget {
  final VoidCallback onClose;
  final String projectId;
  final String sceneId;
  final int frameIndex;
  // PC/DeXモードの常時ドッキング表示時はtrue。閉じるボタンを非表示にする。
  final bool dockedMode;
  // テキストレイヤーをタップした時の編集入口（既存テキストを
  // タップすると編集開始）。nullの場合はテキストレイヤーも通常選択のみ行う。
  final void Function(model.Layer layer)? onEditTextLayer;
  // 実際にペンストロークが書き込まれる対象レイヤーのID
  // （canvas_screen.dartの`_currentLayerId`）。パネル初回表示時、この
  // レイヤーの行を選択状態としてハイライトする。
  final String? currentLayerId;
  // レイヤー行をタップして選択を切り替えたときに呼ばれる（フォルダ行を
  // 除く）。呼び出し元でこの値を`_currentLayerId`へ反映することで、
  // 以降のペンストロークが選択したレイヤーへ書き込まれるようにする。
  final void Function(String layerId)? onLayerSelected;
  // ショートカット（Ctrl+A）からレイヤー全選択を起動するためのトークン。
  // 値が変化するたびに全選択を実行する（メッシュ変形の確定/キャンセル
  // トークンと同じ「値の変化そのものをイベントとして使う」方式）。
  final int selectAllToken;

  const LayerPanel({
    super.key,
    required this.onClose,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
    this.dockedMode = false,
    this.onEditTextLayer,
    this.currentLayerId,
    this.onLayerSelected,
    this.selectAllToken = 0,
  });

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  int _selectedIndex = 0;
  // widget.currentLayerIdに基づく_selectedIndexの初回同期が済んだか
  // （毎buildで探索し直すと、ユーザーがパネル内で選択を変えた直後の
  // buildで上書きしてしまうため、初回のみに限定する）。
  bool _syncedInitialSelection = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  model.LayerType? _selectionBaseType;
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // レイヤーサムネイル更新用（サムネイルはペンを離した瞬間に
  // 現在レイヤーのみ更新する。全レイヤー一括更新はしない）。
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

  @override
  void didUpdateWidget(LayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectAllToken != oldWidget.selectAllToken) {
      final allLayers = context.read<ProjectService>().layersOf(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
      );
      final layers = _visibleLayers(allLayers);
      setState(() {
        _isSelectionMode = true;
        _selectionBaseType = null;
        _selectedIds
          ..clear()
          ..addAll(layers.map((l) => l.id));
      });
    }
  }

  List<model.Layer> _visibleLayers(List<model.Layer> layers) {
    // 選択レイヤー（LayerType.selection）は以前は「内部専用・パネル非表示」
    // だったが、眼鏡断層フィルター等のマスク編集用にユーザーへ常設表示・
    // 通常のレイヤーと同様に操作できるようにする方針へ変更したため、
    // ここでの除外はしない（通常合成からの除外はlayer_compositor.dartの
    // pixelLayerTypes側で引き続き行う）。
    final base = layers.toList();
    final visible = base
        .where((l) => !_isHiddenByCollapsedFolder(l, base))
        .toList();
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
        .where(
          (l) => l.name.toLowerCase().contains(query) || isAncestorOfMatch(l),
        )
        .toList();
  }

  /// フォルダの折りたたみ状態に基づき、祖先フォルダが折りたたまれている場合はtrue
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
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final layers = _visibleLayers(allLayers);

    // パネル初回表示時、実際にペンストロークが書き込まれる対象
    // （widget.currentLayerId）を選択行としてハイライトする（このbuild内
    // のみで完結する直接代入で、setStateは呼ばない。以降ユーザーが別の
    // 行をタップしても、この同期は初回のみなので上書きしない）。
    if (!_syncedInitialSelection) {
      _syncedInitialSelection = true;
      if (widget.currentLayerId != null) {
        final idx = layers.indexWhere((l) => l.id == widget.currentLayerId);
        if (idx >= 0) _selectedIndex = idx;
      }
    }

    // ストロークが確定した（＝ペンが離れた）タイミングを検知し、現在
    // 選択中のレイヤーのサムネイルだけを再生成対象とする。
    final undoCount = context.watch<UndoManager>().undoCount;
    if (_lastUndoCount != undoCount) {
      _lastUndoCount = undoCount;
      if (_selectedIndex >= 0 && _selectedIndex < layers.length) {
        final id = layers[_selectedIndex].id;
        _thumbRevision[id] = (_thumbRevision[id] ?? 0) + 1;
      }
    }

    // Container(color:)はColoredBoxとして描画されるため、内部のListTile
    // （選択中ハイライト・タップ時のインクスプラッシュ）が隠れてしまう
    // （「ListTile background color or ink splashes may be invisible」）。
    // Materialに替えることで、背景色を保ちつつ内部のリップル効果も
    // 正しく表示されるようにする。
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        children: [
          if (!widget.dockedMode) PanelCenterCloseBar(onClose: widget.onClose),
          // ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Text(
                  l10n.layerPanelTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
                const Spacer(),
                // 表示中の全レイヤーをワンタップで結合する（複数選択モードを
                // 使わずに済む一括操作の一つ）。
                IconButton(
                  icon: const Icon(Icons.merge_type, size: 18),
                  onPressed: () => _mergeAllVisibleLayers(context, layers),
                  tooltip: l10n.layerPanelMergeAllVisibleTooltip,
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 18),
                  onPressed: () => _showHelp(context),
                  tooltip: l10n.layerPanelHelpTooltip,
                ),
                IconButton(
                  icon: Icon(
                    _showSearch ? Icons.search_off : Icons.search,
                    size: 18,
                  ),
                  onPressed: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  }),
                  tooltip: l10n.creativePanelSearchTooltip,
                ),
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
                    child: Text(
                      l10n.layerPanelSelectAll,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedIds.clear();
                      _isSelectionMode = false;
                      _selectionBaseType = null;
                    }),
                    child: Text(
                      l10n.layerPanelDeselectAll,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.homeSelectionCount(_selectedIds.length),
                    style: const TextStyle(fontSize: 12),
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
                    label: Text(
                      l10n.layerPanelNewLayerButton,
                      style: const TextStyle(fontSize: 11),
                      // 4ボタンをExpandedで等分するため、標準的な端末幅
                      // （360dp、パネルは約250dp）では1ボタンあたり約60dpしか
                      // 無く、日本語ラベルは1文字ずつ縦に折り返して読めない
                      // 塊になる。折り返さず省略記号で止める
                      // （`test/layer_panel_action_row_test.dart`が監視）。
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _addLayer(
                      context,
                      model.LayerType.normal,
                      (n) => l10n.layerPanelDefaultLayerName(n),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.folder, size: 14),
                    label: Text(
                      l10n.layerPanelNewFolderButton,
                      style: const TextStyle(fontSize: 11),
                      // 4ボタンをExpandedで等分するため、標準的な端末幅
                      // （360dp、パネルは約250dp）では1ボタンあたり約60dpしか
                      // 無く、日本語ラベルは1文字ずつ縦に折り返して読めない
                      // 塊になる。折り返さず省略記号で止める
                      // （`test/layer_panel_action_row_test.dart`が監視）。
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _addLayer(
                      context,
                      model.LayerType.folder,
                      (n) => l10n.layerPanelDefaultFolderName(n),
                    ),
                  ),
                ),
                // 「追加」ボタン（共通レイヤー・自動塗り線画・自動塗りレイヤー等の
                // その他種別）。新規フォルダと画像読み込みの間に配置。
                // 新規レイヤーボタンとアイコンが被らないようlibrary_addを使用。
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.library_add, size: 14),
                    label: Text(
                      l10n.layerPanelAddTooltip,
                      style: const TextStyle(fontSize: 11),
                      // 4ボタンをExpandedで等分するため、標準的な端末幅
                      // （360dp、パネルは約250dp）では1ボタンあたり約60dpしか
                      // 無く、日本語ラベルは1文字ずつ縦に折り返して読めない
                      // 塊になる。折り返さず省略記号で止める
                      // （`test/layer_panel_action_row_test.dart`が監視）。
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _showAddLayerMenu(context),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.photo, size: 14),
                    label: Text(
                      l10n.layerPanelImportImageButton,
                      style: const TextStyle(fontSize: 11),
                      // 4ボタンをExpandedで等分するため、標準的な端末幅
                      // （360dp、パネルは約250dp）では1ボタンあたり約60dpしか
                      // 無く、日本語ラベルは1文字ずつ縦に折り返して読めない
                      // 塊になる。折り返さず省略記号で止める
                      // （`test/layer_panel_action_row_test.dart`が監視）。
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _importImage(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              // 標準の自動ドラッグハンドル（PC/DeXモードなどマウス操作環境で
              // 自動的に行の末尾へ付与される）は、ゴミ箱アイコンなど自前の
              // 末尾アイコン群と重なって表示されてしまっていたため無効化し、
              // 代わりに専用のハンドルアイコンを一番右に明示的に配置する。
              buildDefaultDragHandles: false,
              itemCount: layers.length,
              onReorderItem: (oldIdx, newIdx) {
                if (_searchQuery.trim().isNotEmpty) {
                  return; // 検索中はフィルタ表示のため並び替え不可
                }
                context.read<ProjectService>().reorderLayer(
                  projectId: widget.projectId,
                  sceneId: widget.sceneId,
                  frameIndex: widget.frameIndex,
                  oldIndex: oldIdx,
                  newIndex: preRemovalIndex(oldIdx, newIdx),
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
                          onTap: () =>
                              context.read<ProjectService>().updateLayer(
                                projectId: widget.projectId,
                                sceneId: widget.sceneId,
                                frameIndex: widget.frameIndex,
                                layer: layer.copyWith(
                                  isExpanded: !layer.isExpanded,
                                ),
                              ),
                          child: Icon(
                            layer.isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
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
                          onTap: () =>
                              context.read<ProjectService>().updateLayer(
                                projectId: widget.projectId,
                                sceneId: widget.sceneId,
                                frameIndex: widget.frameIndex,
                                layer: layer.copyWith(
                                  isVisible: !layer.isVisible,
                                ),
                              ),
                          child: Icon(
                            layer.isVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 16,
                          ),
                        ),
                      const SizedBox(width: 4),
                      _layerTypeIcon(context, layer.type),
                      const SizedBox(width: 4),
                      _LayerThumbnail(
                        key: ValueKey(
                          '${layer.id}-${_thumbRevision[layer.id] ?? 0}',
                        ),
                        projectId: widget.projectId,
                        sceneId: widget.sceneId,
                        frameIndex: widget.frameIndex,
                        layerId: layer.id,
                      ),
                    ],
                  ),
                  title: Text(
                    layer.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  subtitle: layer.type == model.LayerType.common
                      ? Text(
                          _rangeSummary(l10n, layer),
                          style: TextStyle(
                            fontSize: 9,
                            color: ThemeService.activeColorScheme.primary,
                          ),
                        )
                      : layer.hasClipping
                      ? Text(
                          l10n.layerPanelClippingBadge,
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 自動塗り更新マーク：初回使用時の吹き出し説明
                      if (layer.needsAutofillUpdate)
                        FirstUseTooltip(
                          tooltipKey: 'autofill_mark',
                          message: l10n.layerPanelAutofillMarkTooltip,
                          child: GestureDetector(
                            onTap: () => _showAutofillDialog(context, layer),
                            onLongPress: () => _showAutofillUpdateHelp(context),
                            child: Icon(
                              Icons.error,
                              color: ThemeService.activeColorScheme.tertiary,
                              size: 14,
                            ),
                          ),
                        ),
                      if (layer.opacityLocked)
                        Icon(
                          Icons.opacity,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      if (layer.isLocked) const Icon(Icons.lock, size: 14),
                      // 三点メニュー・ゴミ箱は各レイヤーの右側に配置する
                      // （対象レイヤーが常に明確になり、選択状態に依存しない）。
                      GestureDetector(
                        onTap: () =>
                            _isTimelineMaterial(layer.type) ||
                                layer.type == model.LayerType.common ||
                                layer.type == model.LayerType.autoFillLineart
                            ? _showTimelineLayerMenu(context, layer)
                            : _showLayerOptions(context, layer),
                        child: const Icon(Icons.more_vert, size: 16),
                      ),
                      const SizedBox(width: 8),
                      // 下のレイヤーとワンタップで結合（複数選択モードを使わずに
                      // 済む一括操作の一つ）。ゴミ箱アイコンのすぐ隣に置くことで
                      // 「レイヤーへの操作」としてまとまって見えるようにしている。
                      GestureDetector(
                        onTap: _layerBelow(layer, layers) != null
                            ? () => _mergeWithLayerBelow(context, layer, layers)
                            : null,
                        child: Icon(
                          Icons.merge_type,
                          size: 16,
                          color: _layerBelow(layer, layers) != null
                              ? null
                              : Theme.of(context).disabledColor,
                        ),
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
                              ? ThemeService.activeColorScheme.error
                              : Theme.of(context).disabledColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ドラッグハンドル（並び替え用）。ゴミ箱等の操作アイコンと
                      // 重ならないよう、常にこの位置に明示的に配置する。
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle, size: 16),
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
                    // フォルダ行は描画対象になり得ないため、実際の描画先
                    // レイヤーの切り替え通知からは除外する（グループ化用の
                    // 見出し行としての選択ハイライトのみ）。
                    if (!_isSelectionMode &&
                        layer.type != model.LayerType.folder) {
                      widget.onLayerSelected?.call(layer.id);
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
          // パネル下部の三点メニュー・ゴミ箱は各レイヤー右側へ移動したため削除した。
          // 「追加」ボタンも上部ショートカット行へ移動済み。削除・結合は
          // 各レイヤー行のボタンとヘッダーの「全レイヤー結合」ボタンへ
          // ワンタップ化したため、複数選択モードはグループ化専用として残す
          // （グループ化は性質上、複数レイヤーの選択が必要なため）。
          if (_isSelectionMode) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 18),
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () =>
                              _setVisibilityForSelected(context, layers, true),
                    tooltip: l10n.layerPanelShowSelectedTooltip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_off, size: 18),
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () =>
                              _setVisibilityForSelected(context, layers, false),
                    tooltip: l10n.layerPanelHideSelectedTooltip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.workspaces_outline, size: 18),
                    onPressed: _selectedIds.length >= 2
                        ? () => _showCreateGroupDialog(context)
                        : null,
                    tooltip: l10n.layerPanelGroupTooltip,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _layerTypeIcon(BuildContext context, model.LayerType type) {
    return switch (type) {
      model.LayerType.autoFillLineart => Icon(
        Icons.edit,
        size: 12,
        color: ThemeService.activeColorScheme.tertiary,
      ),
      model.LayerType.autoFill => Icon(
        Icons.palette,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      model.LayerType.common => Icon(
        Icons.link,
        size: 12,
        color: ThemeService.activeColorScheme.primary,
      ),
      model.LayerType.folder => Icon(
        Icons.folder,
        size: 12,
        color: ThemeService.activeColorScheme.tertiary,
      ),
      model.LayerType.text => Icon(
        Icons.text_fields,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      model.LayerType.timelineImage => Icon(
        Icons.image,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      model.LayerType.timelineVideo => Icon(
        Icons.videocam,
        size: 12,
        color: ThemeService.activeColorScheme.primary,
      ),
      model.LayerType.watermark => Icon(
        Icons.branding_watermark,
        size: 12,
        color: ThemeService.activeColorScheme.secondary,
      ),
      // 選択レイヤーは他の種別と異なり、固定の意味色ではなく、ユーザーが
      // カスタマイズできるテーマの選択色を使う。
      model.LayerType.selection => Icon(
        Icons.highlight_alt,
        size: 12,
        color: Theme.of(context).colorScheme.secondary,
      ),
      _ => const SizedBox(width: 12),
    };
  }

  // 結合可能なレイヤー種別（共通レイヤー・フォルダ・タイムライン
  // 素材は結合不可）。
  static const _mergeableLayerTypesForPanel = {
    model.LayerType.normal,
    model.LayerType.autoFillLineart,
    model.LayerType.autoFill,
  };

  /// このレイヤーのすぐ下にある結合可能なレイヤーを探す（フラット表示上の
  /// 直後の要素。フォルダ・共通レイヤー等は対象外）。見つからなければnull。
  model.Layer? _layerBelow(model.Layer layer, List<model.Layer> layers) {
    if (!_mergeableLayerTypesForPanel.contains(layer.type)) return null;
    final idx = layers.indexWhere((l) => l.id == layer.id);
    if (idx < 0 || idx + 1 >= layers.length) return null;
    final below = layers[idx + 1];
    return _mergeableLayerTypesForPanel.contains(below.type) ? below : null;
  }

  /// このレイヤーとすぐ下のレイヤーをワンタップで結合する。
  Future<void> _mergeWithLayerBelow(
    BuildContext context,
    model.Layer layer,
    List<model.Layer> layers,
  ) async {
    final below = _layerBelow(layer, layers);
    if (below == null) return;
    await context.read<ProjectService>().mergeLayers(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerIds: [layer.id, below.id],
    );
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
  }

  /// 複数選択モードで選択中のレイヤーを一括で表示・非表示にする
  /// （タスク#147：複数選択時の全表示・全非表示ボタン）。
  void _setVisibilityForSelected(
    BuildContext context,
    List<model.Layer> layers,
    bool visible,
  ) {
    final projectService = context.read<ProjectService>();
    for (final layer in layers) {
      if (!_selectedIds.contains(layer.id) || layer.isVisible == visible) {
        continue;
      }
      projectService.updateLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layer: layer.copyWith(isVisible: visible),
      );
    }
  }

  /// 表示中（isVisible）の結合可能なレイヤーを全てワンタップで結合する。
  Future<void> _mergeAllVisibleLayers(
    BuildContext context,
    List<model.Layer> layers,
  ) async {
    final ids = layers
        .where(
          (l) => l.isVisible && _mergeableLayerTypesForPanel.contains(l.type),
        )
        .map((l) => l.id)
        .toList();
    if (ids.length < 2) return;
    await context.read<ProjectService>().mergeLayers(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      layerIds: ids,
    );
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
  }

  /// 選択中の複数レイヤーをグループ化する（複数レイヤーを1つのキーフレームで
  /// まとめて動かす機能）。名前を入力後、すぐにグループのキーフレーム編集
  /// シートを開き、そのまま動きを設定できるようにする。
  void _showCreateGroupDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(
      text: l10n.layerPanelGroupDefaultName,
    );
    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: nameCtrl,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.layerPanelGroupTooltip),
          content: TextField(controller: nameCtrl, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final ids = _selectedIds.toList();
                final name = nameCtrl.text.trim().isEmpty
                    ? l10n.layerPanelGroupDefaultName
                    : nameCtrl.text.trim();
                final group = context.read<ProjectService>().addLayerGroup(
                  widget.projectId,
                  widget.sceneId,
                  name,
                  ids,
                );
                Navigator.pop(ctx);
                setState(() {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                  _selectionBaseType = null;
                });
                final tm = context.read<ProjectService>().tileManagerOf(
                  widget.projectId,
                );
                showLayerGroupKeyframeSheet(
                  context,
                  groupName: group.name,
                  initialKeyframes: group.keyframes,
                  currentFrame: widget.frameIndex,
                  totalFrames:
                      context
                          .read<ProjectService>()
                          .sceneOf(widget.projectId, widget.sceneId)
                          ?.frames
                          .length ??
                      1,
                  canvasWidth: tm.canvasWidth,
                  canvasHeight: tm.canvasHeight,
                  onChanged: (kfs) =>
                      context.read<ProjectService>().updateLayerGroup(
                        widget.projectId,
                        widget.sceneId,
                        group.copyWith(keyframes: kfs),
                      ),
                );
              },
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }

  bool _isTimelineMaterial(model.LayerType type) =>
      type == model.LayerType.timelineImage ||
      type == model.LayerType.timelineVideo ||
      type == model.LayerType.watermark;

  /// [layer]を各レイヤー行のゴミ箱アイコンから単体削除できるかどうか
  /// （最後の1枚の通常レイヤーは削除不可、という既存の制約を踏襲）。
  bool _canDeleteLayerRow(model.Layer layer, List<model.Layer> layers) {
    if (layer.type == model.LayerType.normal) {
      return layers.where((l) => l.type == model.LayerType.normal).length > 1;
    }
    return true;
  }

  /// 各レイヤー行のゴミ箱アイコンからの単体削除（三点メニュー・
  /// ゴミ箱は各レイヤーの右側に配置）。タイムライン素材は既存通り確認ダイアログ
  /// を経由し、共通レイヤーは表示範囲のトリミング（タスク#148）、
  /// それ以外は即時削除する。
  Future<void> _deleteLayerRow(
    BuildContext context,
    model.Layer layer,
    List<model.Layer> layers,
  ) async {
    if (_isTimelineMaterial(layer.type)) {
      _showTimelineDeleteConfirm(context, layer);
      return;
    }
    if (layer.type == model.LayerType.common) {
      await _deleteCommonLayerAtCurrentFrame(context, layer);
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
      if (_selectedIndex >= layers.length - 1) {
        _selectedIndex = layers.length - 2;
      }
      if (_selectedIndex < 0) _selectedIndex = 0;
    });
  }

  /// 共通レイヤーの「このフレームだけ削除」（タスク#148）。共通レイヤーは
  /// 単一の連続した表示範囲（rangeStart〜rangeEnd）でしか表せないため、
  /// 現在表示中のフレームが範囲の端（先頭・末尾）ならその1フレーム分だけ
  /// 範囲を狭め、範囲が1フレームしかなければ通常通りレイヤー自体を削除する。
  /// 範囲の途中のフレームでは、連続区間を保てなくなるため「ここより前を
  /// 残す」「ここより後を残す」をユーザーに選ばせる。
  Future<void> _deleteCommonLayerAtCurrentFrame(
    BuildContext context,
    model.Layer layer,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final range = _effectiveCommonRange(layer);
    final current = widget.frameIndex;
    final projectService = context.read<ProjectService>();

    void applyRange(({int start, int end}) r) {
      projectService.updateLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layer: layer.copyWith(
          rangeMode: model.LayerRangeMode.frameRange,
          rangeStart: r.start + 1,
          rangeEnd: r.end + 1,
          rangeSceneId: null,
        ),
      );
    }

    Future<void> deleteEntirely() async {
      if (!await confirmDelete(context, itemName: layer.name)) return;
      if (!context.mounted) return;
      projectService.removeLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: widget.frameIndex,
        layerId: layer.id,
      );
    }

    // このフレームが範囲外（通常はここへ来ないはずだが念のため）の場合も、
    // レイヤー自体を通常削除する。
    if (current < range.start || current > range.end) {
      await deleteEntirely();
      return;
    }

    final trimmed = model.trimCommonLayerRange(
      start: range.start,
      end: range.end,
      frameIndex: current,
    );
    // 範囲が1フレームのみ（trimCommonLayerRangeがnullを返す境界ケース）。
    if (range.start >= range.end) {
      await deleteEntirely();
      return;
    }
    if (trimmed != null) {
      // 先頭または末尾フレーム：一意に範囲が縮む。
      if (!await confirmDelete(context, itemName: layer.name)) return;
      if (!context.mounted) return;
      applyRange(trimmed);
      return;
    }

    // 範囲の途中：連続区間を保てないため、どちらを残すか選ばせる。
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.layerPanelCommonDeleteMidDialogTitle(layer.name)),
        content: Text(l10n.layerPanelCommonDeleteMidDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keepBefore'),
            child: Text(l10n.layerPanelCommonDeleteKeepBeforeButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'keepAfter'),
            child: Text(l10n.layerPanelCommonDeleteKeepAfterButton),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final resolved = model.trimCommonLayerRange(
      start: range.start,
      end: range.end,
      frameIndex: current,
      keepBefore: choice == 'keepBefore',
    );
    if (resolved != null) applyRange(resolved);
  }

  void _showTimelineDeleteConfirm(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.layerPanelDeleteConfirmTitle(layer.name)),
        content: Text(l10n.layerPanelDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeService.activeColorScheme.error,
            ),
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

  /// 共通レイヤーの実際の表示範囲（現在のシーン内、0始まり）を計算する。
  /// timeline_screen.dartの_buildCommonLayerTrackと同じロジック
  /// （タスク#148：フレーム内削除での長さ変更のために、フレームパネル側
  /// でも同じ計算が必要になったため複製）。
  ({int start, int end}) _effectiveCommonRange(model.Layer layer) {
    final total = context.read<ProjectService>().frameCount(
      widget.projectId,
      widget.sceneId,
    );
    switch (layer.rangeMode) {
      case model.LayerRangeMode.allFrames:
      case model.LayerRangeMode.currentScene:
      case model.LayerRangeMode.sceneRange:
        return (start: 0, end: (total - 1).clamp(0, total - 1));
      case model.LayerRangeMode.frameRange:
        final start = ((layer.rangeStart ?? 1) - 1).clamp(0, total - 1);
        final end = ((layer.rangeEnd ?? start + 1) - 1).clamp(start, total - 1);
        return (start: start, end: end);
    }
  }

  /// 共通レイヤーの表示範囲を「リンクアイコン 名前（開始〜終了）」の形式で要約する
  String _rangeSummary(AppLocalizations l10n, model.Layer layer) {
    switch (layer.rangeMode) {
      case model.LayerRangeMode.allFrames:
        return l10n.layerPanelRangeAllFrames;
      case model.LayerRangeMode.currentScene:
        return l10n.layerPanelRangeCurrentScene;
      case model.LayerRangeMode.sceneRange:
        if (layer.rangeSceneId == null) {
          return l10n.layerPanelRangeSceneSpecified;
        }
        final scenes = context.read<ProjectService>().scenesOf(
          widget.projectId,
        );
        final scene = scenes
            .where((s) => s.id == layer.rangeSceneId)
            .firstOrNull;
        return scene != null
            ? scene.displayName
            : l10n.layerPanelRangeSceneSpecified;
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
    // 対応する線画レイヤーを持たない自動塗りレイヤー（線画レイヤーを
    // 削除した後に残った状態）かどうかを判定する。
    final allLayers = context.read<ProjectService>().layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final isOrphanedAutofill = isOrphanedAutofillLayer(allLayers, layer);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                layer.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
            ),
            if (!isLineart)
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(
                  isCommon
                      ? l10n.layerPanelMenuFrameRangeChange
                      : l10n.layerPanelMenuRangeChange,
                ),
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
            // 線画レイヤーを削除して残った孤立した自動塗りレイヤー：
            // 領域再判定はできないため、不透明度ロック＋最新色での塗りつぶしのみ実行
            if (isOrphanedAutofill)
              ListTile(
                leading: const Icon(Icons.format_color_fill),
                title: Text(l10n.layerPanelMenuOrphanFill),
                subtitle: Text(
                  l10n.layerPanelMenuOrphanFillSubtitle,
                  style: const TextStyle(fontSize: 11),
                ),
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
              leading: Icon(
                Icons.delete,
                color: ThemeService.activeColorScheme.error,
              ),
              title: Text(
                l10n.commonDelete,
                style: TextStyle(color: ThemeService.activeColorScheme.error),
              ),
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
      builder: (ctx) => DisposeOnUnmount(
        controller: nameCtrl,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.commonRename),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
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
      ),
    );
  }

  /// 表示範囲設定ダイアログ（共通レイヤー・タイムライン素材レイヤー）。
  /// 既存レイヤーの変更（[onConfirm]省略時はupdateLayerを直接呼ぶ）・新規作成時の
  /// 設定（[onConfirm]を渡すとその関数へ結果を渡すのみで自動更新しない）の両方に使う。
  void _showRangeChangeDialog(
    BuildContext context,
    model.Layer layer, {
    String? title,
    String? confirmLabel,
    void Function(
      model.LayerRangeMode mode,
      int start,
      int end,
      String? rangeSceneId,
    )?
    onConfirm,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final resolvedConfirmLabel = confirmLabel ?? l10n.commonOk;
    final ps = context.read<ProjectService>();
    final totalFrames = ps.frameCount(widget.projectId, widget.sceneId);
    final scenes = ps.scenesOf(widget.projectId);
    final startCtrl = TextEditingController(
      text: (layer.rangeStart ?? 1).toString(),
    );
    final endCtrl = TextEditingController(
      text: (layer.rangeEnd ?? (totalFrames > 0 ? totalFrames : 1)).toString(),
    );
    model.LayerRangeMode mode = layer.rangeMode;
    String? sceneId = layer.rangeSceneId ?? widget.sceneId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(title ?? l10n.layerPanelRangeDialogTitle),
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （groupValue/onChangedはFlutter 3.32で非推奨）。
          content: RadioGroup<model.LayerRangeMode>(
            groupValue: mode,
            onChanged: (v) => setS(() => mode = v!),
            child: SingleChildScrollView(
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
                          decoration: InputDecoration(
                            labelText: l10n.layerPanelRangeStartFrameLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(l10n.layerPanelRangeTilde),
                      ),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.layerPanelRangeEndFrameLabel,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setS(() {
                      startCtrl.text = '1';
                      endCtrl.text = totalFrames > 0
                          ? totalFrames.toString()
                          : '1';
                    }),
                    child: Text(l10n.layerPanelRangeUseCurrentButton),
                  ),
                  const Divider(),
                  RadioListTile<model.LayerRangeMode>(
                    dense: true,
                    title: Text(l10n.layerPanelRangeAllFrames),
                    value: model.LayerRangeMode.allFrames,
                  ),
                  RadioListTile<model.LayerRangeMode>(
                    dense: true,
                    title: Text(l10n.layerPanelRangeCurrentScene),
                    value: model.LayerRangeMode.currentScene,
                  ),
                  RadioListTile<model.LayerRangeMode>(
                    dense: true,
                    title: Text(l10n.layerPanelRangeSceneSpecified),
                    value: model.LayerRangeMode.sceneRange,
                  ),
                  if (mode == model.LayerRangeMode.sceneRange)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 8,
                        bottom: 8,
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: scenes.any((s) => s.id == sceneId)
                            ? sceneId
                            : scenes.firstOrNull?.id,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.layerPanelRangeTargetSceneLabel,
                          isDense: true,
                        ),
                        items: scenes
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setS(() => sceneId = v),
                      ),
                    ),
                  RadioListTile<model.LayerRangeMode>(
                    dense: true,
                    title: Text(l10n.layerPanelRangeFrameRangeLabel),
                    value: model.LayerRangeMode.frameRange,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final start = int.tryParse(startCtrl.text) ?? 1;
                final end = int.tryParse(endCtrl.text) ?? start;
                final resolvedSceneId = mode == model.LayerRangeMode.sceneRange
                    ? sceneId
                    : null;
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
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.normal,
                  (n) => l10n.layerPanelDefaultLayerName(n),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.link,
                color: ThemeService.activeColorScheme.primary,
              ),
              title: Text(l10n.layerPanelMenuCommonLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addCommonLayer(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(l10n.creativePanelFolderButton),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.folder,
                  (n) => l10n.layerPanelDefaultFolderName(n),
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: ThemeService.activeColorScheme.tertiary,
              ),
              title: Text(l10n.layerPanelMenuLineartLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.autoFillLineart,
                  (n) => l10n.layerPanelDefaultLineartName(n),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.palette,
                color: ThemeService.activeColorScheme.secondary,
              ),
              title: Text(l10n.layerPanelMenuAutofillLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.autoFill,
                  (n) => l10n.layerPanelDefaultAutofillName(n),
                );
              },
            ),
            // 選択レイヤー（眼鏡断層フィルター等、範囲を指定してかけるフィルター用の
            // マスク専用レイヤー）。通常合成には含まれず、テーマの選択色で
            // 半透明タイントしてキャンバス上に重ねて表示する。
            ListTile(
              leading: Icon(
                Icons.highlight_alt,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: Text(l10n.layerPanelMenuSelectionLayer),
              onTap: () {
                Navigator.pop(ctx);
                _addLayer(
                  context,
                  model.LayerType.selection,
                  (n) => l10n.layerPanelDefaultSelectionName(n),
                );
              },
            ),
            // テキストレイヤーはテキストツールからキャンバスタップで自動生成するため追加しない
          ],
        ),
      ),
    );
  }

  /// 共通レイヤーの新規追加。追加前に表示範囲
  /// （共通レイヤー範囲）を設定するダイアログを表示してから作成する。
  void _addCommonLayer(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final layers = context.read<ProjectService>().layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final visible = _visibleLayers(layers);
    final placeholder = model.Layer(
      id: '',
      name: '',
      type: model.LayerType.common,
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
            rangeMode: mode,
            rangeStart: start,
            rangeEnd: end,
            rangeSceneId: rangeSceneId,
          ),
        );
        setState(() => _selectedIndex = 0);
        widget.onLayerSelected?.call(created.id);
      },
    );
  }

  void _addLayer(
    BuildContext context,
    model.LayerType type,
    String Function(int n) nameBuilder,
  ) {
    final layers = context.read<ProjectService>().layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final visible = _visibleLayers(layers);
    final created = context.read<ProjectService>().addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      type: type,
      name: nameBuilder(visible.length + 1),
    );
    setState(() => _selectedIndex = 0);
    // 追加したレイヤーへそのまま描き始められるよう、実際の描画対象も
    // 新規レイヤーへ切り替える（フォルダは描画対象になり得ないため除外）。
    if (type != model.LayerType.folder) {
      widget.onLayerSelected?.call(created.id);
    }
  }

  /// [frameIndex]時点のキーフレーム値（拡大縮小・回転）を書き換えた
  /// キーフレーム一覧を返す。キーフレームが1つも無い、または1つだけの
  /// 状態であれば、単一のキーフレーム値がすべてのフレームへクランプ
  /// 適用される（[LayerKeyframeEngine.valueAt]）ため、この操作は事実上
  /// レイヤー（素材）全体への一括適用になる。既にアニメーション用の
  /// 複数キーフレームが打たれている場合は、現在フレーム位置の値だけを
  /// 書き換える（既存のキーフレーム編集シートと同じ挙動）。
  List<LayerKeyframe> _updateKeyframeAtCurrentFrame(
    List<LayerKeyframe> keyframes,
    int frameIndex,
    LayerKeyframe Function(LayerKeyframe base) modifier,
  ) {
    final base = LayerKeyframeEngine()
        .valueAt(keyframes, frameIndex)
        .copyWith(frameIndex: frameIndex);
    final updated = modifier(base);
    final list = [...keyframes];
    final idx = list.indexWhere((k) => k.frameIndex == frameIndex);
    if (idx >= 0) {
      list[idx] = updated;
    } else {
      list.add(updated);
    }
    return list;
  }

  /// レイヤー詳細設定（不透明度・ブレンドモード・ロック・クリッピング等）。
  /// パネル下部の共通ボタン（`_selectedIndex`使用）と、各レイヤー行の
  /// 三点メニュー（[layer]を直接指定）の両方から呼び出せる。
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
                child: Text(
                  layer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kuramubon',
                    fontFamilyFallback: kHeadingFontFallback,
                  ),
                ),
              ),
              // 不透明度スライダー
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      l10n.layerPanelOpacityLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (ctx, setS) => SteppedSlider(
                          value: layer.opacity.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
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
                      value: layer.opacity,
                      min: 0,
                      max: 100,
                      onChanged: (v) =>
                          update((l) => l.copyWith(opacity: v.round())),
                    ),
                  ],
                ),
              ),
              // 拡大縮小・回転スライダー：不透明度と同様、レイヤー
              // （素材）全体へ一気に適用する操作として直接編集できる
              // ようにする（アニメーション用のキーフレームを個別に
              // 打ちたい場合は引き続きキーフレーム設定シートを使う）。
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      l10n.layerKeyframeScaleLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (ctx, setS) {
                          final current = LayerKeyframeEngine()
                              .valueAt(layer.keyframes, widget.frameIndex)
                              .scale;
                          return SteppedSlider(
                            value: current,
                            min: 0.1,
                            max: 3.0,
                            divisions: 29,
                            label: current.toStringAsFixed(2),
                            onChanged: (v) {
                              setS(() {});
                              update(
                                (l) => l.copyWith(
                                  keyframes: _updateKeyframeAtCurrentFrame(
                                    l.keyframes,
                                    widget.frameIndex,
                                    (base) => base.copyWith(scale: v),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      l10n.layerKeyframeRotationLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (ctx, setS) {
                          final current = LayerKeyframeEngine()
                              .valueAt(layer.keyframes, widget.frameIndex)
                              .rotation;
                          return SteppedSlider(
                            value: current,
                            min: -180,
                            max: 180,
                            divisions: 360,
                            label: '${current.round()}°',
                            onChanged: (v) {
                              setS(() {});
                              update(
                                (l) => l.copyWith(
                                  keyframes: _updateKeyframeAtCurrentFrame(
                                    l.keyframes,
                                    widget.frameIndex,
                                    (base) => base.copyWith(rotation: v),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // ブレンドモード
              ListTile(
                title: Text(l10n.autofillPartBlendModeLabel),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _blendModeName(l10n, layer.blendMode),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlendModeDialog(context, layer, update);
                },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelLockLabel),
                value: layer.isLocked,
                onChanged: (v) {
                  update((l) => l.copyWith(isLocked: v));
                  Navigator.pop(ctx);
                },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelOpacityLockLabel),
                value: layer.opacityLocked,
                onChanged: (v) {
                  update((l) => l.copyWith(opacityLocked: v));
                  Navigator.pop(ctx);
                },
              ),
              SwitchListTile(
                title: Text(l10n.layerPanelClippingBadge),
                subtitle: Text(
                  l10n.layerPanelClippingDescription,
                  style: const TextStyle(fontSize: 11),
                ),
                value: layer.hasClipping,
                onChanged: (v) {
                  update((l) => l.copyWith(hasClipping: v));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.animation_outlined),
                title: Text(l10n.layerPanelKeyframeLabel),
                trailing: layer.keyframes.isEmpty
                    ? null
                    : Icon(
                        Icons.diamond,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                onTap: () {
                  Navigator.pop(ctx);
                  final tm = context.read<ProjectService>().tileManagerOf(
                    widget.projectId,
                  );
                  showLayerKeyframeSheet(
                    context,
                    layer: layer,
                    currentFrame: widget.frameIndex,
                    totalFrames:
                        context
                            .read<ProjectService>()
                            .sceneOf(widget.projectId, widget.sceneId)
                            ?.frames
                            .length ??
                        1,
                    canvasWidth: tm.canvasWidth,
                    canvasHeight: tm.canvasHeight,
                    onChanged: (kfs) =>
                        update((l) => l.copyWith(keyframes: kfs)),
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final group = context
                      .read<ProjectService>()
                      .groupContainingLayer(
                        widget.projectId,
                        widget.sceneId,
                        layer.id,
                      );
                  if (group == null) return const SizedBox.shrink();
                  return ListTile(
                    leading: const Icon(Icons.workspaces_outline),
                    title: Text(
                      l10n.layerPanelGroupMembershipLabel(group.name),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        final ps = context.read<ProjectService>();
                        final remaining = group.memberLayerIds
                            .where((id) => id != layer.id)
                            .toList();
                        if (remaining.isEmpty) {
                          ps.removeLayerGroup(
                            widget.projectId,
                            widget.sceneId,
                            group.id,
                          );
                        } else {
                          ps.updateLayerGroup(
                            widget.projectId,
                            widget.sceneId,
                            group.copyWith(memberLayerIds: remaining),
                          );
                        }
                        Navigator.pop(ctx);
                      },
                      child: Text(l10n.layerPanelGroupLeaveAction),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      final tm = context.read<ProjectService>().tileManagerOf(
                        widget.projectId,
                      );
                      showLayerGroupKeyframeSheet(
                        context,
                        groupName: group.name,
                        initialKeyframes: group.keyframes,
                        currentFrame: widget.frameIndex,
                        totalFrames:
                            context
                                .read<ProjectService>()
                                .sceneOf(widget.projectId, widget.sceneId)
                                ?.frames
                                .length ??
                            1,
                        canvasWidth: tm.canvasWidth,
                        canvasHeight: tm.canvasHeight,
                        onChanged: (kfs) =>
                            context.read<ProjectService>().updateLayerGroup(
                              widget.projectId,
                              widget.sceneId,
                              group.copyWith(keyframes: kfs),
                            ),
                      );
                    },
                  );
                },
              ),
              if (layer.type == model.LayerType.normal)
                ListTile(
                  leading: Icon(
                    Icons.link,
                    color: ThemeService.activeColorScheme.primary,
                  ),
                  title: Text(l10n.layerPanelConvertToCommonLabel),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showConvertToCommonDialog(context, layer);
                  },
                ),
              // 明度で透過：下描きレイヤーに誤って線画を描いてしまった時などに、
              // 白い部分ほど透明になるようレイヤーの不透明度を作り直す
              // 色を保つ「カラー」と、輝度だけで単純に
              // 透過させる「グレー」の2種類。元に戻せない操作のため、
              // Undoには対応していない（このメニューの他の破壊的操作＝
              // 結合と同様の扱い）。
              if (layer.type == model.LayerType.normal)
                ListTile(
                  leading: const Icon(Icons.opacity),
                  title: Text(l10n.layerPanelBrightnessToAlphaLabel),
                  subtitle: Text(
                    l10n.layerPanelBrightnessToAlphaHint,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _applyBrightnessToAlpha(
                            context,
                            layer,
                            grayMode: false,
                          );
                        },
                        child: Text(
                          l10n.layerPanelBrightnessToAlphaColorButton,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _applyBrightnessToAlpha(
                            context,
                            layer,
                            grayMode: true,
                          );
                        },
                        child: Text(l10n.layerPanelBrightnessToAlphaGrayButton),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 「明度で透過」を実行し、サムネイル・プレビューを更新する。
  Future<void> _applyBrightnessToAlpha(
    BuildContext context,
    model.Layer layer, {
    required bool grayMode,
  }) async {
    final projectService = context.read<ProjectService>();
    final tileManager = projectService.tileManagerOf(widget.projectId);
    await tileManager.applyBrightnessToAlpha(
      frameLayerKey(widget.sceneId, widget.frameIndex, layer.id),
      grayMode: grayMode,
    );
    if (!mounted) return;
    setState(
      () => _thumbRevision[layer.id] = (_thumbRevision[layer.id] ?? 0) + 1,
    );
  }

  /// 共通レイヤー化ダイアログ。「現在レイヤーを共通化」／
  /// 「表示中レイヤーを複製して全統合して共通化」の2択→表示範囲設定→変換実行。
  void _showConvertToCommonDialog(BuildContext context, model.Layer layer) {
    final l10n = AppLocalizations.of(context)!;
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.layerPanelConvertToCommonLabel),
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （groupValue/onChangedはFlutter 3.32で非推奨）。
          content: RadioGroup<int>(
            groupValue: selected,
            onChanged: (v) => setS(() => selected = v!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<int>(
                  title: Text(l10n.layerPanelConvertOption1Title),
                  subtitle: Text(
                    l10n.layerPanelConvertOption1Subtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: 0,
                ),
                RadioListTile<int>(
                  title: Text(l10n.layerPanelConvertOption2Title),
                  subtitle: Text(
                    l10n.layerPanelConvertOption2Subtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final placeholder = model.Layer(
                  id: '',
                  name: '',
                  type: model.LayerType.common,
                );
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

  void _showBlendModeDialog(
    BuildContext context,
    model.Layer layer,
    void Function(model.Layer Function(model.Layer)) update,
  ) {
    final l10n = AppLocalizations.of(context)!;
    const modes = model.LayerBlendMode.values;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // popup-standard-close: compact top-right close affordance.
        iconPadding: const EdgeInsets.fromLTRB(0, 4, 4, 0),
        icon: Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        title: Text(l10n.autofillPartBlendModeLabel),
        content: SizedBox(
          width: 280,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: modes.length,
            itemBuilder: (ctx, i) => ListTile(
              dense: true,
              title: Text(
                _blendModeName(l10n, modes[i]),
                style: const TextStyle(fontSize: 13),
              ),
              selected: layer.blendMode == modes[i],
              onTap: () {
                update((l) => l.copyWith(blendMode: modes[i]));
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
        actions: [],
      ),
    );
  }

  String _blendModeName(AppLocalizations l10n, model.LayerBlendMode mode) =>
      switch (mode) {
        model.LayerBlendMode.normal => l10n.blendModeNormal,
        model.LayerBlendMode.multiply => l10n.blendModeMultiply,
        model.LayerBlendMode.screen => l10n.blendModeScreen,
        model.LayerBlendMode.overlay => l10n.blendModeOverlay,
        model.LayerBlendMode.addition => l10n.blendModeAddition,
        model.LayerBlendMode.subtract => l10n.blendModeSubtract,
        model.LayerBlendMode.darken => l10n.blendModeDarken,
        model.LayerBlendMode.lighten => l10n.blendModeLighten,
        model.LayerBlendMode.colorBurn => l10n.blendModeColorBurn,
        model.LayerBlendMode.colorDodge => l10n.blendModeColorDodge,
        model.LayerBlendMode.hardLight => l10n.blendModeHardLight,
        model.LayerBlendMode.softLight => l10n.blendModeSoftLight,
        model.LayerBlendMode.difference => l10n.blendModeDifference,
        model.LayerBlendMode.hue => l10n.blendModeHue,
        model.LayerBlendMode.saturation => l10n.blendModeSaturation,
        model.LayerBlendMode.color => l10n.blendModeColor,
        model.LayerBlendMode.luminosity => l10n.blendModeLuminosity,
      };

  void _showHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // popup-standard-close: compact top-right close affordance.
        iconPadding: const EdgeInsets.fromLTRB(0, 4, 4, 0),
        icon: Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        title: Text(l10n.layerPanelHelpDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.autofillPartBlendModeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              Text(l10n.layerPanelHelpBlendModeBody),
              const SizedBox(height: 8),
              Text(
                l10n.layerPanelClippingBadge,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              Text(l10n.layerPanelHelpClippingBody),
              const SizedBox(height: 8),
              Text(
                l10n.layerPanelCommonLayerLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              Text(l10n.layerPanelHelpCommonLayerBody),
            ],
          ),
        ),
        actions: [],
      ),
    );
  }

  /// [layer] は警告アイコンが表示された自動塗りレイヤー、または三点メニューから起動した場合は
  /// 自動塗り用線画レイヤー（[isLineartLayer]=true）。実行対象の線画レイヤーを特定してから
  /// ダイアログを表示する。
  void _showAutofillDialog(
    BuildContext context,
    model.Layer layer, {
    bool isLineartLayer = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final projectService = context.read<ProjectService>();
    final allLayers = projectService.layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    model.Layer? lineartLayer;
    if (isLineartLayer) {
      lineartLayer = layer;
    } else {
      final idx = allLayers.indexWhere((l) => l.id == layer.id);
      if (idx > 0 &&
          allLayers[idx - 1].type == model.LayerType.autoFillLineart) {
        lineartLayer = allLayers[idx - 1];
      }
    }
    if (lineartLayer == null) {
      // 線画レイヤーを削除して自動塗りレイヤーのみが残っている場合（
      // 「線画レイヤーなし・塗りレイヤーあり」の状態）は、参照する線画が無いため
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
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （groupValue/onChangedはFlutter 3.32で非推奨）。
          content: RadioGroup<int>(
            groupValue: selected,
            onChanged: (v) => setS(() => selected = v!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.layerPanelAutofillNote1,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.layerPanelAutofillNote2,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                RadioListTile<int>(
                  title: Text(l10n.layerPanelAutofillRepaintTitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.layerPanelAutofillRepaintHint,
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        l10n.layerPanelAutofillRepaintNote,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  value: 0,
                  dense: true,
                ),
                RadioListTile<int>(
                  title: Text(l10n.layerPanelAutofillColorUpdateTitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.layerPanelAutofillColorUpdateHint,
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        l10n.layerPanelAutofillColorUpdateNote,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  value: 1,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeAutofill(
                  context,
                  resolvedLineart,
                  selected == 0
                      ? autofill.AutofillMode.repaint
                      : autofill.AutofillMode.colorUpdate,
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
  /// 本処理自体はautofill_batch_runner.dart（タイムラインの
  /// 一括実行とも共通）に集約し、ここではUI固有のエラー案内のみ行う。
  Future<void> _executeAutofill(
    BuildContext context,
    model.Layer lineartLayer,
    autofill.AutofillMode mode,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (lineartLayer.partId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.layerPanelAutofillPartMissingSnackbar)),
      );
      return;
    }
    if (context.read<AutofillPresetService>().findPart(lineartLayer.partId!) ==
        null) {
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
  /// 削除した後に残った状態）を処理する。
  /// 「線画レイヤーなし・塗りレイヤーあり」の行。参照する線画が無いため
  /// 領域の再判定はできず、不透明度ロック＋最新色での塗りつぶしのみを行う
  /// （モード選択の余地がないため確認ダイアログは出さず直接実行する）。
  Future<void> _runOrphanedAutofill(
    BuildContext context,
    model.Layer autofillLayer,
  ) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == AutofillBatchResult.applied
              ? l10n.layerPanelOrphanFillSuccessSnackbar
              : l10n.layerPanelOrphanFillFailSnackbar,
        ),
      ),
    );
  }

  /// 自動塗り用線画レイヤーへプリセットパーツを割り当てるダイアログ（パーツID管理）。
  void _showPartAssignDialog(BuildContext context, model.Layer lineartLayer) {
    final l10n = AppLocalizations.of(context)!;
    final allPresets = context.read<AutofillPresetService>().presets;
    // プロジェクトごとに使用するプリセットが絞り込まれている場合は、その
    // プリセットのみを表示する（プリセットが増えるほど
    // パーツ割り当て時の一覧が長くなるため）。未設定（null）の場合は従来
    // 通りすべて表示する。
    final project = context
        .read<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
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
                        child: Text(
                          preset.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kuramubon',
                            fontFamilyFallback: kHeadingFontFallback,
                          ),
                        ),
                      ),
                      for (final part in preset.parts)
                        ListTile(
                          dense: true,
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(part.color),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ThemeService
                                    .activeColorScheme
                                    .onSurfaceVariant,
                              ),
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
        // popup-standard-close: compact top-right close affordance.
        iconPadding: const EdgeInsets.fromLTRB(0, 4, 4, 0),
        icon: Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        title: Text(l10n.layerPanelAutofillUpdateHelpTitle),
        content: Text(l10n.layerPanelAutofillUpdateHelpBody),
        actions: [],
      ),
    );
  }

  /// 画像を選択し、キャンバスサイズへアスペクト比維持で中央フィットさせて
  /// ラスタライズし、通常レイヤーとして追加する（画像読み込みは
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
    codec.dispose();
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
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    if (byteData == null || !context.mounted) return;

    tileManager.replaceLayerPixels(
      projectService.tileKeyFor(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
        layer.id,
      ),
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
      SnackBar(
        content: Text(
          l10n.layerPanelReplaceMaterialSuccessSnackbar(layer.name),
        ),
      ),
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
    codec.dispose();
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
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
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

/// レイヤー一覧の各行に表示するサムネイル。
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
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
      widget.layerId,
    );
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
