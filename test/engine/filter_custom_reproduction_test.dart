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
  test('levels gamma persists and changes midtones without moving endpoints', () {
    const def = FilterDef(
      id: 'levels-gamma',
      name: 'levels',
      kind: FilterKind.levels,
      inputGamma: 2.0,
    );
    final restored = FilterDef.fromJson(def.toJson());
    expect(restored.inputGamma, 2.0);

    final source = Uint8List.fromList([
      0, 0, 0, 255,
      64, 64, 64, 255,
      128, 128, 128, 255,
      255, 255, 255, 255,
    ]);
    final linear = applyDrawFilterInIsolate((
      source,
      4,
      1,
      def.copyWith(inputGamma: 1.0),
      null,
    ));
    final gamma = applyDrawFilterInIsolate((source, 4, 1, def, null));
    expect(gamma[0], 0);
    expect(gamma[12], 255);
    expect(gamma[4], greaterThan(linear[4]));
    expect(gamma[8], greaterThan(linear[8]));
  });
  test('custom tone curve points persist and drive rendering', () {
    const def = FilterDef(
      id: 'curve-custom',
      name: 'curve',
      kind: FilterKind.toneCurve,
      toneCurvePoints: [0, 0, 0.5, 0.8, 1, 1],
    );
    final restored = FilterDef.fromJson(def.toJson());
    expect(restored.toneCurvePoints, orderedEquals(def.toneCurvePoints));
    final source = Uint8List.fromList([128, 128, 128, 255]);
    final out = applyDrawFilterInIsolate((source, 1, 1, restored, null));
    expect(out[0], greaterThan(128));
    expect(out[1], out[0]);
    expect(out[2], out[0]);
  });
}


