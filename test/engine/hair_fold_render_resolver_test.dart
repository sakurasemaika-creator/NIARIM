import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';
import 'package:niarim/engine/hair_fold_render_resolver.dart';
import 'package:niarim/engine/wave_hair_fold_geometry.dart';
import 'package:niarim/models/brush.dart';

FoldEvent _event() => FoldEvent(
      sample: const BrushStrokeSample(
        screenPosition: Offset(40, 40),
        documentPosition: Offset(100, 100),
        effectiveWidth: 20,
      ),
      tangent: const Offset(1, 0),
      inwardNormal: const Offset(0, 1),
      signedTurnRadians: 1.8,
      screenDistance: 40,
      sourceCurve: const [
        Offset(10, 10),
        Offset(30, 28),
        Offset(50, 46),
        Offset(70, 28),
        Offset(90, 10),
      ],
    );

List<WaveFoldPathSample> _resolve(HairFoldMode mode) =>
    resolveHairFoldRenderPath(
      event: _event(),
      mode: mode,
      curveStartRatio: .2,
      curveStrength: 5,
      lengthRatio: 1.5,
      waveEndRatio: .7,
      waveTriggerAngleDegrees: 45,
    );

void main() {
  test('resolver preserves the user curve for four depth-order modes', () {
    final source = _event().sourceCurve;
    for (final mode in const [
      HairFoldMode.waveTopView,
      HairFoldMode.waveLowAngle,
      HairFoldMode.curlRight,
      HairFoldMode.curlLeft,
    ]) {
      final path = _resolve(mode);
      expect(path.map((s) => s.position).toList(), source);
      expect(path.every((s) => !s.isWave), isTrue);
    }
  });

  test('resolver exposes inverse top and low-angle depth ordering', () {
    final top = _resolve(HairFoldMode.waveTopView);
    final low = _resolve(HairFoldMode.waveLowAngle);
    for (var i = 0; i < top.length; i++) {
      expect(top[i].isForeground, isNot(low[i].isForeground));
    }
  });

  test('resolver exposes inverse right and left curl depth ordering', () {
    final right = _resolve(HairFoldMode.curlRight);
    final left = _resolve(HairFoldMode.curlLeft);
    for (var i = 0; i < right.length; i++) {
      expect(right[i].isForeground, isNot(left[i].isForeground));
    }
  });

  test('crescent remains anchored to user-curve endpoints', () {
    final source = _event().sourceCurve;
    final crescent = _resolve(HairFoldMode.crescent);
    expect(crescent.first.position, source.first);
    expect(crescent.last.position.dx, closeTo(source.last.dx, 1e-6));
    expect(crescent.last.position.dy, closeTo(source.last.dy, 1e-6));
  });
}
