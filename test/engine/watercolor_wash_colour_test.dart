// 水彩風混色の色：白い紙の上で、既定の水分量・絵具量と組み込みの水彩の
// ブラシは選んだ色に見えること（むらは選んだ色の前後で、全体が薄くならない）。
// 水分量が多いほど薄く・下の色となじみ・筆の外へ広がり・縁が柔らかくなり、
// 少ないほど硬く・広がらず・混じりにくいこと。
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';

import '../helpers/delta_e.dart';

const _size = 240;

Brush _brush({
  int opacity = 100,
  int rate = 30,
  int water = kDefaultMixingWater,
  int pigment = kDefaultMixingPigment,
  int bleed = kDefaultMixingBleed,
  int texture = kDefaultMixingTexture,
  int softEdge = kDefaultMixingSoftEdge,
}) => Brush(
  id: 'watercolor-colour-test',
  name: 'Watercolor Colour Test',
  size: 40,
  opacity: opacity,
  spacing: 4,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOff: BrushPressureOffSettings(
    blur: const FixedBrushSetting(enabled: false, value: 0),
    edgeJitter: const FixedBrushSetting(enabled: false, value: 0),
    mixing: PressureMixingOffSetting(
      enabled: true,
      mode: BrushMixingMode.watercolor,
      rate: rate,
      water: water,
      pigment: pigment,
      bleed: bleed,
      texture: texture,
      softEdge: softEdge,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
);

void _stroke(
  DrawingEngine engine,
  Brush brush,
  int colour, {
  required double y,
  double x0 = 30,
  double x1 = 210,
}) {
  engine
    ..currentBrush = brush
    ..currentColor = ui.Color(0xFF000000 | colour)
    ..pressureEnabled = false;
  engine.beginStroke(StrokePoint(x: x0, y: y, pressure: 1), 'layer');
  for (var x = x0 + 2; x <= x1; x += 2) {
    engine.continueStroke(StrokePoint(x: x, y: y, pressure: 1), 'layer');
  }
  engine.endStroke();
}

/// A flat area laid in overlapping strokes of [brush], as one paints a
/// patch of colour.
TileManager _flatArea(Brush brush, int colour) {
  final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
  final engine = DrawingEngine(tileManager: tiles);
  final step = brush.size / 2;
  for (var y = 60.0; y <= 180; y += step) {
    _stroke(engine, brush, colour, y: y);
  }
  return tiles;
}

/// The pixel at ([x], [y]) on white paper, as CIELAB.
List<double> _onPaper(TileManager tiles, int x, int y) {
  final c = tiles.getPixelColorAt('layer', x, y);
  if (c == null) return labOf(255, 255, 255);
  double over(double v) => (v * c.a + (1 - c.a)) * 255;
  return labOf(over(c.r), over(c.g), over(c.b));
}

/// The mean colour over the inside of the area (away from its edges).
List<double> _meanInside(TileManager tiles) => meanLab([
  for (var y = 90; y <= 150; y += 2)
    for (var x = 70; x <= 170; x += 2) _onPaper(tiles, x, y),
]);

void main() {
  const colours = <String, int>{
    'yellow': 0xF5C518,
    'red': 0xD93030,
    'blue': 0x2E4BD8,
    'dark': 0x2B2D42,
    'light': 0xF2B8C6,
  };

  test(
    'at the default water and pigment a wash reads as the chosen colour',
    () {
      for (final MapEntry(key: name, value: colour) in colours.entries) {
        final mean = _meanInside(_flatArea(_brush(), colour));
        final chosen = labOfRgb(colour);
        expect(
          deltaE2000(mean, chosen),
          lessThan(5),
          reason: '$name: mean $mean against $chosen',
        );
        // Not paler overall than the chosen colour.
        expect(mean[0], lessThan(chosen[0] + 3), reason: name);
      }
    },
  );

  test('every built-in watercolour brush reads as the chosen colour', () {
    final presets = BrushService.builtInBrushes.where(
      (b) =>
          b.pressureOff.mixing.enabled &&
          b.pressureOff.mixing.mode == BrushMixingMode.watercolor,
    );
    expect(presets, isNotEmpty);
    for (final preset in presets) {
      for (final MapEntry(key: name, value: colour) in colours.entries) {
        final mean = _meanInside(_flatArea(preset, colour));
        final chosen = labOfRgb(colour);
        expect(
          deltaE2000(mean, chosen),
          lessThan(5),
          reason: '${preset.name} $name: mean $mean against $chosen',
        );
        expect(mean[0], lessThan(chosen[0] + 3), reason: preset.name);
      }
    }
  });

  test(
    'the texture varies the wash both lighter and darker than the colour',
    () {
      final tiles = _flatArea(_brush(texture: 100), 0xD93030);
      final chosen = labOfRgb(0xD93030)[0];
      var lighter = 0, darker = 0;
      for (var y = 90; y <= 150; y += 2) {
        for (var x = 70; x <= 170; x += 2) {
          final l = _onPaper(tiles, x, y)[0];
          if (l > chosen + 2) lighter++;
          if (l < chosen - 2) darker++;
        }
      }
      expect(lighter, greaterThan(20));
      expect(darker, greaterThan(20));
    },
  );

  test('a lowered opacity is a lighter glaze', () {
    List<double> stroke(int opacity) {
      final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
      _stroke(
        DrawingEngine(tileManager: tiles),
        _brush(opacity: opacity),
        0x2E4BD8,
        y: 120,
      );
      return meanLab([
        for (var y = 110; y <= 130; y += 2)
          for (var x = 70; x <= 170; x += 2) _onPaper(tiles, x, y),
      ]);
    }

    expect(stroke(50)[0], greaterThan(stroke(100)[0] + 15));
  });

  group('水分量 drives how wet the whole wash is', () {
    const waters = [0, 25, 50, 75, 100];

    test('more water is paler; little water keeps the chosen colour', () {
      final lightness = <double>[];
      for (final water in waters) {
        final mean = _meanInside(_flatArea(_brush(water: water), 0x2E4BD8));
        lightness.add(mean[0]);
        if (water <= 50) {
          expect(
            deltaE2000(mean, labOfRgb(0x2E4BD8)),
            lessThan(5),
            reason: 'water $water',
          );
        }
      }
      for (var i = 1; i < lightness.length; i++) {
        expect(lightness[i], greaterThan(lightness[i - 1] - 1), reason: '$i');
      }
      expect(lightness.last, greaterThan(lightness[2] + 15));
    });

    /// A single blue stroke across the middle (y 120, the brush reaches to
    /// y 140) of a wash of [water].
    TileManager oneStroke(int water) {
      final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
      _stroke(
        DrawingEngine(tileManager: tiles),
        _brush(water: water, texture: 0),
        0x2E4BD8,
        y: 120,
      );
      return tiles;
    }

    int alphaAt(TileManager tiles, int x, int y) {
      final c = tiles.getPixelColorAt('layer', x, y);
      return c == null ? 0 : (c.a * 255).round();
    }

    test('more water spreads further past the brush', () {
      double reach(TileManager tiles) {
        var sum = 0;
        for (var x = 80; x <= 160; x += 4) {
          var y = 140;
          while (y < _size - 1 && alphaAt(tiles, x, y + 1) > 8) {
            y++;
          }
          sum += y - 140;
        }
        return sum / 21;
      }

      final reaches = [for (final water in waters) reach(oneStroke(water))];
      for (var i = 1; i < reaches.length; i++) {
        expect(reaches[i], greaterThanOrEqualTo(reaches[i - 1]), reason: '$i');
      }
      // Hardly any spread with little water; clearly more with a lot.
      expect(reaches.first, lessThan(2));
      expect(reaches.last, greaterThan(reaches[2] + 3));
    });

    test('more water dries with a softer edge', () {
      // How many pixels the edge takes to fall from 90% to 10% of the
      // middle's opacity.
      double softness(TileManager tiles) {
        var sum = 0;
        for (var x = 80; x <= 160; x += 4) {
          final middle = alphaAt(tiles, x, 120);
          var y = 120;
          while (alphaAt(tiles, x, y) > middle * 0.9 && y < _size - 1) {
            y++;
          }
          final start = y;
          while (alphaAt(tiles, x, y) > middle * 0.1 && y < _size - 1) {
            y++;
          }
          sum += y - start;
        }
        return sum / 21;
      }

      final widths = [for (final water in waters) softness(oneStroke(water))];
      for (var i = 1; i < widths.length; i++) {
        expect(widths[i], greaterThanOrEqualTo(widths[i - 1]), reason: '$i');
      }
      expect(widths.first, lessThan(3));
      expect(widths.last, greaterThan(widths.first + 4));
    });

    test('with more water the colours bloom into each other more widely', () {
      // A blue wash from a flat yellow (x < 120) out onto bare paper: how
      // many pixels along the stroke the colour takes to change from the
      // green over the yellow to the blue over the paper (10% to 90%).
      double blend(int water) {
        final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
        final tile = tiles.getOrCreateTile('layer', 0, 0);
        for (var y = 0; y < _size; y++) {
          for (var x = 0; x < 120; x++) {
            final i = (y * TileManager.tileSize + x) * 4;
            tile[i] = 0xF5;
            tile[i + 1] = 0xC5;
            tile[i + 2] = 0x18;
            tile[i + 3] = 255;
          }
        }
        _stroke(
          DrawingEngine(tileManager: tiles),
          _brush(water: water, texture: 0),
          0x2E4BD8,
          y: 120,
        );
        List<double> along(int x) =>
            meanLab([for (var y = 114; y <= 126; y++) _onPaper(tiles, x, y)]);
        final green = along(70);
        final blue = along(185);
        final whole = deltaE2000(green, blue);
        int? from, to;
        for (var x = 70; x <= 185; x++) {
          final t = deltaE2000(green, along(x)) / whole;
          if (from == null && t > 0.1) from = x;
          if (to == null && t > 0.9) to = x;
        }
        return (to! - from!).toDouble();
      }

      final widths = [
        for (final water in [0, 50, 100]) blend(water),
      ];
      expect(widths[0], lessThanOrEqualTo(3));
      expect(widths[1], greaterThan(widths[0] + 3));
      expect(widths[2], greaterThan(widths[1] + 3));
    });

    test('more water runs further into the colour under it', () {
      // Blue over a flat yellow: how far the result is from the blue.
      double towardsYellow(int water) {
        final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
        final tile = tiles.getOrCreateTile('layer', 0, 0);
        for (var y = 0; y < _size; y++) {
          for (var x = 0; x < _size; x++) {
            final i = (y * TileManager.tileSize + x) * 4;
            tile[i] = 0xF5;
            tile[i + 1] = 0xC5;
            tile[i + 2] = 0x18;
            tile[i + 3] = 255;
          }
        }
        _stroke(
          DrawingEngine(tileManager: tiles),
          _brush(water: water, texture: 0),
          0x2E4BD8,
          y: 120,
        );
        final mixed = meanLab([
          for (var x = 80; x <= 160; x += 4) _onPaper(tiles, x, 120),
        ]);
        return deltaE2000(mixed, labOfRgb(0x2E4BD8));
      }

      final distances = [for (final water in waters) towardsYellow(water)];
      for (var i = 1; i < distances.length; i++) {
        expect(
          distances[i],
          greaterThan(distances[i - 1]),
          reason: 'water ${waters[i]}',
        );
      }
    });
  });
}
