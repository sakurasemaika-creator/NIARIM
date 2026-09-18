import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';

FoldEvent event({
  double width = 20,
  Offset tangent = const Offset(1, 0),
  Offset inward = const Offset(0, 1),
  double turn = 1.8,
}) => FoldEvent(
      sample: BrushStrokeSample(
        screenPosition: const Offset(40, 40),
        documentPosition: const Offset(100, 100),
        effectiveWidth: width,
      ),
      tangent: tangent,
      inwardNormal: inward,
      signedTurnRadians: turn,
      screenDistance: 40,
    );

void main() {
  group('Straight hair fold geometry', () {
    test('length follows effective brush width ratio', () {
      final narrow = buildStraightFoldPath(
        event(width: 20),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: .8,
        taperRatio: 0,
        outlineWidth: 2,
      );
      final wide = buildStraightFoldPath(
        event(width: 40),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: .8,
        taperRatio: 0,
        outlineWidth: 2,
      );
      expect(narrow.last.distanceFromStart, closeTo(16, .05));
      expect(wide.last.distanceFromStart, closeTo(32, .1));
    });

    test('left and right bends stay on their inward side', () {
      final left = buildStraightFoldPath(
        event(inward: const Offset(0, 1), turn: 1.8),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: .8,
        taperRatio: .4,
      );
      final right = buildStraightFoldPath(
        event(inward: const Offset(0, -1), turn: -1.8),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: .8,
        taperRatio: .4,
      );
      expect(left.last.position.dy, greaterThan(100));
      expect(right.last.position.dy, lessThan(100));
    });

    test('larger curve start delays inward movement', () {
      final early = buildStraightFoldPath(
        event(),
        curveStartRatio: .1,
        curveStrength: 5,
        lengthRatio: 1,
        taperRatio: 0,
      );
      final late = buildStraightFoldPath(
        event(),
        curveStartRatio: .5,
        curveStrength: 5,
        lengthRatio: 1,
        taperRatio: 0,
      );
      final earlyQuarter = early[early.length ~/ 4].position.dy - 100;
      final lateQuarter = late[late.length ~/ 4].position.dy - 100;
      expect(earlyQuarter, greaterThan(lateQuarter));
    });

    test('effective width automatically controls fold depth', () {
      final narrow = buildStraightFoldPath(
        event(width: 20),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1,
        taperRatio: 0,
      );
      final wide = buildStraightFoldPath(
        event(width: 40),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: 1,
        taperRatio: 0,
      );
      final narrowDepth = narrow.last.position.dy - 100;
      final wideDepth = wide.last.position.dy - 100;
      expect(narrowDepth, greaterThan(0));
      expect(wideDepth, greaterThan(narrowDepth));
      expect(wideDepth / narrowDepth, closeTo(2, .05));
    });

    test('curve strength changes bend magnitude around neutral five', () {
      List<FoldPathSample> path(int strength) => buildStraightFoldPath(
            event(),
            curveStartRatio: .2,
            curveStrength: strength,
            lengthRatio: 1,
            taperRatio: 0,
          );
      double midDepth(int strength) {
        final samples = path(strength);
        return samples[samples.length ~/ 2].position.dy - 100;
      }
      final gentle = midDepth(1);
      final neutral = midDepth(5);
      final tight = midDepth(10);
      expect(gentle, lessThan(neutral));
      expect(neutral, lessThan(tight));
    });

    test('fold line uses outline width and tapers at endpoint', () {
      final noTaper = buildStraightFoldPath(
        event(),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: .8,
        taperRatio: 0,
        outlineWidth: 3,
      );
      final taper = buildStraightFoldPath(
        event(),
        curveStartRatio: .2,
        curveStrength: 5,
        lengthRatio: .8,
        taperRatio: .5,
        outlineWidth: 3,
      );
      expect(noTaper.first.width, 3);
      expect(noTaper.last.width, 3);
      expect(taper.first.width, 3);
      expect(taper.last.width, closeTo(0, 1e-9));
    });

    test('invalid effective width is rejected', () {
      expect(
        buildStraightFoldPath(
          event(width: 0),
          curveStartRatio: .2,
          curveStrength: 5,
          lengthRatio: .8,
          taperRatio: .4,
        ),
        isEmpty,
      );
    });
  });
}
