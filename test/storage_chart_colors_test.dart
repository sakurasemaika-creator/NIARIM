import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/settings/storage_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void checkPalette(ColorScheme scheme) {
    final accent = HSLColor.fromColor(scheme.primary);
    final darker = (accent.lightness * 100).round() >= 51;
    final shifted = accent.withHue(
      (accent.hue + storageDeviceHueShiftDegrees) % 360,
    );
    for (final (base, colors, count) in [
      (accent, sliceColorsOf(scheme), 6),
      (shifted, storageDeviceSliceColorsOf(scheme), 3),
    ]) {
      expect(colors, hasLength(count));
      expect(colors.toSet(), hasLength(count));
      expect(colors.first, base.toColor());
      for (var i = 1; i < count; i++) {
        final previous = HSLColor.fromColor(colors[i - 1]).lightness;
        final current = HSLColor.fromColor(colors[i]).lightness;
        expect(current, darker ? lessThan(previous) : greaterThan(previous));
        expect((current - previous).abs(), closeTo(.08, .005));
        final expected = base.withLightness(
          base.lightness + (darker ? -.08 : .08) * i,
        );
        expect(colors[i], expected.toColor());
      }
    }
  }

  test('every built-in theme keeps six distinct chart colors', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    expect(service.presets.length, greaterThan(5));
    for (final preset in service.presets) {
      service.applyPreset(preset.id);
      checkPalette(service.themeData.colorScheme);
    }
    service.dispose();
  });

  test('at 50% bars lighten and at 51% bars darken', () {
    for (final level in [0.0, .20, .50, .51, .80, 1.0]) {
      final color = HSLColor.fromAHSL(1, 212, .65, level).toColor();
      checkPalette(const ColorScheme.light().copyWith(primary: color));
    }
  });
}
