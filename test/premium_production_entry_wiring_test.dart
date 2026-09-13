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
      contains(
        'isFeatureAvailable(PremiumFeature.unlimitedDuration)',
      ),
    );
    expect(
      source,
      contains('seconds > premiumService.maxProjectDurationSeconds'),
    );
    expect(
      source,
      contains('isFeatureAvailable(PremiumFeature.endCardEdit)'),
    );
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
}
