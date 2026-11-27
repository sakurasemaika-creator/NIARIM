import 'dart:io';

import 'package:niarim/services/theme_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/signal_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/creative_preset_labels.dart';
import '../../../models/brush.dart';
import '../../../services/brush_service.dart';
import '../../../services/export_share_service.dart';
import '../../../services/shared_asset_card_service.dart';
import '../../../services/settings_service.dart';
import '../../../widgets/list_reveal.dart';
import '../../../widgets/labeled_slider.dart';
import '../../../widgets/menu_action_label.dart';
import '../../../widgets/keep_together_text.dart';
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
import 'asset_panel_actions.dart';
import 'asset_search_bar.dart';
import 'asset_tag_dialog.dart';
import '../../../widgets/asset_tag_label.dart';
import '../../../widgets/action_beside_or_below.dart';
import '../../../widgets/grouped_sheet.dart';
import '../../../widgets/list_ink_clip.dart';
import '../../../widgets/stroke_sample_preview.dart';
import '../../../widgets/typing_dialog_inset.dart';
import '../../../utils/file_failure_reason.dart';

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
  // 複製・作った素材を見える所まで送るための一覧のスクロール。
  final _listScroll = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brushService = context.watch<BrushService>();
    final allBrushes = brushService.brushes;
    final folders = brushService.folders;
    final folderIds = {for (final folder in folders) folder.id};
    final folderFilter =
        _folderFilter == '' || folderIds.contains(_folderFilter)
        ? _folderFilter
        : null;
    var brushes = _showFavoritesOnly
        ? allBrushes.where((b) => b.isFavorite)
        : allBrushes.where((_) => true);
    if (folderFilter == '') {
      brushes = brushes.where((b) => !folderIds.contains(b.folderId));
    } else if (folderFilter != null) {
      brushes = brushes.where((b) => b.folderId == folderFilter);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      brushes = brushes.where(
        (b) => assetMatchesSearch(
          name: creativePresetLabel(
            l10n,
            b.name,
            builtIn: brushService.isBuiltIn(b.id),
          ),
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
        _showFavoritesOnly || query.isNotEmpty || folderFilter != null;
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
            // 一覧の名前・お気に入りのみ・検索と、フォルダ・新規・読込。名前の
            // 無い一覧（ペンのタブ・ドック）では1行にまとめる。入らない幅では
            // 文字を縮めず、アイコンだけにする（名前は吹き出しと読み上げ）。
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
              actions: AssetPanelActions.list(
                l10n,
                onFolder: () => _openFolderManagement(context, brushService),
                onCreate: () => _createFromImage(context, brushService),
                onImport: () => SharedAssetCardService.pickAndImport(
                  context,
                  brushService: brushService,
                ),
              ),
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
                        folderFilter == null,
                        () => setState(() => _folderFilter = null),
                      ),
                      _folderChip(
                        context,
                        l10n.folderNone,
                        folderFilter == '',
                        () => setState(() => _folderFilter = ''),
                      ),
                      ...folders.map(
                        (f) => _folderChip(
                          context,
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
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isFiltering && allBrushes.isNotEmpty
                                  ? l10n.helpNoResults
                                  : l10n.brushEmpty,
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
                      scrollController: _listScroll,
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
                          name: creativePresetLabel(
                            l10n,
                            brush.name,
                            builtIn: brushService.isBuiltIn(brush.id),
                          ),
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
                              Tooltip(
                                message: brush.isFavorite
                                    ? l10n.colorPickerFavoriteRemove
                                    : l10n.colorPickerFavoriteAdd,
                                child: GestureDetector(
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
          style: localizedHeadingStyle(context, const TextStyle(fontSize: 11)),
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
        final copyId = service.duplicateBrush(
          brush.id,
          name: numberedCopyName(l10n, brush.name, {
            for (final b in service.brushes) b.name,
          }),
        );
        // 足したブラシを選び、一覧の最後（足した所）を見せる（以前は末尾に
        // 黙って入り、探さないと見つからなかった）。
        if (copyId != null) {
          service.selectBrush(copyId);
          revealListEnd(_listScroll);
        }
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
          assetName: creativePresetLabel(
            l10n,
            brush.name,
            builtIn: service.isBuiltIn(brush.id),
          ),
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
        title: Text(
          l10n.brushPanelDeleteConfirmTitle(
            creativePresetLabel(
              l10n,
              brush.name,
              builtIn: service.isBuiltIn(brush.id),
            ),
          ),
        ),
        content: messageText(l10n.brushPanelDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          // 取り消せない操作なので、ほかの削除の確かめと同じ警告色の塗りの
          // ボタン。
          FilledButton(
            key: const Key('brushDeleteConfirm'),
            style: warningFilledButtonStyle(ctx),
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
    final created = await service.createBrushFromImage(
      result.files.first.path!,
      name: name,
    );
    service.selectBrush(created.id);
    revealListEnd(_listScroll);
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
        SnackBar(
          content: Text(
            l10n.brushExportFailedSnackbar(fileFailureReason(l10n, e)),
          ),
        ),
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
        insetPadding: typingDialogInsetPadding(
          dialogContext,
          usual: const EdgeInsets.all(16),
        ),
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

  /// 自作のブラシの名前（組み込みのブラシの名前は変えない）。
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _brush = widget.brush;
    _nameController = TextEditingController(text: widget.brush.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 今の設定で描いた線の見本の色（キャンバスで選んでいる色）。
  Color get _sampleColor => context.read<BrushService>().currentColor;

  Future<void> _save() async {
    final service = context.read<BrushService>();
    // 名前は前後の空白を除き、空なら元の名前のまま。
    final typed = _nameController.text.trim();
    final named = service.isBuiltIn(_brush.id) || typed.isEmpty
        ? _brush.copyWith(name: widget.brush.name)
        : _brush.copyWith(name: typed);
    final brush = await service.prepareBrushTip(named);
    if (!mounted) return;
    service.updateBrush(brush);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final penPressureEnabled = context
        .read<SettingsService>()
        .penPressureEnabled;
    final theme = Theme.of(context);
    final rule =
        theme.dividerTheme.color ??
        theme.colorScheme.outlineVariant.withValues(alpha: .6);
    // 筆圧ON・OFFの設定は、いま使っている方を先に開いて出し、もう片方は
    // たたんで後ろに置く。
    final pressureOn = _settingsSection(
      key: const Key('brush-settings-pressure-on'),
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
    );
    final pressureOff = _settingsSection(
      key: const Key('brush-settings-pressure-off'),
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
    );
    final sections = <Widget>[
      _settingsSection(
        key: const Key('brush-settings-stroke'),
        title: l10n.brushSettingsStrokeSection,
        initiallyExpanded: true,
        children: [
          // フェード（色が端で透ける）は縁取りペンには無い：縁取りペンの端は
          // 入り抜きで形だけが細くなる。
          if (!_brush.outlineEnabled)
            ..._endsControls(
              l10n,
              keyPrefix: 'brush-fade',
              title: l10n.brushSettingsFadeModeTitle,
              mode: _brush.fadeMode,
              start: _brush.fadeIn,
              end: _brush.fadeOut,
              startValueLabel: l10n.brushSettingsFadeStartValueLabel,
              startDistanceLabel:
                  '${l10n.brushSettingsFadeDistanceLabel} (${l10n.brushSettingsFadeStartValueLabel})',
              endValueLabel: l10n.brushSettingsFadeEndValueLabel,
              endDistanceLabel:
                  '${l10n.brushSettingsFadeDistanceLabel} (${l10n.brushSettingsFadeEndValueLabel})',
              withMode: (v) => _brush.copyWith(fadeMode: v),
              withStart: (v) => _brush.copyWith(fadeIn: v),
              withEnd: (v) => _brush.copyWith(fadeOut: v),
            ),
          ..._endsControls(
            l10n,
            keyPrefix: 'brush-taper',
            title: l10n.brushSettingsTaperModeTitle,
            mode: _brush.taperMode,
            start: _brush.taperIn,
            end: _brush.taperOut,
            startValueLabel: l10n.brushSettingsTaperStartValueLabel,
            startDistanceLabel: l10n.brushSettingsTaperStartDistanceLabel,
            endValueLabel: l10n.brushSettingsTaperEndValueLabel,
            endDistanceLabel: l10n.brushSettingsTaperEndDistanceLabel,
            withMode: (v) => _brush.copyWith(taperMode: v),
            withStart: (v) => _brush.copyWith(taperIn: v),
            withEnd: (v) => _brush.copyWith(taperOut: v),
          ),
          _sliderRow(
            l10n.brushSettingsSpacingLabel,
            _brush.spacing.toDouble(),
            1,
            kBrushSpacingMax.toDouble(),
            (v) => setState(() => _brush = _brush.copyWith(spacing: v.round())),
          ),
          LabeledSlider(
            label: l10n.brushSettingsPaperGrain,
            value: _brush.grainStrength.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            padding: _sliderPadding,
            valueText: '${_brush.grainStrength}%',
            onChanged: (value) => setState(
              () => _brush = _brush.copyWith(grainStrength: value.round()),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.brushSettingsStrokeDecayTitle),
            subtitle: Text(
              l10n.brushSettingsStrokeDecaySubtitle,
              style: const TextStyle(fontSize: 12),
            ),
            value: _brush.strokeDecay,
            onChanged: (v) =>
                setState(() => _brush = _brush.copyWith(strokeDecay: v)),
          ),
          SwitchListTile(
            title: Text(l10n.brushSettingsPixelModeTitle),
            value: _brush.pixelMode,
            onChanged: (v) =>
                setState(() => _brush = _brush.copyWith(pixelMode: v)),
          ),
          if (_brush.pixelMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        ],
      ),
      penPressureEnabled ? pressureOn : pressureOff,
      // 縁取り・折り畳み・横方向反復（髪・リボンのブラシの決め手）。
      _settingsSection(
        key: const Key('brush-settings-effects'),
        title: l10n.brushSettingsEffectsSection,
        initiallyExpanded: true,
        children: [
          BrushExtensionSettings(
            brush: _brush,
            labels: BrushExtensionLabels.fromLocalizations(l10n),
            onChanged: (value) =>
                setState(() => _brush = _withOutlineEnds(_brush, value)),
            onPickOutlineColor: _showOutlineColorPicker,
            onEyedropOutlineColor: widget.onEyedropOutlineColor == null
                ? null
                : _eyedropOutlineColor,
          ),
        ],
      ),
      penPressureEnabled ? pressureOff : pressureOn,
      _settingsSection(
        key: const Key('brush-settings-tip'),
        title: l10n.brushTipSettingsTitle,
        initiallyExpanded: false,
        children: [
          BrushTipSettings(
            brush: _brush,
            onChanged: (value) => setState(() => _brush = value),
            onAddImages: _addImages,
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    ];
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 題と保存はスクロールの外に置き、いつも押せるようにする（以前は
          // 一番下まで送らないと保存できなかった）。その下に、今の設定で
          // 描いた線の見本を出す（値を動かすとその場で描き直す）。
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
            // 狭い幅・大きな文字で名前が字ごとに折れるときは、保存を名前の
            // 下（行の終わりの側）へ回す。
            child: ActionBesideOrBelow(
              text: Text(
                // 組み込みのブラシは一覧と同じく今の言語の名前。
                context.read<BrushService>().isBuiltIn(_brush.id)
                    ? creativePresetLabel(l10n, _brush.name, builtIn: true)
                    : (_nameController.text.trim().isEmpty
                          ? _brush.name
                          : _nameController.text.trim()),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: localizedHeadingStyle(
                  context,
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              action: FilledButton(
                key: const Key('brush-settings-save'),
                onPressed: _save,
                child: Text(l10n.commonSave),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: StrokeSamplePreview(
              key: const Key('brush-settings-sample'),
              brush: _brush,
              color: _sampleColor,
              height: 64,
            ),
          ),
          Divider(height: 1, thickness: 1, color: rule),
          Expanded(
            child: ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                // 自作のブラシは名前を変えられる（トーン・スタンプの「編集」と
                // 同じ欄）。組み込みのブラシは名前を変えない。
                if (!context.read<BrushService>().isBuiltIn(_brush.id)) ...[
                  TextField(
                    key: const Key('brush-settings-name'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.creativeAssetNameLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  sections[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// スライダーの行の余白：項目名の始まりを行の文字（16px）にそろえる。
  static const _sliderPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 4,
  );

  /// 1つのまとまり：メニューの背景色の面1枚を細い線で縁取り、見出しを押すと
  /// たたむ（影は付けない）。中の行は左右16pxから書き始める。
  Widget _settingsSection({
    required Key key,
    required String title,
    required bool initiallyExpanded,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule =
        theme.dividerTheme.color ?? scheme.outlineVariant.withValues(alpha: .6);
    return Material(
      key: key,
      color: theme.cardTheme.color ?? scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GroupedSheet.radius),
        side: BorderSide(color: rule),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: localizedHeadingStyle(
            context,
            const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        initiallyExpanded: initiallyExpanded,
        // 開いている印も差し色にしない（差し色は選んでいる物のため）。
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, thickness: 1, color: rule),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  /// まとまりの中の小さな見出し（選ぶ物の名前）。
  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.35,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  /// いくつかから1つを選ぶ（入り抜き・混色）：ラジオの行を縦に並べず、
  /// 選べる物を折り返すチップにする。選んだチップだけが選択の色。
  Widget _choices<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
    Key Function(T)? keyOf,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            key: keyOf?.call(value),
            label: Text(label(value)),
            selected: value == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(value),
          ),
      ],
    ),
  );

  Widget _pressureRangeTile({
    required String label,
    required PressureRangeSetting setting,
    required ValueChanged<PressureRangeSetting> onChanged,
    required AppLocalizations l10n,
  }) {
    return Column(
      children: [
        SwitchListTile(
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

  Widget _mixingSubheading(String text) => _fieldLabel(text);

  Widget _mixingModeHeading(AppLocalizations l10n) =>
      _fieldLabel(l10n.brushSettingsMixingTitle);

  BrushMixingMode _selectedMixingMode(
    bool enabled,
    BrushMixingMode storedMode,
  ) => enabled ? storedMode : BrushMixingMode.off;

  Widget _pressureMixingModeSelector({
    required AppLocalizations l10n,
    required BrushMixingMode mode,
    required ValueChanged<BrushMixingMode> onChanged,
  }) => _choices<BrushMixingMode>(
    values: BrushMixingMode.values,
    selected: mode,
    label: (value) => _mixingModeLabel(l10n, value),
    keyOf: (value) => Key('brush-mixing-${value.name}'),
    onSelected: onChanged,
  );

  /// The choices and, for カスタム, the sliders of a brush's ends (フェード or
  /// 入り抜き): a value (%) and a distance (px) for the start and the end.
  List<Widget> _endsControls(
    AppLocalizations l10n, {
    required String keyPrefix,
    required String title,
    required FadeMode mode,
    required FadeEndpointSettings start,
    required FadeEndpointSettings end,
    required String startValueLabel,
    required String startDistanceLabel,
    required String endValueLabel,
    required String endDistanceLabel,
    required Brush Function(FadeMode) withMode,
    required Brush Function(FadeEndpointSettings) withStart,
    required Brush Function(FadeEndpointSettings) withEnd,
  }) => [
    _fieldLabel(title),
    _choices<FadeMode>(
      values: FadeMode.values,
      selected: mode,
      label: (mode) => _fadeModeLabel(l10n, mode),
      keyOf: (mode) => Key('$keyPrefix-${mode.name}'),
      onSelected: (v) => setState(() => _brush = withMode(v)),
    ),
    if (mode == FadeMode.custom) ...[
      _sliderRow(
        startValueLabel,
        start.value,
        0,
        100,
        (v) => setState(() => _brush = withStart(start.copyWith(value: v))),
      ),
      _sliderRow(
        startDistanceLabel,
        start.rangePx,
        10,
        2000,
        (v) => setState(() => _brush = withStart(start.copyWith(rangePx: v))),
      ),
      _sliderRow(
        endValueLabel,
        end.value,
        0,
        100,
        (v) => setState(() => _brush = withEnd(end.copyWith(value: v))),
      ),
      _sliderRow(
        endDistanceLabel,
        end.rangePx,
        10,
        2000,
        (v) => setState(() => _brush = withEnd(end.copyWith(rangePx: v))),
      ),
    ],
  ];

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
      padding: _sliderPadding,
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
      padding: _sliderPadding,
      valueText: value.toStringAsFixed(step < 0.1 ? 2 : 1),
      onChanged: onChanged,
    );
  }

  /// [next] after the outline settings changed from [previous]. An outline
  /// pen's ends change only its shape: turning the outline on moves a fade
  /// without 入り抜き to 入り抜き (as the pen would draw it anyway), so the
  /// sheet shows what draws.
  static Brush _withOutlineEnds(Brush previous, Brush next) {
    if (previous.outlineEnabled ||
        !next.outlineEnabled ||
        next.taperMode != FadeMode.off ||
        next.fadeMode == FadeMode.off) {
      return next;
    }
    return next.copyWith(
      fadeMode: FadeMode.off,
      fadeIn: FadeEndpointSettings.full,
      fadeOut: FadeEndpointSettings.full,
      taperMode: next.fadeMode,
      taperIn: next.fadeIn,
      taperOut: next.fadeOut,
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
