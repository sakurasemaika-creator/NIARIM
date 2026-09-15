import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy Filter0025 without toneCurvePreset migrates to invert', () async {
    final legacy = FilterDef(
      id: 'Filter0025',
      name: '色反転',
      kind: FilterKind.toneCurve,
    ).toJson()
      ..remove('toneCurvePreset');
    SharedPreferences.setMockInitialValues({
      'draw_filters': [jsonEncode(legacy)],
    });

    final service = FilterService();
    await service.init();

    final inversion = service.filters.singleWhere((f) => f.id == 'Filter0025');
    expect(inversion.toneCurvePreset, ToneCurvePreset.invert);
  });

  test('explicit Filter0025 toneCurvePreset is preserved', () async {
    final explicit = FilterDef(
      id: 'Filter0025',
      name: '色反転',
      kind: FilterKind.toneCurve,
      toneCurvePreset: ToneCurvePreset.linear,
    );
    SharedPreferences.setMockInitialValues({
      'draw_filters': [jsonEncode(explicit.toJson())],
    });

    final service = FilterService();
    await service.init();

    final inversion = service.filters.singleWhere((f) => f.id == 'Filter0025');
    expect(inversion.toneCurvePreset, ToneCurvePreset.linear);
  });
}
