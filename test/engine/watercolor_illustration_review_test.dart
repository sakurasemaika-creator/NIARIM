// 水彩風混色で、参考にもらった水彩イラスト（制服の二人・木漏れ日の影・緑の
// 植え込み）のような塗り分けができるかの見本：
// ・ベタ塗り（むら少なめ・にじみ少なめ・縁くっきり）で制服の青や肌を塗る
// ・境界のぼかしで植え込みの緑をなめらかなグラデーションにする
// ・不透明度を下げた青灰色で木漏れ日の影を重ねる
// 最後に水彩境界フィルターで縁に色を溜める。
// build/brush-mixing/watercolor_illustration.png（左：ブラシのみ、右：水彩境界後）。
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/watercolor_border_engine.dart';
import 'package:niarim/models/brush.dart';

const _w = 420;
const _h = 300;

Brush _wash({
  double size = 30,
  int opacity = 100,
  int water = 30,
  int pigment = 60,
  int bleed = 10,
  int texture = 20,
  int softEdge = 0,
  int rate = 0,
}) => Brush(
  id: 'watercolor-illustration',
  name: 'Watercolor Illustration',
  size: size,
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

/// Fills a polygon with back-and-forth strokes, as an area is laid in.
void _fill(
  DrawingEngine engine,
  List<ui.Offset> polygon,
  ui.Color colour,
  Brush brush,
) {
  final top = polygon.map((p) => p.dy).reduce(math.min);
  final bottom = polygon.map((p) => p.dy).reduce(math.max);
  final inset = brush.size / 2;
  engine
    ..currentBrush = brush
    ..currentColor = colour
    ..pressureEnabled = false;
  for (var y = top + inset * 0.8; y <= bottom - inset * 0.6; y += inset) {
    // Where this row crosses the polygon.
    final xs = <double>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if ((a.dy <= y) != (b.dy <= y)) {
        xs.add(a.dx + (y - a.dy) / (b.dy - a.dy) * (b.dx - a.dx));
      }
    }
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      final x0 = xs[k] + inset * 0.8;
      final x1 = xs[k + 1] - inset * 0.8;
      if (x1 <= x0) continue;
      engine.beginStroke(StrokePoint(x: x0, y: y, pressure: 1), 'layer');
      for (var x = x0 + 4; x <= x1; x += 4) {
        engine.continueStroke(StrokePoint(x: x, y: y, pressure: 1), 'layer');
      }
      engine.endStroke();
    }
  }
}

List<ui.Offset> _ellipse(double cx, double cy, double rx, double ry) => [
  for (var i = 0; i < 48; i++)
    ui.Offset(
      cx + rx * math.cos(i / 48 * 2 * math.pi),
      cy + ry * math.sin(i / 48 * 2 * math.pi),
    ),
];

Uint8List _premultiplied(TileManager tiles) {
  final out = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final c = tiles.getPixelColorAt('layer', x, y);
      if (c == null) continue;
      final i = (y * _w + x) * 4;
      out[i] = (c.r * c.a * 255).round();
      out[i + 1] = (c.g * c.a * 255).round();
      out[i + 2] = (c.b * c.a * 255).round();
      out[i + 3] = (c.a * 255).round();
    }
  }
  return out;
}

void main() {
  test('watercolour illustration sample', () {
    final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tiles);
    // Hedge behind the fence: soft greens running into one another.
    for (final (cx, cy, colour) in [
      (70.0, 70.0, const ui.Color(0xFF2E8B57)),
      (150.0, 60.0, const ui.Color(0xFF5FB36A)),
      (110.0, 110.0, const ui.Color(0xFF1F6E4A)),
      (330.0, 70.0, const ui.Color(0xFF6CC27A)),
      (380.0, 110.0, const ui.Color(0xFF2E8B57)),
    ]) {
      _fill(
        engine,
        _ellipse(cx, cy, 70, 45),
        colour,
        _wash(
          size: 34,
          water: 40,
          bleed: 30,
          texture: 45,
          softEdge: 60,
          rate: 60,
          pigment: 80,
        ),
      );
    }
    // Darker leaves on the hedge: crisp shapes over the soft wash.
    final leaves = math.Random(11);
    for (var k = 0; k < 10; k++) {
      final cx = 20 + leaves.nextDouble() * 160;
      final cy = 40 + leaves.nextDouble() * 90;
      _fill(
        engine,
        _ellipse(
          cx,
          cy,
          9 + leaves.nextDouble() * 6,
          5 + leaves.nextDouble() * 3,
        ),
        const ui.Color(0xFF175C3C),
        _wash(size: 8, water: 20, bleed: 5, texture: 30, pigment: 70),
      );
    }
    // A school blazer: flat and crisp.
    _fill(
      engine,
      const [
        ui.Offset(200, 110),
        ui.Offset(260, 105),
        ui.Offset(285, 200),
        ui.Offset(180, 205),
      ],
      const ui.Color(0xFF3550B0),
      _wash(size: 24, water: 5, bleed: 0, texture: 10, pigment: 95),
    );
    // Skin.
    _fill(
      engine,
      _ellipse(230, 80, 26, 30),
      const ui.Color(0xFFF7D2B6),
      _wash(size: 20, water: 20, bleed: 0, texture: 5, pigment: 70),
    );
    // Hair.
    _fill(
      engine,
      const [
        ui.Offset(200, 48),
        ui.Offset(262, 46),
        ui.Offset(268, 90),
        ui.Offset(256, 70),
        ui.Offset(206, 72),
        ui.Offset(194, 96),
      ],
      const ui.Color(0xFF3D7BE0),
      _wash(size: 16, water: 25, bleed: 5, texture: 25),
    );
    // Dappled shade on the pavement: translucent blue-grey, layered.
    final random = math.Random(5);
    for (var k = 0; k < 9; k++) {
      _fill(
        engine,
        _ellipse(
          40 + random.nextDouble() * 340,
          225 + random.nextDouble() * 55,
          18 + random.nextDouble() * 22,
          8 + random.nextDouble() * 8,
        ),
        const ui.Color(0xFF9AACD0),
        _wash(size: 14, water: 30, bleed: 10, texture: 30, pigment: 45),
      );
    }

    final painted = _premultiplied(tiles);
    final bordered = applyWatercolorBorder(
      painted,
      _w,
      _h,
      range: 6,
      opacityEffect: 25,
      darkenEffect: 45,
      blur: 1,
    );
    final sheet = img.Image(width: _w * 2 + 10, height: _h);
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (final (data, ox) in [(painted, 0), (bordered, _w + 10)]) {
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          final i = (y * _w + x) * 4;
          final a = data[i + 3] / 255;
          int over(int c) => (c + 252 * (1 - a)).round().clamp(0, 255);
          sheet.setPixelRgb(
            x + ox,
            y,
            over(data[i]),
            over(data[i + 1]),
            over(data[i + 2]),
          );
        }
      }
    }
    final dir = Directory('build/brush-mixing')..createSync(recursive: true);
    File(
      '${dir.path}/watercolor_illustration.png',
    ).writeAsBytesSync(img.encodePng(sheet));
  });
}
