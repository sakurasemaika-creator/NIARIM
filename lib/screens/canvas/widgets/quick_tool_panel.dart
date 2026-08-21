import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/quick_tool_entry.dart';
import '../../../services/brush_service.dart';
import '../../../services/quick_tool_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/stepped_slider.dart';
import '../canvas_screen.dart' show DrawingTool;
import 'panel_close_bar.dart';

/// 早替えツール設定ポップアップ（仕様書02・08）。
/// ↺ボタンの長押しで表示する。ドラッグで順番変更・削除・追加ができる。
class QuickToolPanel extends StatelessWidget {
  final VoidCallback onClose;
  // 「現在のブラシを追加」用（仕様書08：使用中のブラシ設定をそのまま登録可能）
  final DrawingTool currentTool;
  final String? currentBrushId;
  final String? currentBrushName;
  final double currentSize;

  const QuickToolPanel({
    super.key,
    required this.onClose,
    required this.currentTool,
    this.currentBrushId,
    this.currentBrushName,
    required this.currentSize,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              PanelCenterCloseBar(onClose: onClose),
              Row(
                children: [
                  Text(l10n.quickToolPanelTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                ],
              ),
              const Divider(),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(l10n.quickToolEmpty,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)))
                    : ReorderableListView.builder(
                        // ドラッグハンドルを明示アイコンとして置く（既定のまま
                        // だと行の長押しでしか並べ替えを開始できず、可視の
                        // 目印が無いままだった）。
                        buildDefaultDragHandles: false,
                        itemCount: entries.length,
                        onReorder: service.reorder,
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          return ListTile(
                            key: ValueKey(e.id),
                            dense: true,
                            leading: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                            title: Text(e.label, style: const TextStyle(fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                  tooltip: l10n.commonDelete,
                                  onPressed: () => service.removeEntry(e.id),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle, size: 18),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.commonAdd),
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
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 「現在のブラシを追加」：使用中のブラシ設定をそのまま登録（仕様書08）
            if (currentTool == DrawingTool.pen && currentBrushId != null)
              ListTile(
                leading: const Icon(Icons.bolt, color: Colors.amber),
                title: Text(l10n.quickToolAddCurrentBrush),
                subtitle: Text('$currentBrushName ${currentSize.round()}px'),
                onTap: () {
                  service.addEntry(QuickToolEntry(
                    id: 'qt_${DateTime.now().microsecondsSinceEpoch}',
                    label: '$currentBrushName ${currentSize.round()}px',
                    toolKey: 'pen',
                    brushId: currentBrushId,
                    sizeOverride: currentSize,
                  ));
                  Navigator.pop(ctx);
                },
              ),
            if (currentTool == DrawingTool.pen && currentBrushId != null) const Divider(height: 1),
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
              title: Text(l10n.quickToolEraser),
              onTap: () {
                _addSimple(service, 'eraser', l10n.quickToolEraser);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.colorize),
              title: Text(l10n.quickToolEyedropper),
              onTap: () {
                _addSimple(service, 'eyedropper', l10n.quickToolEyedropper);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_color_fill),
              title: Text(l10n.quickToolBucket),
              onTap: () {
                _addSimple(service, 'bucket', l10n.quickToolBucket);
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.quickToolSizeDialogTitle(brushName)),
          content: Row(
            children: [
              Expanded(
                child: SteppedSlider(
                  value: size.clamp(1, 200),
                  min: 1, max: 200,
                  label: '${size.round()}px',
                  onChanged: (v) => setS(() => size = v),
                ),
              ),
              SizedBox(
                width: 48,
                child: EditableSliderValue(
                  text: '${size.round()}px', textAlign: TextAlign.center,
                  value: size, min: 1, max: 200,
                  onChanged: (v) => setS(() => size = v.toDouble()),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
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
              child: Text(l10n.commonAdd),
            ),
          ],
        ),
      ),
    );
  }
}
