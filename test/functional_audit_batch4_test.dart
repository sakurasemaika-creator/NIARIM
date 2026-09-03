import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'helpers/color_channels.dart';

const int w = 96;
const int h = 96;
const ui.Color base = ui.Color.fromARGB(255, 60, 180, 120);
const ui.Color src = ui.Color.fromARGB(255, 100, 80, 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('全17ブレンド：レイヤー不透明度50%でも標準合成式と一致', () async {
    const alpha = 128 / 255.0; // Layer.opacity=50 は Paint alpha 128 になる
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
            opacity: 50,
          ),
          const Layer(id: 'bottom', name: 'bottom', type: LayerType.normal),
        ],
        (l) => l.id,
        w,
        h,
      );
      await _save(image, '${out.path}/blend_opacity50_${mode.name}.png');
      final actual = _pixel(await _rgba(image), 48, 48);
      final blend = _blend(mode, base, src);
      final expected = mode == LayerBlendMode.addition
          // BlendMode.plus は一般的な加算合成（Porter-Duff plus）。
          // source の premultiplied RGB に layer opacity が掛かった後で
          // backdrop へ加算されるので、通常ブレンドの補間式とは別になる。
          ? [
              for (var c = 0; c < 3; c++)
                math.min(
                  255,
                  (baseChannel(c) + sourceChannel(c) * alpha).round(),
                ),
              255,
            ]
          : [
              for (var c = 0; c < 3; c++)
                (baseChannel(c) * (1 - alpha) + blend[c] * alpha).round(),
              255,
            ];
      for (var c = 0; c < 3; c++) {
        expect(
          (actual[c] - expected[c]).abs(),
          lessThanOrEqualTo(5),
          reason:
              '${mode.name} opacity50 channel=$c actual=${actual[c]} expected=${expected[c]}',
        );
      }
      expect(actual[3], 255);
      image.dispose();
      tm.dispose();
    }
  });

  test('レイヤー不透明度0/50/100が見た目へ線形に反映', () async {
    final values = <int, List<int>>{};
    for (final opacity in [0, 50, 100]) {
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
            opacity: opacity,
          ),
          const Layer(id: 'bottom', name: 'bottom', type: LayerType.normal),
        ],
        (l) => l.id,
        w,
        h,
      );
      await _save(image, '${out.path}/layer_opacity_$opacity.png');
      values[opacity] = _pixel(await _rgba(image), 48, 48);
      image.dispose();
      tm.dispose();
    }
    expect(values[0]!.sublist(0, 3), equals([60, 180, 120]));
    expect(values[100]!.sublist(0, 3), equals([100, 80, 200]));
    for (var c = 0; c < 3; c++) {
      final expected = ((values[0]![c] + values[100]![c]) / 2).round();
      expect((values[50]![c] - expected).abs(), lessThanOrEqualTo(2));
    }
  });

  test('クリッピング：上レイヤーは直下の元レイヤーalpha範囲内だけ表示', () async {
    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final baseTile = tm.getOrCreateTile('clipBase', 0, 0);
    for (var y = 30; y < 66; y++) {
      for (var x = 28; x < 68; x++) {
        tm.setPixel(baseTile, x, y, 40, 160, 70, 255);
      }
    }
    tm.markDirty('clipBase', 0, 0);
    final topTile = tm.getOrCreateTile('clipTop', 0, 0);
    for (var y = 10; y < 86; y++) {
      for (var x = 10; x < 86; x++) {
        tm.setPixel(topTile, x, y, 230, 50, 80, 255);
      }
    }
    tm.markDirty('clipTop', 0, 0);

    final image = await LayerCompositor.composite(
      tm,
      const [
        Layer(
          id: 'clipTop',
          name: 'top',
          type: LayerType.normal,
          hasClipping: true,
        ),
        Layer(id: 'clipBase', name: 'base', type: LayerType.normal),
      ],
      (l) => l.id,
      w,
      h,
    );
    await _save(image, '${out.path}/layer_clipping.png');
    final rgba = await _rgba(image);
    expect(
      _pixel(rgba, 48, 48).sublist(0, 3),
      equals([230, 50, 80]),
      reason: 'inside clip source gets top color',
    );
    expect(
      _pixel(rgba, 15, 15)[3],
      0,
      reason: 'top outside clip source must not show',
    );
    image.dispose();
    tm.dispose();
  });

  test('縁取り描画フィルター：透明背景の図形の外周だけをリング化', () async {
    final input = Uint8List(w * h * 4);
    for (var y = 30; y < 66; y++) {
      for (var x = 30; x < 66; x++) {
        final i = (y * w + x) * 4;
        input[i] = 40;
        input[i + 1] = 120;
        input[i + 2] = 220;
        input[i + 3] = 255;
      }
    }
    final result = applyDrawFilterInIsolate((
      input,
      w,
      h,
      const FilterDef(
        id: 'outline-shape',
        name: 'outline-shape',
        kind: FilterKind.outline,
        outlineColor: 0xFFFF3040,
        outlineWidth: 4,
      ),
      null,
    ));
    final image = await _image(result);
    await _save(image, '${out.path}/draw_filter_outline_shape.png');
    image.dispose();

    expect(
      _pixel(result, 48, 48)[3],
      0,
      reason: 'outline layer must not contain original interior',
    );
    final justOutside = _pixel(result, 28, 48);
    expect(
      justOutside[3],
      greaterThan(0),
      reason: 'ring must exist just outside shape',
    );
    expect(justOutside[0], greaterThan(200));
    expect(
      _pixel(result, 10, 10)[3],
      0,
      reason: 'far background must stay transparent',
    );
  });
}

int baseChannel(int c) => switch (c) {
  0 => base.red8,
  1 => base.green8,
  _ => base.blue8,
};
int sourceChannel(int c) => switch (c) {
  0 => src.red8,
  1 => src.green8,
  _ => src.blue8,
};

void _fill(TileManager tm, String id, ui.Color color, {int inset = 0}) {
  final tile = tm.getOrCreateTile(id, 0, 0);
  for (var y = inset; y < h - inset; y++) {
    for (var x = inset; x < w - inset; x++) {
      tm.setPixel(
        tile,
        x,
        y,
        color.red8,
        color.green8,
        color.blue8,
        color.alpha8,
      );
    }
  }
  tm.markDirty(id, 0, 0);
}

Future<ui.Image> _image(Uint8List rgba) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
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
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

List<int> _pixel(List<int> rgba, int x, int y) {
  final i = (y * w + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
}

Future<void> _save(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

List<int> _blend(LayerBlendMode mode, ui.Color backdrop, ui.Color source) {
  final cb = [
    backdrop.red8 / 255.0,
    backdrop.green8 / 255.0,
    backdrop.blue8 / 255.0,
  ];
  final cs = [source.red8 / 255.0, source.green8 / 255.0, source.blue8 / 255.0];
  List<double> o;
  switch (mode) {
    case LayerBlendMode.normal:
      o = cs;
    case LayerBlendMode.multiply:
      o = List.generate(3, (i) => cb[i] * cs[i]);
    case LayerBlendMode.screen:
      o = List.generate(3, (i) => cb[i] + cs[i] - cb[i] * cs[i]);
    case LayerBlendMode.overlay:
      o = List.generate(
        3,
        (i) =>
            cb[i] <= .5 ? 2 * cb[i] * cs[i] : 1 - 2 * (1 - cb[i]) * (1 - cs[i]),
      );
    case LayerBlendMode.addition:
      o = List.generate(3, (i) => math.min(1, cb[i] + cs[i]));
    case LayerBlendMode.subtract:
      o = List.generate(3, (i) => math.max(0, cb[i] - cs[i]));
    case LayerBlendMode.darken:
      o = List.generate(3, (i) => math.min(cb[i], cs[i]));
    case LayerBlendMode.lighten:
      o = List.generate(3, (i) => math.max(cb[i], cs[i]));
    case LayerBlendMode.colorBurn:
      o = List.generate(
        3,
        (i) => cs[i] <= 0 ? 0 : 1 - math.min(1, (1 - cb[i]) / cs[i]),
      );
    case LayerBlendMode.colorDodge:
      o = List.generate(
        3,
        (i) => cs[i] >= 1 ? 1 : math.min(1, cb[i] / (1 - cs[i])),
      );
    case LayerBlendMode.hardLight:
      o = List.generate(
        3,
        (i) =>
            cs[i] <= .5 ? 2 * cb[i] * cs[i] : 1 - 2 * (1 - cb[i]) * (1 - cs[i]),
      );
    case LayerBlendMode.softLight:
      o = List.generate(3, (i) {
        final b = cb[i], s = cs[i];
        final d = b <= .25 ? ((16 * b - 12) * b + 4) * b : math.sqrt(b);
        return s <= .5
            ? b - (1 - 2 * s) * b * (1 - b)
            : b + (2 * s - 1) * (d - b);
      });
    case LayerBlendMode.difference:
      o = List.generate(3, (i) => (cb[i] - cs[i]).abs());
    case LayerBlendMode.hue:
      o = _setLum(_setSat(cs, _sat(cb)), _lum(cb));
    case LayerBlendMode.saturation:
      o = _setLum(_setSat(cb, _sat(cs)), _lum(cb));
    case LayerBlendMode.color:
      o = _setLum(cs, _lum(cb));
    case LayerBlendMode.luminosity:
      o = _setLum(cb, _lum(cs));
  }
  return o.map((v) => (v.clamp(0.0, 1.0) * 255).round()).toList();
}

double _lum(List<double> c) => .3 * c[0] + .59 * c[1] + .11 * c[2];
double _sat(List<double> c) => c.reduce(math.max) - c.reduce(math.min);
List<double> _clip(List<double> c) {
  var r = c[0], g = c[1], b = c[2];
  final l = _lum([r, g, b]);
  final n = math.min(r, math.min(g, b));
  if (n < 0) {
    r = l + (r - l) * l / (l - n);
    g = l + (g - l) * l / (l - n);
    b = l + (b - l) * l / (l - n);
  }
  final x = math.max(r, math.max(g, b));
  if (x > 1) {
    r = l + (r - l) * (1 - l) / (x - l);
    g = l + (g - l) * (1 - l) / (x - l);
    b = l + (b - l) * (1 - l) / (x - l);
  }
  return [r, g, b];
}

List<double> _setLum(List<double> c, double l) {
  final d = l - _lum(c);
  return _clip([c[0] + d, c[1] + d, c[2] + d]);
}

List<double> _setSat(List<double> c, double s) {
  final idx = [0, 1, 2]..sort((a, b) => c[a].compareTo(c[b]));
  final o = List<double>.from(c);
  final lo = idx[0], mi = idx[1], hi = idx[2];
  if (c[hi] > c[lo]) {
    o[mi] = (c[mi] - c[lo]) * s / (c[hi] - c[lo]);
    o[hi] = s;
  } else {
    o[mi] = 0;
    o[hi] = 0;
  }
  o[lo] = 0;
  return o;
}
