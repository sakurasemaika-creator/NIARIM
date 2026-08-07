import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/theme_service.dart';
import '../../models/app_theme_preset.dart';
import '../../widgets/responsive.dart';
import '../canvas/widgets/color_picker_panel.dart';
import '../../widgets/help_button.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final presets = themeService.presets;
    final current = themeService.current;

    return Scaffold(
      appBar: AppBar(title: const Text('テーマ・外観'), actions: const [HelpButton()]),
      body: desktopCentered(context, ListView(
        children: [
          // ベーステーマ
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('ベーステーマ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...BaseTheme.values.map((theme) => RadioListTile<BaseTheme>(
            title: Text(_baseThemeLabel(theme)),
            value: theme,
            groupValue: current.baseTheme,
            onChanged: (v) {
              if (v != null) {
                final updated = current.copyWith(baseTheme: v);
                themeService.savePreset(updated);
                themeService.applyPreset(updated.id);
              }
            },
            dense: true,
          )),
          const Divider(),
          // カラーカスタマイズ（仕様書24：「すべてカラーピッカー（HSV/RGB/HEX）で
          // 自由に設定できる」）。変更は即座にアプリ全体（現在のプリセット）へ
          // 反映される。
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('カラーカスタマイズ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _ColorCustomizeTile(
            label: 'アクセントカラー',
            color: current.accentColor,
            onTap: () => _showColorPickerDialog(
                context, themeService, (p, c) => p.copyWith(accentColor: c), current.accentColor),
          ),
          _ColorCustomizeTile(
            label: '文字色',
            color: current.textColor,
            onTap: () => _showColorPickerDialog(
                context, themeService, (p, c) => p.copyWith(textColor: c), current.textColor),
          ),
          _ColorCustomizeTile(
            label: 'パネル背景色',
            color: current.panelBgColor,
            onTap: () => _showColorPickerDialog(
                context, themeService, (p, c) => p.copyWith(panelBgColor: c), current.panelBgColor),
          ),
          _ColorCustomizeTile(
            label: 'メニュー背景色',
            color: current.menuBgColor,
            onTap: () => _showColorPickerDialog(
                context, themeService, (p, c) => p.copyWith(menuBgColor: c), current.menuBgColor),
          ),
          _ColorCustomizeTile(
            label: '選択色',
            color: current.selectionColor,
            onTap: () => _showColorPickerDialog(
                context, themeService, (p, c) => p.copyWith(selectionColor: c), current.selectionColor),
          ),
          _ColorCustomizeTile(
            label: '更新マーク色',
            color: current.updateMarkColor,
            onTap: () => _showColorPickerDialog(
                context, themeService, (p, c) => p.copyWith(updateMarkColor: c), current.updateMarkColor),
          ),
          const Divider(),
          // プリセット一覧（ドラッグで並び替え可能、仕様書24）
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('テーマプリセット', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: themeService.reorder,
            children: [
              for (final preset in presets)
                ListTile(
                  key: ValueKey(preset.id),
                  tileColor: current.id == preset.id
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : null,
                  leading: _PresetColorSwatch(preset: preset),
                  title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (current.id == preset.id)
                        Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 16),
                      IconButton(
                        icon: Icon(
                          preset.isFavorite ? Icons.star : Icons.star_outline,
                          size: 16,
                          color: preset.isFavorite ? Colors.amber : null,
                        ),
                        onPressed: () => themeService.toggleFavorite(preset.id),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 16),
                        onSelected: (action) => _handleAction(context, action, preset, themeService),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'rename', child: Text('名前変更')),
                          const PopupMenuItem(value: 'duplicate', child: Text('複製')),
                          const PopupMenuItem(value: 'export', child: Text('書き出し (.miratheme)')),
                          const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                      const Icon(Icons.drag_handle, size: 18),
                    ],
                  ),
                  onTap: () => themeService.applyPreset(preset.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('現在の設定を新しいプリセットとして保存'),
              onPressed: () => _saveCurrentAsNew(context, themeService),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: const Text('.mirathemeを読み込む'),
              onPressed: () => _importTheme(context, themeService),
            ),
          ),
          const SizedBox(height: 32),
        ],
      )),
    );
  }

  /// カラーピッカーダイアログを表示する（仕様書24：カラーカスタマイズ）。
  /// ドラッグ中は`ThemeService.previewCurrent()`でアプリ全体へ即時反映し
  /// （見た目確認用、未保存）、ダイアログを閉じた時点で確定保存する。
  void _showColorPickerDialog(
    BuildContext context,
    ThemeService service,
    AppThemePreset Function(AppThemePreset preset, Color color) update,
    Color initialColor,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ColorPickerPanel(
          currentColor: initialColor,
          onColorChanged: (c) => service.previewCurrent(update(service.current, c)),
          onClose: () {
            service.commitCurrent();
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  String _baseThemeLabel(BaseTheme theme) => switch (theme) {
    BaseTheme.light => 'ライト',
    BaseTheme.dark => 'ダーク',
    BaseTheme.system => 'システム設定に合わせる',
  };

  void _handleAction(BuildContext context, String action, AppThemePreset preset, ThemeService service) {
    switch (action) {
      case 'rename':
        _showRenameDialog(context, preset, service);
      case 'duplicate':
        final copy = preset.copyWith(
          id: 'theme_${DateTime.now().millisecondsSinceEpoch}',
          name: '${preset.name} (コピー)',
        );
        service.savePreset(copy);
      case 'delete':
        service.deletePreset(preset.id);
      case 'export':
        _exportTheme(context, preset);
    }
  }

  Future<void> _exportTheme(BuildContext context, AppThemePreset preset) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = preset.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName.miratheme');
      await file.writeAsString(jsonEncode(preset.toJson()));
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('書き出しに失敗しました: $e')),
      );
    }
  }

  Future<void> _importTheme(BuildContext context, ThemeService service) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['miratheme'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    if (!context.mounted) return;
    try {
      final content = await File(result.files.first.path!).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final preset = AppThemePreset.fromJson(json)
          .copyWith(id: 'theme_${DateTime.now().millisecondsSinceEpoch}');
      service.savePreset(preset);
      service.applyPreset(preset.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('.mirathemeを読み込みました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('読み込みに失敗しました: $e')),
      );
    }
  }

  void _showRenameDialog(BuildContext context, AppThemePreset preset, ThemeService service) {
    final controller = TextEditingController(text: preset.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('名前変更'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              service.savePreset(preset.copyWith(name: controller.text));
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _saveCurrentAsNew(BuildContext context, ThemeService service) {
    final controller = TextEditingController(text: 'マイテーマ');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プリセット名'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              final newPreset = service.current.copyWith(
                id: 'theme_${DateTime.now().millisecondsSinceEpoch}',
                name: controller.text,
              );
              service.savePreset(newPreset);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

/// カラーカスタマイズ項目1件（仕様書24）：色見本＋ラベル＋タップでカラー
/// ピッカーを開く。
class _ColorCustomizeTile extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorCustomizeTile({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}

class _PresetColorSwatch extends StatelessWidget {
  final AppThemePreset preset;
  const _PresetColorSwatch({required this.preset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Row(
        children: [
          Expanded(child: Container(color: preset.panelBgColor)),
          Expanded(child: Container(color: preset.accentColor)),
        ],
      ),
    );
  }
}
