import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/stepped_slider.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/grouped_sheet.dart';
import '../../widgets/fit_or_hide_title.dart';

/// バケツ塗り詳細設定（許容誤差・拡張px・線の下まで潜る）。
/// ここでの設定はバケツツール使用時に常に適用される（プロジェクト単位では
/// なく端末単位の設定）。
class BucketFillSettingsScreen extends StatelessWidget {
  const BucketFillSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // topicはヘルプ画面側の項目タイトル（日本語固定）と一致させるための
      // 内部検索キーであり、UI表示文字列ではないため翻訳しない。
      appBar: AppBar(
        title: FitOrHideTitle(l10n.bucketSettingsTitle),
        actions: const [HelpButton(topic: 'バケツ塗り詳細設定')],
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
            // 項目ごとに欄へ収める（ほかの設定の画面と同じ欄）。「線の下まで
            // 潜る」は拡張の幅を使う設定なので、拡張と同じ欄に置く。
            GroupedSheet(
              children: [
                _sliderBlock(
                  context,
                  title: l10n.bucketSettingsToleranceSection,
                  hint: l10n.bucketSettingsToleranceHint,
                  value: EditableSliderValue(
                    text: '${settings.bucketTolerance.round()} / 100',
                    value: settings.bucketTolerance,
                    min: 0,
                    max: 100,
                    title: l10n.bucketSettingsToleranceSection,
                    onChanged: (v) => settings.setBucketTolerance(v.toDouble()),
                  ),
                  slider: SteppedSlider(
                    value: settings.bucketTolerance,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    compact: true,
                    onChanged: (v) => settings.setBucketTolerance(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GroupedSheet(
              children: [
                _sliderBlock(
                  context,
                  title: l10n.bucketSettingsExpandSection,
                  hint: l10n.bucketSettingsExpandHint,
                  value: EditableSliderValue(
                    text: '${settings.bucketExpandPx}px',
                    value: settings.bucketExpandPx,
                    min: 0,
                    max: 10,
                    title: l10n.bucketSettingsExpandSection,
                    unit: 'px',
                    onChanged: (v) => settings.setBucketExpandPx(v.round()),
                  ),
                  slider: SteppedSlider(
                    value: settings.bucketExpandPx.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    compact: true,
                    onChanged: (v) => settings.setBucketExpandPx(v.round()),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.bucketSettingsUnderLineTitle),
                  subtitle: Text(
                    settings.bucketExpandPx == 0
                        ? '${l10n.bucketSettingsUnderLineHint}\n${l10n.bucketSettingsUnderLineDisabledHint}'
                        : l10n.bucketSettingsUnderLineHint,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                  value: settings.bucketFillUnderLine,
                  onChanged: (v) => settings.setBucketFillUnderLine(v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 欄の中の1項目：題と値（並べて入らなければ値を下へ）、説明、横幅いっぱいの
  /// スライダー。題・説明はスイッチの行と同じ16pxから始める。
  Widget _sliderBlock(
    BuildContext context, {
    required String title,
    required String hint,
    required Widget value,
    required Widget slider,
  }) {
    final theme = Theme.of(context);
    // 左右の空きはLabeledSliderを欄に置いたとき（12px＋項目名の4px）と
    // そろえ、ジェスチャー・パフォーマンスのスライダーと同じ位置に－・＋を置く。
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // 値の右の鉛筆マークは右へはみ出して描かれるので、そのぶん空ける。
            padding: const EdgeInsetsDirectional.only(
              start: 4,
              end: 9,
              bottom: 4,
            ),
            child: ActionBesideOrBelow(
              gap: 12,
              spacing: 4,
              text: Text(
                title,
                style:
                    theme.listTileTheme.titleTextStyle ??
                    theme.textTheme.titleMedium,
              ),
              action: value,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: messageText(
              hint,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          slider,
        ],
      ),
    );
  }
}
