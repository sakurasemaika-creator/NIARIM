// 水彩境界フィルター（applyWatercolorBorder）：塗った所の縁が濃く、内側が
// 透ける。色の境目にも縁が付く（切ればαの縁だけ）。範囲・透明度の影響・
// 明度の影響の効き方。見本は build/brush-mixing/watercolor_border.png。
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/watercolor_border_engine.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';

const _size = 120;

/// Premultiplied RGBA with an opaque disc of [rgb] around the centre.
Uint8List _disc(int rgb, {double radius = 40}) {
  final data = Uint8List(_size * _size * 4);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final d = math.sqrt(
        math.pow(x - 60 + 0.5, 2) + math.pow(y - 60 + 0.5, 2),
      );
      if (d > radius) continue;
      final i = (y * _size + x) * 4;
      data[i] = rgb >> 16 & 0xFF;
      data[i + 1] = rgb >> 8 & 0xFF;
      data[i + 2] = rgb & 0xFF;
      data[i + 3] = 255;
    }
  }
  return data;
}

/// Two opaque blocks side by side (x < 60 and x ≥ 60) inside a margin.
Uint8List _twoBlocks(int left, int right) {
  final data = Uint8List(_size * _size * 4);
  for (var y = 10; y < 110; y++) {
    for (var x = 10; x < 110; x++) {
      final rgb = x < 60 ? left : right;
      final i = (y * _size + x) * 4;
      data[i] = rgb >> 16 & 0xFF;
      data[i + 1] = rgb >> 8 & 0xFF;
      data[i + 2] = rgb & 0xFF;
      data[i + 3] = 255;
    }
  }
  return data;
}

/// How the pixel at ([x], [y]) looks over white paper, 0–255 luminance.
double _onWhite(Uint8List data, int x, int y) {
  final i = (y * _size + x) * 4;
  final a = data[i + 3] / 255;
  double over(int c) => c.toDouble() + 255 * (1 - a);
  return 0.2126 * over(data[i]) +
      0.7152 * over(data[i + 1]) +
      0.0722 * over(data[i + 2]);
}

/// The darkest pixel on the disc's left edge (x 20–24 along the middle row).
double _darkestAtEdge(Uint8List data) =>
    [for (var x = 20; x <= 24; x++) _onWhite(data, x, 60)].reduce(math.min);

Uint8List _apply(
  Uint8List data, {
  double range = 10,
  double opacity = 45,
  double darken = 40,
  double blur = 2,
  bool colorEdges = true,
}) => applyWatercolorBorder(
  data,
  _size,
  _size,
  range: range,
  opacityEffect: opacity,
  darkenEffect: darken,
  blur: blur,
  colorEdges: colorEdges,
);

void main() {
  test('the rim is darker than the centre, which turns sheer', () {
    final out = _apply(_disc(0x3A7BD5));
    final centre = (60 * _size + 60) * 4;
    final rim = (60 * _size + 22) * 4; // 2px inside the disc's edge
    expect(out[centre + 3], lessThan(200));
    expect(out[rim + 3], greaterThan(out[centre + 3]));
    // A crisp darker line right at the edge (the disc's edge is at x 20).
    expect(_darkestAtEdge(out), lessThan(_onWhite(out, 60, 60) - 40));
    // The rim is darker than the paint was, not only more opaque.
    expect(_darkestAtEdge(out), lessThan(_darkestAtEdge(_disc(0x3A7BD5)) - 15));
  });

  test('outside the paint stays transparent; channels stay within alpha', () {
    final out = _apply(_disc(0xE84C8C));
    for (var i = 0; i < out.length; i += 4) {
      expect(out[i], lessThanOrEqualTo(out[i + 3]));
      expect(out[i + 1], lessThanOrEqualTo(out[i + 3]));
      expect(out[i + 2], lessThanOrEqualTo(out[i + 3]));
    }
    expect(out[3], 0);
    expect(out[(60 * _size + 105) * 4 + 3], 0);
  });

  test('範囲 reaches further in; no effect leaves the paint alone', () {
    final narrow = _apply(_disc(0x3A7BD5), range: 4, opacity: 0);
    final wide = _apply(_disc(0x3A7BD5), range: 25, opacity: 0);
    // 6px inside the edge only the wide rim still darkens.
    expect(_onWhite(wide, 26, 60), lessThan(_onWhite(narrow, 26, 60) - 6));
    expect(
      _onWhite(narrow, 26, 60),
      closeTo(_onWhite(_disc(0x3A7BD5), 26, 60), 3),
    );

    final none = _apply(_disc(0x3A7BD5), opacity: 0, darken: 0);
    expect(none, _disc(0x3A7BD5));
  });

  test('透明度の影響 and 明度の影響 each do their own part', () {
    final sheer = _apply(_disc(0x3A7BD5), opacity: 100, darken: 0);
    final dark = _apply(_disc(0x3A7BD5), opacity: 0, darken: 100);
    final centre = (60 * _size + 60) * 4;
    // Transparency thins the inside but leaves the rim's colour.
    expect(sheer[centre + 3], lessThan(80));
    // Darkening keeps every pixel opaque and darkens the rim.
    expect(dark[centre + 3], 255);
    expect(_darkestAtEdge(dark), lessThan(_onWhite(dark, 60, 60) - 30));
  });

  test('areas of different colours each get their own rim', () {
    final blocks = _twoBlocks(0xF2C14E, 0x5DA9E9);
    final withEdges = _apply(blocks);
    final without = _apply(blocks, colorEdges: false);
    // Just either side of the border between the two colours (x = 60).
    for (final x in [57, 62]) {
      expect(
        _onWhite(withEdges, x, 60),
        lessThan(_onWhite(without, x, 60) - 15),
        reason: 'x=$x',
      );
    }
  });

  test('the draw filter changes the working layer itself', () {
    // Not one of the filters that draw onto a new layer beside the source.
    expect(filterGeneratesLayer(FilterKind.watercolorBorder), isFalse);
    const filter = FilterDef(
      id: FilterService.watercolorBorderFilterId,
      name: '水彩境界',
      kind: FilterKind.watercolorBorder,
      watercolorBorderRange: 12,
      watercolorBorderDarken: 70,
      watercolorBorderOpacity: 30,
      watercolorBorderBlur: 3,
      watercolorBorderColorEdges: false,
    );
    final source = _disc(0x3A7BD5);
    final viaDispatcher = applyDrawFilterInIsolate((
      source,
      _size,
      _size,
      filter,
      null,
    ));
    expect(
      viaDispatcher,
      _apply(
        source,
        range: 12,
        darken: 70,
        opacity: 30,
        blur: 3,
        colorEdges: false,
      ),
    );
  });

  test('as an effect filter on an opaque frame, the inside lightens to '
      'paper instead of turning transparent', () {
    // The frame as exported: the disc on white paper.
    final frame = _disc(0x3A7BD5);
    for (var i = 0; i < frame.length; i += 4) {
      if (frame[i + 3] == 0) {
        frame[i] = frame[i + 1] = frame[i + 2] = frame[i + 3] = 255;
      }
    }
    final out = FilterEngine().applyEffectFilters(frame, _size, _size, [
      const EffectFilterInstance(
        id: 'e',
        type: EffectFilterType.watercolorBorder,
        startFrame: 0,
        endFrame: 0,
        param1: 10,
        param2: 40,
        param3: 45,
        param4: 2,
      ),
    ], 0);
    for (var i = 3; i < out.length; i += 4) {
      expect(out[i], 255);
    }
    // The paper stays white; the inside is paler and the rim deeper.
    expect(out.sublist(0, 4), [255, 255, 255, 255]);
    expect(_onWhite(out, 60, 60), greaterThan(_onWhite(frame, 60, 60) + 20));
    expect(_darkestAtEdge(out), lessThan(_darkestAtEdge(frame) - 15));
  });

  test('sample sheet', () {
    // Flat colours side by side, as the reference illustrations are painted.
    const w = 360;
    const h = 200;
    final data = Uint8List(w * h * 4);
    void fill(int rgb, bool Function(int x, int y) inside) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (!inside(x, y)) continue;
          final i = (y * w + x) * 4;
          data[i] = rgb >> 16 & 0xFF;
          data[i + 1] = rgb >> 8 & 0xFF;
          data[i + 2] = rgb & 0xFF;
          data[i + 3] = 255;
        }
      }
    }

    bool circle(int x, int y, double cx, double cy, double r) =>
        (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;
    fill(0xF4C27A, (x, y) => circle(x, y, 90, 100, 70));
    fill(0xE8586B, (x, y) => circle(x, y, 60, 80, 28));
    fill(0x7FC8A9, (x, y) => circle(x, y, 120, 125, 30));
    fill(0x5B8DEF, (x, y) => x > 190 && x < 340 && y > 30 && y < 170);
    fill(0xF7E36B, (x, y) => circle(x, y, 265, 100, 42));
    final out = applyWatercolorBorder(
      data,
      w,
      h,
      range: 10,
      opacityEffect: 45,
      darkenEffect: 40,
    );
    final sheet = img.Image(width: w * 2 + 10, height: h);
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        for (final (src, ox) in [(data, 0), (out, w + 10)]) {
          final i = (y * w + x) * 4;
          final a = src[i + 3] / 255;
          int over(int c) => (c + 255 * (1 - a)).round().clamp(0, 255);
          sheet.setPixelRgb(
            x + ox,
            y,
            over(src[i]),
            over(src[i + 1]),
            over(src[i + 2]),
          );
        }
      }
    }
    final dir = Directory('build/brush-mixing')..createSync(recursive: true);
    File(
      '${dir.path}/watercolor_border.png',
    ).writeAsBytesSync(img.encodePng(sheet));
  });
}
