import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brightness_alpha_engine.dart';
import 'package:niarim/engine/mesh_warp_engine.dart';
import 'package:niarim/engine/ruler_engine.dart';
import 'package:niarim/engine/stamp_engine.dart';
import 'package:niarim/models/ruler.dart';

const int w = 96;
const int h = 96;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('明度で透過：グレーモードはRGBを保持し白ほど透明', () async {
    final src = Uint8List.fromList([
      0,
      0,
      0,
      255,
      128,
      128,
      128,
      255,
      255,
      255,
      255,
      255,
      200,
      100,
      50,
      200,
    ]);
    final got = applyBrightnessToAlpha(src, grayMode: true);
    expect(got.sublist(0, 3), equals([0, 0, 0]));
    expect(got[3], 255);
    expect(got.sublist(4, 7), equals([128, 128, 128]));
    expect(got[7], inInclusiveRange(126, 128));
    expect(got[11], 0);
    expect(got.sublist(12, 15), equals([200, 100, 50]));
    expect(got[15], lessThan(200));
  });

  test('明度で透過：カラーモードは白を透明化し残色を復元', () async {
    final src = Uint8List.fromList([
      255,
      255,
      255,
      255,
      255,
      128,
      128,
      255,
      128,
      255,
      128,
      255,
      128,
      128,
      255,
      255,
    ]);
    final got = applyBrightnessToAlpha(src, grayMode: false);
    expect(got.sublist(0, 4), equals([255, 255, 255, 0]));
    expect(got[7], inInclusiveRange(126, 128));
    expect(got[4], 255);
    expect(got[5], inInclusiveRange(0, 2));
    expect(got[6], inInclusiveRange(0, 2));
    expect(got[11], inInclusiveRange(126, 128));
    expect(got[15], inInclusiveRange(126, 128));
  });

  test('メッシュ変形：規則格子が指定boundsを均等分割', () {
    final grid = MeshWarpEngine.regularGrid(
      2,
      3,
      const ui.Rect.fromLTWH(10, 20, 60, 40),
    );
    expect(grid.length, 12);
    expect(grid.first, const ui.Offset(10, 20));
    expect(grid[3], const ui.Offset(70, 20));
    expect(grid[4], const ui.Offset(10, 40));
    expect(grid.last, const ui.Offset(70, 60));
  });

  test('メッシュ変形：恒等格子では元画像をほぼ維持', () async {
    final input = _patternImageData(48, 48);
    final image = await _image(input, 48, 48);
    final grid = MeshWarpEngine.regularGrid(
      2,
      2,
      const ui.Rect.fromLTWH(0, 0, 48, 48),
    );
    final warped = await MeshWarpEngine.warp(
      image: image,
      rows: 2,
      cols: 2,
      controlPoints: grid,
      outputWidth: 48,
      outputHeight: 48,
    );
    await _save(warped, '${out.path}/mesh_warp_identity.png');
    final a = await _rgba(image);
    final b = await _rgba(warped);
    for (final p in const [
      ui.Offset(8, 8),
      ui.Offset(24, 24),
      ui.Offset(39, 31),
    ]) {
      final pa = _pixel(a, 48, p.dx.toInt(), p.dy.toInt());
      final pb = _pixel(b, 48, p.dx.toInt(), p.dy.toInt());
      for (var c = 0; c < 4; c++) {
        expect(
          (pa[c] - pb[c]).abs(),
          lessThanOrEqualTo(8),
          reason: 'identity warp ${p.dx},${p.dy} c=$c',
        );
      }
    }
    image.dispose();
    warped.dispose();
  });

  test('メッシュ変形：制御点移動で図形が実際に歪む', () async {
    final input = Uint8List(48 * 48 * 4);
    for (var y = 8; y < 40; y++) {
      for (var x = 8; x < 40; x++) {
        final i = (y * 48 + x) * 4;
        input[i] = 230;
        input[i + 1] = 70;
        input[i + 2] = 40;
        input[i + 3] = 255;
      }
    }
    final image = await _image(input, 48, 48);
    final grid = MeshWarpEngine.regularGrid(
      1,
      1,
      const ui.Rect.fromLTWH(0, 0, 48, 48),
    );
    final moved = List<ui.Offset>.from(grid);
    moved[1] = const ui.Offset(36, 8);
    moved[3] = const ui.Offset(46, 46);
    final warped = await MeshWarpEngine.warp(
      image: image,
      rows: 1,
      cols: 1,
      controlPoints: moved,
      outputWidth: 48,
      outputHeight: 48,
    );
    await _save(warped, '${out.path}/mesh_warp_freeform.png');
    final before = await _rgba(image);
    final after = await _rgba(warped);
    expect(_opaqueCount(after), isNot(equals(_opaqueCount(before))));
    image.dispose();
    warped.dispose();
  });

  test('定規：直線・円・楕円・放射のスナップ幾何が正しい', () {
    final e = RulerEngine();

    e.setActiveRuler(
      const Ruler(
        type: RulerType.line,
        position: ui.Offset(10, 10),
        rotation: 0,
        settings: RulerSettings(),
      ),
    );
    expect(e.snapToRuler(const ui.Offset(30, 25)).dy, closeTo(10, 1e-9));

    e.setActiveRuler(
      const Ruler(
        type: RulerType.circle,
        position: ui.Offset(50, 50),
        settings: RulerSettings(radiusX: 20),
      ),
    );
    final c = e.snapToRuler(const ui.Offset(80, 50));
    expect(c.dx, closeTo(70, 1e-9));
    expect(c.dy, closeTo(50, 1e-9));

    e.setActiveRuler(
      const Ruler(
        type: RulerType.ellipse,
        position: ui.Offset(50, 50),
        settings: RulerSettings(radiusX: 30, radiusY: 10),
      ),
    );
    final ell = e.snapToRuler(const ui.Offset(50, 90));
    expect(ell.dx, closeTo(50, 1e-6));
    expect(ell.dy, closeTo(60, 1e-6));

    e.setActiveRuler(
      const Ruler(
        type: RulerType.radial,
        position: ui.Offset(50, 50),
        settings: RulerSettings(divisions: 4),
      ),
    );
    final rad = e.snapToRuler(const ui.Offset(70, 58));
    expect(rad.dy, closeTo(50, 1e-6));
  });

  test('定規：透視定規は1ストローク中に同じ消失点直線へ固定', () {
    final e = RulerEngine();
    e.setActiveRuler(
      const Ruler(
        type: RulerType.twoPointPerspective,
        position: ui.Offset.zero,
        settings: RulerSettings(
          vanishingPoint1: ui.Offset(0, 50),
          vanishingPoint2: ui.Offset(100, 50),
        ),
      ),
    );
    e.beginStroke();
    final first = e.snapToRuler(const ui.Offset(20, 20));
    expect(first, const ui.Offset(20, 20));
    final second = e.snapToRuler(const ui.Offset(60, 35));
    final vp = const ui.Offset(0, 50);
    final a = first - vp;
    final b = second - vp;
    final cross = a.dx * b.dy - a.dy * b.dx;
    expect(cross.abs(), lessThan(1e-6));
  });

  test('スタンプ：透明背景へRGBAを正しくsrc-over合成', () async {
    final tex = Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      255,
      0,
      128,
      0,
      0,
      255,
      255,
      255,
      255,
      255,
      0,
    ]);
    final canvas = Uint8List(w * h * 4);
    final result = StampEngine().stampAlongPath(
      canvasData: canvas,
      width: w,
      height: h,
      texture: tex,
      texSize: 2,
      points: const [ui.Offset(48, 48)],
      stampSize: 20,
    );
    final image = await _image(result, w, h);
    await _save(image, '${out.path}/stamp_basic.png');
    image.dispose();
    expect(_pixel(result, w, 43, 43)[3], greaterThan(0));
    expect(_pixel(result, w, 70, 70)[3], 0);
  });

  test('スタンプ：densityとscatterはseed固定で決定的', () {
    final tex = Uint8List(4 * 4 * 4);
    for (var i = 0; i < tex.length; i += 4) {
      tex[i] = 200;
      tex[i + 1] = 80;
      tex[i + 2] = 40;
      tex[i + 3] = 255;
    }
    final points = [for (var x = 10.0; x <= 86; x += 4) ui.Offset(x, 48)];
    final a = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4),
      width: w,
      height: h,
      texture: tex,
      texSize: 4,
      points: points,
      stampSize: 8,
      scatter: 10,
      density: 0.55,
      seed: 42,
    );
    final b = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4),
      width: w,
      height: h,
      texture: tex,
      texSize: 4,
      points: points,
      stampSize: 8,
      scatter: 10,
      density: 0.55,
      seed: 42,
    );
    expect(b, equals(a));
  });
}

Uint8List _patternImageData(int width, int height) {
  final d = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      d[i] = (x * 255 ~/ (width - 1));
      d[i + 1] = (y * 255 ~/ (height - 1));
      d[i + 2] = ((x + y) % 16) * 16;
      d[i + 3] = 255;
    }
  }
  return d;
}

Future<ui.Image> _image(Uint8List rgba, int width, int height) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}

Future<List<int>> _rgba(ui.Image image) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  return data!.buffer.asUint8List();
}

List<int> _pixel(List<int> rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
}

int _opaqueCount(List<int> rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > 0) n++;
  }
  return n;
}

Future<void> _save(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}
