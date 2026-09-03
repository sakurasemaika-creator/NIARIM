import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/stepped_slider.dart';
import '../../config/font_fallback.dart';

class GestureSettingsScreen extends StatelessWidget {
  const GestureSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gestureSettingsTitle),
        actions: const [HelpButton(topic: 'ジェスチャー設定')],
      ),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  _item(
                    context,
                    l10n.gestureTwoFingerTap,
                    settings.twoFingerTap,
                    (a) => settings.setGesture(GestureType.twoFingerTap, a),
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    l10n.gestureThreeFingerTap,
                    settings.threeFingerTap,
                    (a) => settings.setGesture(GestureType.threeFingerTap, a),
                  ),
                  const Divider(height: 1),
                  // 2本指スワイプ左右のみ、連続動作前提の「フレーム移動」を選択肢に含める。
                  _item(
                    context,
                    l10n.gestureTwoFingerSwipe,
                    settings.twoFingerSwipe,
                    (a) => settings.setGesture(GestureType.twoFingerSwipe, a),
                    options: GestureAction.values,
                  ),
                  const Divider(height: 1),
                  _item(
                    context,
                    l10n.gestureLongPress,
                    settings.longPress,
                    (a) => settings.setGesture(GestureType.longPress, a),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                l10n.gestureHoldEyedropperSection,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Card(
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.gestureHoldEyedropperTitle),
                    subtitle: Text(
                      l10n.gestureHoldEyedropperHint,
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: settings.holdEyedropperEnabled,
                    onChanged: (v) => settings.setHoldEyedropperEnabled(v),
                  ),
                  if (settings.holdEyedropperEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.gestureHoldEyedropperDurationLabel,
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: SteppedSlider(
                              value: settings.holdEyedropperSeconds,
                              min: 0.2,
                              max: 3.0,
                              divisions: 28,
                              step: 0.1,
                              onChanged: (v) =>
                                  settings.setHoldEyedropperSeconds(v),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: EditableSliderValue(
                              text: l10n.gestureHoldEyedropperSecondsValue(
                                settings.holdEyedropperSeconds.toStringAsFixed(
                                  1,
                                ),
                              ),
                              value: settings.holdEyedropperSeconds,
                              min: 0.2,
                              max: 3.0,
                              isInt: false,
                              title: l10n.gestureHoldEyedropperDurationLabel,
                              onChanged: (v) => settings
                                  .setHoldEyedropperSeconds(v.toDouble()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 「フレーム移動」は2本指スワイプのような連続操作前提の機能のため、
  // タップ・長押しのような単発トリガーへ割り当てても何も起こらない。
  // 選べても無反応になるだけの死んだ選択肢を防ぐため、既定では除外する。
  static final List<GestureAction> _defaultOptions = GestureAction.values
      .where((a) => a != GestureAction.frameMove)
      .toList();

  Widget _item(
    BuildContext context,
    String title,
    GestureAction current,
    ValueChanged<GestureAction> onChanged, {
    List<GestureAction>? options,
  }) {
    final choices = options ?? _defaultOptions;
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label(context, current),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          // 選択状態と変更通知はRadioGroupがまとめて持つ
          // （各ラジオのgroupValue/onChangedはFlutter 3.32で非推奨）。
          child: RadioGroup<GestureAction>(
            groupValue: current,
            onChanged: (v) {
              if (v != null) onChanged(v);
              Navigator.pop(ctx);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: choices
                  .map(
                    (action) => RadioListTile<GestureAction>(
                      title: Text(_label(ctx, action)),
                      value: action,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _label(BuildContext context, GestureAction action) {
    final l10n = AppLocalizations.of(context)!;
    return switch (action) {
      GestureAction.undo => 'Undo',
      GestureAction.redo => 'Redo',
      GestureAction.eyedropper => l10n.gestureActionEyedropper,
      GestureAction.panTool => l10n.gestureActionPanTool,
      GestureAction.eraserToggle => l10n.gestureActionEraserToggle,
      GestureAction.brushToggle => l10n.gestureActionBrushToggle,
      GestureAction.frameMove => l10n.gestureActionFrameMove,
      GestureAction.nextTool => l10n.gestureActionNextTool,
      GestureAction.onionSkinToggle => l10n.gestureActionOnionSkinToggle,
      GestureAction.none => l10n.gestureActionNone,
    };
  }
}
