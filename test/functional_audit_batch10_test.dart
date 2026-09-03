import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/text_render.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/text_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('筆圧強度：0/50/100で同じpressure=0.25の効き方が段階的に変わる', () async {
    final alphas = <int, int>{};
    for (final strength in [0, 50, 100]) {
      final tm = TileManager(canvasWidth: 72, canvasHeight: 72);
      final e = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(
          size: 20,
          opacity: 100,
          pressureMode: PressureMode.opacity,
          pressureStrength: strength,
        )
        ..currentColor = const ui.Color(0xFF202020);
      e.beginStroke(const StrokePoint(x: 36, y: 36, pressure: 0.25), 'p');
      e.endStroke();
      final image = await tm.compositeLayerToImage('p');
      await _save(image, '${out.path}/pressure_strength_$strength.png');
      alphas[strength] = _pixel(await _rgba(image), 72, 36, 36)[3];
      image.dispose();
      tm.dispose();
    }

    // strength=0 は筆圧影響なし、100 は入力pressureを完全反映、50 はその中間。
    expect(alphas[0]!, inInclusiveRange(250, 255));
    expect(alphas[100]!, inInclusiveRange(60, 68));
    expect(alphas[50]!, greaterThan(alphas[100]!));
    expect(alphas[50]!, lessThan(alphas[0]!));
    expect(alphas[50]!, inInclusiveRange(154, 166));
  });

  test('半透明消しゴム：50%を1回/2回別ストロークで掛けるとalphaが255→約127→約63', () async {
    final tm = TileManager(canvasWidth: 80, canvasHeight: 80);
    final tile = tm.getOrCreateTile('erase', 0, 0);
    for (var y = 12; y < 68; y++) {
      for (var x = 12; x < 68; x++) tm.setPixel(tile, x, y, 30, 120, 210, 255);
    }
    tm.markDirty('erase', 0, 0);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(size: 20, opacity: 50)
      ..isEraser = true;

    e.beginStroke(const StrokePoint(x: 40, y: 40), 'erase');
    e.endStroke();
    var image = await tm.compositeLayerToImage('erase');
    var d = await _rgba(image);
    final once = _pixel(d, 80, 40, 40)[3];
    image.dispose();

    e.beginStroke(const StrokePoint(x: 40, y: 40), 'erase');
    e.endStroke();
    image = await tm.compositeLayerToImage('erase');
    await _save(image, '${out.path}/eraser_opacity_50_twice.png');
    d = await _rgba(image);
    final twice = _pixel(d, 80, 40, 40)[3];
    expect(once, inInclusiveRange(124, 132));
    expect(twice, inInclusiveRange(60, 68));
    image.dispose();
    tm.dispose();
  });

  test('ピクセルモード連続線：長い斜線でも中間alpha無し・穴無し・同じ入力はキャンバス寸法に依存しない', () async {
    final a = await _drawPixelLine(canvas: 96, offset: const ui.Offset(0, 0));
    final b = await _drawPixelLine(
      canvas: 160,
      offset: const ui.Offset(24, 30),
    );
    await _saveRgba(a, 96, 96, '${out.path}/pixel_line_96.png');
    await _saveRgba(b, 160, 160, '${out.path}/pixel_line_160.png');

    final alphaSet = <int>{};
    for (var i = 3; i < a.length; i += 4) alphaSet.add(a[i]);
    expect(
      alphaSet.every((v) => v == 0 || v == 255),
      isTrue,
      reason: 'pixel mode must never create anti-aliased intermediate alpha',
    );

    // 実際の入力点列に沿う中心付近には穴が無いことを確認。
    for (var i = 0; i <= 24; i++) {
      final t = i / 24;
      final x = (14 + (80 - 14) * t).round();
      final y = (18 + (75 - 18) * t).round();
      expect(
        _hasOpaqueNear(a, 96, x, y, radius: 2),
        isTrue,
        reason: 'hole at $x,$y',
      );
    }

    // 96側の描画を24,30平行移動した領域と160側の相対形状が一致。
    for (var y = 8; y < 88; y++) {
      for (var x = 8; x < 88; x++) {
        final aa = a[(y * 96 + x) * 4 + 3] > 0;
        final bb = b[((y + 30) * 160 + (x + 24)) * 4 + 3] > 0;
        expect(
          bb,
          aa,
          reason: 'pixel-grid footprint mismatch at relative $x,$y',
        );
      }
    }
  });

  test('色伸び：青下地を赤ブラシで連続ストロークすると開始側ほど下地色を拾い後半で選択色へ寄る', () async {
    final tm = TileManager(canvasWidth: 120, canvasHeight: 64);
    final tile = tm.getOrCreateTile('bleed', 0, 0);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 120; x++) tm.setPixel(tile, x, y, 20, 60, 220, 255);
    }
    tm.markDirty('bleed', 0, 0);
    final e = DrawingEngine(tileManager: tm)
      ..currentBrush = _brush(
        size: 10,
        opacity: 100,
        mixingMode: BrushMixingMode.bleed,
        mixingRate: 80,
      )
      ..currentColor = const ui.Color(0xFFDC2814);
    e.beginStroke(const StrokePoint(x: 12, y: 32), 'bleed');
    for (var x = 16.0; x <= 108; x += 4) {
      e.continueStroke(StrokePoint(x: x, y: 32), 'bleed');
    }
    e.endStroke();
    final image = await tm.compositeLayerToImage('bleed');
    await _save(image, '${out.path}/brush_bleed_continuous.png');
    final d = await _rgba(image);
    final early = _pixel(d, 120, 20, 32);
    final late = _pixel(d, 120, 100, 32);
    expect(
      late[0],
      greaterThan(early[0]),
      reason: 'later stroke should move toward selected red',
    );
    expect(
      late[2],
      lessThan(early[2]),
      reason: 'later stroke should carry less picked-up blue',
    );
    image.dispose();
    tm.dispose();
  });

  test('テキスト：横書き/縦書き/縁取り/pixelModeを実ラスタライズして形状とalphaを確認', () async {
    const base = TextObject(
      id: 't',
      text: 'NIARIM 12',
      fontSize: 28,
      color: ui.Color(0xFF202020),
      position: ui.Offset(20, 25),
    );
    final horizontal = await rasterizeTextObject(base, 240, 160);
    expect(horizontal, isNotNull);
    await _saveRgba(horizontal!, 240, 160, '${out.path}/text_horizontal.png');

    final verticalObj = base.copyWith(
      text: '縦12A',
      direction: TextWritingDirection.vertical,
      position: const ui.Offset(90, 10),
    );
    final vertical = await rasterizeTextObject(verticalObj, 240, 200);
    expect(vertical, isNotNull);
    await _saveRgba(vertical!, 240, 200, '${out.path}/text_vertical.png');
    final hb = _alphaBounds(horizontal, 240, 160);
    final vb = _alphaBounds(vertical, 240, 200);
    expect(
      hb.width,
      greaterThan(hb.height),
      reason: 'horizontal text should be wider than tall',
    );
    expect(
      vb.height,
      greaterThan(vb.width),
      reason: 'vertical text should be taller than wide',
    );

    final outlined = await rasterizeTextObject(
      base.copyWith(
        outline: const TextOutline(
          enabled: true,
          color: ui.Color(0xFFFF3040),
          width: 3,
        ),
      ),
      240,
      160,
    );
    expect(outlined, isNotNull);
    await _saveRgba(outlined!, 240, 160, '${out.path}/text_outline.png');
    expect(
      _countNonTransparent(outlined),
      greaterThan(_countNonTransparent(horizontal)),
      reason: 'outline should add pixels around glyphs',
    );

    final pixel = await rasterizeTextObject(base, 240, 160, pixelMode: true);
    expect(pixel, isNotNull);
    await _saveRgba(pixel!, 240, 160, '${out.path}/text_pixel_mode.png');
    final alphas = <int>{};
    for (var i = 3; i < pixel.length; i += 4) alphas.add(pixel[i]);
    expect(
      alphas.every((v) => v == 0 || v == 255),
      isTrue,
      reason: 'pixel text must remove anti-alias intermediate alpha',
    );
  });
}

Brush _brush({
  required double size,
  required int opacity,
  PressureMode pressureMode = PressureMode.off,
  int pressureStrength = 100,
  BrushMixingMode mixingMode = BrushMixingMode.off,
  int mixingRate = 0,
}) => Brush(
  id: 'audit',
  name: 'audit',
  size: size,
  opacity: opacity,
  spacing: 1,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureMode: pressureMode,
  pressureStrength: pressureStrength,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: mixingMode,
  mixingRate: mixingRate,
);

Future<Uint8List> _drawPixelLine({
  required int canvas,
  required ui.Offset offset,
}) async {
  final tm = TileManager(canvasWidth: canvas, canvasHeight: canvas);
  final e = DrawingEngine(tileManager: tm)
    ..currentBrush = Brush(
      id: 'px',
      name: 'px',
      size: 7,
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
    ..currentColor = const ui.Color(0xFF202020);
  final a = ui.Offset(14 + offset.dx, 18 + offset.dy);
  final b = ui.Offset(80 + offset.dx, 75 + offset.dy);
  e.beginStroke(StrokePoint(x: a.dx, y: a.dy), 'px');
  for (var i = 1; i <= 24; i++) {
    final t = i / 24;
    e.continueStroke(
      StrokePoint(x: a.dx + (b.dx - a.dx) * t, y: a.dy + (b.dy - a.dy) * t),
      'px',
    );
  }
  e.endStroke();
  final image = await tm.compositeLayerToImage('px');
  final data = await _rgba(image);
  image.dispose();
  tm.dispose();
  return data;
}

bool _hasOpaqueNear(
  Uint8List d,
  int width,
  int x,
  int y, {
  required int radius,
}) {
  for (
    var yy = math.max(0, y - radius);
    yy <= math.min(width - 1, y + radius);
    yy++
  ) {
    for (
      var xx = math.max(0, x - radius);
      xx <= math.min(width - 1, x + radius);
      xx++
    ) {
      if (d[(yy * width + xx) * 4 + 3] == 255) return true;
    }
  }
  return false;
}

ui.Rect _alphaBounds(Uint8List d, int width, int height) {
  var minX = width, minY = height, maxX = -1, maxY = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (d[(y * width + x) * 4 + 3] == 0) continue;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
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

int _countNonTransparent(Uint8List d) {
  var n = 0;
  for (var i = 3; i < d.length; i += 4) if (d[i] > 0) n++;
  return n;
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
