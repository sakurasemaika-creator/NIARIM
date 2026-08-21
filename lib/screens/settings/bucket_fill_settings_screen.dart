import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/responsive.dart';
import '../../widgets/help_button.dart';
import '../../widgets/stepped_slider.dart';

/// バケツ塗り詳細設定（仕様書03・17：許容誤差・拡張px・線の下まで潜る）。
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
      appBar: AppBar(title: Text(l10n.bucketSettingsTitle), actions: const [HelpButton(topic: 'バケツ塗り詳細設定')]),
      body: desktopCentered(context, ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(context, l10n.bucketSettingsToleranceSection),
          Text(l10n.bucketSettingsToleranceHint,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SteppedSlider(
                  value: settings.bucketTolerance,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (v) => settings.setBucketTolerance(v),
                ),
              ),
              SizedBox(
                width: 32,
                child: EditableSliderValue(
                  text: settings.bucketTolerance.round().toString(),
                  value: settings.bucketTolerance,
                  min: 0,
                  max: 100,
                  title: l10n.bucketSettingsToleranceSection,
                  onChanged: (v) => settings.setBucketTolerance(v.toDouble()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, l10n.bucketSettingsExpandSection),
          Text(l10n.bucketSettingsExpandHint,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SteppedSlider(
                  value: settings.bucketExpandPx.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (v) => settings.setBucketExpandPx(v.round()),
                ),
              ),
              SizedBox(
                width: 32,
                child: EditableSliderValue(
                  text: '${settings.bucketExpandPx}',
                  value: settings.bucketExpandPx,
                  min: 0,
                  max: 10,
                  title: l10n.bucketSettingsExpandSection,
                  onChanged: (v) => settings.setBucketExpandPx(v.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SwitchListTile(
              title: Text(l10n.bucketSettingsUnderLineTitle),
              subtitle: Text(
                settings.bucketExpandPx == 0
                    ? '${l10n.bucketSettingsUnderLineHint}\n${l10n.bucketSettingsUnderLineDisabledHint}'
                    : l10n.bucketSettingsUnderLineHint,
                style: const TextStyle(fontSize: 11),
              ),
              value: settings.bucketFillUnderLine,
              onChanged: (v) => settings.setBucketFillUnderLine(v),
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
}
