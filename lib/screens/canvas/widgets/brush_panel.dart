import 'dart:io';

import 'package:niarim/services/theme_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/brush.dart';
import '../../../services/brush_service.dart';
import '../../../services/export_share_service.dart';
import '../../../services/shared_asset_card_service.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../widgets/preset_stroke_row.dart';
import '../../../widgets/pixel_color_mode_selector.dart';
import 'creative_folder_sheets.dart';
import '../../../widgets/docked_panel_scope.dart';
import 'panel_close_bar.dart';
import 'color_picker_panel.dart';
import 'brush_extension_settings.dart';
import 'brush_tip_settings.dart';
import '../../../config/font_fallback.dart';
import '../../../utils/duplicate_name.dart';
import '../../../utils/reorder_index.dart';
import 'asset_list_header_row.dart';
import 'asset_search_bar.dart';
import 'asset_tag_dialog.dart';
import '../../../widgets/asset_tag_label.dart';
import '../../../widgets/list_ink_clip.dart';

class BrushPanel extends StatefulWidget {
  final VoidCallback onClose;

  /// Embedded inside the single Brush/Tone/Stamp picker with all management
  /// actions intact. Legacy standalone panel entries remain as aliases.
  final bool embedded;
  final double? embeddedHeight;
  final VoidCallback? onPresetSelected;
  final bool dockedMode;
  final Future<int?> Function()? onEyedropOutlineColor;
  const BrushPanel({
    super.key,
    required this.onClose,
    this.embedded = false,
    this.embeddedHeight,
    this.onPresetSelected,
    this.dockedMode = false,
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

    return PanelSurface(
      width: 280,
      height: widget.embeddedHeight ?? 460,
      embedded: widget.embedded,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ドックの中では窓の見出しの×で閉じる（PanelCenterCloseBarも
            // DockedPanelScopeの中では出ない）。
            if (!widget.dockedMode && !widget.embedded)
              PanelCenterCloseBar(onClose: widget.onClose),
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
                    onPressed: () => SharedAssetCardService.pickAndImport(
                      context,
                      brushService: brushService,
                    ),
                  ),
                ],
              ),
            ),
            // 一覧の名前・お気に入りのみ・検索。入らない幅では文字を縮めず、
            // お気に入りを星だけにする（名前は吹き出しと読み上げ）。
            AssetListHeaderRow(
              title:
                  !DockedPanelScope.of(context) &&
                      !widget.dockedMode &&
                      !widget.embedded
                  ? l10n.penSubToolTabBrush
                  : null,
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
            ),
            // フォルダ管理・自作ブラシ・読み込み。
            // 【不具合修正】PC/DeXモードのドッキングパネルは既定幅
            // 280px（パディング差引後240px）まで狭められるため、
            // 3ボタンの自然幅がわずかに収まらずRenderFlexが
            // オーバーフローしていた（PC/DeXモードのドッキングパネルを
            // 実際に自律テストで開くまで気付かれていなかった）。
            // 横スクロール可能にして、狭い幅でも常に例外なく描画・
            // 全ボタンへアクセスできるようにする。
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
                availableTags: localizeAssetTags(l10n, brushService.allTags()),
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
                onClose: () => setState(() {
                  _showSearch = false;
                  _searchQuery = '';
                  _searchController.clear();
                }),
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
                  // 選んだ行の背景を一覧の外（上のタブ・ボタン）へはみ出させない
                  // （末尾のclipListInk）。
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
                        // 使っているブラシは、いま描く太さ・不透明度を出す
                        // （早替えツールが一時的に当てた太さも含む）。
                        final shown = isSelected ? current! : brush;
                        // プリインストールのブラシは編集・削除できない
                        // （複製したものは複製元とは別IDになるため編集・削除可能）。
                        final builtIn = brushService.isBuiltIn(brush.id);
                        return PresetStrokeRow(
                          key: ValueKey(brush.id),
                          name: brush.name,
                          color: brushService.currentColor,
                          brush: shown,
                          selected: isSelected,
                          semanticsLabel: l10n.penSubToolBrushSizeOpacity(
                            shown.size.round(),
                            shown.opacity,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    brushService.toggleFavoriteBrush(brush.id),
                                child: Icon(
                                  brush.isFavorite
                                      ? Icons.star
                                      : Icons.star_outline,
                                  size: 14,
                                  color: brush.isFavorite
                                      ? ThemeService.activeColorScheme.tertiary
                                      : ThemeService
                                            .activeColorScheme
                                            .onSurfaceVariant,
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 14),
                                onSelected: (action) =>
                                    _handleBrushAction(context, action, brush),
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
                                    // ブラシをもう一度は書き出さない。
                                    enabled: !ExportShareService.isRunning(
                                      _exportKey(brush),
                                    ),
                                    child: Text(
                                      SharedAssetCardService.exportMenuLabel(
                                        context,
                                      ),
                                    ),
                                  ),
                                  // 組み込みブラシは、キャンバスで変えて
                                  // 覚えた太さ・不透明度を既定へ戻せる。
                                  if (brushService.hasRememberedBuiltInValues(
                                    brush.id,
                                  ))
                                    PopupMenuItem(
                                      value: 'resetValues',
                                      child: Text(
                                        l10n.brushPanelResetRememberedValues,
                                      ),
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
                          onTap: () {
                            brushService.selectBrush(brush.id);
                            widget.onPresetSelected?.call();
                          },
                          onLongPress: builtIn
                              ? null
                              : () => _showBrushSettings(context, brush),
                        );
                      },
                    ).clipListInk(),
            ),
          ],
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
      case 'resetValues':
        service.resetRememberedBuiltInValues(brush.id);
      case 'duplicate':
        // 言語に合わせた「名前 (コピー)」、同じ名前があれば番号を付ける
        // （以前は日本語の「(コピー)」固定で、2回複製すると同じ名前が並んだ）。
        // 引き継ぎで足す複製と同じ形にして、番号を続けて数える。
        service.duplicateBrush(
          brush.id,
          name: numberedCopyName(l10n, brush.name, {
            for (final b in service.brushes) b.name,
          }),
        );
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
      case 'assetCard':
        _exportBrush(context, service, brush);
      case 'delete':
        _deleteBrush(context, service, brush);
    }
  }

  /// お気に入り登録中は削除できない（誤って
  /// お気に入りのブラシを消してしまう事故を防ぐため）。
  Future<void> _deleteBrush(
    BuildContext context,
    BrushService service,
    Brush brush,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (brush.isFavorite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    // 消したブラシは戻せない（自作の画像ブラシは作り直しになる）ので、
    // メニューの1回の押し間違いで消さないよう確かめる。
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.brushPanelDeleteConfirmTitle(brush.name)),
        content: Text(l10n.brushPanelDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('brushDeleteConfirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    service.deleteBrush(brush.id);
  }

  void _showBrushSettings(BuildContext context, Brush brush) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BrushSettingsSheet(
        brush: brush,
        onEyedropOutlineColor: widget.onEyedropOutlineColor,
        // 縁取りの色をキャンバスから取った後、編集中の内容のままシートを
        // 開き直す（パネルが閉じていれば開き直せないので偽を返す）。
        onReopen: (draft) {
          if (!mounted) return false;
          _showBrushSettings(this.context, draft);
          return true;
        },
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

  static String _exportKey(Brush brush) => 'brush:${brush.id}';

  /// PNG共有カードの生成と端末への保存・共有を順に処理する。
  Future<void> _exportBrush(
    BuildContext context,
    BrushService service,
    Brush brush,
  ) => ExportShareService.runExclusive(_exportKey(brush), () async {
    final l10n = AppLocalizations.of(context)!;
    final File file;
    try {
      file = await SharedAssetCardService.exportBrush(
        service,
        brush,
        l10n: l10n,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.brushExportFailedSnackbar('$e'))),
      );
      return;
    }
    if (!context.mounted) return;
    await SharedAssetCardService.showExportResult(context, file);
  });
}

class _BrushSettingsSheet extends StatefulWidget {
  final Brush brush;
  final Future<int?> Function()? onEyedropOutlineColor;
  final bool Function(Brush draft)? onReopen;
  const _BrushSettingsSheet({
    required this.brush,
    this.onEyedropOutlineColor,
    this.onReopen,
  });

  @override
  State<_BrushSettingsSheet> createState() => _BrushSettingsSheetState();
}

class _BrushSettingsSheetState extends State<_BrushSettingsSheet> {
  Future<void> _addImages() async {
    final service = context.read<BrushService>();
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (selected == null || !mounted) return;
    final paths = await service.importBrushImages(
      selected.files.map((file) => file.path).whereType<String>(),
    );
    if (!mounted || paths.isEmpty) return;
    setState(
      () => _brush = _brush.copyWith(
        customImagePaths: [..._brush.resolvedCustomImagePaths, ...paths],
      ),
    );
  }

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
    var draft = _brush;
    final reopen = widget.onReopen;
    Navigator.of(context).pop();
    final sampled = await callback();
    // 色を取るのを待つ間にキャンバスで変えた太さ・不透明度（ブラシごとの
    // 覚え）を、シートを開いたときの値で上書きしない。
    final live = service.brushes.where((b) => b.id == draft.id).firstOrNull;
    if (live != null) {
      draft = draft.copyWith(size: live.size, opacity: live.opacity);
    }
    if (sampled != null) {
      service.updateBrush(draft.copyWith(outlineColor: sampled));
    }
    // 色を取った後は設定のシートへ戻す（以前は閉じたままで、取るのを
    // やめたときは編集中の内容が消えていた）。
    reopen?.call(
      sampled == null ? draft : draft.copyWith(outlineColor: sampled),
    );
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
                kBrushSpacingMax.toDouble(),
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
            title: l10n.brushTipSettingsTitle,
            initiallyExpanded: true,
            children: [
              BrushTipSettings(
                brush: _brush,
                onChanged: (value) => setState(() => _brush = value),
                onAddImages: _addImages,
              ),
              LabeledSlider(
                label: AppLocalizations.of(context)!.brushSettingsPaperGrain,
                value: _brush.grainStrength.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                valueText: '${_brush.grainStrength}%',
                onChanged: (value) => setState(
                  () => _brush = _brush.copyWith(grainStrength: value.round()),
                ),
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
              _amountRangeTile(
                label: l10n.brushSettingsBlurRadiusLabel,
                setting: _brush.pressureOn.blur,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOn: _brush.pressureOn.copyWith(blur: v),
                ),
                l10n: l10n,
              ),
              _amountRangeTile(
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
              _fixedAmountTile(
                label: l10n.brushSettingsBlurRadiusLabel,
                setting: _brush.pressureOff.blur,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOff: _brush.pressureOff.copyWith(blur: v),
                ),
              ),
              _fixedAmountTile(
                label: l10n.brushSettingsEdgeJitterTitle,
                setting: _brush.pressureOff.edgeJitter,
                onChanged: (v) => _brush = _brush.copyWith(
                  pressureOff: _brush.pressureOff.copyWith(edgeJitter: v),
                ),
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

  /// An amount that pressure varies, where 0 means none (ぼかし・ふち滲み):
  /// both sliders are always shown and the setting is on while either is
  /// above 0.
  Widget _amountRangeTile({
    required String label,
    required PressureRangeSetting setting,
    required ValueChanged<PressureRangeSetting> onChanged,
    required AppLocalizations l10n,
  }) {
    final weak = setting.enabled ? setting.weak : 0;
    final strong = setting.enabled ? setting.strong : 0;
    void update(int nextWeak, int nextStrong) => setState(
      () => onChanged(
        PressureRangeSetting(
          enabled: nextWeak > 0 || nextStrong > 0,
          weak: nextWeak,
          strong: nextStrong,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mixingSubheading(label),
        _sliderRow(
          l10n.brushSettingsWeakPressureLabel,
          weak.toDouble(),
          0,
          100,
          (v) => update(v.round(), strong),
        ),
        _sliderRow(
          l10n.brushSettingsStrongPressureLabel,
          strong.toDouble(),
          0,
          100,
          (v) => update(weak, v.round()),
        ),
      ],
    );
  }

  /// A fixed amount where 0 means none (ぼかし・ふち滲み): one slider, on
  /// while above 0.
  Widget _fixedAmountTile({
    required String label,
    required FixedBrushSetting setting,
    required ValueChanged<FixedBrushSetting> onChanged,
  }) {
    return _sliderRow(
      label,
      (setting.enabled ? setting.value : 0).toDouble(),
      0,
      100,
      (v) => setState(
        () => onChanged(
          FixedBrushSetting(enabled: v.round() > 0, value: v.round()),
        ),
      ),
    );
  }

  Widget _pressureMixingOnTile(AppLocalizations l10n) {
    final setting = _brush.pressureOn.mixing;
    final selectedMode = _selectedMixingMode(setting.enabled, setting.mode);
    void update(PressureMixingOnSetting next) => setState(
      () => _brush = _brush.copyWith(
        pressureOn: _brush.pressureOn.copyWith(mixing: next),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mixingModeHeading(l10n),
        _pressureMixingModeSelector(
          l10n: l10n,
          mode: selectedMode,
          onChanged: (mode) {
            final turningOn =
                selectedMode == BrushMixingMode.off &&
                mode != BrushMixingMode.off;
            update(
              setting.copyWith(
                enabled: mode != BrushMixingMode.off,
                mode: mode,
                weakRate: turningOn && setting.weakRate == 0
                    ? 25
                    : setting.weakRate,
                strongRate: turningOn && setting.strongRate == 0
                    ? 75
                    : setting.strongRate,
              ),
            );
          },
        ),
        if (selectedMode != BrushMixingMode.off) ...[
          _mixingModeHint(l10n, selectedMode),
          _mixingSubheading(l10n.brushSettingsMixingAmount),
          _sliderRow(
            l10n.brushSettingsWeakPressureLabel,
            setting.weakRate.toDouble(),
            0,
            100,
            (v) => update(setting.copyWith(weakRate: v.round())),
          ),
          _sliderRow(
            l10n.brushSettingsStrongPressureLabel,
            setting.strongRate.toDouble(),
            0,
            100,
            (v) => update(setting.copyWith(strongRate: v.round())),
          ),
          ..._mixingStyleSliders(
            l10n,
            selectedMode,
            brightnessCorrection: setting.brightnessCorrection,
            stretch: setting.stretch,
            water: setting.water,
            pigment: setting.pigment,
            bleed: setting.bleed,
            texture: setting.texture,
            softEdge: setting.softEdge,
            onBrightnessCorrection: (v) =>
                update(setting.copyWith(brightnessCorrection: v)),
            onStretch: (v) => update(setting.copyWith(stretch: v)),
            onWater: (v) => update(setting.copyWith(water: v)),
            onPigment: (v) => update(setting.copyWith(pigment: v)),
            onBleed: (v) => update(setting.copyWith(bleed: v)),
            onTexture: (v) => update(setting.copyWith(texture: v)),
            onSoftEdge: (v) => update(setting.copyWith(softEdge: v)),
          ),
        ],
      ],
    );
  }

  Widget _pressureMixingOffTile(AppLocalizations l10n) {
    final setting = _brush.pressureOff.mixing;
    final selectedMode = _selectedMixingMode(setting.enabled, setting.mode);
    void update(PressureMixingOffSetting next) => setState(
      () => _brush = _brush.copyWith(
        pressureOff: _brush.pressureOff.copyWith(mixing: next),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mixingModeHeading(l10n),
        _pressureMixingModeSelector(
          l10n: l10n,
          mode: selectedMode,
          onChanged: (mode) {
            final turningOn =
                selectedMode == BrushMixingMode.off &&
                mode != BrushMixingMode.off;
            update(
              setting.copyWith(
                enabled: mode != BrushMixingMode.off,
                mode: mode,
                rate: turningOn && setting.rate == 0 ? 50 : setting.rate,
              ),
            );
          },
        ),
        if (selectedMode != BrushMixingMode.off) ...[
          _mixingModeHint(l10n, selectedMode),
          _sliderRow(
            l10n.brushSettingsMixingAmount,
            setting.rate.toDouble(),
            0,
            100,
            (v) => update(setting.copyWith(rate: v.round())),
          ),
          ..._mixingStyleSliders(
            l10n,
            selectedMode,
            brightnessCorrection: setting.brightnessCorrection,
            stretch: setting.stretch,
            water: setting.water,
            pigment: setting.pigment,
            bleed: setting.bleed,
            texture: setting.texture,
            softEdge: setting.softEdge,
            onBrightnessCorrection: (v) =>
                update(setting.copyWith(brightnessCorrection: v)),
            onStretch: (v) => update(setting.copyWith(stretch: v)),
            onWater: (v) => update(setting.copyWith(water: v)),
            onPigment: (v) => update(setting.copyWith(pigment: v)),
            onBleed: (v) => update(setting.copyWith(bleed: v)),
            onTexture: (v) => update(setting.copyWith(texture: v)),
            onSoftEdge: (v) => update(setting.copyWith(softEdge: v)),
          ),
        ],
      ],
    );
  }

  /// The sliders of the chosen mixing style: 油彩風 has 色延び and the
  /// brightness correction, 水彩風 水分量・絵具量・にじみ・むら・境界のぼかし (the darker rim
  /// of a dried wash is the 水彩境界 filter's).
  List<Widget> _mixingStyleSliders(
    AppLocalizations l10n,
    BrushMixingMode mode, {
    required int brightnessCorrection,
    required int stretch,
    required int water,
    required int pigment,
    required int bleed,
    required int texture,
    required int softEdge,
    required ValueChanged<int> onBrightnessCorrection,
    required ValueChanged<int> onStretch,
    required ValueChanged<int> onWater,
    required ValueChanged<int> onPigment,
    required ValueChanged<int> onBleed,
    required ValueChanged<int> onTexture,
    required ValueChanged<int> onSoftEdge,
  }) => switch (mode) {
    BrushMixingMode.off => const [],
    BrushMixingMode.oil => [
      _sliderRow(
        l10n.brushSettingsMixingStretch,
        stretch.toDouble(),
        0,
        100,
        (v) => onStretch(v.round()),
      ),
      _sliderRow(
        l10n.brushSettingsMixingBrightnessCorrection,
        brightnessCorrection.toDouble(),
        1,
        5,
        (v) => onBrightnessCorrection(v.round()),
      ),
    ],
    BrushMixingMode.watercolor => [
      _sliderRow(
        l10n.brushSettingsMixingWater,
        water.toDouble(),
        0,
        100,
        (v) => onWater(v.round()),
      ),
      _sliderRow(
        l10n.brushSettingsMixingPigment,
        pigment.toDouble(),
        0,
        100,
        (v) => onPigment(v.round()),
      ),
      _sliderRow(
        l10n.brushSettingsMixingBleed,
        bleed.toDouble(),
        0,
        100,
        (v) => onBleed(v.round()),
      ),
      _sliderRow(
        l10n.brushSettingsMixingTexture,
        texture.toDouble(),
        0,
        100,
        (v) => onTexture(v.round()),
      ),
      _sliderRow(
        l10n.brushSettingsMixingSoftEdge,
        softEdge.toDouble(),
        0,
        100,
        (v) => onSoftEdge(v.round()),
      ),
    ],
  };

  Widget _mixingModeHint(AppLocalizations l10n, BrushMixingMode mode) {
    final text = switch (mode) {
      BrushMixingMode.off => null,
      BrushMixingMode.oil => l10n.brushSettingsMixingOilHint,
      BrushMixingMode.watercolor => l10n.brushSettingsMixingWatercolorHint,
    };
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _mixingSubheading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );

  Widget _mixingModeHeading(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      l10n.brushSettingsMixingTitle,
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );

  BrushMixingMode _selectedMixingMode(
    bool enabled,
    BrushMixingMode storedMode,
  ) => enabled ? storedMode : BrushMixingMode.off;

  Widget _pressureMixingModeSelector({
    required AppLocalizations l10n,
    required BrushMixingMode mode,
    required ValueChanged<BrushMixingMode> onChanged,
  }) {
    const modes = BrushMixingMode.values;
    return RadioGroup<BrushMixingMode>(
      groupValue: mode,
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
    return LabeledSlider(
      label: label,
      min: min,
      max: max,
      value: value,
      valueText: value.round().toString(),
      onChanged: onChanged,
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
    return LabeledSlider(
      label: label,
      min: min,
      max: max,
      value: value,
      step: step,
      isInt: false,
      valueText: value.toStringAsFixed(step < 0.1 ? 2 : 1),
      onChanged: onChanged,
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
        BrushMixingMode.oil => l10n.brushSettingsMixingOil,
        BrushMixingMode.watercolor => l10n.brushSettingsMixingWatercolor,
      };
}
