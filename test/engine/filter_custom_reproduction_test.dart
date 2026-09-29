import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('old prism snapshots migrate without overriding new explicit kinds', () {
    final old = FilterDef.fromJson({
      'id': 'Filter0022',
      'name': 'prism',
      'kind': 'gaussianBlur',
    });
    expect(old.kind, FilterKind.prism);
    expect(
      FilterDef.fromJson(
        old.copyWith(kind: FilterKind.gaussianBlur).toJson(),
      ).kind,
      FilterKind.gaussianBlur,
    );
  });
  test('legacy noise snapshots migrate once to editable common settings', () {
    for (final entry in {
      'Filter0024': NoiseStyle.vhs,
      'Filter0027': NoiseStyle.color,
    }.entries) {
      final legacy = {
        'id': entry.key,
        'name': 'legacy',
        'kind': 'noise',
        'strength': 35,
        'thresholdValue': 73,
      };
      final migrated = FilterDef.fromJson(legacy);
      expect(migrated.noiseStyle, entry.value);
      if (entry.value == NoiseStyle.vhs) expect(migrated.noiseSeed, 73);
      final changed = migrated.copyWith(
        noiseStyle: NoiseStyle.filmGrain,
        noiseSeed: 42,
      );
      final reloaded = FilterDef.fromJson(changed.toJson());
      expect(reloaded.noiseStyle, NoiseStyle.filmGrain);
      expect(reloaded.noiseSeed, 42);
    }
  });
  test('noise presets keep the same result after custom duplication', () async {
    SharedPreferences.setMockInitialValues({});
    final service = FilterService();
    await service.init();
    addTearDown(service.dispose);
    final source = Uint8List.fromList([
      for (var i = 0; i < 32 * 24; i++) ...[
        80 + i % 100,
        60 + i % 150,
        40 + i % 190,
        255,
      ],
    ]);
    for (final preset in service.filters.where(
      (f) => f.kind == FilterKind.noise,
    )) {
      final custom = FilterDef.fromJson(
        preset.copyWith(id: 'custom-${preset.id}', name: 'My noise').toJson(),
      );
      expect(
        applyDrawFilterInIsolate((source, 32, 24, custom, null)),
        orderedEquals(applyDrawFilterInIsolate((source, 32, 24, preset, null))),
        reason: 'same public settings: ${preset.id}',
      );
    }
  });
}
