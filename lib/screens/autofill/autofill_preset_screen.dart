import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/autofill_gradient.dart';
import '../../models/autofill_preset.dart';
import '../../models/layer.dart' show LayerBlendMode;
import '../../services/autofill_preset_service.dart';
import '../../services/project_service.dart';
import '../../services/tone_service.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/help_button.dart';
import '../../widgets/image_eyedropper_dialog.dart';
import '../../widgets/info_icon_tooltip.dart';
import '../../widgets/square_image_crop_dialog.dart';
import '../../widgets/tone_preview_thumb.dart';
import '../canvas/widgets/color_picker_panel.dart';

class AutofillPresetScreen extends StatefulWidget {
  const AutofillPresetScreen({super.key});

  @override
  State<AutofillPresetScreen> createState() => _AutofillPresetScreenState();
}

class _AutofillPresetScreenState extends State<AutofillPresetScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  // お気に入りのみ絞り込み（仕様書20）。以前はパーツ単位にお気に入りが
  // 付いていたが使いどころが薄かったため廃止し、代わりにプリセット単位の
  // お気に入り＋絞り込みへ一本化した。
  bool _showFavoritesOnly = false;

  // このファイルの各ダイアログが使うTextEditingControllerは、
  // showDialog(...).then((_) => WidgetsBinding.instance.
  // addPostFrameCallback((_) => ctrl.dispose())) という形で破棄する。
  // 単純にshowDialogの直後（.then内）で即座にdispose()すると、ダイアログを
  // 閉じる操作自体が裏で走らせているフォーカス解除処理より先に破棄されて
  // しまうことがあり、直後に別の操作（例：パーツの色をタップして次の
  // ダイアログを開く）をした際に「TextEditingController was used after
  // being disposed」のアサーション例外が発生していた（ユーザー報告により
  // 発覚・修正）。1フレーム遅らせることでフォーカス解除処理を先に完了させる。

  // 以前はcontext.watch()をgetter（_presets/_filtered）に入れており、
  // それをListView.builderの各行のタップ用コールバック（onEdit/onDelete/
  // onTap）内からも呼んでいたため、タップした瞬間（build外）に
  // context.watch()が評価されてProviderのアサーション例外が発生し、
  // プリセット詳細画面へ一切遷移できなくなっていた（ユーザー報告により
  // 発覚・修正）。build()内でのみ一度取得し、以降はフィルタ処理を純粋な
  // 関数にしてコールバックへは確定済みの値（preset自体）だけを渡すよう
  // 修正した。
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
                decoration: InputDecoration(hintText: l10n.autofillPresetSearchHint, border: InputBorder.none),
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
      body: SafeArea(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.homeFavoritesOnly),
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
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.palette_outlined, size: 40, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 20),
                        Text(_showFavoritesOnly ? l10n.autofillPresetEmptyFavorites : l10n.autofillPresetEmpty,
                            style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 8),
                        Text(l10n.autofillPresetEmptyHint,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        onToggleFavorite: () => context
                            .read<AutofillPresetService>()
                            .updatePreset(preset.copyWith(isFavorite: !preset.isFavorite)),
                        onEdit: () => _showEditDialog(preset),
                        onDelete: () => _confirmDelete(preset),
                        onSetThumbnail: () => _showThumbnailDialog(preset),
                        onTap: () => _showPresetDetail(preset),
                      );
                    },
                  ),
          ),
        ],
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
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
          decoration: InputDecoration(labelText: l10n.autofillPresetNameLabel, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<AutofillPresetService>().addPreset(AutofillPreset(
                  id: 'p_${DateTime.now().microsecondsSinceEpoch}',
                  name: nameCtrl.text,
                  parts: [],
                ));
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    ).then((_) => WidgetsBinding.instance.addPostFrameCallback((_) => nameCtrl.dispose()));
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<AutofillPresetService>().updatePreset(preset.copyWith(name: nameCtrl.text));
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then((_) => WidgetsBinding.instance.addPostFrameCallback((_) => nameCtrl.dispose()));
  }

  void _confirmDelete(AutofillPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    // お気に入り登録中は削除できない（ユーザー指示により新規追加）。
    if (preset.isFavorite) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.commonFavoriteDeleteBlocked)));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillPresetDeleteConfirmTitle(preset.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

  /// サムネイル画像設定ポップアップ（仕様書20：三点メニューの「名前変更」
  /// と「削除」の間に追加。「画像読み込み」でトリミングして設定、
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
              width: 88, height: 88,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: path != null
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 32),
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
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(l10n.autofillThumbnailDeleteButton, style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemoveThumbnail(preset);
                },
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  Future<void> _pickAndCropThumbnail(AutofillPreset preset) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    if (!mounted) return;
    // 画像選択後、1:1の正方形へトリミング（位置・大きさ・角度はユーザーが
    // ドラッグ・ピンチ・回転ジェスチャーで調整できる、仕様書20）。
    final cropped = await showDialog<Uint8List>(
      context: context,
      builder: (_) => SquareImageCropDialog(imagePath: result.files.first.path!),
    );
    if (cropped == null || !mounted) return;
    final service = context.read<AutofillPresetService>();
    await service.setPresetThumbnailBytes(preset.id, cropped);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.autofillThumbnailSetSnackbar)));
  }

  void _confirmRemoveThumbnail(AutofillPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillThumbnailDeleteConfirmTitle),
        content: Text(l10n.autofillThumbnailDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AutofillPresetService>().clearPresetThumbnail(preset.id);
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
      MaterialPageRoute(
        builder: (_) => _PresetDetailScreen(
          preset: preset,
          onUpdate: (updated, {String? changedPartId}) {
            presetService.updatePreset(updated);
            // パーツ色・名前の変更を、当該パーツIDを参照する全フレームの自動塗りレイヤーへ伝播（仕様書04）
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
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetThumbnail;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onSetThumbnail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          // サムネイル画像が設定されている場合はそれを優先表示し、未設定の
          // 場合のみ従来通りパーツの色（最大4色）をグリッド表示する
          // （仕様書20：サムネイル画像削除時は既定の色表示へ戻る）。
          child: preset.thumbnailPath != null
              ? Image.file(
                  File(preset.thumbnailPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 24),
                )
              : preset.parts.isEmpty
                  ? const Icon(Icons.palette, size: 24)
                  : GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.all(4),
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      children: preset.parts.take(4).map((p) => Container(
                        decoration: BoxDecoration(
                          color: Color(p.color),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )).toList(),
                    ),
        ),
        title: Text(preset.name),
        subtitle: Text(l10n.autofillPresetPartsCount(preset.parts.length), style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(preset.isFavorite ? Icons.star : Icons.star_border,
                  color: preset.isFavorite ? Colors.amber : null),
              onPressed: onToggleFavorite,
              tooltip: preset.isFavorite ? l10n.colorPickerFavoriteRemove : l10n.colorPickerFavoriteAdd,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'thumbnail') onSetThumbnail();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.commonRename)),
                PopupMenuItem(value: 'thumbnail', child: Text(l10n.autofillThumbnailMenuItem)),
                PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

typedef _PresetUpdateCallback = void Function(AutofillPreset updated, {String? changedPartId});

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
  // スクラッチコピー（仕様書20）。この画面を離れる（＝プリセット編集を
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
        try { file.deleteSync(); } catch (_) {}
      }
    }
    super.dispose();
  }

  void _save(AutofillPreset updated, {String? changedPartId}) {
    setState(() => _preset = updated);
    widget.onUpdate(updated, changedPartId: changedPartId);
  }

  /// 画像を都度読み込んでスポイトする（仕様書20：「各パーツ設定の色選択時に
  /// 画像を都度読み込めるようにして」）。読み込んだ画像はスクラッチ領域へ
  /// コピーし、この画面を離れる際に削除する。
  Future<void> _pickColorFromNewImage(ValueChanged<Color> onPicked) async {
    // withData: trueでバイト列も取得しておく。Web版はdart:ioのFileが
    // 使えずpathも常にnullになるため、その場合はバイト列を直接ダイアログへ
    // 渡す（以前はpathがnullだと即returnしてしまい、Web版でスポイトが
    // 全く起動しない不具合があった）。
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null && picked.bytes == null) return;
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
      final scratchPath = '${dir.path}/scratch_${DateTime.now().microsecondsSinceEpoch}.$ext';
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

  /// 未設定パーツ一覧（仕様書20：保存チェック「未設定項目が1つでもある場合は
  /// 保存不可」）。
  List<AutofillPart> get _unconfiguredParts =>
      _preset.parts.where((p) => !p.isConfigured).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unconfigured = _unconfiguredParts;
    return PopScope(
      // 未設定パーツがある間はこの画面を離れられない（仕様書20：保存不可）。
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
                decoration: InputDecoration(hintText: l10n.autofillPartSearchHint, border: InputBorder.none),
                onChanged: (v) => setState(() => _partSearchQuery = v),
              )
            : Text(_preset.name),
        actions: [
          // 検索（仕様書20：「検索・並び替え・お気に入り登録に対応」）
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
      body: SafeArea(child: Column(
        children: [
          // 未設定パーツがある場合の警告バナー（仕様書20：「赤文字で不足している
          // パーツ名と設定内容を表示」）
          if (unconfigured.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                l10n.autofillPartUnconfiguredBanner(
                    unconfigured.length, unconfigured.map((p) => p.name).join('・')),
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
          Expanded(child: _partListBody()),
        ],
      )),
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
            // 保存チェックの仕様根拠は内部コメントに留め、UI文言からは仕様書番号を除いている
            Text(l10n.autofillPartUnconfiguredDialogBody),
            const SizedBox(height: 8),
            for (final p in unconfigured)
              Text(l10n.autofillPartUnconfiguredItem(p.name),
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.autofillPartUnconfiguredBackButton)),
        ],
      ),
    );
  }

  Widget _partListBody() {
    final l10n = AppLocalizations.of(context)!;
    return _preset.parts.isEmpty
          ? Center(
              child: Text(l10n.autofillPartEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          // 検索中は並び替え無効の通常リスト、非検索時のみドラッグ並び替え可能な
          // ReorderableListViewを使う（フィルタ中はインデックスが元リストとずれるため）
          : _partSearchQuery.isNotEmpty
              ? ListView.builder(
                  itemCount: _filteredParts.length,
                  itemBuilder: (context, index) => _partTile(_filteredParts[index]),
                )
              : ReorderableListView.builder(
                  itemCount: _preset.parts.length,
                  onReorder: (oldIdx, newIdx) {
                    final parts = List<AutofillPart>.from(_preset.parts);
                    final item = parts.removeAt(oldIdx);
                    parts.insert(newIdx > oldIdx ? newIdx - 1 : newIdx, item);
                    _save(_preset.copyWith(parts: parts));
                  },
                  itemBuilder: (context, index) => _partTile(_preset.parts[index]),
                );
  }

  /// パーツ一覧の1行（仕様書20：「[サムネイル] パーツ名 [色チップ] ✓設定完了マーク」）。
  /// トーンを使用しているパーツは、単色/グラデーションの丸ではなく指定色で
  /// 着色した実際のトーンパターンをサムネイルに表示する（タスク#91）。
  Widget _partTile(AutofillPart part) {
    final l10n = AppLocalizations.of(context)!;
    Widget thumb;
    if (part.useTone && part.toneId != null) {
      final tone = context.watch<ToneService>().tones.where((t) => t.id == part.toneId).firstOrNull;
      thumb = TonePreviewThumb(tone: tone, color: Color(part.color), size: 32);
    } else {
      thumb = Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: part.gradient == null ? Color(part.color) : null,
          gradient: part.gradient == null
              ? null
              : LinearGradient(
                  colors: part.gradient!.colors.map(Color.new).toList(),
                  stops: part.gradient!.stops,
                ),
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      );
    }
    return ListTile(
                  key: ValueKey(part.id),
                  leading: GestureDetector(
                    onTap: () => _showPartDetailDialog(part),
                    child: thumb,
                  ),
                  title: Text(part.name),
                  // ✓設定完了マーク（仕様書20：保存チェック）
                  subtitle: part.isConfigured
                      ? null
                      : Text(l10n.autofillPartToneUnselected, style: const TextStyle(fontSize: 10, color: Colors.red)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        part.isConfigured ? Icons.check_circle : Icons.error_outline,
                        size: 16,
                        color: part.isConfigured ? Colors.green : Colors.red,
                      ),
                      // パーツ単位のお気に入りは不要（プリセット一覧側の
                      // お気に入り機能に一本化したため削除）。
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: l10n.commonEdit,
                        onPressed: () => _showEditPartDialog(part),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        tooltip: l10n.commonDelete,
                        onPressed: () {
                          final parts = List<AutofillPart>.from(_preset.parts)
                            ..removeWhere((p) => p.id == part.id);
                          _save(_preset.copyWith(parts: parts), changedPartId: part.id);
                        },
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
          decoration: InputDecoration(labelText: l10n.autofillPartNameLabel, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final parts = List<AutofillPart>.from(_preset.parts)
                  ..add(AutofillPart(
                    id: 'part_${DateTime.now().microsecondsSinceEpoch}',
                    name: nameCtrl.text,
                    color: 0xFFCCCCCC,
                  ));
                _save(_preset.copyWith(parts: parts));
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.autofillPartAddButton),
          ),
        ],
      ),
    ).then((_) => WidgetsBinding.instance.addPostFrameCallback((_) => nameCtrl.dispose()));
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final parts = _preset.parts.map((p) =>
                  p.id == part.id ? p.copyWith(name: nameCtrl.text) : p
                ).toList();
                _save(_preset.copyWith(parts: parts), changedPartId: part.id);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then((_) => WidgetsBinding.instance.addPostFrameCallback((_) => nameCtrl.dispose()));
  }

  Map<AutofillLineColorMode, String> _lineColorModeLabels(AppLocalizations l10n) => {
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

  /// 詳細設定ポップアップ（仕様書20：色チップタップ時。塗り色・線画色・
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
                    // リアルタイムプレビュー（仕様書20：不透明度を変更した際に
                    // プレビューでも分かりやすく変化するよう、チェッカー柄の上に
                    // 塗り色・グラデーションを不透明度を反映して重ねる）。
                    _fillPreview(current, height: 40),
                    const SizedBox(height: 12),
                    Text(l10n.autofillPartFillColorLabel, style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => _showColorPickerFor(
                        context,
                        Color(current.color),
                        (c) => setS(() => current = current.copyWith(color: c.toARGB32(), gradient: null)),
                      ),
                      icon: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: Color(current.color),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      label: Text(l10n.autofillPartSelectColorButton, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 6),
                    // 画像を都度読み込んでスポイトで色を拾う（仕様書20：カラー
                    // ピッカーだけでなく、任意の画像から直接色を取得できる）。
                    OutlinedButton.icon(
                      onPressed: () => _pickColorFromNewImage(
                        (c) => setS(() => current = current.copyWith(color: c.toARGB32(), gradient: null)),
                      ),
                      icon: const Icon(Icons.colorize, size: 16),
                      label: Text(l10n.autofillEyedropperFromThumbnailButton, style: const TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final updated = await _showGradientEditor(current);
                        if (updated != null) setS(() => current = updated);
                      },
                      icon: const Icon(Icons.gradient, size: 16),
                      label: Text(current.gradient == null ? l10n.autofillPartGradientSetButton : l10n.autofillPartGradientEditButton,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    EditableSliderValue(
                      text: l10n.autofillPartFillOpacityLabel(current.opacity),
                      style: const TextStyle(fontSize: 12),
                      value: current.opacity, min: 0, max: 100,
                      title: l10n.autofillPartFillOpacityLabel(current.opacity),
                      onChanged: (v) => setS(() => current = current.copyWith(opacity: v.round())),
                    ),
                    Slider(
                      value: current.opacity.toDouble(),
                      min: 0, max: 100, divisions: 100,
                      onChanged: (v) => setS(() => current = current.copyWith(opacity: v.round())),
                    ),
                    const Divider(),
                    Text(l10n.autofillPartLineColorLabel, style: Theme.of(ctx).textTheme.titleSmall),
                    ...AutofillLineColorMode.values.map((m) => RadioListTile<AutofillLineColorMode>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(lineColorModeLabels[m]!, style: const TextStyle(fontSize: 13)),
                          secondary: m == AutofillLineColorMode.traceAdjust
                              ? InfoIconTooltip(message: l10n.autofillLineColorModeTraceAdjustInfo)
                              : null,
                          value: m,
                          groupValue: current.lineColorMode,
                          onChanged: (v) => setS(() => current = current.copyWith(lineColorMode: v)),
                        )),
                    if (current.lineColorMode == AutofillLineColorMode.specified) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: () => _showColorPickerFor(
                          context,
                          Color(current.lineColor),
                          (c) => setS(() => current = current.copyWith(lineColor: c.toARGB32())),
                        ),
                        icon: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: Color(current.lineColor),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                        label: Text(l10n.autofillPartSelectColorButton, style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _pickColorFromNewImage(
                          (c) => setS(() => current = current.copyWith(lineColor: c.toARGB32())),
                        ),
                        icon: const Icon(Icons.colorize, size: 16),
                        label: Text(l10n.autofillEyedropperFromThumbnailButton, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    if (current.lineColorMode == AutofillLineColorMode.traceAdjust) ...[
                      EditableSliderValue(
                        text: l10n.autofillPartTraceHueLabel(current.traceHue.round()),
                        style: const TextStyle(fontSize: 11),
                        value: current.traceHue, min: -180, max: 180, isInt: false,
                        onChanged: (v) => setS(() => current = current.copyWith(traceHue: v.toDouble())),
                      ),
                      Slider(
                        value: current.traceHue, min: -180, max: 180,
                        onChanged: (v) => setS(() => current = current.copyWith(traceHue: v)),
                      ),
                      EditableSliderValue(
                        text: l10n.autofillPartTraceSaturationLabel(current.traceSaturation.round()),
                        style: const TextStyle(fontSize: 11),
                        value: current.traceSaturation, min: 0, max: 100, isInt: false,
                        onChanged: (v) => setS(() => current = current.copyWith(traceSaturation: v.toDouble())),
                      ),
                      Slider(
                        value: current.traceSaturation, min: 0, max: 100,
                        onChanged: (v) => setS(() => current = current.copyWith(traceSaturation: v)),
                      ),
                      EditableSliderValue(
                        text: l10n.autofillPartTraceLightnessLabel(current.traceLightness.round()),
                        style: const TextStyle(fontSize: 11),
                        value: current.traceLightness, min: -100, max: 100, isInt: false,
                        onChanged: (v) => setS(() => current = current.copyWith(traceLightness: v.toDouble())),
                      ),
                      Slider(
                        value: current.traceLightness, min: -100, max: 100,
                        onChanged: (v) => setS(() => current = current.copyWith(traceLightness: v)),
                      ),
                    ],
                    EditableSliderValue(
                      text: l10n.autofillPartLineOpacityLabel(current.lineOpacity),
                      style: const TextStyle(fontSize: 12),
                      value: current.lineOpacity, min: 0, max: 100,
                      onChanged: (v) => setS(() => current = current.copyWith(lineOpacity: v.round())),
                    ),
                    Slider(
                      value: current.lineOpacity.toDouble(),
                      min: 0, max: 100, divisions: 100,
                      onChanged: (v) => setS(() => current = current.copyWith(lineOpacity: v.round())),
                    ),
                    const Divider(),
                    Text(l10n.autofillPartToneLabel, style: Theme.of(ctx).textTheme.titleSmall),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.autofillPartUseToneCheckbox, style: const TextStyle(fontSize: 13)),
                      value: current.useTone,
                      onChanged: (v) => setS(() => current = current.copyWith(useTone: v)),
                    ),
                    // トーンはブラシと同様にユーザーが自作・追加したり配布物を
                    // 読み込んだりできるため、種類が増えるとチップ一覧では
                    // 見づらくなる（ユーザー指摘）。チェックON時のみ現在指定中の
                    // トーン名を1行で表示し、タップで各トーンのプレビュー付き
                    // 一覧から選び直せるようにする。
                    if (current.useTone) ...[
                      const SizedBox(height: 4),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: TonePreviewThumb(
                          tone: tones.where((t) => t.id == current.toneId).firstOrNull,
                          color: Color(current.color),
                          size: 32,
                          shape: BoxShape.rectangle,
                        ),
                        title: Text(
                          tones.where((t) => t.id == current.toneId).firstOrNull?.name ??
                              l10n.autofillPartToneUnselected,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () async {
                          final selected =
                              await _showTonePickerSheet(current.toneId, Color(current.color));
                          if (selected != null) setS(() => current = current.copyWith(toneId: selected));
                        },
                      ),
                    ],
                    const Divider(),
                    Text(l10n.autofillPartBlendModeLabel, style: Theme.of(ctx).textTheme.titleSmall),
                    DropdownButtonFormField<LayerBlendMode>(
                      initialValue: current.blendMode,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: LayerBlendMode.values
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(blendModeLabels[m]!, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setS(() => current = current.copyWith(blendMode: v)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
              FilledButton(
                onPressed: () {
                  final parts =
                      _preset.parts.map((p) => p.id == part.id ? current : p).toList();
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

  /// トーン選択シート（仕様書04・20）。ブラシと同様にユーザーが自作・追加・
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
                    child: Text(l10n.autofillPartToneLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: tones.isEmpty
                        ? Center(child: Text(l10n.toneEmpty, style: const TextStyle(color: Colors.grey, fontSize: 12)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: TonePreviewThumb(
                                        tone: tone, color: color, size: 56, shape: BoxShape.rectangle,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(tone.name,
                                        style: const TextStyle(fontSize: 10),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
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

  /// グラデーション編集ダイアログ（仕様書20：塗り色設定・グラデーション）。
  /// 自由な色比率編集の代わりに均等配置とし、種類・角度（直線時）・
  /// 中心位置（放射時、既定は中央）・色（2〜5色）を編集する簡略実装。
  Future<AutofillPart?> _showGradientEditor(AutofillPart part) {
    final l10n = AppLocalizations.of(context)!;
    var gradient = part.gradient ?? AutofillGradient.defaultTwoColor(part.color, 0xFFFFFFFF);
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

          return AlertDialog(
            title: Text(l10n.autofillPartGradientDialogTitle(part.name)),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 実際の種類・角度・放射方向・ぼかしを反映した正確なプレビュー
                    // （仕様書20：「角度の違うグラデーションや放射状のグラデーション
                    // など対応したプレビューを表示する」）。
                    Container(
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: const _CheckerboardPainter()),
                          DecoratedBox(decoration: BoxDecoration(gradient: _previewGradient(gradient))),
                        ],
                      ),
                    ),
                    // プレビュー直下に各色の切り替え位置（stops）に対応する三角形の
                    // ハンドルを表示し、直接ドラッグして位置を調整できるようにする
                    // （ユーザー指摘：個別スライダーより直感的）。
                    SizedBox(
                      height: 14,
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (int i = 0; i < gradient.stops.length; i++)
                              Positioned(
                                left: gradient.stops[i] * constraints.maxWidth - 7,
                                top: 0,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragUpdate: (d) => setStopAt(
                                      i, gradient.stops[i] + d.delta.dx / constraints.maxWidth),
                                  child: CustomPaint(
                                    size: const Size(14, 12),
                                    painter: _StopHandlePainter(color: Color(gradient.colors[i])),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Text(l10n.autofillPartGradientStopDragHint,
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(l10n.autofillPartGradientTypeLabel, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        InfoIconTooltip(message: l10n.autofillPartGradientTypeInfo),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      children: AutofillGradientType.values.map((t) => ChoiceChip(
                        label: Text(_gradientTypeLabel(l10n, t), style: const TextStyle(fontSize: 11)),
                        selected: gradient.type == t,
                        onSelected: (selected) {
                          if (selected) setS(() => gradient = gradient.copyWith(type: t));
                        },
                      )).toList(),
                    ),
                    if (gradient.type == AutofillGradientType.linear) ...[
                      const SizedBox(height: 8),
                      EditableSliderValue(
                        text: l10n.autofillPartGradientAngleLabel(gradient.angle.round()),
                        style: const TextStyle(fontSize: 12),
                        value: gradient.angle, min: 0, max: 359,
                        onChanged: (v) => setS(() => gradient = gradient.copyWith(angle: v.toDouble())),
                      ),
                      Slider(
                        value: gradient.angle,
                        min: 0, max: 359,
                        onChanged: (v) => setS(() => gradient = gradient.copyWith(angle: v)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // ぼかしの強さ（仕様書20）：0%＝境界がはっきりした帯状、
                    // 100%＝従来通りの滑らかなブレンド。
                    Row(
                      children: [
                        Expanded(
                          child: EditableSliderValue(
                            text: l10n.autofillPartGradientFeatherLabel((gradient.feather * 100).round()),
                            style: const TextStyle(fontSize: 12),
                            value: (gradient.feather * 100).round(), min: 0, max: 100,
                            onChanged: (v) => setS(() => gradient = gradient.copyWith(feather: v / 100)),
                          ),
                        ),
                        InfoIconTooltip(message: l10n.autofillPartGradientFeatherInfo),
                      ],
                    ),
                    Slider(
                      value: gradient.feather,
                      min: 0, max: 1,
                      onChanged: (v) => setS(() => gradient = gradient.copyWith(feather: v)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(l10n.autofillPartGradientColorLabel, style: const TextStyle(fontSize: 12)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: gradient.colors.length >= 10 ? null : () {
                            final colors = [...gradient.colors, 0xFFFFFFFF];
                            setS(() => gradient = gradient.copyWith(
                                  colors: colors,
                                  stops: _evenStops(colors.length),
                                ));
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(l10n.autofillPartGradientAddColorButton, style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    Text(l10n.autofillPartGradientDragHint,
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 4),
                    // 色一覧：ドラッグで順番入れ替え、各色ごとにタップで色（不透明度
                    // 含む）変更・画像からスポイト・切り替え位置の調整・削除ができる
                    // （仕様書20）。
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: gradient.colors.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final colors = List<int>.from(gradient.colors);
                        final item = colors.removeAt(oldIndex);
                        colors.insert(newIndex, item);
                        // 位置（stops）は見た目の並び基準を保つため、色の並び替えに
                        // 合わせて均等配置へ振り直す。
                        setS(() => gradient = gradient.copyWith(
                              colors: colors,
                              stops: _evenStops(colors.length),
                            ));
                      },
                      itemBuilder: (context, i) {
                        final color = Color(gradient.colors[i]);
                        return Padding(
                          key: ValueKey('grad_color_$i-${gradient.colors[i]}'),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showColorPickerFor(context, color, (c) => setColorAt(i, c.toARGB32())),
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // 画像から色をスポイト（仕様書20：グラデーション設定内
                              // でもカラーピッカーだけでなく画像からスポイトできる）。
                              IconButton(
                                icon: const Icon(Icons.colorize, size: 16),
                                tooltip: l10n.autofillEyedropperFromThumbnailButton,
                                onPressed: () => _pickColorFromNewImage((c) => setColorAt(i, c.toARGB32())),
                              ),
                              // 切り替え位置はプレビュー直下の三角形ハンドルを直接
                              // ドラッグして調整する方が直感的なため、ここでは現在値の
                              // 参考表示のみ行う（ユーザー指摘）。
                              Expanded(
                                child: Text(
                                  l10n.autofillPartGradientStopLabel((gradient.stops[i] * 100).round()),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: l10n.commonDelete,
                                onPressed: gradient.colors.length <= 2 ? null : () {
                                  final colors = List<int>.from(gradient.colors)..removeAt(i);
                                  setS(() => gradient = gradient.copyWith(
                                        colors: colors,
                                        stops: _evenStops(colors.length),
                                      ));
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
                onPressed: () => Navigator.pop(ctx, part.copyWith(gradient: null)),
                child: Text(l10n.autofillPartGradientRemoveButton),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, part.copyWith(gradient: gradient)),
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
  /// 不透明度スライダーを動かした時にプレビューでも分かるようにする
  /// （ユーザー指摘）。
  Widget _fillPreview(AutofillPart p, {double height = 40}) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: const _CheckerboardPainter()),
          Opacity(
            opacity: p.opacity / 100,
            child: p.gradient == null
                ? ColoredBox(color: Color(p.color))
                : DecoratedBox(decoration: BoxDecoration(gradient: _previewGradient(p.gradient!))),
          ),
        ],
      ),
    );
  }

  /// [g]の種類（直線／放射2種）・角度・中心位置・ぼかしの強さを反映した
  /// Flutter用Gradientへ変換する（仕様書20：「角度の違うグラデーションや
  /// 放射状のグラデーションなど対応したプレビューを表示する」）。
  /// autofill_engine.dartの実際の塗り計算式（_gradientColorAt/_sampleGradient）
  /// と挙動を合わせている。
  Gradient _previewGradient(AutofillGradient g) {
    final expanded = _expandForFeather(g.colors, g.stops, g.feather);
    final center = Alignment(g.centerX * 2 - 1, g.centerY * 2 - 1);
    switch (g.type) {
      case AutofillGradientType.linear:
        final rad = g.angle * math.pi / 180;
        final dx = math.cos(rad);
        final dy = math.sin(rad);
        return LinearGradient(
          begin: Alignment(-dx, -dy),
          end: Alignment(dx, dy),
          colors: expanded.colors,
          stops: expanded.stops,
        );
      case AutofillGradientType.radialCenterOut:
        return RadialGradient(center: center, radius: 0.85, colors: expanded.colors, stops: expanded.stops);
      case AutofillGradientType.radialOutCenter:
        // engineは中心からの距離tを反転（t=1-t）させて同じ配列をサンプルする。
        // Flutterのradiusベース補間で同じ見た目にするには、色・stopsの
        // 双方を反転させる（詳細はコミット時のコメント参照）。
        return RadialGradient(
          center: center,
          radius: 0.85,
          colors: expanded.colors.reversed.toList(),
          stops: expanded.stops.map((s) => 1 - s).toList().reversed.toList(),
        );
    }
  }

  /// ぼかしの強さ（0.0〜1.0）を反映した表示用の色・stops列を生成する
  /// （仕様書20：ぼかしの強さのプレビューへの反映。autofill_engine.dartの
  /// _sampleGradientと同じアルゴリズムを、Flutter Gradientが扱える
  /// 離散stops列へ展開したもの）。
  ({List<Color> colors, List<double> stops}) _expandForFeather(
      List<int> colorsInt, List<double> stopsIn, double feather) {
    if (colorsInt.length < 2) {
      return (colors: colorsInt.map(Color.new).toList(), stops: stopsIn);
    }
    // 100%（最大）は隣の色の端まで完全に混ざり切る、元のstopsそのままの
    // 単純な線形補間にする（ユーザー指示）。帯計算を経由しないため誤差なく
    // 確実に端まで混ざる。
    if (feather.clamp(0.0, 1.0) >= 0.999) {
      return (colors: colorsInt.map(Color.new).toList(), stops: stopsIn);
    }
    final outColors = <Color>[];
    final outStops = <double>[];
    void addPoint(double stop, Color color) {
      if (outStops.isNotEmpty && stop <= outStops.last) stop = outStops.last + 0.0001;
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
  /// ピッカー（仕様書20・タスク#91：固定12色の「謎パレット」を廃止し、
  /// アプリ全体と同じHSVホイール／RGB／HEX／最近使った色／ユーザーパレット
  /// を備えたColorPickerPanelへ統一した）。
  void _showColorPickerFor(BuildContext context, Color initial, ValueChanged<Color> onChanged) {
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

  String _gradientTypeLabel(AppLocalizations l10n, AutofillGradientType t) => switch (t) {
        AutofillGradientType.linear => l10n.autofillGradientTypeLinear,
        AutofillGradientType.radialCenterOut => l10n.autofillGradientTypeRadialCenterOut,
        AutofillGradientType.radialOutCenter => l10n.autofillGradientTypeRadialOutCenter,
      };
}

/// 不透明度プレビュー用のチェッカー柄背景（仕様書20：不透明度を変更した際
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

/// グラデーションの切り替え位置（stops）を表す三角形ハンドル（仕様書20：
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
    canvas.drawPath(path, Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _StopHandlePainter oldDelegate) => oldDelegate.color != color;
}
