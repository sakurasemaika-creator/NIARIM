import 'dart:convert';

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
    test('custom brush defaults to fold disabled and top-view mode', () {
      final brush = _baseBrush();
      expect(brush.foldEnabled, isFalse);
      expect(brush.foldMode, HairFoldMode.waveTopView);
    });

    const serializedModes = <HairFoldMode, String>{
      HairFoldMode.waveTopView: 'waveTopView',
      HairFoldMode.waveLowAngle: 'waveLowAngle',
      HairFoldMode.curlRight: 'curlRight',
      HairFoldMode.curlLeft: 'curlLeft',
      HairFoldMode.crescent: 'crescent',
    };

    test('serialized mode contract covers every supported mode', () {
      expect(serializedModes.keys, unorderedEquals(HairFoldMode.values));
    });

    for (final entry in serializedModes.entries) {
      test('${entry.value} survives copyWith and JSON round trip', () {
        final configured = _baseBrush().copyWith(
          outlineEnabled: true,
          foldEnabled: true,
          foldMode: entry.key,
          foldTriggerAngle: 67,
          foldCurveStartRatio: 0.31,
          foldCurveStrength: 7,
          foldLengthRatio: 0.72,
          foldEndTaperRatio: 0.43,
        );
        expect(configured.foldMode, entry.key);

        final json = jsonDecode(jsonEncode(configured.toJson()))
            as Map<String, dynamic>;
        expect(json['foldMode'], entry.value);

        final restored = Brush.fromJson(json);
        expect(restored.foldMode, entry.key);
        expect(restored.outlineEnabled, isTrue);
        expect(restored.foldEnabled, isTrue);
        expect(restored.foldTriggerAngle, 67);
        expect(restored.foldCurveStartRatio, 0.31);
        expect(restored.foldCurveStrength, 7);
        expect(restored.foldLengthRatio, 0.72);
        expect(restored.foldEndTaperRatio, 0.43);
        expect(restored.copyWith(name: 'Renamed').foldMode, entry.key);
      });

      test('disabling fold preserves ${entry.value} and its settings', () {
        final configured = _baseBrush().copyWith(
          foldEnabled: true,
          foldMode: entry.key,
          foldCurveStrength: 8,
          foldLengthRatio: 0.62,
        );
        final disabled = configured.copyWith(foldEnabled: false);
        final restored = Brush.fromJson(disabled.toJson());
        expect(restored.foldEnabled, isFalse);
        expect(restored.foldMode, entry.key);
        expect(restored.foldCurveStrength, 8);
        expect(restored.foldLengthRatio, 0.62);
        expect(restored.copyWith(foldEnabled: true).foldMode, entry.key);
      });
    }

    test('missing or unknown mode falls back to top-view mode', () {
      final missingMode = _baseBrush().toJson()..remove('foldMode');
      expect(Brush.fromJson(missingMode).foldMode, HairFoldMode.waveTopView);
      for (final invalidMode in <Object?>[null, 'unsupportedMode', 99]) {
        final json = _baseBrush().toJson()..['foldMode'] = invalidMode;
        expect(Brush.fromJson(json).foldMode, HairFoldMode.waveTopView);
      }
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

    test('obsolete wave fields do not override mode or survive serialization', () {
      final json = _baseBrush().copyWith(foldMode: HairFoldMode.curlLeft).toJson()
        ..['foldWaveEnabled'] = true
        ..['foldWaveEndRatio'] = 0.3
        ..['foldWaveTriggerAngle'] = 70;
      final restored = Brush.fromJson(json);
      expect(restored.foldMode, HairFoldMode.curlLeft);
      expect(restored.toJson(), isNot(contains('foldWaveEnabled')));
      expect(restored.toJson(), isNot(contains('foldWaveEndRatio')));
      expect(restored.toJson(), isNot(contains('foldWaveTriggerAngle')));
    });
  });
}
