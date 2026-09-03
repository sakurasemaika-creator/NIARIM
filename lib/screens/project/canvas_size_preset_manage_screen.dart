import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/canvas_size_preset.dart';
import '../../services/settings_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../config/font_fallback.dart';
import '../../utils/reorder_index.dart';

/// 保存済みカスタムキャンバスサイズプリセットの一覧管理画面。
/// ドラッグでの並べ替え・編集・複製・名前変更・削除ができる。
class CanvasSizePresetManageScreen extends StatelessWidget {
  const CanvasSizePresetManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final presets = settings.customSizePresets;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.canvasSizePresetManageScreenTitle)),
      body: SafeArea(
        child: presets.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.aspect_ratio,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.canvasSizePresetEmpty,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.canvasSizePresetEmptyHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ReorderableListView.builder(
                // 他の並べ替え可能な一覧と操作方法を揃えるため、既定の
                // ドラッグハンドル（行全体の長押し）は無効化し、行末の
                // ハンドルアイコンでのみ並べ替えを開始できるようにする。
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.all(12),
                itemCount: presets.length,
                onReorderItem: (oldIndex, newIndex) =>
                    settings.reorderCustomSizePresets(
                      oldIndex,
                      preRemovalIndex(oldIndex, newIndex),
                    ),
                itemBuilder: (context, index) => _PresetTile(
                  key: ValueKey(presets[index].id),
                  preset: presets[index],
                  dragIndex: index,
                ),
              ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final CanvasSizePreset preset;
  final int dragIndex;

  const _PresetTile({super.key, required this.preset, required this.dragIndex});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsService>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.aspect_ratio),
        title: Text(
          preset.name,
          style: const TextStyle(
            fontFamily: 'Kuramubon',
            fontFamilyFallback: kHeadingFontFallback,
          ),
        ),
        subtitle: Text('${preset.width}×${preset.height}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _showEditDialog(context, settings, preset);
                  case 'rename':
                    _showRenameDialog(context, settings, preset);
                  case 'duplicate':
                    settings.duplicateCustomSizePreset(
                      preset.id,
                      '${preset.name}${l10n.canvasSizePresetDuplicateSuffix}',
                    );
                  case 'delete':
                    _confirmDelete(context, settings, preset);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(l10n.canvasSizePresetEditDialogTitle),
                ),
                PopupMenuItem(value: 'rename', child: Text(l10n.commonRename)),
                PopupMenuItem(value: 'duplicate', child: Text(l10n.commonCopy)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    l10n.commonDelete,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
            ReorderableDragStartListener(
              index: dragIndex,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    SettingsService settings,
    CanvasSizePreset preset,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.commonRename),
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
                settings.updateCustomSizePreset(preset.id, name: nameCtrl.text);
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

  void _showEditDialog(
    BuildContext context,
    SettingsService settings,
    CanvasSizePreset preset,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final widthCtrl = TextEditingController(text: '${preset.width}');
    final heightCtrl = TextEditingController(text: '${preset.height}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.canvasSizePresetEditDialogTitle),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widthCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.newProjectWidthLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: heightCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.newProjectHeightLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final w = int.tryParse(widthCtrl.text);
              final h = int.tryParse(heightCtrl.text);
              if (w != null && h != null && w > 0 && h > 0) {
                settings.updateCustomSizePreset(preset.id, width: w, height: h);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.commonChange),
          ),
        ],
      ),
    ).then(
      (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        widthCtrl.dispose();
        heightCtrl.dispose();
      }),
    );
  }

  void _confirmDelete(
    BuildContext context,
    SettingsService settings,
    CanvasSizePreset preset,
  ) async {
    if (!await confirmDelete(context, itemName: preset.name)) return;
    settings.removeCustomSizePreset(preset.id);
  }
}
