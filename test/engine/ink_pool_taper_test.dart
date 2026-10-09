import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';

/// Black line art on a transparent layer, as round-capped strokes.
class _Art {
  _Art(this.width, this.height) : rgba = Uint8List(width * height * 4);

  final int width, height;
  final Uint8List rgba;

  /// Round-capped strokes; [soft] ones have anti-aliased edges, as a 1 px
  /// pen draws them.
  void stroke(
    List<(double, double)> points,
    double thickness, {
    bool soft = false,
  }) {
    final half = thickness / 2;
    for (var k = 0; k + 1 < points.length; k++) {
      final (ax, ay) = points[k];
      final (bx, by) = points[k + 1];
      final minX = math.max(0, (math.min(ax, bx) - half - 1).floor());
      final maxX = math.min(width - 1, (math.max(ax, bx) + half + 1).ceil());
      final minY = math.max(0, (math.min(ay, by) - half - 1).floor());
      final maxY = math.min(height - 1, (math.max(ay, by) + half + 1).ceil());
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          final px = x + .5, py = y + .5;
          final dx = bx - ax, dy = by - ay;
          final len2 = dx * dx + dy * dy;
          final t = len2 == 0
              ? 0.0
              : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
          final ex = px - (ax + dx * t), ey = py - (ay + dy * t);
          final i = (y * width + x) * 4;
          if (soft) {
            final cover = (half + .5 - math.sqrt(ex * ex + ey * ey)).clamp(
              0.0,
              1.0,
            );
            final a = (cover * 255).round();
            if (a > rgba[i + 3]) {
              rgba[i] = rgba[i + 1] = rgba[i + 2] = 0;
              rgba[i + 3] = a;
            }
          } else if (ex * ex + ey * ey <= half * half) {
            rgba[i] = rgba[i + 1] = rgba[i + 2] = 0;
            rgba[i + 3] = 255;
          }
        }
      }
    }
  }

  void ring(
    double cx,
    double cy,
    double r,
    double thickness, {
    bool soft = false,
  }) => stroke(
    [
      for (var a = 0.0; a <= 2 * math.pi + .02; a += .02)
        (cx + r * math.cos(a), cy + r * math.sin(a)),
    ],
    thickness,
    soft: soft,
  );

  /// A straight line through ([x], [y]) at [degrees] (screen angle: 0 is
  /// to the right, 90 down), [length] px each way.
  void lineThrough(
    double x,
    double y,
    double degrees,
    double length,
    double thickness, {
    bool soft = false,
  }) {
    final a = degrees * math.pi / 180;
    final dx = math.cos(a) * length, dy = math.sin(a) * length;
    stroke([(x - dx, y - dy), (x + dx, y + dy)], thickness, soft: soft);
  }
}

const _black = 0xFF000000;
final _engine = FilterEngine();

Uint8List _pool(
  _Art art, {
  double range = 30,
  double width = 10,
  int color = _black,
}) => _engine.applyInkPoolLayer(
  art.rgba,
  art.width,
  art.height,
  color: color,
  rangePx: range,
  centerWidthPx: width,
);

/// The pool's coverage summed down column [x] from row [fromY] to [toY].
double _column(_Art art, Uint8List pool, int x, int fromY, int toY) {
  var sum = 0.0;
  for (var y = fromY; y <= toY; y++) {
    sum += pool[(y * art.width + x) * 4 + 3] / 255;
  }
  return sum;
}

/// The pool's coverage summed along row [y] from column [fromX] to [toX].
double _row(_Art art, Uint8List pool, int y, int fromX, int toX) {
  var sum = 0.0;
  for (var x = fromX; x <= toX; x++) {
    sum += pool[(y * art.width + x) * 4 + 3] / 255;
  }
  return sum;
}

/// The pool's coverage summed over a disc of [radius] round ([x], [y]); with
/// [visible], only what the line art over it leaves showing.
double _around(
  _Art art,
  Uint8List pool,
  double x,
  double y,
  double radius, {
  bool visible = false,
}) {
  var sum = 0.0;
  for (var py = (y - radius).floor(); py <= (y + radius).ceil(); py++) {
    for (var px = (x - radius).floor(); px <= (x + radius).ceil(); px++) {
      if (px < 0 || py < 0 || px >= art.width || py >= art.height) continue;
      final dx = px + .5 - x, dy = py + .5 - y;
      if (dx * dx + dy * dy > radius * radius) continue;
      final i = (py * art.width + px) * 4 + 3;
      sum += pool[i] / 255 * (visible ? 1 - art.rgba[i] / 255 : 1);
    }
  }
  return sum;
}

double _total(Uint8List pool) {
  var sum = 0.0;
  for (var i = 3; i < pool.length; i += 4) {
    sum += pool[i] / 255;
  }
  return sum;
}

/// Three panels: the pool alone (red), the pool (red) under the line art,
/// and how it really looks: the pool in the line's own black under it.
void _write(String name, _Art art, Uint8List pool) {
  const scale = 3;
  const gap = 12;
  final w = art.width, h = art.height;
  final image = img.Image(
    width: (w * scale + gap) * 3 - gap,
    height: h * scale,
  );
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final line = art.rgba[i + 3] / 255;
      final a = pool[i + 3] / 255;
      final red = (
        (255 - 55 * a).round(),
        (255 - 255 * a).round(),
        (255 - 255 * a).round(),
      );
      int over(int c, double ink) => (c * (1 - ink) + 20 * ink).round();
      final ink = math.min(1.0, line + a * (1 - line));
      final panels = [
        red,
        (over(red.$1, line), over(red.$2, line), over(red.$3, line)),
        (over(255, ink), over(255, ink), over(255, ink)),
      ];
      for (var p = 0; p < 3; p++) {
        final (r, g, b) = panels[p];
        for (var sy = 0; sy < scale; sy++) {
          for (var sx = 0; sx < scale; sx++) {
            image.setPixelRgb(
              p * (w * scale + gap) + x * scale + sx,
              y * scale + sy,
              r,
              g,
              b,
            );
          }
        }
      }
    }
  }
  final dir = Directory('build/ink-pool')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(img.encodePng(image));
}

/// Five rings in the Olympic layout (line centre radius 34) with lines
/// [thickness] px wide, under the filter's own defaults (range 12, centre
/// width 6): every crossing pools in its two narrow angles and nowhere else.
void _olympicRings(double thickness) {
  const r = 34.0;
  const centres = [
    (60.0, 54.0),
    (143.0, 54.0),
    (226.0, 54.0),
    (101.5, 89.0),
    (184.5, 89.0),
  ];
  final art = _Art(290, 150);
  for (final (x, y) in centres) {
    art.ring(x, y, r, thickness, soft: thickness < 2);
  }
  // The filter's own defaults: range 12, centre width 6.
  final pool = _pool(art, range: 12, width: 6);
  _write(thickness < 2 ? 'olympic_rings_1px' : 'olympic_rings', art, pool);

  (double, double) unit((double, double) v) {
    final l = math.sqrt(v.$1 * v.$1 + v.$2 * v.$2);
    return (v.$1 / l, v.$2 / l);
  }

  var narrow = 0, crossings = 0;
  for (var i = 0; i < centres.length; i++) {
    for (var j = i + 1; j < centres.length; j++) {
      final (ax, ay) = centres[i];
      final (bx, by) = centres[j];
      final dx = bx - ax, dy = by - ay;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d >= 2 * r) continue;
      final h = math.sqrt(r * r - d * d / 4);
      for (final s in [-1.0, 1.0]) {
        crossings++;
        final px = ax + dx / 2 - s * h * dy / d;
        final py = ay + dy / 2 + s * h * dx / d;
        // The rings' directions there, and the middles of the angles
        // between them.
        final t1 = (-(py - ay) / r, (px - ax) / r);
        final t2 = (-(py - by) / r, (px - bx) / r);
        final dot = t1.$1 * t2.$1 + t1.$2 * t2.$2;
        final angle = math.acos(dot.abs());
        expect(angle, lessThan(80 * math.pi / 180));
        final acute = unit(
          dot > 0
              ? (t1.$1 + t2.$1, t1.$2 + t2.$2)
              : (t1.$1 - t2.$1, t1.$2 - t2.$2),
        );
        final wide = unit(
          dot > 0
              ? (t1.$1 - t2.$1, t1.$2 - t2.$2)
              : (t1.$1 + t2.$1, t1.$2 + t2.$2),
        );
        // Points inside each angle, clear of the lines' edges.
        final inAcute = (thickness / 2 + 2.5) / math.sin(angle / 2);
        final inWide = (thickness / 2 + 3) / math.sin((math.pi - angle) / 2);
        for (final k in [-1.0, 1.0]) {
          final ink = _around(
            art,
            pool,
            px + k * acute.$1 * inAcute,
            py + k * acute.$2 * inAcute,
            1.5,
          );
          if (ink > 2) narrow++;
          expect(
            ink,
            greaterThan(2),
            reason: 'narrow angle at (${px.round()}, ${py.round()})',
          );
          expect(
            _around(
              art,
              pool,
              px + k * wide.$1 * inWide,
              py + k * wide.$2 * inWide,
              2,
              visible: true,
            ),
            lessThan(.3),
            reason: 'wide angle at (${px.round()}, ${py.round()})',
          );
        }
      }
    }
  }
  expect(crossings, 8);
  expect(narrow, 16);
  // Away from the crossings the rings get none: along the top of each
  // ring and the bottom of the lower ones.
  for (final (x, y) in centres) {
    expect(_around(art, pool, x, y - r + 6, 4), 0);
  }
  for (final (x, y) in centres.skip(3)) {
    expect(_around(art, pool, x, y + r - 6, 4), 0);
  }
}

/// 墨溜まり: ink pools only inside acute and right angles, where lines meet
/// at a right angle or sharper (a V, a fork, the narrow side of a crossing, a
/// T, a square corner), never inside a wider one. At the meeting point
/// the pool shows the set width beyond the line's edge; along each line it
/// thins in a straight slope ("like a slide") to 1 px at the end of the
/// range, and nothing beyond, whether the line is thin or thick. It works on
/// curved lines crossing each other too (the Olympic rings).
void main() {
  test('in a 40 degree crossing: the narrow angles slope from the set width '
      'to 1 px, the wide angles stay clear', () {
    final art = _Art(220, 160)
      ..stroke([(20, 80), (200, 80)], 3)
      // Up to the right at 40 degrees, through (110, 80).
      ..lineThrough(110, 80, -40, 80, 3);
    const range = 30.0, width = 10.0;
    final pool = _pool(art, range: range, width: width);
    _write('crossing_40', art, pool);

    // The bar covers rows 78 to 81. The narrow angles are above the bar to
    // the right of the crossing and below it to the left. From 21 px out,
    // the slanted line's own pool has left the rows next to the bar.
    for (final d in [21, 24, 27]) {
      final expected = 1 + (width - 1) * (1 - d / range);
      expect(
        _column(art, pool, 110 + d, 71, 77),
        closeTo(expected, 1.5),
        reason: 'above the bar $d px to the right',
      );
      expect(
        _column(art, pool, 110 - d, 82, 88),
        closeTo(expected, 1.5),
        reason: 'below the bar $d px to the left',
      );
      // The wide angles: below the bar to the right, above it to the left.
      expect(_column(art, pool, 110 + d, 82, 110), 0, reason: 'wide, right');
      expect(_column(art, pool, 110 - d, 40, 77), 0, reason: 'wide, left');
    }
    // It keeps getting thinner: a slope, not a blob.
    final profile = [
      for (var d = 20; d <= 28; d += 2) _column(art, pool, 110 + d, 71, 77),
    ];
    for (var k = 1; k < profile.length; k++) {
      expect(profile[k], lessThanOrEqualTo(profile[k - 1] + .3));
    }
    // Beyond the range, nothing.
    expect(_column(art, pool, 110 + 34, 40, 120), 0);
    expect(_column(art, pool, 110 - 34, 40, 120), 0);
    // Under the line art it reaches back to the line's centre (the bar's
    // upper half is rows 78 and 79), so no gap shows along the line's edge.
    expect(_column(art, pool, 110 + 21, 78, 79), greaterThan(1.5));
  });

  test('a right angle pools too: a T on both sides of its stem, a square '
      'corner inside it, at any rotation, thin or thick; a wider angle does '
      'not', () {
    const range = 30.0, width = 10.0;
    for (final thickness in [3.0, 8.0]) {
      // The bar runs along row 50, the stem down column 85.
      final t = _Art(200, 160)
        ..stroke([(20, 50), (150, 50)], thickness)
        ..stroke([(85, 50), (85, 150)], thickness);
      final pool = _pool(t, range: range, width: width);
      _write(thickness == 8 ? 't_junction_thick' : 't_junction', t, pool);
      // The lines' pixels: rows and columns 50 - e to 49 + e (85 - e to
      // 84 + e).
      final e = (thickness / 2 + .5).floor();
      for (final d in [16, 20, 24, 28]) {
        final expected = 1 + (width - 1) * (1 - d / range);
        for (final side in [-1, 1]) {
          // Below the bar, on both sides of the stem.
          expect(
            _column(t, pool, 85 + side * d, 50 + e, 50 + e + 12),
            closeTo(expected, 1.5),
            reason:
                'below the bar, $d px ${side < 0 ? 'left' : 'right'} '
                '($thickness px lines)',
          );
          // Beside the stem, on both sides.
          expect(
            _row(
              t,
              pool,
              50 + d,
              side < 0 ? 85 - e - 13 : 85 + e,
              side < 0 ? 85 - e - 1 : 85 + e + 12,
            ),
            closeTo(expected, 1.5),
            reason:
                'beside the stem, $d px down, '
                '${side < 0 ? 'left' : 'right'} ($thickness px lines)',
          );
        }
      }
      // Above the bar, the straight side: none.
      expect(_around(t, pool, 85, 50.0 - e - 4, 4), 0);
      for (var x = 20; x < 150; x++) {
        expect(_column(t, pool, x, 0, 49 - e), 0, reason: 'above the bar');
      }
      // Beyond the range, none.
      expect(_column(t, pool, 85 + 34, 0, 159), 0);
      expect(_row(t, pool, 50 + 34, 0, 199), 0);
    }

    // A square corner: inside it only.
    final corner = _Art(200, 160)..stroke([(30, 30), (150, 30), (150, 140)], 3);
    final cornerPool = _pool(corner, range: range, width: width);
    _write('square_corner', corner, cornerPool);
    expect(_around(corner, cornerPool, 140, 37, 2), greaterThan(4));
    expect(_column(corner, cornerPool, 130, 32, 44), closeTo(1 + 9 / 3, 1.5));
    expect(_row(corner, cornerPool, 50, 136, 147), closeTo(1 + 9 / 3, 1.5));
    expect(_around(corner, cornerPool, 140, 22, 4), 0, reason: 'above');
    expect(_around(corner, cornerPool, 158, 40, 4), 0, reason: 'right');
    expect(_around(corner, cornerPool, 158, 22, 4), 0, reason: 'outside');

    // Turned: still both sides of the stem, never across the bar.
    for (var degrees = 5; degrees < 90; degrees += 10) {
      final a = degrees * math.pi / 180;
      const cx = 100.0, cy = 80.0;
      final ux = math.cos(a), uy = math.sin(a);
      // The stem leaves the bar towards (-uy, ux).
      final nx = -uy, ny = ux;
      final turned = _Art(200, 160)
        ..stroke([
          (cx - 60 * ux, cy - 60 * uy),
          (cx + 60 * ux, cy + 60 * uy),
        ], 4)
        ..stroke([(cx, cy), (cx + 60 * nx, cy + 60 * ny)], 4);
      final pool = _pool(turned, range: range, width: width);
      for (final k in [-1.0, 1.0]) {
        for (final d in [8.0, 16.0]) {
          expect(
            _around(
              turned,
              pool,
              cx + k * d * ux + 5 * nx,
              cy + k * d * uy + 5 * ny,
              1.5,
            ),
            greaterThan(2),
            reason: 'by the bar, $d px along, T turned $degrees degrees',
          );
          expect(
            _around(
              turned,
              pool,
              cx + d * nx + k * 5 * ux,
              cy + d * ny + k * 5 * uy,
              1.5,
            ),
            greaterThan(2),
            reason: 'by the stem, $d px along, T turned $degrees degrees',
          );
          expect(
            _around(
              turned,
              pool,
              cx + k * d * ux - 5 * nx,
              cy + k * d * uy - 5 * ny,
              3,
            ),
            0,
            reason: 'across the bar, T turned $degrees degrees',
          );
        }
      }
    }

    // Wider than a right angle: none.
    for (final degrees in [110.0, 120.0, 135.0]) {
      final a = degrees * math.pi / 180;
      final wide = _Art(200, 160)
        ..stroke([
          (40, 80),
          (100, 80),
          (100 - 60 * math.cos(a), 80 + 60 * math.sin(a)),
        ], 3);
      expect(
        _total(_pool(wide, range: range, width: width)),
        0,
        reason: 'a $degrees degree corner',
      );
    }
  });

  test('a sharp corner pools inside it, in the pool colour', () {
    // A V opening to the left, 50 degrees wide, its point at (150, 80).
    final art = _Art(200, 160);
    final a = 25 * math.pi / 180;
    art.stroke([
      (150 - 110 * math.cos(a), 80 - 110 * math.sin(a)),
      (150, 80),
      (150 - 110 * math.cos(a), 80 + 110 * math.sin(a)),
    ], 3);
    final pool = _pool(art, range: 24, width: 8, color: 0xFF7A2038);
    _write('corner', art, pool);
    // Inside the V, near its point: covered, in the pool colour.
    final i = (80 * art.width + 141) * 4;
    final alpha = pool[i + 3];
    expect(alpha, greaterThan(180));
    expect(pool[i] * 255 / alpha, closeTo(0x7A, 3));
    expect(pool[i + 1] * 255 / alpha, closeTo(0x20, 3));
    expect(pool[i + 2] * 255 / alpha, closeTo(0x38, 3));
    for (var k = 0; k < pool.length; k += 4) {
      for (var c = 0; c < 3; c++) {
        expect(pool[k + c], lessThanOrEqualTo(pool[k + 3]));
      }
    }
    // Outside the V (beyond its point, above and below the arms): none.
    expect(_around(art, pool, 158, 80, 4), 0, reason: 'beyond the point');
    expect(_around(art, pool, 135, 64, 3), 0, reason: 'outside the top arm');
    expect(_around(art, pool, 135, 96, 3), 0, reason: 'outside the bottom');
    // Far along the arms, none.
    expect(_around(art, pool, 80, 80 - 70 * math.tan(a), 5), 0);
  });

  for (final thickness in [6.0, 1.0]) {
    test('the Olympic rings (${thickness.round()} px lines): every crossing '
        'pools in its two narrow angles only', () {
      _olympicRings(thickness);
    });
  }

  test('on 1 px line art, where nothing hides it: the narrow angles of a '
      'crossing, a sharp corner, a T and a square corner pool, wider '
      'corners do not', () {
    const range = 30.0, width = 10.0;
    // The bar runs along row 80; the other line crosses it at 40 degrees.
    final crossing = _Art(220, 160)
      ..stroke([(20, 80.5), (200, 80.5)], 1, soft: true)
      ..lineThrough(110, 80.5, -40, 80, 1, soft: true);
    final pool = _pool(crossing, range: range, width: width);
    _write('crossing_40_1px', crossing, pool);
    for (final d in [21, 24, 27]) {
      final expected = 1 + (width - 1) * (1 - d / range);
      expect(
        _column(crossing, pool, 110 + d, 72, 79),
        closeTo(expected, 1.5),
        reason: 'above the bar $d px to the right',
      );
      expect(
        _column(crossing, pool, 110 - d, 81, 88),
        closeTo(expected, 1.5),
        reason: 'below the bar $d px to the left',
      );
      expect(_column(crossing, pool, 110 + d, 81, 110), 0);
      expect(_column(crossing, pool, 110 - d, 40, 79), 0);
    }
    expect(_column(crossing, pool, 110 + 34, 40, 120), 0);
    // Right inside the narrow angle, by the crossing: ink.
    final bisector = -20 * math.pi / 180;
    expect(
      _around(
        crossing,
        pool,
        110 + 7 * math.cos(bisector),
        80.5 + 7 * math.sin(bisector),
        1.5,
      ),
      greaterThan(3),
    );

    // A sharp corner, 50 degrees, its point at (150, 80).
    final a = 25 * math.pi / 180;
    final corner = _Art(200, 160)
      ..stroke(
        [
          (150 - 110 * math.cos(a), 80.5 - 110 * math.sin(a)),
          (150, 80.5),
          (150 - 110 * math.cos(a), 80.5 + 110 * math.sin(a)),
        ],
        1,
        soft: true,
      );
    final cornerPool = _pool(corner, range: 24, width: 8);
    _write('corner_1px', corner, cornerPool);
    expect(_around(corner, cornerPool, 143, 80.5, 2), greaterThan(8));
    expect(_around(corner, cornerPool, 155, 80.5, 3), 0, reason: 'outside');
    expect(_around(corner, cornerPool, 135, 70, 2), 0, reason: 'outside');

    // A T and a square corner: inside the right angles too. The bar runs
    // along row 50, the stem down column 85; the corner's lines along row
    // 120 and down column 60.
    final t = _Art(200, 160)
      ..stroke([(20, 50.5), (150, 50.5)], 1, soft: true)
      ..stroke([(85.5, 50.5), (85.5, 150)], 1, soft: true)
      ..stroke([(30, 120.5), (60.5, 120.5), (60.5, 150)], 1, soft: true);
    final tPool = _pool(t, range: range, width: width);
    _write('t_junction_1px', t, tPool);
    for (final d in [16, 20, 24]) {
      final expected = 1 + (width - 1) * (1 - d / range);
      for (final side in [-1, 1]) {
        expect(
          _column(t, tPool, 85 + side * d, 51, 63),
          closeTo(expected, 1.5),
          reason: 'below the bar, $d px ${side < 0 ? 'left' : 'right'}',
        );
        expect(
          _row(t, tPool, 50 + d, side < 0 ? 72 : 86, side < 0 ? 84 : 98),
          closeTo(expected, 1.5),
          reason:
              'beside the stem, $d px down, '
              '${side < 0 ? 'left' : 'right'}',
        );
      }
    }
    for (var x = 20; x < 150; x++) {
      expect(_column(t, tPool, x, 0, 49), 0, reason: 'above the bar');
    }
    // The corner: inside it (below the line, left of the other) only.
    expect(_around(t, tPool, 55, 125.5, 2), greaterThan(4));
    expect(_column(t, tPool, 40, 121, 133), closeTo(1 + 9 / 3, 1.5));
    expect(_around(t, tPool, 50, 114, 4), 0, reason: 'above the corner');
    expect(_around(t, tPool, 67, 135, 4), 0, reason: 'right of the corner');
    for (var degrees = 5; degrees < 90; degrees += 10) {
      final r = degrees * math.pi / 180;
      const cx = 100.0, cy = 80.0;
      final ux = math.cos(r), uy = math.sin(r);
      final nx = -uy, ny = ux;
      final turned = _Art(200, 160)
        ..stroke(
          [(cx - 60 * ux, cy - 60 * uy), (cx + 60 * ux, cy + 60 * uy)],
          1,
          soft: true,
        )
        ..stroke([(cx, cy), (cx + 60 * nx, cy + 60 * ny)], 1, soft: true);
      final pool = _pool(turned, range: range, width: width);
      for (final k in [-1.0, 1.0]) {
        expect(
          _around(
            turned,
            pool,
            cx + k * 12 * ux + 3 * nx,
            cy + k * 12 * uy + 3 * ny,
            1.5,
          ),
          greaterThan(2),
          reason: 'by the bar of a 1 px T turned $degrees degrees',
        );
        expect(
          _around(
            turned,
            pool,
            cx + k * 12 * ux - 4 * nx,
            cy + k * 12 * uy - 4 * ny,
            2.5,
          ),
          0,
          reason: 'across the bar of a 1 px T turned $degrees degrees',
        );
      }
    }

    // Wider than a right angle: none, at 110, 120 and 135 degrees.
    final wide = _Art(200, 160);
    for (final (k, degrees) in [(0, 110.0), (1, 120.0), (2, 135.0)]) {
      final a = degrees * math.pi / 180;
      const x = 100.0;
      final y = 15.5 + 48 * k;
      wide.stroke(
        [(x - 60, y), (x, y), (x - 36 * math.cos(a), y + 36 * math.sin(a))],
        1,
        soft: true,
      );
    }
    final widePool = _pool(wide, range: range, width: width);
    _write('obtuse_1px', wide, widePool);
    expect(_total(widePool), 0);
  });

  for (final thickness in [3.0, 1.0]) {
    test('a line that ends within the range ends its pool there, at 1 px; '
        'the other line keeps the whole range (${thickness.round()} px '
        'lines)', () {
      const range = 30.0, width = 10.0;
      final soft = thickness < 2;
      final o = soft ? .5 : 0.0;
      // A T whose stem stops 15 px below the bar (row 50, stem column 85),
      // and a 50 degree V, its point at (150, 130), whose upper arm stops 20
      // px out while the lower one runs on.
      const a = 25 * math.pi / 180;
      final art = _Art(220, 190)
        ..stroke([(20, 50 + o), (200, 50 + o)], thickness, soft: soft)
        ..stroke([(85 + o, 50 + o), (85 + o, 65 + o)], thickness, soft: soft)
        ..stroke(
          [
            (150 - 20 * math.cos(a), 130 + o - 20 * math.sin(a)),
            (150, 130 + o),
            (150 - 120 * math.cos(a), 130 + o + 120 * math.sin(a)),
          ],
          thickness,
          soft: soft,
        );
      final pool = _pool(art, range: range, width: width);
      _write(soft ? 'line_end_1px' : 'line_end', art, pool);

      // The stem's pool, beside it, where the bar's pool is out of the way
      // (from row 62): just before the stem's round end begins, about 1 to
      // 2 px, not the 6 px the whole range would leave there; past the end,
      // nothing.
      final e = soft ? 1 : 2;
      for (final side in [-1, 1]) {
        final from = side < 0 ? 85 - e - 12 : 85 + e;
        final to = side < 0 ? 85 - e : 85 + e + 12;
        for (final y in [62, 63]) {
          final s = y - 50.0;
          final thin = _row(art, pool, y, from, to);
          expect(
            thin,
            lessThan(1 + (width - 1) * (1 - s / 15) + 1.2),
            reason: 'beside the stem, row $y, ${side < 0 ? 'left' : 'right'}',
          );
          expect(thin, greaterThan(.3), reason: 'still there at row $y');
        }
        for (var y = 66; y < 100; y++) {
          expect(_row(art, pool, y, from, to), 0, reason: 'past the end, $y');
        }
      }
      // The bar's pool keeps the whole range.
      for (final d in [20, 25]) {
        expect(
          _column(art, pool, 85 + d, 50 + e, 50 + e + 12),
          closeTo(1 + (width - 1) * (1 - d / range), 1.5),
          reason: 'below the bar, $d px right',
        );
      }

      // The V: along the lower arm, past where the upper arm's pool ended,
      // the whole range's slope, measured straight across from its edge.
      double across(double s) {
        // From the lower arm's centre at s along it, towards the inside.
        final px = 150 - s * math.cos(a), py = 130 + o + s * math.sin(a);
        final nx = -math.sin(a), ny = -math.cos(a);
        var sum = 0.0;
        for (var h = thickness / 2 + .5; h <= thickness / 2 + 14; h += .1) {
          final x = (px + nx * h).floor(), y = (py + ny * h).floor();
          sum += pool[(y * art.width + x) * 4 + 3] / 255 * .1;
        }
        return sum;
      }

      for (final s in [24.0, 27.0]) {
        expect(
          across(s),
          closeTo(1 + (width - 1) * (1 - s / range), 1.2),
          reason: 'the lower arm, $s px along',
        );
      }
      // The upper arm's own pool stops at its end: nothing beside where it
      // would have gone on.
      final ux = 150 - 26 * math.cos(a), uy = 130 + o - 26 * math.sin(a);
      expect(
        _around(art, pool, ux + 3 * math.sin(a), uy + 3 * math.cos(a), 2),
        0,
        reason: 'past the upper arm\'s end',
      );
    });
  }

  test('curves and straight lines get none', () {
    final art = _Art(200, 160)
      ..stroke([
        for (var a = 0.3; a <= math.pi - .3; a += .05)
          (100 + 50 * math.cos(a), 60 + 30 * math.sin(a)),
      ], 3)
      ..stroke([(20, 130), (180, 130)], 3)
      ..ring(28, 36, 16, 3);
    expect(_total(_pool(art)), 0);
  });
}
