import 'package:flutter/material.dart';

import '../../widgets/icon_notice.dart';

import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../widgets/labeled_slider.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import 'widgets/settings_choice_sheet.dart';
import '../../widgets/grouped_sheet.dart';
import 'widgets/settings_value_tile.dart';
import '../../widgets/fit_or_hide_title.dart';

class GestureSettingsScreen extends StatelessWidget {
  const GestureSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final usesHoldEyedropper = settings.longPress == GestureAction.eyedropper;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: FitOrHideTitle(l10n.gestureSettingsTitle),
        actions: const [HelpButton(topic: 'ジェスチャー設定')],
      ),
      body: desktopCentered(
        context,
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            GroupedSheet(
              title: l10n.gestureTouchSection,
              children: [
                _item(
                  context,
                  l10n.gestureTwoFingerTap,
                  settings.twoFingerTap,
                  (a) => settings.setGesture(GestureType.twoFingerTap, a),
                ),
                _item(
                  context,
                  l10n.gestureThreeFingerTap,
                  settings.threeFingerTap,
                  (a) => settings.setGesture(GestureType.threeFingerTap, a),
                ),
                _item(
                  context,
                  l10n.gestureFourOrMoreFingerTap,
                  settings.fourOrMoreFingerTap,
                  (a) =>
                      settings.setGesture(GestureType.fourOrMoreFingerTap, a),
                ),
                // 2本指スワイプ左右のみ、連続動作前提の「フレーム移動」を選択肢に含める。
                _item(
                  context,
                  l10n.gestureTwoFingerSwipe,
                  settings.twoFingerSwipe,
                  (a) => settings.setGesture(GestureType.twoFingerSwipe, a),
                  options: GestureAction.values,
                ),
                _item(
                  context,
                  l10n.gestureLongPress,
                  settings.longPress,
                  (a) => settings.setGesture(GestureType.longPress, a),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GroupedSheet(
              title: l10n.gestureHoldEyedropperSection,
              children: [
                SwitchListTile(
                  title: Text(l10n.gestureHoldEyedropperTitle),
                  subtitle: Text(
                    l10n.gestureHoldEyedropperHint,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  value: settings.holdEyedropperEnabled,
                  onChanged: usesHoldEyedropper
                      ? settings.setHoldEyedropperEnabled
                      : null,
                ),
                // 長押しの割り当てがスポイトでないと、このスイッチは押せない。
                // 押せない理由と、その場で長押しをスポイトにする道を出す
                // （以前は灰色のスイッチだけで、なぜ押せないか分からなかった）。
                if (!usesHoldEyedropper)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          child: IconNotice(
                            l10n.gestureHoldEyedropperNeedsLongPress,
                            icon: Icons.info_outline,
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () => settings.setGesture(
                              GestureType.longPress,
                              GestureAction.eyedropper,
                            ),
                            child: Text(l10n.gestureHoldEyedropperUseLongPress),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (settings.holdEyedropperEnabled)
                  LabeledSlider(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    label: l10n.gestureHoldEyedropperDurationLabel,
                    value: settings.holdEyedropperSeconds,
                    min: 0.2,
                    max: 3.0,
                    divisions: 28,
                    step: 0.1,
                    isInt: false,
                    valueText: l10n.gestureHoldEyedropperSecondsValue(
                      settings.holdEyedropperSeconds.toStringAsFixed(1),
                    ),
                    onChanged: usesHoldEyedropper
                        ? settings.setHoldEyedropperSeconds
                        : null,
                  ),
              ],
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
    return SettingsValueTile(
      title: title,
      value: _label(context, current),
      onTap: () async {
        // 選択肢は既定で9件あり、シートの中でスクロールできる
        // （`ScrollableSheetBody`のdoc参照）。
        final selected = await showSettingsChoiceSheet<GestureAction>(
          context: context,
          title: title,
          options: choices,
          current: current,
          labelOf: _label,
        );
        if (selected != null) onChanged(selected);
      },
    );
  }

  String _label(BuildContext context, GestureAction action) {
    final l10n = AppLocalizations.of(context)!;
    return switch (action) {
      // 訳文を使う。ここだけ英語のままだと、日本語UIの一覧に
      // 「Undo」「Redo」だけ英語で並ぶ
      // （build/all-route-screenshots/16_settings_gestures.png で発覚）。
      GestureAction.undo => l10n.gestureActionUndo,
      GestureAction.redo => l10n.gestureActionRedo,
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
