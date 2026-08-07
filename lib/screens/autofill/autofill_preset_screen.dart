import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/autofill_gradient.dart';
import '../../models/autofill_preset.dart';
import '../../services/autofill_preset_service.dart';
import '../../services/project_service.dart';

class AutofillPresetScreen extends StatefulWidget {
  const AutofillPresetScreen({super.key});

  @override
  State<AutofillPresetScreen> createState() => _AutofillPresetScreenState();
}

class _AutofillPresetScreenState extends State<AutofillPresetScreen> {
  String _searchQuery = '';
  bool _isSearching = false;

  List<AutofillPreset> get _presets => context.watch<AutofillPresetService>().presets;

  List<AutofillPreset> get _filtered => _searchQuery.isEmpty
      ? _presets
      : _presets.where((p) => p.name.contains(_searchQuery)).toList();

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
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchQuery = '';
            }),
          ),
        ],
      ),
      body: _filtered.isEmpty
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
                  Text('プリセットがありません',
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
                onEdit: () => _showEditDialog(_filtered[index]),
                onDelete: () => _confirmDelete(_filtered[index]),
                onTap: () => _showPresetDetail(_filtered[index]),
              ),
            ),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
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
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('名前変更')),
            const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
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

  @override
  void initState() {
    super.initState();
    _preset = widget.preset;
  }

  void _save(AutofillPreset updated, {String? changedPartId}) {
    setState(() => _preset = updated);
    widget.onUpdate(updated, changedPartId: changedPartId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_preset.name)),
      body: _preset.parts.isEmpty
          ? Center(
              child: Text('パーツがありません\n＋ボタンで追加してください',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            )
          : ReorderableListView.builder(
              itemCount: _preset.parts.length,
              onReorder: (oldIdx, newIdx) {
                final parts = List<AutofillPart>.from(_preset.parts);
                final item = parts.removeAt(oldIdx);
                parts.insert(newIdx > oldIdx ? newIdx - 1 : newIdx, item);
                _save(_preset.copyWith(parts: parts));
              },
              itemBuilder: (context, index) {
                final part = _preset.parts[index];
                return ListTile(
                  key: ValueKey(part.id),
                  leading: GestureDetector(
                    onTap: () => _showColorPicker(part),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPartDialog,
        child: const Icon(Icons.add),
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

  void _showColorPicker(AutofillPart part) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${part.name}の色'),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: _paletteColors.map((c) => GestureDetector(
            onTap: () {
              final parts = _preset.parts.map((p) =>
                p.id == part.id ? p.copyWith(color: c, gradient: null) : p
              ).toList();
              _save(_preset.copyWith(parts: parts), changedPartId: part.id);
              Navigator.pop(ctx);
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey),
              ),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _showGradientEditor(part); },
            child: const Text('グラデーション設定'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }

  /// グラデーション編集ダイアログ（仕様書20：塗り色設定・グラデーション）。
  /// 自由な色比率編集の代わりに均等配置とし、種類・角度（直線時）・
  /// 中心位置（放射時、既定は中央）・色（2〜5色）を編集する簡略実装。
  void _showGradientEditor(AutofillPart part) {
    var gradient = part.gradient ?? AutofillGradient.defaultTwoColor(part.color, 0xFFFFFFFF);
    showDialog(
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
              onPressed: () {
                final parts = _preset.parts.map((p) =>
                  p.id == part.id ? p.copyWith(gradient: null) : p
                ).toList();
                _save(_preset.copyWith(parts: parts), changedPartId: part.id);
                Navigator.pop(ctx);
              },
              child: const Text('グラデーション解除'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                final parts = _preset.parts.map((p) =>
                  p.id == part.id ? p.copyWith(gradient: gradient) : p
                ).toList();
                _save(_preset.copyWith(parts: parts), changedPartId: part.id);
                Navigator.pop(ctx);
              },
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
