import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/lasso_fill_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('ブラシ不透明度：25/50/75%を実際に別ストロークで重ね数値どおり累積', () async {
    for (final opacity in [25, 50, 75]) {
      final tm = TileManager(canvasWidth: 96, canvasHeight: 96);
      final engine = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(size: 10, opacity: opacity)
        ..currentColor = const ui.Color(0xFF3050D0);

      _line(
        engine,
        'paint',
        const ui.Offset(12, 48),
        const ui.Offset(84, 48),
        steps: 24,
      );
      final once = await tm.compositeLayerToImage('paint');
      final onceData = await _rgba(once);
      final singleAlpha = _pixel(onceData, 96, 28, 48)[3];
      once.dispose();

      _line(
        engine,
        'paint',
        const ui.Offset(48, 12),
        const ui.Offset(48, 84),
        steps: 24,
      );
      final twice = await tm.compositeLayerToImage('paint');
      await _save(twice, '${out.path}/brush_opacity_cross_$opacity.png');
      final d = await _rgba(twice);
      final crossAlpha = _pixel(d, 96, 48, 48)[3];
      final expectedSingle = (255 * opacity / 100).round();
      final a = expectedSingle / 255.0;
      final expectedCross = ((a + a * (1 - a)) * 255).round();
      expect(
        singleAlpha,
        inInclusiveRange(expectedSingle - 4, expectedSingle + 4),
        reason: '$opacity% one stroke must preserve configured opacity',
      );
      expect(
        crossAlpha,
        inInclusiveRange(expectedCross - 5, expectedCross + 5),
        reason:
            '$opacity% two separate strokes must source-over only at the intersection',
      );
      twice.dispose();
      tm.dispose();
    }
  });

  test('筆圧不透明度：同じブラシでpressure 1.0と0.4がalphaへ比例反映', () async {
    final tm = TileManager(canvasWidth: 96, canvasHeight: 64);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(
        size: 18,
        opacity: 100,
        pressureMode: PressureMode.opacity,
      )
      ..currentColor = const ui.Color(0xFF202020);

    engine.beginStroke(const StrokePoint(x: 28, y: 32, pressure: 1.0), 'p');
    engine.endStroke();
    engine.beginStroke(const StrokePoint(x: 68, y: 32, pressure: 0.4), 'p');
    engine.endStroke();

    final image = await tm.compositeLayerToImage('p');
    await _save(image, '${out.path}/brush_pressure_opacity.png');
    final d = await _rgba(image);
    expect(_pixel(d, 96, 28, 32)[3], inInclusiveRange(250, 255));
    expect(_pixel(d, 96, 68, 32)[3], inInclusiveRange(98, 106));
    image.dispose();
    tm.dispose();
  });

  test('手ブレ補正：同じジグザグ入力を強補正すると描画の縦振れ幅が小さくなる', () async {
    final raw = await _drawJitter(stabilized: false);
    final smooth = await _drawJitter(stabilized: true);
    await _saveRgba(raw, 128, 96, '${out.path}/brush_stabilization_off.png');
    await _saveRgba(
      smooth,
      128,
      96,
      '${out.path}/brush_stabilization_strong.png',
    );
    final rawSpan = _alphaYSpan(raw, 128, 96);
    final smoothSpan = _alphaYSpan(smooth, 128, 96);
    expect(
      smoothSpan,
      lessThan(rawSpan),
      reason:
          'strong stabilization should reduce the vertical excursion of the same jittery input',
    );
  });

  test('カスタムフェード：100→20%を長い実ストロークで描くと後半ほど薄い', () async {
    final tm = TileManager(canvasWidth: 128, canvasHeight: 64);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(
        size: 6,
        opacity: 100,
        fadeMode: FadeMode.custom,
        fadeCustom: const FadeCustomSettings(
          startValue: 100,
          endValue: 20,
          distancePx: 96,
        ),
      )
      ..currentColor = const ui.Color(0xFF2030C0);

    final pts = <ui.Offset>[];
    for (var x = 12.0; x <= 108; x += 4) pts.add(ui.Offset(x, 32));
    engine.beginStroke(StrokePoint(x: pts.first.dx, y: pts.first.dy), 'fade');
    for (final p in pts.skip(1)) {
      engine.continueStroke(StrokePoint(x: p.dx, y: p.dy), 'fade');
    }
    engine.endStroke();

    final image = await tm.compositeLayerToImage('fade');
    await _save(image, '${out.path}/brush_fade_custom.png');
    final d = await _rgba(image);
    final early = _pixel(d, 128, 18, 32)[3];
    final middle = _pixel(d, 128, 60, 32)[3];
    final late = _pixel(d, 128, 104, 32)[3];
    expect(early, greaterThan(middle));
    expect(middle, greaterThan(late));
    expect(early, greaterThan(220));
    expect(late, lessThan(100));
    image.dispose();
    tm.dispose();
  });

  test('混色：青い下地へ赤50%混色ブラシを置くと中間色になり不透明度は維持', () async {
    final tm = TileManager(canvasWidth: 80, canvasHeight: 80);
    final tile = tm.getOrCreateTile('mix', 0, 0);
    for (var y = 16; y < 64; y++) {
      for (var x = 16; x < 64; x++) {
        tm.setPixel(tile, x, y, 20, 60, 220, 255);
      }
    }
    tm.markDirty('mix', 0, 0);

    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(
        size: 20,
        opacity: 100,
        mixingMode: BrushMixingMode.simple,
        mixingRate: 50,
      )
      ..currentColor = const ui.Color(0xFFDC2814);
    engine.beginStroke(const StrokePoint(x: 40, y: 40), 'mix');
    engine.endStroke();

    final image = await tm.compositeLayerToImage('mix');
    await _save(image, '${out.path}/brush_mixing_50.png');
    final p = _pixel(await _rgba(image), 80, 40, 40);
    expect(p[3], 255);
    expect(p[0], inInclusiveRange(115, 125));
    expect(p[1], inInclusiveRange(45, 55));
    expect(p[2], inInclusiveRange(115, 125));
    image.dispose();
    tm.dispose();
  });

  test('図形ブラシ：閉じた四角形を実描画して四辺に穴がなく内部は塗られない', () async {
    final tm = TileManager(canvasWidth: 96, canvasHeight: 96);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 6, opacity: 100)
      ..currentColor = const ui.Color(0xFF202020);
    engine.commitShapePath(
      const [
        StrokePoint(x: 20, y: 20),
        StrokePoint(x: 76, y: 20),
        StrokePoint(x: 76, y: 76),
        StrokePoint(x: 20, y: 76),
      ],
      'shape',
      closeLoop: true,
    );
    final image = await tm.compositeLayerToImage('shape');
    await _save(image, '${out.path}/shape_rectangle_brush.png');
    final d = await _rgba(image);
    for (var x = 24; x <= 72; x += 4) {
      expect(_pixel(d, 96, x, 20)[3], greaterThan(200));
      expect(_pixel(d, 96, x, 76)[3], greaterThan(200));
    }
    for (var y = 24; y <= 72; y += 4) {
      expect(_pixel(d, 96, 20, y)[3], greaterThan(200));
      expect(_pixel(d, 96, 76, y)[3], greaterThan(200));
    }
    expect(
      _pixel(d, 96, 48, 48)[3],
      0,
      reason: 'outline shape must not fill its interior',
    );
    image.dispose();
    tm.dispose();
  });

  test('囲って塗る：空キャンバスでも投げ縄外へ一切漏れず選択範囲内だけ確定', () async {
    const polygon = [
      ui.Offset(15, 18),
      ui.Offset(79, 13),
      ui.Offset(85, 50),
      ui.Offset(62, 82),
      ui.Offset(24, 72),
    ];
    final result = LassoFillEngine().fillEnclosed(
      points: polygon,
      color: const ui.Color(0xFF70C040),
      canvasData: Uint8List(96 * 96 * 4),
      width: 96,
      height: 96,
    );
    await _saveRgba(
      result,
      96,
      96,
      '${out.path}/lasso_enclosed_polygon_limit.png',
    );
    var leaked = 0;
    var filled = 0;
    for (var y = 0; y < 96; y++) {
      for (var x = 0; x < 96; x++) {
        final has = result[(y * 96 + x) * 4 + 3] > 0;
        final inside = _pointInPolygon(ui.Offset(x + 0.5, y + 0.5), polygon);
        if (has && !inside) leaked++;
        if (has) filled++;
      }
    }
    expect(leaked, 0);
    expect(filled, greaterThan(1500));
  });
}

Brush _brush({
  required double size,
  required int opacity,
  PressureMode pressureMode = PressureMode.off,
  bool stabilization = false,
  int stabilizationStrength = 0,
  FadeMode fadeMode = FadeMode.off,
  FadeCustomSettings? fadeCustom,
  BrushMixingMode mixingMode = BrushMixingMode.off,
  int mixingRate = 0,
}) => Brush(
  id: 'audit',
  name: 'audit',
  size: size,
  opacity: opacity,
  spacing: 1,
  blurRadius: 0,
  stabilization: stabilization,
  stabilizationStrength: stabilizationStrength,
  pixelMode: false,
  pressureMode: pressureMode,
  pressureStrength: 100,
  fadeMode: fadeMode,
  fadeCustom: fadeCustom,
  strokeDecay: false,
  mixingMode: mixingMode,
  mixingRate: mixingRate,
);

void _line(
  DrawingEngine engine,
  String layer,
  ui.Offset a,
  ui.Offset b, {
  int steps = 20,
}) {
  engine.beginStroke(StrokePoint(x: a.dx, y: a.dy), layer);
  for (var i = 1; i <= steps; i++) {
    final t = i / steps;
    engine.continueStroke(
      StrokePoint(x: a.dx + (b.dx - a.dx) * t, y: a.dy + (b.dy - a.dy) * t),
      layer,
    );
  }
  engine.endStroke();
}

Future<Uint8List> _drawJitter({required bool stabilized}) async {
  final tm = TileManager(canvasWidth: 128, canvasHeight: 96);
  final engine = DrawingEngine(tileManager: tm)
    ..currentBrush = _brush(
      size: 5,
      opacity: 100,
      stabilization: stabilized,
      stabilizationStrength: stabilized ? 90 : 0,
    )
    ..currentColor = const ui.Color(0xFF202020);
  const ys = [
    48.0,
    31.0,
    64.0,
    33.0,
    62.0,
    35.0,
    60.0,
    37.0,
    58.0,
    40.0,
    55.0,
    44.0,
    52.0,
  ];
  engine.beginStroke(StrokePoint(x: 10, y: ys.first), 'j');
  for (var i = 1; i < ys.length; i++) {
    engine.continueStroke(StrokePoint(x: 10 + i * 8.0, y: ys[i]), 'j');
  }
  engine.endStroke();
  final image = await tm.compositeLayerToImage('j');
  final data = await _rgba(image);
  image.dispose();
  tm.dispose();
  return data;
}

int _alphaYSpan(Uint8List d, int width, int height) {
  var minY = height, maxY = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (d[(y * width + x) * 4 + 3] > 30) {
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
  }
  return maxY < minY ? 0 : maxY - minY + 1;
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
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
}
