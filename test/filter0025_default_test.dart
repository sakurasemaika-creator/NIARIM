import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Filter0025 is the color-inversion tone-curve preset', () async {
    SharedPreferences.setMockInitialValues({});
    final service = FilterService();
    await service.init();

    final filter = service.filters.singleWhere((item) => item.id == 'Filter0025');
    expect(filter.name, '色反転');
    expect(filter.kind, FilterKind.toneCurve);
    expect(filter.toneCurvePreset, ToneCurvePreset.invert);
  });
}
