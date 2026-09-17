import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';
import 'package:niarim/engine/wave_hair_fold_geometry.dart';

FoldEvent _event({
  double width = 20,
  double turn = 1.8,
}) => FoldEvent(
      sample: BrushStrokeSample(
        screenPosition: const Offset(40, 40),
        documentPosition: const Offset(100, 100),
        effectiveWidth: width,
      ),
      tangent: const Offset(1, 0),
      inwardNormal: const Offset(0, 1),
      signedTurnRadians: turn,
      screenDistance: 40,
    );

void main() {
  group('Drawing engine wave fold production contract', () {
    test('straight and wave sections can coexist in one fold path', () {
      final path = buildWaveFoldPath(
        _event(),
        curveStartRatio: .2,
        depthRatio: .5,
        lengthRatio: 1.5,
        waveEndRatio: .4,
        waveTriggerAngleDegrees: 45,
      );

      expect(path.where((sample) => !sample.isWave), isNotEmpty);
      expect(path.where((sample) => sample.isWave), isNotEmpty);
      expect(path.first.isWave, isFalse);
      expect(path.last.isWave, isTrue);
    });

    test('wave disabled remains the straight production geometry', () {
      final straight = buildStraightFoldPath(
        _event(),
        curveStartRatio: .2,
        depthRatio: .5,
        lengthRatio: 1.5,
        taperRatio: .35,
      );
      final disabled = buildWaveFoldPath(
        _event(),
        curveStartRatio: .2,
        depthRatio: .5,
        lengthRatio: 1.5,
        waveEndRatio: 0,
        waveTriggerAngleDegrees: 45,
        taperRatio: .35,
      );

      expect(disabled.length, straight.length);
      for (var i = 0; i < straight.length; i++) {
        expect(disabled[i].position.dx, closeTo(straight[i].position.dx, 1e-6));
        expect(disabled[i].position.dy, closeTo(straight[i].position.dy, 1e-6));
        expect(disabled[i].width, closeTo(straight[i].width, 1e-6));
        expect(disabled[i].isWave, isFalse);
      }
    });

    test('hair 7:3 means only the endpoint-side 30 percent is waved', () {
      final path = buildWaveFoldPath(
        _event(width: 24),
        curveStartRatio: .2,
        depthRatio: .5,
        lengthRatio: 1,
        waveEndRatio: .3,
        waveTriggerAngleDegrees: 45,
      );
      final firstWave = path.indexWhere((sample) => sample.isWave);

      expect(firstWave, greaterThan(0));
      expect(path[firstWave].distanceFromStart, closeTo(14, 1.2));
      expect(path.last.distanceFromStart, closeTo(20, .2));
    });

    test('bangs with zero wave percentage never emit wave samples', () {
      final path = buildWaveFoldPath(
        _event(width: 24),
        curveStartRatio: .2,
        depthRatio: .5,
        lengthRatio: 1,
        waveEndRatio: 0,
        waveTriggerAngleDegrees: 45,
      );

      expect(path.every((sample) => !sample.isWave), isTrue);
    });
  });
}
