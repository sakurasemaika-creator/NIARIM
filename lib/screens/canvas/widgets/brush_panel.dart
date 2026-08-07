import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/brush.dart';
import '../../../services/brush_service.dart';
import 'creative_folder_sheets.dart';

class BrushPanel extends StatefulWidget {
  final VoidCallback onClose;
  const BrushPanel({super.key, required this.onClose});

  @override
  State<BrushPanel> createState() => _BrushPanelState();
}

class _BrushPanelState extends State<BrushPanel> {
  bool _showFavoritesOnly = false;
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  // null=全て表示・''(空文字)=フォルダなしのみ・その他=そのフォルダIDのみ
  String? _folderFilter;
  static const _allFolders = '__all__';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brushService = context.watch<BrushService>();
    final allBrushes = brushService.brushes;
    final folders = brushService.folders;
    var brushes = _showFavoritesOnly
        ? allBrushes.where((b) => b.isFavorite)
        : allBrushes.where((_) => true);
    if (_folderFilter == '') {
      brushes = brushes.where((b) => b.folderId == null);
    } else if (_folderFilter != null && _folderFilter != _allFolders) {
      brushes = brushes.where((b) => b.folderId == _folderFilter);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      brushes = brushes.where((b) => b.name.toLowerCase().contains(query));
    }
    final brushList = brushes.toList();
    final isFiltering = _showFavoritesOnly || query.isNotEmpty ||
        (_folderFilter != null && _folderFilter != _allFolders);
    final current = brushService.currentBrush;

    return Card(
      elevation: 8,
      child: SizedBox(
        width: 280,
        height: 460,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('ブラシ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // お気に入りのみ表示
                  IconButton(
                    icon: Icon(
                      _showFavoritesOnly ? Icons.star : Icons.star_outline,
                      size: 16,
                      color: _showFavoritesOnly ? Colors.amber : null,
                    ),
                    onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                    tooltip: 'お気に入りのみ表示',
                  ),
                  IconButton(
                    icon: Icon(_showSearch ? Icons.search_off : Icons.search, size: 16),
                    onPressed: () => setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    }),
                    tooltip: '名前で検索',
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 16), onPressed: widget.onClose),
                ],
              ),
              // フォルダ管理・自作ブラシ・読み込み（仕様書17・21）
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.folder_outlined, size: 15),
                    label: const Text('フォルダ', style: TextStyle(fontSize: 11)),
                    onPressed: () => _openFolderManagement(context, brushService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                    label: const Text('自作', style: TextStyle(fontSize: 11)),
                    onPressed: () => _createFromImage(context, brushService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 15),
                    label: const Text('読込', style: TextStyle(fontSize: 11)),
                    onPressed: () => _importBrush(context, brushService),
                  ),
                ],
              ),
              if (folders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _folderChip(context, '全て', _folderFilter == null || _folderFilter == _allFolders,
                            () => setState(() => _folderFilter = null)),
                        _folderChip(context, 'フォルダなし', _folderFilter == '',
                            () => setState(() => _folderFilter = '')),
                        ...folders.map((f) => _folderChip(
                            context, f.name, _folderFilter == f.id, () => setState(() => _folderFilter = f.id))),
                      ],
                    ),
                  ),
                ),
              if (_showSearch)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'ブラシ名で検索',
                      prefixIcon: Icon(Icons.search, size: 16),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              const Divider(),
              Expanded(
                child: brushList.isEmpty
                    ? const Center(child: Text('ブラシがありません', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ReorderableListView.builder(
                  itemCount: brushList.length,
                  onReorder: (oldIndex, newIndex) {
                    if (!isFiltering) {
                      brushService.reorderBrush(oldIndex, newIndex);
                    }
                  },
                  itemBuilder: (context, index) {
                    final brush = brushList[index];
                    final isSelected = current?.id == brush.id;
                    return ListTile(
                      key: ValueKey(brush.id),
                      dense: true,
                      selected: isSelected,
                      leading: Icon(Icons.brush, size: 16,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null),
                      title: Text(brush.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${brush.size.round()}px · ${brush.opacity}%',
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => brushService.toggleFavoriteBrush(brush.id),
                            child: Icon(
                              brush.isFavorite ? Icons.star : Icons.star_outline,
                              size: 14,
                              color: brush.isFavorite ? Colors.amber : Colors.grey,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 14),
                            onSelected: (action) => _handleBrushAction(context, action, brush),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('編集')),
                              const PopupMenuItem(value: 'duplicate', child: Text('複製')),
                              const PopupMenuItem(value: 'move', child: Text('フォルダへ移動')),
                              const PopupMenuItem(value: 'export', child: Text('書き出し')),
                              const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => brushService.selectBrush(brush.id),
                      onLongPress: () => _showBrushSettings(context, brush),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderChip(BuildContext context, String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _handleBrushAction(BuildContext context, String action, Brush brush) {
    final service = context.read<BrushService>();
    switch (action) {
      case 'edit':
        _showBrushSettings(context, brush);
      case 'duplicate':
        service.duplicateBrush(brush.id);
      case 'move':
        showMoveToCreativeFolderSheet(
          context,
          folders: service.folders.map((f) => (id: f.id, name: f.name)).toList(),
          onSelect: (folderId) => service.moveToFolder(brush.id, folderId),
        );
      case 'export':
        _exportBrush(context, service, brush);
      case 'delete':
        service.deleteBrush(brush.id);
    }
  }

  void _showBrushSettings(BuildContext context, Brush brush) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BrushSettingsSheet(brush: brush),
    );
  }

  void _openFolderManagement(BuildContext context, BrushService service) {
    showFolderManagementSheet(
      context,
      getFolders: () => service.folders.map((f) => (id: f.id, name: f.name, isFavorite: f.isFavorite)).toList(),
      onCreate: (name) => service.createFolder(name),
      onRename: (id, name) => service.renameFolder(id, name),
      onToggleFavorite: (id) => service.toggleFolderFavorite(id),
      onReorder: (oldIndex, newIndex) => service.reorderFolder(oldIndex, newIndex),
      onDelete: (id) => service.deleteFolder(id),
    );
  }

  Future<void> _createFromImage(BuildContext context, BrushService service) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    if (!context.mounted) return;
    final name = await promptCreativeAssetName(context, title: '自作ブラシ');
    if (name == null) return;
    await service.createBrushFromImage(result.files.first.path!, name: name);
  }

  Future<void> _importBrush(BuildContext context, BrushService service) async {
    final result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['mirabrush']);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    try {
      await service.importBrushFile(result.files.first.path!);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ブラシの読み込みに失敗しました: $e')));
    }
  }

  Future<void> _exportBrush(BuildContext context, BrushService service, Brush brush) async {
    try {
      final file = await service.exportBrush(brush.id);
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ブラシの書き出しに失敗しました: $e')));
    }
  }
}

class _BrushSettingsSheet extends StatefulWidget {
  final Brush brush;
  const _BrushSettingsSheet({required this.brush});

  @override
  State<_BrushSettingsSheet> createState() => _BrushSettingsSheetState();
}

class _BrushSettingsSheetState extends State<_BrushSettingsSheet> {
  late Brush _brush;

  @override
  void initState() {
    super.initState();
    _brush = widget.brush;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text(_brush.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // サイズ
          _sliderRow('サイズ', _brush.size, 1, 500, (v) => setState(() => _brush = _brush.copyWith(size: v))),
          // 不透明度
          _sliderRow('不透明度', _brush.opacity.toDouble(), 1, 100,
              (v) => setState(() => _brush = _brush.copyWith(opacity: v.round()))),
          // 間隔
          _sliderRow('間隔', _brush.spacing.toDouble(), 1, 100,
              (v) => setState(() => _brush = _brush.copyWith(spacing: v.round()))),
          // ぼかし半径（仕様書17：0〜100・デフォルト0）
          _sliderRow('ぼかし半径', _brush.blurRadius.toDouble(), 0, 100,
              (v) => setState(() => _brush = _brush.copyWith(blurRadius: v.round()))),
          const Divider(),
          // 手ブレ補正
          SwitchListTile(
            title: const Text('手ブレ補正'),
            value: _brush.stabilization,
            onChanged: (v) => setState(() => _brush = _brush.copyWith(stabilization: v)),
          ),
          if (_brush.stabilization)
            _sliderRow('補正強度', _brush.stabilizationStrength.toDouble(), 0, 100,
                (v) => setState(() => _brush = _brush.copyWith(stabilizationStrength: v.round()))),
          // ドットペンモード
          SwitchListTile(
            title: const Text('ドットペンモード'),
            value: _brush.dotPenMode,
            onChanged: (v) => setState(() => _brush = _brush.copyWith(dotPenMode: v)),
          ),
          const Divider(),
          // 筆圧設定
          const Text('筆圧設定', style: TextStyle(fontWeight: FontWeight.bold)),
          ...PressureMode.values.map((mode) => RadioListTile<PressureMode>(
            title: Text(_pressureLabel(mode)),
            value: mode,
            groupValue: _brush.pressureMode,
            onChanged: (v) => setState(() => _brush = _brush.copyWith(pressureMode: v)),
            dense: true,
          )),
          const Divider(),
          // フェード
          const Text('フェード', style: TextStyle(fontWeight: FontWeight.bold)),
          ...FadeMode.values.map((mode) => RadioListTile<FadeMode>(
            title: Text(_fadeModeLabel(mode)),
            value: mode,
            groupValue: _brush.fadeMode,
            onChanged: (v) => setState(() => _brush = _brush.copyWith(fadeMode: v)),
            dense: true,
          )),
          if (_brush.fadeMode == FadeMode.custom) ...[
            _sliderRow('開始値(%)', _brush.fadeCustom?.startValue ?? 100, 0, 100,
                (v) => setState(() => _brush = _brush.copyWith(
                    fadeCustom: FadeCustomSettings(
                      startValue: v,
                      endValue: _brush.fadeCustom?.endValue ?? 0,
                      distancePx: _brush.fadeCustom?.distancePx ?? 500,
                    )))),
            _sliderRow('終了値(%)', _brush.fadeCustom?.endValue ?? 0, 0, 100,
                (v) => setState(() => _brush = _brush.copyWith(
                    fadeCustom: FadeCustomSettings(
                      startValue: _brush.fadeCustom?.startValue ?? 100,
                      endValue: v,
                      distancePx: _brush.fadeCustom?.distancePx ?? 500,
                    )))),
            _sliderRow('距離(px)', _brush.fadeCustom?.distancePx ?? 500, 10, 2000,
                (v) => setState(() => _brush = _brush.copyWith(
                    fadeCustom: FadeCustomSettings(
                      startValue: _brush.fadeCustom?.startValue ?? 100,
                      endValue: _brush.fadeCustom?.endValue ?? 0,
                      distancePx: v,
                    )))),
          ],
          const Divider(),
          // ストローク減衰
          SwitchListTile(
            title: const Text('ストローク減衰'),
            subtitle: const Text('描き続けるほど不透明度が下がる', style: TextStyle(fontSize: 11)),
            value: _brush.strokeDecay,
            onChanged: (v) => setState(() => _brush = _brush.copyWith(strokeDecay: v)),
          ),
          const Divider(),
          // 混色
          const Text('混色', style: TextStyle(fontWeight: FontWeight.bold)),
          ...BrushMixingMode.values.map((mode) => RadioListTile<BrushMixingMode>(
            title: Text(_mixingModeLabel(mode)),
            value: mode,
            groupValue: _brush.mixingMode,
            onChanged: (v) => setState(() => _brush = _brush.copyWith(mixingMode: v)),
            dense: true,
          )),
          if (_brush.mixingMode != BrushMixingMode.off) ...[
            const Text('混色率', style: TextStyle(fontSize: 12)),
            Wrap(
              spacing: 8,
              children: kMixingRateOptions.map((rate) => ChoiceChip(
                label: Text(rate == 0 ? 'OFF' : '$rate%'),
                selected: _brush.mixingRate == rate,
                onSelected: (selected) {
                  if (selected) setState(() => _brush = _brush.copyWith(mixingRate: rate));
                },
              )).toList(),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context.read<BrushService>().updateBrush(_brush);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(child: Slider(min: min, max: max, value: value.clamp(min, max), onChanged: onChanged)),
        SizedBox(width: 40, child: Text(value.round().toString(), style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  String _pressureLabel(PressureMode mode) => switch (mode) {
    PressureMode.off => '無効',
    PressureMode.size => 'サイズに反映',
    PressureMode.opacity => '不透明度に反映',
    PressureMode.sizeAndOpacity => 'サイズ＋不透明度に反映',
  };

  String _fadeModeLabel(FadeMode mode) => switch (mode) {
    FadeMode.off => 'OFF',
    FadeMode.weak => '弱',
    FadeMode.medium => '中',
    FadeMode.strong => '強',
    FadeMode.custom => 'カスタム',
  };

  String _mixingModeLabel(BrushMixingMode mode) => switch (mode) {
    BrushMixingMode.off => 'OFF',
    BrushMixingMode.simple => '簡易混色',
    BrushMixingMode.bleed => 'にじみ',
  };
}
