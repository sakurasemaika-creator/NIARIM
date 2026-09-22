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
      expect(centers, const [
        Offset(100, 90),
        Offset(100, 100),
        Offset(100, 110),
      ]);
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
}
