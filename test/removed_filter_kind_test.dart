import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The monochrome drawing filter was removed (saturation adjustment covers
/// it). A stored or recorded filter of a removed kind must not turn into a
/// different filter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final monochrome = {
    'id': 'Filter0013',
    'name': '単色化フィルター',
    'kind': 'monochrome',
    'strength': 100,
  };

  test('the monochrome drawing filter no longer exists', () async {
    expect(FilterKind.values.map((k) => k.name), isNot(contains('monochrome')));
    SharedPreferences.setMockInitialValues({});
    final service = FilterService();
    await service.init();
    expect(service.filters.map((f) => f.id), isNot(contains('Filter0013')));
  });

  test('a stored filter of a removed kind is dropped, not shown as another '
      'filter under its old name', () async {
    SharedPreferences.setMockInitialValues({});
    final defaults = FilterService();
    await defaults.init();
    SharedPreferences.setMockInitialValues({
      'draw_filters': [
        for (final f in defaults.filters) jsonEncode(f.toJson()),
        jsonEncode(monochrome),
      ],
    });
    final service = FilterService();
    await service.init();
    expect(service.filters.map((f) => f.id), isNot(contains('Filter0013')));
    expect(service.filters.length, defaults.filters.length);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('draw_filters')!.any((s) => s.contains('monochrome')),
      isFalse,
      reason: 'the dropped entry is not written back',
    );
  });

  test('a recorded snapshot of a removed kind is reported, not applied as '
      'another filter', () {
    expect(FilterDef.hasKnownKind(monochrome), isFalse);
    expect(() => FilterDef.fromJson(monochrome), throwsFormatException);
  });

  test('the legacy prism snapshot without a schema version still parses', () {
    final legacy = {'id': 'Filter0022', 'name': 'プリズム', 'kind': 'noise'};
    expect(FilterDef.hasKnownKind(legacy), isTrue);
    expect(FilterDef.fromJson(legacy).kind, FilterKind.prism);
  });
}
