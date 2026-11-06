// 水彩風混色（WatercolorStroke）の振る舞い：透明な重ね塗り、乾くとにじんで
// 広がること（縁の溜まりは水彩境界フィルター）、水分量・絵具量・にじみの
// 効き方、重ねると深くなること、Undoの記録に乾かした結果まで入ること。
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const _size = 200;

Brush _brush({
  int opacity = 100,
  int rate = 0,
  int water = 50,
  int pigment = 60,
  int bleed = 50,
  int texture = 50,
  int softEdge = 0,
}) => Brush(
  id: 'watercolor-test',
  name: 'Watercolor Test',
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

/// A horizontal stroke through the middle of the canvas.
void _stroke(
  DrawingEngine engine,
  Brush brush, {
  ui.Color colour = const ui.Color(0xFF2A6FD0),
  double y = 100,
  bool cancel = false,
}) {
  engine
    ..currentBrush = brush
    ..currentColor = colour
    ..pressureEnabled = false;
  engine.beginStroke(StrokePoint(x: 50, y: y, pressure: 1), 'layer');
  for (var x = 54.0; x <= 150; x += 4) {
    engine.continueStroke(StrokePoint(x: x, y: y, pressure: 1), 'layer');
  }
  engine.endStroke(cancel: cancel);
}

int _alpha(TileManager tiles, int x, int y) {
  final c = tiles.getPixelColorAt('layer', x, y);
  return c == null ? 0 : (c.a * 255).round();
}

/// Mean alpha over a horizontal band of rows (to even out the texture).
double _meanAlpha(
  TileManager tiles,
  int y0,
  int y1, {
  int x0 = 80,
  int x1 = 120,
}) {
  var sum = 0;
  var n = 0;
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      sum += _alpha(tiles, x, y);
      n++;
    }
  }
  return sum / n;
}

/// How many rows across the middle hold any paint.
int _paintedRows(TileManager tiles) {
  var rows = 0;
  for (var y = 0; y < _size; y++) {
    if (_alpha(tiles, 100, y) > 8) rows++;
  }
  return rows;
}

TileManager _paint(
  Brush brush, {
  ui.Color colour = const ui.Color(0xFF2A6FD0),
}) {
  final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
  _stroke(DrawingEngine(tileManager: tiles), brush, colour: colour);
  return tiles;
}

void main() {
  test('a wash is transparent paint of the brush colour', () {
    final tiles = _paint(_brush());
    final c = tiles.getPixelColorAt('layer', 100, 100)!;
    expect(c.a, inExclusiveRange(0.15, 0.85));
    // Over bare paper the wash keeps the paint's own colour.
    expect((c.r * 255).round(), 0x2A);
    expect((c.g * 255).round(), 0x6F);
    expect((c.b * 255).round(), 0xD0);
  });

  test('drying leaves no rim of its own (水彩境界 is a filter)', () {
    final tiles = _paint(_brush(water: 30));
    // Just inside the stroke's edge (y 80) is no denser than its middle.
    final centre = _meanAlpha(tiles, 94, 106, x0: 60, x1: 140);
    final nearEdge = _meanAlpha(tiles, 82, 88, x0: 60, x1: 140);
    expect(nearEdge, lessThan(centre * 1.1));
  });

  test('more water is paler and spreads a little; more pigment is deeper', () {
    final dry = _paint(_brush(water: 0));
    final wet = _paint(_brush(water: 100));
    expect(_meanAlpha(wet, 96, 104), lessThan(_meanAlpha(dry, 96, 104)));
    expect(_paintedRows(wet), greaterThan(_paintedRows(dry)));

    final thin = _paint(_brush(pigment: 10));
    final rich = _paint(_brush(pigment: 100));
    expect(
      _meanAlpha(rich, 96, 104),
      greaterThan(_meanAlpha(thin, 96, 104) * 1.8),
    );
  });

  test('にじみ carries the wash further past the brush, raggedly', () {
    final tight = _paint(_brush(bleed: 0));
    final loose = _paint(_brush(bleed: 100));
    expect(_paintedRows(loose), greaterThan(_paintedRows(tight) + 4));

    // The bleed does not end in a straight line: how far it reaches past
    // the brush's lower edge (y 120) varies along the stroke.
    int reachAt(TileManager tiles, int x) {
      var y = 120;
      while (y < _size - 1 && _alpha(tiles, x, y + 1) > 8) {
        y++;
      }
      return y;
    }

    final reaches = [for (var x = 70; x <= 130; x += 4) reachAt(loose, x)];
    final spread = reaches.reduce(math.max) - reaches.reduce(math.min);
    expect(spread, greaterThanOrEqualTo(2));
    // With no bleed the wash stays close to the brush.
    final tightReach = [for (var x = 70; x <= 130; x += 4) reachAt(tight, x)];
    expect(tightReach.reduce(math.max), lessThan(reaches.reduce(math.max)));
  });

  double luminance(ui.Color c) =>
      (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a + (1 - c.a);

  test('at a lowered opacity a second wash of the same colour is deeper', () {
    final once = _paint(_brush(opacity: 60));
    final twice = TileManager(canvasWidth: _size, canvasHeight: _size);
    final engine = DrawingEngine(tileManager: twice);
    _stroke(engine, _brush(opacity: 60));
    _stroke(engine, _brush(opacity: 60));
    final a = once.getPixelColorAt('layer', 100, 100)!;
    final b = twice.getPixelColorAt('layer', 100, 100)!;
    // More opaque, and no lighter in any channel.
    expect(b.a, greaterThan(a.a + 0.1));
    expect(luminance(b), lessThan(luminance(a) - 0.05));
  });

  test('at full opacity washes of the same colour join without deepening', () {
    // Two overlapping strokes, as a flat area is laid in.
    final once = _paint(_brush());
    final twice = TileManager(canvasWidth: _size, canvasHeight: _size);
    final engine = DrawingEngine(tileManager: twice);
    _stroke(engine, _brush());
    _stroke(engine, _brush(), y: 110);
    // Where both covered, it is as one wash: no darker overlap band.
    for (final (x, y) in [(90, 100), (100, 104), (110, 108)]) {
      final a = once.getPixelColorAt('layer', x, y)!;
      final b = twice.getPixelColorAt('layer', x, y)!;
      expect(b.a, closeTo(a.a, 2 / 255), reason: '($x, $y)');
      expect(luminance(b), closeTo(luminance(a), 0.01), reason: '($x, $y)');
    }
    // The area grew: the second stroke reaches further down.
    expect(_paintedRows(twice), greaterThan(_paintedRows(once) + 6));
  });

  test('a wash of another colour still mixes at full opacity', () {
    final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
    final engine = DrawingEngine(tileManager: tiles);
    _stroke(engine, _brush(), colour: const ui.Color(0xFFF2D020));
    final yellow = tiles.getPixelColorAt('layer', 100, 100)!;
    _stroke(engine, _brush());
    final mixed = tiles.getPixelColorAt('layer', 100, 100)!;
    // Blue over yellow turns green and deeper.
    expect(mixed.g, greaterThan(mixed.r));
    expect(mixed.g, greaterThan(mixed.b));
    expect(mixed.a, greaterThan(yellow.a + 0.1));
  });

  test('over paint it glazes; 混色度合い instead blends wet into wet', () {
    TileManager overYellow(int rate) {
      final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
      final tile = tiles.getOrCreateTile('layer', 0, 0);
      for (var y = 0; y < _size; y++) {
        for (var x = 0; x < _size; x++) {
          final i = (y * TileManager.tileSize + x) * 4;
          tile[i] = 0xF2;
          tile[i + 1] = 0xD0;
          tile[i + 2] = 0x20;
          tile[i + 3] = 255;
        }
      }
      _stroke(
        DrawingEngine(tileManager: tiles),
        _brush(rate: rate, pigment: 90),
      );
      return tiles;
    }

    final glaze = overYellow(0).getPixelColorAt('layer', 100, 100)!;
    final wetMix = overYellow(100).getPixelColorAt('layer', 100, 100)!;
    // Blue over yellow: a green either way, never blue-grey.
    for (final c in [glaze, wetMix]) {
      expect(c.g, greaterThan(c.r));
      expect(c.g, greaterThan(c.b));
      expect(c.a, closeTo(1, 1e-9));
    }
    // A glaze filters the yellow, so it is darker than blending the paints.
    expect(
      glaze.r + glaze.g + glaze.b,
      lessThan(wetMix.r + wetMix.g + wetMix.b),
    );
  });

  test('the same stroke always dries the same way', () {
    Uint8List pixels() {
      final tiles = _paint(_brush(water: 80));
      return Uint8List.fromList(tiles.getOrCreateTile('layer', 0, 0));
    }

    expect(pixels(), pixels());
  });

  test('the dried wash is what undo records as the stroke', () {
    final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
    tiles.beginUndoRecording('layer');
    _stroke(DrawingEngine(tileManager: tiles), _brush(water: 80));
    final finished = Uint8List.fromList(tiles.getOrCreateTile('layer', 0, 0));
    final snapshot = tiles.endUndoRecording();
    expect(snapshot.after['0,0'], finished);
    expect(snapshot.before['0,0'], isNull);
  });

  test('むら 0 paints an even wash; 100 a blotchy one', () {
    double spread(TileManager tiles) {
      final values = <int>[
        for (var y = 92; y <= 108; y += 2)
          for (var x = 70; x <= 130; x += 2) _alpha(tiles, x, y),
      ];
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance =
          values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
          values.length;
      return math.sqrt(variance) / mean;
    }

    final even = spread(_paint(_brush(texture: 0)));
    final blotchy = spread(_paint(_brush(texture: 100)));
    expect(even, lessThan(0.02));
    expect(blotchy, greaterThan(even + 0.1));
  });

  test('境界のぼかし fades the wash out towards its edge', () {
    // How the wash falls off below the stroke (its edge is at y 120).
    List<double> profile(TileManager tiles) => [
      for (var y = 104; y <= 140; y += 4) _meanAlpha(tiles, y, y),
    ];
    final crisp = profile(_paint(_brush(texture: 0, bleed: 0)));
    final soft = profile(_paint(_brush(texture: 0, bleed: 0, softEdge: 100)));
    // Crisp: full until the edge, then nothing. Soft: already fading
    // inside, and a gentle tail outside.
    expect(crisp[1], closeTo(crisp[0], 3)); // y 108
    expect(soft[2], lessThan(soft[0] * 0.92)); // y 112, inside the stroke
    expect(soft[6], greaterThan(8)); // y 128, past the brush
    expect(crisp[6], lessThan(soft[6] - 6));
    // Smooth: no step bigger than a fraction of the wash.
    for (var i = 1; i < soft.length; i++) {
      expect((soft[i] - soft[i - 1]).abs(), lessThan(soft[0] * 0.3));
    }
  });

  test('a cancelled stroke is not dried', () {
    final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
    _stroke(
      DrawingEngine(tileManager: tiles),
      _brush(bleed: 100),
      cancel: true,
    );
    final dried = _paint(_brush(bleed: 100));
    // Without drying the wash does not bleed past the brush.
    expect(_paintedRows(tiles), lessThan(_paintedRows(dried)));
  });
}
