import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/tone_engine.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/layer.dart';

const w = 96;
const h = 96;
const base = ui.Color.fromARGB(255, 60, 180, 120);
const src = ui.Color.fromARGB(255, 100, 80, 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('17ブレンドモードを実合成し数値と画像で検証', () async {
    final outputs = <LayerBlendMode, List<int>>{};
    for (final mode in LayerBlendMode.values) {
      final tm = TileManager(canvasWidth: w, canvasHeight: h);
      _fill(tm, 'bottom', base);
      _fill(tm, 'top', src, inset: 16);
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
        w,
        h,
      );
      await _save(image, '${out.path}/blend_${mode.name}.png');
      final data = await _rgba(image);
      final p = _pixel(data, 48, 48);
      outputs[mode] = p;
      expect(p[3], 255, reason: '${mode.name} alpha');
      final expected = _reference(mode);
      if (expected != null) _near(p, expected, mode.name);
      image.dispose();
      tm.dispose();
    }
    expect(
      outputs[LayerBlendMode.multiply],
      isNot(equals(outputs[LayerBlendMode.screen])),
    );
    expect(
      outputs[LayerBlendMode.addition],
      isNot(equals(outputs[LayerBlendMode.difference])),
    );
    expect(
      outputs[LayerBlendMode.overlay],
      isNot(equals(outputs[LayerBlendMode.hardLight])),
    );
  });

  test('通常ブラシ：連続線・円形断面', () async {
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 20)
      ..currentColor = const ui.Color(0xFF202020);
    e.beginStroke(const StrokePoint(x: 18, y: 48), 'normal');
    e.continueStroke(const StrokePoint(x: 78, y: 48), 'normal');
    e.endStroke();
    final image = await tm.compositeLayerToImage('normal');
    await _save(image, '${out.path}/brush_normal.png');
    final d = await _rgba(image);
    expect(_pixel(d, 48, 48)[3], greaterThan(245));
    expect(_pixel(d, 48, 20)[3], 0);
    expect(_pixel(d, 18, 48)[3], greaterThan(200));
    image.dispose();
    tm.dispose();
  });

  test('ピクセルブラシ：中間alpha無し', () async {
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 18, pixelMode: true)
      ..currentColor = const ui.Color(0xFF000000);
    e.beginStroke(const StrokePoint(x: 48, y: 48), 'pixel');
    e.endStroke();
    final image = await tm.compositeLayerToImage('pixel');
    await _save(image, '${out.path}/brush_pixel.png');
    final d = await _rgba(image);
    final alphas = <int>{};
    for (var y = 34; y <= 62; y++) {
      for (var x = 34; x <= 62; x++) alphas.add(_pixel(d, x, y)[3]);
    }
    expect(alphas.every((a) => a == 0 || a == 255), isTrue);
    image.dispose();
    tm.dispose();
  });

  test('ソフトブラシ：中心から外周へalpha減衰', () async {
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 20, blurRadius: 10)
      ..currentColor = const ui.Color(0xFF000000);
    e.beginStroke(const StrokePoint(x: 48, y: 48), 'soft');
    e.endStroke();
    final image = await tm.compositeLayerToImage('soft');
    await _save(image, '${out.path}/brush_soft.png');
    final d = await _rgba(image);
    expect(_pixel(d, 48, 48)[3], 255);
    expect(_pixel(d, 63, 48)[3], inInclusiveRange(1, 254));
    expect(_pixel(d, 72, 48)[3], 0);
    image.dispose();
    tm.dispose();
  });

  test('カリグラフィー：固定角度の扁平ペン先', () async {
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 18, calligraphyAngle: 0)
      ..currentColor = const ui.Color(0xFF000000);
    e.beginStroke(const StrokePoint(x: 48, y: 48), 'calligraphy');
    e.endStroke();
    final image = await tm.compositeLayerToImage('calligraphy');
    await _save(image, '${out.path}/brush_calligraphy.png');
    final d = await _rgba(image);
    expect(_pixel(d, 66, 48)[3], greaterThan(0));
    expect(_pixel(d, 48, 66)[3], 0);
    image.dispose();
    tm.dispose();
  });

  test('筆圧size：低筆圧で細くなる', () async {
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 28, pressureMode: PressureMode.size)
      ..currentColor = const ui.Color(0xFF000000);
    e.beginStroke(const StrokePoint(x: 28, y: 48, pressure: 1), 'pressure');
    e.endStroke();
    e.beginStroke(const StrokePoint(x: 68, y: 48, pressure: 0.4), 'pressure');
    e.endStroke();
    final image = await tm.compositeLayerToImage('pressure');
    await _save(image, '${out.path}/brush_pressure_size.png');
    final d = await _rgba(image);
    expect(_span(d, 28), greaterThan(_span(d, 68) * 1.8));
    image.dispose();
    tm.dispose();
  });

  test('消しゴム：描画済みalphaを削る', () async {
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 24)
      ..currentColor = const ui.Color(0xFF000000);
    e.beginStroke(const StrokePoint(x: 20, y: 48), 'erase');
    e.continueStroke(const StrokePoint(x: 76, y: 48), 'erase');
    e.endStroke();
    e.isEraser = true;
    e.beginStroke(const StrokePoint(x: 48, y: 48), 'erase');
    e.endStroke();
    final image = await tm.compositeLayerToImage('erase');
    await _save(image, '${out.path}/brush_eraser.png');
    final d = await _rgba(image);
    expect(_pixel(d, 48, 48)[3], lessThan(10));
    expect(_pixel(d, 30, 48)[3], greaterThan(200));
    image.dispose();
    tm.dispose();
  });

  test('トーン：2x2周期を保ち円形ストローク内だけ描画', () async {
    final tone = Uint8List.fromList([
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      255,
    ]);
    final result = ToneEngine().drawToneStroke(
      points: const [ui.Offset(48, 48)],
      brushSize: 48,
      color: const ui.Color(0xFF7040D0),
      canvasData: Uint8List(w * h * 4),
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: tone,
      toneWidth: 2,
      toneHeight: 2,
    );
    final image = await _image(result);
    await _save(image, '${out.path}/tone_checker.png');
    expect(_pixel(result, 48, 48)[3], 255);
    expect(_pixel(result, 49, 48)[3], 0);
    expect(_pixel(result, 49, 49)[3], 255);
    expect(_pixel(result, 80, 80)[3], 0);
    image.dispose();
  });

  test('トーン：50%描画は既存の不透明背景へ正しくalpha合成される', () async {
    final background = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      background[i * 4] = 40;
      background[i * 4 + 1] = 80;
      background[i * 4 + 2] = 120;
      background[i * 4 + 3] = 255;
    }
    final result = ToneEngine().drawToneStroke(
      points: const [ui.Offset(48, 48)],
      brushSize: 30,
      color: const ui.Color(0xFFC04020),
      canvasData: background,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: Uint8List.fromList([0, 0, 0, 255]),
      toneWidth: 1,
      toneHeight: 1,
      opacity: 50,
    );
    final image = await _image(result);
    await _save(image, '${out.path}/tone_over_opaque_50.png');
    final p = _pixel(result, 48, 48);
    expect(p[3], 255, reason: '不透明背景へ50%トーンを重ねてもalphaは不透明のままのはず');
    _near(p, [116, 72, 76], 'tone alpha composite', tolerance: 3);
    image.dispose();
  });

  test('トーン消去：パターン形状で透明化', () async {
    final engine = ToneEngine();
    final drawn = engine.drawToneStroke(
      points: const [ui.Offset(48, 48)],
      brushSize: 36,
      color: const ui.Color(0xFF309060),
      canvasData: Uint8List(w * h * 4),
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: Uint8List.fromList([0, 0, 0, 255]),
      toneWidth: 1,
      toneHeight: 1,
    );
    final erased = engine.eraseToneStroke(
      points: const [ui.Offset(48, 48)],
      brushSize: 12,
      canvasData: drawn,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: Uint8List.fromList([0, 0, 0, 255]),
      toneWidth: 1,
      toneHeight: 1,
    );
    final image = await _image(erased);
    await _save(image, '${out.path}/tone_erase.png');
    expect(_pixel(erased, 48, 48)[3], 0);
    expect(_pixel(erased, 60, 48)[3], 255);
    image.dispose();
  });
}

Brush _brush({
  double size = 20,
  int blurRadius = 0,
  bool pixelMode = false,
  PressureMode pressureMode = PressureMode.off,
  double? calligraphyAngle,
}) => Brush(
  id: 'f',
  name: 'f',
  size: size,
  opacity: 100,
  spacing: 1,
  blurRadius: blurRadius,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: pixelMode,
  pressureMode: pressureMode,
  pressureStrength: 100,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
  calligraphyAngle: calligraphyAngle,
);

void _fill(TileManager tm, String key, ui.Color c, {int inset = 0}) {
  final tile = tm.getOrCreateTile(key, 0, 0);
  for (var y = inset; y < h - inset; y++) {
    for (var x = inset; x < w - inset; x++) {
      tm.setPixel(tile, x, y, c.red, c.green, c.blue, c.alpha);
    }
  }
  tm.markDirty(key, 0, 0);
}

Future<Uint8List> _rgba(ui.Image image) async => (await image.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

Future<void> _save(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('functional-visual captured: $path');
}

Future<ui.Image> _image(Uint8List data) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(data, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

List<int> _pixel(Uint8List d, int x, int y) {
  final i = (y * w + x) * 4;
  return [d[i], d[i + 1], d[i + 2], d[i + 3]];
}

int _span(Uint8List d, int x) {
  var first = -1, last = -1;
  for (var y = 0; y < h; y++) {
    if (_pixel(d, x, y)[3] > 0) {
      first = first < 0 ? y : first;
      last = y;
    }
  }
  return first < 0 ? 0 : last - first + 1;
}

void _near(
  List<int> actual,
  List<int> expected,
  String reason, {
  int tolerance = 4,
}) {
  for (var i = 0; i < 3; i++) {
    expect(
      (actual[i] - expected[i]).abs(),
      lessThanOrEqualTo(tolerance),
      reason: '$reason ch$i actual=${actual[i]} expected=${expected[i]}',
    );
  }
}

List<int>? _reference(LayerBlendMode mode) {
  final b = [base.red / 255, base.green / 255, base.blue / 255];
  final s = [src.red / 255, src.green / 255, src.blue / 255];
  if ({
    LayerBlendMode.hue,
    LayerBlendMode.saturation,
    LayerBlendMode.color,
    LayerBlendMode.luminosity,
  }.contains(mode))
    return null;
  double blend(double cb, double cs) => switch (mode) {
    LayerBlendMode.normal => cs,
    LayerBlendMode.multiply => cb * cs,
    LayerBlendMode.screen => cb + cs - cb * cs,
    LayerBlendMode.overlay =>
      cb <= .5 ? 2 * cb * cs : 1 - 2 * (1 - cb) * (1 - cs),
    LayerBlendMode.addition => math.min(1, cb + cs),
    LayerBlendMode.subtract => math.max(0, cb - cs),
    LayerBlendMode.darken => math.min(cb, cs),
    LayerBlendMode.lighten => math.max(cb, cs),
    LayerBlendMode.colorBurn => cs <= 0 ? 0 : 1 - math.min(1, (1 - cb) / cs),
    LayerBlendMode.colorDodge => cs >= 1 ? 1 : math.min(1, cb / (1 - cs)),
    LayerBlendMode.hardLight =>
      cs <= .5 ? 2 * cb * cs : 1 - 2 * (1 - cb) * (1 - cs),
    LayerBlendMode.softLight =>
      cs <= .5
          ? cb - (1 - 2 * cs) * cb * (1 - cb)
          : cb +
                (2 * cs - 1) *
                    ((cb <= .25
                            ? ((16 * cb - 12) * cb + 4) * cb
                            : math.sqrt(cb)) -
                        cb),
    LayerBlendMode.difference => (cb - cs).abs(),
    _ => double.nan,
  };
  return [
    for (var i = 0; i < 3; i++) (blend(b[i], s[i]) * 255).round().clamp(0, 255),
  ];
}
