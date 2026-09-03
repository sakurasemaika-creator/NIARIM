import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/bucket_fill_engine.dart';
import 'package:niarim/engine/lasso_fill_engine.dart';

const int w = 96;
const int h = 96;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('バケツ：境界を越えず接続領域だけ塗る', () async {
    final data = _partitionedCanvas();
    final result = BucketFillEngine().fill(
      canvasData: data,
      width: w,
      height: h,
      startX: 20,
      startY: 48,
      fillColor: const ui.Color(0xFFEF4060),
      tolerance: 5,
    );
    await _saveRgba(result, '${out.path}/bucket_basic.png');
    expect(_pixel(result, 20, 48), equals([239, 64, 96, 255]));
    expect(_pixel(result, 70, 48).sublist(0, 3), equals([180, 190, 200]));
    expect(_pixel(result, 48, 48).sublist(0, 3), equals([20, 20, 20]));
  });

  test('バケツ：許容誤差が色差へ正しく効く', () {
    final data = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final v = 100 + x ~/ 8;
        data[i] = data[i + 1] = data[i + 2] = v;
        data[i + 3] = 255;
      }
    }
    final strict = BucketFillEngine().fill(
      canvasData: data,
      width: w,
      height: h,
      startX: 1,
      startY: 48,
      fillColor: const ui.Color(0xFF20A0F0),
      tolerance: 1,
    );
    final loose = BucketFillEngine().fill(
      canvasData: data,
      width: w,
      height: h,
      startX: 1,
      startY: 48,
      fillColor: const ui.Color(0xFF20A0F0),
      tolerance: 20,
    );
    expect(
      _countColor(loose, [32, 160, 240]),
      greaterThan(_countColor(strict, [32, 160, 240])),
    );
  });

  test('バケツ：選択マスク外へ漏れない', () async {
    final data = Uint8List(w * h * 4);
    final mask = Uint8List(w * h);
    for (var y = 24; y < 72; y++) {
      for (var x = 24; x < 48; x++) {
        mask[y * w + x] = 1;
      }
    }
    final result = BucketFillEngine().fill(
      canvasData: data,
      width: w,
      height: h,
      startX: 30,
      startY: 48,
      fillColor: const ui.Color(0xFF60C050),
      selectionMask: mask,
    );
    await _saveRgba(result, '${out.path}/bucket_selection_mask.png');
    expect(_pixel(result, 30, 48)[3], 255);
    expect(_pixel(result, 55, 48)[3], 0);
  });

  test('バケツ：拡張pxで境界方向へ指定量広がる', () async {
    final data = _partitionedCanvas();
    final noExpand = BucketFillEngine().fill(
      canvasData: data,
      width: w,
      height: h,
      startX: 20,
      startY: 48,
      fillColor: const ui.Color(0xFFEF4060),
      tolerance: 5,
    );
    final expanded = BucketFillEngine().fill(
      canvasData: data,
      width: w,
      height: h,
      startX: 20,
      startY: 48,
      fillColor: const ui.Color(0xFFEF4060),
      tolerance: 5,
      expandPx: 2,
    );
    await _saveRgba(expanded, '${out.path}/bucket_expand2.png');
    expect(
      _countColor(expanded, [239, 64, 96]),
      greaterThan(_countColor(noExpand, [239, 64, 96])),
    );
  });

  test('バケツ：線の下まで潜るは不透明線を見た目上保持', () async {
    final data = _partitionedCanvas();
    final over = BucketFillEngine().fill(
      canvasData: data,
      width: w,
      height: h,
      startX: 20,
      startY: 48,
      fillColor: const ui.Color(0xFFFF0000),
      tolerance: 5,
      expandPx: 2,
      fillUnderLine: false,
    );
    final under = BucketFillEngine().fill(
      canvasData: data,
      width: w,
      height: h,
      startX: 20,
      startY: 48,
      fillColor: const ui.Color(0xFFFF0000),
      tolerance: 5,
      expandPx: 2,
      fillUnderLine: true,
    );
    await _saveRgba(under, '${out.path}/bucket_fill_under_line.png');
    expect(
      _pixel(over, 48, 48)[0],
      255,
      reason: 'normal expand overwrites boundary',
    );
    expect(
      _pixel(under, 48, 48).sublist(0, 3),
      equals([20, 20, 20]),
      reason: 'under-line keeps opaque line',
    );
  });

  test('トーンバケツ：透明セルがあっても領域走査を継続し周期維持', () async {
    final data = Uint8List(w * h * 4);
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
    final result = BucketFillEngine().fillWithTone(
      canvasData: data,
      width: w,
      height: h,
      startX: 48,
      startY: 48,
      toneColor: const ui.Color(0xFF7040D0),
      toneTexture: tone,
      toneWidth: 2,
      toneHeight: 2,
    );
    await _saveRgba(result, '${out.path}/bucket_tone.png');
    expect(_pixel(result, 48, 48)[3], 255);
    expect(_pixel(result, 49, 48)[3], 0);
    expect(
      _pixel(result, 90, 90)[3],
      255,
      reason: 'transparent tone cells must not stop flood propagation',
    );
  });

  test('マジックワンド：接続色領域だけ選択し元画像は不変', () async {
    final data = _partitionedCanvas();
    final before = Uint8List.fromList(data);
    final mask = BucketFillEngine().selectionMask(
      canvasData: data,
      width: w,
      height: h,
      startX: 20,
      startY: 48,
      tolerance: 5,
    );
    expect(data, equals(before));
    expect(mask[48 * w + 20], 1);
    expect(mask[48 * w + 70], 0);
    final rgba = Uint8List(w * h * 4);
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == 0) continue;
      rgba[i * 4] = 40;
      rgba[i * 4 + 1] = 130;
      rgba[i * 4 + 2] = 255;
      rgba[i * 4 + 3] = 180;
    }
    await _saveRgba(rgba, '${out.path}/magic_wand_selection.png');
  });

  test('投げ縄塗り：多角形内部だけ塗る', () async {
    final points = <ui.Offset>[
      const ui.Offset(18, 22),
      const ui.Offset(78, 28),
      const ui.Offset(70, 76),
      const ui.Offset(28, 70),
    ];
    final result = LassoFillEngine().fillLasso(
      points: points,
      color: const ui.Color(0xFF30A0E0),
      canvasData: Uint8List(w * h * 4),
      width: w,
      height: h,
    );
    await _saveRgba(result, '${out.path}/lasso_fill.png');
    expect(_pixel(result, 48, 48)[3], 255);
    expect(_pixel(result, 5, 5)[3], 0);
  });

  test('投げ縄トーン：多角形内でトーン周期を維持', () async {
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
    final result = LassoFillEngine().fillLasso(
      points: const [
        ui.Offset(20, 20),
        ui.Offset(76, 20),
        ui.Offset(76, 76),
        ui.Offset(20, 76),
      ],
      color: const ui.Color(0xFFE05090),
      canvasData: Uint8List(w * h * 4),
      width: w,
      height: h,
      toneTexture: tone,
      toneTextureWidth: 2,
      toneTextureHeight: 2,
    );
    await _saveRgba(result, '${out.path}/lasso_tone.png');
    expect(_pixel(result, 48, 48)[3], 255);
    expect(_pixel(result, 49, 48)[3], 0);
  });

  test('投げ縄消しゴム：指定領域だけ透明化', () async {
    final data = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      data[i * 4] = 30;
      data[i * 4 + 1] = 130;
      data[i * 4 + 2] = 220;
      data[i * 4 + 3] = 255;
    }
    final result = LassoFillEngine().fillLasso(
      points: const [
        ui.Offset(28, 28),
        ui.Offset(68, 28),
        ui.Offset(68, 68),
        ui.Offset(28, 68),
      ],
      color: const ui.Color(0x00000000),
      canvasData: data,
      width: w,
      height: h,
    );
    await _saveRgba(result, '${out.path}/lasso_eraser.png');
    expect(_pixel(result, 48, 48)[3], 0);
    expect(_pixel(result, 10, 10)[3], 255);
  });

  test('囲って塗る：投げ縄内にある閉じた透明領域を一括塗り', () async {
    final data = Uint8List(w * h * 4);
    _drawRectBoundary(data, 18, 18, 42, 42);
    _drawRectBoundary(data, 54, 54, 80, 80);
    final result = LassoFillEngine().fillEnclosed(
      points: const [
        ui.Offset(10, 10),
        ui.Offset(48, 10),
        ui.Offset(48, 48),
        ui.Offset(10, 48),
      ],
      color: const ui.Color(0xFF70C040),
      canvasData: data,
      width: w,
      height: h,
    );
    await _saveRgba(result, '${out.path}/lasso_enclosed.png');
    expect(_pixel(result, 30, 30).sublist(0, 3), equals([112, 192, 64]));
    expect(
      _pixel(result, 66, 66)[3],
      0,
      reason: 'closed region outside lasso must remain unfilled',
    );
  });
}

Uint8List _partitionedCanvas() {
  final data = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      if (x < 48) {
        data[i] = 100;
        data[i + 1] = 110;
        data[i + 2] = 120;
      } else if (x == 48) {
        data[i] = 20;
        data[i + 1] = 20;
        data[i + 2] = 20;
      } else {
        data[i] = 180;
        data[i + 1] = 190;
        data[i + 2] = 200;
      }
      data[i + 3] = 255;
    }
  }
  return data;
}

void _drawRectBoundary(Uint8List data, int l, int t, int r, int b) {
  void p(int x, int y) {
    final i = (y * w + x) * 4;
    data[i] = data[i + 1] = data[i + 2] = 10;
    data[i + 3] = 255;
  }

  for (var x = l; x <= r; x++) {
    p(x, t);
    p(x, b);
  }
  for (var y = t; y <= b; y++) {
    p(l, y);
    p(r, y);
  }
}

int _countColor(List<int> rgba, List<int> rgb) {
  var n = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i] == rgb[0] && rgba[i + 1] == rgb[1] && rgba[i + 2] == rgb[2]) {
      n++;
    }
  }
  return n;
}

List<int> _pixel(List<int> rgba, int x, int y) {
  final i = (y * w + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
}

Future<void> _saveRgba(Uint8List rgba, String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
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
