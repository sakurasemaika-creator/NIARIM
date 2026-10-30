import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/canvas_size_preset.dart';
import '../../services/settings_service.dart';
import '../../widgets/confirm_delete.dart';
import '../../config/font_fallback.dart';
import '../../utils/duplicate_name.dart';
import '../../utils/reorder_index.dart';
import '../../widgets/name_entry_dialog.dart';
import '../../config/accent_text_theme.dart';

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
                          color: AccentTextTheme.of(context),
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
                    // 名前は作品・フォルダの複製と同じ「(コピー)」「(コピー 2)」…
                    settings.duplicateCustomSizePreset(
                      preset.id,
                      numberedCopyName(l10n, preset.name, {
                        for (final p in settings.customSizePresets) p.name,
                      }),
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
                    style: TextStyle(
                      color: ThemeService.activeColorScheme.error,
                    ),
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
    showDialog(
      context: context,
      builder: (_) => NameEntryDialog(
        title: l10n.commonRename,
        labelText: l10n.newProjectSaveCustomSizeNameLabel,
        initialName: preset.name,
        confirmLabel: l10n.commonChange,
        cancelLabel: l10n.commonCancel,
        onSubmit: (name) =>
            settings.updateCustomSizePreset(preset.id, name: name),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    SettingsService settings,
    CanvasSizePreset preset,
  ) {
    showDialog(
      context: context,
      builder: (_) => _PresetSizeDialog(preset: preset, settings: settings),
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

/// 保存したサイズの幅・高さを変えるダイアログ。範囲外・空の欄があれば理由を
/// 出して保存できない（以前は5000×5000のような上限を超えるサイズも保存でき、
/// そのサイズで作品を作れた）。入力欄のコントローラーはこのダイアログが持ち、
/// 閉じ終えてから破棄する。
class _PresetSizeDialog extends StatefulWidget {
  final CanvasSizePreset preset;
  final SettingsService settings;

  const _PresetSizeDialog({required this.preset, required this.settings});

  @override
  State<_PresetSizeDialog> createState() => _PresetSizeDialogState();
}

class _PresetSizeDialogState extends State<_PresetSizeDialog> {
  late final _width = TextEditingController(text: '${widget.preset.width}');
  late final _height = TextEditingController(text: '${widget.preset.height}');

  static final _numberInput = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  int? _valueOf(TextEditingController controller) {
    final value = int.tryParse(controller.text);
    if (value == null || value < kMinCanvasEdge || value > kMaxCanvasEdge) {
      return null;
    }
    return value;
  }

  bool get _valid => _valueOf(_width) != null && _valueOf(_height) != null;

  void _save() {
    // 閉じる途中にもう一度押されても二度保存しない。
    if (!_valid || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    widget.settings.updateCustomSizePreset(
      widget.preset.id,
      width: _valueOf(_width),
      height: _valueOf(_height),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = l10n.newProjectNumberRangeError(
      kMinCanvasEdge,
      kMaxCanvasEdge,
    );
    InputDecoration decoration(String label, TextEditingController c) =>
        InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: _valueOf(c) == null ? error : null,
          errorMaxLines: 3,
        );
    return AlertDialog(
      title: Text(l10n.canvasSizePresetEditDialogTitle),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: const Key('presetWidthField'),
              controller: _width,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: _numberInput,
              textInputAction: TextInputAction.next,
              decoration: decoration(l10n.newProjectWidthLabel, _width),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('presetHeightField'),
              controller: _height,
              keyboardType: TextInputType.number,
              inputFormatters: _numberInput,
              textInputAction: TextInputAction.done,
              decoration: decoration(l10n.newProjectHeightLabel, _height),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.commonCancel,
            style: TextStyle(shadows: cancelLabelShadows(context)),
          ),
        ),
        FilledButton(
          onPressed: _valid ? _save : null,
          child: Text(l10n.commonChange),
        ),
      ],
    );
  }
}
