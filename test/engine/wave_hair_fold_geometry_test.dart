import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';
import 'package:niarim/engine/wave_hair_fold_geometry.dart';
import 'package:niarim/models/brush.dart';

FoldEvent event({
  double width = 20,
  double turn = 1.8,
  Offset inward = const Offset(0, 1),
  List<Offset>? curve,
}) =>
    FoldEvent(
      sample: BrushStrokeSample(
        screenPosition: const Offset(40, 40),
        documentPosition: const Offset(100, 100),
        effectiveWidth: width,
      ),
      tangent: const Offset(1, 0),
      inwardNormal: inward,
      signedTurnRadians: turn,
      screenDistance: 40,
      sourceCurve: curve ??
          const [
            Offset(10, 10),
            Offset(30, 16),
            Offset(50, 32),
            Offset(66, 56),
            Offset(78, 84),
          ],
    );

List<WaveFoldPathSample> build(
  HairFoldMode mode, {
  FoldEvent? fold,
  double width = 2,
}) =>
    buildWaveFoldPath(
      fold ?? event(),
      mode: mode,
      curveStartRatio: .2,
      curveStrength: 5,
      lengthRatio: 1,
      waveEndRatio: 1,
      waveTriggerAngleDegrees: 45,
      outlineWidth: width,
    );

void main() {
  group('Hair fold modes use the user-drawn curve', () {
    test('non-crescent modes preserve every source-curve position', () {
      final fold = event();
      for (final mode in const [
        HairFoldMode.waveTopView,
        HairFoldMode.waveLowAngle,
        HairFoldMode.curlRight,
        HairFoldMode.curlLeft,
      ]) {
        final path = build(mode, fold: fold);
        expect(path.length, fold.sourceCurve.length);
        for (var i = 0; i < path.length; i++) {
          expect(path[i].position, fold.sourceCurve[i]);
          expect(path[i].isWave, isFalse);
        }
      }
    });

    test('top and low-angle views invert foreground depth', () {
      final top = build(HairFoldMode.waveTopView);
      final low = build(HairFoldMode.waveLowAngle);
      expect(top.length, low.length);
      for (var i = 0; i < top.length; i++) {
        expect(top[i].isForeground, isNot(low[i].isForeground));
      }
    });

    test('right and left curls invert foreground depth', () {
      final right = build(HairFoldMode.curlRight);
      final left = build(HairFoldMode.curlLeft);
      expect(right.length, left.length);
      for (var i = 0; i < right.length; i++) {
        expect(right[i].isForeground, isNot(left[i].isForeground));
      }
    });

    test('local direction can change depth within one curved stroke', () {
      final fold = event(curve: const [
        Offset(10, 10),
        Offset(30, 30),
        Offset(50, 50),
        Offset(70, 30),
        Offset(90, 10),
      ]);
      final right = build(HairFoldMode.curlRight, fold: fold);
      expect(right.any((s) => s.isForeground), isTrue);
      expect(right.any((s) => !s.isForeground), isTrue);
    });

    test('crescent follows the same endpoints and bends inward', () {
      final fold = event();
      final crescent = build(HairFoldMode.crescent, fold: fold);
      expect(crescent.length, fold.sourceCurve.length);
      expect(crescent.first.position, fold.sourceCurve.first);
      expect(crescent.last.position.dx, closeTo(fold.sourceCurve.last.dx, 1e-6));
      expect(crescent.last.position.dy, closeTo(fold.sourceCurve.last.dy, 1e-6));
      expect(
        List.generate(
          crescent.length,
          (i) => (crescent[i].position - fold.sourceCurve[i]).distance,
        ).reduce((a, b) => a > b ? a : b),
        greaterThan(0),
      );
    });

    test('outline width scales independently of centerline geometry', () {
      final narrow = build(HairFoldMode.waveTopView, width: 2);
      final wide = build(HairFoldMode.waveTopView, width: 4);
      expect(wide.first.width, closeTo(narrow.first.width * 2, 1e-6));
      for (var i = 0; i < narrow.length; i++) {
        expect(wide[i].position, narrow[i].position);
      }
    });
  });
}
