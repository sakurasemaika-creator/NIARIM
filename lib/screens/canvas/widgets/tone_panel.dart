import 'dart:io';

import 'package:niarim/services/theme_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/creative_preset_labels.dart';
import '../../../models/tone.dart';
import '../../../services/export_share_service.dart';
import '../../../services/shared_asset_card_service.dart';
import '../../../services/brush_service.dart';
import '../../../services/tone_service.dart';
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

/// トーンの全機能管理パネル（一覧・お気に入り・検索・
/// 自作トーン・読み込み・書き出し・フォルダ管理）。ブラシパネルと同構成。
class TonePanel extends StatefulWidget {
  final VoidCallback onClose;
  final bool embedded;
  final double? embeddedHeight;
  final VoidCallback? onPresetSelected;
  const TonePanel({
    super.key,
    required this.onClose,
    this.embedded = false,
    this.embeddedHeight,
    this.onPresetSelected,
  });

  @override
  State<TonePanel> createState() => _TonePanelState();
}

class _TonePanelState extends State<TonePanel> {
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
    final toneService = context.watch<ToneService>();
    final allTones = toneService.tones;
    final folders = toneService.folders;
    final folderIds = {for (final folder in folders) folder.id};
    final folderFilter =
        _folderFilter == '' || folderIds.contains(_folderFilter)
        ? _folderFilter
        : null;
    var tones = _showFavoritesOnly
        ? allTones.where((t) => t.isFavorite)
        : allTones.where((_) => true);
    if (folderFilter == '') {
      tones = tones.where((t) => !folderIds.contains(t.folderId));
    } else if (folderFilter != null) {
      tones = tones.where((t) => t.folderId == folderFilter);
    }
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      tones = tones.where(
        (t) => assetMatchesSearch(
          name: creativePresetLabel(
            l10n,
            t.name,
            builtIn: toneService.isBuiltIn(t.id),
          ),
          // 既定タグは言語非依存のキーで保存されているため、その言語での
          // 表示文言へ直してから突き合わせる（英語UIで「pixel」と打って
          // ドット絵向けの素材が出る、という当たり前の挙動にするため）。
          tags: localizeAssetTags(l10n, t.tags),
          mode: _searchMode,
          query: query,
        ),
      );
    }
    final toneList = tones.toList();
    final current = toneService.currentTone;
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
            // 入らない幅ではアイコンだけ（名前は吹き出しと読み上げ）。
            AssetPanelActions(
              onFolder: () => _openFolderManagement(context, toneService),
              onCreate: () => _createFromImage(context, toneService),
              onImport: () => SharedAssetCardService.pickAndImport(
                context,
                toneService: toneService,
              ),
            ),
            // 一覧の名前・お気に入りのみ・検索。入らない幅では文字を縮めず、
            // お気に入りを星だけにする（名前は吹き出しと読み上げ）。
            AssetListHeaderRow(
              title: !widget.embedded ? l10n.toneTitle : null,
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
                availableTags: localizeAssetTags(l10n, toneService.allTags()),
                keywordHint: l10n.toneSearchHint,
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
              child: toneList.isEmpty
                  // 絞り込み（お気に入り・検索・フォルダ）で全部隠れたときは
                  // 「トーンがありません」と言わない（ブラシの一覧と同じ）。
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isFiltering && allTones.isNotEmpty
                                  ? l10n.helpNoResults
                                  : l10n.toneEmpty,
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
                      itemCount: toneList.length,
                      onReorderItem: (oldIndex, newIndex) {
                        if (!isFiltering) {
                          toneService.reorderTone(
                            oldIndex,
                            preRemovalIndex(oldIndex, newIndex),
                          );
                        }
                      },
                      itemBuilder: (context, index) {
                        final tone = toneList[index];
                        final isSelected = current?.id == tone.id;
                        // プリインストールのトーンは編集・削除できない
                        // （複製したものは複製元とは別IDになるため編集・削除可能）。
                        final builtIn = toneService.isBuiltIn(tone.id);
                        return PresetStrokeRow(
                          key: ValueKey(tone.id),
                          name: creativePresetLabel(
                            l10n,
                            tone.name,
                            builtIn: toneService.isBuiltIn(tone.id),
                          ),
                          color: context.watch<BrushService>().currentColor,
                          tone: tone,
                          selected: isSelected,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: tone.isFavorite
                                    ? l10n.colorPickerFavoriteRemove
                                    : l10n.colorPickerFavoriteAdd,
                                child: GestureDetector(
                                  onTap: () =>
                                      toneService.toggleFavorite(tone.id),
                                  child: Icon(
                                    tone.isFavorite
                                        ? Icons.star
                                        : Icons.star_outline,
                                    size: 14,
                                    color: tone.isFavorite
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
                                    _handleAction(context, action, tone),
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
                                    // トーンをもう一度は書き出さない。
                                    enabled: !ExportShareService.isRunning(
                                      _exportKey(tone),
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
                            toneService.selectTone(tone.id);
                            widget.onPresetSelected?.call();
                          },
                          onLongPress: builtIn
                              ? null
                              : () => _showToneSettings(context, tone),
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

  void _handleAction(BuildContext context, String action, Tone tone) {
    final service = context.read<ToneService>();
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case 'edit':
        _showToneSettings(context, tone);
      case 'duplicate':
        // 言語に合わせた「名前 (コピー)」、同じ名前があれば番号を付ける
        // （複製の複製も元の名前に番号。ブラシの一覧と同じ）。
        service.duplicateTone(
          tone.id,
          name: numberedCopyName(l10n, tone.name, {
            for (final t in service.tones) t.name,
          }),
        );
      case 'move':
        showMoveToCreativeFolderSheet(
          context,
          folders: service.folders
              .map((f) => (id: f.id, name: f.name))
              .toList(),
          onSelect: (folderId) => service.moveToFolder(tone.id, folderId),
        );
      case 'tags':
        showAssetTagDialog(
          context,
          assetName: creativePresetLabel(
            l10n,
            tone.name,
            builtIn: service.isBuiltIn(tone.id),
          ),
          currentTags: localizeAssetTags(l10n, tone.tags),
          suggestions: localizeAssetTags(l10n, service.allTags()),
          // ダイアログは表示文言で編集させるので、保存時にキーへ戻す。
          // ここを通さないと既定タグがその言語の文字列として焼き付き、
          // 言語を切り替えても元に戻らなくなる。
          onSave: (tags) =>
              service.setTags(tone.id, delocalizeAssetTags(l10n, tags)),
        );
      case 'assetCard':
        _exportTone(context, service, tone);
      case 'delete':
        _deleteTone(context, service, tone);
    }
  }

  /// お気に入り登録中は削除できない。
  void _deleteTone(BuildContext context, ToneService service, Tone tone) {
    if (tone.isFavorite) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    service.deleteTone(tone.id);
  }

  void _showToneSettings(BuildContext context, Tone tone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ToneSettingsSheet(tone: tone),
    );
  }

  void _openFolderManagement(BuildContext context, ToneService service) {
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
    ToneService service,
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
      title: l10n.toneCreateDialogTitle,
    );
    if (name == null) return;
    await service.createToneFromImage(result.files.first.path!, name: name);
  }

  static String _exportKey(Tone tone) => 'tone:${tone.id}';

  /// PNG共有カードの生成と端末への保存・共有を順に処理する。
  Future<void> _exportTone(
    BuildContext context,
    ToneService service,
    Tone tone,
  ) => ExportShareService.runExclusive(_exportKey(tone), () async {
    final l10n = AppLocalizations.of(context)!;
    final File file;
    try {
      file = await SharedAssetCardService.exportTone(service, tone, l10n: l10n);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.toneExportFailedSnackbar(fileFailureReason(l10n, e)),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await SharedAssetCardService.showExportResult(context, file);
  });
}

class _ToneSettingsSheet extends StatefulWidget {
  final Tone tone;
  const _ToneSettingsSheet({required this.tone});

  @override
  State<_ToneSettingsSheet> createState() => _ToneSettingsSheetState();
}

class _ToneSettingsSheetState extends State<_ToneSettingsSheet> {
  late final TextEditingController _nameController;
  late Tone _draft;
  bool _saving = false;
  String? _replacementPath;

  @override
  void initState() {
    super.initState();
    _draft = widget.tone;
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.toneEditTitle,
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.brushSettingsPixelModeTitle),
              value: _draft.pixelMode,
              onChanged: _saving
                  ? null
                  : (value) => setState(
                      () => _draft = _draft.copyWith(pixelMode: value),
                    ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined, size: 16),
              label: Text(l10n.toneChangeTextureButton),
              onPressed: _saving
                  ? null
                  : () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      final path = result?.files.firstOrNull?.path;
                      if (!mounted || path == null) return;
                      setState(() => _replacementPath = path);
                    },
            ),
            if (_replacementPath != null)
              Text(
                _replacementPath!.split(RegExp(r'[/\\]')).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final service = context.read<ToneService>();
                      var draft = _draft.copyWith(
                        name: _nameController.text,
                        patternName: _draft.texturePath == null
                            ? (_draft.patternName ?? _draft.name)
                            : null,
                      );
                      final replacement = _replacementPath;
                      if (replacement != null) {
                        setState(() => _saving = true);
                        try {
                          draft = await service.withReplacementTexture(
                            draft,
                            replacement,
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          setState(() => _saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.toneImportFailedSnackbar(
                                  fileFailureReason(l10n, error),
                                ),
                              ),
                            ),
                          );
                          return;
                        }
                      }
                      if (!context.mounted) return;
                      service.updateTone(draft);
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
