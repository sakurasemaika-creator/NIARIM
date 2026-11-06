import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/fisheye_perspective.dart';
import 'package:niarim/engine/ruler_engine.dart';
import 'package:niarim/models/ruler.dart';

/// The fisheye (five-point curvilinear) perspective: horizontal lines are
/// arcs through the left and right vanishing points on the lens circle,
/// vertical lines arcs through the top and bottom ones, depth lines meet
/// at the centre; a stroke follows the one it starts along.
void main() {
  const r = 100.0;

  /// How far [q] is from [curve].
  double off(FisheyeCurve curve, Offset q) => (curve.project(q) - q).distance;

  test('the three lines through a point meet their vanishing points', () {
    const p = Offset(30, -40);
    final horizontal = fisheyeCurveThrough(FisheyeDirection.horizontal, p, r);
    final vertical = fisheyeCurveThrough(FisheyeDirection.vertical, p, r);
    final depth = fisheyeCurveThrough(FisheyeDirection.depth, p, r);
    for (final curve in [horizontal, vertical, depth]) {
      expect(off(curve, p), lessThan(1e-9), reason: 'through the point');
    }
    expect(off(horizontal, const Offset(-r, 0)), lessThan(1e-9));
    expect(off(horizontal, const Offset(r, 0)), lessThan(1e-9));
    expect(off(vertical, const Offset(0, -r)), lessThan(1e-9));
    expect(off(vertical, const Offset(0, r)), lessThan(1e-9));
    expect(off(depth, Offset.zero), lessThan(1e-9));
    // Above the horizon the horizontal arc bows up, away from the centre.
    expect(horizontal.project(const Offset(0, -40)).dy, lessThan(-40));
  });

  test('the axes are straight lines', () {
    final horizon = fisheyeCurveThrough(
      FisheyeDirection.horizontal,
      const Offset(20, 0),
      r,
    );
    expect(horizon.isLine, isTrue);
    expect(horizon.project(const Offset(50, 30)), const Offset(50, 0));
    final vertical = fisheyeCurveThrough(
      FisheyeDirection.vertical,
      const Offset(0, -60),
      r,
    );
    expect(vertical.isLine, isTrue);
    expect(vertical.project(const Offset(-20, 10)), const Offset(0, 10));
  });

  test('a stroke follows the line nearest the way it starts', () {
    const p = Offset(30, -40);
    final horizontal = fisheyeCurveAlong(p, const Offset(1, 0.1), r);
    expect(off(horizontal, const Offset(r, 0)), lessThan(1e-9));
    expect(off(horizontal, const Offset(-r, 0)), lessThan(1e-9));
    final vertical = fisheyeCurveAlong(p, const Offset(0.1, 1), r);
    expect(off(vertical, const Offset(0, r)), lessThan(1e-9));
    final depth = fisheyeCurveAlong(p, p, r);
    expect(off(depth, Offset.zero), lessThan(1e-9));
    // From the centre any direction is a depth line.
    final fromCentre = fisheyeCurveAlong(Offset.zero, const Offset(1, 1), r);
    expect(off(fromCentre, const Offset(50, 50)), lessThan(1e-9));
  });

  test('the ruler snaps a whole stroke onto one arc, rotated and moved', () {
    const centre = Offset(500, 400);
    const tilt = 0.3;
    final engine = RulerEngine()
      ..setActiveRuler(
        const Ruler(
          type: RulerType.fisheyePerspective,
          position: centre,
          rotation: tilt,
          settings: RulerSettings(radiusX: r),
        ),
      );
    Offset world(Offset local) =>
        centre +
        Offset(
          local.dx * math.cos(tilt) - local.dy * math.sin(tilt),
          local.dx * math.sin(tilt) + local.dy * math.cos(tilt),
        );
    Offset local(Offset world) {
      final d = world - centre;
      return Offset(
        d.dx * math.cos(tilt) + d.dy * math.sin(tilt),
        -d.dx * math.sin(tilt) + d.dy * math.cos(tilt),
      );
    }

    engine.beginStroke(directionDistance: 5);
    final start = world(const Offset(-40, -35));
    expect(engine.snapToRuler(start), start);
    // Until it has moved far enough to tell the direction, it stays put.
    expect(engine.snapToRuler(world(const Offset(-38, -35))), start);
    final arc = fisheyeCurveThrough(
      FisheyeDirection.horizontal,
      const Offset(-40, -35),
      r,
    );
    // The finger goes straight across; the line bends with the lens.
    for (var x = -30.0; x <= 60; x += 10) {
      final snapped = local(engine.snapToRuler(world(Offset(x, -35))));
      expect(off(arc, snapped), lessThan(1e-6));
    }
    final top = local(engine.snapToRuler(world(const Offset(0, -35))));
    expect(top.dy, lessThan(-40), reason: 'bowed up in the middle');

    // A new stroke starting downwards follows a vertical arc instead.
    engine.beginStroke(directionDistance: 5);
    final down = world(const Offset(50, -20));
    engine.snapToRuler(down);
    final vertical = fisheyeCurveThrough(
      FisheyeDirection.vertical,
      const Offset(50, -20),
      r,
    );
    for (var y = -10.0; y <= 60; y += 10) {
      final snapped = local(engine.snapToRuler(world(Offset(50, y))));
      expect(off(vertical, snapped), lessThan(1e-6));
    }
  });

  test('the guide is drawn inside the lens', () {
    final bounds = fisheyeGuidePath(r).getBounds();
    expect(bounds.left, closeTo(-r, 0.5));
    expect(bounds.right, closeTo(r, 0.5));
    expect(bounds.top, closeTo(-r, 0.5));
    expect(bounds.bottom, closeTo(r, 0.5));
  });
}
