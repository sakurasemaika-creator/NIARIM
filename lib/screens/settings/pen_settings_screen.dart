import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import 'widgets/pressure_curve_graph.dart';
import 'widgets/pressure_curve_try_draw.dart';

/// ペン入力設定（仕様書08）。
/// 筆圧の「無効／サイズ／不透明度／両方」反映モードは仕様書17により
/// ブラシ個別設定のため、ブラシ設定パネル側で管理する（ここでは扱わない）。
/// このため、この画面では「筆圧カーブ（アプリ全体に適用）」と「ペンボタン設定」を扱う。
class PenSettingsScreen extends StatelessWidget {
  const PenSettingsScreen({super.key});

  // ペンボタンに割り当て可能なアクション（仕様書08：消しゴム切替・スポイト・
  // Undo・Redo・ツール早替え・なし）。ジェスチャー設定の全アクションとは異なる
  // 限定リストであることに注意。
  static const _penButtonActions = [
    GestureAction.eraserToggle,
    GestureAction.eyedropper,
    GestureAction.undo,
    GestureAction.redo,
    GestureAction.nextTool,
    GestureAction.none,
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(title: const Text('ペン入力設定'), actions: const [HelpButton(topic: '筆圧カーブ')]),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(context, '筆圧カーブ（アプリ全体に適用）'),
          Text('弱い設定ほど筆圧の立ち上がりが緩やかに、強い設定ほど鋭くなります。',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          SegmentedButton<PenPressureCurve>(
            segments: const [
              ButtonSegment(value: PenPressureCurve.weak, label: Text('弱')),
              ButtonSegment(value: PenPressureCurve.normal, label: Text('普通')),
              ButtonSegment(value: PenPressureCurve.strong, label: Text('強')),
              ButtonSegment(value: PenPressureCurve.custom, label: Text('カスタム')),
            ],
            selected: {settings.penPressureCurve},
            onSelectionChanged: (v) => settings.setPenPressureCurve(v.first),
          ),
          if (settings.penPressureCurve == PenPressureCurve.custom) ...[
            const SizedBox(height: 8),
            Text('グラフの点を上下にドラッグして、筆圧に対する反映度合いの曲線を調整できます。',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Center(
              child: PressureCurveGraph(
                exponent: settings.customPressureExponent,
                onExponentChanged: (v) => settings.setCustomPressureExponent(v),
              ),
            ),
            const SizedBox(height: 4),
            Center(child: Text('指数: ${settings.customPressureExponent.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11))),
          ],
          const SizedBox(height: 4),
          Text('※ 筆圧の「サイズ／不透明度に反映」設定はブラシごとの個別設定です（ブラシ設定パネルで変更）。',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          const PressureCurveTryDraw(),
          const SizedBox(height: 20),
          _sectionLabel(context, 'ペンボタン設定'),
          Card(
            child: Column(
              children: [
                _buttonItem(context, 'ボタン1', settings.penButton1, (a) => settings.setPenButton(1, a)),
                const Divider(height: 1),
                _buttonItem(context, 'ボタン2', settings.penButton2, (a) => settings.setPenButton(2, a)),
              ],
            ),
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

  Widget _buttonItem(BuildContext context, String title, GestureAction current, ValueChanged<GestureAction> onChanged) {
    return ListTile(
      title: Text(title),
      trailing: Text(_actionLabel(current), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _penButtonActions.map((action) => RadioListTile<GestureAction>(
              title: Text(_actionLabel(action)),
              value: action,
              groupValue: current,
              onChanged: (v) { if (v != null) onChanged(v); Navigator.pop(ctx); },
            )).toList(),
          ),
        ),
      ),
    );
  }

  String _actionLabel(GestureAction action) => switch (action) {
    GestureAction.undo => 'Undo',
    GestureAction.redo => 'Redo',
    GestureAction.eyedropper => 'スポイト',
    GestureAction.eraserToggle => '消しゴム切替',
    GestureAction.nextTool => 'ツール早替え',
    GestureAction.none => 'なし',
    GestureAction.panTool => '手のひらツール',
    GestureAction.brushToggle => 'ブラシ切替',
    GestureAction.frameMove => 'フレーム移動',
    GestureAction.onionSkinToggle => 'オニオンスキンON/OFF',
  };
}
