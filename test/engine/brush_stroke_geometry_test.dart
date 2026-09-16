import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';

void main() {
  group('lateral repeat geometry', () {
    test('centers even counts symmetrically around stroke', () {
      expect(lateralOffsets(count: 4, spacing: 10), [-15, -5, 5, 15]);
      expect(lateralOffsets(count: 0, spacing: 10), [0]);
      expect(lateralOffsets(count: 99, spacing: 10).length, 10);
    });

    test('centers follow the local normal', () {
      final centers = lateralCenters(
        center: const Offset(20, 30),
        tangent: const Offset(1, 0),
        count: 3,
        spacing: 5,
      );
      expect(centers, const [Offset(20, 25), Offset(20, 30), Offset(20, 35)]);
    });
  });

  group('screen-space fold detector', () {
    List<FoldEvent> feed(List<Offset> points, {double zoom = 1}) {
      final detector = ScreenSpaceFoldDetector();
      final events = <FoldEvent>[];
      for (final p in points) {
        final event = detector.add(
          BrushStrokeSample(
            screenPosition: p,
            documentPosition: p / zoom,
            effectiveWidth: 20 / zoom,
          ),
        );
        if (event != null) events.add(event);
      }
      return events;
    }

    test('gentle path and jitter do not trigger', () {
      final straight = [for (var x = 0.0; x <= 80; x += 2) Offset(x, x * .03)];
      expect(feed(straight), isEmpty);
      expect(feed(const [Offset.zero, Offset(.2, -.1), Offset(-.1, .1)]), isEmpty);
    });

    test('sharp left and right turns point inward', () {
      final left = <Offset>[
        for (var x = 0.0; x <= 30; x += 2) Offset(x, 0),
        for (var y = 2.0; y <= 34; y += 2) Offset(30, -y),
      ];
      final right = <Offset>[
        for (var x = 0.0; x <= 30; x += 2) Offset(x, 0),
        for (var y = 2.0; y <= 34; y += 2) Offset(30, y),
      ];
      final le = feed(left).first;
      final re = feed(right).first;
      expect(le.inwardNormal.dy, lessThan(0));
      expect(re.inwardNormal.dy, greaterThan(0));
    });

    test('screen-space result is independent of document zoom', () {
      final path = <Offset>[
        for (var x = 0.0; x <= 30; x += 2) Offset(x, 0),
        for (var y = 2.0; y <= 34; y += 2) Offset(30, y),
      ];
      expect(feed(path, zoom: 1).length, feed(path, zoom: 4).length);
    });

    test('fold Y uses effective width ratios and tapers to zero', () {
      const event = FoldEvent(
        sample: BrushStrokeSample(
          screenPosition: Offset(10, 10),
          documentPosition: Offset(20, 20),
          effectiveWidth: 40,
        ),
        tangent: Offset(1, 0),
        inwardNormal: Offset(0, 1),
        signedTurnRadians: 1.7,
        screenDistance: 30,
      );
      final branches = buildFoldY(
        event,
        branchAngleDegrees: 45,
        lengthRatio: .5,
        widthRatio: .1,
        taperRatio: .5,
      );
      expect(branches, hasLength(3));
      expect(branches.first.width, 4);
      expect((branches.first.end - branches.first.start).distance, closeTo(20, .001));
      expect(branches.first.widthAt(0), 4);
      expect(branches.first.widthAt(1), 0);
    });
  });
}
