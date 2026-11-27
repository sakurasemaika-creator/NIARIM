import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/pixel_art_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

/// 塗った面の絵（乗算済みRGBA）。縁はアンチエイリアス。
class _Picture {
  _Picture(this.w, this.h, {bool paper = true}) : data = Uint8List(w * h * 4) {
    if (!paper) return;
    data.fillRange(0, data.length, 255);
  }

  final int w, h;
  final Uint8List data;

  void paint(bool Function(double x, double y) inside, (int, int, int) rgb) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var hits = 0;
        for (var sy = 0; sy < 4; sy++) {
          for (var sx = 0; sx < 4; sx++) {
            if (inside(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4)) hits++;
          }
        }
        if (hits == 0) continue;
        final cover = hits / 16, keep = 1 - cover;
        final i = (y * w + x) * 4;
        data[i] = (rgb.$1 * cover + data[i] * keep).round();
        data[i + 1] = (rgb.$2 * cover + data[i + 1] * keep).round();
        data[i + 2] = (rgb.$3 * cover + data[i + 2] * keep).round();
        data[i + 3] = (255 * cover + data[i + 3] * keep).round();
      }
    }
  }
}

/// 肌・髪・シャツ・シャツの影の面と、なめらかな空のグラデーション。
_Picture _scene({required bool paper}) {
  final p = _Picture(160, 160, paper: paper);
  bool disc(double x, double y, double cx, double cy, double r) =>
      (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;
  p.paint((x, y) => y > 128 && (x - 80).abs() < 30 + (y - 128) * 0.9, (
    131,
    170,
    203,
  ));
  p.paint((x, y) => y > 128 && x > 92 && (x - 80) < 30 + (y - 128) * 0.9, (
    97,
    136,
    174,
  ));
  p.paint((x, y) => disc(x, y, 80, 82, 46), (249, 223, 203));
  p.paint((x, y) => disc(x, y, 80, 76, 50) && y < 62 + 6 * math.sin(x / 7), (
    122,
    81,
    61,
  ));
  return p;
}

(double, double, double) _lab(double r, double g, double b) {
  double lin(double c) {
    c /= 255;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final lr = lin(r), lg = lin(g), lb = lin(b);
  final x = (0.4124 * lr + 0.3576 * lg + 0.1805 * lb) / 0.95047;
  final y = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb;
  final z = (0.0193 * lr + 0.1192 * lg + 0.9505 * lb) / 1.08883;
  double f(double t) => t > 216 / 24389
      ? math.pow(t, 1 / 3).toDouble()
      : (24389 / 27 * t + 16) / 116;
  return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)));
}

/// 各ドットの色と、そのドットの画素（不透明度が半分以上の画素があれば
/// それだけ）の色のうち最も近いものとのΔE（CIELAB）の最大。
double _worstDistance(_Picture p, Uint8List out, double size) {
  final xs = PixelArtEngine.cellEdges(p.w, size);
  final ys = PixelArtEngine.cellEdges(p.h, size);
  var worst = 0.0;
  for (var cy = 0; cy + 1 < ys.length; cy++) {
    for (var cx = 0; cx + 1 < xs.length; cx++) {
      final o = (ys[cy] * p.w + xs[cx]) * 4;
      final a = out[o + 3];
      if (a == 0) continue;
      final dot = _lab(
        out[o] * 255 / a,
        out[o + 1] * 255 / a,
        out[o + 2] * 255 / a,
      );
      var opaque = false;
      for (var y = ys[cy]; y < ys[cy + 1]; y++) {
        for (var x = xs[cx]; x < xs[cx + 1]; x++) {
          if (p.data[(y * p.w + x) * 4 + 3] >= 128) opaque = true;
        }
      }
      var best = double.infinity;
      for (var y = ys[cy]; y < ys[cy + 1]; y++) {
        for (var x = xs[cx]; x < xs[cx + 1]; x++) {
          final i = (y * p.w + x) * 4;
          final pa = p.data[i + 3];
          if (pa == 0 || (opaque && pa < 128)) continue;
          final c = _lab(
            p.data[i] * 255 / pa,
            p.data[i + 1] * 255 / pa,
            p.data[i + 2] * 255 / pa,
          );
          final d = math.sqrt(
            (c.$1 - dot.$1) * (c.$1 - dot.$1) +
                (c.$2 - dot.$2) * (c.$2 - dot.$2) +
                (c.$3 - dot.$3) * (c.$3 - dot.$3),
          );
          best = math.min(best, d);
        }
      }
      worst = math.max(worst, best);
    }
  }
  return worst;
}

void main() {
  const engine = PixelArtEngine();

  // 色を指定しない（元の色のまま）では、ドットの色はそのドットの画素に
  // 実際にある色（2つの面にまたがるドットを、絵に無い中間の色にしない）。
  for (final paper in [true, false]) {
    for (final size in [5.3, 8.0, 10.0, 16.0]) {
      test('colours as they are (${paper ? 'paper' : 'transparent layer'}, '
          'dot $size): every dot takes a colour its own paint has', () {
        final p = _scene(paper: paper);
        final out = engine.convert(
          p.data,
          p.w,
          p.h,
          pixelSize: size,
          colorMode: PixelColorMode.none,
        );
        expect(_worstDistance(p, out, size), lessThan(2.0));
      });
    }
  }

  test('colours as they are: a cell straddling hair and paper takes one of '
      'them, not grey', () {
    final p = _Picture(64, 64);
    // 左半分が髪、右半分が紙。境目はドットの真ん中。
    p.paint((x, y) => x < 28, (122, 81, 61));
    final out = engine.convert(
      p.data,
      64,
      64,
      pixelSize: 8,
      colorMode: PixelColorMode.none,
    );
    for (var y = 0; y < 64; y += 8) {
      final i = (y * 64 + 24) * 4;
      final colour = (out[i], out[i + 1], out[i + 2]);
      expect([(122, 81, 61), (255, 255, 255)], contains(colour));
    }
  });
}
