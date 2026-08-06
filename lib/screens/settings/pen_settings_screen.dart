import 'package:flutter/material.dart';
import '../../widgets/responsive.dart';

class PenSettingsScreen extends StatefulWidget {
  const PenSettingsScreen({super.key});

  @override
  State<PenSettingsScreen> createState() => _PenSettingsScreenState();
}

class _PenSettingsScreenState extends State<PenSettingsScreen> {
  int _pressureMode = 1;
  int _pressureCurve = 1;
  String _penButton1 = 'eraser';
  String _penButton2 = 'eyedropper';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ペン入力設定')),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('筆圧設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RadioListTile<int>(title: const Text('無効'), value: 0, groupValue: _pressureMode, onChanged: (v) => setState(() => _pressureMode = v!)),
          RadioListTile<int>(title: const Text('サイズに反映'), value: 1, groupValue: _pressureMode, onChanged: (v) => setState(() => _pressureMode = v!)),
          RadioListTile<int>(title: const Text('不透明度に反映'), value: 2, groupValue: _pressureMode, onChanged: (v) => setState(() => _pressureMode = v!)),
          RadioListTile<int>(title: const Text('サイズ＋不透明度に反映'), value: 3, groupValue: _pressureMode, onChanged: (v) => setState(() => _pressureMode = v!)),
          const Divider(height: 32),
          const Text('筆圧カーブ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('弱')),
              ButtonSegment(value: 1, label: Text('普通')),
              ButtonSegment(value: 2, label: Text('強')),
              ButtonSegment(value: 3, label: Text('カスタム')),
            ],
            selected: {_pressureCurve},
            onSelectionChanged: (v) => setState(() => _pressureCurve = v.first),
          ),
          const Divider(height: 32),
          const Text('ペンボタン設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(title: const Text('ボタン1'), trailing: Text(_buttonLabel(_penButton1)), onTap: () => _showButtonPicker(1)),
          ListTile(title: const Text('ボタン2'), trailing: Text(_buttonLabel(_penButton2)), onTap: () => _showButtonPicker(2)),
        ],
      )),
    );
  }

  String _buttonLabel(String action) => switch (action) {
    'eraser' => '消しゴム切替', 'eyedropper' => 'スポイト', 'undo' => 'Undo',
    'redo' => 'Redo', 'next_tool' => 'ツール早替え', 'none' => 'なし', _ => action,
  };

  void _showButtonPicker(int buttonNumber) {
    final actions = ['eraser', 'eyedropper', 'undo', 'redo', 'next_tool', 'none'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions.map((action) => ListTile(
            title: Text(_buttonLabel(action)),
            onTap: () {
              setState(() { if (buttonNumber == 1) _penButton1 = action; else _penButton2 = action; });
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
  }
}
