import 'package:niarim/services/theme_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/stamp.dart';
import '../../../services/stamp_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/stepped_slider.dart';
import 'creative_folder_sheets.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/reorder_index.dart';
import 'asset_search_bar.dart';
import 'asset_tag_dialog.dart';
import '../../../widgets/asset_tag_label.dart';

/// スタンプの全機能管理パネル（一覧・お気に入り・検索・
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
  AssetSearchMode _searchMode = AssetSearchMode.keyword;
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
    var stamps = _showFavoritesOnly
        ? allStamps.where((s) => s.isFavorite)
        : allStamps.where((_) => true);
    if (_folderFilter == '') {
      stamps = stamps.where((s) => s.folderId == null);
    } else if (_folderFilter != null && _folderFilter != _allFolders) {
      stamps = stamps.where((s) => s.folderId == _folderFilter);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      stamps = stamps.where(
        (s) => assetMatchesSearch(
          name: s.name,
          // 既定タグは言語非依存のキーで保存されているため、その言語での
          // 表示文言へ直してから突き合わせる（英語UIで「pixel」と打って
          // ドット絵向けの素材が出る、という当たり前の挙動にするため）。
          tags: localizeAssetTags(l10n, s.tags),
          mode: _searchMode,
          query: query,
        ),
      );
    }
    final stampList = stamps.toList();
    final current = stampService.currentStamp;
    // 絞込中（お気に入りのみ・検索・フォルダ指定）は表示順と実際の並び順が
    // 一致しないため、並べ替えは絞込なしのときだけ有効にする。
    final isFiltering =
        _showFavoritesOnly ||
        query.isNotEmpty ||
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
                  Text(
                    l10n.stampTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(
                      _showFavoritesOnly ? Icons.star : Icons.star_outline,
                      size: 16,
                      color: _showFavoritesOnly
                          ? ThemeService.activeColorScheme.tertiary
                          : null,
                    ),
                    onPressed: () => setState(
                      () => _showFavoritesOnly = !_showFavoritesOnly,
                    ),
                    tooltip: l10n.creativePanelFavoritesOnlyTooltip,
                  ),
                  IconButton(
                    icon: Icon(
                      _showSearch ? Icons.search_off : Icons.search,
                      size: 16,
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
              // 【不具合修正】brush_panel.dartと同じ理由（PC/DeXモードの
              // ドッキングパネル既定幅ではボタン3つの自然幅が収まらず
              // RenderFlexがオーバーフローしていた）で横スクロール化。
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.folder_outlined, size: 15),
                      label: Text(
                        l10n.creativePanelFolderButton,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                      onPressed: () =>
                          _openFolderManagement(context, stampService),
                    ),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 15,
                      ),
                      label: Text(
                        l10n.creativePanelCreateButton,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                      onPressed: () => _createFromImage(context, stampService),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.file_upload_outlined, size: 15),
                      label: Text(
                        l10n.creativePanelImportButton,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                      onPressed: () => _importStamp(context, stampService),
                    ),
                  ],
                ),
              ),
              if (folders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _folderChip(
                          l10n.creativePanelFolderAllChip,
                          _folderFilter == null || _folderFilter == _allFolders,
                          () => setState(() => _folderFilter = null),
                        ),
                        _folderChip(
                          l10n.folderNone,
                          _folderFilter == '',
                          () => setState(() => _folderFilter = ''),
                        ),
                        ...folders.map(
                          (f) => _folderChip(
                            f.name,
                            _folderFilter == f.id,
                            () => setState(() => _folderFilter = f.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showSearch)
                AssetSearchBar(
                  controller: _searchController,
                  mode: _searchMode,
                  availableTags: localizeAssetTags(
                    l10n,
                    stampService.allTags(),
                  ),
                  keywordHint: l10n.stampSearchHint,
                  onModeChanged: (m) => setState(() {
                    _searchMode = m;
                    // 方式を切り替えたら入力は持ち越さない。名前とタグでは
                    // 一致するものが全く違い、切り替えた瞬間に0件になって
                    // 「壊れた」ように見えるため。
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                  onQueryChanged: (v) => setState(() => _searchQuery = v),
                ),
              const Divider(),
              Expanded(
                child: stampList.isEmpty
                    ? Center(
                        child: Text(
                          l10n.stampEmpty,
                          style: TextStyle(
                            color:
                                ThemeService.activeColorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        // ドラッグハンドルは行末に明示アイコンとして置く
                        // （既定のドラッグハンドルだと、行全体の長押しで開く
                        // 編集シートや、お気に入り・三点メニューのタップと
                        // ジェスチャーが競合するため）。
                        buildDefaultDragHandles: false,
                        itemCount: stampList.length,
                        onReorderItem: (oldIndex, newIndex) {
                          if (!isFiltering) {
                            stampService.reorderStamp(
                              oldIndex,
                              preRemovalIndex(oldIndex, newIndex),
                            );
                          }
                        },
                        itemBuilder: (context, index) {
                          final stamp = stampList[index];
                          final isSelected = current?.id == stamp.id;
                          // プリインストールのスタンプは編集・削除できない
                          // （複製したものは複製元とは別IDになるため編集・削除可能）。
                          final builtIn = stampService.isBuiltIn(stamp.id);
                          return ListTile(
                            key: ValueKey(stamp.id),
                            dense: true,
                            selected: isSelected,
                            leading: Icon(
                              Icons.star_border_purple500,
                              size: 16,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              stamp.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Kuramubon',
                                fontFamilyFallback: kHeadingFontFallback,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      stampService.toggleFavorite(stamp.id),
                                  child: Icon(
                                    stamp.isFavorite
                                        ? Icons.star
                                        : Icons.star_outline,
                                    size: 14,
                                    color: stamp.isFavorite
                                        ? ThemeService
                                              .activeColorScheme
                                              .tertiary
                                        : ThemeService
                                              .activeColorScheme
                                              .onSurfaceVariant,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 14),
                                  onSelected: (action) =>
                                      _handleAction(context, action, stamp),
                                  itemBuilder: (_) => [
                                    if (!builtIn)
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(
                                          l10n.creativePanelEditAction,
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'duplicate',
                                      child: Text(l10n.themeDuplicateAction),
                                    ),
                                    PopupMenuItem(
                                      value: 'move',
                                      child: Text(l10n.folderMoveToTitle),
                                    ),
                                    // タグはお気に入りと同じく
                                    // 「利用者の分類」なので、
                                    // 組み込み素材にも付けられる。
                                    PopupMenuItem(
                                      value: 'tags',
                                      child: Text(l10n.creativePanelTagsLabel),
                                    ),
                                    PopupMenuItem(
                                      value: 'export',
                                      child: Text(l10n.transferExport),
                                    ),
                                    if (!builtIn)
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          l10n.commonDelete,
                                          style: TextStyle(
                                            color: ThemeService
                                                .activeColorScheme
                                                .error,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (!isFiltering)
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 2),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        size: 16,
                                        color: ThemeService
                                            .activeColorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => stampService.selectStamp(stamp.id),
                            onLongPress: builtIn
                                ? null
                                : () => _showStampSettings(context, stamp),
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

  Widget _folderChip(String label, bool selected, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: ChoiceChip(
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          selected: selected,
          onSelected: (_) => onTap(),
          visualDensity: VisualDensity.compact,
        ),
      );

  void _handleAction(BuildContext context, String action, Stamp stamp) {
    final service = context.read<StampService>();
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case 'edit':
        _showStampSettings(context, stamp);
      case 'duplicate':
        service.duplicateStamp(stamp.id);
      case 'move':
        showMoveToCreativeFolderSheet(
          context,
          folders: service.folders
              .map((f) => (id: f.id, name: f.name))
              .toList(),
          onSelect: (folderId) => service.moveToFolder(stamp.id, folderId),
        );
      case 'tags':
        showAssetTagDialog(
          context,
          assetName: stamp.name,
          currentTags: localizeAssetTags(l10n, stamp.tags),
          suggestions: localizeAssetTags(l10n, service.allTags()),
          // ダイアログは表示文言で編集させるので、保存時にキーへ戻す。
          // ここを通さないと既定タグがその言語の文字列として焼き付き、
          // 言語を切り替えても元に戻らなくなる。
          onSave: (tags) =>
              service.setTags(stamp.id, delocalizeAssetTags(l10n, tags)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
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
      getFolders: () => service.folders
          .map((f) => (id: f.id, name: f.name, isFavorite: f.isFavorite))
          .toList(),
      onCreate: (name) => service.createFolder(name),
      onRename: (id, name) => service.renameFolder(id, name),
      onToggleFavorite: (id) => service.toggleFolderFavorite(id),
      onReorder: (oldIndex, newIndex) =>
          service.reorderFolder(oldIndex, newIndex),
      onDelete: (id) => service.deleteFolder(id),
    );
  }

  Future<void> _createFromImage(
    BuildContext context,
    StampService service,
  ) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await promptCreativeAssetName(
      context,
      title: l10n.stampCreateDialogTitle,
    );
    if (name == null) return;
    await service.createStampFromImage(result.files.first.path!, name: name);
  }

  Future<void> _importStamp(BuildContext context, StampService service) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['niastamp'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    try {
      await service.importStampFile(result.files.first.path!);
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.stampImportFailedSnackbar(e.toString()))),
      );
    }
  }

  Future<void> _exportStamp(
    BuildContext context,
    StampService service,
    Stamp stamp,
  ) async {
    try {
      final file = await service.exportStamp(stamp.id);
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.stampExportFailedSnackbar(e.toString()))),
      );
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
          Text(
            l10n.stampEditTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.creativeAssetNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          // スタンプは回転・密度・散布に対応
          SwitchListTile(
            title: Text(l10n.stampRotationLabel),
            value: _stamp.rotation,
            onChanged: (v) =>
                setState(() => _stamp = _stamp.copyWith(rotation: v)),
          ),
          _intSliderRow(
            l10n.brushSettingsOpacityLabel,
            _stamp.opacity,
            1,
            100,
            (v) => setState(() => _stamp = _stamp.copyWith(opacity: v)),
          ),
          // ピクセルモード：ONにするとスタンプ
          // テクスチャをモザイク低解像度化＋色数削減でドット絵風に加工する。
          SwitchListTile(
            title: Text(l10n.stampPixelModeLabel),
            subtitle: Text(
              l10n.stampPixelModeHint,
              style: const TextStyle(fontSize: 11),
            ),
            value: _stamp.pixelMode,
            onChanged: (v) =>
                setState(() => _stamp = _stamp.copyWith(pixelMode: v)),
          ),
          _sliderRow(
            l10n.stampDensityLabel,
            _stamp.density,
            0.1,
            5.0,
            (v) => setState(() => _stamp = _stamp.copyWith(density: v)),
          ),
          _sliderRow(
            l10n.stampScatterLabel,
            _stamp.scatter,
            0.0,
            1.0,
            (v) => setState(() => _stamp = _stamp.copyWith(scatter: v)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.image_outlined, size: 16),
            label: Text(l10n.stampChangeImageButton),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (result == null ||
                  result.files.isEmpty ||
                  result.files.first.path == null) {
                return;
              }
              if (!context.mounted) return;
              final service = context.read<StampService>();
              await service.createStampFromImage(
                result.files.first.path!,
                name: _nameController.text,
              );
              service.deleteStamp(_stamp.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context.read<StampService>().updateStamp(
                _stamp.copyWith(name: _nameController.text),
              );
              Navigator.pop(context);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  Widget _intSliderRow(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: SteppedSlider(
            min: min.toDouble(),
            max: max.toDouble(),
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            step: 1,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 40,
          child: EditableSliderValue(
            text: value.toString(),
            style: const TextStyle(fontSize: 12),
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            isInt: true,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: SteppedSlider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            step: 0.1,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: EditableSliderValue(
            text: value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 12),
            value: value,
            min: min,
            max: max,
            isInt: false,
            onChanged: (v) => onChanged(v.toDouble()),
          ),
        ),
      ],
    );
  }
}
