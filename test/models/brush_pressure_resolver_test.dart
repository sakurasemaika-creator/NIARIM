import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_pressure_resolver.dart';

Brush _brush() => Brush(
  id: 'PressureResolverBrush',
  name: 'Pressure Resolver',
  size: 20,
  opacity: 80,
  spacing: 10,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 50,
  pixelMode: false,
  pressureMode: PressureMode.off,
  pressureStrength: 100,
  pressureOn: const BrushPressureOnSettings(
    size: PressureRangeSetting(enabled: true, weak: 50, strong: 100),
    opacity: PressureRangeSetting(enabled: true, weak: 25, strong: 75),
    blur: PressureRangeSetting(enabled: true, weak: 80, strong: 20),
    edgeJitter: PressureRangeSetting(enabled: true, weak: 60, strong: 10),
    mixing: PressureMixingOnSetting(
      enabled: true,
      mode: BrushMixingMode.bleed,
      weakRate: 70,
      strongRate: 30,
    ),
  ),
  pressureOff: const BrushPressureOffSettings(
    blur: FixedBrushSetting(enabled: true, value: 23),
    edgeJitter: FixedBrushSetting(enabled: true, value: 34),
    mixing: PressureMixingOffSetting(
      enabled: true,
      mode: BrushMixingMode.simple,
      rate: 45,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
);

void main() {
  group('resolveBrushPressure', () {
    test('pressure ON resolves weak, midpoint, and strong values', () {
      final brush = _brush();

      final weak = resolveBrushPressure(
        brush: brush,
        pressureEnabled: true,
        curvedPressure: 0,
      );
      expect(weak.sizeScale, 0.5);
      expect(weak.opacityScale, 0.25);
      expect(weak.blur, 80);
      expect(weak.edgeJitterEnabled, isTrue);
      expect(weak.edgeJitterStrength, 60);
      expect(weak.mixingMode, BrushMixingMode.bleed);
      expect(weak.mixingRate, 70);

      final midpoint = resolveBrushPressure(
        brush: brush,
        pressureEnabled: true,
        curvedPressure: 0.5,
      );
      expect(midpoint.sizeScale, 0.75);
      expect(midpoint.opacityScale, 0.5);
      expect(midpoint.blur, 50);
      expect(midpoint.edgeJitterStrength, 35);
      expect(midpoint.mixingRate, 50);

      final strong = resolveBrushPressure(
        brush: brush,
        pressureEnabled: true,
        curvedPressure: 1,
      );
      expect(strong.sizeScale, 1.0);
      expect(strong.opacityScale, 0.75);
      expect(strong.blur, 20);
      expect(strong.edgeJitterStrength, 10);
      expect(strong.mixingRate, 30);
    });

    test('pressure OFF uses fixed values regardless of pressure', () {
      final brush = _brush();
      final weak = resolveBrushPressure(
        brush: brush,
        pressureEnabled: false,
        curvedPressure: 0,
      );
      final strong = resolveBrushPressure(
        brush: brush,
        pressureEnabled: false,
        curvedPressure: 1,
      );

      expect(weak, strong);
      expect(weak.sizeScale, 1);
      expect(weak.opacityScale, 1);
      expect(weak.blur, 23);
      expect(weak.edgeJitterEnabled, isTrue);
      expect(weak.edgeJitterStrength, 34);
      expect(weak.mixingMode, BrushMixingMode.simple);
      expect(weak.mixingRate, 45);
    });

    test('disabled items contribute no pressure-specific effect', () {
      final brush = _brush().copyWith(
        pressureOn: BrushPressureOnSettings.defaults.copyWith(
          size: const PressureRangeSetting(enabled: false, weak: 10, strong: 20),
          opacity: const PressureRangeSetting(enabled: false, weak: 10, strong: 20),
          blur: const PressureRangeSetting(enabled: false, weak: 90, strong: 10),
          edgeJitter: const PressureRangeSetting(enabled: false, weak: 90, strong: 10),
          mixing: const PressureMixingOnSetting(
            enabled: false,
            mode: BrushMixingMode.bleed,
            weakRate: 90,
            strongRate: 10,
          ),
        ),
      );

      final resolved = resolveBrushPressure(
        brush: brush,
        pressureEnabled: true,
        curvedPressure: 0.5,
      );

      expect(resolved.sizeScale, 1);
      expect(resolved.opacityScale, 1);
      expect(resolved.blur, 0);
      expect(resolved.edgeJitterEnabled, isFalse);
      expect(resolved.edgeJitterStrength, 0);
      expect(resolved.mixingMode, BrushMixingMode.off);
      expect(resolved.mixingRate, 0);
    });

    test('pressure input is clamped to 0 through 1', () {
      final brush = _brush();
      expect(
        resolveBrushPressure(
          brush: brush,
          pressureEnabled: true,
          curvedPressure: -2,
        ).sizeScale,
        0.5,
      );
      expect(
        resolveBrushPressure(
          brush: brush,
          pressureEnabled: true,
          curvedPressure: 3,
        ).sizeScale,
        1.0,
      );
    });
  });
}
