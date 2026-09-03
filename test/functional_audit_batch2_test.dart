import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/camera_engine.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/layer_keyframe_engine.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'helpers/color_channels.dart';

const int w = 96;
const int h = 96;
const ui.Color base = ui.Color.fromARGB(255, 60, 180, 120);
const ui.Color src = ui.Color.fromARGB(255, 100, 80, 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('全17ブレンドモードを標準参照式と比較', () async {
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
          ),
          const Layer(id: 'bottom', name: 'bottom', type: LayerType.normal),
        ],
        (l) => l.id,
        w,
        h,
      );
      await _save(image, '${out.path}/blend_ref_${mode.name}.png');
      final rgba = await _rgba(image);
      final actual = _pixel(rgba, 48, 48);
      final expected = _blendReference(mode, base, src);
      for (var c = 0; c < 3; c++) {
        expect(
          (actual[c] - expected[c]).abs(),
          lessThanOrEqualTo(5),
          reason:
              '${mode.name} channel=$c actual=${actual[c]} expected=${expected[c]}',
        );
      }
      expect(actual[3], 255, reason: '${mode.name} alpha');
      image.dispose();
      tm.dispose();
    }
  });

  test('描画フィルター全種を実画像へ適用しPNG化', () async {
    final input = _testPattern();
    final mask = _lensMask();
    for (final kind in FilterKind.values) {
      final filter = _filterFor(kind);
      final result = applyDrawFilterInIsolate((
        input,
        w,
        h,
        filter,
        kind == FilterKind.lensDistortion ? mask : null,
      ));
      expect(result.length, input.length, reason: '${kind.name} output length');
      expect(
        result,
        isNot(same(input)),
        reason: '${kind.name} must return independent buffer',
      );
      final image = await _image(result);
      await _save(image, '${out.path}/draw_filter_${kind.name}.png');
      image.dispose();
      for (var i = 3; i < result.length; i += 4) {
        expect(
          result[i],
          inInclusiveRange(0, 255),
          reason: '${kind.name} alpha range',
        );
      }
    }

    final linear = applyDrawFilterInIsolate((
      input,
      w,
      h,
      const FilterDef(
        id: 'linear',
        name: 'linear',
        kind: FilterKind.toneCurve,
        toneCurvePreset: ToneCurvePreset.linear,
      ),
      null,
    ));
    _expectBytesNear(
      linear,
      input,
      tolerance: 1,
      reason: 'linear tone curve must be identity',
    );

    final levels = applyDrawFilterInIsolate((
      input,
      w,
      h,
      const FilterDef(id: 'levels', name: 'levels', kind: FilterKind.levels),
      null,
    ));
    _expectBytesNear(
      levels,
      input,
      tolerance: 1,
      reason: 'default levels must be identity',
    );

    final threshold = applyDrawFilterInIsolate((
      input,
      w,
      h,
      const FilterDef(
        id: 'threshold',
        name: 'threshold',
        kind: FilterKind.threshold,
        thresholdValue: 128,
      ),
      null,
    ));
    for (var i = 0; i < threshold.length; i += 4) {
      if (threshold[i + 3] == 0) continue;
      expect({0, 255}.contains(threshold[i]), isTrue);
      expect(threshold[i], threshold[i + 1]);
      expect(threshold[i + 1], threshold[i + 2]);
    }

    final vignette = applyDrawFilterInIsolate((
      input,
      w,
      h,
      const FilterDef(
        id: 'vig',
        name: 'vig',
        kind: FilterKind.vignette,
        strength: 100,
      ),
      null,
    ));
    expect(
      _luma(_pixel(vignette, 48, 48)),
      greaterThan(_luma(_pixel(vignette, 2, 2))),
      reason: 'vignette should darken corners more than center',
    );

    final pixelated = applyDrawFilterInIsolate((
      input,
      w,
      h,
      const FilterDef(
        id: 'px',
        name: 'px',
        kind: FilterKind.pixelate,
        strength: 8,
      ),
      null,
    ));
    expect(
      _pixel(pixelated, 17, 17).sublist(0, 3),
      equals(_pixel(pixelated, 22, 22).sublist(0, 3)),
      reason: 'pixelate should make pixels inside a block equal',
    );
  });

  test('演出フィルター全種：範囲・enabled・実出力を確認', () async {
    final engine = FilterEngine();
    final input = _testPattern();
    for (final type in EffectFilterType.values) {
      final effect = EffectFilterInstance(
        id: type.name,
        type: type,
        startFrame: 3,
        endFrame: 7,
        param1: _effectParam1(type),
        param2: 50,
        param3: 2,
        param4: 25,
        fadeColor: const Color(0xFF203060),
      );
      final before = engine.applyEffectFilters(
        Uint8List.fromList(input),
        w,
        h,
        [effect],
        2,
      );
      expect(
        before,
        equals(input),
        reason: '${type.name}: before range must be no-op',
      );
      final after = engine.applyEffectFilters(Uint8List.fromList(input), w, h, [
        effect,
      ], 8);
      expect(
        after,
        equals(input),
        reason: '${type.name}: after range must be no-op',
      );
      final disabled = engine.applyEffectFilters(
        Uint8List.fromList(input),
        w,
        h,
        [effect.copyWith(enabled: false)],
        5,
      );
      expect(
        disabled,
        equals(input),
        reason: '${type.name}: disabled must be no-op',
      );
      final active = engine.applyEffectFilters(
        Uint8List.fromList(input),
        w,
        h,
        [effect],
        5,
      );
      expect(active.length, input.length);
      final image = await _image(active);
      await _save(image, '${out.path}/effect_filter_${type.name}.png');
      image.dispose();
    }
  });

  test('カメラ：補間・移動・拡大・回転を実レンダリング', () async {
    final engine = CameraEngine();
    const keys = [
      CameraKeyframe(frameIndex: 0, x: 0, y: 0, zoom: 1, rotation: 0),
      CameraKeyframe(frameIndex: 10, x: 20, y: -10, zoom: 2, rotation: 90),
    ];
    final mid = engine.valueAt(keys, 5);
    expect(mid.x, closeTo(10, 1e-9));
    expect(mid.y, closeTo(-5, 1e-9));
    expect(mid.zoom, closeTo(1.5, 1e-9));
    expect(mid.rotation, closeTo(45, 1e-9));
    expect(engine.valueAt(keys, -10).x, 0);
    expect(engine.valueAt(keys, 99).x, 20);
    for (final frame in [0, 5, 10]) {
      final kf = engine.valueAt(keys, frame);
      final image = await _renderCamera(engine, kf);
      await _save(image, '${out.path}/camera_frame_$frame.png');
      image.dispose();
    }
    final noMove = await _renderCamera(
      engine,
      const CameraKeyframe(frameIndex: 0),
    );
    final moveX = await _renderCamera(
      engine,
      const CameraKeyframe(frameIndex: 0, x: 15),
    );
    final a = await _rgba(noMove);
    final b = await _rgba(moveX);
    expect(_centroidX(b), lessThan(_centroidX(a)));
    noMove.dispose();
    moveX.dispose();
  });

  test('レイヤーキーフレーム：linear/easingと実変形を確認', () async {
    final engine = LayerKeyframeEngine();
    for (final easing in LayerKeyframeEasing.values) {
      final keys = [
        LayerKeyframe(
          frameIndex: 0,
          x: 0,
          scale: 1,
          rotation: 0,
          easing: easing,
        ),
        const LayerKeyframe(frameIndex: 10, x: 40, scale: 2, rotation: 90),
      ];
      final start = engine.valueAt(keys, 0);
      final end = engine.valueAt(keys, 10);
      expect(start.x, closeTo(0, 1e-9));
      expect(end.x, closeTo(40, 1e-9));
      final mid = engine.valueAt(keys, 5);
      if (easing == LayerKeyframeEasing.linear ||
          easing == LayerKeyframeEasing.easeInOut) {
        expect(mid.x, closeTo(20, 0.001));
      } else if (easing == LayerKeyframeEasing.easeIn) {
        expect(mid.x, lessThan(20));
      } else if (easing == LayerKeyframeEasing.easeOut) {
        expect(mid.x, greaterThan(20));
      }
    }

    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final tile = tm.getOrCreateTile('layer', 0, 0);
    for (var y = 38; y < 58; y++) {
      for (var x = 18; x < 38; x++) {
        tm.setPixel(tile, x, y, 230, 70, 50, 255);
      }
    }
    tm.markDirty('layer', 0, 0);
    const layer = Layer(id: 'layer', name: 'layer', type: LayerType.normal);
    for (final frame in [0, 5, 10]) {
      final kf = engine.valueAt(const [
        LayerKeyframe(frameIndex: 0, x: 0, y: 0, scale: 1, rotation: 0),
        LayerKeyframe(frameIndex: 10, x: 35, y: -10, scale: 1.5, rotation: 45),
      ], frame);
      final image = await LayerCompositor.composite(
        tm,
        const [layer],
        (l) => l.id,
        w,
        h,
        keyframeOf: (_) => kf,
      );
      await _save(image, '${out.path}/layer_keyframe_$frame.png');
      image.dispose();
    }
    tm.dispose();
  });
}

FilterDef _filterFor(FilterKind kind) {
  return FilterDef(
    id: kind.name,
    name: kind.name,
    kind: kind,
    strength: switch (kind) {
      FilterKind.gaussianBlur || FilterKind.lensBlur => 6,
      FilterKind.sharpen => 60,
      FilterKind.unsharpMask => 4,
      FilterKind.vignette => 70,
      FilterKind.noise => 35,
      FilterKind.threshold => 128,
      FilterKind.fisheye ||
      FilterKind.chromaticAberration ||
      FilterKind.lensDistortion => 45,
      FilterKind.pixelate => 8,
      FilterKind.auroraHologram => 100,
      _ => 60,
    },
    colorLevels: 6,
    edgeStrength: 0.8,
    toneCurvePreset: kind == FilterKind.toneCurve
        ? ToneCurvePreset.highContrast
        : ToneCurvePreset.linear,
    outlineColor: 0xFFFF3050,
    outlineWidth: 4,
    vignetteColor: 0xFF101020,
    caSaturation: 35,
    caBrightness: 12,
    caContrast: 25,
    monochromeColor: 0xFFFFC080,
    thresholdValue: 128,
    lensCenterOffsetX: 2,
    lensCenterOffsetY: -2,
    hologramBrightness: 10,
    hologramSaturation: 20,
    bgBlendColor: 0xFF6080A0,
    bgBlendDirection: 30,
    bgBlendLength: 8,
    bgBlendBlur: 3,
  );
}

double _effectParam1(EffectFilterType type) => switch (type) {
  EffectFilterType.fade => 65,
  EffectFilterType.gaussianBlur || EffectFilterType.lensBlur => 5,
  EffectFilterType.mosaic || EffectFilterType.pixelate => 8,
  EffectFilterType.chromaticAberration => 6,
  EffectFilterType.noise || EffectFilterType.animatedNoise => 35,
  EffectFilterType.threshold => 128,
  EffectFilterType.fisheye => 45,
  EffectFilterType.auroraHologram => 80,
  _ => 60,
};

Uint8List _testPattern() {
  final data = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final checker = ((x ~/ 12) + (y ~/ 12)).isEven;
      data[i] = ((x / (w - 1)) * 255).round();
      data[i + 1] = ((y / (h - 1)) * 255).round();
      data[i + 2] = checker ? 220 : 40;
      data[i + 3] = 255;
    }
  }
  return data;
}

Uint8List _lensMask() {
  final data = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = x - 48;
      final dy = y - 48;
      if (dx * dx + dy * dy <= 28 * 28) {
        final i = (y * w + x) * 4;
        data[i] = data[i + 1] = data[i + 2] = 255;
        data[i + 3] = 255;
      }
    }
  }
  return data;
}

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

void _expectBytesNear(
  List<int> actual,
  List<int> expected, {
  required int tolerance,
  required String reason,
}) {
  expect(actual.length, expected.length, reason: reason);
  for (var i = 0; i < actual.length; i++) {
    expect(
      (actual[i] - expected[i]).abs(),
      lessThanOrEqualTo(tolerance),
      reason: '$reason index=$i',
    );
  }
}

double _luma(List<int> p) => p[0] * 0.2126 + p[1] * 0.7152 + p[2] * 0.0722;

Future<ui.Image> _renderCamera(CameraEngine engine, CameraKeyframe kf) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  canvas.save();
  engine.apply(canvas, kf, w.toDouble(), h.toDouble());
  canvas.drawRect(
    const ui.Rect.fromLTWH(58, 38, 16, 20),
    ui.Paint()..color = const ui.Color(0xFFEF4030),
  );
  canvas.drawCircle(
    const ui.Offset(30, 62),
    8,
    ui.Paint()..color = const ui.Color(0xFF2060D0),
  );
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  return image;
}

double _centroidX(List<int> rgba) {
  double sum = 0;
  int count = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = _pixel(rgba, x, y);
      if (p[0] > 180 && p[1] < 120 && p[2] < 120) {
        sum += x;
        count++;
      }
    }
  }
  return count == 0 ? double.nan : sum / count;
}

List<int> _blendReference(
  LayerBlendMode mode,
  ui.Color backdrop,
  ui.Color source,
) {
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
        (i) => cb[i] <= 0.5
            ? 2 * cb[i] * cs[i]
            : 1 - 2 * (1 - cb[i]) * (1 - cs[i]),
      );
    case LayerBlendMode.addition:
      o = List.generate(3, (i) => math.min(1.0, cb[i] + cs[i]));
    case LayerBlendMode.subtract:
      o = List.generate(3, (i) => math.max(0.0, cb[i] - cs[i]));
    case LayerBlendMode.darken:
      o = List.generate(3, (i) => math.min(cb[i], cs[i]));
    case LayerBlendMode.lighten:
      o = List.generate(3, (i) => math.max(cb[i], cs[i]));
    case LayerBlendMode.colorBurn:
      o = List.generate(
        3,
        (i) => cs[i] <= 0 ? 0 : 1 - math.min(1.0, (1 - cb[i]) / cs[i]),
      );
    case LayerBlendMode.colorDodge:
      o = List.generate(
        3,
        (i) => cs[i] >= 1 ? 1 : math.min(1.0, cb[i] / (1 - cs[i])),
      );
    case LayerBlendMode.hardLight:
      o = List.generate(
        3,
        (i) => cs[i] <= 0.5
            ? 2 * cb[i] * cs[i]
            : 1 - 2 * (1 - cb[i]) * (1 - cs[i]),
      );
    case LayerBlendMode.softLight:
      o = List.generate(3, (i) {
        final b = cb[i], s = cs[i];
        final d = b <= 0.25 ? ((16 * b - 12) * b + 4) * b : math.sqrt(b);
        return s <= 0.5
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
  return [...o.map((v) => (v.clamp(0.0, 1.0) * 255).round()), 255];
}

double _lum(List<double> c) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];
double _sat(List<double> c) => c.reduce(math.max) - c.reduce(math.min);

List<double> _clipColor(List<double> c) {
  var r = c[0], g = c[1], b = c[2];
  final l = _lum([r, g, b]);
  final n = math.min(r, math.min(g, b));
  if (n < 0) {
    r = l + ((r - l) * l) / (l - n);
    g = l + ((g - l) * l) / (l - n);
    b = l + ((b - l) * l) / (l - n);
  }
  final max2 = math.max(r, math.max(g, b));
  if (max2 > 1) {
    r = l + ((r - l) * (1 - l)) / (max2 - l);
    g = l + ((g - l) * (1 - l)) / (max2 - l);
    b = l + ((b - l) * (1 - l)) / (max2 - l);
  }
  return [r, g, b];
}

List<double> _setLum(List<double> c, double l) {
  final d = l - _lum(c);
  return _clipColor([c[0] + d, c[1] + d, c[2] + d]);
}

List<double> _setSat(List<double> c, double s) {
  final indexed = [0, 1, 2]..sort((a, b) => c[a].compareTo(c[b]));
  final out = List<double>.from(c);
  final minI = indexed[0], midI = indexed[1], maxI = indexed[2];
  if (c[maxI] > c[minI]) {
    out[midI] = ((c[midI] - c[minI]) * s) / (c[maxI] - c[minI]);
    out[maxI] = s;
  } else {
    out[midI] = 0;
    out[maxI] = 0;
  }
  out[minI] = 0;
  return out;
}
