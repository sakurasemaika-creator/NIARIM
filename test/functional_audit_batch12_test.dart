import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('フェード仕様：強フェードは長い1ストロークで不透明度だけでなく線幅も細くなる', () async {
    final tm = TileManager(canvasWidth: 260, canvasHeight: 100);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 30, fadeMode: FadeMode.strong)
      ..currentColor = const ui.Color(0xFF2040C0);
    _line(
      e,
      'fade',
      const ui.Offset(20, 50),
      const ui.Offset(238, 50),
      steps: 55,
    );
    final image = await tm.compositeLayerToImage('fade');
    await _save(image, '${out.path}/fade_strong_size_and_opacity.png');
    final d = await _rgba(image);

    final earlySpan = _verticalSpan(d, 260, 100, 35, threshold: 15);
    final midSpan = _verticalSpan(d, 260, 100, 115, threshold: 15);
    final lateSpan = _verticalSpan(d, 260, 100, 185, threshold: 15);
    final earlyAlpha = _pixel(d, 260, 35, 50)[3];
    final midAlpha = _pixel(d, 260, 115, 50)[3];
    final lateAlpha = _pixel(d, 260, 185, 50)[3];

    expect(earlyAlpha, greaterThan(midAlpha));
    expect(midAlpha, greaterThan(lateAlpha));
    expect(
      earlySpan,
      greaterThan(midSpan),
      reason: 'fade must reduce brush size, not opacity only',
    );
    expect(
      midSpan,
      greaterThan(lateSpan),
      reason: 'later stroke must continue becoming thinner',
    );
    image.dispose();
    tm.dispose();
  });

  test('カスタムフェード：100→30%/120pxで線幅とalphaが設定距離に沿って同時減衰', () async {
    final tm = TileManager(canvasWidth: 210, canvasHeight: 100);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(
        size: 28,
        fadeMode: FadeMode.custom,
        fadeCustom: const FadeCustomSettings(
          startValue: 100,
          endValue: 30,
          distancePx: 120,
        ),
      )
      ..currentColor = const ui.Color(0xFFB03040);
    _line(
      e,
      'fade',
      const ui.Offset(20, 50),
      const ui.Offset(180, 50),
      steps: 40,
    );
    final image = await tm.compositeLayerToImage('fade');
    await _save(image, '${out.path}/fade_custom_size_and_opacity.png');
    final d = await _rgba(image);

    final startSpan = _verticalSpan(d, 210, 100, 30, threshold: 10);
    final endSpan = _verticalSpan(d, 210, 100, 150, threshold: 10);
    final startAlpha = _pixel(d, 210, 30, 50)[3];
    final endAlpha = _pixel(d, 210, 150, 50)[3];
    expect(startSpan, greaterThan(endSpan * 1.8));
    expect(startAlpha, greaterThan(endAlpha * 1.8));
    expect(
      endSpan,
      inInclusiveRange(6, 12),
      reason: '30% of 28px should be roughly 8px plus raster edge',
    );
    image.dispose();
    tm.dispose();
  });

  test('傾き：ペンを寝かせた方向へ伸び、左右対称の一様濃度ではなく方向性の濃淡を持つ', () async {
    final tm = TileManager(canvasWidth: 120, canvasHeight: 120);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 24)
      ..currentColor = const ui.Color(0xFF202020);
    e.beginStroke(
      const StrokePoint(x: 60, y: 60, tiltX: 0.75, tiltY: 0.0),
      'tilt',
    );
    e.endStroke();
    final image = await tm.compositeLayerToImage('tilt');
    await _save(image, '${out.path}/brush_tilt_directional_shading.png');
    final d = await _rgba(image);
    final bounds = _alphaBounds(d, 120, 120, threshold: 5);
    expect(
      bounds.width,
      greaterThan(bounds.height * 1.7),
      reason: 'positive tiltX should stretch footprint horizontally',
    );

    // 中心から等距離の前後で濃度差があることを要求する。
    // 仕様の「ペン先側を濃く・手前側を薄く」の方向性が実際の画素に現れる必要がある。
    final left = _pixel(d, 120, 48, 60)[3];
    final right = _pixel(d, 120, 72, 60)[3];
    expect(
      (left - right).abs(),
      greaterThan(12),
      reason:
          'tilted nib must have directional alpha shading, not a uniformly filled symmetric ellipse',
    );
    image.dispose();
    tm.dispose();
  });

  test('筆圧 sizeAndOpacity：pressure 0.35では太さとalphaの両方が同時に縮む', () async {
    final tm = TileManager(canvasWidth: 120, canvasHeight: 80);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(
        size: 30,
        pressureMode: PressureMode.sizeAndOpacity,
        pressureStrength: 100,
      )
      ..currentColor = const ui.Color(0xFF202020);
    e.beginStroke(const StrokePoint(x: 30, y: 40, pressure: 1), 'p');
    e.endStroke();
    e.beginStroke(const StrokePoint(x: 90, y: 40, pressure: 0.35), 'p');
    e.endStroke();
    final image = await tm.compositeLayerToImage('p');
    await _save(image, '${out.path}/pressure_size_and_opacity.png');
    final d = await _rgba(image);
    final fullSpan = _verticalSpan(d, 120, 80, 30, threshold: 5);
    final lowSpan = _verticalSpan(d, 120, 80, 90, threshold: 5);
    final fullAlpha = _pixel(d, 120, 30, 40)[3];
    final lowAlpha = _pixel(d, 120, 90, 40)[3];
    expect(fullSpan, greaterThan(lowSpan * 2.3));
    expect(fullAlpha, inInclusiveRange(250, 255));
    expect(lowAlpha, inInclusiveRange(84, 94));
    image.dispose();
    tm.dispose();
  });

  test('ストローク減衰：長く描き続けた後半だけ自然に薄くなり、太さは維持', () async {
    final tm = TileManager(canvasWidth: 260, canvasHeight: 90);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 18, strokeDecay: true)
      ..currentColor = const ui.Color(0xFF206040);
    _line(
      e,
      'decay',
      const ui.Offset(15, 45),
      const ui.Offset(245, 45),
      steps: 60,
    );
    final image = await tm.compositeLayerToImage('decay');
    await _save(image, '${out.path}/brush_stroke_decay.png');
    final d = await _rgba(image);
    final early = _pixel(d, 260, 30, 45)[3];
    final late = _pixel(d, 260, 220, 45)[3];
    final earlySpan = _verticalSpan(d, 260, 90, 30, threshold: 8);
    final lateSpan = _verticalSpan(d, 260, 90, 220, threshold: 8);
    expect(early, greaterThan(late));
    expect(
      (earlySpan - lateSpan).abs(),
      lessThanOrEqualTo(2),
      reason: 'strokeDecay is an opacity-only ink depletion feature',
    );
    image.dispose();
    tm.dispose();
  });

  test('ブラシ間隔：spacingを広げると個々のスタンプが分離し、狭いspacingでは連続線になる', () async {
    final dense = await _drawSpacing(2);
    final sparse = await _drawSpacing(22);
    await _saveRgba(dense, 180, 70, '${out.path}/brush_spacing_dense.png');
    await _saveRgba(sparse, 180, 70, '${out.path}/brush_spacing_sparse.png');
    expect(_countTransparentGapsOnRow(dense, 180, 35, 20, 160), 0);
    expect(
      _countTransparentGapsOnRow(sparse, 180, 35, 20, 160),
      greaterThan(3),
    );
  });
}

Brush _brush({
  required double size,
  FadeMode fadeMode = FadeMode.off,
  FadeCustomSettings? fadeCustom,
  PressureMode pressureMode = PressureMode.off,
  int pressureStrength = 100,
  bool strokeDecay = false,
}) => Brush(
  id: 'audit',
  name: 'audit',
  size: size,
  opacity: 100,
  spacing: 1,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureMode: pressureMode,
  pressureStrength: pressureStrength,
  fadeMode: fadeMode,
  fadeCustom: fadeCustom,
  strokeDecay: strokeDecay,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
);

void _line(
  DrawingEngine e,
  String layer,
  ui.Offset a,
  ui.Offset b, {
  required int steps,
}) {
  e.beginStroke(StrokePoint(x: a.dx, y: a.dy), layer);
  for (var i = 1; i <= steps; i++) {
    final t = i / steps;
    e.continueStroke(
      StrokePoint(x: a.dx + (b.dx - a.dx) * t, y: a.dy + (b.dy - a.dy) * t),
      layer,
    );
  }
  e.endStroke();
}

Future<Uint8List> _drawSpacing(int spacing) async {
  final tm = TileManager(canvasWidth: 180, canvasHeight: 70);
  final e = DrawingEngine(tileManager: tm)
    ..currentBrush = Brush(
      id: 's',
      name: 's',
      size: 10,
      opacity: 100,
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
    )
    ..currentColor = const ui.Color(0xFF202020);
  // 1回のcontinueStrokeでengine自身のspacing分割を使う。
  e.beginStroke(const StrokePoint(x: 20, y: 35), 's');
  e.continueStroke(const StrokePoint(x: 160, y: 35), 's');
  e.endStroke();
  final image = await tm.compositeLayerToImage('s');
  final d = await _rgba(image);
  image.dispose();
  tm.dispose();
  return d;
}

int _countTransparentGapsOnRow(Uint8List d, int width, int y, int x0, int x1) {
  var gaps = 0;
  var inGap = false;
  for (var x = x0; x <= x1; x++) {
    final transparent = d[(y * width + x) * 4 + 3] == 0;
    if (transparent && !inGap) {
      gaps++;
      inGap = true;
    } else if (!transparent) {
      inGap = false;
    }
  }
  return gaps;
}

int _verticalSpan(
  Uint8List d,
  int width,
  int height,
  int x, {
  required int threshold,
}) {
  var minY = height, maxY = -1;
  for (var y = 0; y < height; y++) {
    if (d[(y * width + x) * 4 + 3] >= threshold) {
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
  }
  return maxY < minY ? 0 : maxY - minY + 1;
}

ui.Rect _alphaBounds(
  Uint8List d,
  int width,
  int height, {
  required int threshold,
}) {
  var minX = width, minY = height, maxX = -1, maxY = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (d[(y * width + x) * 4 + 3] >= threshold) {
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }
  }
  if (maxX < minX) return ui.Rect.zero;
  return ui.Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}

List<int> _pixel(List<int> d, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [d[i], d[i + 1], d[i + 2], d[i + 3]];
}

Future<Uint8List> _rgba(ui.Image i) async => (await i.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();
Future<void> _save(ui.Image i, String p) async {
  final d = await i.toByteData(format: ui.ImageByteFormat.png);
  await File(p).writeAsBytes(d!.buffer.asUint8List());
}

Future<void> _saveRgba(Uint8List rgba, int w, int h, String p) async {
  final b = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    b,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final c = await desc.instantiateCodec();
  final f = await c.getNextFrame();
  final png = await f.image.toByteData(format: ui.ImageByteFormat.png);
  await File(p).writeAsBytes(png!.buffer.asUint8List());
  f.image.dispose();
  c.dispose();
  desc.dispose();
  b.dispose();
}
