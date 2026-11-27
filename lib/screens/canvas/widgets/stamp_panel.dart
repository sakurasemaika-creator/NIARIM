import 'dart:io';

import 'package:niarim/services/theme_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../widgets/confirm_delete.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/creative_preset_labels.dart';
import '../../../models/stamp.dart';
import '../../../services/brush_service.dart';
import '../../../services/export_share_service.dart';
import '../../../services/shared_asset_card_service.dart';
import '../../../services/stamp_service.dart';
import '../../../widgets/labeled_slider.dart';
import 'creative_folder_sheets.dart';
import '../../../widgets/docked_panel_scope.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/duplicate_name.dart';
import '../../../utils/reorder_index.dart';
import 'asset_list_header_row.dart';
import 'asset_panel_actions.dart';
import 'asset_search_bar.dart';
import 'asset_tag_dialog.dart';
import '../../../widgets/asset_tag_label.dart';
import '../../../widgets/preset_stroke_row.dart';
import '../../../widgets/list_ink_clip.dart';
import '../../../utils/file_failure_reason.dart';
import '../../../widgets/menu_action_label.dart';

/// スタンプの全機能管理パネル（一覧・お気に入り・検索・
/// 自作スタンプ・読み込み・書き出し・フォルダ管理）。ブラシパネルと同構成。
class StampPanel extends StatefulWidget {
  final VoidCallback onClose;
  final bool embedded;
  final double? embeddedHeight;
  final VoidCallback? onPresetSelected;
  const StampPanel({
    super.key,
    required this.onClose,
    this.embedded = false,
    this.embeddedHeight,
    this.onPresetSelected,
  });

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stampService = context.watch<StampService>();
    final drawingColor = context.select<BrushService?, Color?>(
      (brushes) => brushes?.currentColor,
    );
    final allStamps = stampService.stamps;
    final folders = stampService.folders;
    final folderIds = {for (final folder in folders) folder.id};
    final folderFilter =
        _folderFilter == '' || folderIds.contains(_folderFilter)
        ? _folderFilter
        : null;
    var stamps = _showFavoritesOnly
        ? allStamps.where((s) => s.isFavorite)
        : allStamps.where((_) => true);
    if (folderFilter == '') {
      stamps = stamps.where((s) => !folderIds.contains(s.folderId));
    } else if (folderFilter != null) {
      stamps = stamps.where((s) => s.folderId == folderFilter);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      stamps = stamps.where(
        (s) => assetMatchesSearch(
          name: creativePresetLabel(
            l10n,
            s.name,
            builtIn: stampService.isBuiltIn(s.id),
          ),
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
        _showFavoritesOnly || query.isNotEmpty || folderFilter != null;

    return PanelSurface(
      width: 280,
      height: widget.embeddedHeight ?? 460,
      embedded: widget.embedded,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.embedded) PanelCenterCloseBar(onClose: widget.onClose),
            // 一覧の名前・お気に入りのみ・検索と、フォルダ・新規・読込。名前の
            // 無い一覧（ペンのタブ・ドック）では1行にまとめる。入らない幅では
            // 文字を縮めず、アイコンだけにする（名前は吹き出しと読み上げ）。
            AssetListHeaderRow(
              title: !widget.embedded ? l10n.stampTitle : null,
              favoritesOnly: _showFavoritesOnly,
              onFavoritesOnlyChanged: (selected) =>
                  setState(() => _showFavoritesOnly = selected),
              searching: _showSearch,
              onSearchPressed: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              }),
              actions: AssetPanelActions.list(
                l10n,
                onFolder: () => _openFolderManagement(context, stampService),
                onCreate: () => _createFromImage(context, stampService),
                onImport: () => SharedAssetCardService.pickAndImport(
                  context,
                  stampService: stampService,
                ),
              ),
            ),
            // 【不具合修正】brush_panel.dartと同じ理由（PC/DeXモードの
            // ドッキングパネル既定幅ではボタン3つの自然幅が収まらず
            // RenderFlexがオーバーフローしていた）で横スクロール化。
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
                        folderFilter == null,
                        () => setState(() => _folderFilter = null),
                      ),
                      _folderChip(
                        l10n.folderNone,
                        folderFilter == '',
                        () => setState(() => _folderFilter = ''),
                      ),
                      ...folders.map(
                        (f) => _folderChip(
                          f.name,
                          folderFilter == f.id,
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
                availableTags: localizeAssetTags(l10n, stampService.allTags()),
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
                onClose: () => setState(() {
                  _showSearch = false;
                  _searchQuery = '';
                  _searchController.clear();
                }),
              ),
            const Divider(),
            Expanded(
              child: stampList.isEmpty
                  // 絞り込み（お気に入り・検索・フォルダ）で全部隠れたときは
                  // 「スタンプがありません」と言わない（ブラシの一覧と同じ）。
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isFiltering && allStamps.isNotEmpty
                                  ? l10n.helpNoResults
                                  : l10n.stampEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            if (query.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                }),
                                child: Text(l10n.projectListClearSearch),
                              ),
                          ],
                        ),
                      ),
                    )
                  // 選んだ行の背景を一覧の外（上のタブ・ボタン）へはみ出させない
                  // （末尾のclipListInk）。
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
                        return PresetStrokeRow(
                          key: ValueKey(stamp.id),
                          name: creativePresetLabel(
                            l10n,
                            stamp.name,
                            builtIn: stampService.isBuiltIn(stamp.id),
                          ),
                          color:
                              drawingColor ??
                              Theme.of(context).colorScheme.onSurface,
                          stamp: stamp,
                          selected: isSelected,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: stamp.isFavorite
                                    ? l10n.colorPickerFavoriteRemove
                                    : l10n.colorPickerFavoriteAdd,
                                child: GestureDetector(
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
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 14),
                                onSelected: (action) =>
                                    _handleAction(context, action, stamp),
                                itemBuilder: (_) => [
                                  if (!builtIn)
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(l10n.creativePanelEditAction),
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
                                    value: 'assetCard',
                                    // 書き出しと共有が終わるまで、同じ
                                    // スタンプをもう一度は書き出さない。
                                    enabled: !ExportShareService.isRunning(
                                      _exportKey(stamp),
                                    ),
                                    child: Text(
                                      SharedAssetCardService.exportMenuLabel(
                                        context,
                                      ),
                                    ),
                                  ),
                                  if (!builtIn)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: MenuActionLabel(
                                        icon: Icons.delete_outline,
                                        label: l10n.commonDelete,
                                        destructive: true,
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
                          onTap: () {
                            stampService.selectStamp(stamp.id);
                            widget.onPresetSelected?.call();
                          },
                          onLongPress: builtIn
                              ? null
                              : () => _showStampSettings(context, stamp),
                        );
                      },
                    ).clipListInk(),
            ),
          ],
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
            style: localizedHeadingStyle(
              context,
              const TextStyle(fontSize: 11),
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
        // 言語に合わせた「名前 (コピー)」、同じ名前があれば番号を付ける
        // （複製の複製も元の名前に番号。ブラシの一覧と同じ）。
        service.duplicateStamp(
          stamp.id,
          name: numberedCopyName(l10n, stamp.name, {
            for (final s in service.stamps) s.name,
          }),
        );
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
          assetName: creativePresetLabel(
            l10n,
            stamp.name,
            builtIn: service.isBuiltIn(stamp.id),
          ),
          currentTags: localizeAssetTags(l10n, stamp.tags),
          suggestions: localizeAssetTags(l10n, service.allTags()),
          // ダイアログは表示文言で編集させるので、保存時にキーへ戻す。
          // ここを通さないと既定タグがその言語の文字列として焼き付き、
          // 言語を切り替えても元に戻らなくなる。
          onSave: (tags) =>
              service.setTags(stamp.id, delocalizeAssetTags(l10n, tags)),
        );
      case 'assetCard':
        _exportStamp(context, service, stamp);
      case 'delete':
        _deleteStamp(context, service, stamp);
    }
  }

  /// お気に入り登録中は削除できない。消したスタンプは戻せない（自作の画像は
  /// 作り直しになる）ので、ブラシと同じく確かめてから消す。
  Future<void> _deleteStamp(
    BuildContext context,
    StampService service,
    Stamp stamp,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (stamp.isFavorite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    final confirmed = await confirmDelete(
      context,
      itemName: creativePresetLabel(
        l10n,
        stamp.name,
        builtIn: service.isBuiltIn(stamp.id),
      ),
    );
    if (!confirmed) return;
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
      onDelete: (id) async {
        await service.deleteFolder(id);
        if (mounted && _folderFilter == id) {
          setState(() => _folderFilter = null);
        }
      },
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

  static String _exportKey(Stamp stamp) => 'stamp:${stamp.id}';

  /// PNG共有カードの生成と端末への保存・共有を順に処理する。
  Future<void> _exportStamp(
    BuildContext context,
    StampService service,
    Stamp stamp,
  ) => ExportShareService.runExclusive(_exportKey(stamp), () async {
    final l10n = AppLocalizations.of(context)!;
    final File file;
    try {
      file = await SharedAssetCardService.exportStamp(
        service,
        stamp,
        l10n: l10n,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.stampExportFailedSnackbar(fileFailureReason(l10n, e)),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await SharedAssetCardService.showExportResult(context, file);
  });
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
            style: localizedHeadingStyle(
              context,
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    return LabeledSlider(
      label: label,
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      valueText: value.toString(),
      onChanged: (v) => onChanged(v.round()),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return LabeledSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      step: 0.1,
      isInt: false,
      valueText: value.toStringAsFixed(1),
      onChanged: onChanged,
    );
  }
}
