import 'package:flutter/material.dart';
import '../../models/autofill_preset.dart';

class AutofillPresetScreen extends StatefulWidget {
  const AutofillPresetScreen({super.key});

  @override
  State<AutofillPresetScreen> createState() => _AutofillPresetScreenState();
}

class _AutofillPresetScreenState extends State<AutofillPresetScreen> {
  final List<AutofillPreset> _presets = [
    AutofillPreset(id: 'p1', name: '主人公', parts: [
      AutofillPart(id: 'p1_1', name: '髪', color: 0xFF4A3728),
      AutofillPart(id: 'p1_2', name: '肌', color: 0xFFFFD5B0),
      AutofillPart(id: 'p1_3', name: '瞳', color: 0xFF3A6EA5),
      AutofillPart(id: 'p1_4', name: '服', color: 0xFF2C5F8A),
    ]),
    AutofillPreset(id: 'p2', name: 'ヒロイン', parts: [
      AutofillPart(id: 'p2_1', name: '髪', color: 0xFFE8C4A0),
      AutofillPart(id: 'p2_2', name: '肌', color: 0xFFFFE0C8),
      AutofillPart(id: 'p2_3', name: '瞳', color: 0xFF8B4513),
      AutofillPart(id: 'p2_4', name: '服', color: 0xFFFF6B9D),
      AutofillPart(id: 'p2_5', name: 'リボン', color: 0xFFFF1493),
    ]),
  ];

  String _searchQuery = '';
  bool _isSearching = false;

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
          ? const Center(child: Text('プリセットがありません'))
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
                setState(() => _presets.add(AutofillPreset(
                  id: 'p_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  parts: [],
                )));
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
                setState(() {
                  final idx = _presets.indexWhere((p) => p.id == preset.id);
                  if (idx >= 0) _presets[idx] = preset.copyWith(name: nameCtrl.text);
                });
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
              setState(() => _presets.removeWhere((p) => p.id == preset.id));
              Navigator.pop(ctx);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showPresetDetail(AutofillPreset preset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PresetDetailScreen(
          preset: preset,
          onUpdate: (updated) => setState(() {
            final idx = _presets.indexWhere((p) => p.id == updated.id);
            if (idx >= 0) _presets[idx] = updated;
          }),
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
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(4),
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

class _PresetDetailScreen extends StatefulWidget {
  final AutofillPreset preset;
  final ValueChanged<AutofillPreset> onUpdate;

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

  void _save(AutofillPreset updated) {
    setState(() => _preset = updated);
    widget.onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_preset.name)),
      body: _preset.parts.isEmpty
          ? const Center(child: Text('パーツがありません\n＋ボタンで追加してください'))
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
                        color: Color(part.color),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
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
                          _save(_preset.copyWith(parts: parts));
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
                  p.id == part.id ? AutofillPart(id: p.id, name: nameCtrl.text, color: p.color) : p
                ).toList();
                _save(_preset.copyWith(parts: parts));
              }
              Navigator.pop(ctx);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    ).then((_) => nameCtrl.dispose());
  }

  void _showColorPicker(AutofillPart part) {
    final colors = [
      0xFFFF0000, 0xFFFF6600, 0xFFFFCC00, 0xFF00CC00,
      0xFF0066FF, 0xFF9900CC, 0xFFFF99CC, 0xFF996633,
      0xFFFFD5B0, 0xFF4A3728, 0xFF2C5F8A, 0xFFCCCCCC,
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${part.name}の色'),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: colors.map((c) => GestureDetector(
            onTap: () {
              final parts = _preset.parts.map((p) =>
                p.id == part.id ? AutofillPart(id: p.id, name: p.name, color: c) : p
              ).toList();
              _save(_preset.copyWith(parts: parts));
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ],
      ),
    );
  }
}
