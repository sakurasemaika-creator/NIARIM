import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';

void main() {
  group('lateral repeat geometry', () {
    test('four columns are centered symmetrically', () {
      expect(lateralOffsets(count: 4, spacing: 10), [-15.0, -5.0, 5.0, 15.0]);
    });

    test('count is clamped to one through ten', () {
      expect(lateralOffsets(count: 0, spacing: 10), [0.0]);
      expect(lateralOffsets(count: 99, spacing: 10).length, 10);
    });

    test('centers follow the local normal', () {
      final centers = lateralCenters(
        center: const Offset(100, 100),
        tangent: const Offset(1, 0),
        count: 3,
        spacing: 10,
      );
      expect(centers, const [Offset(100, 90), Offset(100, 100), Offset(100, 110)]);
    });
  });

  group('screen-space fold detector', () {
    List<FoldEvent> runPath(List<Offset> screen, {double documentScale = 1}) {
      final detector = ScreenSpaceFoldDetector(
        triggerAngleDegrees: 80,
        sampleSpacing: 2,
        minimumTravel: 10,
        windowLength: 44,
        cooldownDistance: 20,
      );
      final events = <FoldEvent>[];
      for (final point in screen) {
        final event = detector.add(
          BrushStrokeSample(
            screenPosition: point,
            documentPosition: point * documentScale,
            effectiveWidth: 20 * documentScale,
          ),
        );
        if (event != null) events.add(event);
      }
      return events;
    }

    test('jitter and gentle motion do not fire', () {
      final points = <Offset>[
        for (var x = 0; x <= 50; x += 2)
          Offset(x.toDouble(), x.isEven ? .2 : -.2),
      ];
      expect(runPath(points), isEmpty);
    });

    test('a meaningful sharp bend fires', () {
      final points = <Offset>[
        for (var x = 0; x <= 30; x += 2) Offset(x.toDouble(), 0),
        for (var y = 2; y <= 32; y += 2) Offset(30, y.toDouble()),
      ];
      expect(runPath(points), isNotEmpty);
    });

    test('document zoom does not change screen-space detection', () {
      final points = <Offset>[
        for (var x = 0; x <= 30; x += 2) Offset(x.toDouble(), 0),
        for (var y = 2; y <= 32; y += 2) Offset(30, y.toDouble()),
      ];
      expect(
        runPath(points, documentScale: 1).length,
        runPath(points, documentScale: 8).length,
      );
    });

    test('opposite bend signs both point toward their curve interior', () {
      final down = <Offset>[
        for (var x = 0; x <= 30; x += 2) Offset(x.toDouble(), 0),
        for (var y = 2; y <= 32; y += 2) Offset(30, y.toDouble()),
      ];
      final up = <Offset>[
        for (var x = 0; x <= 30; x += 2) Offset(x.toDouble(), 0),
        for (var y = -2; y >= -32; y -= 2) Offset(30, y.toDouble()),
      ];
      final a = runPath(down).first;
      final b = runPath(up).first;
      expect(a.signedTurnRadians.sign, -b.signedTurnRadians.sign);
      expect(a.inwardNormal.dx, lessThan(0));
      expect(b.inwardNormal.dx, lessThan(0));
    });
  });

  group('straight hair fold geometry', () {
    const event = FoldEvent(
      sample: BrushStrokeSample(
        screenPosition: Offset.zero,
        documentPosition: Offset(50, 50),
        effectiveWidth: 40,
      ),
      tangent: Offset(1, 0),
      inwardNormal: Offset(0, 1),
      signedTurnRadians: 1.5707963267948966,
      screenDistance: 40,
    );

    test('length follows effective width and fold depth is automatic', () {
      final path = buildStraightFoldPath(
        event,
        curveStartRatio: .25,
        curveStrength: 5,
        lengthRatio: .75,
        taperRatio: .4,
      );
      expect(path.length, greaterThan(3));
      expect(path.last.distanceFromStart, closeTo(30, 1.0));
      expect(path.map((p) => p.position.dy).reduce((a, b) => a > b ? a : b),
          greaterThanOrEqualTo(39));
    });

    test('curve strength 5 is neutral and 1/10 relax/tighten the bend', () {
      List<FoldPathSample> path(int strength) => buildStraightFoldPath(
        event,
        curveStartRatio: .25,
        curveStrength: strength,
        lengthRatio: .8,
        taperRatio: .4,
      );
      final gentle = path(1);
      final neutral = path(5);
      final tight = path(10);
      double inwardAtMid(List<FoldPathSample> p) =>
          p[p.length ~/ 2].position.dy - event.sample.documentPosition.dy;
      expect(inwardAtMid(gentle), lessThan(inwardAtMid(neutral)));
      expect(inwardAtMid(neutral), lessThan(inwardAtMid(tight)));
    });

    test('curve-start ratio delays bending without changing initial tangent', () {
      final early = buildStraightFoldPath(
        event,
        curveStartRatio: .1,
        curveStrength: 5,
        lengthRatio: .8,
        taperRatio: .4,
      );
      final late = buildStraightFoldPath(
        event,
        curveStartRatio: .6,
        curveStrength: 5,
        lengthRatio: .8,
        taperRatio: .4,
      );
      final earlyFirstBend = early.indexWhere(
        (sample) => (sample.position.dy - early.first.position.dy).abs() > .25,
      );
      final lateFirstBend = late.indexWhere(
        (sample) => (sample.position.dy - late.first.position.dy).abs() > .25,
      );
      expect(earlyFirstBend, greaterThan(0));
      expect(lateFirstBend, greaterThan(earlyFirstBend));
      expect(
        (late[1].position - late.first.position).dy.abs(),
        lessThan(.25),
      );
    });

    test('terminal taper reaches zero while start uses outline width', () {
      final path = buildStraightFoldPath(
        event,
        curveStartRatio: .25,
        curveStrength: 5,
        lengthRatio: .75,
        taperRatio: .5,
        outlineWidth: 6,
      );
      expect(path.first.width, 6);
      expect(path[path.length ~/ 3].width, closeTo(6, .01));
      expect(path.last.width, 0);
    });

    test('opposite turns mirror the inward fold side', () {
      final opposite = FoldEvent(
        sample: event.sample,
        tangent: event.tangent,
        inwardNormal: const Offset(0, -1),
        signedTurnRadians: -event.signedTurnRadians,
        screenDistance: event.screenDistance,
      );
      final a = buildStraightFoldPath(
        event,
        curveStartRatio: .25,
        curveStrength: 5,
        lengthRatio: .75,
        taperRatio: .4,
      );
      final b = buildStraightFoldPath(
        opposite,
        curveStartRatio: .25,
        curveStrength: 5,
        lengthRatio: .75,
        taperRatio: .4,
      );
      expect(a.last.position.dx, closeTo(b.last.position.dx, .001));
      expect(a.last.position.dy - 50, closeTo(-(b.last.position.dy - 50), .001));
    });
  });

  test('legacy fold Y still uses effective-width ratios during migration', () {
    const event = FoldEvent(
      sample: BrushStrokeSample(
        screenPosition: Offset.zero,
        documentPosition: Offset(50, 50),
        effectiveWidth: 40,
      ),
      tangent: Offset(1, 0),
      inwardNormal: Offset(0, 1),
      signedTurnRadians: 1.8,
      screenDistance: 40,
    );
    final branches = buildFoldY(
      event,
      branchAngleDegrees: 45,
      lengthRatio: .5,
      widthRatio: .1,
      taperRatio: .5,
    );
    expect(branches.length, 3);
    expect(branches.first.length, closeTo(20, .001));
    expect(branches.first.width, 4);
    expect(branches.first.widthAt(1), 0);
  });
}
