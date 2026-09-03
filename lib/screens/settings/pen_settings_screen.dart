import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import 'widgets/pressure_curve_graph.dart';
import 'widgets/pressure_curve_try_draw.dart';
import '../../config/font_fallback.dart';

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
        title: Text(l10n.penSettingsTitle),
        actions: const [HelpButton(topic: 'ペン設定')],
      ),
      body: desktopCentered(
        context,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel(context, l10n.penSettingsCurveSection),
            Text(
              l10n.penSettingsCurveHint,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PenPressureCurve>(
              segments: [
                ButtonSegment(
                  value: PenPressureCurve.weak,
                  label: Text(l10n.penSettingsCurveWeak),
                ),
                ButtonSegment(
                  value: PenPressureCurve.normal,
                  label: Text(l10n.penSettingsCurveNormal),
                ),
                ButtonSegment(
                  value: PenPressureCurve.strong,
                  label: Text(l10n.penSettingsCurveStrong),
                ),
                ButtonSegment(
                  value: PenPressureCurve.custom,
                  label: Text(l10n.penSettingsCurveCustom),
                ),
              ],
              selected: {settings.penPressureCurve},
              onSelectionChanged: (v) => settings.setPenPressureCurve(v.first),
            ),
            if (settings.penPressureCurve == PenPressureCurve.custom) ...[
              const SizedBox(height: 8),
              Text(
                l10n.penSettingsCustomGraphHint,
                style: TextStyle(
                  fontSize: 11,
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
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const PressureCurveTryDraw(),
            SizedBox(height: 20),
            _sectionLabel(context, l10n.penSettingsButtonSection),
            Card(
              elevation: 1,
              shadowColor: ThemeService.activeColorScheme.shadow.withValues(alpha: 0.15),
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

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _actionLabel(context, current),
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
      GestureAction.undo => 'Undo',
      GestureAction.redo => 'Redo',
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
