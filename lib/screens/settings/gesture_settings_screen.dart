import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../widgets/responsive.dart';

class GestureSettingsScreen extends StatelessWidget {
  const GestureSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(title: const Text('ジェスチャー設定')),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                _item(context, '2本指タップ', settings.twoFingerTap, (a) => settings.setGesture(GestureType.twoFingerTap, a)),
                const Divider(height: 1),
                _item(context, '3本指タップ', settings.threeFingerTap, (a) => settings.setGesture(GestureType.threeFingerTap, a)),
                const Divider(height: 1),
                _item(context, '2本指スワイプ左右', settings.twoFingerSwipe, (a) => settings.setGesture(GestureType.twoFingerSwipe, a)),
                const Divider(height: 1),
                _item(context, '長押し', settings.longPress, (a) => settings.setGesture(GestureType.longPress, a)),
              ],
            ),
          ),
        ],
      )),
    );
  }

  Widget _item(BuildContext context, String title, GestureAction current, ValueChanged<GestureAction> onChanged) {
    return ListTile(
      title: Text(title),
      trailing: Text(_label(current), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: GestureAction.values.map((action) => RadioListTile<GestureAction>(
              title: Text(_label(action)),
              value: action,
              groupValue: current,
              onChanged: (v) { if (v != null) onChanged(v); Navigator.pop(ctx); },
            )).toList(),
          ),
        ),
      ),
    );
  }

  String _label(GestureAction action) => switch (action) {
    GestureAction.undo => 'Undo',
    GestureAction.redo => 'Redo',
    GestureAction.eyedropper => 'スポイト',
    GestureAction.panTool => '手のひらツール',
    GestureAction.eraserToggle => '消しゴム切替',
    GestureAction.brushToggle => 'ブラシ切替',
    GestureAction.frameMove => 'フレーム移動',
    GestureAction.nextTool => 'ツール早替え',
    GestureAction.onionSkinToggle => 'オニオンスキンON/OFF',
    GestureAction.none => '何もしない',
  };
}
