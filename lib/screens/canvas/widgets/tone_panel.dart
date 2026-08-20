import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/tone.dart';
import '../../../services/tone_service.dart';
import 'creative_folder_sheets.dart';
import 'panel_close_bar.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
    // 絞込中（お気に入りのみ・検索・フォルダ指定）は表示順と実際の並び順が
    // 一致しないため、並べ替えは絞込なしのときだけ有効にする。
    final isFiltering = _showFavoritesOnly || query.isNotEmpty ||
        (_folderFilter != null && _folderFilter != _allFolders);

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
              PanelCenterCloseBar(onClose: widget.onClose),
              Row(
                children: [
                  Text(l10n.toneTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_showFavoritesOnly ? Icons.star : Icons.star_outline, size: 16,
                        color: _showFavoritesOnly ? Colors.amber : null),
                    onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                    tooltip: l10n.creativePanelFavoritesOnlyTooltip,
                  ),
                  IconButton(
                    icon: Icon(_showSearch ? Icons.search_off : Icons.search, size: 16),
                    onPressed: () => setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) { _searchQuery = ''; _searchController.clear(); }
                    }),
                    tooltip: l10n.creativePanelSearchTooltip,
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.folder_outlined, size: 15),
                    label: Text(l10n.creativePanelFolderButton, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _openFolderManagement(context, toneService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                    label: Text(l10n.creativePanelCreateButton, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _createFromImage(context, toneService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 15),
                    label: Text(l10n.creativePanelImportButton, style: const TextStyle(fontSize: 11)),
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
                        _folderChip(l10n.creativePanelFolderAllChip, _folderFilter == null || _folderFilter == _allFolders,
                            () => setState(() => _folderFilter = null)),
                        _folderChip(l10n.folderNone, _folderFilter == '', () => setState(() => _folderFilter = '')),
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
                    decoration: InputDecoration(
                        isDense: true, hintText: l10n.toneSearchHint, prefixIcon: const Icon(Icons.search, size: 16)),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              const Divider(),
              Expanded(
                child: toneList.isEmpty
                    ? Center(child: Text(l10n.toneEmpty, style: const TextStyle(color: Colors.grey, fontSize: 12)))
                    : ReorderableListView.builder(
                        // ドラッグハンドルは行末に明示アイコンとして置く
                        // （既定のドラッグハンドルだと、行全体の長押しで開く
                        // 編集シートや、お気に入り・三点メニューのタップと
                        // ジェスチャーが競合するため）。
                        buildDefaultDragHandles: false,
                        itemCount: toneList.length,
                        onReorder: (oldIndex, newIndex) {
                          if (!isFiltering) toneService.reorderTone(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final tone = toneList[index];
                          final isSelected = current?.id == tone.id;
                          // プリインストールのトーンは編集・削除できない
                          // （複製したものは複製元とは別IDになるため編集・削除可能）。
                          final builtIn = toneService.isBuiltIn(tone.id);
                          return ListTile(
                            key: ValueKey(tone.id),
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
                                    if (!builtIn) PopupMenuItem(value: 'edit', child: Text(l10n.creativePanelEditAction)),
                                    PopupMenuItem(value: 'duplicate', child: Text(l10n.themeDuplicateAction)),
                                    PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
                                    PopupMenuItem(value: 'export', child: Text(l10n.transferExport)),
                                    if (!builtIn)
                                      PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red))),
                                  ],
                                ),
                                if (!isFiltering)
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 2),
                                      child: Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => toneService.selectTone(tone.id),
                            onLongPress: builtIn ? null : () => _showToneSettings(context, tone),
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
      case 'duplicate':
        service.duplicateTone(tone.id);
      case 'move':
        showMoveToCreativeFolderSheet(
          context,
          folders: service.folders.map((f) => (id: f.id, name: f.name)).toList(),
          onSelect: (folderId) => service.moveToFolder(tone.id, folderId),
        );
      case 'export':
        _exportTone(context, service, tone);
      case 'delete':
        _deleteTone(context, service, tone);
    }
  }

  /// お気に入り登録中は削除できない。
  void _deleteTone(BuildContext context, ToneService service, Tone tone) {
    if (tone.isFavorite) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    service.deleteTone(tone.id);
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
    final l10n = AppLocalizations.of(context)!;
    final name = await promptCreativeAssetName(context, title: l10n.toneCreateDialogTitle);
    if (name == null) return;
    await service.createToneFromImage(result.files.first.path!, name: name);
  }

  Future<void> _importTone(BuildContext context, ToneService service) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['niatone']);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    try {
      await service.importToneFile(result.files.first.path!);
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.toneImportFailedSnackbar(e.toString()))));
    }
  }

  Future<void> _exportTone(BuildContext context, ToneService service, Tone tone) async {
    try {
      final file = await service.exportTone(tone.id);
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.toneExportFailedSnackbar(e.toString()))));
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
    final l10n = AppLocalizations.of(context)!;
    // 仕様書17：トーンの編集可能項目は名前・テクスチャ画像のみ
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.toneEditTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.creativeAssetNameLabel, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined, size: 16),
              label: Text(l10n.toneChangeTextureButton),
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
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
