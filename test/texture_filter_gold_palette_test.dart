import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test('texture filter naming and yellow-gold palette are locked', () {
    final ja = File('lib/l10n/app_ja.arb').readAsStringSync();
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final service = File('lib/services/filter_service.dart').readAsStringSync();

    expect(ja, contains('"filterNameAuroraHologram": "質感変更フィルター"'));
    expect(
      ja,
      contains('"filterAuroraHologramPresetClassicHologram": "レインボーホログラム"'),
    );
    expect(
      ja,
      contains('"filterAuroraHologramPresetSunsetGold": "アンバーゴールド"'),
    );
    expect(en, contains('"filterNameAuroraHologram": "Texture Filter"'));
    expect(
      en,
      contains('"filterAuroraHologramPresetClassicHologram": "Rainbow Hologram"'),
    );
    expect(service, contains("id: 'Filter0019'"));
    expect(service, contains("name: '質感変更フィルター'"));

    final stops = auroraHologramStops(AuroraHologramPreset.sunsetGold);
    expect(stops.first, equals((0.00, 62, 42, 8)));
    expect(stops.last, equals((1.00, 255, 253, 225)));

    // Mid/high tones should read as yellow gold rather than orange:
    // green stays relatively close to red while blue remains restrained.
    final goldTones = stops.where((s) => s.$1 >= 0.40 && s.$1 <= 0.90);
    for (final stop in goldTones) {
      expect(stop.$2 - stop.$3, lessThanOrEqualTo(70), reason: '$stop');
      expect(stop.$3, greaterThan(stop.$4), reason: '$stop');
    }

    // Pure-white input maps to the brightest color in the palette.
    final brightest = stops.reduce((a, b) {
      final la = 299 * a.$2 + 587 * a.$3 + 114 * a.$4;
      final lb = 299 * b.$2 + 587 * b.$3 + 114 * b.$4;
      return la >= lb ? a : b;
    });
    expect(stops.last, brightest);
  });
}
