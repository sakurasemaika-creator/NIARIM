import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/sphere_shading_engine.dart';
import 'package:niarim/models/filter_canvas_gizmo.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 120, _h = 80;

/// An opaque disc of [rgb] centred on the canvas (premultiplied, as layers
/// are), the rest transparent.
Uint8List _disc(List<int> rgb, {double radius = 34, int alpha = 255}) {
  final out = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final dx = x + 0.5 - _w / 2, dy = y + 0.5 - _h / 2;
      if (dx * dx + dy * dy > radius * radius) continue;
      final i = (y * _w + x) * 4;
      out[i] = (rgb[0] * alpha / 255).round();
      out[i + 1] = (rgb[1] * alpha / 255).round();
      out[i + 2] = (rgb[2] * alpha / 255).round();
      out[i + 3] = alpha;
    }
  }
  return out;
}

List<int> _px(Uint8List data, int x, int y) {
  final i = (y * _w + x) * 4;
  return data.sublist(i, i + 4);
}

Uint8List _shade(
  Uint8List data, {
  int shadow = 0xFF000000,
  int light = 0xFFFFFFFF,
  LayerBlendMode shadowBlend = LayerBlendMode.normal,
  LayerBlendMode lightBlend = LayerBlendMode.normal,
  bool combined = false,
  LayerBlendMode combinedBlend = LayerBlendMode.hardLight,
  double cx = 50,
  double cy = 30,
  double rx = 16,
  double ry = 12,
  double blur = 0,
  Uint8List? mask,
}) => applySphereShading(
  data,
  _w,
  _h,
  shadowColor: shadow,
  lightColor: light,
  shadowBlend: shadowBlend,
  lightBlend: lightBlend,
  combined: combined,
  combinedBlend: combinedBlend,
  centerX: cx,
  centerY: cy,
  radiusX: rx,
  radiusY: ry,
  blur: blur,
  mask: mask,
);

void main() {
  test('inside the light ellipse gets the light colour, outside it the '
      'shadow colour, and only where something is drawn', () {
    final out = _shade(_disc([120, 120, 120]));
    expect(_px(out, 50, 30), [255, 255, 255, 255], reason: 'light centre');
    expect(_px(out, 64, 30), [255, 255, 255, 255], reason: 'inside, rx 16');
    expect(_px(out, 68, 30), [0, 0, 0, 255], reason: 'outside the light');
    expect(_px(out, 80, 55), [0, 0, 0, 255], reason: 'far side of the disc');
    expect(_px(out, 2, 2), [0, 0, 0, 0], reason: 'nothing drawn there');
  });

  test('the layer keeps its own opacity; colours stay valid premultiplied', () {
    final out = _shade(_disc([200, 100, 50], alpha: 128));
    for (var i = 0; i < out.length; i += 4) {
      expect(out[i + 3], i % 4 == 0 ? out[i + 3] : 0);
      expect(out[i], lessThanOrEqualTo(out[i + 3]));
      expect(out[i + 1], lessThanOrEqualTo(out[i + 3]));
      expect(out[i + 2], lessThanOrEqualTo(out[i + 3]));
    }
    expect(_px(out, 50, 30), [128, 128, 128, 128]);
    expect(_px(out, 80, 55), [0, 0, 0, 128]);
  });

  test('blur widens the soft edge between light and shadow', () {
    int softPixels(Uint8List out) {
      var n = 0;
      // Across the right-hand edge of the light (x = 66) only.
      for (var x = 50; x < 90; x++) {
        final v = _px(out, x, 30)[0];
        if (v > 5 && v < 250) n++;
      }
      return n;
    }

    final sharp = softPixels(_shade(_disc([120, 120, 120])));
    final soft = softPixels(_shade(_disc([120, 120, 120]), blur: 60));
    expect(sharp, lessThanOrEqualTo(2), reason: 'one antialiased pixel');
    expect(soft, greaterThan(12));
  });

  test(
    'each colour goes on in its own blend mode, as strongly as its alpha',
    () {
      final base = _disc([200, 160, 120]);
      final out = _shade(
        base,
        shadow: 0xFF808080,
        light: 0x80FFFFFF,
        shadowBlend: LayerBlendMode.multiply,
        lightBlend: LayerBlendMode.screen,
      );
      // Shadow: 200 × 128/255 ≈ 100 (multiply at full strength).
      expect(_px(out, 80, 55)[0], closeTo(100, 1));
      // Light: screen with white is white, at half strength.
      expect(_px(out, 50, 30)[0], closeTo((200 + 255) / 2, 1));
      // A transparent colour leaves its side as it was.
      final none = _shade(base, shadow: 0x00000000);
      expect(_px(none, 80, 55), _px(base, 80, 55));
    },
  );

  test('combined: one map in one blend mode — Hard Light darkens with the '
      'dark shadow colour and brightens with the bright light colour', () {
    final base = _disc([128, 128, 128]);
    final out = _shade(
      base,
      shadow: 0xFF404040,
      light: 0xFFE0E0E0,
      combined: true,
    );
    // Hard light, s = 64/255: 2bs = 2 × 0.502 × 0.251 ≈ 0.252 → 64.
    expect(_px(out, 80, 55)[0], closeTo(64, 1));
    // s = 224/255: screen(b, 2s - 1) = 1 - (1 - .502)(1 - .757) ≈ 0.879.
    expect(_px(out, 50, 30)[0], closeTo(224, 1));
    // The same colours each on their own in hard light give the same ends;
    // the combined map differs only across the edge.
    final apart = _shade(
      base,
      shadow: 0xFF404040,
      light: 0xFFE0E0E0,
      shadowBlend: LayerBlendMode.hardLight,
      lightBlend: LayerBlendMode.hardLight,
    );
    expect(_px(apart, 80, 55), _px(out, 80, 55));
    expect(_px(apart, 50, 30), _px(out, 50, 30));
  });

  test('a painted selection layer limits where the shading goes', () {
    final base = _disc([120, 120, 120]);
    final mask = Uint8List(_w * _h * 4);
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w / 2; x++) {
        mask[(y * _w + x) * 4 + 3] = 255;
      }
    }
    final out = _shade(base, mask: mask);
    expect(_px(out, 40, 55), [0, 0, 0, 255], reason: 'selected, in shadow');
    expect(_px(out, 80, 55), _px(base, 80, 55), reason: 'not selected');
    // An empty selection layer means no selection: all of it is shaded.
    final whole = _shade(base, mask: Uint8List(_w * _h * 4));
    expect(_px(whole, 80, 55), [0, 0, 0, 255]);
  });

  test('the filter places the light in proportions of the canvas, so the '
      'preview and the full-size result agree; it saves and restores', () {
    const filter = FilterDef(
      id: 'sphere',
      name: 'Sphere',
      kind: FilterKind.sphereShading,
      sphereShadowColor: 0x80102030,
      sphereLightColor: 0x00FFFFFF,
      sphereShadowBlend: LayerBlendMode.colorBurn,
      sphereLightBlend: LayerBlendMode.linearDodge,
      sphereCombined: true,
      sphereCombinedBlend: LayerBlendMode.softLight,
      sphereLightX: 25,
      sphereLightY: 75,
      sphereLightWidth: 50,
      sphereLightHeight: 30,
      sphereLightBlur: 12,
    );
    final restored = FilterDef.fromJson(filter.toJson());
    expect(restored.toJson(), filter.toJson());
    expect(restored.sphereShadowBlend, LayerBlendMode.colorBurn);
    expect(restored.sphereCombinedBlend, LayerBlendMode.softLight);

    // 25 % across, 75 % down; sizes are of the shorter side (80).
    final light = filter.sphereLight(_w, _h);
    expect(light.centerX, 30);
    expect(light.centerY, 60);
    expect(light.radiusX, 20);
    expect(light.radiusY, 12);
    final half = filter.sphereLight(_w ~/ 2, _h ~/ 2);
    expect(half.centerX, light.centerX / 2);
    expect(half.radiusX, light.radiusX / 2);

    final base = _disc([150, 90, 60]);
    expect(
      applyDrawFilterInIsolate((base, _w, _h, filter, null)),
      orderedEquals(applySphereShadingFilter(base, _w, _h, filter, null)),
    );
    expect(filterUsesSelectionMask(FilterKind.sphereShading), isTrue);
  });

  test('dragging the light on the canvas sets the sliders it maps to, and the '
      'fisheye centre moves by a percentage of the canvas', () async {
    SharedPreferences.setMockInitialValues({});
    final service = FilterService();
    await service.init();
    final sphere = service.filters.firstWhere(
      (f) => f.kind == FilterKind.sphereShading,
    );
    expect(sphere.id, FilterService.sphereShadingFilterId);
    final gizmo = filterCanvasGizmoFor(sphere, 1920, 1080)!;
    expect(gizmo.resizable, isTrue);
    expect(gizmo.center, const Offset(768, 378));
    expect(gizmo.radiusX, 324);

    service.moveCanvasGizmo(
      sphere.id,
      gizmo.copyWith(center: const Offset(960, 540), radiusX: 108),
      1920,
      1080,
    );
    var moved = service.filters.firstWhere((f) => f.id == sphere.id);
    expect(moved.sphereLightX, 50);
    expect(moved.sphereLightY, 50);
    expect(moved.sphereLightWidth, 20);
    expect(moved.sphereLightHeight, sphere.sphereLightHeight);
    // Kept within the sliders' ranges.
    service.moveCanvasGizmo(
      sphere.id,
      gizmo.copyWith(center: const Offset(-50, 5000), radiusX: 9999),
      1920,
      1080,
    );
    moved = service.filters.firstWhere((f) => f.id == sphere.id);
    expect(moved.sphereLightX, 0);
    expect(moved.sphereLightY, 100);
    expect(moved.sphereLightWidth, 200);

    final fisheye = service.filters.firstWhere(
      (f) => f.kind == FilterKind.fisheye,
    );
    final eye = filterCanvasGizmoFor(fisheye, 1000, 500)!;
    expect(eye.resizable, isFalse);
    expect(eye.center, const Offset(500, 250));
    expect(eye.reach, closeTo(math.sqrt(1000 * 1000 + 500 * 500) / 2, 1e-9));
    service.moveCanvasGizmo(
      fisheye.id,
      eye.copyWith(center: const Offset(750, 100)),
      1000,
      500,
    );
    final movedEye = service.filters.firstWhere((f) => f.id == fisheye.id);
    expect(movedEye.fisheyeCenterX, 25);
    expect(movedEye.fisheyeCenterY, -30);
    expect(movedEye.fisheyeCenter(1000, 500), (x: 750.0, y: 100.0));
  });

  test('visual: original, separate blends, one combined blend, soft edge, '
      'transparent light, selection', () {
    // A shaded-flat character-ish blob: a disc with a darker band.
    final base = _disc([236, 168, 140], radius: 36);
    for (var y = 50; y < 58; y++) {
      for (var x = 0; x < _w; x++) {
        final i = (y * _w + x) * 4;
        if (base[i + 3] == 0) continue;
        base.setAll(i, [120, 60, 70, 255]);
      }
    }
    final selection = Uint8List(_w * _h * 4);
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < 64; x++) {
        selection[(y * _w + x) * 4 + 3] = 255;
      }
    }
    const f = FilterDef(id: 's', name: 's', kind: FilterKind.sphereShading);
    final cases = <(String, Uint8List)>[
      ('original', base),
      (
        'separate multiply+screen (default)',
        applySphereShadingFilter(base, _w, _h, f, null),
      ),
      (
        'combined hard light',
        applySphereShadingFilter(
          base,
          _w,
          _h,
          f.copyWith(sphereCombined: true),
          null,
        ),
      ),
      (
        'blur 0',
        applySphereShadingFilter(
          base,
          _w,
          _h,
          f.copyWith(sphereLightBlur: 0),
          null,
        ),
      ),
      (
        'blur 90',
        applySphereShadingFilter(
          base,
          _w,
          _h,
          f.copyWith(sphereLightBlur: 90),
          null,
        ),
      ),
      (
        'transparent light',
        applySphereShadingFilter(
          base,
          _w,
          _h,
          f.copyWith(sphereLightColor: 0x00FFFFFF),
          null,
        ),
      ),
      (
        'left half selected',
        applySphereShadingFilter(base, _w, _h, f, selection),
      ),
    ];
    const scale = 3, gap = 6;
    final sheet = img.Image(
      width: cases.length * (_w * scale + gap) + gap,
      height: _h * scale + 2 * gap,
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (var c = 0; c < cases.length; c++) {
      final data = cases[c].$2;
      final ox = gap + c * (_w * scale + gap);
      for (var y = 0; y < _h * scale; y++) {
        for (var x = 0; x < _w * scale; x++) {
          final i = ((y ~/ scale) * _w + x ~/ scale) * 4;
          final a = data[i + 3];
          // Over a light checkerboard so transparency shows.
          final bg = ((x ~/ 12) + (y ~/ 12)).isEven ? 242 : 210;
          int over(int v) => (v + bg * (255 - a) / 255).round();
          sheet.setPixelRgb(
            ox + x,
            gap + y,
            over(data[i]),
            over(data[i + 1]),
            over(data[i + 2]),
          );
        }
      }
    }
    final dir = Directory('build/sphere-shading')..createSync(recursive: true);
    File('${dir.path}/engine_cases.png').writeAsBytesSync(img.encodePng(sheet));
    File(
      '${dir.path}/engine_cases.txt',
    ).writeAsStringSync([for (final c in cases) c.$1].join('\n'));
    // The two modes look different, and both differ from the original.
    expect(cases[1].$2, isNot(orderedEquals(base)));
    expect(cases[2].$2, isNot(orderedEquals(cases[1].$2)));
  });
}
