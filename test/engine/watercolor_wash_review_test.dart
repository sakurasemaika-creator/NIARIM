// Review images for 水彩風混色 (build/brush-mixing/watercolor_*.png): washes
// scribbled like the reference (Adobe Fresco's watercolour wash), a glaze of
// one colour over another, wet-in-wet mixing, and the sliders' extremes.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

Brush _watercolor({
  double size = 56,
  int opacity = 100,
  int rate = 30,
  int water = 50,
  int pigment = 60,
  int bleed = 50,
}) => Brush(
  id: 'watercolor-review',
  name: 'Watercolor Review',
  size: size,
  opacity: opacity,
  spacing: 4,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOff: BrushPressureOffSettings(
    blur: const FixedBrushSetting(enabled: true, value: 1),
    edgeJitter: const FixedBrushSetting(enabled: true, value: 40),
    mixing: PressureMixingOffSetting(
      enabled: true,
      mode: BrushMixingMode.watercolor,
      rate: rate,
      water: water,
      pigment: pigment,
      bleed: bleed,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
);

/// A scribble filling a blob around ([cx], [cy]), the way a wash is laid.
List<ui.Offset> _scribble(
  double cx,
  double cy,
  double rx,
  double ry,
  int seed,
) {
  final random = math.Random(seed);
  final points = <ui.Offset>[];
  const turns = 5;
  for (var i = 0; i <= turns * 40; i++) {
    final t = i / 40;
    final band = (t / turns) * 2 - 1; // −1 → 1 across the blob
    final y = cy + band * ry * 0.75;
    final x = cx + math.sin(t * math.pi) * rx * math.sqrt(1 - band * band);
    points.add(
      ui.Offset(
        x + (random.nextDouble() - 0.5) * 4,
        y + (random.nextDouble() - 0.5) * 4,
      ),
    );
  }
  return points;
}

void _paint(
  DrawingEngine engine,
  List<ui.Offset> points,
  ui.Color colour,
  Brush brush,
) {
  engine
    ..currentBrush = brush
    ..currentColor = colour
    ..pressureEnabled = false;
  engine.beginStroke(
    StrokePoint(
      x: points.first.dx,
      y: points.first.dy,
      pressure: 1,
      tiltX: 0,
      tiltY: 0,
    ),
    'layer',
  );
  for (final p in points.skip(1)) {
    engine.continueStroke(
      StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0),
      'layer',
    );
  }
  engine.endStroke();
}

img.Image _onPaper(TileManager tiles, int width, int height) {
  final sheet = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final c = tiles.getPixelColorAt('layer', x, y);
      final a = c?.a ?? 0.0;
      int over(double v) => (250 * (1 - a) + v * 255 * a).round();
      sheet.setPixelRgb(
        x,
        y,
        over(c?.r ?? 0),
        over(c?.g ?? 0),
        over(c?.b ?? 0),
      );
    }
  }
  return sheet;
}

void _write(String name, img.Image image) {
  final dir = Directory('build/brush-mixing')..createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(img.encodePng(image));
}

void main() {
  test('washes like the reference', () {
    const width = 720;
    const height = 580;
    final tiles = TileManager(canvasWidth: width, canvasHeight: height);
    final engine = DrawingEngine(tileManager: tiles);
    const red = ui.Color(0xFFE8344A);
    const pink = ui.Color(0xFFE84C8C);
    const mint = ui.Color(0xFF52C6AA);
    const sky = ui.Color(0xFF4AA8D8);
    _paint(engine, _scribble(100, 80, 70, 55, 1), red, _watercolor());
    _paint(engine, _scribble(280, 80, 70, 55, 2), pink, _watercolor(water: 30));
    _paint(engine, _scribble(460, 80, 70, 55, 3), mint, _watercolor(water: 70));
    _paint(
      engine,
      _scribble(630, 80, 65, 55, 4),
      sky,
      _watercolor(pigment: 85),
    );
    // A second wash over the first, and two wet colours run together.
    _paint(engine, _scribble(110, 220, 75, 55, 5), red, _watercolor());
    _paint(engine, _scribble(150, 230, 55, 40, 6), red, _watercolor());
    _paint(engine, _scribble(330, 220, 70, 55, 7), mint, _watercolor());
    _paint(engine, _scribble(380, 225, 60, 45, 8), sky, _watercolor(rate: 80));
    _paint(
      engine,
      _scribble(560, 220, 70, 55, 9),
      pink,
      _watercolor(pigment: 90),
    );
    _paint(engine, _scribble(600, 230, 60, 45, 10), sky, _watercolor(rate: 0));
    // にじみ 0, 30, 70 and 100.
    _paint(engine, _scribble(100, 360, 60, 45, 11), sky, _watercolor(bleed: 0));
    _paint(
      engine,
      _scribble(280, 360, 60, 45, 12),
      sky,
      _watercolor(bleed: 30),
    );
    _paint(
      engine,
      _scribble(460, 360, 60, 45, 13),
      sky,
      _watercolor(bleed: 70),
    );
    _paint(
      engine,
      _scribble(630, 360, 60, 45, 14),
      sky,
      _watercolor(bleed: 100),
    );
    // A flat area laid in four overlapping strokes: at full opacity they
    // join into one even wash; at 60% each overlap is deeper.
    for (final (left, opacity) in [(40.0, 100), (400.0, 60)]) {
      for (var row = 0; row < 4; row++) {
        final y = 470.0 + row * 26;
        _paint(
          engine,
          [for (var x = left; x <= left + 280; x += 6) ui.Offset(x, y)],
          mint,
          _watercolor(size: 40, rate: 0, opacity: opacity),
        );
      }
    }
    _write('watercolor_washes.png', _onPaper(tiles, width, height));
  });
}
