import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';

void main() {
  Brush base() => const Brush(
        id: 'x',
        name: 'x',
        size: 20,
        opacity: 100,
        spacing: 1,
        stabilization: false,
        stabilizationStrength: 0,
        pixelMode: false,
        fadeMode: FadeMode.off,
        strokeDecay: false,
      );

  test('approved outline and fold defaults are retained', () {
    final brush = base();
    // These expectations intentionally remain RED until Brush itself uses the
    // approved canonical defaults. Keeping the failing contract visible avoids
    // silently shipping the stale 1.0/.12 values.
    expect(brush.outlineWidth, 1.5);
    expect(brush.outlineColor, 0xff000000);
    expect(brush.yBranchWidthRatio, .08);
    expect(brush.yBranchLengthRatio, .6);
    expect(brush.yBranchEndTaperRatio, .4);
  });

  test('malformed repeat count is bounded on copy', () {
    expect(base().copyWith(lateralRepeatCount: -3).lateralRepeatCount, 1);
    expect(base().copyWith(lateralRepeatCount: 42).lateralRepeatCount, 10);
  });
}
