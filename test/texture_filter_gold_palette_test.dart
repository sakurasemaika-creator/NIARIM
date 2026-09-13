import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('texture filter naming and Sunset Gold reference colors are locked', () {
    final ja = File('lib/l10n/app_ja.arb').readAsStringSync();
    final en = File('lib/l10n/app_en.arb').readAsStringSync();
    final engine = File('lib/engine/filter_engine.dart').readAsStringSync();
    final presets = File(
      'lib/models/custom_automation_presets.dart',
    ).readAsStringSync();
    final service = File('lib/services/filter_service.dart').readAsStringSync();

    expect(ja, contains('"filterNameAuroraHologram": "質感変更フィルター"'));
    expect(
      ja,
      contains('"filterAuroraHologramPresetClassicHologram": "オーロラホログラム"'),
    );
    expect(en, contains('"filterNameAuroraHologram": "Texture Filter"'));
    expect(
      en,
      contains(
        '"filterAuroraHologramPresetClassicHologram": "Aurora Hologram"',
      ),
    );
    expect(presets, contains("name: '質感変更フィルター'"));
    expect(presets, contains("id: 'Filter0019'"));
    expect(service, contains("id: 'Filter0019'"));
    expect(service, contains("name: '質感変更フィルター'"));

    for (final rgbTail in <String>[
      '223, 149, 31)',
      '114, 77, 17)',
      '80, 53, 10)',
      '255, 190, 57)',
      '255, 221, 151)',
      '251, 138, 11)',
    ]) {
      expect(engine, contains(rgbTail));
    }
  });
}
