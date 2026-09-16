import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/outlined_stroke_compositor.dart';

void main() {
  test('fill removes internal outline coverage', () {
    final layers = OutlinedStrokeCompositor.compose(
      fillCoverage: 1,
      outerCoverage: 1,
      foldCoverage: 0,
    );
    expect(layers.fill, 1);
    expect(layers.outline, 0);
  });

  test('outline survives only outside fill union', () {
    final layers = OutlinedStrokeCompositor.compose(
      fillCoverage: .25,
      outerCoverage: .8,
      foldCoverage: 0,
    );
    expect(layers.fill, .25);
    expect(layers.outline, closeTo(.55, 1e-9));
  });

  test('fold marks are clipped to filled interior', () {
    final layers = OutlinedStrokeCompositor.compose(
      fillCoverage: .4,
      outerCoverage: 1,
      foldCoverage: .9,
    );
    expect(layers.fold, .4);
  });

  test('coverage union is max coverage, not additive', () {
    expect(OutlinedStrokeCompositor.union(.6, .7), .7);
  });

  test('non-finite and out-of-range coverage is bounded', () {
    expect(OutlinedStrokeCompositor.clampCoverage(double.nan), 0);
    expect(OutlinedStrokeCompositor.clampCoverage(-1), 0);
    expect(OutlinedStrokeCompositor.clampCoverage(2), 1);
  });
}
