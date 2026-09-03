import 'package:niarim/services/theme_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/brush.dart';
import '../../../services/brush_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/pixel_color_mode_selector.dart';
import '../../../widgets/stepped_slider.dart';
import 'creative_folder_sheets.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/reorder_index.dart';
import 'asset_search_bar.dart';
import 'asset_tag_dialog.dart';
import '../../../widgets/asset_tag_label.dart';

class BrushPanel extends StatefulWidget {
  final VoidCallback onClose;
  const BrushPanel({super.key, required this.onClose});

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
                      color: _showFavoritesOnly ? ThemeService.activeColorScheme.tertiary : null,
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
                            color: ThemeService.activeColorScheme.onSurfaceVariant,
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
                                        ? ThemeService.activeColorScheme.tertiary
                                        : ThemeService.activeColorScheme.onSurfaceVariant,
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
                                            color: ThemeService.activeColorScheme.error,
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
                                        color: ThemeService.activeColorScheme.onSurfaceVariant,
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
      builder: (ctx) => _BrushSettingsSheet(brush: brush),
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
    final l10n = AppLocalizations.of(context)!;
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
          // サイズ
          _sliderRow(
            l10n.brushSettingsSizeLabel,
            _brush.size,
            1,
            500,
            (v) => setState(() => _brush = _brush.copyWith(size: v)),
          ),
          // 不透明度
          _sliderRow(
            l10n.brushSettingsOpacityLabel,
            _brush.opacity.toDouble(),
            1,
            100,
            (v) => setState(() => _brush = _brush.copyWith(opacity: v.round())),
          ),
          // 間隔
          _sliderRow(
            l10n.brushSettingsSpacingLabel,
            _brush.spacing.toDouble(),
            1,
            100,
            (v) => setState(() => _brush = _brush.copyWith(spacing: v.round())),
          ),
          // ぼかし半径（0〜100・デフォルト0）
          _sliderRow(
            l10n.brushSettingsBlurRadiusLabel,
            _brush.blurRadius.toDouble(),
            0,
            100,
            (v) =>
                setState(() => _brush = _brush.copyWith(blurRadius: v.round())),
          ),
          const Divider(),
          // 回転・密度・散布（スタンプと同じ意味／範囲）
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
          const Divider(),
          // 手ブレ補正
          SwitchListTile(
            title: Text(l10n.brushSettingsStabilizationTitle),
            value: _brush.stabilization,
            onChanged: (v) =>
                setState(() => _brush = _brush.copyWith(stabilization: v)),
          ),
          if (_brush.stabilization)
            _sliderRow(
              l10n.brushSettingsStabilizationStrengthLabel,
              _brush.stabilizationStrength.toDouble(),
              0,
              100,
              (v) => setState(
                () =>
                    _brush = _brush.copyWith(stabilizationStrength: v.round()),
              ),
            ),
          // ピクセルモード（旧称：ドットペンモード。
          // 「ドット」だと水玉模様と誤認される恐れがあるため改称）
          SwitchListTile(
            title: Text(l10n.brushSettingsPixelModeTitle),
            value: _brush.pixelMode,
            onChanged: (v) =>
                setState(() => _brush = _brush.copyWith(pixelMode: v)),
          ),
          if (_brush.pixelMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: PixelColorModeSelector(
                mode: _brush.pixelColorMode,
                colorLevels: _brush.pixelColorLevels,
                explicitColors: _brush.pixelExplicitColors,
                onModeChanged: (m) =>
                    setState(() => _brush = _brush.copyWith(pixelColorMode: m)),
                onColorLevelsChanged: (v) => setState(
                  () => _brush = _brush.copyWith(pixelColorLevels: v),
                ),
                onExplicitColorsChanged: (c) => setState(
                  () => _brush = _brush.copyWith(pixelExplicitColors: c),
                ),
              ),
            ),
          const Divider(),
          // 筆圧設定
          Text(
            l10n.brushSettingsPressureModeTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
          // spreadのままだとRadioGroupを祖先に置けないため、Columnで束ねる。
          RadioGroup<PressureMode>(
            groupValue: _brush.pressureMode,
            onChanged: (v) =>
                setState(() => _brush = _brush.copyWith(pressureMode: v)),
            child: Column(
              children: PressureMode.values
                  .map(
                    (mode) => RadioListTile<PressureMode>(
                      title: Text(_pressureLabel(l10n, mode)),
                      value: mode,
                      dense: true,
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(),
          // フェード
          Text(
            l10n.brushSettingsFadeModeTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
          // spreadのままだとRadioGroupを祖先に置けないため、Columnで束ねる。
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
              _brush.fadeCustom?.startValue ?? 100,
              0,
              100,
              (v) => setState(
                () => _brush = _brush.copyWith(
                  fadeCustom: FadeCustomSettings(
                    startValue: v,
                    endValue: _brush.fadeCustom?.endValue ?? 0,
                    distancePx: _brush.fadeCustom?.distancePx ?? 500,
                  ),
                ),
              ),
            ),
            _sliderRow(
              l10n.brushSettingsFadeEndValueLabel,
              _brush.fadeCustom?.endValue ?? 0,
              0,
              100,
              (v) => setState(
                () => _brush = _brush.copyWith(
                  fadeCustom: FadeCustomSettings(
                    startValue: _brush.fadeCustom?.startValue ?? 100,
                    endValue: v,
                    distancePx: _brush.fadeCustom?.distancePx ?? 500,
                  ),
                ),
              ),
            ),
            _sliderRow(
              l10n.brushSettingsFadeDistanceLabel,
              _brush.fadeCustom?.distancePx ?? 500,
              10,
              2000,
              (v) => setState(
                () => _brush = _brush.copyWith(
                  fadeCustom: FadeCustomSettings(
                    startValue: _brush.fadeCustom?.startValue ?? 100,
                    endValue: _brush.fadeCustom?.endValue ?? 0,
                    distancePx: v,
                  ),
                ),
              ),
            ),
          ],
          const Divider(),
          // ストローク減衰
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
          const Divider(),
          // ふち滲み
          SwitchListTile(
            title: Text(l10n.brushSettingsEdgeJitterTitle),
            subtitle: Text(
              l10n.brushSettingsEdgeJitterSubtitle,
              style: const TextStyle(fontSize: 11),
            ),
            value: _brush.edgeJitter,
            onChanged: (v) =>
                setState(() => _brush = _brush.copyWith(edgeJitter: v)),
          ),
          if (_brush.edgeJitter)
            _sliderRow(
              l10n.brushSettingsEdgeJitterStrengthLabel,
              _brush.edgeJitterStrength.toDouble(),
              0,
              100,
              (v) => setState(
                () => _brush = _brush.copyWith(edgeJitterStrength: v.round()),
              ),
            ),
          const Divider(),
          // 混色
          Text(
            l10n.brushSettingsMixingTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            ),
          ),
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
          // spreadのままだとRadioGroupを祖先に置けないため、Columnで束ねる。
          RadioGroup<BrushMixingMode>(
            groupValue: _brush.mixingMode,
            onChanged: (v) =>
                setState(() => _brush = _brush.copyWith(mixingMode: v)),
            child: Column(
              children: BrushMixingMode.values
                  .map(
                    (mode) => RadioListTile<BrushMixingMode>(
                      title: Text(_mixingModeLabel(l10n, mode)),
                      value: mode,
                      dense: true,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_brush.mixingMode != BrushMixingMode.off) ...[
            Text(
              l10n.brushSettingsMixingRateLabel,
              style: const TextStyle(fontSize: 12),
            ),
            Wrap(
              spacing: 8,
              children: kMixingRateOptions
                  .map(
                    (rate) => ChoiceChip(
                      label: Text(
                        rate == 0 ? l10n.brushSettingsMixingOff : '$rate%',
                      ),
                      selected: _brush.mixingRate == rate,
                      onSelected: (selected) {
                        if (selected) {
                          setState(
                            () => _brush = _brush.copyWith(mixingRate: rate),
                          );
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
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

  String _pressureLabel(AppLocalizations l10n, PressureMode mode) =>
      switch (mode) {
        PressureMode.off => l10n.brushSettingsPressureOff,
        PressureMode.size => l10n.brushSettingsPressureSize,
        PressureMode.opacity => l10n.brushSettingsPressureOpacity,
        PressureMode.sizeAndOpacity => l10n.brushSettingsPressureSizeAndOpacity,
      };

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
