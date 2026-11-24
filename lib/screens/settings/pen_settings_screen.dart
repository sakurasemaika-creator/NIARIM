import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../widgets/responsive.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/help_button.dart';
import 'widgets/pressure_curve_graph.dart';
import 'widgets/pressure_curve_try_draw.dart';
import 'widgets/settings_choice_sheet.dart';
import '../../widgets/grouped_sheet.dart';
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
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            GroupedSheet(
              children: [
                SwitchListTile(
                  title: Text(l10n.penSettingsPalmRejectionTitle),
                  subtitle: Text(
                    l10n.penSettingsPalmRejectionHint,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  value: settings.palmRejectionEnabled,
                  onChanged: settings.setPalmRejectionEnabled,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 筆圧カーブの節：選ぶ・形を見る・試し書きを1枚の面にまとめる
            // （以前は面の外に説明・グラフ・試し書きが並び、どこまでが筆圧
            // カーブの設定か分かりにくかった）。ブラシごとの設定の注意は面の下。
            GroupedSheet(
              title: l10n.penSettingsCurveSection,
              footer: l10n.penSettingsPerBrushNote,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _note(context, l10n.penSettingsCurveHint),
                      const SizedBox(height: 12),
                      _curveSelector(context, settings, l10n),
                      const SizedBox(height: 16),
                      // 選んでいるカーブの形をいつも同じ場所・同じ大きさで
                      // 見せる（弱・普通・強でも形が分かり、カスタムへ替えても
                      // 枠が動かない）。カスタムだけ点を足す・動かす・消せる。
                      Center(
                        child:
                            settings.penPressureCurve == PenPressureCurve.custom
                            ? PressureCurveGraph(
                                points: settings.customPressurePoints,
                                onAddPoint: (x, y) =>
                                    settings.addCustomPressurePoint(x, y),
                                onMovePoint: (i, x, y) =>
                                    settings.moveCustomPressurePoint(i, x, y),
                                onRemovePoint: (i) =>
                                    settings.removeCustomPressurePoint(i),
                              )
                            : PressureCurveGraph.preview(
                                points: [
                                  for (var i = 0; i <= 32; i++)
                                    (
                                      i / 32,
                                      settings.applyPressureCurve(i / 32),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: SizedBox(
                          width: 240,
                          child: messageText(
                            l10n.penSettingsGraphAxes,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      if (settings.penPressureCurve ==
                          PenPressureCurve.custom) ...[
                        const SizedBox(height: 12),
                        _note(context, l10n.penSettingsCustomGraphHint),
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton.icon(
                            icon: const Icon(Icons.restart_alt, size: 18),
                            label: Text(l10n.penSettingsResetCurveButton),
                            onPressed: () =>
                                settings.resetCustomPressureCurve(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: PressureCurveTryDraw(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GroupedSheet(
              title: l10n.penSettingsButtonSection,
              children: [
                _buttonItem(
                  context,
                  l10n.penSettingsButton1,
                  settings.penButton1,
                  (a) => settings.setPenButton(1, a),
                ),
                _buttonItem(
                  context,
                  l10n.penSettingsButton2,
                  settings.penButton2,
                  (a) => settings.setPenButton(2, a),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 節の説明（本文の書体・13px・薄い文字色）。
  Widget _note(BuildContext context, String text) => messageText(
    text,
    style: TextStyle(
      fontSize: 13,
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

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

  Widget _buttonItem(
    BuildContext context,
    String title,
    GestureAction current,
    ValueChanged<GestureAction> onChanged,
  ) {
    return SettingsValueTile(
      title: title,
      value: _actionLabel(context, current),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<GestureAction>(
          context: context,
          title: title,
          options: _penButtonActions,
          current: current,
          labelOf: _actionLabel,
        );
        if (selected != null) onChanged(selected);
      },
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
