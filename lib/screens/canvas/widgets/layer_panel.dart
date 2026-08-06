import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/layer.dart' as model;
import '../../../services/project_service.dart';

class LayerPanel extends StatefulWidget {
  final VoidCallback onClose;
  final String projectId;
  final String sceneId;
  final int frameIndex;

  const LayerPanel({
    super.key,
    required this.onClose,
    required this.projectId,
    required this.sceneId,
    required this.frameIndex,
  });

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  int _selectedIndex = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  model.LayerType? _selectionBaseType;

  List<model.Layer> _visibleLayers(List<model.Layer> layers) =>
      layers.where((l) => l.type != model.LayerType.selection).toList();

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
                IconButton(icon: const Icon(Icons.search, size: 18), onPressed: () {}),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: widget.onClose),
              ],
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
                return ListTile(
                  key: ValueKey(layer.id),
                  selected: isSelected,
                  dense: true,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      Container(width: 24, height: 24, color: Colors.grey[700]),
                    ],
                  ),
                  title: Text(layer.name, style: const TextStyle(fontSize: 12)),
                  subtitle: layer.hasClipping
                      ? const Text('クリッピング', style: TextStyle(fontSize: 9, color: Colors.blue))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (layer.needsAutofillUpdate)
                        GestureDetector(
                          onTap: () => _showAutofillDialog(context),
                          onLongPress: () => _showAutofillUpdateHelp(context),
                          child: const Icon(Icons.error, color: Colors.orange, size: 14),
                        ),
                      if (layer.opacityLocked)
                        const Icon(Icons.opacity, size: 14, color: Colors.blue),
                      if (layer.isLocked)
                        const Icon(Icons.lock, size: 14),
                      if (_isTimelineMaterial(layer.type))
                        GestureDetector(
                          onTap: () => _showTimelineLayerMenu(context, layer),
                          child: const Icon(Icons.more_vert, size: 16),
                        ),
                    ],
                  ),
                  onTap: () => setState(() {
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
                  }),
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
                if (_selectedIndex >= 0 &&
                    _selectedIndex < layers.length &&
                    !_isTimelineMaterial(layers[_selectedIndex].type)) ...[
                  IconButton(icon: const Icon(Icons.merge_type, size: 18), onPressed: () {}, tooltip: '結合'),
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

  void _showTimelineLayerMenu(BuildContext context, model.Layer layer) {
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
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('表示範囲変更'),
              onTap: () {
                Navigator.pop(ctx);
                _showRangeChangeDialog(context, layer);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('素材差し替え'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 素材差し替えピッカー連携
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('素材差し替え（実装予定）')),
                );
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

  void _showRangeChangeDialog(BuildContext context, model.Layer layer) {
    final startCtrl = TextEditingController(text: '1');
    final endCtrl = TextEditingController(text: '120');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('表示範囲変更'),
        content: Row(
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: 表示範囲をモデルに反映
            },
            child: const Text('OK'),
          ),
        ],
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
              onTap: () { Navigator.pop(ctx); _addLayer(context, model.LayerType.common, '共通'); },
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
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
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
            ],
          ),
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
    model.LayerBlendMode.colorDodge  => '発光カラー',
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

  void _showAutofillDialog(BuildContext context) {
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('自動塗り方式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('※ プロジェクト内で自動塗りを初回実行する場合はどちらを選んでも問題ありません。', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('※ 自動塗りレイヤーのみ存在する場合は、一から領域を判定して自動塗りします。', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('実行')),
          ],
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

  Future<void> _importImage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    if (!context.mounted) return;
    context.read<ProjectService>().addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: widget.frameIndex,
      type: model.LayerType.timelineImage,
      name: name,
    );
    setState(() => _selectedIndex = 0);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('loaded: $name')),
    );
  }
}
