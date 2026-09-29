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
    expect(en, contains('"filterNameAuroraHologram": "Texture Filter"'));
    expect(
      en,
      contains('"filterAuroraHologramPresetClassicHologram": "Rainbow Hologram"'),
    );
    expect(service, contains("id: 'Filter0019'"));
    expect(service, contains("name: '質感変更フィルター'"));

    final stops = auroraHologramStops(AuroraHologramPreset.sampledGold);
    expect(stops.first, equals((0.00, 70, 50, 31)));
    expect(stops.last, equals((1.00, 255, 255, 244)));

    // Sampled gold remains warm metallic through the mid/high range.
    final goldTones = stops.where((s) => s.$1 >= 0.40 && s.$1 <= 0.90);
    for (final stop in goldTones) {
      expect(stop.$2, greaterThanOrEqualTo(stop.$3), reason: '$stop');
      expect(stop.$3, greaterThan(stop.$4), reason: '$stop');
    }
  });
    expect(stops.last, brightest);
  });
}
