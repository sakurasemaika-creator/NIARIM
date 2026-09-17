import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';
import 'package:niarim/engine/hair_fold_render_resolver.dart';

FoldEvent _event({double width = 20, double turn = 1.8}) => FoldEvent(
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
  test('wave toggle alone controls whether wave percentage is applied', () {
    final disabled = resolveHairFoldRenderPath(
      event: _event(),
      waveEnabled: false,
      curveStartRatio: .2,
      depthRatio: .5,
      lengthRatio: 1.5,
      waveEndRatio: .7,
      waveTriggerAngleDegrees: 45,
    );
    final enabled = resolveHairFoldRenderPath(
      event: _event(),
      waveEnabled: true,
      curveStartRatio: .2,
      depthRatio: .5,
      lengthRatio: 1.5,
      waveEndRatio: .7,
      waveTriggerAngleDegrees: 45,
    );

    expect(disabled.every((sample) => !sample.isWave), isTrue);
    expect(enabled.any((sample) => sample.isWave), isTrue);
  });

  test('30 percent wave remains confined to endpoint side', () {
    final path = resolveHairFoldRenderPath(
      event: _event(width: 24),
      waveEnabled: true,
      curveStartRatio: .2,
      depthRatio: .5,
      lengthRatio: 1,
      waveEndRatio: .3,
      waveTriggerAngleDegrees: 45,
    );
    final firstWave = path.indexWhere((sample) => sample.isWave);

    expect(firstWave, greaterThan(0));
    expect(path[firstWave].distanceFromStart, closeTo(16.8, 1.2));
    expect(path.last.distanceFromStart, closeTo(24, .2));
  });

  test('zero percent wave is straight even when wave toggle is on', () {
    final path = resolveHairFoldRenderPath(
      event: _event(),
      waveEnabled: true,
      curveStartRatio: .2,
      depthRatio: .5,
      lengthRatio: 1,
      waveEndRatio: 0,
      waveTriggerAngleDegrees: 45,
    );

    expect(path.every((sample) => !sample.isWave), isTrue);
  });
}
