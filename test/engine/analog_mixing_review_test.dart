// Review images for the brush's analog-style mixing (build/brush-mixing/):
// colour strips comparing a straight RGB blend, the earlier hue-wheel
// interpolation and the analog mixer, and real strokes of a mixing brush
// over coloured paint.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/perceptual_color_mixer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const _pairs = [
  (0xFFFF00, 0x0000FF),
  (0xFFFC2A, 0x2B31FF),
  (0xFFD000, 0x1E3CFF),
  (0xFF0000, 0x0000FF),
  (0xFF0000, 0xFFFF00),
  (0x00FFFF, 0xFF00FF),
  (0xFF0000, 0xFFFFFF),
  (0xF2C8A8, 0x3050C0),
  (0xE03030, 0x30A050),
];

int _rgbBlend(int a, int b, double t) {
  int channel(int shift) =>
      ((a >> shift & 0xFF) + ((b >> shift & 0xFF) - (a >> shift & 0xFF)) * t)
          .round();
  return channel(16) << 16 | channel(8) << 8 | channel(0);
}

/// The earlier approach, for comparison (the previous mixPerceptualColor):
/// HSL with the hue taking the shorter arc of the wheel, so yellows tinted
/// towards orange went round through red and magenta to reach blue.
int _previousHueWheel(int below, int selected, double belowWeight) {
  (double, double, double) hsl(int c) {
    final r = (c >> 16 & 0xFF) / 255;
    final g = (c >> 8 & 0xFF) / 255;
    final b = (c & 0xFF) / 255;
    final hi = math.max(r, math.max(g, b));
    final lo = math.min(r, math.min(g, b));
    final l = (hi + lo) / 2;
    final d = hi - lo;
    if (d <= 1e-9) return (0, 0, l);
    final denominator = 1 - (2 * l - 1).abs();
    final s = denominator <= 1e-9 ? 0.0 : (d / denominator).clamp(0.0, 1.0);
    final h = hi == r
        ? 60 * (((g - b) / d) % 6)
        : hi == g
        ? 60 * ((b - r) / d + 2)
        : 60 * ((r - g) / d + 4);
    return (h % 360, s, l);
  }

  final selectedWeight = 1 - belowWeight;
  final (ha, sa, la) = hsl(below);
  final (hb, sb, lb) = hsl(selected);
  final hueA = sa <= 1e-6 ? hb : ha;
  final hueB = sb <= 1e-6 ? hueA : hb;
  final raw = hueB - hueA;
  var delta = raw % 360;
  if (delta > 180) {
    delta -= 360;
  } else if ((delta - 180).abs() <= 1e-9) {
    delta = raw < 0 ? -180 : 180;
  }
  final h = (hueA + delta * selectedWeight) % 360;
  final s = sa + (sb - sa) * selectedWeight;
  final l = la + (lb - la) * selectedWeight;
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final (r1, g1, b1) = switch (h ~/ 60) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  final m = l - c / 2;
  int to8(double v) => ((v + m).clamp(0.0, 1.0) * 255).round();
  return to8(r1) << 16 | to8(g1) << 8 | to8(b1);
}

void _write(String name, img.Image image) {
  final dir = Directory('build/brush-mixing')..createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(img.encodePng(image));
}

Brush _mixingBrush(BrushMixingMode mode, int rate, {int stretch = 0}) => Brush(
  id: 'analog-review',
  name: 'Analog Review',
  size: 26,
  opacity: 100,
  spacing: 10,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOff: BrushPressureOffSettings(
    blur: const FixedBrushSetting(enabled: false, value: 0),
    edgeJitter: const FixedBrushSetting(enabled: false, value: 0),
    mixing: PressureMixingOffSetting(
      enabled: mode != BrushMixingMode.off,
      mode: mode,
      rate: rate,
      stretch: stretch,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
);

void main() {
  test('colour strips: RGB, earlier hue-wheel, analog', () {
    const cell = 12;
    const steps = 40;
    const row = 18;
    const group = row * 3 + 14;
    final sheet = img.Image(
      width: (steps + 1) * cell + 16,
      height: _pairs.length * group + 8,
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (var p = 0; p < _pairs.length; p++) {
      final (below, paint) = _pairs[p];
      final mixer = AnalogPaintMixer(selected: paint);
      final rows = [
        (double t) => _rgbBlend(paint, below, t),
        (double t) => _previousHueWheel(below, paint, t),
        (double t) => mixer.mix(below, t),
      ];
      for (var r = 0; r < rows.length; r++) {
        for (var i = 0; i <= steps; i++) {
          final c = rows[r](i / steps);
          img.fillRect(
            sheet,
            x1: 8 + i * cell,
            y1: 8 + p * group + r * row,
            x2: 8 + (i + 1) * cell - 1,
            y2: 8 + p * group + (r + 1) * row - 2,
            color: img.ColorRgb8(c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF),
          );
        }
      }
    }
    _write('strips.png', sheet);
  });

  test('strokes of a mixing brush over yellow and red paint', () {
    const width = 560;
    const height = 300;
    final tiles = TileManager(canvasWidth: width, canvasHeight: height);
    // Yellow and red paint already on the layer, paper in between.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final colour = x >= 50 && x < 230
            ? 0xFFFC2A
            : x >= 330 && x < 510
            ? 0xE02828
            : null;
        if (colour == null) continue;
        final tile = tiles.getOrCreateTile(
          'layer',
          x ~/ TileManager.tileSize,
          y ~/ TileManager.tileSize,
        );
        final i =
            ((y % TileManager.tileSize) * TileManager.tileSize +
                x % TileManager.tileSize) *
            4;
        tile[i] = colour >> 16 & 0xFF;
        tile[i + 1] = colour >> 8 & 0xFF;
        tile[i + 2] = colour & 0xFF;
        tile[i + 3] = 255;
      }
    }
    final engine = DrawingEngine(tileManager: tiles)
      ..currentColor = const ui.Color(0xFF2B31FF)
      ..pressureEnabled = false;
    // デジタル, then 油彩風 at 混色度合い 50 with 色延び 0, 30 and 80: the
    // longer the stretch, the further the brush carries the colours it
    // picked up (yellow, then red) along the stroke.
    final rows = [
      (BrushMixingMode.off, 0, 0),
      (BrushMixingMode.oil, 50, 0),
      (BrushMixingMode.oil, 50, 30),
      (BrushMixingMode.oil, 50, 80),
    ];
    for (var r = 0; r < rows.length; r++) {
      engine.currentBrush = _mixingBrush(
        rows[r].$1,
        rows[r].$2,
        stretch: rows[r].$3,
      );
      final y = 45.0 + r * 70;
      engine.beginStroke(
        StrokePoint(x: 20, y: y, pressure: 1, tiltX: 0, tiltY: 0),
        'layer',
      );
      for (var x = 30.0; x <= width - 20; x += 10) {
        engine.continueStroke(
          StrokePoint(x: x, y: y, pressure: 1, tiltX: 0, tiltY: 0),
          'layer',
        );
      }
      engine.endStroke();
    }
    final sheet = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = tiles.getPixelColorAt('layer', x, y);
        final a = c?.a ?? 0.0;
        int over(double v) => (255 * (1 - a) + v * 255 * a).round();
        sheet.setPixelRgb(
          x,
          y,
          over(c?.r ?? 0),
          over(c?.g ?? 0),
          over(c?.b ?? 0),
        );
      }
    }
    _write('strokes.png', sheet);

    // Over the yellow the blue stroke turns green; over the red, purple.
    final green = tiles.getPixelColorAt('layer', 140, 115)!;
    expect(green.g, greaterThan(green.r + 0.3));
    final purple = tiles.getPixelColorAt('layer', 420, 115)!;
    expect(purple.b, greaterThan(purple.g + 0.3));
    expect(purple.r, greaterThan(purple.g + 0.2));
    // With 色延び the brush carries yellow past the yellow paint.
    final carried = tiles.getPixelColorAt('layer', 250, 255)!;
    final clean = tiles.getPixelColorAt('layer', 250, 115)!;
    expect(carried.g, greaterThan(clean.g + 0.15));
  });
}
