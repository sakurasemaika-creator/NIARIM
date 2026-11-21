import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../widgets/help_button.dart';
import 'widgets/pressure_curve_graph.dart';
import 'widgets/pressure_curve_try_draw.dart';
import '../../config/font_fallback.dart';
import 'widgets/settings_value_tile.dart';
import '../../widgets/fit_or_hide_title.dart';

/// ペン入力設定。
/// 筆圧の「無効／サイズ／不透明度／両方」反映モードはブラシ個別設定のため、
/// ブラシ設定パネル側で管理する（ここでは扱わない）。
/// このため、この画面では「筆圧カーブ（アプリ全体に適用）」と「ペンボタン設定」を扱う。
class PenSettingsScreen extends StatelessWidget {
  const PenSettingsScreen({super.key});

  // ペンボタンに割り当て可能なアクション（消しゴム切替・スポイト・
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // topicはヘルプ画面側の項目タイトル（日本語固定）と一致させるための
      // 内部検索キーであり、UI表示文字列ではないため翻訳しない。
      appBar: AppBar(
        title: FitOrHideTitle(l10n.penSettingsTitle),
        actions: const [HelpButton(topic: 'ペン設定')],
      ),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                alpha: 0.15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SwitchListTile(
                title: Text(l10n.penSettingsPalmRejectionTitle),
                subtitle: Text(
                  l10n.penSettingsPalmRejectionHint,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                value: settings.palmRejectionEnabled,
                onChanged: settings.setPalmRejectionEnabled,
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, l10n.penSettingsCurveSection),
            Text(
              l10n.penSettingsCurveHint,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _curveSelector(context, settings, l10n),
            if (settings.penPressureCurve == PenPressureCurve.custom) ...[
              const SizedBox(height: 8),
              Text(
                l10n.penSettingsCustomGraphHint,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: PressureCurveGraph(
                  points: settings.customPressurePoints,
                  onAddPoint: (x, y) => settings.addCustomPressurePoint(x, y),
                  onMovePoint: (i, x, y) =>
                      settings.moveCustomPressurePoint(i, x, y),
                  onRemovePoint: (i) => settings.removeCustomPressurePoint(i),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: Text(l10n.penSettingsResetCurveButton),
                  onPressed: () => settings.resetCustomPressureCurve(),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              l10n.penSettingsPerBrushNote,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const PressureCurveTryDraw(),
            SizedBox(height: 20),
            _sectionLabel(context, l10n.penSettingsButtonSection),
            Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(
                alpha: 0.15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  _buttonItem(
                    context,
                    l10n.penSettingsButton1,
                    settings.penButton1,
                    (a) => settings.setPenButton(1, a),
                  ),
                  const Divider(height: 1),
                  _buttonItem(
                    context,
                    l10n.penSettingsButton2,
                    settings.penButton2,
                    (a) => settings.setPenButton(2, a),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _curveSelector(
    BuildContext context,
    SettingsService settings,
    AppLocalizations l10n,
  ) {
    final labels = {
      PenPressureCurve.weak: l10n.penSettingsCurveWeak,
      PenPressureCurve.normal: l10n.penSettingsCurveNormal,
      PenPressureCurve.strong: l10n.penSettingsCurveStrong,
      PenPressureCurve.custom: l10n.penSettingsCurveCustom,
    };
    final theme = Theme.of(context);
    final style =
        theme.segmentedButtonTheme.style?.textStyle?.resolve({}) ??
        theme.textTheme.labelLarge;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
      maxLines: 1,
    );
    var widest = 0.0;
    for (final label in labels.values) {
      painter
        ..text = TextSpan(text: label, style: style)
        ..layout();
      if (painter.width > widest) widest = painter.width;
    }
    painter.dispose();

    const horizontalPadding = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // All horizontal segments have the same width. Fit the widest
        // translated label with equal padding on both sides of every segment.
        final fits =
            (widest.ceil() + 2 * horizontalPadding) * labels.length <=
            constraints.maxWidth;
        return SegmentedButton<PenPressureCurve>(
          direction: fits ? Axis.horizontal : Axis.vertical,
          showSelectedIcon: !fits,
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(fits ? 24 : 16),
            ),
          ),
          segments: [
            for (final entry in labels.entries)
              ButtonSegment(value: entry.key, label: Text(entry.value)),
          ],
          selected: {settings.penPressureCurve},
          onSelectionChanged: (values) =>
              settings.setPenPressureCurve(values.single),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: localizedHeadingStyle(
          context,
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buttonItem(
    BuildContext context,
    String title,
    GestureAction current,
    ValueChanged<GestureAction> onChanged,
  ) {
    return SettingsValueTile(
      title: title,
      value: _actionLabel(context, current),
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => ScrollableSheetBody(
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
              children: _penButtonActions
                  .map(
                    (action) => RadioListTile<GestureAction>(
                      title: Text(_actionLabel(ctx, action)),
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

  String _actionLabel(BuildContext context, GestureAction action) {
    final l10n = AppLocalizations.of(context)!;
    return switch (action) {
      // 訳文を使う。ここだけ英語のままだと、日本語UIの一覧に
      // 「Undo」「Redo」だけ英語で並ぶ
      // （build/all-route-screenshots/16_settings_gestures.png で発覚）。
      GestureAction.undo => l10n.gestureActionUndo,
      GestureAction.redo => l10n.gestureActionRedo,
      GestureAction.eyedropper => l10n.gestureActionEyedropper,
      GestureAction.eraserToggle => l10n.gestureActionEraserToggle,
      GestureAction.nextTool => l10n.gestureActionNextTool,
      GestureAction.none => l10n.gestureActionNoneShort,
      GestureAction.panTool => l10n.gestureActionPanTool,
      GestureAction.brushToggle => l10n.gestureActionBrushToggle,
      GestureAction.frameMove => l10n.gestureActionFrameMove,
      GestureAction.onionSkinToggle => l10n.gestureActionOnionSkinToggle,
    };
  }
}
