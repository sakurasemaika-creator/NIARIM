import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';

Map<String, dynamic> _legacyJson({
  String pressureMode = 'sizeAndOpacity',
  int pressureStrength = 50,
  int blurRadius = 24,
  bool edgeJitter = true,
  int edgeJitterStrength = 36,
  String mixingMode = 'bleed',
  int mixingRate = 40,
}) => {
  'id': 'legacy',
  'name': 'legacy',
  'size': 20.0,
  'opacity': 80,
  'spacing': 10,
  'blurRadius': blurRadius,
  'stabilization': false,
  'stabilizationStrength': 50,
  'pixelMode': false,
  'pressureMode': pressureMode,
  'pressureStrength': pressureStrength,
  'fadeMode': 'off',
  'fadeCustom': null,
  'strokeDecay': false,
  'mixingMode': mixingMode,
  'mixingRate': mixingRate,
  'edgeJitter': edgeJitter,
  'edgeJitterStrength': edgeJitterStrength,
};

void main() {
  group('legacy brush pressure migration', () {
    test('loads legacy json without pressure profile keys', () {
      final brush = Brush.fromJson(_legacyJson());

      expect(brush.pressureOn.size.enabled, isTrue);
      expect(brush.pressureOn.size.weak, 50);
      expect(brush.pressureOn.size.strong, 100);
      expect(brush.pressureOn.opacity.enabled, isTrue);
      expect(brush.pressureOn.opacity.weak, 50);
      expect(brush.pressureOn.opacity.strong, 100);

      expect(brush.pressureOn.blur,
          const PressureRangeSetting(enabled: true, weak: 24, strong: 24));
      expect(brush.pressureOff.blur,
          const FixedBrushSetting(enabled: true, value: 24));
      expect(brush.pressureOn.edgeJitter,
          const PressureRangeSetting(enabled: true, weak: 36, strong: 36));
      expect(brush.pressureOff.edgeJitter,
          const FixedBrushSetting(enabled: true, value: 36));

      expect(brush.pressureOn.mixing.enabled, isTrue);
      expect(brush.pressureOn.mixing.mode, BrushMixingMode.bleed);
      expect(brush.pressureOn.mixing.weakRate, 40);
      expect(brush.pressureOn.mixing.strongRate, 40);
      expect(brush.pressureOff.mixing.enabled, isTrue);
      expect(brush.pressureOff.mixing.mode, BrushMixingMode.bleed);
      expect(brush.pressureOff.mixing.rate, 40);
    });

    test('maps legacy pressure mode and strength into selected ranges only', () {
      final brush = Brush.fromJson(
        _legacyJson(
          pressureMode: 'size',
          pressureStrength: 80,
          blurRadius: 0,
          edgeJitter: false,
          mixingMode: 'off',
          mixingRate: 0,
        ),
      );

      expect(brush.pressureOn.size,
          const PressureRangeSetting(enabled: true, weak: 20, strong: 100));
      expect(brush.pressureOn.opacity.enabled, isFalse);
      expect(brush.pressureOn.blur.enabled, isFalse);
      expect(brush.pressureOff.blur.enabled, isFalse);
      expect(brush.pressureOn.edgeJitter.enabled, isFalse);
      expect(brush.pressureOff.edgeJitter.enabled, isFalse);
      expect(brush.pressureOn.mixing.enabled, isFalse);
      expect(brush.pressureOff.mixing.enabled, isFalse);
    });

    test('new profile json remains authoritative when present', () {
      final original = Brush.fromJson(_legacyJson()).copyWith(
        pressureOn: BrushPressureOnSettings.defaults.copyWith(
          size: const PressureRangeSetting(enabled: true, weak: 33, strong: 77),
        ),
        pressureOff: BrushPressureOffSettings.defaults.copyWith(
          blur: const FixedBrushSetting(enabled: true, value: 19),
        ),
      );

      final restored = Brush.fromJson(original.toJson());
      expect(restored.pressureOn.size.weak, 33);
      expect(restored.pressureOn.size.strong, 77);
      expect(restored.pressureOff.blur,
          const FixedBrushSetting(enabled: true, value: 19));
    });
  });
}
