import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/lasso_fill_engine.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('ブレンドモード：複数の実色組み合わせを重ねて全17種のRGB変化を照合', () async {
    const pairs = [
      (ui.Color(0xFF244060), ui.Color(0xFFD06030)),
      (ui.Color(0xFFD8C090), ui.Color(0xFF3050D0)),
      (ui.Color(0xFF30B070), ui.Color(0xFFB040C0)),
    ];
    for (final mode in LayerBlendMode.values) {
      for (var i = 0; i < pairs.length; i++) {
        final tm = TileManager(canvasWidth: 64, canvasHeight: 64);
        _fillLayer(tm, 'bottom', 64, 64, pairs[i].$1);
        _fillLayer(
          tm,
          'top',
          64,
          64,
          pairs[i].$2,
          left: 16,
          top: 16,
          right: 48,
          bottom: 48,
        );
        final image = await LayerCompositor.composite(
          tm,
          [
            Layer(
              id: 'top',
              name: 'top',
              type: LayerType.normal,
              blendMode: mode,
            ),
            const Layer(id: 'bottom', name: 'bottom', type: LayerType.normal),
          ],
          (l) => l.id,
          64,
          64,
        );
        final rgba = await _rgba(image);
        final overlap = _pixel(rgba, 64, 32, 32);
        final outside = _pixel(rgba, 64, 8, 8);
        final expected = _blend(mode, pairs[i].$1, pairs[i].$2);
        for (var c = 0; c < 3; c++) {
          expect(
            (overlap[c] - expected[c]).abs(),
            lessThanOrEqualTo(5),
            reason:
                '${mode.name} pair=$i channel=$c actual=${overlap[c]} expected=${expected[c]}',
          );
        }
        expect(
          outside.sublist(0, 3),
          equals([pairs[i].$1.red, pairs[i].$1.green, pairs[i].$1.blue]),
          reason: '${mode.name} must not affect non-overlap area',
        );
        if (i == 0)
          await _save(image, '${out.path}/blend_interaction_${mode.name}.png');
        image.dispose();
        tm.dispose();
      }
    }
  });

  test('ブラシ不透明度：50%の線2本を交差させ非交差部50%、交差部75%になる', () async {
    final tm = TileManager(canvasWidth: 96, canvasHeight: 96);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 12, opacity: 50, spacing: 1)
      ..currentColor = const ui.Color(0xFF2040C0);

    // 実際の操作と同じく、横線を1ストローク描いてペンを離し、次に縦線を描く。
    engine.beginStroke(const StrokePoint(x: 16, y: 48), 'paint');
    engine.continueStroke(const StrokePoint(x: 80, y: 48), 'paint');
    engine.endStroke();
    engine.beginStroke(const StrokePoint(x: 48, y: 16), 'paint');
    engine.continueStroke(const StrokePoint(x: 48, y: 80), 'paint');
    engine.endStroke();

    final image = await tm.compositeLayerToImage('paint');
    await _save(image, '${out.path}/brush_opacity_cross_50.png');
    final d = await _rgba(image);
    final single = _pixel(d, 96, 30, 48);
    final cross = _pixel(d, 96, 48, 48);

    // 50% = 128/255。別ストロークを同じ場所へ重ねると
    // Aout = 128 + 128*(1-128/255) ≒ 192 (75%)。
    expect(
      single[3],
      inInclusiveRange(124, 132),
      reason:
          'one 50% stroke must remain at the configured opacity along its body',
    );
    expect(
      cross[3],
      inInclusiveRange(188, 196),
      reason:
          'only the intersection of two 50% strokes should become about 75% alpha',
    );
    expect(cross[3], greaterThan(single[3]));
    tm.dispose();
    image.dispose();
  });

  test('投げ縄：不規則多角形の外側へ1pxも塗りが漏れない', () async {
    const width = 96;
    const height = 96;
    const polygon = [
      ui.Offset(13, 19),
      ui.Offset(74, 14),
      ui.Offset(84, 47),
      ui.Offset(67, 82),
      ui.Offset(29, 74),
      ui.Offset(17, 52),
    ];
    final result = LassoFillEngine().fillLasso(
      points: polygon,
      color: const ui.Color(0xFF40A0E0),
      canvasData: Uint8List(width * height * 4),
      width: width,
      height: height,
    );
    await _saveRgba(
      result,
      width,
      height,
      '${out.path}/lasso_full_boundary_scan.png',
    );

    var leaked = 0;
    var paintedInside = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final painted = result[(y * width + x) * 4 + 3] > 0;
        final inside = _pointInPolygon(ui.Offset(x + 0.5, y + 0.5), polygon);
        if (painted && !inside) leaked++;
        if (painted && inside) paintedInside++;
      }
    }
    expect(
      leaked,
      0,
      reason:
          'lasso fill must not paint any pixel whose center is outside the polygon',
    );
    expect(paintedInside, greaterThan(1000));
  });

  test('クリッピング：上レイヤー由来の色が基底alpha外へ1pxも出ない', () async {
    const width = 96;
    const height = 96;
    final tm = TileManager(canvasWidth: width, canvasHeight: height);
    _fillLayer(
      tm,
      'base',
      width,
      height,
      const ui.Color(0xFF208050),
      left: 26,
      top: 24,
      right: 70,
      bottom: 72,
    );
    _fillLayer(
      tm,
      'top',
      width,
      height,
      const ui.Color(0xFFE03060),
      left: 4,
      top: 4,
      right: 92,
      bottom: 92,
    );

    final image = await LayerCompositor.composite(
      tm,
      const [
        Layer(
          id: 'top',
          name: 'top',
          type: LayerType.normal,
          hasClipping: true,
        ),
        Layer(id: 'base', name: 'base', type: LayerType.normal),
      ],
      (l) => l.id,
      width,
      height,
    );
    await _save(image, '${out.path}/clipping_full_boundary_scan.png');
    final d = await _rgba(image);
    var leaks = 0;
    var clippedPixels = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = _pixel(d, width, x, y);
        final isTopColor = p[0] > 200 && p[1] < 80 && p[2] < 120;
        final inBase = x >= 26 && x < 70 && y >= 24 && y < 72;
        if (isTopColor && !inBase) leaks++;
        if (isTopColor && inBase) clippedPixels++;
      }
    }
    expect(leaks, 0);
    expect(clippedPixels, 44 * 48);
    image.dispose();
    tm.dispose();
  });

  test('ピクセルモード：ブラシサイズに比例してドット径が変わり整数グリッドがずれない', () async {
    final small = await _pixelStampMask(canvas: 64, size: 8, cx: 20, cy: 20);
    final large = await _pixelStampMask(canvas: 64, size: 16, cx: 40, cy: 40);
    expect(_bboxWidth(small.$1, small.$2), 8);
    expect(_bboxHeight(small.$1, small.$2), 8);
    expect(_bboxWidth(large.$1, large.$2), 16);
    expect(_bboxHeight(large.$1, large.$2), 16);

    // 同じサイズのドットを別の整数座標へ置いたとき、相対形状が完全一致する。
    final a = await _pixelStampMask(canvas: 96, size: 12, cx: 24, cy: 30);
    final b = await _pixelStampMask(canvas: 96, size: 12, cx: 57, cy: 61);
    expect(
      _normalizeMask(a.$1, a.$2),
      equals(_normalizeMask(b.$1, b.$2)),
      reason:
          'pixel brush footprint must stay locked to the integer pixel grid',
    );

    // キャンバス寸法を変えても、同じブラシサイズのドットは同じピクセル寸法。
    final c64 = await _pixelStampMask(canvas: 64, size: 10, cx: 32, cy: 32);
    final c128 = await _pixelStampMask(canvas: 128, size: 10, cx: 64, cy: 64);
    expect(_bboxWidth(c64.$1, c64.$2), _bboxWidth(c128.$1, c128.$2));
    expect(_bboxHeight(c64.$1, c64.$2), _bboxHeight(c128.$1, c128.$2));
  });
}

Brush _brush({
  required double size,
  required int opacity,
  required int spacing,
}) => Brush(
  id: 'audit',
  name: 'audit',
  size: size,
  opacity: opacity,
  spacing: spacing,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureMode: PressureMode.off,
  pressureStrength: 100,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
);

Future<(Uint8List, int)> _pixelStampMask({
  required int canvas,
  required double size,
  required double cx,
  required double cy,
}) async {
  final tm = TileManager(canvasWidth: canvas, canvasHeight: canvas);
  final engine = DrawingEngine(tileManager: tm)
    ..currentBrush = Brush(
      id: 'px',
      name: 'px',
      size: size,
      opacity: 100,
      spacing: 1,
      blurRadius: 0,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: true,
      pressureMode: PressureMode.off,
      pressureStrength: 100,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      mixingMode: BrushMixingMode.off,
      mixingRate: 0,
    )
    ..currentColor = const ui.Color(0xFF000000);
  engine.beginStroke(StrokePoint(x: cx, y: cy), 'px');
  engine.endStroke();
  final image = await tm.compositeLayerToImage('px');
  final d = await _rgba(image);
  image.dispose();
  tm.dispose();
  return (d, canvas);
}

int _bboxWidth(Uint8List d, int width) {
  var minX = width, maxX = -1;
  for (var y = 0; y < width; y++)
    for (var x = 0; x < width; x++) {
      if (d[(y * width + x) * 4 + 3] > 0) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
      }
    }
  return maxX < minX ? 0 : maxX - minX + 1;
}

int _bboxHeight(Uint8List d, int width) {
  var minY = width, maxY = -1;
  for (var y = 0; y < width; y++)
    for (var x = 0; x < width; x++) {
      if (d[(y * width + x) * 4 + 3] > 0) {
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
  return maxY < minY ? 0 : maxY - minY + 1;
}

List<String> _normalizeMask(Uint8List d, int width) {
  var minX = width, maxX = -1, minY = width, maxY = -1;
  for (var y = 0; y < width; y++)
    for (var x = 0; x < width; x++) {
      if (d[(y * width + x) * 4 + 3] > 0) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
  final rows = <String>[];
  for (var y = minY; y <= maxY; y++) {
    final sb = StringBuffer();
    for (var x = minX; x <= maxX; x++)
      sb.write(d[(y * width + x) * 4 + 3] > 0 ? '1' : '0');
    rows.add(sb.toString());
  }
  return rows;
}

bool _pointInPolygon(ui.Offset p, List<ui.Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    final crosses =
        ((a.dy > p.dy) != (b.dy > p.dy)) &&
        (p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx);
    if (crosses) inside = !inside;
  }
  return inside;
}

void _fillLayer(
  TileManager tm,
  String id,
  int width,
  int height,
  ui.Color color, {
  int left = 0,
  int top = 0,
  int? right,
  int? bottom,
}) {
  final r = right ?? width, b = bottom ?? height;
  for (var y = top; y < b; y++) {
    for (var x = left; x < r; x++) {
      final tx = x ~/ TileManager.tileSize, ty = y ~/ TileManager.tileSize;
      final tile = tm.getOrCreateTile(id, tx, ty);
      tm.setPixel(
        tile,
        x % TileManager.tileSize,
        y % TileManager.tileSize,
        color.red,
        color.green,
        color.blue,
        color.alpha,
      );
      tm.markDirty(id, tx, ty);
    }
  }
}

Future<Uint8List> _rgba(ui.Image image) async => (await image.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

List<int> _pixel(List<int> rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
}

Future<void> _save(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

Future<void> _saveRgba(
  Uint8List rgba,
  int width,
  int height,
  String path,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  await _save(frame.image, path);
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
}

List<int> _blend(LayerBlendMode mode, ui.Color backdrop, ui.Color source) {
  final cb = [
    backdrop.red / 255.0,
    backdrop.green / 255.0,
    backdrop.blue / 255.0,
  ];
  final cs = [source.red / 255.0, source.green / 255.0, source.blue / 255.0];
  List<double> o;
  switch (mode) {
    case LayerBlendMode.normal:
      o = cs;
    case LayerBlendMode.multiply:
      o = List.generate(3, (i) => cb[i] * cs[i]);
    case LayerBlendMode.screen:
      o = List.generate(3, (i) => cb[i] + cs[i] - cb[i] * cs[i]);
    case LayerBlendMode.overlay:
      o = List.generate(
        3,
        (i) =>
            cb[i] <= .5 ? 2 * cb[i] * cs[i] : 1 - 2 * (1 - cb[i]) * (1 - cs[i]),
      );
    case LayerBlendMode.addition:
      o = List.generate(3, (i) => math.min(1, cb[i] + cs[i]));
    case LayerBlendMode.subtract:
      o = List.generate(3, (i) => math.max(0, cb[i] - cs[i]));
    case LayerBlendMode.darken:
      o = List.generate(3, (i) => math.min(cb[i], cs[i]));
    case LayerBlendMode.lighten:
      o = List.generate(3, (i) => math.max(cb[i], cs[i]));
    case LayerBlendMode.colorBurn:
      o = List.generate(
        3,
        (i) => cs[i] <= 0 ? 0 : 1 - math.min(1, (1 - cb[i]) / cs[i]),
      );
    case LayerBlendMode.colorDodge:
      o = List.generate(
        3,
        (i) => cs[i] >= 1 ? 1 : math.min(1, cb[i] / (1 - cs[i])),
      );
    case LayerBlendMode.hardLight:
      o = List.generate(
        3,
        (i) =>
            cs[i] <= .5 ? 2 * cb[i] * cs[i] : 1 - 2 * (1 - cb[i]) * (1 - cs[i]),
      );
    case LayerBlendMode.softLight:
      o = List.generate(3, (i) {
        final b = cb[i], s = cs[i];
        final d = b <= .25 ? ((16 * b - 12) * b + 4) * b : math.sqrt(b);
        return s <= .5
            ? b - (1 - 2 * s) * b * (1 - b)
            : b + (2 * s - 1) * (d - b);
      });
    case LayerBlendMode.difference:
      o = List.generate(3, (i) => (cb[i] - cs[i]).abs());
    case LayerBlendMode.hue:
      o = _setLum(_setSat(cs, _sat(cb)), _lum(cb));
    case LayerBlendMode.saturation:
      o = _setLum(_setSat(cb, _sat(cs)), _lum(cb));
    case LayerBlendMode.color:
      o = _setLum(cs, _lum(cb));
    case LayerBlendMode.luminosity:
      o = _setLum(cb, _lum(cs));
  }
  return o.map((v) => (v.clamp(0.0, 1.0) * 255).round()).toList();
}

double _lum(List<double> c) => .3 * c[0] + .59 * c[1] + .11 * c[2];
double _sat(List<double> c) => c.reduce(math.max) - c.reduce(math.min);
List<double> _clip(List<double> c) {
  var r = c[0], g = c[1], b = c[2];
  final l = _lum([r, g, b]);
  final n = math.min(r, math.min(g, b));
  if (n < 0) {
    r = l + (r - l) * l / (l - n);
    g = l + (g - l) * l / (l - n);
    b = l + (b - l) * l / (l - n);
  }
  final x = math.max(r, math.max(g, b));
  if (x > 1) {
    r = l + (r - l) * (1 - l) / (x - l);
    g = l + (g - l) * (1 - l) / (x - l);
    b = l + (b - l) * (1 - l) / (x - l);
  }
  return [r, g, b];
}

List<double> _setLum(List<double> c, double l) {
  final d = l - _lum(c);
  return _clip([c[0] + d, c[1] + d, c[2] + d]);
}

List<double> _setSat(List<double> c, double s) {
  final idx = [0, 1, 2]..sort((a, b) => c[a].compareTo(c[b]));
  final o = List<double>.from(c);
  final lo = idx[0], mi = idx[1], hi = idx[2];
  if (c[hi] > c[lo]) {
    o[mi] = (c[mi] - c[lo]) * s / (c[hi] - c[lo]);
    o[hi] = s;
  } else {
    o[mi] = 0;
    o[hi] = 0;
  }
  o[lo] = 0;
  return o;
}
