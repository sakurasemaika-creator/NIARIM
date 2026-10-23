import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/ruler_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/ruler.dart';

import 'helpers/color_channels.dart';

const _w = 256;
const _h = 256;
const _layer = 'paint';
const _blue = ui.Color(0xFF1646E6);
const _red = ui.Color(0xFFE63220);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/strict-visual-evidence');
  setUpAll(() => out.createSync(recursive: true));

  test('手ブレ補正0/25/50/75/100: 同一ジグザグ入力で強度に応じ平滑化が強くなる', () async {
    final strengths = [0, 25, 50, 75, 100];
    final roughness = <int, double>{};

    final raw = <StrokePoint>[
      for (var i = 0; i < 37; i++)
        StrokePoint(
          x: 20 + i * 6.0,
          y: 128 + (i.isEven ? 30 : -30),
          pressure: 1,
        ),
    ];

    for (final strength in strengths) {
      final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
      final engine = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(
          size: 4,
          stabilization: true,
          stabilizationStrength: strength,
        )
        ..currentColor = const ui.Color(0xFF202020);
      engine.beginStroke(raw.first, _layer);
      for (final p in raw.skip(1)) {
        engine.continueStroke(p, _layer);
      }
      engine.endStroke();

      final image = await tm.compositeLayerToImage(_layer);
      final rgba = await _rgba(image);
      roughness[strength] = _centerlineVariation(rgba, _w, _h);
      await _save(
        image,
        '${out.path}/stabilizer_${strength.toString().padLeft(3, '0')}.png',
      );
      image.dispose();
      tm.dispose();
    }

    for (var i = 1; i < strengths.length; i++) {
      final prev = roughness[strengths[i - 1]]!;
      final cur = roughness[strengths[i]]!;
      expect(
        cur,
        lessThanOrEqualTo(prev * 1.08),
        reason: '補正強度を上げたとき中心線の揺れ量が増えてはいけない: $roughness',
      );
    }
    expect(
      roughness[100]!,
      lessThan(roughness[0]! * 0.72),
      reason: '100%補正は0%より明確に平滑化される必要がある: $roughness',
    );
  });

  test('混色0/20/40/60/80/100: 同一背景と同一ストロークで色が設定率へ段階追従する（油彩風混色）', () async {
    final rates = [0, 20, 40, 60, 80, 100];
    final centers = <int, List<int>>{};

    for (final rate in rates) {
      final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
      _fillLayer(tm, _layer, _blue);
      final engine = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(
          size: 24,
          mixingMode: BrushMixingMode.oil,
          mixingRate: rate,
        )
        ..currentColor = _red;
      // 1回のdabで率そのものを検証する。長いストロークでは同じ画素へ
      // 複数stampが重なり、各stampが直前結果を再び混色するため、単純な1回分の
      // 線形補間値との比較にはならない。機能の率追従を見るfixtureとして単発dabを使う。
      engine.beginStroke(const StrokePoint(x: 128, y: 128), _layer);
      engine.endStroke();

      final image = await tm.compositeLayerToImage(_layer);
      final rgba = await _rgba(image);
      final p = _pixel(rgba, _w, 128, 128);
      centers[rate] = p;
      // 油彩風混色は絵の具のように混ざる（赤と青の間は紫を通る）ので、
      // RGBの直線補間とは一致しない。端点は元の色のまま、途中は紫。
      if (rate == 0) {
        _near(
          p,
          [_red.red8, _red.green8, _red.blue8],
          'mix rate=0',
          tolerance: 1,
        );
      } else if (rate == 100) {
        _near(
          p,
          [_blue.red8, _blue.green8, _blue.blue8],
          'mix rate=100',
          tolerance: 1,
        );
      } else {
        expect(p[1], lessThan(p[0]), reason: '紫：緑は赤より弱い rate=$rate');
        expect(p[1], lessThan(p[2]), reason: '紫：緑は青より弱い rate=$rate');
      }
      await _save(
        image,
        '${out.path}/mix_${rate.toString().padLeft(3, '0')}.png',
      );
      image.dispose();
      tm.dispose();
    }

    for (var i = 1; i < rates.length; i++) {
      final a = centers[rates[i - 1]]!;
      final b = centers[rates[i]]!;
      expect(b[0], lessThan(a[0]), reason: '混色率↑で選択色(red)寄り成分は単調減少する');
      expect(b[2], greaterThan(a[2]), reason: '混色率↑で背景色(blue)寄り成分は単調増加する');
    }
  });

  test('色延び20/60/100: 青い絵の具を出た後も、色延びが長いほど拾った青を遠くまで運ぶ', () async {
    final stretches = [20, 60, 100];
    final near = <int, List<int>>{};
    final far = <int, List<int>>{};

    for (final stretch in stretches) {
      final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
      // 左側だけ青い絵の具、右側は何もない紙。
      final rgba = Uint8List(_w * _h * 4);
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < 80; x++) {
          final i = (y * _w + x) * 4;
          rgba[i] = _blue.red8;
          rgba[i + 1] = _blue.green8;
          rgba[i + 2] = _blue.blue8;
          rgba[i + 3] = 255;
        }
      }
      tm.replaceLayerPixels(_layer, rgba);
      final engine = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(
          size: 20,
          mixingMode: BrushMixingMode.oil,
          mixingRate: 80,
          mixingStretch: stretch,
        )
        ..currentColor = _red;

      final points = <StrokePoint>[
        for (var x = 28; x <= 228; x += 10)
          StrokePoint(x: x.toDouble(), y: 128, pressure: 1),
      ];
      engine.beginStroke(points.first, _layer);
      for (final p in points.skip(1)) {
        engine.continueStroke(p, _layer);
      }
      engine.endStroke();

      final image = await tm.compositeLayerToImage(_layer);
      final rgba2 = await _rgba(image);
      near[stretch] = _pixel(rgba2, _w, 104, 128);
      far[stretch] = _pixel(rgba2, _w, 220, 128);
      await _save(
        image,
        '${out.path}/color_stretch_${stretch.toString().padLeft(3, '0')}.png',
      );
      image.dispose();
      tm.dispose();
    }

    // 青を出た直後：色延びが長いほど青が多い。
    expect(near[100]![2], greaterThan(near[60]![2]));
    expect(near[60]![2], greaterThan(near[20]![2]));
    expect(near[100]![0], lessThan(near[20]![0]));
    for (final stretch in stretches) {
      // 遠くでは新しい絵の具が戻り、赤へ近づく。
      expect(
        far[stretch]![0],
        greaterThanOrEqualTo(near[stretch]![0] - 3),
        reason: '色延びの先では選択色へ戻ること stretch=$stretch',
      );
      expect(
        far[stretch]![2],
        lessThanOrEqualTo(near[stretch]![2] + 3),
        reason: '色延びの先では拾った青が薄れること stretch=$stretch',
      );
    }
  });

  test('1/2/3点透視: 複数線群が設定した各消失点へ収束する証拠PNGを生成し幾何誤差も検査', () async {
    await _perspectiveCase(
      out: out,
      name: 'perspective1',
      ruler: const Ruler(
        type: RulerType.onePointPerspective,
        position: ui.Offset(128, 48),
        settings: RulerSettings(vanishingPoint1: ui.Offset(128, 48)),
      ),
      rays: [
        for (final x in [45.0, 78.0, 108.0, 148.0, 178.0, 211.0])
          (anchor: ui.Offset(x, 222), vp: const ui.Offset(128, 48)),
      ],
      vanishingPoints: const [ui.Offset(128, 48)],
    );

    await _perspectiveCase(
      out: out,
      name: 'perspective2',
      ruler: const Ruler(
        type: RulerType.twoPointPerspective,
        position: ui.Offset(128, 128),
        settings: RulerSettings(
          vanishingPoint1: ui.Offset(22, 82),
          vanishingPoint2: ui.Offset(234, 82),
        ),
      ),
      rays: const [
        (anchor: ui.Offset(72, 132), vp: ui.Offset(22, 82)),
        (anchor: ui.Offset(82, 168), vp: ui.Offset(22, 82)),
        (anchor: ui.Offset(92, 206), vp: ui.Offset(22, 82)),
        (anchor: ui.Offset(184, 132), vp: ui.Offset(234, 82)),
        (anchor: ui.Offset(174, 168), vp: ui.Offset(234, 82)),
        (anchor: ui.Offset(164, 206), vp: ui.Offset(234, 82)),
      ],
      vanishingPoints: const [ui.Offset(22, 82), ui.Offset(234, 82)],
    );

    await _perspectiveCase(
      out: out,
      name: 'perspective3',
      ruler: const Ruler(
        type: RulerType.threePointPerspective,
        position: ui.Offset(128, 128),
        settings: RulerSettings(
          vanishingPoint1: ui.Offset(20, 105),
          vanishingPoint2: ui.Offset(236, 105),
          vanishingPoint3: ui.Offset(128, 18),
        ),
      ),
      rays: const [
        (anchor: ui.Offset(70, 135), vp: ui.Offset(20, 105)),
        (anchor: ui.Offset(78, 180), vp: ui.Offset(20, 105)),
        (anchor: ui.Offset(186, 135), vp: ui.Offset(236, 105)),
        (anchor: ui.Offset(178, 180), vp: ui.Offset(236, 105)),
        (anchor: ui.Offset(112, 75), vp: ui.Offset(128, 18)),
        (anchor: ui.Offset(144, 75), vp: ui.Offset(128, 18)),
      ],
      vanishingPoints: const [
        ui.Offset(20, 105),
        ui.Offset(236, 105),
        ui.Offset(128, 18),
      ],
    );
  });
}

Future<void> _perspectiveCase({
  required Directory out,
  required String name,
  required Ruler ruler,
  required List<({ui.Offset anchor, ui.Offset vp})> rays,
  required List<ui.Offset> vanishingPoints,
}) async {
  final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
  final re = RulerEngine()..setActiveRuler(ruler);
  final draw = DrawingEngine(tileManager: tm)
    ..currentBrush = _brush(size: 3)
    ..currentColor = const ui.Color(0xFFDD3B2E)
    ..pointConstraint = re.snapToRuler;

  for (var i = 0; i < rays.length; i++) {
    final ray = rays[i];
    re.beginStroke();
    draw.beginStroke(StrokePoint(x: ray.anchor.dx, y: ray.anchor.dy), _layer);
    final delta = ray.vp - ray.anchor;
    final normal = ui.Offset(-delta.dy, delta.dx) / delta.distance;
    for (var s = 1; s <= 12; s++) {
      final t = s / 14.0;
      final jitter = math.sin((s + i) * 1.7) * 10;
      final raw = ray.anchor + delta * t + normal * jitter;
      draw.continueStroke(StrokePoint(x: raw.dx, y: raw.dy), _layer);
    }
    draw.endStroke();
  }

  final baseImage = await tm.compositeLayerToImage(_layer);
  final rgba = await _rgba(baseImage);
  var painted = 0;
  var far = 0;
  var maxDistance = 0.0;
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      if (rgba[(y * _w + x) * 4 + 3] == 0) continue;
      painted++;
      final p = ui.Offset(x + 0.5, y + 0.5);
      var d = double.infinity;
      for (final ray in rays) {
        d = math.min(d, _distanceToInfiniteLine(p, ray.vp, ray.anchor));
      }
      maxDistance = math.max(maxDistance, d);
      if (d > 4.5) far++;
    }
  }
  expect(painted, greaterThan(250), reason: '$name: 複数の実ストロークが十分描画されること');
  expect(far, 0, reason: '$name: 全描画画素が期待する消失点レイ群上にあること max=$maxDistance');
  baseImage.dispose();

  for (final vp in vanishingPoints) {
    _markCross(tm, _layer, vp, const ui.Color(0xFF111111));
  }
  final evidence = await tm.compositeLayerToImage(_layer);
  await _save(evidence, '${out.path}/$name-convergence.png');
  evidence.dispose();
  tm.dispose();
}

Brush _brush({
  double size = 12,
  int opacity = 100,
  bool stabilization = false,
  int stabilizationStrength = 0,
  BrushMixingMode mixingMode = BrushMixingMode.off,
  int mixingRate = 0,
  int mixingStretch = 0,
}) => Brush(
  id: 'strict',
  name: 'strict',
  size: size,
  opacity: opacity,
  spacing: 1,
  stabilization: stabilization,
  stabilizationStrength: stabilizationStrength,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: const PressureRangeSetting(enabled: false, weak: 50, strong: 100),
    opacity: const PressureRangeSetting(enabled: false, weak: 50, strong: 100),
    mixing: PressureMixingOnSetting(
      enabled: mixingMode != BrushMixingMode.off,
      mode: mixingMode == BrushMixingMode.off
          ? BrushMixingMode.oil
          : mixingMode,
      weakRate: mixingRate,
      strongRate: mixingRate,
      stretch: mixingStretch,
    ),
  ),
  pressureOff: BrushPressureOffSettings.defaults.copyWith(
    mixing: PressureMixingOffSetting(
      enabled: mixingMode != BrushMixingMode.off,
      mode: mixingMode == BrushMixingMode.off
          ? BrushMixingMode.oil
          : mixingMode,
      rate: mixingRate,
      stretch: mixingStretch,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
);

void _fillLayer(TileManager tm, String key, ui.Color color) {
  final rgba = Uint8List(_w * _h * 4);
  for (var i = 0; i < _w * _h; i++) {
    rgba[i * 4] = color.red8;
    rgba[i * 4 + 1] = color.green8;
    rgba[i * 4 + 2] = color.blue8;
    rgba[i * 4 + 3] = 255;
  }
  tm.replaceLayerPixels(key, rgba);
}

void _markCross(TileManager tm, String key, ui.Offset p, ui.Color c) {
  final tx = (p.dx ~/ TileManager.tileSize);
  final ty = (p.dy ~/ TileManager.tileSize);
  final tile = tm.getOrCreateTile(key, tx, ty);
  final ox = tx * TileManager.tileSize;
  final oy = ty * TileManager.tileSize;
  for (var d = -6; d <= 6; d++) {
    for (final q in [ui.Offset(p.dx + d, p.dy), ui.Offset(p.dx, p.dy + d)]) {
      final x = q.dx.round() - ox;
      final y = q.dy.round() - oy;
      if (x >= 0 &&
          y >= 0 &&
          x < TileManager.tileSize &&
          y < TileManager.tileSize) {
        tm.setPixel(tile, x, y, c.red8, c.green8, c.blue8, 255);
      }
    }
  }
  tm.markDirty(key, tx, ty);
}

Future<Uint8List> _rgba(ui.Image image) async => (await image.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

Future<void> _save(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
}

List<int> _pixel(Uint8List rgba, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
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

double _centerlineVariation(Uint8List rgba, int w, int h) {
  final ys = <double>[];
  for (var x = 18; x < w - 18; x++) {
    var sum = 0.0;
    var weight = 0.0;
    for (var y = 20; y < h - 20; y++) {
      final a = rgba[(y * w + x) * 4 + 3].toDouble();
      if (a <= 16) continue;
      sum += y * a;
      weight += a;
    }
    if (weight > 0) ys.add(sum / weight);
  }
  if (ys.length < 3) return double.infinity;
  var total = 0.0;
  for (var i = 1; i < ys.length; i++) {
    total += (ys[i] - ys[i - 1]).abs();
  }
  return total;
}

double _distanceToInfiniteLine(ui.Offset p, ui.Offset a, ui.Offset b) {
  final ab = b - a;
  if (ab.distance < 1e-9) return (p - a).distance;
  return ((ab.dx * (a.dy - p.dy) - (a.dx - p.dx) * ab.dy).abs()) / ab.distance;
}
