import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('watermark production entry remains gated before navigation', () {
    final source = File(
      'lib/screens/settings/settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('void _showWatermarkSetting()'));
    expect(source, contains('PremiumFeature.watermark'));
    expect(source, contains('isFeatureAvailable('));
    expect(source, contains('showPremiumBanner(context);'));
    expect(source, contains("context.push('/settings/watermark');"));
  });

  test('tone curve and level adjustment production entries stay locked', () {
    final source = File(
      'lib/screens/canvas/widgets/filter_panel.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('FilterKind.toneCurve => PremiumFeature.toneCurve'),
    );
    expect(
      source,
      contains('FilterKind.levels => PremiumFeature.levelAdjustment'),
    );
    expect(source, contains('isFeatureAvailable('));
    expect(source, contains('onTap: locked'));
    expect(
      source,
      contains('PremiumLockWidget(feature: premium, child: child)'),
    );
  });

  test('export enforces unlimited duration and end-card Premium gates', () {
    final source = File(
      'lib/screens/export/export_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('isFeatureAvailable(PremiumFeature.unlimitedDuration)'),
    );
    expect(
      source,
      contains('seconds > premiumService.maxProjectDurationSeconds'),
    );
    expect(source, contains('isFeatureAvailable(PremiumFeature.endCardEdit)'));
    expect(source, contains('appendEndCard: shouldAppendEndCard'));
  });

  test('custom automation production entry remains gated before manager', () {
    final source = File(
      'lib/screens/canvas/canvas_screen.dart',
    ).readAsStringSync();

    expect(source, contains('void _showCustomAutomationManager()'));
    expect(source, contains('PremiumFeature.customAutomation'));
    expect(source, contains('isFeatureAvailable('));
    expect(source, contains('showPremiumBanner(context);'));
    expect(source, contains('_showCustomAutomationManager();'));
  });
  test('watermark deep links and open dialogs recheck active Premium rights', () {
    final source = File(
      'lib/screens/settings/watermark_settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PremiumFeature.watermark'));
    expect(source, contains('context.watch<PremiumService>()'));
    expect(source, contains('bool _canEditNow(BuildContext context)'));
    expect(source, contains('showPremiumBanner(context);'));
    // Delete after confirmation, imported image after file picker, text save
    // and image edit save must all fail closed if the lease expires mid-dialog.
    expect(
      RegExp(r'_canEditNow\(context\)').allMatches(source).length,
      greaterThanOrEqualTo(4),
    );
  });

  test('timeline cannot add or modify watermark after entitlement expiry', () {
    final source = File(
      'lib/screens/timeline/timeline_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _addWatermarkLayer('));
    expect(source, contains('Future<bool> _reRasterizeWatermark('));
    expect(source, contains('if (!await _reRasterizeWatermark('));
    expect(
      RegExp(r'PremiumFeature\.watermark').allMatches(source).length,
      greaterThanOrEqualTo(6),
    );
    expect(source, contains('if (mounted) showPremiumBanner(context);'));
  });

}
