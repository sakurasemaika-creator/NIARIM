import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tone_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('同一トーンを同じ場所へ何度描いてもパターン位置と密度は変わらない', () async {
    const w = 128, h = 96;
    final tone = _checkerTone(8, 8);
    final points = List<ui.Offset>.generate(
      80,
      (i) => ui.Offset(24 + i.toDouble(), 48),
    );
    final blank = Uint8List(w * h * 4);
    final once = ToneEngine().drawToneStroke(
      points: points,
      brushSize: 42,
      color: const ui.Color(0xFF202020),
      canvasData: blank,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: tone,
      toneWidth: 8,
      toneHeight: 8,
      opacity: 100,
    );
    final twice = ToneEngine().drawToneStroke(
      points: points,
      brushSize: 42,
      color: const ui.Color(0xFF202020),
      canvasData: once,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: tone,
      toneWidth: 8,
      toneHeight: 8,
      opacity: 100,
    );
    final tenTimes = List.generate(8, (_) => 0).fold<Uint8List>(
      twice,
      (data, _) => ToneEngine().drawToneStroke(
        points: points,
        brushSize: 42,
        color: const ui.Color(0xFF202020),
        canvasData: data,
        canvasWidth: w,
        canvasHeight: h,
        toneTexture: tone,
        toneWidth: 8,
        toneHeight: 8,
        opacity: 100,
      ),
    );

    await _save(once, w, h, '${out.path}/tone_same_once.png');
    await _save(tenTimes, w, h, '${out.path}/tone_same_ten_times.png');
    expect(_opaquePositions(twice, w, h), orderedEquals(_opaquePositions(once, w, h)));
    expect(_opaquePositions(tenTimes, w, h), orderedEquals(_opaquePositions(once, w, h)),
        reason: 'same fixed tone must never fill its own transparent gaps on repeated strokes');
  });

  test('ストローク開始位置が違ってもトーンの位相はキャンバス座標へ固定される', () async {
    const w = 128, h = 96;
    final tone = _verticalStripeTone(7, 5);
    final blank = Uint8List(w * h * 4);
    final leftStroke = ToneEngine().drawToneStroke(
      points: const [ui.Offset(18, 48)],
      brushSize: 42,
      color: const ui.Color(0xFF303030),
      canvasData: blank,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: tone,
      toneWidth: 7,
      toneHeight: 5,
    );
    final rightStroke = ToneEngine().drawToneStroke(
      points: const [ui.Offset(82, 48)],
      brushSize: 42,
      color: const ui.Color(0xFF303030),
      canvasData: blank,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: tone,
      toneWidth: 7,
      toneHeight: 5,
    );
    await _save(leftStroke, w, h, '${out.path}/tone_phase_left.png');
    await _save(rightStroke, w, h, '${out.path}/tone_phase_right.png');

    // 両ストロークの共通y=48上で、描画されるxは常にx%7==1になる。
    for (var x = 0; x < w; x++) {
      final aLeft = leftStroke[(48 * w + x) * 4 + 3];
      final aRight = rightStroke[(48 * w + x) * 4 + 3];
      if (aLeft != 0 || aRight != 0) {
        expect(x % 7, 1,
            reason: 'tone phase must be anchored to canvas x, not stroke origin');
      }
    }
  });

  test('異なる固定トーンなら互いの空白を補ってディザリングできる', () async {
    const w = 128, h = 96;
    final toneA = _evenColumnTone(4, 4);
    final toneB = _oddColumnTone(4, 4);
    final points = List<ui.Offset>.generate(80, (i) => ui.Offset(24 + i.toDouble(), 48));
    final blank = Uint8List(w * h * 4);
    final aOnly = ToneEngine().drawToneStroke(
      points: points,
      brushSize: 42,
      color: const ui.Color(0xFF202020),
      canvasData: blank,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: toneA,
      toneWidth: 4,
      toneHeight: 4,
    );
    final aPlusB = ToneEngine().drawToneStroke(
      points: points,
      brushSize: 42,
      color: const ui.Color(0xFF202020),
      canvasData: aOnly,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: toneB,
      toneWidth: 4,
      toneHeight: 4,
    );
    await _save(aOnly, w, h, '${out.path}/tone_dither_a.png');
    await _save(aPlusB, w, h, '${out.path}/tone_dither_a_plus_b.png');

    expect(_nonTransparentCount(aPlusB), greaterThan(_nonTransparentCount(aOnly)),
        reason: 'a different tone may reveal positions that were gaps in the first tone');
  });
}

Uint8List _checkerTone(int w, int h) {
  final d = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if ((x + y).isEven) d[(y * w + x) * 4 + 3] = 255;
    }
  }
  return d;
}

Uint8List _verticalStripeTone(int w, int h) {
  final d = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x == 1) d[(y * w + x) * 4 + 3] = 255;
    }
  }
  return d;
}

Uint8List _evenColumnTone(int w, int h) {
  final d = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x.isEven) d[(y * w + x) * 4 + 3] = 255;
    }
  }
  return d;
}

Uint8List _oddColumnTone(int w, int h) {
  final d = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x.isOdd) d[(y * w + x) * 4 + 3] = 255;
    }
  }
  return d;
}

List<int> _opaquePositions(Uint8List rgba, int w, int h) {
  final out = <int>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (rgba[(y * w + x) * 4 + 3] != 0) out.add(y * w + x);
    }
  }
  return out;
}

int _nonTransparentCount(Uint8List rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0) n++;
  }
  return n;
}

Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    buffer, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await desc.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  frame.image.dispose(); codec.dispose(); desc.dispose(); buffer.dispose();
}
