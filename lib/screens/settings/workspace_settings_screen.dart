import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../widgets/responsive.dart';

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  State<WorkspaceSettingsScreen> createState() => _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  bool _isLeftHanded = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Scaffold(
      appBar: AppBar(title: const Text('ワークスペース設定')),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('パネル配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(title: const Text('左利きモード'), subtitle: const Text('パネルを右側に配置'), value: _isLeftHanded, onChanged: (v) => setState(() => _isLeftHanded = v)),
          const SizedBox(height: 8),
          const Text('PCモード（DeX）', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('画面幅の広い環境ではプロ向けのドッキングUIへ自動で切り替わります。'
              '手動で固定したい場合はここで指定してください（仕様書02）。',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
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
          const Divider(height: 32),
          const Text('ツールバー編集', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...[('Gペン', true), ('消しゴム', true), ('バケツ', true), ('スポイト', true), ('定規', false), ('テキスト', false), ('フィルター', false)]
              .map((t) => CheckboxListTile(title: Text(t.$1), value: t.$2, onChanged: (v) {}, dense: true)),
          const Divider(height: 32),
          const Text('ワークスペース保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.save), label: const Text('現在のワークスペースを保存')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.folder_open), label: const Text('ワークスペースを読み込み')),
        ],
      )),
    );
  }
}
