import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';

Brush _baseBrush() => const Brush(
  id: 'test',
  name: 'test',
  size: 20,
  opacity: 100,
  spacing: 10,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  fadeMode: FadeMode.off,
  strokeDecay: false,
);

void main() {
  group('hair fold settings', () {
    test('custom brush defaults to straight with wave disabled', () {
      final brush = _baseBrush();
      expect(brush.foldWaveEnabled, isFalse);
      expect(brush.foldWaveEndRatio, 0.0);
    });

    test('new fold settings survive copyWith and JSON round-trip', () {
      final configured = _baseBrush().copyWith(
        foldEnabled: true,
        foldCurveStartRatio: 0.25,
        foldCurveStrength: 7,
        foldLengthRatio: 0.8,
        foldEndTaperRatio: 0.35,
        foldWaveEnabled: true,
        foldWaveEndRatio: 0.3,
        foldWaveTriggerAngle: 72,
      );

      final restored = Brush.fromJson(configured.toJson());
      expect(restored.foldCurveStartRatio, 0.25);
      expect(restored.foldCurveStrength, 7);
      expect(restored.foldLengthRatio, 0.8);
      expect(restored.foldEndTaperRatio, 0.35);
      expect(restored.foldWaveEnabled, isTrue);
      expect(restored.foldWaveEndRatio, 0.3);
      expect(restored.foldWaveTriggerAngle, 72);
    });

    test('curve strength defaults to five and clamps to one through ten', () {
      expect(_baseBrush().foldCurveStrength, 5);
      expect(_baseBrush().copyWith(foldCurveStrength: -3).foldCurveStrength, 1);
      expect(_baseBrush().copyWith(foldCurveStrength: 99).foldCurveStrength, 10);
    });

    test('legacy fold depth is ignored when reading pre-release JSON', () {
      final json = _baseBrush().toJson()
        ..remove('foldCurveStrength')
        ..['foldDepthRatio'] = .12;
      final restored = Brush.fromJson(json);
      expect(restored.foldCurveStrength, 5);
      expect(restored.toJson().containsKey('foldDepthRatio'), isFalse);
    });

    test('wave endpoint range clamps to zero through one', () {
      expect(_baseBrush().copyWith(foldWaveEndRatio: -1).foldWaveEndRatio, 0);
      expect(_baseBrush().copyWith(foldWaveEndRatio: 2).foldWaveEndRatio, 1);
    });

    test('turning wave off preserves its configured dependent values', () {
      final configured = _baseBrush().copyWith(
        foldWaveEnabled: true,
        foldWaveEndRatio: 0.3,
        foldWaveTriggerAngle: 70,
      );
      final disabled = configured.copyWith(foldWaveEnabled: false);
      expect(disabled.foldWaveEnabled, isFalse);
      expect(disabled.foldWaveEndRatio, 0.3);
      expect(disabled.foldWaveTriggerAngle, 70);
    });
  });
}
