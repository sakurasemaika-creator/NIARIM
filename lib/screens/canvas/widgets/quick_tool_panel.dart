import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/quick_tool_entry.dart';
import '../../../services/brush_service.dart';
import '../../../services/quick_tool_service.dart';

/// 早替えツール設定ポップアップ（仕様書02・08）。
/// ↺ボタンの長押しで表示する。ドラッグで順番変更・削除・追加ができる。
class QuickToolPanel extends StatelessWidget {
  final VoidCallback onClose;
  const QuickToolPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<QuickToolService>();
    final entries = service.entries;

    return Card(
      elevation: 8,
      child: SizedBox(
        width: 260,
        height: 360,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('早替えツール設定', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClose),
                ],
              ),
              const Divider(),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text('登録されたツールがありません',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)))
                    : ReorderableListView.builder(
                        itemCount: entries.length,
                        onReorder: service.reorder,
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          return ListTile(
                            key: ValueKey(e.id),
                            dense: true,
                            leading: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                            title: Text(e.label, style: const TextStyle(fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                              onPressed: () => service.removeEntry(e.id),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('追加'),
                onPressed: () => _showAddDialog(context, service),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, QuickToolService service) {
    final brushService = context.read<BrushService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final brush in brushService.brushes)
              ListTile(
                leading: const Icon(Icons.brush),
                title: Text(brush.name),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSizeDialog(context, service, brush.id, brush.name, brush.size);
                },
              ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: const Text('消しゴム'),
              onTap: () {
                _addSimple(service, 'eraser', '消しゴム');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.colorize),
              title: const Text('スポイト'),
              onTap: () {
                _addSimple(service, 'eyedropper', 'スポイト');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_color_fill),
              title: const Text('バケツ'),
              onTap: () {
                _addSimple(service, 'bucket', 'バケツ');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addSimple(QuickToolService service, String toolKey, String label) {
    service.addEntry(QuickToolEntry(
      id: 'qt_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      toolKey: toolKey,
    ));
  }

  void _showSizeDialog(
      BuildContext context, QuickToolService service, String brushId, String brushName, double defaultSize) {
    double size = defaultSize;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('$brushNameのサイズ'),
          content: Row(
            children: [
              Expanded(
                child: Slider(
                  value: size.clamp(1, 200),
                  min: 1, max: 200,
                  label: '${size.round()}px',
                  onChanged: (v) => setS(() => size = v),
                ),
              ),
              SizedBox(width: 48, child: Text('${size.round()}px', textAlign: TextAlign.center)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                service.addEntry(QuickToolEntry(
                  id: 'qt_${DateTime.now().microsecondsSinceEpoch}',
                  label: '$brushName ${size.round()}px',
                  toolKey: 'pen',
                  brushId: brushId,
                  sizeOverride: size,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }
}
