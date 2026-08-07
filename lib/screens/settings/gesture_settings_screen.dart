import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';

class GestureSettingsScreen extends StatelessWidget {
  const GestureSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(title: const Text('ジェスチャー設定'), actions: const [HelpButton()]),
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
                // 2本指スワイプ左右のみ、連続動作前提の「フレーム移動」を選択肢に含める
                // （仕様書08：フレーム移動は2本指スワイプ専用の初期割り当て）。
                _item(context, '2本指スワイプ左右', settings.twoFingerSwipe, (a) => settings.setGesture(GestureType.twoFingerSwipe, a),
                    options: GestureAction.values),
                const Divider(height: 1),
                _item(context, '長押し', settings.longPress, (a) => settings.setGesture(GestureType.longPress, a)),
              ],
            ),
          ),
        ],
      )),
    );
  }

  // 「フレーム移動」は2本指スワイプのような連続操作前提の機能のため、
  // タップ・長押しのような単発トリガーへ割り当てても何も起こらない
  // （仕様書08：カスタマイズ可能な割り当て候補にフレーム移動は含まれない）。
  // 選べても無反応になるだけの死んだ選択肢を防ぐため、既定では除外する。
  static final List<GestureAction> _defaultOptions =
      GestureAction.values.where((a) => a != GestureAction.frameMove).toList();

  Widget _item(BuildContext context, String title, GestureAction current, ValueChanged<GestureAction> onChanged,
      {List<GestureAction>? options}) {
    final choices = options ?? _defaultOptions;
    return ListTile(
      title: Text(title),
      trailing: Text(_label(current), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: choices.map((action) => RadioListTile<GestureAction>(
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
