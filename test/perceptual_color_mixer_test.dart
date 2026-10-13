import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/perceptual_color_mixer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

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

    final chroma =
        [mixed.r, mixed.g, mixed.b].reduce((a, b) => a > b ? a : b) -
        [mixed.r, mixed.g, mixed.b].reduce((a, b) => a < b ? a : b);
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

  test('brightness correction adjusts the mix but not endpoints', () {
    final darker = mixPerceptualColor(
      yellow,
      blue,
      0.5,
      brightnessCorrection: 1,
    );
    final neutral = mixPerceptualColor(yellow, blue, 0.5);
    final brighter = mixPerceptualColor(
      yellow,
      blue,
      0.5,
      brightnessCorrection: 5,
    );

    expect(darker.g, lessThan(neutral.g));
    expect(darker.b, lessThan(neutral.b));
    expect(brighter.r, greaterThan(neutral.r));
    expect(brighter.b, greaterThan(neutral.b));

    final endpoint = mixPerceptualColor(
      yellow,
      blue,
      1,
      brightnessCorrection: 1,
    );
    expect(endpoint.r, closeTo(1, 1e-6));
    expect(endpoint.g, closeTo(1, 1e-6));
    expect(endpoint.b, closeTo(0, 1e-6));
  });

  test('cyan and magenta travel through blue around the hue wheel', () {
    const cyan = ui.Color(0xFF00FFFF);
    const magenta = ui.Color(0xFFFF00FF);
    final mixed = mixPerceptualColor(cyan, magenta, 0.5);

    expect(mixed.r, lessThan(0.05));
    expect(mixed.g, lessThan(0.05));
    expect(mixed.b, greaterThan(0.95));
  });

  test('perceptual setting round-trips and renders through hue wheel', () {
    final setting = PressureMixingOffSetting.fromJson({
      'enabled': true,
      'mode': 'perceptual',
      'rate': 60,
    });

    expect(setting.mode, BrushMixingMode.perceptual);
    expect(setting.brightnessCorrection, 3);
    expect(setting.toJson()['mode'], 'perceptual');
    expect(PressureMixingOffSetting.fromJson(setting.toJson()), setting);

    // Exercise the actual raster path with the perceptual brush setting.
    final engine = DrawingEngine(
      tileManager: TileManager(canvasWidth: 128, canvasHeight: 128),
    )
      ..currentBrush = Brush(
        id: 'perceptual-mixing',
        name: 'Perceptual Mixing',
        size: 20,
        opacity: 100,
        spacing: 10,
        stabilization: false,
        stabilizationStrength: 0,
        pixelMode: false,
        pressureOff: const BrushPressureOffSettings(
          blur: FixedBrushSetting(enabled: false, value: 0),
          edgeJitter: FixedBrushSetting(enabled: false, value: 0),
          mixing: PressureMixingOffSetting(
            enabled: true,
            mode: BrushMixingMode.perceptual,
            rate: 50,
          ),
        ),
        fadeMode: FadeMode.off,
        strokeDecay: false,
      )
      ..currentColor = blue
      ..pressureEnabled = false;
    final tile = engine.tileManager.getOrCreateTile('layer', 0, 0);
    final index = (64 * TileManager.tileSize + 64) * 4;
    tile[index] = 255;
    tile[index + 1] = 255;
    tile[index + 2] = 0;
    tile[index + 3] = 255;

    engine.beginStroke(
      const StrokePoint(x: 64, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
    engine.endStroke();

    expect(tile[index], lessThan(13));
    expect(tile[index + 1], greaterThan(240));
    expect(tile[index + 2], greaterThan(90));
  });

  test('mixing a chromatic colour with white keeps its hue', () {
    const red = ui.Color(0xFFFF0000);
    const white = ui.Color(0xFFFFFFFF);
    final mixed = mixPerceptualColor(red, white, 0.5);

    expect(mixed.r, greaterThan(mixed.g));
    expect(mixed.r, greaterThan(mixed.b));
    expect(mixed.g, closeTo(mixed.b, 1e-6));
    expect(mixed.a, closeTo(1, 1e-6));
  });

  test(
    'hues near the red boundary travel through red, not around the long arc',
    () {
      const magentaRed = ui.Color(0xFFFF0080);
      const orangeRed = ui.Color(0xFFFF8000);
      final mixed = mixPerceptualColor(magentaRed, orangeRed, 0.5);

      expect(mixed.r, greaterThan(0.95));
      expect(mixed.g, lessThan(0.25));
      expect(mixed.b, lessThan(0.25));
    },
  );
  
  test('bleed mixing carries picked-up colour with direct channel interpolation', () {
    final engine = DrawingEngine(
      tileManager: TileManager(canvasWidth: 8, canvasHeight: 8),
    );
    const selected = ui.Color(0xFF00FF00);
    const pickedUp = ui.Color(0xFFFF0000);

    final midpoint = engine.bleedColor(selected, pickedUp, 0.5);
    expect(midpoint.red, closeTo(128, 1));
    expect(midpoint.green, closeTo(128, 1));
    expect(midpoint.blue, 0);
    expect(engine.bleedColor(selected, null, 1), selected);
    expect(engine.bleedColor(selected, pickedUp, 0), selected);
  });

  test('bleed mode drags paint from the starting pixel along the stroke', () {
    final engine = DrawingEngine(
      tileManager: TileManager(canvasWidth: 128, canvasHeight: 128),
    )
      ..currentBrush = Brush(
        id: 'bleed-mixing',
        name: 'Bleed Mixing',
        size: 8,
        opacity: 100,
        spacing: 1,
        stabilization: false,
        stabilizationStrength: 0,
        pixelMode: false,
        pressureOff: const BrushPressureOffSettings(
          blur: FixedBrushSetting(enabled: false, value: 0),
          edgeJitter: FixedBrushSetting(enabled: false, value: 0),
          mixing: PressureMixingOffSetting(
            enabled: true,
            mode: BrushMixingMode.bleed,
            rate: 100,
          ),
        ),
        fadeMode: FadeMode.off,
        strokeDecay: false,
      )
      ..currentColor = const ui.Color(0xFF00FF00)
      ..pressureEnabled = false;

    final tile = engine.tileManager.getOrCreateTile('layer', 0, 0);
    final seedIndex = (64 * TileManager.tileSize + 40) * 4;
    tile[seedIndex] = 255;
    tile[seedIndex + 1] = 0;
    tile[seedIndex + 2] = 0;
    tile[seedIndex + 3] = 255;

    engine.beginStroke(
      const StrokePoint(x: 40, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
    engine.continueStroke(
      const StrokePoint(x: 80, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
    engine.endStroke();

    final dragged = engine.tileManager.getPixelColorAt('layer', 70, 64);
    expect(dragged, isNotNull);
    expect(dragged!.red, greaterThan(240));
    expect(dragged.green, lessThan(10));
    expect(dragged.blue, lessThan(10));
  });

}
