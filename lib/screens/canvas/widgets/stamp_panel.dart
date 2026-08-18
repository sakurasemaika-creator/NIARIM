import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/stamp.dart';
import '../../../services/stamp_service.dart';
import '../../../widgets/editable_slider_value.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
                  Text(l10n.stampTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  IconButton(icon: const Icon(Icons.close, size: 16), tooltip: l10n.commonClose, onPressed: widget.onClose),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.folder_outlined, size: 15),
                    label: Text(l10n.creativePanelFolderButton, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _openFolderManagement(context, stampService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 15),
                    label: Text(l10n.creativePanelCreateButton, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _createFromImage(context, stampService),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 15),
                    label: Text(l10n.creativePanelImportButton, style: const TextStyle(fontSize: 11)),
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
                        isDense: true, hintText: l10n.stampSearchHint, prefixIcon: const Icon(Icons.search, size: 16)),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              const Divider(),
              Expanded(
                child: stampList.isEmpty
                    ? Center(child: Text(l10n.stampEmpty, style: const TextStyle(color: Colors.grey, fontSize: 12)))
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
                                    PopupMenuItem(value: 'edit', child: Text(l10n.creativePanelEditAction)),
                                    PopupMenuItem(value: 'move', child: Text(l10n.folderMoveToTitle)),
                                    PopupMenuItem(value: 'export', child: Text(l10n.transferExport)),
                                    PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red))),
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
        _deleteStamp(context, service, stamp);
    }
  }

  /// お気に入り登録中は削除できない。
  void _deleteStamp(BuildContext context, StampService service, Stamp stamp) {
    if (stamp.isFavorite) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    service.deleteStamp(stamp.id);
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
    final l10n = AppLocalizations.of(context)!;
    final name = await promptCreativeAssetName(context, title: l10n.stampCreateDialogTitle);
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.stampImportFailedSnackbar(e.toString()))));
    }
  }

  Future<void> _exportStamp(BuildContext context, StampService service, Stamp stamp) async {
    try {
      final file = await service.exportStamp(stamp.id);
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.stampExportFailedSnackbar(e.toString()))));
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
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.stampEditTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.creativeAssetNameLabel, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          // 仕様書17：スタンプは回転・密度・散布に対応
          SwitchListTile(
            title: Text(l10n.stampRotationLabel),
            value: _stamp.rotation,
            onChanged: (v) => setState(() => _stamp = _stamp.copyWith(rotation: v)),
          ),
          // ピクセルモード：ONにするとスタンプ
          // テクスチャをモザイク低解像度化＋色数削減でドット絵風に加工する。
          SwitchListTile(
            title: Text(l10n.stampPixelModeLabel),
            subtitle: Text(l10n.stampPixelModeHint, style: const TextStyle(fontSize: 11)),
            value: _stamp.pixelMode,
            onChanged: (v) => setState(() => _stamp = _stamp.copyWith(pixelMode: v)),
          ),
          _sliderRow(l10n.stampDensityLabel, _stamp.density, 0.1, 5.0,
              (v) => setState(() => _stamp = _stamp.copyWith(density: v))),
          _sliderRow(l10n.stampScatterLabel, _stamp.scatter, 0.0, 1.0,
              (v) => setState(() => _stamp = _stamp.copyWith(scatter: v))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.image_outlined, size: 16),
            label: Text(l10n.stampChangeImageButton),
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
            child: Text(l10n.commonSave),
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
        SizedBox(
          width: 40,
          child: EditableSliderValue(
            text: value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12),
            value: value, min: min, max: max, isInt: false,
            onChanged: (v) => onChanged(v.toDouble()),
          ),
        ),
      ],
    );
  }
}
