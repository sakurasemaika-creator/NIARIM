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

  group('custom pen curve', () {
    test(
      'points survive reloading and drive interpolated stylus pressure',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsService();
        addTearDown(settings.dispose);
        await settings.init();
        await settings.setPenPressureCurve(PenPressureCurve.custom);
        await settings.addCustomPressurePoint(.25, .75);
        await settings.addCustomPressurePoint(.75, .20);
        await settings.addCustomPressurePoint(.254, .35);
        await settings.addCustomPressurePoint(1, .5);
        await settings.addCustomPressurePoint(double.nan, .5);

        final restored = SettingsService();
        addTearDown(restored.dispose);
        await restored.init();
        expect(restored.penPressureCurve, PenPressureCurve.custom);
        expect(restored.customPressurePoints, [
          (0.0, 0.0),
          (.25, .75),
          (.75, .20),
          (1.0, 1.0),
        ]);
        expect(restored.applyPressureCurve(.25), .75);
        expect(restored.applyPressureCurve(.50), closeTo(.475, 1e-10));
        expect(restored.applyPressureCurve(.75), closeTo(.20, 1e-10));
      },
    );

    test(
      'more than ten points, flat sections and endpoint values persist',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsService();
        addTearDown(settings.dispose);
        await settings.init();
        await settings.setPenPressureCurve(PenPressureCurve.custom);
        await settings.moveCustomPressurePoint(0, .5, .8);
        for (var i = 1; i <= 16; i++) {
          await settings.addCustomPressurePoint(i / 20, i % 3 == 0 ? .1 : .9);
        }
        await settings.moveCustomPressurePoint(17, .5, .2);
        final restored = SettingsService();
        addTearDown(restored.dispose);
        await restored.init();
        expect(restored.customPressurePoints, settings.customPressurePoints);
        expect(restored.customPressurePoints, hasLength(18));
        expect(restored.applyPressureCurve(0), .8);
        expect(restored.applyPressureCurve(.075), .9);
        expect(restored.applyPressureCurve(.15), closeTo(.1, 1e-10));
        expect(restored.applyPressureCurve(.2), closeTo(.9, 1e-10));
        expect(restored.applyPressureCurve(1), .2);
      },
    );

    test('previous curves with overlapping points remain editable', () async {
      SharedPreferences.setMockInitialValues({
        'pen_pressure_curve': 'custom',
        'pen_pressure_custom_points': [
          '0',
          '0',
          '.5',
          '.3',
          '.503',
          '.8',
          '.504',
          '.6',
          '1',
          '1',
        ],
      });
      final settings = SettingsService();
      addTearDown(settings.dispose);
      await settings.init();
      await settings.moveCustomPressurePoint(2, .8, .4);
      expect(settings.customPressurePoints[2], (.503, .4));
      await settings.removeCustomPressurePoint(1);
      await settings.removeCustomPressurePoint(2);
      await settings.moveCustomPressurePoint(1, .8, .6);
      expect(settings.customPressurePoints[1], (.8, .6));
    });
  });
}
