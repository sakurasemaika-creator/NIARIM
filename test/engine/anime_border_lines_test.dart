import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

const _w = 48, _h = 16;

/// Opaque columns: [left] for x < 24, [right] from 24 (straight RGB).
Uint8List _split(List<int> left, List<int> right) {
  final rgba = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      rgba.setAll((y * _w + x) * 4, [...(x < 24 ? left : right), 255]);
    }
  }
  return rgba;
}

List<int> _row(Uint8List rgba, int channel) => [
  for (var x = 0; x < _w; x++) rgba[(8 * _w + x) * 4 + channel],
];

/// アニメ風加工 draws border lines where colours change, instead of
/// thickening the drawing's lines: a line of the set width on the darker
/// side of every border between colours that differ by at least the
/// threshold, so line art keeps its width and gradients get none.
void main() {
  final engine = FilterEngine();
  Uint8List anime(
    Uint8List input, {
    double width = 2,
    double threshold = 20,
    double darkness = 1,
    int w = _w,
    int h = _h,
  }) => engine.applyAnimeStyle(
    input,
    w,
    h,
    strength: 100,
    colorCount: 32,
    edgeStrength: darkness,
    borderWidth: width,
    borderThreshold: threshold,
  );

  const skin = [248, 215, 164], purple = [120, 70, 150];

  test('a border between two colours: a line on the darker side', () {
    final before = _split(skin, purple);
    for (final width in [1.0, 2.0, 4.0]) {
      final out = anime(before, width: width);
      final g = _row(out, 1);
      // The skin side is untouched; the purple side is dark for [width] px
      // from the border at x = 24.
      for (var x = 0; x < 24; x++) {
        expect(g[x], closeTo(_row(anime(before, width: 0), 1)[x], 1));
      }
      for (var x = 24; x < 24 + width; x++) {
        expect(g[x], lessThan(20), reason: 'width $width: line at $x');
      }
      expect(
        g[24 + width.toInt() + 1],
        greaterThan(50),
        reason: 'width $width: past the line, purple again',
      );
    }
  });

  test('only where the colours differ by the threshold or more', () {
    // Two close shades of skin (ΔE about 4).
    final close = _split(skin, const [236, 202, 152]);
    final plain = anime(close, width: 0);
    expect(anime(close, threshold: 20), orderedEquals(plain));
    expect(anime(close, threshold: 2), isNot(orderedEquals(plain)));
    // A smooth ramp of grey has small steps only: no lines anywhere.
    final ramp = Uint8List(_w * _h * 4);
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final v = 40 + x * 4;
        ramp.setAll((y * _w + x) * 4, [v, v, v, 255]);
      }
    }
    expect(anime(ramp), orderedEquals(anime(ramp, width: 0)));
  });

  test('line art keeps its width, solid or anti-aliased', () {
    // A 3 px dark line on light paper, and the same with soft edges. The
    // border falls inside the line: the paper beside it is untouched, and
    // a soft edge stays soft (only its share of the line darkens) instead
    // of filling in.
    for (final soft in [false, true]) {
      final rgba = Uint8List(_w * _h * 4);
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          final v = x >= 20 && x <= 22
              ? 40
              : soft && (x == 19 || x == 23)
              ? 135
              : 230;
          rgba.setAll((y * _w + x) * 4, [v, v, v, 255]);
        }
      }
      final plain = _row(anime(rgba, width: 0), 1);
      for (final width in [1.0, 3.0, 6.0]) {
        final g = _row(anime(rgba, width: width), 1);
        final why = 'soft $soft, width $width';
        for (var x = 0; x < _w; x++) {
          if (x >= 20 && x <= 22) {
            expect(g[x], lessThanOrEqualTo(plain[x]), reason: '$why: line');
          } else if (soft && (x == 19 || x == 23)) {
            expect(g[x], greaterThan(100), reason: '$why: soft edge at $x');
          } else {
            expect(g[x], plain[x], reason: '$why: paper at $x');
          }
        }
      }
    }
  });

  test('a shape on a transparent layer gets a line just inside its edge', () {
    // Whatever its colour, white too.
    for (final colour in [
      skin,
      const [255, 255, 255],
    ]) {
      final rgba = Uint8List(_w * _h * 4);
      for (var y = 0; y < _h; y++) {
        for (var x = 10; x < 38; x++) {
          rgba.setAll((y * _w + x) * 4, [...colour, 255]);
        }
      }
      final out = anime(rgba, width: 2);
      final g = _row(out, 1), a = _row(out, 3);
      expect(g[10], lessThan(20), reason: '$colour: inside the left edge');
      expect(g[37], lessThan(20), reason: '$colour: inside the right edge');
      expect(g[24], greaterThan(150), reason: '$colour: the middle stays');
      expect(a[9], 0, reason: '$colour: outside stays transparent');
      expect(a[38], 0, reason: '$colour: outside stays transparent');
    }
  });

  test('the darkness sets how dark the line is', () {
    final before = _split(skin, purple);
    final half = _row(anime(before, darkness: .5), 1)[24];
    final full = _row(anime(before, darkness: 1), 1)[24];
    final none = _row(anime(before, width: 0), 1)[24];
    expect(full, lessThan(half));
    expect(half, lessThan(none));
  });

  test('the width and threshold are saved, restored and applied', () {
    const defaults = FilterDef(id: 'a', name: 'a', kind: FilterKind.animeStyle);
    expect(defaults.animeBorderWidth, 2);
    expect(defaults.animeBorderThreshold, 20);
    const filter = FilterDef(
      id: 'anime',
      name: 'Anime',
      kind: FilterKind.animeStyle,
      colorLevels: 32,
      edgeStrength: 1,
      animeBorderWidth: 3.5,
      animeBorderThreshold: 30,
    );
    final restored = FilterDef.fromJson(filter.toJson());
    expect(restored.animeBorderWidth, 3.5);
    expect(restored.animeBorderThreshold, 30);
    final before = _split(skin, purple);
    expect(
      applyDrawFilterInIsolate((before, _w, _h, filter, null)),
      orderedEquals(
        engine.applyAnimeStyle(
          before,
          _w,
          _h,
          strength: filter.strength,
          colorCount: 32,
          edgeStrength: 1,
          borderWidth: 3.5,
          borderThreshold: 30,
        ),
      ),
    );
  });

  test('sample sheet', () {
    // A face, for the eye: the before, and widths 0 / 1 / 2 / 4.
    const w = 96, h = 96;
    final face = Uint8List(w * h * 4);
    void disc(double cx, double cy, double r, List<int> c) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final dx = x + .5 - cx, dy = y + .5 - cy;
          if (dx * dx + dy * dy <= r * r) {
            face.setAll((y * w + x) * 4, [...c, 255]);
          }
        }
      }
    }

    disc(48, 56, 40, purple);
    disc(48, 40, 28, skin);
    disc(38, 40, 3, const [30, 40, 70]);
    disc(58, 40, 3, const [30, 40, 70]);
    disc(48, 52, 4, const [230, 110, 130]);
    final shots = [
      face,
      for (final width in [0.0, 1.0, 2.0, 4.0])
        anime(face, width: width, w: w, h: h),
    ];
    final sheet = img.Image(width: w * shots.length * 2, height: h * 2);
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (var k = 0; k < shots.length; k++) {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final a = shots[k][i + 3] / 255;
          int c(int ch) =>
              (shots[k][i + ch] + 255 * (1 - a)).round().clamp(0, 255);
          for (var s = 0; s < 4; s++) {
            sheet.setPixelRgb(
              (k * w + x) * 2 + s % 2,
              y * 2 + s ~/ 2,
              c(0),
              c(1),
              c(2),
            );
          }
        }
      }
    }
    final dir = Directory('build/anime-border')..createSync(recursive: true);
    File('${dir.path}/widths.png').writeAsBytesSync(img.encodePng(sheet));
  });
}
