import 'package:niarim/services/theme_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/autofill_gradient.dart';
import '../../models/autofill_preset.dart';
import '../../models/layer.dart' show LayerBlendMode;
import '../../services/autofill_preset_service.dart';
import '../../services/project_service.dart';
import '../../services/tone_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/stepped_slider.dart';
import '../../widgets/help_button.dart';
import '../../widgets/image_eyedropper_dialog.dart';
import '../../widgets/info_icon_tooltip.dart';
import '../../widgets/square_image_crop_dialog.dart';
import '../../widgets/tone_preview_thumb.dart';
import '../canvas/widgets/color_picker_panel.dart';
import '../../config/font_fallback.dart';

class AutofillPresetScreen extends StatefulWidget {
  const AutofillPresetScreen({super.key});

  @override
  State<AutofillPresetScreen> createState() => _AutofillPresetScreenState();
}

class _AutofillPresetScreenState extends State<AutofillPresetScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  // お気に入りのみ絞り込み。プリセット単位のお気に入り登録・絞り込みに使う。
  bool _showFavoritesOnly = false;

  // 複数選択モード（他画面と同じく長押しでON、全選択／全解除ボタンあり）。
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  // 「複製」で作られたコピーをこのセッション内のクリップボードにも
  // 保持しておき、「貼り付け」で選択なしにいつでも再度貼り付けられる
  // ようにする（アプリを離れると保持しない、画面内のみのUI状態）。
  final List<AutofillPreset> _presetClipboard = [];

  // このファイルの各ダイアログが使うTextEditingControllerは、
  // showDialog(...).then((_) => WidgetsBinding.instance.
  // addPostFrameCallback((_) => ctrl.dispose())) という形で破棄する。
  // 単純にshowDialogの直後（.then内）で即座にdispose()すると、ダイアログを
  // 閉じる操作自体が裏で走らせているフォーカス解除処理より先に破棄されて
  // しまうことがあり、直後に別の操作（例：パーツの色をタップして次の
  // ダイアログを開く）をした際に「TextEditingController was used after
  // being disposed」のアサーション例外が発生する。1フレーム遅らせることで
  // フォーカス解除処理を先に完了させる。

  // context.watch()をgetter（_presets/_filtered）に入れ、それを
  // ListView.builderの各行のタップ用コールバック（onEdit/onDelete/onTap）
  // 内からも呼ぶと、タップした瞬間（build外）にcontext.watch()が評価されて
  // Providerのアサーション例外が発生し、プリセット詳細画面へ遷移できなく
  // なる。build()内でのみ一度取得し、以降はフィルタ処理を純粋な関数にして
  // コールバックへは確定済みの値（preset自体）だけを渡す。
  List<AutofillPreset> _filter(List<AutofillPreset> presets) {
    var list = _searchQuery.isEmpty
        ? presets
        : presets.where((p) => p.name.contains(_searchQuery)).toList();
    if (_showFavoritesOnly) list = list.where((p) => p.isFavorite).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filter(context.watch<AutofillPresetService>().presets);
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.autofillPresetSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(l10n.autofillPresetScreenTitle),
        actions: [
          const HelpButton(topic: '自動塗り'),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? l10n.commonClose : l10n.commonSearch,
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchQuery = '';
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isSelectionMode)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(
                        () => _selectedIds.addAll(filtered.map((p) => p.id)),
                      ),
                      child: Text(l10n.homeSelectionAllSelect),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedIds.clear();
                        _isSelectionMode = false;
                      }),
                      child: Text(l10n.homeSelectionAllDeselect),
                    ),
                    const Spacer(),
                    Text(l10n.homeSelectionCount(_selectedIds.length)),
                    if (_selectedIds.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.content_copy),
                        onPressed: () => _bulkDuplicate(filtered),
                        tooltip: l10n.commonDuplicate,
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_paste),
                        onPressed: _presetClipboard.isEmpty ? null : _bulkPaste,
                        tooltip: l10n.commonPaste,
                      ),
                      IconButton(
                        icon: Icon(Icons.ios_share),
                        onPressed: () => _bulkExport(filtered),
                        tooltip: l10n.autofillPresetExportMenuItem,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: ThemeService.activeColorScheme.error),
                        onPressed: () => _bulkDelete(filtered),
                        tooltip: l10n.commonDelete,
                      ),
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  FilterChip(
                    label: Text(
                      l10n.homeFavoritesOnly,
                      style: const TextStyle(
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                    selected: _showFavoritesOnly,
                    onSelected: (v) => setState(() => _showFavoritesOnly = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.palette_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _showFavoritesOnly
                                ? l10n.autofillPresetEmptyFavorites
                                : l10n.autofillPresetEmpty,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Kuramubon',
                              fontFamilyFallback: kHeadingFontFallback,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.autofillPresetEmptyHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final preset = filtered[index];
                        return _PresetCard(
                          preset: preset,
                          isSelectionMode: _isSelectionMode,
                          isSelected: _selectedIds.contains(preset.id),
                          onToggleFavorite: () => context
                              .read<AutofillPresetService>()
                              .updatePreset(
                                preset.copyWith(isFavorite: !preset.isFavorite),
                              ),
                          onEdit: () => _showEditDialog(preset),
                          onDelete: () => _confirmDelete(preset),
                          onSetThumbnail: () => _showThumbnailDialog(preset),
                          onExport: () => _exportPresets([preset]),
                          onLongPress: () => setState(() {
                            _isSelectionMode = true;
                            _selectedIds.add(preset.id);
                          }),
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                if (!_selectedIds.remove(preset.id)) {
                                  _selectedIds.add(preset.id);
                                }
                                if (_selectedIds.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              });
                            } else {
                              _showPresetDetail(preset);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOrImportChoice,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// ＋ボタン：以前はタップで即座に新規作成ダイアログへ入っていたが、
  /// 「新規作成」か「読み込み」かを選べるボトムシートを挟む。
  void _showAddOrImportChoice() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.autofillPresetNewDialogTitle),
              onTap: () {
                Navigator.pop(ctx);
                _showAddDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(l10n.autofillFabImportOption),
              onTap: () {
                Navigator.pop(ctx);
                _importPresets();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 選択中のプリセットを複製する（一覧へ即座に追加し、いつでも再度
  /// 貼り付けられるようクリップボードにも保持する）。
  void _bulkDuplicate(List<AutofillPreset> filtered) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<AutofillPresetService>();
    final selected = filtered
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    final copies = selected
        .map(
          (p) => p.copyWith(
            id: 'p_${DateTime.now().microsecondsSinceEpoch}_${p.id}',
            name: l10n.autofillPresetDuplicateName(p.name),
            isFavorite: false,
          ),
        )
        .toList();
    for (final copy in copies) {
      service.addPreset(copy);
    }
    setState(() {
      _presetClipboard
        ..clear()
        ..addAll(copies);
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  /// クリップボードの内容を新しいIDで貼り付ける（何度でも繰り返せる）。
  void _bulkPaste() {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<AutofillPresetService>();
    for (final p in _presetClipboard) {
      service.addPreset(
        p.copyWith(
          id: 'p_${DateTime.now().microsecondsSinceEpoch}_${p.id}',
          name: l10n.autofillPresetDuplicateName(p.name),
        ),
      );
    }
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  /// 選択中のプリセットを一括削除する（お気に入り登録中のものは除外し、
  /// 1件でも除外があった場合はスナックバーで知らせる）。
  Future<void> _bulkDelete(List<AutofillPreset> filtered) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = filtered
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    final deletable = selected.where((p) => !p.isFavorite).toList();
    if (!await confirmDelete(context)) return;
    if (!mounted) return;
    final projectService = context.read<ProjectService>();
    final service = context.read<AutofillPresetService>();
    for (final preset in deletable) {
      for (final part in preset.parts) {
        projectService.markAutofillUpdateForPartId(part.id);
      }
      service.removePreset(preset.id);
    }
    if (deletable.length < selected.length) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
    }
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  /// 選択中のプリセットをまとめて.niafillファイルへ書き出し、1回の共有で
  /// まとめて渡す。
  Future<void> _bulkExport(List<AutofillPreset> filtered) async {
    final selected = filtered
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    await _exportPresets(selected);
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  /// [presets]をそれぞれ独立した.niafillファイルへ書き出し、1回の共有操作で
  /// まとめて渡す（プリセット単体の書き出しもこれを1件呼び出すだけで済む）。
  Future<void> _exportPresets(List<AutofillPreset> presets) async {
    if (presets.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];
      for (final preset in presets) {
        final safeName = preset.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final file = File('${dir.path}/$safeName.niafill');
        await file.writeAsString(jsonEncode(preset.toJson()));
        files.add(XFile(file.path));
      }
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: files));
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.autofillPresetExportFailedSnackbar(e.toString())),
        ),
      );
    }
  }

  /// .niafillファイルを複数選択して一括で読み込む。
  Future<void> _importPresets() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['niafill'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    final service = context.read<AutofillPresetService>();
    var imported = 0;
    String? lastError;
    for (final picked in result.files) {
      try {
        final content = picked.bytes != null
            ? utf8.decode(picked.bytes!)
            : await File(picked.path!).readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final preset = AutofillPreset.fromJson(json).copyWith(
          id: 'p_${DateTime.now().microsecondsSinceEpoch}_$imported',
          isFavorite: false,
        );
        await service.addPreset(preset);
        imported++;
      } catch (e) {
        lastError = e.toString();
      }
    }
    if (!mounted) return;
    if (imported > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.autofillPresetImportSuccessSnackbar(imported)),
        ),
      );
    }
    if (lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.autofillPresetImportFailedSnackbar(lastError)),
        ),
      );
    }
  }

  void _showAddDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillPresetNewDialogTitle),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.autofillPresetNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<AutofillPresetService>().addPreset(
                  AutofillPreset(
                    id: 'p_${DateTime.now().microsecondsSinceEpoch}',
                    name: nameCtrl.text,
                    parts: [],
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    ).then(
      (_) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => nameCtrl.dispose(),
      ),
    );
  }

  void _showEditDialog(AutofillPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillPresetRenameDialogTitle),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<AutofillPresetService>().updatePreset(
                  preset.copyWith(name: nameCtrl.text),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then(
      (_) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => nameCtrl.dispose(),
      ),
    );
  }

  void _confirmDelete(AutofillPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    // お気に入り登録中は削除できない。
    if (preset.isFavorite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillPresetDeleteConfirmTitle(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeService.activeColorScheme.error),
            onPressed: () {
              // 削除されるパーツを使用中の線画レイヤーへ更新マークを伝播（対応プリセット消失前に通知）
              final ps = context.read<ProjectService>();
              for (final part in preset.parts) {
                ps.markAutofillUpdateForPartId(part.id);
              }
              context.read<AutofillPresetService>().removePreset(preset.id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  /// サムネイル画像設定ポップアップ（三点メニューの「名前変更」と「削除」
  /// の間に追加。「画像読み込み」でトリミングして設定、
  /// 「サムネイル画像削除」で確認の上、既定の色表示へ戻す）。
  void _showThumbnailDialog(AutofillPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    final path = preset.thumbnailPath;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillThumbnailMenuItem),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 現在設定されているサムネイルをそのまま表示し、変更・削除の判断を
            // つけやすくする（未設定の場合はパレットアイコンを表示）。
            Container(
              width: 88,
              height: 88,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: path != null
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      // サムネイルは512x512で保存されている。88px表示の
                      // ために原寸でデコードして画像キャッシュへ載せない。
                      cacheWidth: (88 * MediaQuery.devicePixelRatioOf(ctx))
                          .round(),
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image, size: 32),
                    )
                  : const Icon(Icons.palette, size: 32),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.autofillThumbnailLoadButton),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndCropThumbnail(preset);
              },
            ),
            if (path != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: ThemeService.activeColorScheme.error),
                title: Text(
                  l10n.autofillThumbnailDeleteButton,
                  style: TextStyle(color: ThemeService.activeColorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemoveThumbnail(preset);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndCropThumbnail(AutofillPreset preset) async {
    final l10n = AppLocalizations.of(context)!;
    // withData: trueでバイト列も取得しておく。Web版はdart:ioのFileが
    // 使えずpathも常にnullになるため、その場合はバイト列を直接ダイアログへ渡す。
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null && picked.bytes == null) return;
    if (!mounted) return;
    // 画像選択後、1:1の正方形へトリミング（位置・大きさ・角度はユーザーが
    // ドラッグ・ピンチ・回転ジェスチャーで調整できる）。
    final cropped = await showDialog<Uint8List>(
      context: context,
      builder: (_) => picked.path != null
          ? SquareImageCropDialog(imagePath: picked.path!)
          : SquareImageCropDialog(imageBytes: picked.bytes!),
    );
    if (cropped == null || !mounted) return;
    final service = context.read<AutofillPresetService>();
    await service.setPresetThumbnailBytes(preset.id, cropped);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.autofillThumbnailSetSnackbar)));
  }

  void _confirmRemoveThumbnail(AutofillPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillThumbnailDeleteConfirmTitle),
        content: Text(l10n.autofillThumbnailDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeService.activeColorScheme.error),
            onPressed: () {
              context.read<AutofillPresetService>().clearPresetThumbnail(
                preset.id,
              );
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  void _showPresetDetail(AutofillPreset preset) {
    final presetService = context.read<AutofillPresetService>();
    final projectService = context.read<ProjectService>();
    Navigator.push(
      context,
      adMockMaterialPageRoute(
        builder: (_) => _PresetDetailScreen(
          preset: preset,
          onUpdate: (updated, {String? changedPartId}) {
            presetService.updatePreset(updated);
            // パーツ色・名前の変更を、当該パーツIDを参照する全フレームの自動塗りレイヤーへ伝播
            if (changedPartId != null) {
              projectService.markAutofillUpdateForPartId(changedPartId);
            }
          },
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final AutofillPreset preset;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetThumbnail;
  final VoidCallback onExport;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onSetThumbnail,
    required this.onExport,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      child: ListTile(
        onLongPress: onLongPress,
        leading: isSelectionMode
            ? Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              )
            : Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                // サムネイル画像が設定されている場合はそれを優先表示し、未設定の
                // 場合のみパーツの色（最大4色）をグリッド表示する
                // （サムネイル画像削除時は既定の色表示へ戻る）。
                child: preset.thumbnailPath != null
                    ? Image.file(
                        File(preset.thumbnailPath!),
                        fit: BoxFit.cover,
                        // 保存は512x512、ここでの表示は48px。一覧に並ぶぶん
                        // だけ効くので表示画素数へ落としてデコードする。
                        cacheWidth:
                            (48 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image, size: 24),
                      )
                    : preset.parts.isEmpty
                    ? const Icon(Icons.palette, size: 24)
                    : GridView.count(
                        crossAxisCount: 2,
                        padding: const EdgeInsets.all(4),
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        children: preset.parts
                            .take(4)
                            .map(
                              (p) => Container(
                                decoration: BoxDecoration(
                                  color: Color(p.color),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
        title: Text(preset.name),
        subtitle: Text(
          l10n.autofillPresetPartsCount(preset.parts.length),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: isSelectionMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      preset.isFavorite ? Icons.star : Icons.star_border,
                      color: preset.isFavorite ? ThemeService.activeColorScheme.tertiary : null,
                    ),
                    onPressed: onToggleFavorite,
                    tooltip: preset.isFavorite
                        ? l10n.colorPickerFavoriteRemove
                        : l10n.colorPickerFavoriteAdd,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'thumbnail') onSetThumbnail();
                      if (v == 'export') onExport();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(l10n.commonRename),
                      ),
                      PopupMenuItem(
                        value: 'thumbnail',
                        child: Text(l10n.autofillThumbnailMenuItem),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Text(l10n.autofillPresetExportMenuItem),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          l10n.commonDelete,
                          style: TextStyle(color: ThemeService.activeColorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        onTap: onTap,
      ),
    );
  }
}

typedef _PresetUpdateCallback =
    void Function(AutofillPreset updated, {String? changedPartId});

class _PresetDetailScreen extends StatefulWidget {
  final AutofillPreset preset;
  final _PresetUpdateCallback onUpdate;

  const _PresetDetailScreen({required this.preset, required this.onUpdate});

  @override
  State<_PresetDetailScreen> createState() => _PresetDetailScreenState();
}

class _PresetDetailScreenState extends State<_PresetDetailScreen> {
  late AutofillPreset _preset;
  String _partSearchQuery = '';
  bool _isSearchingParts = false;

  // パーツの色選択時に「画像からスポイト」で都度読み込んだ参考画像の
  // スクラッチコピー。この画面を離れる（＝プリセット編集を
  // 終える）タイミングでまとめて削除し容量を節約する。取得した色自体は
  // 各パーツのcolor/lineColorへ既に反映済みのため消えない。
  final Set<String> _scratchImagePaths = {};

  @override
  void initState() {
    super.initState();
    _preset = widget.preset;
  }

  @override
  void dispose() {
    for (final path in _scratchImagePaths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    super.dispose();
  }

  void _save(AutofillPreset updated, {String? changedPartId}) {
    setState(() => _preset = updated);
    widget.onUpdate(updated, changedPartId: changedPartId);
  }

  /// 各パーツ設定の色選択時に画像を都度読み込んでスポイトする。読み込んだ画像はスクラッチ領域へ
  /// コピーし、この画面を離れる際に削除する。
  Future<void> _pickColorFromNewImage(ValueChanged<Color> onPicked) async {
    final l10n = AppLocalizations.of(context)!;
    // withData: trueでバイト列も取得しておく。Web版はdart:ioのFileが
    // 使えずpathも常にnullになるため、その場合はバイト列を直接ダイアログへ渡す。
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null && picked.bytes == null) {
      // ファイルは選ばれたのにpath・bytesとも取得できなかった異常系。
      // 無言で戻ると原因が分からないため、スナックバーで明示する。
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.autofillEyedropperImageLoadFailedSnackbar),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    Color? pickedColor;
    if (picked.path != null) {
      // デスクトップ/モバイル：画面を離れる際に削除するスクラッチ領域へ
      // コピーしてから開く。
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/niarim/autofill_scratch');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final sourcePath = picked.path!;
      final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'png';
      final scratchPath =
          '${dir.path}/scratch_${DateTime.now().microsecondsSinceEpoch}.$ext';
      await File(sourcePath).copy(scratchPath);
      _scratchImagePaths.add(scratchPath);
      if (!mounted) return;
      pickedColor = await showDialog<Color>(
        context: context,
        builder: (_) => ImageEyedropperDialog(imagePath: scratchPath),
      );
    } else {
      // Web版：バイト列を直接渡す（ローカルファイルシステムが存在しないため
      // コピー先を用意できない）。
      pickedColor = await showDialog<Color>(
        context: context,
        builder: (_) => ImageEyedropperDialog(imageBytes: picked.bytes!),
      );
    }
    if (pickedColor != null) onPicked(pickedColor);
  }

  List<AutofillPart> get _filteredParts => _partSearchQuery.isEmpty
      ? _preset.parts
      : _preset.parts.where((p) => p.name.contains(_partSearchQuery)).toList();

  /// 未設定パーツ一覧。保存チェックで、未設定項目が1つでもある場合は
  /// 保存不可とする。
  List<AutofillPart> get _unconfiguredParts =>
      _preset.parts.where((p) => !p.isConfigured).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unconfigured = _unconfiguredParts;
    return PopScope(
      // 未設定パーツがある間はこの画面を離れられない（保存不可）。
      canPop: unconfigured.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showUnconfiguredBlockDialog(unconfigured);
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearchingParts
              ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.autofillPartSearchHint,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _partSearchQuery = v),
                )
              : Text(_preset.name),
          actions: [
            // 検索・並び替え・お気に入り登録に対応
            IconButton(
              icon: Icon(_isSearchingParts ? Icons.close : Icons.search),
              tooltip: _isSearchingParts ? l10n.commonClose : l10n.commonSearch,
              onPressed: () => setState(() {
                _isSearchingParts = !_isSearchingParts;
                if (!_isSearchingParts) _partSearchQuery = '';
              }),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 未設定パーツがある場合の警告バナー（赤文字で不足している
              // パーツ名と設定内容を表示）
              if (unconfigured.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: ThemeService.activeColorScheme.error.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.autofillPartUnconfiguredBanner(
                      unconfigured.length,
                      unconfigured.map((p) => p.name).join('・'),
                    ),
                    style: TextStyle(color: ThemeService.activeColorScheme.error, fontSize: 11),
                  ),
                ),
              Expanded(child: _partListBody()),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddPartDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showUnconfiguredBlockDialog(List<AutofillPart> unconfigured) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillPartUnconfiguredDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.autofillPartUnconfiguredDialogBody),
            SizedBox(height: 8),
            for (final p in unconfigured)
              Text(
                l10n.autofillPartUnconfiguredItem(p.name),
                style: TextStyle(color: ThemeService.activeColorScheme.error, fontSize: 13),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.autofillPartUnconfiguredBackButton),
          ),
        ],
      ),
    );
  }

  Widget _partListBody() {
    final l10n = AppLocalizations.of(context)!;
    return _preset.parts.isEmpty
        ? Center(
            child: Text(
              l10n.autofillPartEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        // 検索中は並び替え無効の通常リスト、非検索時のみドラッグ並び替え可能な
        // ReorderableListViewを使う（フィルタ中はインデックスが元リストとずれるため）
        : _partSearchQuery.isNotEmpty
        ? ListView.builder(
            itemCount: _filteredParts.length,
            itemBuilder: (context, index) => _partTile(_filteredParts[index]),
          )
        : ReorderableListView.builder(
            // ドラッグハンドルを行末に明示アイコンとして置くため、
            // 既定のドラッグハンドル（行全体の長押しで開始・ハンドル
            // アイコンなし）は無効化する。他の並べ替え可能な一覧
            // （ブラシ・トーン・スタンプ・テーマ等）と操作方法を揃える。
            buildDefaultDragHandles: false,
            itemCount: _preset.parts.length,
            // onReorderItemはnewIndexを「削除後の位置」へ調整済みで渡すため、
            // 従来の `newIdx > oldIdx ? newIdx - 1 : newIdx` 補正は不要。
            onReorderItem: (oldIdx, newIdx) {
              final parts = List<AutofillPart>.from(_preset.parts);
              final item = parts.removeAt(oldIdx);
              parts.insert(newIdx, item);
              _save(_preset.copyWith(parts: parts));
            },
            itemBuilder: (context, index) =>
                _partTile(_preset.parts[index], dragIndex: index),
          );
  }

  /// パーツ一覧の1行（[サムネイル] パーツ名 [色チップ] 設定完了チェックアイコン）。
  /// トーンを使用しているパーツは、単色/グラデーションの丸ではなく指定色で
  /// 着色した実際のトーンパターンをサムネイルに表示する。
  Widget _partTile(AutofillPart part, {int? dragIndex}) {
    final l10n = AppLocalizations.of(context)!;
    Widget thumb;
    if (part.useTone && part.toneId != null) {
      final tone = context
          .watch<ToneService>()
          .tones
          .where((t) => t.id == part.toneId)
          .firstOrNull;
      thumb = TonePreviewThumb(tone: tone, color: Color(part.color), size: 32);
    } else {
      thumb = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: part.gradient == null ? Color(part.color) : null,
          gradient: part.gradient == null
              ? null
              : LinearGradient(
                  colors: part.gradient!.colors.map(Color.new).toList(),
                  stops: part.gradient!.stops,
                ),
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      );
    }
    return ListTile(
      key: ValueKey(part.id),
      leading: GestureDetector(
        onTap: () => _showPartDetailDialog(part),
        // 右下の小さな輪＝線画色プレビュー（塗り色だけでなく線画色も
        // プレビューする）。
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            thumb,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _lineColorFor(part),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      title: Text(part.name),
      // 設定完了チェックアイコン（保存チェック用）
      subtitle: part.isConfigured
          ? null
          : Text(
              l10n.autofillPartToneUnselected,
              style: TextStyle(fontSize: 10, color: ThemeService.activeColorScheme.error),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            part.isConfigured ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: part.isConfigured ? ThemeService.activeColorScheme.secondary : ThemeService.activeColorScheme.error,
          ),
          // パーツ単位のお気に入りは不要（プリセット一覧側の
          // お気に入り機能に一本化したため削除）。
          IconButton(
            icon: Icon(Icons.edit, size: 18),
            tooltip: l10n.commonEdit,
            onPressed: () => _showEditPartDialog(part),
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 18, color: ThemeService.activeColorScheme.error),
            tooltip: l10n.commonDelete,
            onPressed: () async {
              if (!await confirmDelete(context, itemName: part.name)) return;
              final parts = List<AutofillPart>.from(_preset.parts)
                ..removeWhere((p) => p.id == part.id);
              _save(_preset.copyWith(parts: parts), changedPartId: part.id);
            },
          ),
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddPartDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillPartAddDialogTitle),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.autofillPartNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final parts = List<AutofillPart>.from(_preset.parts)
                  ..add(
                    AutofillPart(
                      id: 'part_${DateTime.now().microsecondsSinceEpoch}',
                      name: nameCtrl.text,
                      color: 0xFFCCCCCC,
                    ),
                  );
                _save(_preset.copyWith(parts: parts));
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.autofillPartAddButton),
          ),
        ],
      ),
    ).then(
      (_) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => nameCtrl.dispose(),
      ),
    );
  }

  void _showEditPartDialog(AutofillPart part) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: part.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillPartRenameDialogTitle),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final parts = _preset.parts
                    .map(
                      (p) =>
                          p.id == part.id ? p.copyWith(name: nameCtrl.text) : p,
                    )
                    .toList();
                _save(_preset.copyWith(parts: parts), changedPartId: part.id);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then(
      (_) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => nameCtrl.dispose(),
      ),
    );
  }

  Map<AutofillLineColorMode, String> _lineColorModeLabels(
    AppLocalizations l10n,
  ) => {
    AutofillLineColorMode.specified: l10n.autofillLineColorModeSpecified,
    AutofillLineColorMode.sameAsFill: l10n.autofillLineColorModeSameAsFill,
    AutofillLineColorMode.traceAdjust: l10n.autofillLineColorModeTraceAdjust,
  };

  Map<LayerBlendMode, String> _blendModeLabels(AppLocalizations l10n) => {
    LayerBlendMode.normal: l10n.blendModeNormal,
    LayerBlendMode.multiply: l10n.blendModeMultiply,
    LayerBlendMode.screen: l10n.blendModeScreen,
    LayerBlendMode.overlay: l10n.blendModeOverlay,
    LayerBlendMode.addition: l10n.blendModeAddition,
    LayerBlendMode.subtract: l10n.blendModeSubtract,
    LayerBlendMode.darken: l10n.blendModeDarken,
    LayerBlendMode.lighten: l10n.blendModeLighten,
    LayerBlendMode.colorBurn: l10n.blendModeColorBurn,
    LayerBlendMode.colorDodge: l10n.blendModeColorDodge,
    LayerBlendMode.hardLight: l10n.blendModeHardLight,
    LayerBlendMode.softLight: l10n.blendModeSoftLight,
    LayerBlendMode.difference: l10n.blendModeDifference,
    LayerBlendMode.hue: l10n.blendModeHue,
    LayerBlendMode.saturation: l10n.blendModeSaturation,
    LayerBlendMode.color: l10n.blendModeColor,
    LayerBlendMode.luminosity: l10n.blendModeLuminosity,
  };

  /// 詳細設定ポップアップ（色チップタップ時。塗り色・線画色・
  /// グラデーション・トーン・ブレンドモード・不透明度をすべてリアルタイム
  /// プレビュー付きで設定する）。
  void _showPartDetailDialog(AutofillPart part) {
    final l10n = AppLocalizations.of(context)!;
    var current = part;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final tones = context.watch<ToneService>().tones;
          final lineColorModeLabels = _lineColorModeLabels(l10n);
          final blendModeLabels = _blendModeLabels(l10n);
          return AlertDialog(
            title: Text(l10n.autofillPartDetailDialogTitle(part.name)),
            content: SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 塗り色のリアルタイムプレビュー（不透明度を
                    // 変更した際にプレビューでも分かりやすく変化するよう、
                    // チェッカー柄の上に塗り色・グラデーションを不透明度を
                    // 反映して重ねる）。塗り色設定のすぐ上に置くことで、
                    // どちらの設定に対応するプレビューかが一目でわかる。
                    _fillPreview(current, height: 40),
                    const SizedBox(height: 12),
                    Text(
                      l10n.autofillPartFillColorLabel,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => _showColorPickerFor(
                        context,
                        Color(current.color),
                        (c) => setS(
                          () => current = current.copyWith(
                            color: c.toARGB32(),
                            gradient: null,
                          ),
                        ),
                      ),
                      icon: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Color(current.color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      label: Text(
                        l10n.autofillPartSelectColorButton,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 画像を都度読み込んでスポイトで色を拾う（カラー
                    // ピッカーだけでなく、任意の画像から直接色を取得できる）。
                    OutlinedButton.icon(
                      onPressed: () => _pickColorFromNewImage(
                        (c) => setS(
                          () => current = current.copyWith(
                            color: c.toARGB32(),
                            gradient: null,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.colorize, size: 16),
                      label: Text(
                        l10n.autofillEyedropperFromThumbnailButton,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final updated = await _showGradientEditor(current);
                        if (updated != null) setS(() => current = updated);
                      },
                      icon: const Icon(Icons.gradient, size: 16),
                      label: Text(
                        current.gradient == null
                            ? l10n.autofillPartGradientSetButton
                            : l10n.autofillPartGradientEditButton,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    EditableSliderValue(
                      text: l10n.autofillPartFillOpacityLabel(current.opacity),
                      style: const TextStyle(fontSize: 12),
                      value: current.opacity,
                      min: 0,
                      max: 100,
                      title: l10n.autofillPartFillOpacityLabel(current.opacity),
                      onChanged: (v) => setS(
                        () => current = current.copyWith(opacity: v.round()),
                      ),
                    ),
                    SteppedSlider(
                      value: current.opacity.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (v) => setS(
                        () => current = current.copyWith(opacity: v.round()),
                      ),
                    ),
                    const Divider(),
                    // 指定色で縁取り：塗り範囲の一番外側（線画に接する部分）へ、
                    // 指定色・指定太さのラインを重ねる。チェックボックスと
                    // 設定項目の間にプレビューを挟み、どんな色・太さになるか
                    // その場で確認できるようにする。
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.autofillPartOutlineLabel),
                      value: current.outlineEnabled,
                      onChanged: (v) => setS(
                        () => current = current.copyWith(
                          outlineEnabled: v ?? false,
                        ),
                      ),
                    ),
                    if (current.outlineEnabled) ...[
                      const SizedBox(height: 4),
                      _outlinePreview(current),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showColorPickerFor(
                          context,
                          Color(current.outlineColor),
                          (c) => setS(
                            () => current = current.copyWith(
                              outlineColor: c.toARGB32(),
                            ),
                          ),
                        ),
                        icon: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Color(current.outlineColor),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        label: Text(
                          l10n.autofillPartSelectColorButton,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: EditableSliderValue(
                              text: l10n.autofillPartOutlineWidthLabel(
                                current.outlineWidth.round(),
                              ),
                              style: const TextStyle(fontSize: 12),
                              value: current.outlineWidth,
                              min: 1,
                              max: 100,
                              title: l10n.autofillPartOutlineWidthLabel(
                                current.outlineWidth.round(),
                              ),
                              onChanged: (v) => setS(
                                () => current = current.copyWith(
                                  outlineWidth: v.toDouble(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SteppedSlider(
                        value: current.outlineWidth,
                        min: 1,
                        max: 100,
                        onChanged: (v) => setS(
                          () => current = current.copyWith(outlineWidth: v),
                        ),
                      ),
                    ],
                    const Divider(),
                    // 線画色のリアルタイムプレビュー。塗り色プレビューと同じく、
                    // 線画色設定のすぐ上に置く（色トレス・線画馴染ませ選択時は
                    // 塗り色からのオフセット適用後の色をプレビューする）。
                    Container(
                      height: 32,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: const _CheckerboardPainter()),
                          Opacity(
                            opacity: current.lineOpacity / 100,
                            child: ColoredBox(color: _lineColorFor(current)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.autofillPartLineColorLabel,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    // 選択状態と変更通知はRadioGroupがまとめて持つ
                    // （groupValue/onChangedはFlutter 3.32で非推奨）。
                    RadioGroup<AutofillLineColorMode>(
                      groupValue: current.lineColorMode,
                      onChanged: (v) => setS(
                        () => current = current.copyWith(lineColorMode: v),
                      ),
                      child: Column(
                        children: AutofillLineColorMode.values
                            .map(
                              (m) => RadioListTile<AutofillLineColorMode>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  lineColorModeLabels[m]!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                secondary:
                                    m == AutofillLineColorMode.traceAdjust
                                    ? InfoIconTooltip(
                                        message: l10n
                                            .autofillLineColorModeTraceAdjustInfo,
                                      )
                                    : null,
                                value: m,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (current.lineColorMode ==
                        AutofillLineColorMode.specified) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: () => _showColorPickerFor(
                          context,
                          Color(current.lineColor),
                          (c) => setS(
                            () => current = current.copyWith(
                              lineColor: c.toARGB32(),
                            ),
                          ),
                        ),
                        icon: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Color(current.lineColor),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        label: Text(
                          l10n.autofillPartSelectColorButton,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 指定色は「何が既定か」という基準が無く、ユーザーが自由に
                      // 選んだ色を黒へ戻すこと自体に意味がないため、デフォルトに
                      // 戻すボタンは置かない（色トレス・線画馴染ませのみ、既定の
                      // 補正値へ戻す意味のあるボタンとして下に用意している）。
                      OutlinedButton.icon(
                        onPressed: () => _pickColorFromNewImage(
                          (c) => setS(
                            () => current = current.copyWith(
                              lineColor: c.toARGB32(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.colorize, size: 16),
                        label: Text(
                          l10n.autofillEyedropperFromThumbnailButton,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    if (current.lineColorMode ==
                        AutofillLineColorMode.traceAdjust) ...[
                      EditableSliderValue(
                        text: l10n.autofillPartTraceHueLabel(
                          current.traceHue.round(),
                        ),
                        style: const TextStyle(fontSize: 11),
                        value: current.traceHue,
                        min: -180,
                        max: 180,
                        isInt: false,
                        onChanged: (v) => setS(
                          () => current = current.copyWith(
                            traceHue: v.toDouble(),
                          ),
                        ),
                      ),
                      SteppedSlider(
                        value: current.traceHue,
                        min: -180,
                        max: 180,
                        onChanged: (v) =>
                            setS(() => current = current.copyWith(traceHue: v)),
                      ),
                      EditableSliderValue(
                        text: l10n.autofillPartTraceSaturationLabel(
                          current.traceSaturation.round(),
                        ),
                        style: const TextStyle(fontSize: 11),
                        value: current.traceSaturation,
                        min: -100,
                        max: 100,
                        isInt: false,
                        onChanged: (v) => setS(
                          () => current = current.copyWith(
                            traceSaturation: v.toDouble(),
                          ),
                        ),
                      ),
                      SteppedSlider(
                        value: current.traceSaturation,
                        min: -100,
                        max: 100,
                        onChanged: (v) => setS(
                          () => current = current.copyWith(traceSaturation: v),
                        ),
                      ),
                      EditableSliderValue(
                        text: l10n.autofillPartTraceLightnessLabel(
                          current.traceLightness.round(),
                        ),
                        style: const TextStyle(fontSize: 11),
                        value: current.traceLightness,
                        min: -100,
                        max: 100,
                        isInt: false,
                        onChanged: (v) => setS(
                          () => current = current.copyWith(
                            traceLightness: v.toDouble(),
                          ),
                        ),
                      ),
                      SteppedSlider(
                        value: current.traceLightness,
                        min: -100,
                        max: 100,
                        onChanged: (v) => setS(
                          () => current = current.copyWith(traceLightness: v),
                        ),
                      ),
                      // 色トレス・線画馴染ませの3項目をまとめて既定値へ戻す。
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed:
                              (current.traceHue == -10 &&
                                  current.traceSaturation == 60 &&
                                  current.traceLightness == -50)
                              ? null
                              : () => setS(
                                  () => current = current.copyWith(
                                    traceHue: -10,
                                    traceSaturation: 60,
                                    traceLightness: -50,
                                  ),
                                ),
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: Text(
                            l10n.autofillPartResetTraceButton,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    EditableSliderValue(
                      text: l10n.autofillPartLineOpacityLabel(
                        current.lineOpacity,
                      ),
                      style: const TextStyle(fontSize: 12),
                      value: current.lineOpacity,
                      min: 0,
                      max: 100,
                      onChanged: (v) => setS(
                        () =>
                            current = current.copyWith(lineOpacity: v.round()),
                      ),
                    ),
                    SteppedSlider(
                      value: current.lineOpacity.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (v) => setS(
                        () =>
                            current = current.copyWith(lineOpacity: v.round()),
                      ),
                    ),
                    const Divider(),
                    Text(
                      l10n.autofillPartToneLabel,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.autofillPartUseToneCheckbox,
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: current.useTone,
                      onChanged: (v) =>
                          setS(() => current = current.copyWith(useTone: v)),
                    ),
                    // トーンはブラシと同様にユーザーが自作・追加したり配布物を
                    // 読み込んだりできるため、種類が増えるとチップ一覧では
                    // 見づらくなる。チェックON時のみ現在指定中の
                    // トーン名を1行で表示し、タップで各トーンのプレビュー付き
                    // 一覧から選び直せるようにする。
                    if (current.useTone) ...[
                      const SizedBox(height: 4),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: TonePreviewThumb(
                          tone: tones
                              .where((t) => t.id == current.toneId)
                              .firstOrNull,
                          color: Color(current.color),
                          size: 32,
                          shape: BoxShape.rectangle,
                        ),
                        title: Text(
                          tones
                                  .where((t) => t.id == current.toneId)
                                  .firstOrNull
                                  ?.name ??
                              l10n.autofillPartToneUnselected,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () async {
                          final selected = await _showTonePickerSheet(
                            current.toneId,
                            Color(current.color),
                          );
                          if (selected != null) {
                            setS(
                              () =>
                                  current = current.copyWith(toneId: selected),
                            );
                          }
                        },
                      ),
                    ],
                    const Divider(),
                    Text(
                      l10n.autofillPartBlendModeLabel,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    DropdownButtonFormField<LayerBlendMode>(
                      initialValue: current.blendMode,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: LayerBlendMode.values
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                blendModeLabels[m]!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setS(() => current = current.copyWith(blendMode: v)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  final parts = _preset.parts
                      .map((p) => p.id == part.id ? current : p)
                      .toList();
                  _save(_preset.copyWith(parts: parts), changedPartId: part.id);
                  Navigator.pop(ctx);
                },
                child: Text(l10n.autofillPartApplyButton),
              ),
            ],
          );
        },
      ),
    );
  }

  /// トーン選択シート。ブラシと同様にユーザーが自作・追加・
  /// 配布物のDLができるトーンは種類が増えやすいため、名前だけのチップ一覧
  /// ではなく各トーンの実際のパターンプレビュー（指定色で着色）付きの
  /// グリッドから選べるようにする。戻り値は選択されたトーンID（キャンセル時
  /// はnull）。
  Future<String?> _showTonePickerSheet(String? currentToneId, Color color) {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer<ToneService>(
        builder: (ctx, toneService, _) {
          final tones = toneService.tones;
          return SafeArea(
            child: SizedBox(
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      l10n.autofillPartToneLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kuramubon',
                        fontFamilyFallback: kHeadingFontFallback,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: tones.isEmpty
                        ? Center(
                            child: Text(
                              l10n.toneEmpty,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 0.8,
                                ),
                            itemCount: tones.length,
                            itemBuilder: (context, index) {
                              final tone = tones[index];
                              final isSelected = currentToneId == tone.id;
                              return GestureDetector(
                                onTap: () => Navigator.pop(ctx, tone.id),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: TonePreviewThumb(
                                        tone: tone,
                                        color: color,
                                        size: 56,
                                        shape: BoxShape.rectangle,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tone.name,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'Kuramubon',
                                        fontFamilyFallback:
                                            kHeadingFontFallback,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // グラデーション編集ダイアログのプレビュー円の直径。ダイアログの
  // content幅（320）に収まり、かつ左右のハンドルがはみ出さない余白を
  // 残せる大きさにしている。
  static const double _gradientPreviewDiameter = 180;

  /// グラデーション編集ダイアログ（塗り色設定・グラデーション）。
  /// 自由な色比率編集の代わりに均等配置とし、種類・角度（直線時）・
  /// 中心位置（放射時、既定は中央）・色（2〜5色）を編集する簡略実装。
  Future<AutofillPart?> _showGradientEditor(AutofillPart part) {
    final l10n = AppLocalizations.of(context)!;
    var gradient =
        part.gradient ??
        AutofillGradient.defaultTwoColor(part.color, 0xFFFFFFFF);
    // 放射グラデーションで中心（t=0）から始まるドラッグは、重なって表示
    // されている左右2つの分身ハンドルのどちらをつまんだか区別できない
    // （常に見た目上の一番上＝右分身側だけがジェスチャーを受け取る）。
    // そのままだと「つまんだ側の想定方向」にしか反応せず、逆方向へ
    // ドラッグすると反応しないように見えるため、ドラッグ開始時に中心
    // ぴったりだった場合は、実際に動かした最初の方向をそのジェスチャー
    // 中ずっと「外側へ広がる方向」として固定し、左右どちらへ引っ張っても
    // 素直に分割できるようにする（indexごとに保持、setSでは再生成
    // されないようこのメソッドのスコープに置く）。
    final Map<int, int> centerDragSign = {};
    return showDialog<AutofillPart>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void setColorAt(int i, int argb) {
            final colors = List<int>.from(gradient.colors);
            colors[i] = argb;
            setS(() => gradient = gradient.copyWith(colors: colors));
          }

          void setStopAt(int i, double stop) {
            final stops = List<double>.from(gradient.stops);
            final lo = i == 0 ? 0.0 : stops[i - 1] + 0.01;
            final hi = i == stops.length - 1 ? 1.0 : stops[i + 1] - 0.01;
            stops[i] = stop.clamp(lo, hi > lo ? hi : lo);
            setS(() => gradient = gradient.copyWith(stops: stops));
          }

          // 放射グラデーションでは、stops[i]は「中心からの見た目の距離」と
          // 必ずしも一致しない（放射：外側→中央は色順・位置が反転して
          // 描画されるため。_previewGradient/エンジン側のt=1-t反転と対応）。
          // ハンドルは実際に見えている位置（中心からの距離）で操作できるよう、
          // 見た目の距離⇔stopsの相互変換を行う。
          bool isRadial = gradient.type != AutofillGradientType.linear;
          bool isOutCenter =
              gradient.type == AutofillGradientType.radialOutCenter;
          double geomT(int i) =>
              isOutCenter ? 1 - gradient.stops[i] : gradient.stops[i];
          void setGeomT(int i, double t) =>
              setStopAt(i, isOutCenter ? 1 - t : t);

          return AlertDialog(
            title: Text(l10n.autofillPartGradientDialogTitle(part.name)),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 実際の種類・角度・放射方向・ぼかしを反映した正確なプレビュー。
                    // 他の画面のグラデーションプレビュー（長方形）と違い、自動塗りの
                    // 塗り範囲は正方形とは限らない任意の形のため、角度の傾きを
                    // 直感的に確認できるよう真円で表示する。色の切り替え位置を
                    // 示す三角形ハンドルも円の外周へ直接重ねて表示し、直線
                    // グラデーションの角度を変えるとハンドルの並ぶ直径の向きも
                    // 連動して円の周りを回転する。
                    Center(
                      child: SizedBox(
                        width: _gradientPreviewDiameter,
                        height: _gradientPreviewDiameter,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    painter: const _CheckerboardPainter(),
                                  ),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: _previewGradient(
                                        gradient,
                                        _gradientPreviewDiameter,
                                        _gradientPreviewDiameter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final diameter = _gradientPreviewDiameter;
                                final radius = diameter / 2;
                                final center = Offset(radius, radius);
                                // 直線グラデーションはgradient.angleの向きに、
                                // 放射グラデーションは角度の概念がないため
                                // 水平（右）を基準の向きとして固定する。
                                final rad = isRadial
                                    ? 0.0
                                    : gradient.angle * math.pi / 180;
                                final dir = Offset(
                                  math.cos(rad),
                                  math.sin(rad),
                                );

                                Widget handle(
                                  int i,
                                  Offset pos, {
                                  required bool mirrorDrag,
                                }) {
                                  return Positioned(
                                    left: pos.dx - 7,
                                    top: pos.dy - 6,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanStart: (_) {
                                        // 中心ぴったりから始まる場合だけ「未確定」の
                                        // 印として0を入れる（それ以外の通常ドラッグは
                                        // 記録を残さず、常にmirrorDragの向きで動く）。
                                        if (isRadial && geomT(i) <= 0.001) {
                                          centerDragSign[i] = 0;
                                        } else {
                                          centerDragSign.remove(i);
                                        }
                                      },
                                      onPanUpdate: (d) {
                                        // ドラッグ量（画面上のdx・dy）を、ハンドルが
                                        // 実際に動く方向（directionForHandles）へ
                                        // 射影し、その方向にどれだけ動かしたかを
                                        // 求める（円周上のどこにハンドルがあっても、
                                        // 直径の向きに沿ってドラッグした分だけ
                                        // 動くようにするため）。
                                        final proj =
                                            d.delta.dx * dir.dx +
                                            d.delta.dy * dir.dy;
                                        if (isRadial) {
                                          final halfWidth = radius;
                                          final locked = centerDragSign[i];
                                          if (locked == 0 && proj != 0) {
                                            centerDragSign[i] = proj > 0
                                                ? 1
                                                : -1;
                                          }
                                          final sign = centerDragSign[i];
                                          final dt = (sign != null && sign != 0)
                                              ? proj / halfWidth * sign
                                              : proj /
                                                    halfWidth *
                                                    (mirrorDrag ? -1 : 1);
                                          setGeomT(i, geomT(i) + dt);
                                        } else {
                                          setStopAt(
                                            i,
                                            gradient.stops[i] + proj / diameter,
                                          );
                                        }
                                      },
                                      onPanEnd: (_) => centerDragSign.remove(i),
                                      child: CustomPaint(
                                        size: const Size(14, 12),
                                        painter: _StopHandlePainter(
                                          color: Color(gradient.colors[i]),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                if (!isRadial) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      for (
                                        int i = 0;
                                        i < gradient.stops.length;
                                        i++
                                      )
                                        handle(
                                          i,
                                          center +
                                              dir *
                                                  ((gradient.stops[i] - 0.5) *
                                                      diameter),
                                          mirrorDrag: false,
                                        ),
                                    ],
                                  );
                                }
                                // 放射グラデーション：中心を軸に左右対称のハンドルを
                                // 2つずつ配置し、片方を動かすと反対側も連動する。
                                // t=0（中心そのもの）でも常に2つ重ねて表示する
                                // ことで、どちらの方向へドラッグしても意図通り
                                // 分割できるようにする。
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (
                                      int i = 0;
                                      i < gradient.stops.length;
                                      i++
                                    ) ...[
                                      handle(
                                        i,
                                        center + dir * (geomT(i) * radius),
                                        mirrorDrag: false,
                                      ),
                                      handle(
                                        i,
                                        center - dir * (geomT(i) * radius),
                                        mirrorDrag: true,
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.autofillPartGradientStopDragHint,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          l10n.autofillPartGradientTypeLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        InfoIconTooltip(
                          message: l10n.autofillPartGradientTypeInfo,
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      children: AutofillGradientType.values
                          .map(
                            (t) => ChoiceChip(
                              label: Text(
                                _gradientTypeLabel(l10n, t),
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: gradient.type == t,
                              onSelected: (selected) {
                                if (selected) {
                                  setS(
                                    () => gradient = gradient.copyWith(type: t),
                                  );
                                }
                              },
                            ),
                          )
                          .toList(),
                    ),
                    if (gradient.type == AutofillGradientType.linear) ...[
                      const SizedBox(height: 8),
                      EditableSliderValue(
                        text: l10n.autofillPartGradientAngleLabel(
                          gradient.angle.round(),
                        ),
                        style: const TextStyle(fontSize: 12),
                        value: gradient.angle,
                        min: 0,
                        max: 359,
                        onChanged: (v) => setS(
                          () =>
                              gradient = gradient.copyWith(angle: v.toDouble()),
                        ),
                      ),
                      SteppedSlider(
                        value: gradient.angle,
                        min: 0,
                        max: 359,
                        onChanged: (v) =>
                            setS(() => gradient = gradient.copyWith(angle: v)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // ぼかしの強さ：0%＝境界がはっきりした帯状、
                    // 100%＝滑らかなブレンド。
                    Row(
                      children: [
                        Expanded(
                          child: EditableSliderValue(
                            text: l10n.autofillPartGradientFeatherLabel(
                              (gradient.feather * 100).round(),
                            ),
                            style: const TextStyle(fontSize: 12),
                            value: (gradient.feather * 100).round(),
                            min: 0,
                            max: 100,
                            onChanged: (v) => setS(
                              () => gradient = gradient.copyWith(
                                feather: v / 100,
                              ),
                            ),
                          ),
                        ),
                        InfoIconTooltip(
                          message: l10n.autofillPartGradientFeatherInfo,
                        ),
                      ],
                    ),
                    SteppedSlider(
                      value: gradient.feather,
                      min: 0,
                      max: 1,
                      step: 0.01,
                      onChanged: (v) =>
                          setS(() => gradient = gradient.copyWith(feather: v)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          l10n.autofillPartGradientColorLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: gradient.colors.length >= 10
                              ? null
                              : () {
                                  final colors = [
                                    ...gradient.colors,
                                    0xFFFFFFFF,
                                  ];
                                  setS(
                                    () => gradient = gradient.copyWith(
                                      colors: colors,
                                      stops: _evenStops(colors.length),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            l10n.autofillPartGradientAddColorButton,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      l10n.autofillPartGradientDragHint,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 色一覧：ドラッグで順番入れ替え、各色ごとにタップで色（不透明度
                    // 含む）変更・画像からスポイト・切り替え位置の調整・削除ができる。
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // 手動のドラッグハンドルアイコンを行末に置いているため、
                      // 既定のドラッグハンドルは無効化する（有効のままだと
                      // 二重に表示されるバグがあった）。
                      buildDefaultDragHandles: false,
                      itemCount: gradient.colors.length,
                      // onReorderItemはnewIndexを「削除後の位置」へ調整済みで
                      // 渡すため、従来の `newIndex -= 1` 補正は不要。
                      onReorderItem: (oldIndex, newIndex) {
                        final colors = List<int>.from(gradient.colors);
                        final item = colors.removeAt(oldIndex);
                        colors.insert(newIndex, item);
                        // 位置（stops）は見た目の並び基準を保つため、色の並び替えに
                        // 合わせて均等配置へ振り直す。
                        setS(
                          () => gradient = gradient.copyWith(
                            colors: colors,
                            stops: _evenStops(colors.length),
                          ),
                        );
                      },
                      itemBuilder: (context, i) {
                        final color = Color(gradient.colors[i]);
                        return Padding(
                          key: ValueKey('grad_color_$i-${gradient.colors[i]}'),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showGradientColorPicker(
                                  context,
                                  color,
                                  (c) => setColorAt(i, c.toARGB32()),
                                ),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // 画像から色をスポイト（グラデーション設定内
                              // でもカラーピッカーだけでなく画像からスポイトできる）。
                              IconButton(
                                icon: const Icon(Icons.colorize, size: 16),
                                tooltip:
                                    l10n.autofillEyedropperFromThumbnailButton,
                                onPressed: () => _pickColorFromNewImage(
                                  (c) => setColorAt(i, c.toARGB32()),
                                ),
                              ),
                              // 切り替え位置はプレビュー直下の三角形ハンドルを直接
                              // ドラッグして調整する方が直感的なため、ここでは現在値の
                              // 参考表示のみ行う。
                              Expanded(
                                child: Text(
                                  l10n.autofillPartGradientStopLabel(
                                    (gradient.stops[i] * 100).round(),
                                  ),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: ThemeService.activeColorScheme.error,
                                ),
                                tooltip: l10n.commonDelete,
                                onPressed: gradient.colors.length <= 2
                                    ? null
                                    : () {
                                        final colors = List<int>.from(
                                          gradient.colors,
                                        )..removeAt(i);
                                        setS(
                                          () => gradient = gradient.copyWith(
                                            colors: colors,
                                            stops: _evenStops(colors.length),
                                          ),
                                        );
                                      },
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.drag_handle, size: 18),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, part.copyWith(gradient: null)),
                child: Text(l10n.autofillPartGradientRemoveButton),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, part.copyWith(gradient: gradient)),
                child: Text(l10n.autofillPartApplyButton),
              ),
            ],
          );
        },
      ),
    );
  }

  List<double> _evenStops(int count) {
    if (count <= 1) return const [0.0];
    return List.generate(count, (i) => i / (count - 1));
  }

  /// 塗り色（単色・グラデーションいずれも）のリアルタイムプレビュー。
  /// チェッカー柄の背景に、不透明度を反映した状態で重ねて表示することで、
  /// 不透明度スライダーを動かした時にプレビューでも分かるようにする。
  /// 線画色プレビュー用に、線画の実際の色（塗り色プレビューだけでなく
  /// 線画色も）を計算する。
  /// autofill_engine.dartのrecolorLineart/_traceAdjustColorと同じロジック
  /// （色トレス・線画馴染ませの基準は塗り色）をHSLColorで再現している。
  /// グラデーション塗りの場合、線画色プレビューは代表色として先頭の色を
  /// 使う（実際の塗りは位置によって連続的に変化するが、小さなスウォッチ
  /// では代表色1色で十分なため）。
  Color _lineColorFor(AutofillPart p) {
    switch (p.lineColorMode) {
      case AutofillLineColorMode.specified:
        return Color(p.lineColor);
      case AutofillLineColorMode.sameAsFill:
        return p.gradient != null
            ? Color(p.gradient!.colors.first)
            : Color(p.color);
      case AutofillLineColorMode.traceAdjust:
        final base = p.gradient != null
            ? Color(p.gradient!.colors.first)
            : Color(p.color);
        final hsl = HSLColor.fromColor(base);
        var newHue = (hsl.hue + p.traceHue) % 360;
        if (newHue < 0) newHue += 360;
        final newSat = (hsl.saturation + p.traceSaturation / 100).clamp(
          0.0,
          1.0,
        );
        final newLight = (hsl.lightness + p.traceLightness / 100).clamp(
          0.0,
          1.0,
        );
        return HSLColor.fromAHSL(1.0, newHue, newSat, newLight).toColor();
    }
  }

  Widget _fillPreview(AutofillPart p, {double height = 40}) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: const _CheckerboardPainter()),
          Opacity(
            opacity: p.opacity / 100,
            child: p.gradient == null
                ? ColoredBox(color: Color(p.color))
                // プレビュー枠の実際の縦横比（LayoutBuilderで取得）を
                // _previewGradient()へ渡し、角度の見た目を実際の塗り結果と
                // 一致させる（枠の縦横比を考慮しないと、正方形でない枠では
                // 角度が実際より歪んで見えてしまうため）。
                : LayoutBuilder(
                    builder: (context, constraints) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _previewGradient(
                          p.gradient!,
                          constraints.maxWidth,
                          height,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 縁取り設定のプレビュー：塗り色の丸みを帯びた見本図形へ、現在の
  /// 縁取り色・太さを縁として重ねて表示する（自動塗りエンジン本体の
  /// 計算とは独立した簡易表示）。極端に太い値を指定してもプレビュー枠に
  /// 収まるよう、表示上の太さのみ上限を設けている（実際の縁取り太さは
  /// 上限なくそのまま反映される）。
  Widget _outlinePreview(AutofillPart p) {
    final displayWidth = p.outlineWidth.clamp(1, 16).toDouble();
    return Container(
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: const _CheckerboardPainter()),
          Center(
            child: Container(
              width: 72,
              height: 28,
              decoration: BoxDecoration(
                color: Color(p.color),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Color(p.outlineColor),
                  width: displayWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [g]の種類（直線／放射2種）・角度・中心位置・ぼかしの強さを反映した
  /// Flutter用Gradientへ変換する（角度の違うグラデーションや
  /// 放射状のグラデーションなど対応したプレビューを表示する）。
  /// autofill_engine.dartの実際の塗り計算式（_gradientColorAt/_sampleGradient）
  /// と挙動を合わせている。[w]・[h]はプレビュー枠の実際の幅・高さ
  /// （直線グラデーションの角度計算で、枠の縦横比に依存せず指定した
  /// 角度どおりの傾きになるよう補正するために使う）。
  Gradient _previewGradient(AutofillGradient g, double w, double h) {
    switch (g.type) {
      case AutofillGradientType.linear:
        final expanded = _expandForFeather(g.colors, g.stops, g.feather);
        final rad = g.angle * math.pi / 180;
        final dx = math.cos(rad);
        final dy = math.sin(rad);
        // Alignmentはx・yをそれぞれ枠の幅・高さの半分を基準に正規化する
        // ため、dx・dyをそのまま使うと正方形でない枠では見た目の傾きが
        // 指定角度からズレる（autofill_engine.dart側の同じ不具合と対応する
        // 修正）。ピクセル単位の対角線長を幅・高さそれぞれで割ることで、
        // 枠の縦横比によらず実際のピクセル空間で指定角度どおりに見える
        // Alignmentへ変換する。
        final diag = math.sqrt(w * w + h * h);
        final ax = w > 0 ? diag * dx / w : dx;
        final ay = h > 0 ? diag * dy / h : dy;
        return LinearGradient(
          begin: Alignment(-ax, -ay),
          end: Alignment(ax, ay),
          colors: expanded.colors,
          stops: expanded.stops,
        );
      case AutofillGradientType.radialCenterOut:
      case AutofillGradientType.radialOutCenter:
        // プレビューは横長・薄い帯（本来の塗り範囲とは形が違う簡易表示）
        // のため、Flutter標準のRadialGradient（箱の短辺基準の円）を
        // そのまま使うと、下の三角ハンドル（幅いっぱいを使って中心からの
        // 距離を表す）とは全く違う位置に色の境界が来てしまっていた
        // （ぼかしの強さを下げてはっきりした帯にすると特に目立つズレ）。
        // ハンドルと同じ「中心からの距離＝箱の幅に対する割合」で色を
        // 配置した、左右対称のLinearGradientとして描き直す。
        final isOutCenter = g.type == AutofillGradientType.radialOutCenter;
        final pairs = <MapEntry<double, int>>[
          for (int i = 0; i < g.colors.length; i++)
            MapEntry(isOutCenter ? 1 - g.stops[i] : g.stops[i], g.colors[i]),
        ]..sort((a, b) => a.key.compareTo(b.key));
        final geomStops = pairs.map((p) => p.key).toList();
        final geomColors = pairs.map((p) => p.value).toList();
        final expanded = _expandForFeather(geomColors, geomStops, g.feather);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [
            for (final t in expanded.stops.reversed) 0.5 - t * 0.5,
            for (final t in expanded.stops) 0.5 + t * 0.5,
          ],
          colors: [...expanded.colors.reversed, ...expanded.colors],
        );
    }
  }

  /// ぼかしの強さ（0.0〜1.0）を反映した表示用の色・stops列を生成する
  /// （autofill_engine.dartの_sampleGradientと同じアルゴリズムを、
  /// Flutter Gradientが扱える離散stops列へ展開したもの）。
  ({List<Color> colors, List<double> stops}) _expandForFeather(
    List<int> colorsInt,
    List<double> stopsIn,
    double feather,
  ) {
    if (colorsInt.length < 2) {
      return (colors: colorsInt.map(Color.new).toList(), stops: stopsIn);
    }
    // 100%（最大）は隣の色の端まで完全に混ざり切る、元のstopsそのままの
    // 単純な線形補間にする。帯計算を経由しないため誤差なく確実に端まで
    // 混ざる。
    if (feather.clamp(0.0, 1.0) >= 0.999) {
      return (colors: colorsInt.map(Color.new).toList(), stops: stopsIn);
    }
    final outColors = <Color>[];
    final outStops = <double>[];
    void addPoint(double stop, Color color) {
      if (outStops.isNotEmpty && stop <= outStops.last) {
        stop = outStops.last + 0.0001;
      }
      outStops.add(stop.clamp(0.0, 1.0));
      outColors.add(color);
    }

    addPoint(stopsIn.first, Color(colorsInt.first));
    for (int i = 0; i < colorsInt.length - 1; i++) {
      final s0 = stopsIn[i], s1 = stopsIn[i + 1];
      final mid = (s0 + s1) / 2;
      final halfBand = (s1 - s0) / 2 * feather.clamp(0.0, 1.0);
      addPoint(mid - halfBand, Color(colorsInt[i]));
      addPoint(mid + halfBand, Color(colorsInt[i + 1]));
    }
    addPoint(stopsIn.last, Color(colorsInt.last));
    return (colors: outColors, stops: outStops);
  }

  /// パーツの塗り色・線画色・グラデーション色の選択に共通利用するカラー
  /// ピッカー。アプリ全体と同じHSVホイール／RGB／HEX／最近使った色／
  /// ユーザーパレットを備えたColorPickerPanelを使う。
  void _showColorPickerFor(
    BuildContext context,
    Color initial,
    ValueChanged<Color> onChanged,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ColorPickerPanel(
          currentColor: initial,
          onColorChanged: onChanged,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  /// グラデーション設定内の色スウォッチ専用のカラーピッカー。変更が
  /// 保持されるか破棄されるか明確になるよう、通常のColorPickerPanel
  /// （[_showColorPickerFor]）とは異なり上部の閉じるボタンは表示せず、
  /// グラデーション設定本体と同じ「キャンセル・適用」ボタンを下部に
  /// 常設する。調整中はプレビューだけ更新し、キャンセルなら破棄・
  /// 適用を押して初めて[onApply]（グラデーションの当該色）へ反映する。
  void _showGradientColorPicker(
    BuildContext context,
    Color initial,
    ValueChanged<Color> onApply,
  ) {
    final l10n = AppLocalizations.of(context)!;
    var working = initial;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        // ColorPickerPanel自体は最大680px・内部スクロール済みだが、下に
        // 「キャンセル・適用」ボタンのCardを追加した分だけ通常のカラー
        // ピッカーより全体が縦に長くなり、画面の低い端末（横画面や
        // 小型端末）では画面外へはみ出してボトムオーバーフローになって
        // いた。全体をSingleChildScrollViewで包み、画面に収まらない
        // 場合は縦スクロールできるようにして防ぐ。
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPickerPanel(
                currentColor: initial,
                showCloseBar: false,
                onColorChanged: (c) => working = c,
                onClose: () {},
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.commonCancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          onApply(working);
                          Navigator.pop(ctx);
                        },
                        child: Text(l10n.autofillPartApplyButton),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _gradientTypeLabel(AppLocalizations l10n, AutofillGradientType t) =>
      switch (t) {
        AutofillGradientType.linear => l10n.autofillGradientTypeLinear,
        AutofillGradientType.radialCenterOut =>
          l10n.autofillGradientTypeRadialCenterOut,
        AutofillGradientType.radialOutCenter =>
          l10n.autofillGradientTypeRadialOutCenter,
      };
}

/// 不透明度プレビュー用のチェッカー柄背景（不透明度を変更した際
/// にプレビューでも分かりやすく変化するようにする）。
class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 6.0;
    final light = Paint()..color = const Color(0xFFCCCCCC);
    final dark = Paint()..color = const Color(0xFF999999);
    canvas.drawRect(Offset.zero & size, light);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final isDark = ((x / cell).floor() + (y / cell).floor()) % 2 == 0;
        if (isDark) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}

/// グラデーションの切り替え位置（stops）を表す三角形ハンドル（
/// プレビュー直下でドラッグして直接位置調整できるようにする）。
class _StopHandlePainter extends CustomPainter {
  final Color color;
  const _StopHandlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = ThemeService.activeColorScheme.onSurface.withValues(alpha: 0.54)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _StopHandlePainter oldDelegate) =>
      oldDelegate.color != color;
}
