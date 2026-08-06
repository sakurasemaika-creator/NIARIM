import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/workspace_preset_service.dart';
import '../../widgets/responsive.dart';

class WorkspaceSettingsScreen extends StatelessWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final presetService = context.watch<WorkspacePresetService>();
    return Scaffold(
      appBar: AppBar(title: const Text('ワークスペース設定')),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(context, 'パネル配置'),
          Card(
            child: SwitchListTile(
              title: const Text('左利きモード'),
              subtitle: const Text('パネルを右側に配置'),
              value: settings.isLeftHanded,
              onChanged: (v) => settings.setLeftHanded(v),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'PCモード（DeX）'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('画面幅の広い環境ではプロ向けのドッキングUIへ自動で切り替わります。'
                '手動で固定したい場合はここで指定してください（仕様書02）。',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Card(
            child: Column(
              children: [
                RadioListTile<bool?>(
                  title: const Text('自動（画面幅で判定・推奨）'),
                  value: null,
                  groupValue: settings.forcePcMode,
                  onChanged: (v) => settings.setForcePcMode(v),
                ),
                RadioListTile<bool?>(
                  title: const Text('常にPCモード'),
                  value: true,
                  groupValue: settings.forcePcMode,
                  onChanged: (v) => settings.setForcePcMode(v),
                ),
                RadioListTile<bool?>(
                  title: const Text('常にスマホモード'),
                  value: false,
                  groupValue: settings.forcePcMode,
                  onChanged: (v) => settings.setForcePcMode(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'ワークスペース保存'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('左利きモード・PCモード設定を名前を付けて保存し、後から呼び出せます。',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          FilledButton.icon(
            onPressed: () => _showSaveDialog(context, settings, presetService),
            icon: const Icon(Icons.save),
            label: const Text('現在のワークスペースを保存'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: presetService.presets.isEmpty
                ? null
                : () => _showLoadSheet(context, settings, presetService),
            icon: const Icon(Icons.folder_open),
            label: Text(presetService.presets.isEmpty ? 'ワークスペースを読み込み（未保存）' : 'ワークスペースを読み込み'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      )),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  void _showSaveDialog(BuildContext context, SettingsService settings, WorkspacePresetService presetService) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ワークスペースを保存'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名前（例：アニメ用・線画用）', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              presetService.save(name, isLeftHanded: settings.isLeftHanded, forcePcMode: settings.forcePcMode);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showLoadSheet(BuildContext context, SettingsService settings, WorkspacePresetService presetService) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final preset in presetService.presets)
              ListTile(
                leading: const Icon(Icons.dashboard_customize),
                title: Text(preset.name),
                subtitle: Text(preset.isLeftHanded ? '左利き' : '右利き'),
                onTap: () {
                  settings.setLeftHanded(preset.isLeftHanded);
                  settings.setForcePcMode(preset.forcePcMode);
                  Navigator.pop(ctx);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => presetService.delete(preset.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
