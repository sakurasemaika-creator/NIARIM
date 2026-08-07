import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/tone.dart';
import '../../../services/tone_service.dart';
import 'creative_folder_sheets.dart';

/// トーンの全機能管理パネル（仕様書04・17・25：一覧・お気に入り・検索・
/// 自作トーン・読み込み・書き出し・フォルダ管理）。ブラシパネルと同構成。
class TonePanel extends StatefulWidget {
  final VoidCallback onClose;
  const TonePanel({super.key, required this.onClose});

  @override
  State<TonePanel> createState() => _TonePanelState();
}

class _TonePanelState extends State<TonePanel> {
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
    final toneService = context.watch<ToneService>();
    final allTones = toneService.tones;
    final folders = toneService.folders;
    var tones = _showFavoritesOnly ? allTones.where((t) => t.isFavorite) : allTones.where((_) => true);
    if (_folderFilter == '') {
      tones = tones.where((t) => t.folderId == null);
    } else if (_folderFilter != null && _folderFilter != _allFolders) {
      tones = tones.where((t) => t.folderId == _folderFilter);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      tones = tones.where((t) => t.name.toLowerCase().contains(query));
    }
    final toneList = tones.toList();
    final current = toneService.currentTone;

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
                  const Text('トーン', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    onPressed: () => _openFolderManagement(context, toneService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                    label: const Text('自作', style: TextStyle(fontSize: 11)),
                    onPressed: () => _createFromImage(context, toneService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 15),
                    label: const Text('読込', style: TextStyle(fontSize: 11)),
                    onPressed: () => _importTone(context, toneService),
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
                        isDense: true, hintText: 'トーン名で検索', prefixIcon: Icon(Icons.search, size: 16)),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              const Divider(),
              Expanded(
                child: toneList.isEmpty
                    ? const Center(child: Text('トーンがありません', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        itemCount: toneList.length,
                        itemBuilder: (context, index) {
                          final tone = toneList[index];
                          final isSelected = current?.id == tone.id;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            leading: Icon(Icons.texture, size: 16,
                                color: isSelected ? Theme.of(context).colorScheme.primary : null),
                            title: Text(tone.name, style: const TextStyle(fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => toneService.toggleFavorite(tone.id),
                                  child: Icon(tone.isFavorite ? Icons.star : Icons.star_outline,
                                      size: 14, color: tone.isFavorite ? Colors.amber : Colors.grey),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 14),
                                  onSelected: (action) => _handleAction(context, action, tone),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: Text('編集')),
                                    const PopupMenuItem(value: 'move', child: Text('フォルダへ移動')),
                                    const PopupMenuItem(value: 'export', child: Text('書き出し')),
                                    const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => toneService.selectTone(tone.id),
                            onLongPress: () => _showToneSettings(context, tone),
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

  void _handleAction(BuildContext context, String action, Tone tone) {
    final service = context.read<ToneService>();
    switch (action) {
      case 'edit':
        _showToneSettings(context, tone);
      case 'move':
        showMoveToCreativeFolderSheet(
          context,
          folders: service.folders.map((f) => (id: f.id, name: f.name)).toList(),
          onSelect: (folderId) => service.moveToFolder(tone.id, folderId),
        );
      case 'export':
        _exportTone(context, service, tone);
      case 'delete':
        service.deleteTone(tone.id);
    }
  }

  void _showToneSettings(BuildContext context, Tone tone) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _ToneSettingsSheet(tone: tone),
    );
  }

  void _openFolderManagement(BuildContext context, ToneService service) {
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

  Future<void> _createFromImage(BuildContext context, ToneService service) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    if (!context.mounted) return;
    final name = await promptCreativeAssetName(context, title: '自作トーン');
    if (name == null) return;
    await service.createToneFromImage(result.files.first.path!, name: name);
  }

  Future<void> _importTone(BuildContext context, ToneService service) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['miratone']);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    try {
      await service.importToneFile(result.files.first.path!);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('トーンの読み込みに失敗しました: $e')));
    }
  }

  Future<void> _exportTone(BuildContext context, ToneService service, Tone tone) async {
    try {
      final file = await service.exportTone(tone.id);
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('トーンの書き出しに失敗しました: $e')));
    }
  }
}

class _ToneSettingsSheet extends StatefulWidget {
  final Tone tone;
  const _ToneSettingsSheet({required this.tone});

  @override
  State<_ToneSettingsSheet> createState() => _ToneSettingsSheetState();
}

class _ToneSettingsSheetState extends State<_ToneSettingsSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tone.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 仕様書17：トーンの編集可能項目は名前・テクスチャ画像のみ
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('トーンを編集', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名前', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined, size: 16),
              label: const Text('テクスチャ画像を変更'),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(type: FileType.image);
                if (result == null || result.files.isEmpty || result.files.first.path == null) return;
                if (!context.mounted) return;
                final service = context.read<ToneService>();
                await service.createToneFromImage(result.files.first.path!, name: _nameController.text);
                service.deleteTone(widget.tone.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                context.read<ToneService>().updateTone(widget.tone.copyWith(name: _nameController.text));
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
