import 'dart:io';
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
import '../../widgets/help_button.dart';
import '../../widgets/image_eyedropper_dialog.dart';
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autofillThumbnailMenuItem),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.autofillThumbnailLoadButton),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndCropThumbnail(preset);
              },
            ),
            if (preset.thumbnailPath != null)
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
              ? Image.file(File(preset.thumbnailPath!), fit: BoxFit.cover)
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
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    if (!mounted) return;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/niarim/autofill_scratch');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final sourcePath = result.files.first.path!;
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'png';
    final scratchPath = '${dir.path}/scratch_${DateTime.now().microsecondsSinceEpoch}.$ext';
    await File(sourcePath).copy(scratchPath);
    _scratchImagePaths.add(scratchPath);
    if (!mounted) return;
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => ImageEyedropperDialog(imagePath: scratchPath),
    );
    if (picked != null) onPicked(picked);
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
                        onPressed: () => _showEditPartDialog(part),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
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
                    // リアルタイムプレビュー
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: current.gradient == null ? Color(current.color) : null,
                        gradient: current.gradient == null
                            ? null
                            : LinearGradient(
                                colors: current.gradient!.colors.map(Color.new).toList(),
                                stops: current.gradient!.stops,
                              ),
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
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
                    Text(l10n.autofillPartFillOpacityLabel(current.opacity), style: const TextStyle(fontSize: 12)),
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
                      OutlinedButton.icon(
                        onPressed: () => _pickColorFromNewImage(
                          (c) => setS(() => current = current.copyWith(lineColor: c.toARGB32())),
                        ),
                        icon: const Icon(Icons.colorize, size: 16),
                        label: Text(l10n.autofillEyedropperFromThumbnailButton, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    if (current.lineColorMode == AutofillLineColorMode.traceAdjust) ...[
                      Text(l10n.autofillPartTraceHueLabel(current.traceHue.round()), style: const TextStyle(fontSize: 11)),
                      Slider(
                        value: current.traceHue, min: -180, max: 180,
                        onChanged: (v) => setS(() => current = current.copyWith(traceHue: v)),
                      ),
                      Text(l10n.autofillPartTraceSaturationLabel(current.traceSaturation.round()), style: const TextStyle(fontSize: 11)),
                      Slider(
                        value: current.traceSaturation, min: 0, max: 100,
                        onChanged: (v) => setS(() => current = current.copyWith(traceSaturation: v)),
                      ),
                      Text(l10n.autofillPartTraceLightnessLabel(current.traceLightness.round()), style: const TextStyle(fontSize: 11)),
                      Slider(
                        value: current.traceLightness, min: -100, max: 100,
                        onChanged: (v) => setS(() => current = current.copyWith(traceLightness: v)),
                      ),
                    ],
                    Text(l10n.autofillPartLineOpacityLabel(current.lineOpacity), style: const TextStyle(fontSize: 12)),
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
                    if (current.useTone)
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: tones.map((t) {
                          final selected = current.toneId == t.id;
                          return ChoiceChip(
                            label: Text(t.name, style: const TextStyle(fontSize: 10)),
                            selected: selected,
                            onSelected: (_) => setS(() => current = current.copyWith(toneId: t.id)),
                          );
                        }).toList(),
                      ),
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

  /// グラデーション編集ダイアログ（仕様書20：塗り色設定・グラデーション）。
  /// 自由な色比率編集の代わりに均等配置とし、種類・角度（直線時）・
  /// 中心位置（放射時、既定は中央）・色（2〜5色）を編集する簡略実装。
  Future<AutofillPart?> _showGradientEditor(AutofillPart part) {
    final l10n = AppLocalizations.of(context)!;
    var gradient = part.gradient ?? AutofillGradient.defaultTwoColor(part.color, 0xFFFFFFFF);
    return showDialog<AutofillPart>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.autofillPartGradientDialogTitle(part.name)),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: gradient.colors.map(Color.new).toList(),
                        stops: gradient.stops,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.autofillPartGradientTypeLabel, style: const TextStyle(fontSize: 12)),
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
                    Text(l10n.autofillPartGradientAngleLabel(gradient.angle.round()), style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: gradient.angle,
                      min: 0, max: 359,
                      onChanged: (v) => setS(() => gradient = gradient.copyWith(angle: v)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(l10n.autofillPartGradientColorLabel, style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: gradient.colors.length >= 5 ? null : () {
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
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: List.generate(gradient.colors.length, (i) => GestureDetector(
                      onTap: () => _pickGradientStopColor(ctx, gradient, i, (updated) {
                        setS(() => gradient = updated);
                      }),
                      onLongPress: gradient.colors.length <= 2 ? null : () {
                        final colors = List<int>.from(gradient.colors)..removeAt(i);
                        setS(() => gradient = gradient.copyWith(
                              colors: colors,
                              stops: _evenStops(colors.length),
                            ));
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Color(gradient.colors[i]),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                    )),
                  ),
                  Text(l10n.autofillPartGradientDeleteHint,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
        ),
      ),
    );
  }

  List<double> _evenStops(int count) {
    if (count <= 1) return const [0.0];
    return List.generate(count, (i) => i / (count - 1));
  }

  void _pickGradientStopColor(
    BuildContext context, AutofillGradient gradient, int index, ValueChanged<AutofillGradient> onPicked) {
    _showColorPickerFor(context, Color(gradient.colors[index]), (c) {
      final colors = List<int>.from(gradient.colors);
      colors[index] = c.toARGB32();
      onPicked(gradient.copyWith(colors: colors));
    });
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
