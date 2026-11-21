import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../widgets/action_beside_or_below.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/stepped_slider.dart';
import '../../config/font_fallback.dart';
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
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel(
              context,
              l10n.bucketSettingsToleranceSection,
              value: EditableSliderValue(
                text: '${settings.bucketTolerance.round()} / 100',
                value: settings.bucketTolerance,
                min: 0,
                max: 100,
                title: l10n.bucketSettingsToleranceSection,
                onChanged: (v) => settings.setBucketTolerance(v.toDouble()),
              ),
            ),
            Text(
              l10n.bucketSettingsToleranceHint,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SteppedSlider(
              value: settings.bucketTolerance,
              min: 0,
              max: 100,
              divisions: 100,
              compact: true,
              onChanged: (v) => settings.setBucketTolerance(v),
            ),
            const SizedBox(height: 20),
            _sectionLabel(
              context,
              l10n.bucketSettingsExpandSection,
              value: EditableSliderValue(
                text: '${settings.bucketExpandPx}px',
                value: settings.bucketExpandPx,
                min: 0,
                max: 10,
                title: l10n.bucketSettingsExpandSection,
                unit: 'px',
                onChanged: (v) => settings.setBucketExpandPx(v.round()),
              ),
            ),
            Text(
              l10n.bucketSettingsExpandHint,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SteppedSlider(
              value: settings.bucketExpandPx.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              compact: true,
              onChanged: (v) => settings.setBucketExpandPx(v.round()),
            ),
            SizedBox(height: 8),
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
            ),
          ],
        ),
      ),
    );
  }

  /// 見出しと、その行の右端に置くスライダーの値。スライダー本体は下の行で
  /// 横幅いっぱいを使う。
  Widget _sectionLabel(
    BuildContext context,
    String text, {
    required Widget value,
  }) {
    return Padding(
      // 値の右の鉛筆マークは右へはみ出して描かれるので、そのぶん空ける。
      padding: const EdgeInsetsDirectional.only(end: 10, bottom: 6),
      child: ActionBesideOrBelow(
        gap: 12,
        spacing: 4,
        text: Text(
          text,
          style: localizedHeadingStyle(
            context,
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        action: value,
      ),
    );
  }
}
