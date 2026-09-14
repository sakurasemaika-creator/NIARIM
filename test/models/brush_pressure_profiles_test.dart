import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';

void main() {
  group('Brush pressure profiles', () {
    test('new brushes store explicit pressure profile defaults', () {
      final brush = Brush.defaultBrush('pressure-defaults');

      expect(brush.pressureOn.size.enabled, isTrue);
      expect(brush.pressureOn.size.weak, 50);
      expect(brush.pressureOn.size.strong, 100);
      expect(brush.pressureOn.opacity.enabled, isTrue);
      expect(brush.pressureOn.opacity.weak, 50);
      expect(brush.pressureOn.opacity.strong, 100);
      expect(brush.pressureOn.blur.enabled, isFalse);
      expect(brush.pressureOn.blur.weak, 50);
      expect(brush.pressureOn.blur.strong, 0);
      expect(brush.pressureOn.edgeJitter.enabled, isFalse);
      expect(brush.pressureOn.edgeJitter.weak, 50);
      expect(brush.pressureOn.edgeJitter.strong, 0);
      expect(brush.pressureOn.mixing.enabled, isFalse);
      expect(brush.pressureOn.mixing.weakRate, 50);
      expect(brush.pressureOn.mixing.strongRate, 0);

      expect(brush.pressureOff.blur.enabled, isFalse);
      expect(brush.pressureOff.blur.value, 0);
      expect(brush.pressureOff.edgeJitter.enabled, isFalse);
      expect(brush.pressureOff.edgeJitter.strength, 0);
      expect(brush.pressureOff.mixing.enabled, isFalse);
      expect(brush.pressureOff.mixing.rate, 0);
    });

    test('pressure profiles round trip through brush json', () {
      final original = Brush.defaultBrush('pressure-roundtrip').copyWith(
        pressureOn: BrushPressureOnSettings.defaults.copyWith(
          size: const PressureRangeSetting(enabled: true, weak: 35, strong: 92),
          opacity: const PressureRangeSetting(enabled: true, weak: 44, strong: 88),
          blur: const PressureRangeSetting(enabled: true, weak: 70, strong: 10),
          edgeJitter: const PressureRangeSetting(enabled: true, weak: 60, strong: 5),
          mixing: const PressureMixingOnSetting(
            enabled: true,
            mode: BrushMixingMode.bleed,
            weakRate: 75,
            strongRate: 15,
          ),
        ),
        pressureOff: BrushPressureOffSettings.defaults.copyWith(
          blur: const FixedBrushSetting(enabled: true, value: 23),
          edgeJitter: const FixedBrushSetting(enabled: true, value: 34),
          mixing: const PressureMixingOffSetting(
            enabled: true,
            mode: BrushMixingMode.simple,
            rate: 45,
          ),
        ),
      );

      final restored = Brush.fromJson(original.toJson());

      expect(restored.pressureOn, original.pressureOn);
      expect(restored.pressureOff, original.pressureOff);
    });
  });
}
