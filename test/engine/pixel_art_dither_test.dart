import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

const _six = [
  0xFF000000,
  0xFFFFFFFF,
  0xFFFF0000,
  0xFFFFFF00,
  0xFF0000FF,
  0xFF00FF00,
];

final _engine = FilterEngine();

/// An opaque picture painted by [colour] at each pixel.
Uint8List _picture(int w, int h, (int, int, int) Function(int x, int y) at) {
  final data = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final (r, g, b) = at(x, y);
      final i = (y * w + x) * 4;
      data
        ..[i] = r
        ..[i + 1] = g
        ..[i + 2] = b
        ..[i + 3] = 255;
    }
  }
  return data;
}

Uint8List _pixelArt(
  Uint8List data,
  int w,
  int h, {
  int block = 4,
  PixelColorMode mode = PixelColorMode.explicit,
  List<int> palette = _six,
  int levels = 6,
  bool dither = true,
}) => _engine.applyPixelate(
  data,
  w,
  h,
  mosaicSize: block,
  colorMode: mode,
  colorLevels: levels,
  paletteColors: palette,
  dither: dither,
);

double _linear(int c) {
  final v = c / 255;
  return v <= 0.04045
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

/// CIELAB of a linear-light colour.
List<double> _lab(double r, double g, double b) {
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) => t > 216 / 24389
      ? math.pow(t, 1 / 3).toDouble()
      : (24389 / 27 * t + 16) / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// How different the picture looks from [original] over the square of
/// [size] px at ([x], [y]), seen from far enough that neighbouring dots blend
/// (their light averages): the CIELAB distance of the two averages.
double _seenDifference(
  Uint8List out,
  Uint8List original,
  int w,
  int x,
  int y,
  int size,
) {
  final a = [0.0, 0.0, 0.0], b = [0.0, 0.0, 0.0];
  for (var py = y; py < y + size; py++) {
    for (var px = x; px < x + size; px++) {
      final i = (py * w + px) * 4;
      for (var c = 0; c < 3; c++) {
        a[c] += _linear(out[i + c]);
        b[c] += _linear(original[i + c]);
      }
    }
  }
  final n = (size * size).toDouble();
  final la = _lab(a[0] / n, a[1] / n, a[2] / n);
  final lb = _lab(b[0] / n, b[1] / n, b[2] / n);
  return math.sqrt(
    math.pow(la[0] - lb[0], 2) +
        math.pow(la[1] - lb[1], 2) +
        math.pow(la[2] - lb[2], 2),
  );
}

Set<int> _colours(Uint8List out) => {
  for (var i = 0; i < out.length; i += 4)
    0xFF000000 | (out[i] << 16) | (out[i + 1] << 8) | out[i + 2],
};

/// The average difference over the picture, in squares of 4 x 4 dots.
double _meanSeen(Uint8List out, Uint8List original, int w, int h, int block) {
  final size = block * 4;
  var sum = 0.0, n = 0;
  for (var y = 0; y + size <= h; y += size) {
    for (var x = 0; x + size <= w; x += size) {
      sum += _seenDifference(out, original, w, x, y, size);
      n++;
    }
  }
  return sum / n;
}

/// ドット絵 with a limited set of colours: a dot no single colour of the set
/// comes close to mixes the two that look nearest side by side (ordered
/// dithering), so areas keep their colour instead of being filled with a
/// different one. With a set of colours chosen by count, the colours are the
/// ones the picture is mostly made of.
void main() {
  test('a grey ramp between black and white keeps its shades as a mix of the '
      'two', () {
    const w = 256, h = 32;
    final ramp = _picture(w, h, (x, _) => (x, x, x));
    const bw = [0xFF000000, 0xFFFFFFFF];
    final dithered = _pixelArt(ramp, w, h, palette: bw);
    final flat = _pixelArt(ramp, w, h, palette: bw, dither: false);

    expect(_colours(dithered), {0xFF000000, 0xFFFFFFFF});
    final mixed = _meanSeen(dithered, ramp, w, h, 4);
    final plain = _meanSeen(flat, ramp, w, h, 4);
    expect(mixed, lessThan(plain / 3), reason: 'mixed $mixed, flat $plain');
    // Mid greys seen from afar are close to the original (near either end,
    // where the original is close to black or white, a dot stays solid
    // rather than speckled).
    for (var x = 64; x + 16 <= 208; x += 16) {
      expect(
        _seenDifference(dithered, ramp, w, x, 0, 16),
        lessThan(6),
        reason: 'grey ${x + 8}',
      );
    }
    // The ends stay solid.
    expect(_colours(Uint8List.sublistView(dithered, 0, 4 * 4)), {0xFF000000});
  });

  test('orange with no orange in the set mixes red and yellow', () {
    const w = 64, h = 64;
    final orange = _picture(w, h, (_, _) => (255, 140, 0));
    final dithered = _pixelArt(orange, w, h);
    final flat = _pixelArt(orange, w, h, dither: false);
    expect(_colours(dithered), {0xFFFF0000, 0xFFFFFF00});
    final mixed = _meanSeen(dithered, orange, w, h, 4);
    final plain = _meanSeen(flat, orange, w, h, 4);
    expect(mixed, lessThan(8));
    expect(plain, greaterThan(mixed * 3));
  });

  test('a colour the set already matches stays one colour', () {
    const w = 32, h = 32;
    for (final (r, g, b) in const [
      (255, 0, 0),
      (245, 12, 10),
      (0, 0, 0),
      (25, 25, 25),
      (250, 250, 245),
      (10, 10, 240),
      (240, 250, 20),
    ]) {
      final out = _pixelArt(_picture(w, h, (_, _) => (r, g, b)), w, h);
      expect(_colours(out).length, 1, reason: '($r, $g, $b)');
    }
  });

  test('a colour count keeps the colour most of the picture is', () {
    // A face-coloured area with a dark outline and small bright accents.
    const w = 128, h = 128;
    final picture = _picture(w, h, (x, y) {
      if (x < 6 || y < 6 || x >= w - 6 || y >= h - 6) return (20, 20, 30);
      if (x < 30 && y < 30) return (230, 30, 40);
      if (x >= 98 && y < 30) return (30, 60, 220);
      if (x < 30 && y >= 98) return (40, 200, 60);
      if (x >= 98 && y >= 98) return (250, 230, 40);
      return (240, 200, 170);
    });
    for (final dither in [false, true]) {
      final out = _pixelArt(
        picture,
        w,
        h,
        mode: PixelColorMode.count,
        palette: const [],
        levels: 6,
        dither: dither,
      );
      expect(_colours(out).length, lessThanOrEqualTo(6));
      // The face area: its own colour, solid.
      expect(
        _seenDifference(out, picture, w, 48, 48, 32),
        lessThan(3),
        reason: dither ? 'dithered' : 'flat',
      );
      expect(
        _colours(Uint8List.sublistView(out, (48 * w) * 4, (49 * w) * 4)).length,
        lessThanOrEqualTo(2),
      );
    }
  });

  test('a hard edge stays clean: each side keeps its own mix up to it', () {
    // An orange disc on a light blue ground: neither colour is in the set,
    // so both are mixed (red and yellow, blue and white).
    const w = 160, h = 160;
    const red = 0xFFFF0000, yellow = 0xFFFFFF00;
    const blue = 0xFF0000FF, white = 0xFFFFFFFF;
    bool inDisc(num x, num y) =>
        (x - 80) * (x - 80) + (y - 80) * (y - 80) < 50 * 50;
    final picture = _picture(
      w,
      h,
      (x, y) => inDisc(x + .5, y + .5) ? (255, 140, 0) : (120, 150, 245),
    );
    final out = _pixelArt(picture, w, h);
    for (var y = 0; y < h; y += 4) {
      for (var x = 0; x < w; x += 4) {
        final i = (y * w + x) * 4;
        final colour =
            0xFF000000 | (out[i] << 16) | (out[i + 1] << 8) | out[i + 2];
        // The dot's middle, and whether all of it is on one side.
        final inside = [
          for (final (dx, dy) in const [(0, 0), (4, 0), (0, 4), (4, 4)])
            inDisc(x + dx, y + dy),
        ];
        if (inside.every((v) => v)) {
          expect([red, yellow], contains(colour), reason: 'disc ($x, $y)');
        } else if (inside.every((v) => !v)) {
          expect([blue, white], contains(colour), reason: 'ground ($x, $y)');
        } else {
          // Across the edge: one side's colours, never a third.
          expect(
            [red, yellow, blue, white],
            contains(colour),
            reason: 'edge ($x, $y)',
          );
        }
      }
    }
    // Both are really mixed.
    expect(_colours(out), {red, yellow, blue, white});
  });

  test('the pattern stays put between animation frames', () {
    // The same grey area in two frames; a red square moves beside it.
    const w = 96, h = 64;
    Uint8List frame(int squareX) => _picture(w, h, (x, y) {
      if (x >= squareX && x < squareX + 16 && y >= 24 && y < 40) {
        return (230, 30, 40);
      }
      return x < 48 ? (128, 128, 128) : (255, 255, 255);
    });
    final a = _pixelArt(frame(56), w, h);
    final b = _pixelArt(frame(72), w, h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < 48; x++) {
        final i = (y * w + x) * 4;
        expect(b.sublist(i, i + 4), a.sublist(i, i + 4), reason: '($x, $y)');
      }
    }
  });

  test('the brush pixel mode still snaps each pixel to one colour', () {
    final grey = _picture(16, 1, (_, _) => (128, 128, 128));
    final out = quantizeColors(
      grey,
      colorMode: PixelColorMode.explicit,
      paletteColors: const [0xFF000000, 0xFFFFFFFF],
    );
    expect(_colours(out).length, 1);
  });

  test('sample sheet', () {
    // A sky-to-ground picture with a sun and a face: original, flat, and
    // dithered, with six chosen colours and with a count of six.
    const w = 240, h = 160;
    final picture = _picture(w, h, (x, y) {
      final dx = x - 70, dy = y - 80;
      if (dx * dx + dy * dy < 40 * 40) {
        final d = math.sqrt((dx * dx + dy * dy).toDouble()) / 40;
        return (
          (245 - 30 * d).round(),
          (205 - 40 * d).round(),
          (175 - 40 * d).round(),
        );
      }
      final sx = x - 190, sy = y - 40;
      if (sx * sx + sy * sy < 22 * 22) return (255, 170, 30);
      if (y > 110) {
        final t = (y - 110) / 50;
        return ((90 - 40 * t).round(), (160 - 60 * t).round(), 70);
      }
      final t = y / 110;
      return ((40 + 150 * t).round(), (90 + 120 * t).round(), 230);
    });
    final cases = [
      ('original', picture),
      (
        'flat, 6 colours',
        _pixelArt(picture, w, h, palette: _six, dither: false),
      ),
      ('dithered, 6 colours', _pixelArt(picture, w, h, palette: _six)),
      (
        'flat, count 6',
        _pixelArt(
          picture,
          w,
          h,
          mode: PixelColorMode.count,
          palette: const [],
          dither: false,
        ),
      ),
      (
        'dithered, count 6',
        _pixelArt(picture, w, h, mode: PixelColorMode.count, palette: const []),
      ),
    ];
    const scale = 2, gap = 10, top = 30;
    final sheet = img.Image(
      width: 3 * (w * scale + gap),
      height: 2 * (h * scale + top + gap),
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    final ink = img.ColorRgb8(37, 48, 71);
    final slots = [(0, 0), (1, 0), (2, 0), (1, 1), (2, 1)];
    for (var k = 0; k < cases.length; k++) {
      final (label, data) = cases[k];
      final (col, row) = slots[k];
      final ox = col * (w * scale + gap), oy = row * (h * scale + top + gap);
      img.drawString(
        sheet,
        label,
        font: img.arial24,
        x: ox + 4,
        y: oy + 2,
        color: ink,
      );
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          for (var sy = 0; sy < scale; sy++) {
            for (var sx = 0; sx < scale; sx++) {
              sheet.setPixelRgb(
                ox + x * scale + sx,
                oy + top + y * scale + sy,
                data[i],
                data[i + 1],
                data[i + 2],
              );
            }
          }
        }
      }
    }
    final dir = Directory('build/pixel-art-dither')
      ..createSync(recursive: true);
    File('${dir.path}/compare.png').writeAsBytesSync(img.encodePng(sheet));
  });
}
