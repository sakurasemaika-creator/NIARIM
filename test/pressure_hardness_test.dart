import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/pressure_hardness.dart';

void main() {
  group('pressure hardness', () {
    test('maps ten UI levels to the existing pressure-strength scale', () {
      expect(pressureStrengthForHardness(1), 10);
      expect(pressureStrengthForHardness(5), 50);
      expect(pressureStrengthForHardness(10), 100);
    });

    test('normalizes existing strength values to one of ten UI levels', () {
      expect(pressureHardnessForStrength(0), 1);
      expect(pressureHardnessForStrength(10), 1);
      expect(pressureHardnessForStrength(54), 5);
      expect(pressureHardnessForStrength(55), 6);
      expect(pressureHardnessForStrength(100), 10);
    });

    test('hardness can only be edited while pressure is enabled', () {
      expect(isPressureHardnessEnabled(PressureMode.off), isFalse);
      expect(isPressureHardnessEnabled(PressureMode.size), isTrue);
      expect(isPressureHardnessEnabled(PressureMode.opacity), isTrue);
      expect(isPressureHardnessEnabled(PressureMode.sizeAndOpacity), isTrue);
    });
  });
}
