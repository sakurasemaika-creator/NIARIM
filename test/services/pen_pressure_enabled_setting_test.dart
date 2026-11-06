import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pen pressure enabled setting', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults to enabled', () async {
      final settings = SettingsService();
      await settings.init();

      expect(settings.penPressureEnabled, isTrue);
    });

    test('persists disabled state and restores it on init', () async {
      final settings = SettingsService();
      await settings.init();
      await settings.setPenPressureEnabled(false);

      expect(settings.penPressureEnabled, isFalse);

      final restored = SettingsService();
      await restored.init();
      expect(restored.penPressureEnabled, isFalse);
    });

    test('can be enabled again after being disabled', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pen_pressure_enabled': false,
      });
      final settings = SettingsService();
      await settings.init();

      await settings.setPenPressureEnabled(true);

      expect(settings.penPressureEnabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pen_pressure_enabled'), isTrue);
    });
  });
}
