import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_render_plan.dart';
import 'package:niarim/models/brush.dart';

void main() {
  Brush brush({
    bool lateral = false,
    int count = 1,
    double lateralSpacing = 1,
    bool outline = false,
    double outlineWidth = 1.5,
    BrushTipShape tip = BrushTipShape.round,
  }) => Brush(
    id: 'test',
    name: 'test',
    size: 20,
    opacity: 100,
    spacing: 1,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    fadeMode: FadeMode.off,
    strokeDecay: false,
    lateralRepeatEnabled: lateral,
    lateralRepeatCount: count,
    lateralRepeatSpacing: lateralSpacing,
    outlineEnabled: outline,
    outlineWidth: outlineWidth,
    tipShape: tip,
  );

  test('disabled extension keeps exactly one center stamp', () {
    final plan = buildBrushStampPlan(
      brush: brush(),
      center: const Offset(20, 30),
      pathAngle: 0,
      effectiveSize: 20,
    );
    expect(plan.centers, const [Offset(20, 30)]);
    expect(plan.outlineRadius, isNull);
  });

  test('lateral spacing scales with effective brush size', () {
    final plan = buildBrushStampPlan(
      brush: brush(lateral: true, count: 4, lateralSpacing: .5),
      center: Offset.zero,
      pathAngle: 0,
      effectiveSize: 20,
    );
    expect(plan.centers, const [
      Offset(0, -15),
      Offset(0, -5),
      Offset(0, 5),
      Offset(0, 15),
    ]);
  });

  test('outline expands outside fill without changing fill radius', () {
    final plan = buildBrushStampPlan(
      brush: brush(outline: true, outlineWidth: 1.5),
      center: Offset.zero,
      pathAngle: 0,
      effectiveSize: 20,
    );
    expect(plan.fillRadius, 10);
    expect(plan.outlineRadius, 11.5);
  });

  test('hollow square keeps a real center opening', () {
    final plan = buildBrushStampPlan(
      brush: brush(tip: BrushTipShape.hollowSquare),
      center: Offset.zero,
      pathAngle: 0,
      effectiveSize: 20,
    );
    expect(plan.hollowSquare, isTrue);
    expect(plan.hollowSquareInnerRatio, greaterThan(0));
    expect(plan.hollowSquareInnerRatio, lessThan(1));
  });
}
