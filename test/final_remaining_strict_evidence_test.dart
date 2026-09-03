import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/mesh_warp_engine.dart';
import 'package:niarim/engine/ruler_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/ruler.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/final-remaining-strict');
  late Directory tempDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() => out.createSync(recursive: true));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('niarim_final_remaining_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('筆圧サイズ: strength 0/50/100 が同一pressure=0.25の実線幅へ段階追従', () async {
    final spans = <int, int>{};
    for (final strength in [0, 50, 100]) {
      final tm = TileManager(canvasWidth: 80, canvasHeight: 80);
      final e = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(
          size: 32,
          pressureMode: PressureMode.size,
          pressureStrength: strength,
        )
        ..currentColor = const ui.Color(0xFF202020);
      e.beginStroke(const StrokePoint(x: 40, y: 40, pressure: 0.25), 'p');
      e.endStroke();
      final image = await tm.compositeLayerToImage('p');
      await _saveImage(
        image,
        '${out.path}/pressure_size_strength_$strength.png',
      );
      final rgba = await _rgba(image);
      spans[strength] = _verticalSpan(rgba, 80, 40);
      image.dispose();
      tm.dispose();
    }
    expect(spans[0]!, greaterThan(spans[50]!));
    expect(spans[50]!, greaterThan(spans[100]!));
    expect(spans[0]!, greaterThanOrEqualTo(28));
    expect(spans[100]!, lessThanOrEqualTo(12));
  });

  test('フェード: off/weak/medium/strong/custom が同一長ストローク終端へ段階反映', () async {
    final late = <String, int>{};
    final modes = <String, FadeMode>{
      'off': FadeMode.off,
      'weak': FadeMode.weak,
      'medium': FadeMode.medium,
      'strong': FadeMode.strong,
      'custom': FadeMode.custom,
    };
    for (final entry in modes.entries) {
      final tm = TileManager(canvasWidth: 260, canvasHeight: 80);
      final e = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(
          size: 24,
          fadeMode: entry.value,
          fadeCustom: entry.value == FadeMode.custom
              ? const FadeCustomSettings(
                  startValue: 100,
                  endValue: 15,
                  distancePx: 200,
                )
              : null,
        )
        ..currentColor = const ui.Color(0xFF3040C0);
      e.beginStroke(const StrokePoint(x: 20, y: 40), 'f');
      for (var x = 24.0; x <= 230; x += 4) {
        e.continueStroke(StrokePoint(x: x, y: 40), 'f');
      }
      e.endStroke();
      final image = await tm.compositeLayerToImage('f');
      await _saveImage(image, '${out.path}/fade_${entry.key}.png');
      final rgba = await _rgba(image);
      late[entry.key] = rgba[(40 * 260 + 210) * 4 + 3];
      image.dispose();
      tm.dispose();
    }
    expect(late['off']!, greaterThan(late['weak']!));
    expect(late['weak']!, greaterThanOrEqualTo(late['medium']!));
    expect(late['medium']!, greaterThanOrEqualTo(late['strong']!));
    expect(late['custom']!, lessThan(late['off']!));
  });

  test('直線/円/楕円/放射定規: ノイズ入力が各定規の幾何へ拘束される証拠PNG', () async {
    await _rulerLine(out);
    await _rulerCircle(out, ellipse: false);
    await _rulerCircle(out, ellipse: true);
    await _rulerRadial(out);
  });

  test('ぼかし: strength 1/4/10 で高周波エネルギーが単調減少', () async {
    const w = 96, h = 96;
    final input = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final v = ((x ~/ 4 + y ~/ 4).isEven) ? 0 : 255;
        input[i] = input[i + 1] = input[i + 2] = v;
        input[i + 3] = 255;
      }
    }
    final energies = <int, double>{};
    for (final strength in [1, 4, 10]) {
      final effect = EffectFilterInstance(
        id: 'b$strength',
        type: EffectFilterType.blur,
        startFrame: 0,
        endFrame: 0,
        param1: strength.toDouble(),
      );
      final got = FilterEngine().applyEffectFilters(
        Uint8List.fromList(input),
        w,
        h,
        [effect],
        0,
      );
      energies[strength] = _edgeEnergy(got, w, h);
      await _saveRgba(got, w, h, '${out.path}/blur_strength_$strength.png');
    }
    expect(energies[1]!, greaterThan(energies[4]!));
    expect(energies[4]!, greaterThan(energies[10]!));
  });

  test('メッシュ変形: 制御点移動量0/6/12で元画像との差分量が段階増加', () async {
    const w = 64, h = 64;
    final src = Uint8List(w * h * 4);
    for (var y = 12; y < 52; y++) {
      for (var x = 12; x < 52; x++) {
        final i = (y * w + x) * 4;
        src[i] = 230;
        src[i + 1] = 70;
        src[i + 2] = 40;
        src[i + 3] = 255;
      }
    }
    final base = await _image(src, w, h);
    final diffs = <int, double>{};
    for (final shift in [0, 6, 12]) {
      final grid = MeshWarpEngine.regularGrid(
        1,
        1,
        const ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      );
      final moved = List<ui.Offset>.from(grid);
      moved[1] = moved[1] + ui.Offset(-shift.toDouble(), shift.toDouble());
      final warped = await MeshWarpEngine.warp(
        image: base,
        rows: 1,
        cols: 1,
        controlPoints: moved,
        outputWidth: w,
        outputHeight: h,
      );
      final rgba = await _rgba(warped);
      diffs[shift] = _meanAbsDiff(src, rgba);
      await _saveImage(warped, '${out.path}/mesh_shift_$shift.png');
      warped.dispose();
    }
    base.dispose();
    expect(diffs[0]!, lessThan(diffs[6]!));
    expect(diffs[6]!, lessThan(diffs[12]!));
  });

  test('フレーム並べ替え: [2,0,1] 後も実タイル色が新indexへ完全追従', () async {
    final ps = ProjectService();
    await ps.init();
    final p = await ps.createProject(
      name: 'reorder-final',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0,
      exportWidth: 8,
      exportHeight: 8,
    );
    final scene = ps.scenesOf(p.id).first;
    ps.addFrame(p.id, scene.id);
    ps.addFrame(p.id, scene.id);
    final colors = [
      [240, 20, 30, 255],
      [30, 220, 50, 255],
      [40, 70, 235, 255],
    ];
    for (var fi = 0; fi < 3; fi++) {
      final layer = ps.layersOf(p.id, scene.id, fi).first;
      final key = ps.tileKeyFor(p.id, scene.id, fi, layer.id);
      final b = Uint8List(8 * 8 * 4);
      for (var i = 0; i < b.length; i += 4) {
        b[i] = colors[fi][0];
        b[i + 1] = colors[fi][1];
        b[i + 2] = colors[fi][2];
        b[i + 3] = 255;
      }
      ps.tileManagerOf(p.id).replaceLayerPixels(key, b);
    }
    ps.reorderFrames(p.id, scene.id, [2, 0, 1]);
    expect(_framePixel(ps, p.id, scene.id, 0), colors[2]);
    expect(_framePixel(ps, p.id, scene.id, 1), colors[0]);
    expect(_framePixel(ps, p.id, scene.id, 2), colors[1]);
  });

  test('プロジェクト保存/再読込: metadata/scene/frame/layer/tile RGBAをディスク往復', () async {
    final ps = ProjectService();
    await ps.init();
    final p = await ps.createProject(
      name: 'persist-final',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFABCDEF,
      exportWidth: 16,
      exportHeight: 12,
    );
    final scene = ps.scenesOf(p.id).first;
    final layer = ps.layersOf(p.id, scene.id, 0).first;
    final key = ps.tileKeyFor(p.id, scene.id, 0, layer.id);
    final b = Uint8List(16 * 12 * 4);
    b[0] = 17;
    b[1] = 91;
    b[2] = 203;
    b[3] = 177;
    ps.tileManagerOf(p.id).replaceLayerPixels(key, b);
    await ps.saveProject(p.id);

    final restored = ProjectService();
    await restored.init();
    final rp = restored.projects.singleWhere((x) => x.id == p.id);
    expect(rp.name, 'persist-final');
    expect(rp.fps, 12);
    expect(rp.backgroundColor, 0xFFABCDEF);
    expect(restored.scenesOf(p.id).length, 1);
    expect(restored.frameCount(p.id, scene.id), 12);
    final rl = restored.layersOf(p.id, scene.id, 0).first;
    final rk = restored.tileKeyFor(p.id, scene.id, 0, rl.id);
    final tile = restored.tileManagerOf(p.id).getTile(rk, 0, 0)!;
    expect(tile.sublist(0, 4), [17, 91, 203, 177]);
  });
}

Brush _brush({
  double size = 12,
  PressureMode pressureMode = PressureMode.off,
  int pressureStrength = 100,
  FadeMode fadeMode = FadeMode.off,
  FadeCustomSettings? fadeCustom,
}) => Brush(
  id: 'final',
  name: 'final',
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
  strokeDecay: false,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
);

Future<void> _rulerLine(Directory out) async {
  final tm = TileManager(canvasWidth: 256, canvasHeight: 256);
  final re = RulerEngine()
    ..setActiveRuler(
      const Ruler(
        type: RulerType.line,
        position: ui.Offset(20, 128),
        rotation: 0,
        settings: RulerSettings(),
      ),
    );
  final d = DrawingEngine(tileManager: tm)
    ..currentBrush = _brush(size: 4)
    ..currentColor = const ui.Color(0xFF202020)
    ..pointConstraint = re.snapToRuler;
  re.beginStroke();
  d.beginStroke(const StrokePoint(x: 24, y: 90), 'r');
  for (var x = 30.0; x <= 230; x += 10) {
    d.continueStroke(StrokePoint(x: x, y: 128 + math.sin(x) * 35), 'r');
  }
  d.endStroke();
  final im = await tm.compositeLayerToImage('r');
  final rgba = await _rgba(im);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      if (rgba[(y * 256 + x) * 4 + 3] > 0) {
        expect((y - 128).abs(), lessThanOrEqualTo(4));
      }
    }
  }
  await _saveImage(im, '${out.path}/ruler_line_constrained.png');
  im.dispose();
  tm.dispose();
}

Future<void> _rulerCircle(Directory out, {required bool ellipse}) async {
  final tm = TileManager(canvasWidth: 256, canvasHeight: 256);
  final rx = ellipse ? 82.0 : 70.0, ry = ellipse ? 42.0 : 70.0;
  final re = RulerEngine()
    ..setActiveRuler(
      Ruler(
        type: ellipse ? RulerType.ellipse : RulerType.circle,
        position: const ui.Offset(128, 128),
        settings: RulerSettings(radiusX: rx, radiusY: ry),
      ),
    );
  final d = DrawingEngine(tileManager: tm)
    ..currentBrush = _brush(size: 3)
    ..currentColor = const ui.Color(0xFF2040C0)
    ..pointConstraint = re.snapToRuler;
  re.beginStroke();
  for (var i = 0; i <= 72; i++) {
    final a = 2 * math.pi * i / 72;
    final jitter = (i % 2 == 0 ? 18.0 : -14.0);
    final p = ui.Offset(
      128 + (rx + jitter) * math.cos(a),
      128 + (ry + jitter) * math.sin(a),
    );
    if (i == 0) {
      d.beginStroke(StrokePoint(x: p.dx, y: p.dy), 'r');
    } else {
      d.continueStroke(StrokePoint(x: p.dx, y: p.dy), 'r');
    }
  }
  d.endStroke();
  final im = await tm.compositeLayerToImage('r');
  await _saveImage(
    im,
    '${out.path}/ruler_${ellipse ? 'ellipse' : 'circle'}_constrained.png',
  );
  final rgba = await _rgba(im);
  expect(_opaqueCount(rgba), greaterThan(500));
  im.dispose();
  tm.dispose();
}

Future<void> _rulerRadial(Directory out) async {
  final tm = TileManager(canvasWidth: 256, canvasHeight: 256);
  final re = RulerEngine()
    ..setActiveRuler(
      const Ruler(
        type: RulerType.radial,
        position: ui.Offset(128, 128),
        settings: RulerSettings(divisions: 8),
      ),
    );
  final d = DrawingEngine(tileManager: tm)
    ..currentBrush = _brush(size: 3)
    ..currentColor = const ui.Color(0xFFD04030)
    ..pointConstraint = re.snapToRuler;
  for (final a in [0.1, 0.9, 1.7, 2.5, 3.3, 4.1, 4.9, 5.7]) {
    re.beginStroke();
    final s = ui.Offset(128 + 25 * math.cos(a), 128 + 25 * math.sin(a));
    d.beginStroke(StrokePoint(x: s.dx, y: s.dy), 'r');
    for (var rr = 35.0; rr <= 105; rr += 10) {
      final p = ui.Offset(
        128 + rr * math.cos(a + 0.12 * math.sin(rr)),
        128 + rr * math.sin(a + 0.12 * math.sin(rr)),
      );
      d.continueStroke(StrokePoint(x: p.dx, y: p.dy), 'r');
    }
    d.endStroke();
  }
  final im = await tm.compositeLayerToImage('r');
  await _saveImage(im, '${out.path}/ruler_radial_constrained.png');
  final rgba = await _rgba(im);
  expect(_opaqueCount(rgba), greaterThan(600));
  im.dispose();
  tm.dispose();
}

int _verticalSpan(Uint8List d, int w, int x) {
  var minY = 999, maxY = -1;
  for (var y = 0; y < 80; y++) {
    if (d[(y * w + x) * 4 + 3] > 5) {
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
  }
  return maxY < 0 ? 0 : maxY - minY + 1;
}

double _edgeEnergy(Uint8List d, int w, int h) {
  double s = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w - 1; x++) {
      final i = (y * w + x) * 4, j = i + 4;
      s +=
          (d[i] - d[j]).abs() +
          (d[i + 1] - d[j + 1]).abs() +
          (d[i + 2] - d[j + 2]).abs();
    }
  }
  return s;
}

double _meanAbsDiff(Uint8List a, Uint8List b) {
  double s = 0;
  for (var i = 0; i < a.length; i++) {
    s += (a[i] - b[i]).abs();
  }
  return s / a.length;
}

int _opaqueCount(Uint8List d) {
  var n = 0;
  for (var i = 3; i < d.length; i += 4) {
    if (d[i] > 0) n++;
  }
  return n;
}

List<int> _framePixel(ProjectService ps, String pid, String sid, int fi) {
  final l = ps.layersOf(pid, sid, fi).first;
  final k = ps.tileKeyFor(pid, sid, fi, l.id);
  final t = ps.tileManagerOf(pid).getTile(k, 0, 0)!;
  return t.sublist(0, 4);
}

Future<ui.Image> _image(Uint8List rgba, int w, int h) async {
  final b = await ui.ImmutableBuffer.fromUint8List(rgba);
  final d = ui.ImageDescriptor.raw(
    b,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final c = await d.instantiateCodec();
  final f = await c.getNextFrame();
  c.dispose();
  d.dispose();
  b.dispose();
  return f.image;
}

Future<Uint8List> _rgba(ui.Image i) async => (await i.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();
Future<void> _saveImage(ui.Image i, String p) async {
  final d = await i.toByteData(format: ui.ImageByteFormat.png);
  await File(p).writeAsBytes(d!.buffer.asUint8List());
}

Future<void> _saveRgba(Uint8List d, int w, int h, String p) async {
  final i = await _image(d, w, h);
  await _saveImage(i, p);
  i.dispose();
}
