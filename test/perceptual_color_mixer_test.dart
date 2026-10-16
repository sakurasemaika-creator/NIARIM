import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/perceptual_color_mixer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

import 'helpers/color_channels.dart';

/// OKLCh of [color]: lightness 0–1, chroma, hue in degrees (yellow ≈ 110,
/// green ≈ 142, cyan ≈ 195, blue ≈ 264, magenta ≈ 328, red ≈ 29).
({double l, double c, double h, double a, double b}) _oklch(ui.Color color) {
  double linear(double v) =>
      v > 0.04045 ? math.pow((v + 0.055) / 1.055, 2.4).toDouble() : v / 12.92;
  double cbrt(double v) => math.pow(v, 1 / 3).toDouble();
  final r = linear(color.r);
  final g = linear(color.g);
  final b = linear(color.b);
  final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  final lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  var hue = math.atan2(bb, a) * 180 / math.pi;
  if (hue < 0) hue += 360;
  return (l: lightness, c: math.sqrt(a * a + bb * bb), h: hue, a: a, b: bb);
}

double _distance(ui.Color x, ui.Color y) {
  final p = _oklch(x);
  final q = _oklch(y);
  final dl = p.l - q.l;
  final da = p.a - q.a;
  final db = p.b - q.b;
  return math.sqrt(dl * dl + da * da + db * db);
}

/// The colours from [paint] (weight 0) into [below] (weight 1).
List<ui.Color> _strip(
  ui.Color below,
  ui.Color paint, {
  int steps = 10,
  int brightnessCorrection = 3,
}) => [
  for (var i = 0; i <= steps; i++)
    mixPerceptualColor(
      below,
      paint,
      i / steps,
      brightnessCorrection: brightnessCorrection,
    ),
];

void main() {
  const yellow = ui.Color(0xFFFFFF00);
  const blue = ui.Color(0xFF0000FF);

  test('DrawingEngine brush mixing uses the analog mixer', () {
    final engine = DrawingEngine(
      tileManager: TileManager(canvasWidth: 1, canvasHeight: 1),
    );
    expect(
      engine.mixColor(yellow, blue, 0.5).toARGB32(),
      mixPerceptualColor(yellow, blue, 0.5).toARGB32(),
    );
  });

  test('yellow and blue meet in a vivid green, not the grey of RGB', () {
    final mixed = _oklch(mixPerceptualColor(yellow, blue, 0.5));
    expect(mixed.h, inInclusiveRange(130, 200));
    expect(mixed.c, greaterThan(0.12));
    // What "digital" mixing does: the RGB average of yellow and blue is grey.
    expect(_oklch(const ui.Color(0xFF808080)).c, lessThan(0.01));
  });

  test("the reference strip: yellow turns through green to blue, never "
      "greying out", () {
    // Colours picked from the analog-mixing image the user gave.
    const paperYellow = ui.Color(0xFFFFFC2A);
    const paintBlue = ui.Color(0xFF2B31FF);
    final strip = _strip(paperYellow, paintBlue);
    var previous = _oklch(strip.first).h;
    for (final colour in strip.skip(1)) {
      final now = _oklch(colour);
      // Around the wheel the short way through cyan and green: the hue only
      // ever decreases from blue (≈ 266°) to yellow (≈ 108°).
      expect(now.h, lessThanOrEqualTo(previous + 1.0));
      expect(now.h, inInclusiveRange(100, 270));
      expect(now.c, greaterThan(0.09));
      previous = now.h;
    }
    // A straight RGB blend of the same two colours dips into grey.
    final rgbMiddle = ui.Color.fromARGB(255, 149, 150, 149);
    expect(_oklch(rgbMiddle).c, lessThan(0.01));
  });

  test('orange-tinted yellows meet blue in green too, never in magenta', () {
    // Hue-wheel interpolation by the shorter arc sent these through red and
    // magenta: their hues are almost exactly opposite.
    for (final pair in const [
      (ui.Color(0xFFFFD000), ui.Color(0xFF1E3CFF)),
      (ui.Color(0xFFFFE600), ui.Color(0xFF0000FF)),
      (ui.Color(0xFFFFC000), ui.Color(0xFF3050FF)),
    ]) {
      for (final colour in _strip(pair.$1, pair.$2)) {
        expect(_oklch(colour).h, inInclusiveRange(70, 275));
      }
      expect(
        _oklch(mixPerceptualColor(pair.$1, pair.$2, 0.5)).c,
        greaterThan(0.1),
      );
    }
  });

  test('paint-like hues: red + blue is purple, red + yellow orange, '
      'cyan + magenta blue', () {
    const red = ui.Color(0xFFFF0000);
    expect(
      _oklch(mixPerceptualColor(red, blue, 0.5)).h,
      inInclusiveRange(285, 350),
    );
    expect(
      _oklch(mixPerceptualColor(red, yellow, 0.5)).h,
      inInclusiveRange(40, 80),
    );
    expect(
      _oklch(
        mixPerceptualColor(
          const ui.Color(0xFF00FFFF),
          const ui.Color(0xFFFF00FF),
          0.5,
        ),
      ).h,
      inInclusiveRange(255, 300),
    );
  });

  test('mixing is symmetric and the weight convention is kept', () {
    const pairs = [
      (ui.Color(0xFFFFFF00), ui.Color(0xFF0000FF)),
      (ui.Color(0xFFF2C8A8), ui.Color(0xFF3050C0)),
      (ui.Color(0xFFE03030), ui.Color(0xFF30A050)),
    ];
    for (final (a, b) in pairs) {
      for (final weight in const [0.1, 0.25, 0.5, 0.8]) {
        final forward = mixPerceptualColor(a, b, weight);
        final backward = mixPerceptualColor(b, a, 1 - weight);
        // Colours one level apart share a cached path, so the two
        // directions can differ by a few levels.
        expect((forward.red8 - backward.red8).abs(), lessThanOrEqualTo(4));
        expect((forward.green8 - backward.green8).abs(), lessThanOrEqualTo(4));
        expect((forward.blue8 - backward.blue8).abs(), lessThanOrEqualTo(4));
      }
      // 1 keeps the colour below, 0 is the paint itself.
      expect(mixPerceptualColor(a, b, 1).toARGB32(), a.toARGB32());
      expect(mixPerceptualColor(a, b, 0).toARGB32(), b.toARGB32());
    }
  });

  test('a colour mixed with itself stays exactly the same', () {
    final random = math.Random(3);
    for (var i = 0; i < 50; i++) {
      final colour = ui.Color(0xFF000000 | random.nextInt(0x1000000));
      for (final weight in const [0.2, 0.5, 0.9]) {
        expect(
          mixPerceptualColor(colour, colour, weight).toARGB32(),
          colour.toARGB32(),
        );
      }
    }
  });

  test('the mixing rate moves evenly: a little yellow does not swamp blue', () {
    // By pigment, a touch of yellow turns blue paint dark teal at once; the
    // rate is measured along the way instead, so 10% is about a tenth.
    for (final (below, paint) in const [
      (ui.Color(0xFFFFFF00), ui.Color(0xFF0000FF)),
      (ui.Color(0xFF0000FF), ui.Color(0xFFFFFF00)),
      (ui.Color(0xFFFF0000), ui.Color(0xFF0000FF)),
      (ui.Color(0xFFF2C8A8), ui.Color(0xFF3050C0)),
    ]) {
      final strip = _strip(below, paint, steps: 20);
      final steps = [
        for (var i = 1; i < strip.length; i++)
          _distance(strip[i - 1], strip[i]),
      ];
      final total = steps.reduce((x, y) => x + y);
      final first10 = steps[0] + steps[1];
      expect(first10 / total, inInclusiveRange(0.05, 0.16));
      expect(steps.reduce(math.max), lessThan(total / steps.length * 2.2));
    }
  });

  test('neighbouring weights never jump, whatever the two colours', () {
    final random = math.Random(11);
    for (var i = 0; i < 120; i++) {
      final a = ui.Color(0xFF000000 | random.nextInt(0x1000000));
      final b = ui.Color(0xFF000000 | random.nextInt(0x1000000));
      final strip = _strip(a, b, steps: 40);
      final steps = [
        for (var k = 1; k < strip.length; k++)
          _distance(strip[k - 1], strip[k]),
      ];
      final mean = steps.reduce((x, y) => x + y) / steps.length;
      // 0.012 covers 8-bit rounding on short paths.
      expect(
        steps.reduce(math.max),
        lessThan(math.max(mean * 3, 0.012)),
        reason:
            '${a.toARGB32().toRadixString(16)} → '
            '${b.toARGB32().toRadixString(16)}',
      );
    }
  });

  test('a mix never turns lighter than the lighter of the two colours', () {
    // Digital hue-wheel mixing jumps to neon in between (yellow + blue
    // through bright cyan); paint never gets lighter than its lightest paint.
    final random = math.Random(17);
    final pairs = [
      for (var i = 0; i < 80; i++)
        (
          ui.Color(0xFF000000 | random.nextInt(0x1000000)),
          ui.Color(0xFF000000 | random.nextInt(0x1000000)),
        ),
      (yellow, blue),
      (const ui.Color(0xFFFF0000), blue),
      (const ui.Color(0xFF00FFFF), const ui.Color(0xFFFF00FF)),
      (const ui.Color(0xFFFF0000), const ui.Color(0xFFFFFFFF)),
    ];
    for (final (a, b) in pairs) {
      final lighter = math.max(_oklch(a).l, _oklch(b).l);
      for (final colour in _strip(a, b, steps: 20)) {
        expect(_oklch(colour).l, lessThan(lighter + 0.006));
      }
    }
  });

  test('brightness correction moves the lightness but not the endpoints', () {
    final darker = _oklch(
      mixPerceptualColor(yellow, blue, 0.5, brightnessCorrection: 1),
    );
    final neutral = _oklch(mixPerceptualColor(yellow, blue, 0.5));
    final brighter = _oklch(
      mixPerceptualColor(yellow, blue, 0.5, brightnessCorrection: 5),
    );
    expect(darker.l, lessThan(neutral.l - 0.02));
    expect(brighter.l, greaterThan(neutral.l + 0.02));
    for (final correction in const [1, 5]) {
      expect(
        mixPerceptualColor(
          yellow,
          blue,
          1,
          brightnessCorrection: correction,
        ).toARGB32(),
        yellow.toARGB32(),
      );
      expect(
        mixPerceptualColor(
          yellow,
          blue,
          0,
          brightnessCorrection: correction,
        ).toARGB32(),
        blue.toARGB32(),
      );
    }
  });

  test('OFF mixing mode is persisted separately from the saved mode', () {
    final pressureOff = PressureMixingOffSetting.fromJson({
      'enabled': false,
      'mode': 'off',
      'rate': 0,
    });
    expect(pressureOff.enabled, isFalse);
    expect(pressureOff.mode, BrushMixingMode.off);
    expect(pressureOff.toJson()['mode'], 'off');
    expect(
      PressureMixingOffSetting.fromJson(pressureOff.toJson()),
      pressureOff,
    );

    final pressureOn = PressureMixingOnSetting.fromJson({
      'enabled': false,
      'mode': 'off',
      'weakRate': 0,
      'strongRate': 0,
    });
    expect(pressureOn.enabled, isFalse);
    expect(pressureOn.mode, BrushMixingMode.off);
    expect(pressureOn.toJson()['mode'], 'off');
    expect(PressureMixingOnSetting.fromJson(pressureOn.toJson()), pressureOn);
  });

  test('oil setting round-trips and renders around the colour wheel', () {
    final setting = PressureMixingOffSetting.fromJson({
      'enabled': true,
      'mode': 'oil',
      'rate': 60,
    });

    expect(setting.mode, BrushMixingMode.oil);
    expect(setting.brightnessCorrection, 3);
    expect(setting.stretch, kDefaultMixingStretch);
    expect(setting.toJson()['mode'], 'oil');
    expect(PressureMixingOffSetting.fromJson(setting.toJson()), setting);

    // Exercise the actual raster path with the oil brush setting.
    final engine =
        DrawingEngine(
            tileManager: TileManager(canvasWidth: 128, canvasHeight: 128),
          )
          ..currentBrush = Brush(
            id: 'oil-mixing',
            name: 'Oil Mixing',
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
                mode: BrushMixingMode.oil,
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

    // Blue paint into yellow at 50%: a vivid green-teal, not the grey of an
    // RGB average.
    final mixed = _oklch(
      ui.Color.fromARGB(255, tile[index], tile[index + 1], tile[index + 2]),
    );
    expect(mixed.h, inInclusiveRange(130, 200));
    expect(mixed.c, greaterThan(0.12));
  });

  test('mixing a colour with white makes a tint of the same hue', () {
    const red = ui.Color(0xFFFF0000);
    const white = ui.Color(0xFFFFFFFF);
    final mixed = mixPerceptualColor(red, white, 0.5);

    expect(mixed.r, greaterThan(mixed.g));
    expect(mixed.r, greaterThan(mixed.b));
    expect(mixed.a, closeTo(1, 1e-6));
    // A pink: a little cooler, as tints of paint are, but still red.
    final tint = _oklch(mixed);
    expect((tint.h - _oklch(red).h).abs(), lessThan(25));
    expect(tint.c, greaterThan(0.08));
    expect(tint.l, greaterThan(_oklch(red).l));
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

  test('a faint pixel below gives up less paint than a solid one', () {
    ui.Color paintOver(int alpha) {
      final engine =
          DrawingEngine(
              tileManager: TileManager(canvasWidth: 128, canvasHeight: 128),
            )
            ..currentBrush = Brush(
              id: 'analog-mixing',
              name: 'Analog Mixing',
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
                  mode: BrushMixingMode.oil,
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
      tile[index + 3] = alpha;
      engine.beginStroke(
        const StrokePoint(x: 64, y: 64, pressure: 1, tiltX: 0, tiltY: 0),
        'layer',
      );
      engine.endStroke();
      return ui.Color.fromARGB(
        255,
        tile[index],
        tile[index + 1],
        tile[index + 2],
      );
    }

    final solid = paintOver(255);
    final faint = paintOver(40);
    expect(_distance(faint, blue), lessThan(_distance(solid, blue) * 0.5));
    expect(_oklch(faint).h, inInclusiveRange(230, 290));
  });

  test('saved modes from before 油彩風/水彩風 still load', () {
    BrushMixingMode modeOf(Object? saved) => PressureMixingOffSetting.fromJson({
      'enabled': true,
      'mode': saved,
      'rate': 40,
    }).mode;
    expect(modeOf('off'), BrushMixingMode.off);
    expect(modeOf('oil'), BrushMixingMode.oil);
    expect(modeOf('watercolor'), BrushMixingMode.watercolor);
    // アナログ風 (and the older 簡易混色) became 油彩風; にじみ became 水彩風.
    expect(modeOf('perceptual'), BrushMixingMode.oil);
    expect(modeOf('simple'), BrushMixingMode.oil);
    expect(modeOf('bleed'), BrushMixingMode.watercolor);
    expect(modeOf(null), BrushMixingMode.oil);

    // Settings saved before the new sliders get their defaults.
    final on = PressureMixingOnSetting.fromJson({
      'enabled': true,
      'mode': 'bleed',
      'weakRate': 10,
      'strongRate': 90,
    });
    expect(on.mode, BrushMixingMode.watercolor);
    expect(on.stretch, kDefaultMixingStretch);
    expect(on.water, kDefaultMixingWater);
    expect(on.pigment, kDefaultMixingPigment);
    expect(on.edge, kDefaultMixingEdge);
  });

  test('the new sliders round-trip and stay within 0–100', () {
    const on = PressureMixingOnSetting(
      enabled: true,
      mode: BrushMixingMode.watercolor,
      weakRate: 20,
      strongRate: 70,
      brightnessCorrection: 4,
      stretch: 15,
      water: 80,
      pigment: 35,
      edge: 90,
    );
    expect(PressureMixingOnSetting.fromJson(on.toJson()), on);
    const off = PressureMixingOffSetting(
      enabled: true,
      mode: BrushMixingMode.oil,
      rate: 55,
      stretch: 66,
      water: 1,
      pigment: 99,
      edge: 0,
    );
    expect(PressureMixingOffSetting.fromJson(off.toJson()), off);
    final clamped = PressureMixingOffSetting.fromJson({
      'enabled': true,
      'mode': 'watercolor',
      'rate': 50,
      'stretch': 250,
      'water': -4,
    });
    expect(clamped.stretch, 100);
    expect(clamped.water, 0);
  });

  test(
    'read-only global pixel sampling crosses tile boundaries without allocating tiles',
    () {
      final manager = TileManager(
        canvasWidth: TileManager.tileSize * 2,
        canvasHeight: TileManager.tileSize,
      );
      expect(
        manager.getPixelColorAt('layer', TileManager.tileSize + 2, 10),
        isNull,
      );
      expect(manager.exportAll(), isEmpty);

      final tile = manager.getOrCreateTile('layer', 1, 0);
      final index = (10 * TileManager.tileSize + 2) * 4;
      tile[index] = 12;
      tile[index + 1] = 34;
      tile[index + 2] = 56;
      tile[index + 3] = 255;
      final sampled = manager.getPixelColorAt(
        'layer',
        TileManager.tileSize + 2,
        10,
      );

      expect(sampled, isNotNull);
      expect(sampled!.red8, 12);
      expect(sampled.green8, 34);
      expect(sampled.blue8, 56);
    },
  );
}
