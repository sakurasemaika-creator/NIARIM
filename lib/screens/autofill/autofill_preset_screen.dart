import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/autofill_gradient.dart';
import '../../models/autofill_preset.dart';
import '../../models/layer.dart' show LayerBlendMode;
import '../../services/autofill_preset_service.dart';
import '../../services/project_service.dart';
import '../../services/tone_service.dart';
import '../../widgets/help_button.dart';

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

  List<AutofillPreset> get _presets => context.watch<AutofillPresetService>().presets;

  List<AutofillPreset> get _filtered {
    var list = _searchQuery.isEmpty
        ? _presets
        : _presets.where((p) => p.name.contains(_searchQuery)).toList();
    if (_showFavoritesOnly) list = list.where((p) => p.isFavorite).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'プリセット検索', border: InputBorder.none),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('自動塗りプリセット'),
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
                  label: const Text('お気に入り'),
                  selected: _showFavoritesOnly,
                  onSelected: (v) => setState(() => _showFavoritesOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
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
                        Text(_showFavoritesOnly ? 'お気に入りのプリセットがありません' : 'プリセットがありません',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 8),
                        Text('右下の＋から作成できます',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) => _PresetCard(
                      preset: _filtered[index],
                      onToggleFavorite: () => context
                          .read<AutofillPresetService>()
                          .updatePreset(_filtered[index].copyWith(isFavorite: !_filtered[index].isFavorite)),
                      onEdit: () => _showEditDialog(_filtered[index]),
                      onDelete: () => _confirmDelete(_filtered[index]),
                      onTap: () => _showPresetDetail(_filtered[index]),
                    ),
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
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規プリセット'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'プリセット名', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<AutofillPresetService>().addPreset(AutofillPreset(
                  id: 'p_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  parts: [],
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    ).then((_) => nameCtrl.dispose());
  }

  void _showEditDialog(AutofillPreset preset) {
    final nameCtrl = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プリセット名変更'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                context.read<AutofillPresetService>().updatePreset(preset.copyWith(name: nameCtrl.text));
              }
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    ).then((_) => nameCtrl.dispose());
  }

  void _confirmDelete(AutofillPreset preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「${preset.name}」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
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
            child: const Text('削除'),
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
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: preset.parts.isEmpty
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
        subtitle: Text('${preset.parts.length}パーツ', style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(preset.isFavorite ? Icons.star : Icons.star_border,
                  color: preset.isFavorite ? Colors.amber : null),
              onPressed: onToggleFavorite,
              tooltip: preset.isFavorite ? 'お気に入り解除' : 'お気に入り登録',
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('名前変更')),
                const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
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

  @override
  void initState() {
    super.initState();
    _preset = widget.preset;
  }

  void _save(AutofillPreset updated, {String? changedPartId}) {
    setState(() => _preset = updated);
    widget.onUpdate(updated, changedPartId: changedPartId);
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
                decoration: const InputDecoration(hintText: 'パーツ名で検索', border: InputBorder.none),
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
                '未設定のパーツが${unconfigured.length}件あります：'
                '${unconfigured.map((p) => p.name).join('・')}（トーン未選択）\n'
                'すべて設定するまでこの画面を閉じられません。',
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未設定のパーツがあります'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('保存する前に、以下のパーツを設定してください（仕様書20：保存チェック）。'),
            const SizedBox(height: 8),
            for (final p in unconfigured)
              Text('・${p.name}：トーンが未選択です',
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('設定へ戻る')),
        ],
      ),
    );
  }

  Widget _partListBody() {
    return _preset.parts.isEmpty
          ? Center(
              child: Text('パーツがありません\n＋ボタンで追加してください',
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
  Widget _partTile(AutofillPart part) {
    return ListTile(
                  key: ValueKey(part.id),
                  leading: GestureDetector(
                    onTap: () => _showPartDetailDialog(part),
                    child: Container(
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
                    ),
                  ),
                  title: Text(part.name),
                  // ✓設定完了マーク（仕様書20：保存チェック）
                  subtitle: part.isConfigured
                      ? null
                      : const Text('トーンが未選択です', style: TextStyle(fontSize: 10, color: Colors.red)),
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
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('パーツ追加'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'パーツ名', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final parts = List<AutofillPart>.from(_preset.parts)
                  ..add(AutofillPart(
                    id: 'part_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text,
                    color: 0xFFCCCCCC,
                  ));
                _save(_preset.copyWith(parts: parts));
              }
              Navigator.pop(ctx);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    ).then((_) => nameCtrl.dispose());
  }

  void _showEditPartDialog(AutofillPart part) {
    final nameCtrl = TextEditingController(text: part.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('パーツ名変更'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
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
            child: const Text('変更'),
          ),
        ],
      ),
    ).then((_) => nameCtrl.dispose());
  }

  static const _paletteColors = [
    0xFFFF0000, 0xFFFF6600, 0xFFFFCC00, 0xFF00CC00,
    0xFF0066FF, 0xFF9900CC, 0xFFFF99CC, 0xFF996633,
    0xFFFFD5B0, 0xFF4A3728, 0xFF2C5F8A, 0xFFCCCCCC,
  ];

  static const _lineColorModeLabels = {
    AutofillLineColorMode.specified: '指定色',
    AutofillLineColorMode.sameAsFill: '塗り色と同じ',
    AutofillLineColorMode.traceAdjust: '色トレス・線画馴染ませ',
  };

  static const _blendModeLabels = {
    LayerBlendMode.normal: '通常',
    LayerBlendMode.multiply: '乗算',
    LayerBlendMode.screen: 'スクリーン',
    LayerBlendMode.overlay: 'オーバーレイ',
    LayerBlendMode.addition: '加算',
    LayerBlendMode.subtract: '減算',
    LayerBlendMode.darken: '比較（暗）',
    LayerBlendMode.lighten: '比較（明）',
    LayerBlendMode.colorBurn: '焼き込みカラー',
    LayerBlendMode.colorDodge: '覆い焼きカラー',
    LayerBlendMode.hardLight: 'ハードライト',
    LayerBlendMode.softLight: 'ソフトライト',
    LayerBlendMode.difference: '差の絶対値',
    LayerBlendMode.hue: '色相',
    LayerBlendMode.saturation: '彩度',
    LayerBlendMode.color: 'カラー',
    LayerBlendMode.luminosity: '輝度',
  };

  /// 詳細設定ポップアップ（仕様書20：色チップタップ時。塗り色・線画色・
  /// グラデーション・トーン・ブレンドモード・不透明度をすべてリアルタイム
  /// プレビュー付きで設定する）。
  void _showPartDetailDialog(AutofillPart part) {
    var current = part;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final tones = context.watch<ToneService>().tones;
          return AlertDialog(
            title: Text('${part.name}の詳細設定'),
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
                    Text('塗り色', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _paletteColors.map((c) => GestureDetector(
                        onTap: () => setS(() => current = current.copyWith(color: c, gradient: null)),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: current.gradient == null && current.color == c
                                    ? Theme.of(ctx).colorScheme.primary
                                    : Colors.grey,
                                width: current.gradient == null && current.color == c ? 2 : 1),
                          ),
                        ),
                      )).toList(),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final updated = await _showGradientEditor(current);
                        if (updated != null) setS(() => current = updated);
                      },
                      icon: const Icon(Icons.gradient, size: 16),
                      label: Text(current.gradient == null ? 'グラデーション設定' : 'グラデーション編集',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Text('不透明度（塗りレイヤー）: ${current.opacity}%', style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: current.opacity.toDouble(),
                      min: 0, max: 100, divisions: 100,
                      onChanged: (v) => setS(() => current = current.copyWith(opacity: v.round())),
                    ),
                    const Divider(),
                    Text('線画色', style: Theme.of(ctx).textTheme.titleSmall),
                    ...AutofillLineColorMode.values.map((m) => RadioListTile<AutofillLineColorMode>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_lineColorModeLabels[m]!, style: const TextStyle(fontSize: 13)),
                          value: m,
                          groupValue: current.lineColorMode,
                          onChanged: (v) => setS(() => current = current.copyWith(lineColorMode: v)),
                        )),
                    if (current.lineColorMode == AutofillLineColorMode.specified) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _paletteColors.map((c) => GestureDetector(
                          onTap: () => setS(() => current = current.copyWith(lineColor: c)),
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: current.lineColor == c ? Theme.of(ctx).colorScheme.primary : Colors.grey,
                                  width: current.lineColor == c ? 2 : 1),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                    if (current.lineColorMode == AutofillLineColorMode.traceAdjust) ...[
                      Text('色相: ${current.traceHue.round()}', style: const TextStyle(fontSize: 11)),
                      Slider(
                        value: current.traceHue, min: -180, max: 180,
                        onChanged: (v) => setS(() => current = current.copyWith(traceHue: v)),
                      ),
                      Text('彩度: ${current.traceSaturation.round()}', style: const TextStyle(fontSize: 11)),
                      Slider(
                        value: current.traceSaturation, min: 0, max: 100,
                        onChanged: (v) => setS(() => current = current.copyWith(traceSaturation: v)),
                      ),
                      Text('明度: ${current.traceLightness.round()}', style: const TextStyle(fontSize: 11)),
                      Slider(
                        value: current.traceLightness, min: -100, max: 100,
                        onChanged: (v) => setS(() => current = current.copyWith(traceLightness: v)),
                      ),
                    ],
                    Text('不透明度（線画レイヤー）: ${current.lineOpacity}%', style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: current.lineOpacity.toDouble(),
                      min: 0, max: 100, divisions: 100,
                      onChanged: (v) => setS(() => current = current.copyWith(lineOpacity: v.round())),
                    ),
                    const Divider(),
                    Text('トーン', style: Theme.of(ctx).textTheme.titleSmall),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('トーンを使用', style: TextStyle(fontSize: 13)),
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
                    Text('ブレンドモード', style: Theme.of(ctx).textTheme.titleSmall),
                    DropdownButtonFormField<LayerBlendMode>(
                      initialValue: current.blendMode,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: LayerBlendMode.values
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(_blendModeLabels[m]!, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setS(() => current = current.copyWith(blendMode: v)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
              FilledButton(
                onPressed: () {
                  final parts =
                      _preset.parts.map((p) => p.id == part.id ? current : p).toList();
                  _save(_preset.copyWith(parts: parts), changedPartId: part.id);
                  Navigator.pop(ctx);
                },
                child: const Text('適用'),
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
    var gradient = part.gradient ?? AutofillGradient.defaultTwoColor(part.color, 0xFFFFFFFF);
    return showDialog<AutofillPart>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('${part.name}のグラデーション'),
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
                  const Text('種類', style: TextStyle(fontSize: 12)),
                  Wrap(
                    spacing: 6,
                    children: AutofillGradientType.values.map((t) => ChoiceChip(
                      label: Text(_gradientTypeLabel(t), style: const TextStyle(fontSize: 11)),
                      selected: gradient.type == t,
                      onSelected: (selected) {
                        if (selected) setS(() => gradient = gradient.copyWith(type: t));
                      },
                    )).toList(),
                  ),
                  if (gradient.type == AutofillGradientType.linear) ...[
                    const SizedBox(height: 8),
                    Text('角度: ${gradient.angle.round()}°', style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: gradient.angle,
                      min: 0, max: 359,
                      onChanged: (v) => setS(() => gradient = gradient.copyWith(angle: v)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('色', style: TextStyle(fontSize: 12)),
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
                        label: const Text('色を追加', style: TextStyle(fontSize: 11)),
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
                  const Text('長押しで削除（2色未満にはできません）',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, part.copyWith(gradient: null)),
              child: const Text('グラデーション解除'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, part.copyWith(gradient: gradient)),
              child: const Text('適用'),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('色を選択'),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: _paletteColors.map((c) => GestureDetector(
            onTap: () {
              final colors = List<int>.from(gradient.colors);
              colors[index] = c;
              onPicked(gradient.copyWith(colors: colors));
              Navigator.pop(ctx);
            },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  String _gradientTypeLabel(AutofillGradientType t) => switch (t) {
        AutofillGradientType.linear => '直線',
        AutofillGradientType.radialCenterOut => '放射：中央→外側',
        AutofillGradientType.radialOutCenter => '放射：外側→中央',
      };
}
