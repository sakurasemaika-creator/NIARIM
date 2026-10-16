// 水彩風混色（WatercolorStroke）の振る舞い：透明な重ね塗り、乾くと縁に
// 色が溜まること、水分量・絵具量・縁の濃さの効き方、重ねると深くなる
// こと、Undoの記録に乾かした結果まで入ること。
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const _size = 200;

Brush _brush({int rate = 0, int water = 50, int pigment = 60, int edge = 50}) =>
    Brush(
      id: 'watercolor-test',
      name: 'Watercolor Test',
      size: 40,
      opacity: 100,
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
          edge: edge,
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

  test('drying gathers pigment in a darker rim inside the edge', () {
    final tiles = _paint(_brush(edge: 80));
    final centre = _meanAlpha(tiles, 96, 104);
    // The stroke is 40px wide (y 80–120): the rim is just inside its edge.
    var rim = 0.0;
    for (var y = 70; y < 100; y++) {
      rim = math.max(rim, _meanAlpha(tiles, y, y));
    }
    expect(rim, greaterThan(centre * 1.25));
  });

  test('縁の濃さ 0 leaves no rim; 100 a strong one', () {
    double rimRatio(int edge) {
      final tiles = _paint(_brush(edge: edge, water: 30));
      final centre = _meanAlpha(tiles, 96, 104);
      var rim = 0.0;
      for (var y = 70; y < 100; y++) {
        rim = math.max(rim, _meanAlpha(tiles, y, y));
      }
      return rim / centre;
    }

    final none = rimRatio(0);
    final strong = rimRatio(100);
    expect(none, lessThan(1.15));
    expect(strong, greaterThan(none + 0.4));
  });

  test('more water is paler and spreads further; more pigment is deeper', () {
    final dry = _paint(_brush(water: 0));
    final wet = _paint(_brush(water: 100));
    expect(_meanAlpha(wet, 96, 104), lessThan(_meanAlpha(dry, 96, 104)));
    expect(_paintedRows(wet), greaterThan(_paintedRows(dry) + 3));

    final thin = _paint(_brush(pigment: 10));
    final rich = _paint(_brush(pigment: 100));
    expect(
      _meanAlpha(rich, 96, 104),
      greaterThan(_meanAlpha(thin, 96, 104) * 1.8),
    );
  });

  test('a second wash of the same colour over the first is deeper', () {
    final once = _paint(_brush());
    final twice = TileManager(canvasWidth: _size, canvasHeight: _size);
    final engine = DrawingEngine(tileManager: twice);
    _stroke(engine, _brush());
    _stroke(engine, _brush());
    final a = once.getPixelColorAt('layer', 100, 100)!;
    final b = twice.getPixelColorAt('layer', 100, 100)!;
    // More opaque, and no lighter in any channel.
    expect(b.a, greaterThan(a.a + 0.1));
    double luminance(ui.Color c) =>
        (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a + (1 - c.a);
    expect(luminance(b), lessThan(luminance(a) - 0.05));
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
    _stroke(DrawingEngine(tileManager: tiles), _brush(edge: 100));
    final finished = Uint8List.fromList(tiles.getOrCreateTile('layer', 0, 0));
    final snapshot = tiles.endUndoRecording();
    expect(snapshot.after['0,0'], finished);
    expect(snapshot.before['0,0'], isNull);
  });

  test('a cancelled stroke is not dried', () {
    final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
    _stroke(DrawingEngine(tileManager: tiles), _brush(edge: 100), cancel: true);
    final dried = _paint(_brush(edge: 100));
    // Without drying there is no spread past the brush and no rim.
    expect(_paintedRows(tiles), lessThanOrEqualTo(_paintedRows(dried)));
    final centre = _meanAlpha(tiles, 96, 104);
    var rim = 0.0;
    for (var y = 70; y < 100; y++) {
      rim = math.max(rim, _meanAlpha(tiles, y, y));
    }
    expect(rim, lessThan(centre * 1.15));
  });
}
