import 'package:flutter/material.dart';

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  State<WorkspaceSettingsScreen> createState() => _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  bool _isLeftHanded = false;
  bool _isPcMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ワークスペース設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('パネル配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(title: const Text('左利きモード'), subtitle: const Text('パネルを右側に配置'), value: _isLeftHanded, onChanged: (v) => setState(() => _isLeftHanded = v)),
          SwitchListTile(title: const Text('PCモード（DeX）'), subtitle: const Text('デスクトップUIレイアウト'), value: _isPcMode, onChanged: (v) => setState(() => _isPcMode = v)),
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
      ),
    );
  }
}
