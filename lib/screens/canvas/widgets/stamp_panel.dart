import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/stamp.dart';
import '../../../services/stamp_service.dart';
import 'creative_folder_sheets.dart';

/// スタンプの全機能管理パネル（仕様書17：一覧・お気に入り・検索・
/// 自作スタンプ・読み込み・書き出し・フォルダ管理）。ブラシパネルと同構成。
class StampPanel extends StatefulWidget {
  final VoidCallback onClose;
  const StampPanel({super.key, required this.onClose});

  @override
  State<StampPanel> createState() => _StampPanelState();
}

class _StampPanelState extends State<StampPanel> {
  bool _showFavoritesOnly = false;
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String? _folderFilter;
  static const _allFolders = '__all__';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stampService = context.watch<StampService>();
    final allStamps = stampService.stamps;
    final folders = stampService.folders;
    var stamps = _showFavoritesOnly ? allStamps.where((s) => s.isFavorite) : allStamps.where((_) => true);
    if (_folderFilter == '') {
      stamps = stamps.where((s) => s.folderId == null);
    } else if (_folderFilter != null && _folderFilter != _allFolders) {
      stamps = stamps.where((s) => s.folderId == _folderFilter);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      stamps = stamps.where((s) => s.name.toLowerCase().contains(query));
    }
    final stampList = stamps.toList();
    final current = stampService.currentStamp;

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
                  const Text('スタンプ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_showFavoritesOnly ? Icons.star : Icons.star_outline, size: 16,
                        color: _showFavoritesOnly ? Colors.amber : null),
                    onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                    tooltip: 'お気に入りのみ表示',
                  ),
                  IconButton(
                    icon: Icon(_showSearch ? Icons.search_off : Icons.search, size: 16),
                    onPressed: () => setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) { _searchQuery = ''; _searchController.clear(); }
                    }),
                    tooltip: '名前で検索',
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 16), onPressed: widget.onClose),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.folder_outlined, size: 15),
                    label: const Text('フォルダ', style: TextStyle(fontSize: 11)),
                    onPressed: () => _openFolderManagement(context, stampService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                    label: const Text('自作', style: TextStyle(fontSize: 11)),
                    onPressed: () => _createFromImage(context, stampService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 15),
                    label: const Text('読込', style: TextStyle(fontSize: 11)),
                    onPressed: () => _importStamp(context, stampService),
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
                        _folderChip('全て', _folderFilter == null || _folderFilter == _allFolders,
                            () => setState(() => _folderFilter = null)),
                        _folderChip('フォルダなし', _folderFilter == '', () => setState(() => _folderFilter = '')),
                        ...folders.map((f) => _folderChip(
                            f.name, _folderFilter == f.id, () => setState(() => _folderFilter = f.id))),
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
                        isDense: true, hintText: 'スタンプ名で検索', prefixIcon: Icon(Icons.search, size: 16)),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              const Divider(),
              Expanded(
                child: stampList.isEmpty
                    ? const Center(child: Text('スタンプがありません', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        itemCount: stampList.length,
                        itemBuilder: (context, index) {
                          final stamp = stampList[index];
                          final isSelected = current?.id == stamp.id;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            leading: Icon(Icons.star_border_purple500, size: 16,
                                color: isSelected ? Theme.of(context).colorScheme.primary : null),
                            title: Text(stamp.name, style: const TextStyle(fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => stampService.toggleFavorite(stamp.id),
                                  child: Icon(stamp.isFavorite ? Icons.star : Icons.star_outline,
                                      size: 14, color: stamp.isFavorite ? Colors.amber : Colors.grey),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 14),
                                  onSelected: (action) => _handleAction(context, action, stamp),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: Text('編集')),
                                    const PopupMenuItem(value: 'move', child: Text('フォルダへ移動')),
                                    const PopupMenuItem(value: 'export', child: Text('書き出し')),
                                    const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => stampService.selectStamp(stamp.id),
                            onLongPress: () => _showStampSettings(context, stamp),
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

  Widget _folderChip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: selected,
          onSelected: (_) => onTap(),
          visualDensity: VisualDensity.compact,
        ),
      );

  void _handleAction(BuildContext context, String action, Stamp stamp) {
    final service = context.read<StampService>();
    switch (action) {
      case 'edit':
        _showStampSettings(context, stamp);
      case 'move':
        showMoveToCreativeFolderSheet(
          context,
          folders: service.folders.map((f) => (id: f.id, name: f.name)).toList(),
          onSelect: (folderId) => service.moveToFolder(stamp.id, folderId),
        );
      case 'export':
        _exportStamp(context, service, stamp);
      case 'delete':
        service.deleteStamp(stamp.id);
    }
  }

  void _showStampSettings(BuildContext context, Stamp stamp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StampSettingsSheet(stamp: stamp),
    );
  }

  void _openFolderManagement(BuildContext context, StampService service) {
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

  Future<void> _createFromImage(BuildContext context, StampService service) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    if (!context.mounted) return;
    final name = await promptCreativeAssetName(context, title: '自作スタンプ');
    if (name == null) return;
    await service.createStampFromImage(result.files.first.path!, name: name);
  }

  Future<void> _importStamp(BuildContext context, StampService service) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['niastamp']);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    try {
      await service.importStampFile(result.files.first.path!);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('スタンプの読み込みに失敗しました: $e')));
    }
  }

  Future<void> _exportStamp(BuildContext context, StampService service, Stamp stamp) async {
    try {
      final file = await service.exportStamp(stamp.id);
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('スタンプの書き出しに失敗しました: $e')));
    }
  }
}

class _StampSettingsSheet extends StatefulWidget {
  final Stamp stamp;
  const _StampSettingsSheet({required this.stamp});

  @override
  State<_StampSettingsSheet> createState() => _StampSettingsSheetState();
}

class _StampSettingsSheetState extends State<_StampSettingsSheet> {
  late Stamp _stamp;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _stamp = widget.stamp;
    _nameController = TextEditingController(text: _stamp.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          const Text('スタンプを編集', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '名前', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          // 仕様書17：スタンプは回転・密度・散布に対応
          SwitchListTile(
            title: const Text('回転'),
            value: _stamp.rotation,
            onChanged: (v) => setState(() => _stamp = _stamp.copyWith(rotation: v)),
          ),
          _sliderRow('密度', _stamp.density, 0.1, 5.0,
              (v) => setState(() => _stamp = _stamp.copyWith(density: v))),
          _sliderRow('散布', _stamp.scatter, 0.0, 1.0,
              (v) => setState(() => _stamp = _stamp.copyWith(scatter: v))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.image_outlined, size: 16),
            label: const Text('スタンプ画像を変更'),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.image);
              if (result == null || result.files.isEmpty || result.files.first.path == null) return;
              if (!context.mounted) return;
              final service = context.read<StampService>();
              await service.createStampFromImage(result.files.first.path!, name: _nameController.text);
              service.deleteStamp(_stamp.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context.read<StampService>().updateStamp(_stamp.copyWith(name: _nameController.text));
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
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(child: Slider(min: min, max: max, value: value.clamp(min, max), onChanged: onChanged)),
        SizedBox(width: 40, child: Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}
