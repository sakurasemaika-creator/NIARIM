import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

const moonlitValleyWidth = 132;
const moonlitValleyHeight = 84;

/// Elements of the common artwork that can be edited on separate layers.
enum MoonlitValleyPart {
  scene,
  landscape,
  foreground,
  ridges,
  roughRidges,
  moonMask,
  lighting,
}

/// Renders Moonlit Valley as premultiplied RGBA. [scale] increases the
/// sampling resolution while keeping the composition and proportions.
Uint8List moonlitValleyPixels({
  MoonlitValleyPart part = MoonlitValleyPart.scene,
  int scale = 1,
}) {
  final art = _Raster(moonlitValleyWidth * scale, moonlitValleyHeight * scale);
  switch (part) {
    case MoonlitValleyPart.scene:
      _paintValley(art, scale);
      _paintMoonAndBirds(art, scale);
    case MoonlitValleyPart.landscape:
      _paintValley(art, scale);
    case MoonlitValleyPart.foreground:
      _paintMoonAndBirds(art, scale);
    case MoonlitValleyPart.ridges:
    case MoonlitValleyPart.roughRidges:
      // Fine, uneven strokes at the ridge intersections show what line-art
      // filters do while still using the original mountain silhouettes.
      final rough = part == MoonlitValleyPart.roughRidges;
      for (final (points, _) in _valleyRidges.take(2)) {
        for (final dy in rough ? [-.9, 0.0, .9] : [0.0]) {
          art.stroke(
            [
              for (final point in points)
                point.translate(0, dy) * scale.toDouble(),
            ],
            (rough ? 1.2 : 1.6) * scale,
            rough ? 0xB0342A3E : 0xFF342A3E,
          );
        }
      }
    case MoonlitValleyPart.moonMask:
      art.disc(_moonCenter * scale.toDouble(), 15.0 * scale, 0xFFFFFFFF);
    case MoonlitValleyPart.lighting:
      // The moon and the illuminated slopes overlap the base image. The
      // distant, midground and foreground slopes use different colors and
      // opacities, so the blend mode remains visible even in a small tile.
      const light = [0x9AC473B8, 0xE947AABD, 0xFFB95583, 0xFF191B30];
      for (final (i, (points, _)) in _valleyRidges.indexed) {
        art.fillBelow([
          for (final point in points) point * scale.toDouble(),
        ], light[i]);
      }
      _paintMoonAndBirds(art, scale);
  }
  return art.rgba;
}

const _moonCenter = Offset(93.8, 26.1);
const _moonRadius = 10.0;
const _moonlight = 0xFFFFE4A9;
const _moonShadow = 0xFF645274;

/// Moonlit Valley, traced from the unmarked reference at thumbnail width.
/// The extra height of the card continues the sky and foreground evenly.
void _paintValley(_Raster art, int scale) {
  for (var y = 0; y < art.height; y++) {
    final t = ((y / scale - 4.85) / 52).clamp(0.0, 1.0);
    final color = _lerpColor(0xFF232B50, 0xFFB17489, t);
    for (var x = 0; x < art.width; x++) {
      art.set(x, y, color);
    }
  }
  const starlight = 0xFFF7DCE5;
  for (final star in _brightStars) {
    art.disc(star * scale.toDouble(), .72 * scale, starlight);
  }
  for (final star in _smallStars) {
    art.disc(star * scale.toDouble(), .43 * scale, starlight);
  }
  for (final (points, color) in _valleyRidges) {
    art.fillBelow([
      for (final point in points) point * scale.toDouble(),
    ], color);
  }
}

void _paintMoonAndBirds(_Raster art, int scale) {
  final center = _moonCenter * scale.toDouble();
  final radius = _moonRadius * scale;
  final shadowCenter = _moonCenter.translate(3.9, -2.1) * scale.toDouble();
  final left = (center.dx - radius).floor();
  final right = (center.dx + radius).ceil();
  final top = (center.dy - radius).floor();
  final bottom = (center.dy + radius).ceil();
  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      final point = Offset(x + .5, y + .5);
      final diskCoverage = radius + .5 - (point - center).distance;
      final shadow = (9.15 * scale + .5 - (point - shadowCenter).distance)
          .clamp(0.0, 1.0);
      // Both colours share the same outer edge of the lunar disk.
      art._over(
        x,
        y,
        _lerpColor(_moonlight, _moonShadow, shadow),
        diskCoverage,
      );
    }
  }
  for (final bird in const [
    Offset(31.9, 53.6),
    Offset(35.3, 56.8),
    Offset(39.1, 52.8),
    Offset(44.2, 49.2),
  ]) {
    art.stroke(
      [
        bird.translate(-1.1, -.2) * scale.toDouble(),
        bird.translate(.2, .5) * scale.toDouble(),
        bird.translate(1.1, -.8) * scale.toDouble(),
      ],
      .55 * scale,
      _moonlight,
    );
  }
}

const _brightStars = [
  Offset(24.0, 6.4),
  Offset(122.2, 9.4),
  Offset(69.5, 13.2),
  Offset(36.4, 13.7),
  Offset(44.9, 15.8),
  Offset(77.5, 16.0),
  Offset(29.4, 18.1),
  Offset(66.9, 18.6),
  Offset(113.5, 23.8),
  Offset(51.9, 24.4),
  Offset(115.3, 28.9),
  Offset(130.3, 29.2),
  Offset(49.3, 34.1),
  Offset(74.9, 34.6),
  Offset(1.9, 35.0),
  Offset(68.6, 35.7),
  Offset(31.5, 39.3),
  Offset(27.7, 41.1),
  Offset(26.1, 43.2),
  Offset(9.6, 43.7),
];

const _smallStars = [
  Offset(48.3, 5.1),
  Offset(119.3, 6.1),
  Offset(96.8, 7.8),
  Offset(83.9, 8.9),
  Offset(11.8, 9.9),
  Offset(95.4, 10.9),
  Offset(69.0, 12.0),
  Offset(121.0, 12.5),
  Offset(22.5, 13.2),
  Offset(12.2, 13.9),
  Offset(59.0, 15.0),
  Offset(73.0, 17.2),
  Offset(18.6, 18.1),
  Offset(74.0, 18.6),
  Offset(115.3, 23.0),
  Offset(69.1, 23.0),
  Offset(65.8, 24.0),
  Offset(115.8, 24.9),
  Offset(35.9, 26.1),
  Offset(28.4, 26.3),
  Offset(108.7, 26.4),
  Offset(2.1, 30.3),
  Offset(120.3, 30.4),
  Offset(54.7, 30.4),
  Offset(52.6, 30.8),
  Offset(59.6, 30.8),
  Offset(25.8, 32.4),
  Offset(82.0, 32.5),
  Offset(17.8, 33.1),
  Offset(104.6, 33.9),
  Offset(113.4, 36.4),
  Offset(11.3, 39.3),
  Offset(64.8, 40.5),
  Offset(61.5, 40.9),
  Offset(5.9, 42.3),
  Offset(10.3, 42.3),
  Offset(28.0, 44.2),
];

const _valleyRidges = [
  (
    [
      Offset(0, 55.6),
      Offset(17.9, 41),
      Offset(28.2, 47),
      Offset(41.6, 32.7),
      Offset(59.6, 47.7),
      Offset(74, 38.3),
      Offset(90.3, 50.5),
      Offset(109.5, 33.6),
      Offset(132, 53),
    ],
    0xFF8D648A,
  ),
  (
    [
      Offset(0, 58.4),
      Offset(19.5, 49.6),
      Offset(32.2, 54.1),
      Offset(50.4, 44),
      Offset(69.1, 53),
      Offset(80.1, 47.7),
      Offset(104, 58),
      Offset(119.5, 49.4),
      Offset(132, 56.6),
    ],
    0xFF535074,
  ),
  (
    [
      Offset(0, 64.5),
      Offset(12.2, 60.8),
      Offset(32, 64.5),
      Offset(46.3, 53.1),
      Offset(59.2, 61.2),
      Offset(76.5, 57),
      Offset(88.3, 63.9),
      Offset(100.7, 58),
      Offset(132, 64.2),
    ],
    0xFF363754,
  ),
  (
    [
      Offset(0, 70.4),
      Offset(26.2, 72),
      Offset(45, 66.1),
      Offset(56.4, 68.9),
      Offset(75.4, 64),
      Offset(90.6, 70.4),
      Offset(117, 67.1),
      Offset(132, 70.8),
    ],
    0xFF232B45,
  ),
];

int _lerpColor(int a, int b, double t) {
  int ch(int shift) {
    final u = (a >> shift) & 0xFF, v = (b >> shift) & 0xFF;
    return (u + (v - u) * t).round().clamp(0, 255);
  }

  return ch(24) << 24 | ch(16) << 16 | ch(8) << 8 | ch(0);
}

/// A tiny anti-aliased rasteriser into premultiplied RGBA, so the samples
/// can be drawn inside the background isolate.
class _Raster {
  final int width, height;
  final Uint8List rgba;
  _Raster(this.width, this.height) : rgba = Uint8List(width * height * 4);

  void set(int x, int y, int color) => _over(x, y, color, 1);

  /// [color] (ARGB) over the pixel, [coverage] of it.
  void _over(int x, int y, int color, double coverage) {
    if (x < 0 || y < 0 || x >= width || y >= height || coverage <= 0) return;
    final a = ((color >> 24) & 0xFF) / 255 * coverage.clamp(0.0, 1.0);
    final i = (y * width + x) * 4;
    final keep = 1 - a;
    rgba[i] = (((color >> 16) & 0xFF) * a + rgba[i] * keep).round();
    rgba[i + 1] = (((color >> 8) & 0xFF) * a + rgba[i + 1] * keep).round();
    rgba[i + 2] = ((color & 0xFF) * a + rgba[i + 2] * keep).round();
    rgba[i + 3] = (255 * a + rgba[i + 3] * keep).round();
  }

  void disc(Offset c, double r, int color) {
    for (var y = (c.dy - r - 1).floor(); y <= (c.dy + r + 1).ceil(); y++) {
      for (var x = (c.dx - r - 1).floor(); x <= (c.dx + r + 1).ceil(); x++) {
        final d = (Offset(x + .5, y + .5) - c).distance;
        _over(x, y, color, r + .5 - d);
      }
    }
  }

  void stroke(List<Offset> points, double lineWidth, int color) {
    final half = lineWidth / 2;
    final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
    final x0 = (xs.reduce(math.min) - half - 1).floor();
    final x1 = (xs.reduce(math.max) + half + 1).ceil();
    final y0 = (ys.reduce(math.min) - half - 1).floor();
    final y1 = (ys.reduce(math.max) + half + 1).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final p = Offset(x + .5, y + .5);
        var d = double.infinity;
        for (var k = 0; k + 1 < points.length; k++) {
          d = math.min(d, _toSegment(p, points[k], points[k + 1]));
        }
        _over(x, y, color, half + .5 - d);
      }
    }
  }

  /// Fills below a left-to-right ridge spanning the raster. Four subpixel
  /// samples per column smooth the silhouette against the layer behind it.
  void fillBelow(List<Offset> ridge, int color) {
    var segment = 0;
    final edge = Float64List(4);
    for (var x = 0; x < width; x++) {
      for (var sample = 0; sample < edge.length; sample++) {
        final px = x + (sample + .5) / edge.length;
        while (px > ridge[segment + 1].dx) {
          segment++;
        }
        final a = ridge[segment], b = ridge[segment + 1];
        edge[sample] = a.dy + (b.dy - a.dy) * (px - a.dx) / (b.dx - a.dx);
      }
      final top = edge.reduce(math.min).floor();
      final bottom = edge.reduce(math.max).ceil();
      for (var y = top; y < bottom; y++) {
        var coverage = 0.0;
        for (final edgeY in edge) {
          coverage += (y + 1 - edgeY).clamp(0.0, 1.0);
        }
        _over(x, y, color, coverage / edge.length);
      }
      for (var y = bottom; y < height; y++) {
        set(x, y, color);
      }
    }
  }

  static double _toSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length = ab.distanceSquared;
    if (length == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }
}
