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

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final presets = themeService.presets;
    final current = themeService.current;

    return Scaffold(
      appBar: AppBar(title: const Text('テーマ・外観')),
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
          // プリセット一覧
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('テーマプリセット', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...presets.map((preset) => ListTile(
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
              ],
            ),
            onTap: () => themeService.applyPreset(preset.id),
          )),
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
