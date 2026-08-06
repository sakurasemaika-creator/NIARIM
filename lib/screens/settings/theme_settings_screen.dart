import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../models/app_theme_preset.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final presets = themeService.presets;
    final current = themeService.current;

    return Scaffold(
      appBar: AppBar(title: const Text('テーマ・外観')),
      body: ListView(
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
            leading: _PresetColorSwatch(preset: preset),
            title: Text(preset.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (current.id == preset.id)
                  const Icon(Icons.check, color: Colors.blue, size: 16),
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
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 32),
        ],
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
        // TODO: .mirathemeファイルとして書き出し
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('.miratheme書き出しは未実装です')),
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
    return SizedBox(
      width: 40,
      height: 40,
      child: Row(
        children: [
          Expanded(child: Container(color: preset.panelBgColor)),
          Expanded(child: Container(color: preset.accentColor)),
        ],
      ),
    );
  }
}
