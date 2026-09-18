import 'package:niarim/services/theme_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/brush.dart';
import '../../../services/brush_service.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/pixel_color_mode_selector.dart';
import '../../../widgets/stepped_slider.dart';
import 'creative_folder_sheets.dart';
import 'panel_close_bar.dart';
import 'color_picker_panel.dart';
import 'brush_extension_settings.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/reorder_index.dart';
import 'asset_search_bar.dart';
import 'asset_tag_dialog.dart';
import '../../../widgets/asset_tag_label.dart';

class BrushPanel extends StatefulWidget {
  final VoidCallback onClose;
  final Future<int?> Function()? onEyedropOutlineColor;
  const BrushPanel({
    super.key,
    required this.onClose,
    this.onEyedropOutlineColor,
  });

  @override
  State<BrushPanel> createState() => _BrushPanelState();
}

class _BrushPanelState extends State<BrushPanel> {
  bool _showFavoritesOnly = false;
  bool _showSearch = false;
  AssetSearchMode _searchMode = AssetSearchMode.keyword;
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
    final l10n = AppLocalizations.of(context)!;
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
      brushes = brushes.where(
        (b) => assetMatchesSearch(
          name: b.name,
          // 既定タグは言語非依存のキーで保存されているため、その言語での
          // 表示文言へ直してから突き合わせる（英語UIで「pixel」と打って
          // ドット絵向けの素材が出る、という当たり前の挙動にするため）。
          tags: localizeAssetTags(l10n, b.tags),
          mode: _searchMode,
          query: query,
        ),
      );
    }
    final brushList = brushes.toList();
    final isFiltering =
        _showFavoritesOnly ||
        query.isNotEmpty ||
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
              PanelCenterCloseBar(onClose: widget.onClose),
              Row(
                children: [
                  Text(
                    l10n.penSubToolTabBrush,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  Spacer(),
                  // お気に入りのみ表示
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
              // フォルダ管理・自作ブラシ・読み込み。
              // 【不具合修正】PC/DeXモードのドッキングパネルは既定幅
              // 280px（パディング差引後240px）まで狭められるため、
              // 3ボタンの自然幅がわずかに収まらずRenderFlexが
              // オーバーフローしていた（PC/DeXモードのドッキングパネルを
              // 実際に自律テストで開くまで気付かれていなかった）。
              // 横スクロール可能にして、狭い幅でも常に例外なく描画・
              // 全ボタンへアクセスできるようにする。
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
                          _openFolderManagement(context, brushService),
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
                      onPressed: () => _createFromImage(context, brushService),
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
                      onPressed: () => _importBrush(context, brushService),
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
                          context,
                          l10n.creativePanelFolderAllChip,
                          _folderFilter == null || _folderFilter == _allFolders,
                          () => setState(() => _folderFilter = null),
                        ),
                        _folderChip(
                          context,
                          l10n.folderNone,
                          _folderFilter == '',
                          () => setState(() => _folderFilter = ''),
                        ),
                        ...folders.map(
                          (f) => _folderChip(
                            context,
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
                    brushService.allTags(),
                  ),
                  keywordHint: l10n.brushSearchHint,
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
                child: brushList.isEmpty
                    ? Center(
                        child: Text(
                          l10n.brushEmpty,
                          style: TextStyle(
                            color:
                                ThemeService.activeColorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        // ドラッグハンドルは行末に明示アイコンとして置く（既定の
                        // ドラッグハンドルだと、行全体の長押しで開く編集シート
                        // （onLongPress）や、お気に入り・三点メニューのタップと
                        // ジェスチャーが競合するため）。
                        buildDefaultDragHandles: false,
                        itemCount: brushList.length,
                        onReorderItem: (oldIndex, newIndex) {
                          if (!isFiltering) {
                            brushService.reorderBrush(
                              oldIndex,
                              preRemovalIndex(oldIndex, newIndex),
                            );
                          }
                        },
                        itemBuilder: (context, index) {
                          final brush = brushList[index];
                          final isSelected = current?.id == brush.id;
                          // プリインストールのブラシは編集・削除できない
                          // （複製したものは複製元とは別IDになるため編集・削除可能）。
                          final builtIn = brushService.isBuiltIn(brush.id);
                          return ListTile(
                            key: ValueKey(brush.id),
                            dense: true,
                            selected: isSelected,
                            leading: Icon(
                              Icons.brush,
                              size: 16,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              brush.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Kuramubon',
                                fontFamilyFallback: kHeadingFontFallback,
                              ),
                            ),
                            subtitle: Text(
                              l10n.penSubToolBrushSizeOpacity(
                                brush.size.round(),
                                brush.opacity,
                              ),
                              style: const TextStyle(fontSize: 10),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => brushService.toggleFavoriteBrush(
                                    brush.id,
                                  ),
                                  child: Icon(
                                    brush.isFavorite
                                        ? Icons.star
                                        : Icons.star_outline,
                                    size: 14,
                                    color: brush.isFavorite
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
                                  onSelected: (action) => _handleBrushAction(
                                    context,
                                    action,
                                    brush,
                                  ),
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
                            onTap: () => brushService.selectBrush(brush.id),
                            onLongPress: builtIn
                                ? null
                                : () => _showBrushSettings(context, brush),
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

  Widget _folderChip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return Padding(
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
  }

  void _handleBrushAction(BuildContext context, String action, Brush brush) {
    final service = context.read<BrushService>();
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case 'edit':
        _showBrushSettings(context, brush);
      case 'duplicate':
        service.duplicateBrush(brush.id);
      case 'move':
        showMoveToCreativeFolderSheet(
          context,
          folders: service.folders
              .map((f) => (id: f.id, name: f.name))
              .toList(),
          onSelect: (folderId) => service.moveToFolder(brush.id, folderId),
        );
      case 'tags':
        showAssetTagDialog(
          context,
          assetName: brush.name,
          currentTags: localizeAssetTags(l10n, brush.tags),
          suggestions: localizeAssetTags(l10n, service.allTags()),
          // ダイアログは表示文言で編集させるので、保存時にキーへ戻す。
          // ここを通さないと既定タグがその言語の文字列として焼き付き、
          // 言語を切り替えても元に戻らなくなる。
          onSave: (tags) =>
              service.setTags(brush.id, delocalizeAssetTags(l10n, tags)),
        );
      case 'export':
        _exportBrush(context, service, brush);
      case 'delete':
        _deleteBrush(context, service, brush);
    }
  }

  /// お気に入り登録中は削除できない（誤って
  /// お気に入りのブラシを消してしまう事故を防ぐため）。
  void _deleteBrush(BuildContext context, BrushService service, Brush brush) {
    if (brush.isFavorite) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    service.deleteBrush(brush.id);
  }

  void _showBrushSettings(BuildContext context, Brush brush) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BrushSettingsSheet(
        brush: brush,
        onEyedropOutlineColor: widget.onEyedropOutlineColor,
      ),
    );
  }

  void _openFolderManagement(BuildContext context, BrushService service) {
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
    BrushService service,
  ) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    if (!context.mounted) return;
    final name = await promptCreativeAssetName(
      context,
      title: AppLocalizations.of(context)!.brushCreateDialogTitle,
    );
    if (name == null) return;
    await service.createBrushFromImage(result.files.first.path!, name: name);
  }

  Future<void> _importBrush(BuildContext context, BrushService service) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['niabrush'],
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    try {
      await service.importBrushFile(result.files.first.path!);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.brushImportFailedSnackbar('$e'))),
      );
    }
  }

  Future<void> _exportBrush(
    BuildContext context,
    BrushService service,
    Brush brush,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final file = await service.exportBrush(brush.id);
      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.brushExportFailedSnackbar('$e'))),
      );
    }
  }
}

class _BrushSettingsSheet extends StatefulWidget {
  final Brush brush;
  final Future<int?> Function()? onEyedropOutlineColor;
  const _BrushSettingsSheet({required this.brush, this.onEyedropOutlineColor});

  @override
  State<_BrushSettingsSheet> createState() => _BrushSettingsSheetState();
}

class _BrushSettingsSheetState extends State<_BrushSettingsSheet> {
  Future<void> _showOutlineColorPicker() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ColorPickerPanel(
          currentColor: Color(_brush.outlineColor),
          onColorChanged: (color) {
            if (!mounted) return;
            setState(
              () => _brush = _brush.copyWith(outlineColor: color.toARGB32()),
            );
          },
          onClose: () => Navigator.of(dialogContext).pop(),
          onEyedropperTap: widget.onEyedropOutlineColor == null
              ? null
              : () async {
                  Navigator.of(dialogContext).pop();
                  final sampled = await widget.onEyedropOutlineColor!();
                  if (!mounted || sampled == null) return;
                  setState(
                    () => _brush = _brush.copyWith(outlineColor: sampled),
                  );
                },
        ),
      ),
    );
  }

  Future<void> _eyedropOutlineColor() async {
    final callback = widget.onEyedropOutlineColor;
    if (callback == null) return;
    final service = context.read<BrushService>();
    final draft = _brush;
    Navigator.of(context).pop();
    final sampled = await callback();
    if (sampled == null) return;
    service.updateBrush(draft.copyWith(outlineColor: sampled));
  }

  late Brush _brush;

  @override
  void initState() {
    super.initState();
    _brush = widget.brush;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final penPressureEnabled = context
        .read<SettingsService>()
        .penPressureEnabled;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _brush.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          const SizedBox(height: 16),
          _settingsSection(
            title: l10n.brushSettingsCommonSection,
            initiallyExpanded: true,
            children: [
              _sliderRow(
                l10n.brushSettingsSpacingLabel,
                _brush.spacing.toDouble(),
                1,
                100,
                (v) => setState(
                  () => _brush = _brush.copyWith(spacing: v.round()),
                ),
              ),
              SwitchListTile(
                title: Text(l10n.stampRotationLabel),
                value: _brush.rotation,
                onChanged: (v) =>
                    setState(() => _brush = _brush.copyWith(rotation: v)),
              ),
              _decimalSliderRow(
                l10n.stampDensityLabel,
                _brush.density,
                0.1,
                5.0,
                0.1,
                (v) => setState(() => _brush = _brush.copyWith(density: v)),
              ),
              _decimalSliderRow(
                l10n.stampScatterLabel,
                _brush.scatter,
                0.0,
                1.0,
                0.01,
                (v) => setState(() => _brush = _brush.copyWith(scatter: v)),
              ),
              SwitchListTile(
                title: Text(l10n.brushSettingsPixelModeTitle),
                value: _brush.pixelMode,
                onChanged: (v) =>
                    setState(() => _brush = _brush.copyWith(pixelMode: v)),
              ),
              if (_brush.pixelMode)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: PixelColorModeSelector(
                    mode: _brush.pixelColorMode,
                    colorLevels: _brush.pixelColorLevels,
                    explicitColors: _brush.pixelExplicitColors,
                    onModeChanged: (m) => setState(
                      () => _brush = _brush.copyWith(pixelColorMode: m),
                    ),
                    onColorLevelsChanged: (v) => setState(
                      () => _brush = _brush.copyWith(pixelColorLevels: v),
                    ),
                    onExplicitColorsChanged: (c) => setState(
                      () => _brush = _brush.copyWith(pixelExplicitColors: c),
                    ),
                  ),
                ),
              Text(
                l10n.brushSettingsFadeModeTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              RadioGroup<FadeMode>(
                groupValue: _brush.fadeMode,
                onChanged: (v) =>
                    setState(() => _brush = _brush.copyWith(fadeMode: v)),
                child: Column(
                  children: FadeMode.values
                      .map(
                        (mode) => RadioListTile<FadeMode>(
                          title: Text(_fadeModeLabel(l10n, mode)),
                          value: mode,
                          dense: true,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (_brush.fadeMode == FadeMode.custom) ...[
                _sliderRow(
                  l10n.brushSettingsFadeStartValueLabel,
                  _brush.fadeIn.value,
                  0,
                  100,
                  (v) => setState(
                    () => _brush = _brush.copyWith(
                      fadeIn: _brush.fadeIn.copyWith(value: v),
                    ),
                  ),
                ),
                _sliderRow(
                  '${l10n.brushSettingsFadeDistanceLabel} (${l10n.brushSettingsFadeStartValueLabel})',
                  _brush.fadeIn.rangePx,
                  10,
                  2000,
                  (v) => setState(
                    () => _brush = _brush.copyWith(
                      fadeIn: _brush.fadeIn.copyWith(rangePx: v),
                    ),
                  ),
                ),
                _sliderRow(
                  l10n.brushSettingsFadeEndValueLabel,
                  _brush.fadeOut.value,
                  0,
                  100,
                  (v) => setState(
                    () => _brush = _brush.copyWith(
                      fadeOut: _brush.fadeOut.copyWith(value: v),
                    ),
                  ),
                ),
                _sliderRow(
                  '${l10n.brushSettingsFadeDistanceLabel} (${l10n.brushSettingsFadeEndValueLabel})',
                  _brush.fadeOut.rangePx,
                  10,
                  2000,
                  (v) => setState(
                    () => _brush = _brush.copyWith(
                      fadeOut: _brush.fadeOut.copyWith(rangePx: v),
                    ),
                  ),
                ),
              ],
              SwitchListTile(
                title: Text(l10n.brushSettingsStrokeDecayTitle),
                subtitle: Text(
                  l10n.brushSettingsStrokeDecaySubtitle,
                  style: const TextStyle(fontSize: 11),
                ),
                value: _brush.strokeDecay,
                onChanged: (v) =>
                    setState(() => _brush = _brush.copyWith(strokeDecay: v)),
              ),
            ],
          ),
          _settingsSection(
            title: l10n.brushSettingsPressureOnSection,
            initiallyExpanded: penPressureEnabled,
            children: [
              _pressureRangeTile(
                label: l10n.brushSettingsSizeLabel,
                setting: _brush.pressureOn.size,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOn: _brush.pressureOn.copyWith(size: v),
                ),
                l10n: l10n,
              ),
              _pressureRangeTile(
                label: l10n.brushSettingsOpacityLabel,
                setting: _brush.pressureOn.opacity,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOn: _brush.pressureOn.copyWith(opacity: v),
                ),
                l10n: l10n,
              ),
              _pressureRangeTile(
                label: l10n.brushSettingsBlurRadiusLabel,
                setting: _brush.pressureOn.blur,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOn: _brush.pressureOn.copyWith(blur: v),
                ),
                l10n: l10n,
              ),
              _pressureRangeTile(
                label: l10n.brushSettingsEdgeJitterTitle,
                setting: _brush.pressureOn.edgeJitter,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOn: _brush.pressureOn.copyWith(edgeJitter: v),
                ),
                l10n: l10n,
              ),
              _pressureMixingOnTile(l10n),
            ],
          ),
          _settingsSection(
            title: l10n.brushSettingsPressureOffSection,
            initiallyExpanded: !penPressureEnabled,
            children: [
              _fixedPressureTile(
                label: l10n.brushSettingsBlurRadiusLabel,
                setting: _brush.pressureOff.blur,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOff: _brush.pressureOff.copyWith(blur: v),
                ),
                l10n: l10n,
              ),
              _fixedPressureTile(
                label: l10n.brushSettingsEdgeJitterTitle,
                setting: _brush.pressureOff.edgeJitter,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOff: _brush.pressureOff.copyWith(edgeJitter: v),
                ),
                l10n: l10n,
              ),
              _pressureMixingOffTile(l10n),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          BrushExtensionSettings(
            brush: _brush,
            labels: BrushExtensionLabels.fromLocalizations(l10n),
            onChanged: (value) => setState(() => _brush = value),
            onPickOutlineColor: _showOutlineColorPicker,
            onEyedropOutlineColor: widget.onEyedropOutlineColor == null
                ? null
                : _eyedropOutlineColor,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context.read<BrushService>().updateBrush(_brush);
              Navigator.pop(context);
            },
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  Widget _settingsSection({
    required String title,
    required bool initiallyExpanded,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
        ),
      ),
      initiallyExpanded: initiallyExpanded,
      childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      children: children,
    );
  }

  Widget _pressureRangeTile({
    required String label,
    required PressureRangeSetting setting,
    required ValueChanged<PressureRangeSetting> onChanged,
    required AppLocalizations l10n,
  }) {
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          title: Text(label),
          value: setting.enabled,
          onChanged: (v) =>
              setState(() => onChanged(setting.copyWith(enabled: v))),
        ),
        if (setting.enabled) ...[
          _sliderRow(
            l10n.brushSettingsWeakPressureLabel,
            setting.weak.toDouble(),
            0,
            100,
            (v) => setState(() => onChanged(setting.copyWith(weak: v.round()))),
          ),
          _sliderRow(
            l10n.brushSettingsStrongPressureLabel,
            setting.strong.toDouble(),
            0,
            100,
            (v) =>
                setState(() => onChanged(setting.copyWith(strong: v.round()))),
          ),
        ],
      ],
    );
  }

  Widget _fixedPressureTile({
    required String label,
    required FixedBrushSetting setting,
    required ValueChanged<FixedBrushSetting> onChanged,
    required AppLocalizations l10n,
  }) {
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          title: Text(label),
          value: setting.enabled,
          onChanged: (v) =>
              setState(() => onChanged(setting.copyWith(enabled: v))),
        ),
        if (setting.enabled)
          _sliderRow(
            l10n.brushSettingsValueLabel,
            setting.value.toDouble(),
            0,
            100,
            (v) =>
                setState(() => onChanged(setting.copyWith(value: v.round()))),
          ),
      ],
    );
  }

  Widget _pressureMixingOnTile(AppLocalizations l10n) {
    final setting = _brush.pressureOn.mixing;
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          title: Text(l10n.brushSettingsMixingTitle),
          value: setting.enabled,
          onChanged: (v) => setState(
            () => _brush = _brush.copyWith(
              pressureOn: _brush.pressureOn.copyWith(
                mixing: setting.copyWith(enabled: v),
              ),
            ),
          ),
        ),
        if (setting.enabled) ...[
          _pressureMixingModeSelector(
            l10n: l10n,
            mode: setting.mode,
            onChanged: (mode) => setState(
              () => _brush = _brush.copyWith(
                pressureOn: _brush.pressureOn.copyWith(
                  mixing: setting.copyWith(mode: mode),
                ),
              ),
            ),
          ),
          _sliderRow(
            l10n.brushSettingsWeakPressureLabel,
            setting.weakRate.toDouble(),
            0,
            100,
            (v) => setState(
              () => _brush = _brush.copyWith(
                pressureOn: _brush.pressureOn.copyWith(
                  mixing: setting.copyWith(weakRate: v.round()),
                ),
              ),
            ),
          ),
          _sliderRow(
            l10n.brushSettingsStrongPressureLabel,
            setting.strongRate.toDouble(),
            0,
            100,
            (v) => setState(
              () => _brush = _brush.copyWith(
                pressureOn: _brush.pressureOn.copyWith(
                  mixing: setting.copyWith(strongRate: v.round()),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pressureMixingOffTile(AppLocalizations l10n) {
    final setting = _brush.pressureOff.mixing;
    return Column(
      children: [
        SwitchListTile(
          dense: true,
          title: Text(l10n.brushSettingsMixingTitle),
          value: setting.enabled,
          onChanged: (v) => setState(
            () => _brush = _brush.copyWith(
              pressureOff: _brush.pressureOff.copyWith(
                mixing: setting.copyWith(enabled: v),
              ),
            ),
          ),
        ),
        if (setting.enabled) ...[
          _pressureMixingModeSelector(
            l10n: l10n,
            mode: setting.mode,
            onChanged: (mode) => setState(
              () => _brush = _brush.copyWith(
                pressureOff: _brush.pressureOff.copyWith(
                  mixing: setting.copyWith(mode: mode),
                ),
              ),
            ),
          ),
          _sliderRow(
            l10n.brushSettingsValueLabel,
            setting.rate.toDouble(),
            0,
            100,
            (v) => setState(
              () => _brush = _brush.copyWith(
                pressureOff: _brush.pressureOff.copyWith(
                  mixing: setting.copyWith(rate: v.round()),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pressureMixingModeSelector({
    required AppLocalizations l10n,
    required BrushMixingMode mode,
    required ValueChanged<BrushMixingMode> onChanged,
  }) {
    final modes = [BrushMixingMode.simple, BrushMixingMode.bleed];
    return RadioGroup<BrushMixingMode>(
      groupValue: mode == BrushMixingMode.off ? BrushMixingMode.simple : mode,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      child: Column(
        children: modes
            .map(
              (value) => RadioListTile<BrushMixingMode>(
                dense: true,
                title: Text(_mixingModeLabel(l10n, value)),
                value: value,
              ),
            )
            .toList(),
      ),
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
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: SteppedSlider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: EditableSliderValue(
            text: value.round().toString(),
            style: const TextStyle(fontSize: 12),
            value: value,
            min: min,
            max: max,
            onChanged: (v) => onChanged(v.toDouble()),
          ),
        ),
      ],
    );
  }

  Widget _decimalSliderRow(
    String label,
    double value,
    double min,
    double max,
    double step,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: SteppedSlider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            step: step,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: EditableSliderValue(
            text: value.toStringAsFixed(step < 0.1 ? 2 : 1),
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

  String _fadeModeLabel(AppLocalizations l10n, FadeMode mode) => switch (mode) {
    FadeMode.off => l10n.brushSettingsFadeOff,
    FadeMode.weak => l10n.brushSettingsFadeWeak,
    FadeMode.medium => l10n.brushSettingsFadeMedium,
    FadeMode.strong => l10n.brushSettingsFadeStrong,
    FadeMode.custom => l10n.brushSettingsFadeCustom,
  };

  String _mixingModeLabel(AppLocalizations l10n, BrushMixingMode mode) =>
      switch (mode) {
        BrushMixingMode.off => l10n.brushSettingsMixingOff,
        BrushMixingMode.simple => l10n.brushSettingsMixingSimple,
        BrushMixingMode.bleed => l10n.brushSettingsMixingBleed,
      };
}
