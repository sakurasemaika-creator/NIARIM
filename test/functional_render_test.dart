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

const _w = 96;
const _h = 96;
const _base = ui.Color.fromARGB(255, 60, 180, 120);
const _src = ui.Color.fromARGB(255, 100, 80, 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outDir = Directory('build/functional-visual');

  setUpAll(() {
    outDir.createSync(recursive: true);
  });

  testWidgets('全17ブレンドモードを実合成し結果画像を保存する', (tester) async {
    final seen = <String, List<int>>{};

    for (final mode in LayerBlendMode.values) {
      final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
      const bottomKey = 'bottom';
      const topKey = 'top';
      _fillLayer(tm, bottomKey, _base);
      _fillLayer(tm, topKey, _src, inset: 16);

      final layers = [
        Layer(id: topKey, name: 'top', type: LayerType.normal, blendMode: mode),
        const Layer(id: bottomKey, name: 'bottom', type: LayerType.normal),
      ];
      final image = await LayerCompositor.composite(
        tm,
        layers,
        (layer) => layer.id,
        _w,
        _h,
      );
      await _savePng(image, '${outDir.path}/blend_${mode.name}.png');
      final rgba = await _rgba(image);
      final center = _pixel(rgba, _w, 48, 48);
      seen[mode.name] = center;
      expect(center[3], 255, reason: '${mode.name}: 合成後alpha');

      final expected = _referenceBlend(mode, _base, _src);
      if (expected != null) {
        _expectRgbNear(center, expected, tolerance: 4, reason: mode.name);
      }

      image.dispose();
      tm.dispose();
    }

    // 名前だけ違って実際には同一結果、という配線ミスを検出する。
    expect(seen['multiply'], isNot(seen['screen']));
    expect(seen['addition'], isNot(seen['difference']));
    expect(seen['overlay'], isNot(seen['hardLight']));
  });

  testWidgets('通常ブラシが連続した丸筆ストロークになる', (tester) async {
    final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 20)
      ..currentColor = const ui.Color(0xFF202020);

    engine.beginStroke(const StrokePoint(x: 18, y: 48), 'brush');
    engine.continueStroke(const StrokePoint(x: 78, y: 48), 'brush');
    engine.endStroke();

    final image = await tm.compositeLayerToImage('brush');
    await _savePng(image, '${outDir.path}/brush_normal.png');
    final rgba = await _rgba(image);
    expect(_pixel(rgba, _w, 48, 48)[3], greaterThan(245));
    expect(_pixel(rgba, _w, 48, 20)[3], 0);
    expect(_pixel(rgba, _w, 18, 48)[3], greaterThan(200));
    image.dispose();
    tm.dispose();
  });

  testWidgets('ピクセルブラシはアンチエイリアス無しの輪郭になる', (tester) async {
    final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 18, pixelMode: true)
      ..currentColor = const ui.Color(0xFF000000);

    engine.beginStroke(const StrokePoint(x: 48, y: 48), 'pixel');
    engine.endStroke();
    final image = await tm.compositeLayerToImage('pixel');
    await _savePng(image, '${outDir.path}/brush_pixel.png');
    final rgba = await _rgba(image);
    final alphas = <int>{};
    for (var y = 35; y <= 61; y++) {
      for (var x = 35; x <= 61; x++) {
        alphas.add(_pixel(rgba, _w, x, y)[3]);
      }
    }
    expect(alphas.every((a) => a == 0 || a == 255), isTrue,
        reason: 'pixelModeに中間alphaが混ざっている');
    image.dispose();
    tm.dispose();
  });

  testWidgets('ソフトブラシは中心不透明・外周半透明のフォールオフになる', (tester) async {
    final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 20, blurRadius: 10)
      ..currentColor = const ui.Color(0xFF000000);

    engine.beginStroke(const StrokePoint(x: 48, y: 48), 'soft');
    engine.endStroke();
    final image = await tm.compositeLayerToImage('soft');
    await _savePng(image, '${outDir.path}/brush_soft.png');
    final rgba = await _rgba(image);
    expect(_pixel(rgba, _w, 48, 48)[3], 255);
    final outer = _pixel(rgba, _w, 63, 48)[3];
    expect(outer, inInclusiveRange(1, 254));
    expect(_pixel(rgba, _w, 72, 48)[3], 0);
    image.dispose();
    tm.dispose();
  });

  testWidgets('カリグラフィーブラシは固定角度の扁平なペン先になる', (tester) async {
    final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 18, calligraphyAngle: 0)
      ..currentColor = const ui.Color(0xFF000000);

    engine.beginStroke(const StrokePoint(x: 48, y: 48), 'calligraphy');
    engine.endStroke();
    final image = await tm.compositeLayerToImage('calligraphy');
    await _savePng(image, '${outDir.path}/brush_calligraphy.png');
    final rgba = await _rgba(image);
    expect(_pixel(rgba, _w, 66, 48)[3], greaterThan(0),
        reason: '横方向へ扁平化されていない');
    expect(_pixel(rgba, _w, 48, 66)[3], 0,
        reason: '縦方向まで同じ太さになっている');
    image.dispose();
    tm.dispose();
  });

  testWidgets('筆圧sizeは低筆圧で実際に細くなる', (tester) async {
    final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 28, pressureMode: PressureMode.size)
      ..currentColor = const ui.Color(0xFF000000);

    engine.beginStroke(const StrokePoint(x: 28, y: 48, pressure: 1.0), 'pressure');
    engine.endStroke();
    engine.beginStroke(const StrokePoint(x: 68, y: 48, pressure: 0.4), 'pressure');
    engine.endStroke();
    final image = await tm.compositeLayerToImage('pressure');
    await _savePng(image, '${outDir.path}/brush_pressure_size.png');
    final rgba = await _rgba(image);
    final fullSpan = _verticalAlphaSpan(rgba, _w, _h, 28);
    final lowSpan = _verticalAlphaSpan(rgba, _w, _h, 68);
    expect(fullSpan, greaterThan(lowSpan * 1.8));
    image.dispose();
    tm.dispose();
  });

  testWidgets('消しゴムは既存ストロークのalphaを実際に削る', (tester) async {
    final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 24)
      ..currentColor = const ui.Color(0xFF000000);

    engine.beginStroke(const StrokePoint(x: 20, y: 48), 'eraser');
    engine.continueStroke(const StrokePoint(x: 76, y: 48), 'eraser');
    engine.endStroke();
    engine.isEraser = true;
    engine.beginStroke(const StrokePoint(x: 48, y: 48), 'eraser');
    engine.endStroke();

    final image = await tm.compositeLayerToImage('eraser');
    await _savePng(image, '${outDir.path}/brush_eraser.png');
    final rgba = await _rgba(image);
    expect(_pixel(rgba, _w, 48, 48)[3], lessThan(10));
    expect(_pixel(rgba, _w, 30, 48)[3], greaterThan(200));
    image.dispose();
    tm.dispose();
  });

  testWidgets('トーンはテクスチャ周期を保ったままストローク形状内だけ描画する', (tester) async {
    final engine = ToneEngine();
    final canvas = Uint8List(_w * _h * 4);
    final tone = Uint8List.fromList([
      0, 0, 0, 255, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 255,
    ]); // 2x2 checker alpha
    final result = engine.drawToneStroke(
      points: const [ui.Offset(48, 48)],
      brushSize: 48,
      color: const ui.Color(0xFF7040D0),
      canvasData: canvas,
      canvasWidth: _w,
      canvasHeight: _h,
      toneTexture: tone,
      toneWidth: 2,
      toneHeight: 2,
    );
    final image = await _imageFromRgba(result, _w, _h);
    await _savePng(image, '${outDir.path}/tone_checker.png');
    expect(_pixel(result, _w, 48, 48)[3], 255);
    expect(_pixel(result, _w, 49, 48)[3], 0);
    expect(_pixel(result, _w, 49, 49)[3], 255);
    expect(_pixel(result, _w, 80, 80)[3], 0,
        reason: 'ブラシ円の外までトーンが描かれている');
    image.dispose();
  });

  testWidgets('トーン不透明度50%とトーン消去が実データへ反映される', (tester) async {
    final engine = ToneEngine();
    final canvas = Uint8List(_w * _h * 4);
    final tone = Uint8List.fromList([0, 0, 0, 255]);
    final drawn = engine.drawToneStroke(
      points: const [ui.Offset(48, 48)],
      brushSize: 36,
      color: const ui.Color(0xFF309060),
      canvasData: canvas,
      canvasWidth: _w,
      canvasHeight: _h,
      toneTexture: tone,
      toneWidth: 1,
      toneHeight: 1,
      opacity: 50,
    );
    expect(_pixel(drawn, _w, 48, 48)[3], inInclusiveRange(126, 129));

    final erased = engine.eraseToneStroke(
      points: const [ui.Offset(48, 48)],
      brushSize: 12,
      canvasData: drawn,
      canvasWidth: _w,
      canvasHeight: _h,
      toneTexture: tone,
      toneWidth: 1,
      toneHeight: 1,
    );
    final image = await _imageFromRgba(erased, _w, _h);
    await _savePng(image, '${outDir.path}/tone_opacity_erase.png');
    expect(_pixel(erased, _w, 48, 48)[3], 0);
    expect(_pixel(erased, _w, 60, 48)[3], greaterThan(120));
    image.dispose();
  });
}

Brush _brush({
  double size = 20,
  int blurRadius = 0,
  bool pixelMode = false,
  PressureMode pressureMode = PressureMode.off,
  double? calligraphyAngle,
}) =>
    Brush(
      id: 'functional',
      name: 'functional',
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

void _fillLayer(TileManager tm, String key, ui.Color color, {int inset = 0}) {
  final tile = tm.getOrCreateTile(key, 0, 0);
  for (var y = inset; y < _h - inset; y++) {
    for (var x = inset; x < _w - inset; x++) {
      tm.setPixel(tile, x, y, color.red, color.green, color.blue, color.alpha);
    }
  }
  tm.markDirty(key, 0, 0);
}

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

Future<void> _savePng(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('functional-visual captured: $path');
}

Future<ui.Image> _imageFromRgba(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

List<int> _pixel(Uint8List rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
}

int _verticalAlphaSpan(Uint8List rgba, int width, int height, int x) {
  var first = -1;
  var last = -1;
  for (var y = 0; y < height; y++) {
    if (_pixel(rgba, width, x, y)[3] > 0) {
      first = first < 0 ? y : first;
      last = y;
    }
  }
  return first < 0 ? 0 : last - first + 1;
}

void _expectRgbNear(List<int> actual, List<int> expected,
    {required int tolerance, required String reason}) {
  for (var i = 0; i < 3; i++) {
    expect((actual[i] - expected[i]).abs(), lessThanOrEqualTo(tolerance),
        reason: '$reason channel=$i actual=${actual[i]} expected=${expected[i]}');
  }
}

List<int>? _referenceBlend(LayerBlendMode mode, ui.Color base, ui.Color src) {
  final b = [base.red / 255.0, base.green / 255.0, base.blue / 255.0];
  final s = [src.red / 255.0, src.green / 255.0, src.blue / 255.0];
  double f(double cb, double cs) {
    return switch (mode) {
      LayerBlendMode.normal => cs,
      LayerBlendMode.multiply => cb * cs,
      LayerBlendMode.screen => cb + cs - cb * cs,
      LayerBlendMode.overlay => cb <= 0.5 ? 2 * cb * cs : 1 - 2 * (1 - cb) * (1 - cs),
      LayerBlendMode.addition => math.min(1.0, cb + cs),
      LayerBlendMode.subtract => math.max(0.0, cb - cs),
      LayerBlendMode.darken => math.min(cb, cs),
      LayerBlendMode.lighten => math.max(cb, cs),
      LayerBlendMode.colorBurn => cs <= 0 ? 0 : 1 - math.min(1.0, (1 - cb) / cs),
      LayerBlendMode.colorDodge => cs >= 1 ? 1 : math.min(1.0, cb / (1 - cs)),
      LayerBlendMode.hardLight => cs <= 0.5 ? 2 * cb * cs : 1 - 2 * (1 - cb) * (1 - cs),
      LayerBlendMode.softLight => cs <= 0.5
          ? cb - (1 - 2 * cs) * cb * (1 - cb)
          : cb + (2 * cs - 1) * (_softD(cb) - cb),
      LayerBlendMode.difference => (cb - cs).abs(),
      LayerBlendMode.hue ||
      LayerBlendMode.saturation ||
      LayerBlendMode.color ||
      LayerBlendMode.luminosity => double.nan,
    };
  }

  if (mode == LayerBlendMode.hue ||
      mode == LayerBlendMode.saturation ||
      mode == LayerBlendMode.color ||
      mode == LayerBlendMode.luminosity) {
    // HSL系はSkia実装をスクリーンショットで監査し、ここでは配線を
    // mapLayerBlendModeの列挙対応で保証する。チャンネル独立式ではないため
    // この単純リファレンスからは数値判定しない。
    return null;
  }
  return [for (var i = 0; i < 3; i++) (f(b[i], s[i]) * 255).round().clamp(0, 255)];
}

double _softD(double cb) => cb <= 0.25
    ? ((16 * cb - 12) * cb + 4) * cb
    : math.sqrt(cb);
