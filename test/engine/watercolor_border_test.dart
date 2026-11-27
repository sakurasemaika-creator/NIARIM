// 水彩境界フィルター（applyWatercolorBorder）：塗った所の縁にだけ色が溜まって
// 濃くなり、縁より内側は1画素も変えない（所有者の判断、2026-11-27「透けさせる
// のはブラシ側でやるので水彩境界では透けさせないでそのままにして名前の通り縁の
// 境界だけに色が溜まるように描画追加するだけ」）。色の境目にも縁が付く（切れば
// αの縁だけ）。範囲・縁の濃さの効き方。以前の「透明度の影響」は保存に残るが
// 効かない。見本は build/brush-mixing/watercolor_border.png。
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

/// The pixels of a disc of radius 40 at (60, 60) further than [depth] in
/// from its edge (byte offsets of their red).
Iterable<int> _deepInside(double depth) sync* {
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final d = math.sqrt(
        math.pow(x - 60 + 0.5, 2) + math.pow(y - 60 + 0.5, 2),
      );
      if (d < 40 - depth) yield (y * _size + x) * 4;
    }
  }
}

Uint8List _apply(
  Uint8List data, {
  double range = 10,
  double darken = 40,
  double blur = 2,
  bool colorEdges = true,
}) => applyWatercolorBorder(
  data,
  _size,
  _size,
  range: range,
  darkenEffect: darken,
  blur: blur,
  colorEdges: colorEdges,
);

void main() {
  const colours = [0xF5C518, 0xD93030, 0x2E4BD8, 0x2B2D42, 0xF2B8C6, 0x3A7BD5];

  test('only the rim changes: beyond it every pixel is as painted', () {
    for (final rgb in colours) {
      final input = _disc(rgb);
      final out = _apply(input);
      // Beyond the rim's reach (10px, softened by 2px) nothing changes, not
      // even by a level: the inside is neither lighter nor see-through.
      for (final i in _deepInside(10 + 2 * 3 + 1)) {
        expect(
          out.sublist(i, i + 4),
          input.sublist(i, i + 4),
          reason: '${rgb.toRadixString(16)} at ${i ~/ 4}',
        );
      }
      // The rim is deeper than the paint and than the inside.
      expect(
        _darkestAtEdge(out),
        lessThan(_darkestAtEdge(input) - 2),
        reason: rgb.toRadixString(16),
      );
      expect(
        _darkestAtEdge(out),
        lessThan(_onWhite(out, 60, 60) - 2),
        reason: rgb.toRadixString(16),
      );
    }
    // A crisp darker line right at the edge (the disc's edge is at x 20).
    final blue = _apply(_disc(0x3A7BD5));
    expect(_darkestAtEdge(blue), lessThan(_onWhite(blue, 60, 60) - 30));
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
    final narrow = _apply(_disc(0x3A7BD5), range: 4);
    final wide = _apply(_disc(0x3A7BD5), range: 25);
    // 6px inside the edge only the wide rim still darkens.
    expect(_onWhite(wide, 26, 60), lessThan(_onWhite(narrow, 26, 60) - 6));
    expect(
      _onWhite(narrow, 26, 60),
      closeTo(_onWhite(_disc(0x3A7BD5), 26, 60), 3),
    );

    final none = _apply(_disc(0x3A7BD5), darken: 0);
    expect(none, _disc(0x3A7BD5));
  });

  test('縁の濃さ deepens the rim and keeps every pixel opaque', () {
    final dark = _apply(_disc(0x3A7BD5), darken: 100);
    final centre = (60 * _size + 60) * 4;
    expect(dark[centre + 3], 255);
    expect(_darkestAtEdge(dark), lessThan(_onWhite(dark, 60, 60) - 30));
    expect(
      _darkestAtEdge(dark),
      lessThan(_darkestAtEdge(_apply(_disc(0x3A7BD5))) - 5),
    );
  });

  test('a pale wash is left as pale inside; its rim turns denser', () {
    // A wash at a third of full alpha: the brush made it see-through, and
    // the filter keeps it so.
    final input = _disc(0x2E4BD8);
    for (var i = 0; i < input.length; i += 4) {
      for (var c = 0; c < 4; c++) {
        input[i + c] = input[i + c] ~/ 3;
      }
    }
    final out = _apply(input);
    for (final i in _deepInside(17)) {
      expect(out.sublist(i, i + 4), input.sublist(i, i + 4));
    }
    final rim = (60 * _size + 21) * 4;
    expect(out[rim + 3], greaterThan(input[rim + 3]));
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
      _apply(source, range: 12, darken: 70, blur: 3, colorEdges: false),
    );
  });

  test('the saved 透明度の影響 changes nothing, and old saves load', () {
    // A filter saved when 透明度の影響 made the inside see-through.
    final saved = FilterDef.fromJson({
      ...FilterService.builtInFilters
          .singleWhere((f) => f.id == FilterService.watercolorBorderFilterId)
          .toJson(),
      'watercolorBorderOpacity': 100,
    });
    expect(saved.watercolorBorderOpacity, 100);
    // Kept as it was when saved again.
    expect(saved.toJson()['watercolorBorderOpacity'], 100);
    final source = _disc(0x2E4BD8);
    Uint8List draw(FilterDef f) =>
        applyDrawFilterInIsolate((source, _size, _size, f, null));
    expect(draw(saved), draw(saved.copyWith(watercolorBorderOpacity: 0)));
    expect(draw(saved), _apply(source));

    // The same for the effect filter's param3.
    Uint8List effect(double param3) =>
        FilterEngine().applyEffectFilters(source, _size, _size, [
          EffectFilterInstance(
            id: 'e',
            type: EffectFilterType.watercolorBorder,
            startFrame: 0,
            endFrame: 0,
            param1: 10,
            param2: 40,
            param3: param3,
            param4: 2,
            param5: 1,
          ),
        ], 0);
    expect(effect(100), effect(0));
    expect(effect(45), _apply(source));
  });

  test('as an effect filter on an opaque frame, only the rim changes', () {
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
    // The paper stays white, the inside as painted, and the rim deeper.
    expect(out.sublist(0, 4), [255, 255, 255, 255]);
    for (final i in _deepInside(17)) {
      expect(out.sublist(i, i + 4), frame.sublist(i, i + 4));
    }
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
    final out = applyWatercolorBorder(data, w, h, range: 10, darkenEffect: 40);
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
