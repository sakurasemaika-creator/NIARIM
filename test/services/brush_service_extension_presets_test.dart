import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/brush_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('first launch includes Net and Hair as built-in presets', () async {
    final service = BrushService();
    await service.init();

    final byId = {for (final brush in service.brushes) brush.id: brush};
    expect(byId.containsKey('Brush0022'), isTrue);
    expect(byId.containsKey('Brush0023'), isTrue);
    expect(byId['Brush0022']!.name, 'ネット');
    expect(byId['Brush0023']!.name, '髪の毛');
    expect(service.isBuiltIn('Brush0022'), isTrue);
    expect(service.isBuiltIn('Brush0023'), isTrue);
  });

  test('existing saved brush list receives missing extension presets', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'brushes': <String>[],
    });
    final service = BrushService();
    await service.init();

    final ids = service.brushes.map((brush) => brush.id).toSet();
    expect(ids, containsAll(<String>{'Brush0022', 'Brush0023'}));
  });
}
