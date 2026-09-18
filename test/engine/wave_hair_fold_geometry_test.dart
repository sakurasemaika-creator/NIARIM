import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';
import 'package:niarim/engine/wave_hair_fold_geometry.dart';

FoldEvent event({
  double width = 20,
  double turn = 1.8,
  Offset inward = const Offset(0, 1),
}) => FoldEvent(
      sample: BrushStrokeSample(
        screenPosition: const Offset(40, 40),
        documentPosition: const Offset(100, 100),
        effectiveWidth: width,
      ),
      tangent: const Offset(1, 0),
      inwardNormal: inward,
      signedTurnRadians: turn,
      screenDistance: 40,
    );

void main() {
  group('Wave hair fold geometry', () {
    test('wave section occupies requested percentage from endpoint', () {
      final path = buildWaveFoldPath(
        event(),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1,
        waveEndRatio: .3,
        waveTriggerAngleDegrees: 45,
      );
      expect(path, isNotEmpty);
      final firstWave = path.indexWhere((sample) => sample.isWave);
      expect(firstWave, greaterThan(0));
      expect(path[firstWave].distanceFromStart, closeTo(14, 1.2));
      expect(path.last.distanceFromStart, closeTo(20, .2));
    });

    test('wave thickness follows pressure resolved effective brush width', () {
      final narrow = buildWaveFoldPath(
        event(width: 20),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1,
        waveEndRatio: 1,
        waveTriggerAngleDegrees: 45,
      );
      final wide = buildWaveFoldPath(
        event(width: 40),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1,
        waveEndRatio: 1,
        waveTriggerAngleDegrees: 45,
      );
      expect(wide.map((e) => e.width).reduce((a, b) => a > b ? a : b),
          closeTo(narrow.map((e) => e.width).reduce((a, b) => a > b ? a : b) * 2, 1));
    });

    test('adjacent crescents alternate around the fold centerline', () {
      final path = buildWaveFoldPath(
        event(width: 24),
        curveStartRatio: .15,
        curveStrength: 5,
        lengthRatio: 1.5,
        waveEndRatio: 1,
        waveTriggerAngleDegrees: 45,
      );
      final wave = path.where((sample) => sample.isWave).toList();
      expect(wave.any((sample) => sample.waveSide > 0), isTrue);
      expect(wave.any((sample) => sample.waveSide < 0), isTrue);
    });

    test('first curve is an open pen transition and later lobes close at midpoints', () {
      final path = buildWaveFoldPath(
        event(width: 20),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1.6,
        waveEndRatio: 1,
        waveTriggerAngleDegrees: 45,
      );
      final wave = path.where((sample) => sample.isWave).toList();
      expect(wave.first.isTransition, isTrue);
      expect(wave.skip(1).any((sample) => sample.isJoin), isTrue);
    });

    test('wave trigger angle keeps shallow bends straight', () {
      final shallow = buildWaveFoldPath(
        event(turn: .5),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1,
        waveEndRatio: 1,
        waveTriggerAngleDegrees: 45,
      );
      expect(shallow.every((sample) => !sample.isWave), isTrue);
    });

    test('zero wave percentage is identical to straight mode positions', () {
      final straight = buildStraightFoldPath(
        event(),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1,
        taperRatio: .35,
      );
      final waveOff = buildWaveFoldPath(
        event(),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1,
        waveEndRatio: 0,
        waveTriggerAngleDegrees: 45,
        taperRatio: .35,
      );
      expect(waveOff.length, straight.length);
      for (var i = 0; i < straight.length; i++) {
        expect(waveOff[i].position.dx, closeTo(straight[i].position.dx, 1e-6));
        expect(waveOff[i].position.dy, closeTo(straight[i].position.dy, 1e-6));
      }
    });
  });
}
