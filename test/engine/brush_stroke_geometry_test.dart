import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';
import 'package:niarim/engine/hair_fold_raster.dart';

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
      expect(centers, const [
        Offset(100, 90),
        Offset(100, 100),
        Offset(100, 110),
      ]);
    });
  });

  group('stroke fold vertices', () {
    List<HairRibbonPoint> strand(List<Offset> path, {double width = 20}) => [
      for (final p in path) HairRibbonPoint(p, width, 1),
    ];
    List<Offset> arc(double degrees, {double radius = 60, double step = 5}) {
      final count = (degrees.abs() / step).ceil();
      final sign = degrees.sign;
      return [
        for (var i = 0; i <= count; i++)
          Offset(
            radius * math.cos(sign * i * step * math.pi / 180),
            radius * math.sin(sign * i * step * math.pi / 180),
          ),
      ];
    }

    List<({int index, bool continuous})> folds(List<Offset> path) =>
        HairFoldRaster.foldVertices(strand(path));

    test('jitter and gentle motion do not fold', () {
      final points = <Offset>[
        for (var i = 0; i < 80; i++) Offset(i * 3.0, i.isEven ? 0 : .6),
      ];
      expect(folds(points), isEmpty);
      expect(folds(arc(80, radius: 400, step: 1)), isEmpty);
    });

    test('a sharp corner folds at the corner', () {
      final points = <Offset>[
        for (var x = 0; x <= 60; x += 2) Offset(x.toDouble(), 0),
        for (var y = 2; y <= 60; y += 2) Offset(60, y.toDouble()),
      ];
      final result = folds(points);
      expect(result, hasLength(1));
      expect(
        (points[result.single.index] - const Offset(60, 0)).distance,
        lessThan(8),
      );
    });

    test('a hand-drawn wave folds at every apex', () {
      final points = <Offset>[
        for (var i = 0; i <= 240; i++)
          Offset(60 * math.sin(i * math.pi / 60), i * 2.0),
      ];
      final result = folds(points);
      expect(result, hasLength(4));
      for (final fold in result) {
        expect(points[fold.index].dx.abs(), greaterThan(50));
        expect(fold.continuous, isFalse);
      }
    });

    test('continuous turning folds once per completed 270 degrees', () {
      expect(folds(arc(265)), isEmpty);
      expect(folds(arc(275)), hasLength(1));
      expect(folds(arc(535)), hasLength(1));
      expect(folds(arc(545)), hasLength(2));
      expect(folds(arc(815)), hasLength(3));
      expect(folds(arc(275)).single.continuous, isTrue);
    });

    test('continuous folds do not depend on the turn direction', () {
      expect(folds(arc(545)), hasLength(2));
      expect(folds(arc(-545)), hasLength(2));
    });

    test('a crescent curls a lone bend before a full turn', () {
      final points = strand(arc(90, radius: 180, step: 1), width: 40);
      expect(HairFoldRaster.foldVertices(points, triggerDegrees: 30), isEmpty);
      expect(
        HairFoldRaster.foldVertices(points, triggerDegrees: 30, crescent: true),
        hasLength(1),
      );
    });
  });
}
