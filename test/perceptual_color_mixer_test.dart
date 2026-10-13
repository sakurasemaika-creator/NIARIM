import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/perceptual_color_mixer.dart';
import 'package:niarim/engine/tile_manager.dart';

void main() {
  const yellow = ui.Color(0xFFFFFF00);
  const blue = ui.Color(0xFF0000FF);

  test('DrawingEngine brush mixing uses the perceptual mixer', () {
    final engine = DrawingEngine(
      tileManager: TileManager(canvasWidth: 1, canvasHeight: 1),
    );
    final mixed = engine.mixColor(yellow, blue, 0.5);

    expect(mixed.r, lessThan(0.05));
    expect(mixed.g, greaterThan(0.95));
    expect(mixed.b, greaterThan(0.35));
  });

  test('yellow and blue mix through saturated green/cyan, not grey', () {
    final mixed = mixPerceptualColor(yellow, blue, 0.5);

    expect(mixed.r, lessThan(0.05));
    expect(mixed.g, greaterThan(0.95));
    expect(mixed.b, greaterThan(0.35));
    expect(mixed.g, greaterThan(mixed.b));

    final chroma = [
      mixed.r,
      mixed.g,
      mixed.b,
    ].reduce((a, b) => a > b ? a : b) -
        [
          mixed.r,
          mixed.g,
          mixed.b,
        ].reduce((a, b) => a < b ? a : b);
    expect(chroma, greaterThan(0.9));
  });

  test('mixing is symmetric at opposite hues', () {
    final yellowToBlue = mixPerceptualColor(yellow, blue, 0.5);
    final blueToYellow = mixPerceptualColor(blue, yellow, 0.5);

    expect(blueToYellow.r, closeTo(yellowToBlue.r, 1e-9));
    expect(blueToYellow.g, closeTo(yellowToBlue.g, 1e-9));
    expect(blueToYellow.b, closeTo(yellowToBlue.b, 1e-9));
  });

  test('mixing weights preserve the existing below-colour convention', () {
    final mostlyBelow = mixPerceptualColor(yellow, blue, 0.75);
    final sameBlendReversed = mixPerceptualColor(blue, yellow, 0.25);

    expect(mostlyBelow.r, closeTo(sameBlendReversed.r, 1e-9));
    expect(mostlyBelow.g, closeTo(sameBlendReversed.g, 1e-9));
    expect(mostlyBelow.b, closeTo(sameBlendReversed.b, 1e-9));

    final allBelow = mixPerceptualColor(yellow, blue, 1);
    final allSelected = mixPerceptualColor(yellow, blue, 0);
    expect(allBelow.r, closeTo(1, 1e-6));
    expect(allBelow.g, closeTo(1, 1e-6));
    expect(allBelow.b, closeTo(0, 1e-6));
    expect(allSelected.r, closeTo(0, 1e-6));
    expect(allSelected.g, closeTo(0, 1e-6));
    expect(allSelected.b, closeTo(1, 1e-6));
  });

  test('mixing a chromatic colour with white keeps its hue', () {
    const red = ui.Color(0xFFFF0000);
    const white = ui.Color(0xFFFFFFFF);
    final mixed = mixPerceptualColor(red, white, 0.5);

    expect(mixed.r, greaterThan(mixed.g));
    expect(mixed.r, greaterThan(mixed.b));
    expect(mixed.g, closeTo(mixed.b, 1e-6));
    expect(mixed.alpha, closeTo(1, 1e-6));
  });

  test('hues near the red boundary travel through red, not around the long arc', () {
    const magentaRed = ui.Color(0xFFFF0080);
    const orangeRed = ui.Color(0xFFFF8000);
    final mixed = mixPerceptualColor(magentaRed, orangeRed, 0.5);

    expect(mixed.r, greaterThan(0.95));
    expect(mixed.g, lessThan(0.25));
    expect(mixed.b, lessThan(0.25));
  });
}
