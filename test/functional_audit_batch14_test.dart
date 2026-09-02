import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/stamp_engine.dart';
import 'package:niarim/models/stamp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('スタンプ密度0.5/1/2/5は実際の重なり量が段階的に増える', () async {
    const w = 320, h = 100;
    final tex = _solidTexture(7, alpha: 40);
    final results = <double, Uint8List>{};
    for (final density in [0.5, 1.0, 2.0, 5.0]) {
      final d = StampEngine().stampAlongPath(
        canvasData: Uint8List(w * h * 4),
        width: w,
        height: h,
        texture: tex,
        texSize: 7,
        points: const [ui.Offset(20, 50), ui.Offset(300, 50)],
        stampSize: 20,
        density: density,
      );
      results[density] = d;
      await _saveRgba(d, w, h, '${out.path}/stamp_density_${density.toStringAsFixed(1)}.png');
    }

    final a05 = _meanAlpha(results[0.5]!, w, 60, 260, 50);
    final a10 = _meanAlpha(results[1.0]!, w, 60, 260, 50);
    final a20 = _meanAlpha(results[2.0]!, w, 60, 260, 50);
    final a50 = _meanAlpha(results[5.0]!, w, 60, 260, 50);
    expect(a05, lessThan(a10), reason: 'density 0.5 must be visibly sparser than 1.0');
    expect(a10, lessThan(a20), reason: 'density 2.0 must actually increase stamp density');
    expect(a20, lessThan(a50), reason: 'density 5.0 must not collapse to the same behavior as >=1.0');
  });

  test('散布はrotation OFFでもストローク進行方向に対して垂直に広がる', () async {
    const w = 300, h = 300;
    final tex = _solidTexture(5, alpha: 255);
    final horizontal = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 5,
      points: const [ui.Offset(30, 150), ui.Offset(270, 150)],
      stampSize: 8, rotation: false, scatter: 35, density: 0.5, seed: 123,
    );
    final vertical = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 5,
      points: const [ui.Offset(150, 30), ui.Offset(150, 270)],
      stampSize: 8, rotation: false, scatter: 35, density: 0.5, seed: 123,
    );
    await _saveRgba(horizontal, w, h, '${out.path}/stamp_scatter_horizontal.png');
    await _saveRgba(vertical, w, h, '${out.path}/stamp_scatter_vertical.png');

    final hb = _alphaBounds(horizontal, w, h);
    final vb = _alphaBounds(vertical, w, h);
    expect(hb.height, greaterThan(30), reason: 'horizontal stroke scatter must spread vertically');
    expect(vb.width, greaterThan(30), reason: 'vertical stroke scatter must spread horizontally');
    expect(hb.width, greaterThan(hb.height));
    expect(vb.height, greaterThan(vb.width));
  });

  test('回転ONでは非対称テクスチャが進行方向へ追従し、OFFでは元向きを保つ', () async {
    const w = 180, h = 220;
    final tex = _horizontalBarTexture(17);
    final off = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 17,
      points: const [ui.Offset(90, 45), ui.Offset(90, 175)],
      stampSize: 26, rotation: false, density: 0.5,
    );
    final on = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 17,
      points: const [ui.Offset(90, 45), ui.Offset(90, 175)],
      stampSize: 26, rotation: true, density: 0.5,
    );
    await _saveRgba(off, w, h, '${out.path}/stamp_rotation_off_vertical_path.png');
    await _saveRgba(on, w, h, '${out.path}/stamp_rotation_on_vertical_path.png');

    // 先頭スタンプ周辺だけを測る。OFFは横長、ONは縦長になること。
    final offLocal = _alphaBoundsIn(off, w, h, 55, 15, 125, 80);
    final onLocal = _alphaBoundsIn(on, w, h, 55, 15, 125, 80);
    expect(offLocal.width, greaterThan(offLocal.height * 1.8));
    expect(onLocal.height, greaterThan(onLocal.width * 1.8));
  });

  test('疎入力2点と密入力51点で同一直線のスタンプ列がほぼ一致する', () async {
    const w = 320, h = 110;
    final tex = _solidTexture(5, alpha: 90);
    final sparse = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 5,
      points: const [ui.Offset(20, 55), ui.Offset(300, 55)],
      stampSize: 18, density: 1.7,
    );
    final densePoints = List<ui.Offset>.generate(51, (i) {
      final t = i / 50;
      return ui.Offset(20 + 280 * t, 55);
    });
    final dense = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 5,
      points: densePoints,
      stampSize: 18, density: 1.7,
    );
    await _saveRgba(sparse, w, h, '${out.path}/stamp_sparse_input.png');
    await _saveRgba(dense, w, h, '${out.path}/stamp_dense_input.png');

    var differentPixels = 0;
    for (var i = 0; i < sparse.length; i += 4) {
      if ((sparse[i] - dense[i]).abs() > 2 ||
          (sparse[i + 1] - dense[i + 1]).abs() > 2 ||
          (sparse[i + 2] - dense[i + 2]).abs() > 2 ||
          (sparse[i + 3] - dense[i + 3]).abs() > 2) {
        differentPixels++;
      }
    }
    expect(differentPixels, lessThanOrEqualTo(24),
        reason: 'same geometric path must not depend materially on pointer event count');
  });

  test('スタンプ設定はrotation/density/scatterをJSON往復して保持する', () {
    const original = Stamp(
      id: 'audit14', name: 'audit stamp', imagePath: '/tmp/a.png',
      rotation: true, density: 3.4, scatter: 0.7, pixelMode: true,
    );
    final restored = Stamp.fromJson(original.toJson());
    expect(restored.rotation, isTrue);
    expect(restored.density, closeTo(3.4, 1e-9));
    expect(restored.scatter, closeTo(0.7, 1e-9));
    expect(restored.pixelMode, isTrue);
  });
}

Uint8List _solidTexture(int size, {required int alpha}) {
  final d = Uint8List(size * size * 4);
  for (var i = 0; i < size * size; i++) {
    d[i * 4] = 220;
    d[i * 4 + 1] = 50;
    d[i * 4 + 2] = 30;
    d[i * 4 + 3] = alpha;
  }
  return d;
}

Uint8List _horizontalBarTexture(int size) {
  final d = Uint8List(size * size * 4);
  final cy = size ~/ 2;
  for (var y = cy - 1; y <= cy + 1; y++) {
    for (var x = 1; x < size - 1; x++) {
      final i = (y * size + x) * 4;
      d[i] = 240; d[i + 1] = 60; d[i + 2] = 30; d[i + 3] = 255;
    }
  }
  // 片端だけ青いマーカーを置いて180度方向も判別できる非対称形状にする。
  for (var y = cy - 3; y <= cy + 3; y++) {
    final x = size - 3;
    final i = (y * size + x) * 4;
    d[i] = 30; d[i + 1] = 80; d[i + 2] = 240; d[i + 3] = 255;
  }
  return d;
}

double _meanAlpha(Uint8List d, int width, int x0, int x1, int y) {
  var sum = 0;
  var n = 0;
  for (var x = x0; x <= x1; x++) {
    sum += d[(y * width + x) * 4 + 3];
    n++;
  }
  return sum / n;
}

math.Rectangle<int> _alphaBounds(Uint8List d, int w, int h) =>
    _alphaBoundsIn(d, w, h, 0, 0, w, h);

math.Rectangle<int> _alphaBoundsIn(
    Uint8List d, int w, int h, int x0, int y0, int x1, int y1) {
  var minX = x1, minY = y1, maxX = x0 - 1, maxY = y0 - 1;
  for (var y = y0.clamp(0, h - 1); y < y1.clamp(0, h); y++) {
    for (var x = x0.clamp(0, w - 1); x < x1.clamp(0, w); x++) {
      if (d[(y * w + x) * 4 + 3] == 0) continue;
      minX = math.min(minX, x); minY = math.min(minY, y);
      maxX = math.max(maxX, x); maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) return const math.Rectangle<int>(0, 0, 0, 0);
  return math.Rectangle<int>(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

Future<void> _saveRgba(Uint8List rgba, int w, int h, String path) async {
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
