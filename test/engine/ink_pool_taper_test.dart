import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';

const _w = 200, _h = 160;

/// Black line art on a transparent layer, as round-capped strokes.
class _Art {
  final rgba = Uint8List(_w * _h * 4);

  void stroke(List<(double, double)> points, double thickness) {
    final half = thickness / 2;
    for (var k = 0; k + 1 < points.length; k++) {
      final (ax, ay) = points[k];
      final (bx, by) = points[k + 1];
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          final px = x + .5, py = y + .5;
          final dx = bx - ax, dy = by - ay;
          final len2 = dx * dx + dy * dy;
          final t = len2 == 0
              ? 0.0
              : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
          final ex = px - (ax + dx * t), ey = py - (ay + dy * t);
          if (ex * ex + ey * ey <= half * half) {
            final i = (y * _w + x) * 4;
            rgba[i] = rgba[i + 1] = rgba[i + 2] = 0;
            rgba[i + 3] = 255;
          }
        }
      }
    }
  }
}

/// The pool's thickness across column [x] (summed coverage).
double _thicknessAcrossColumn(Uint8List pool, int x, int fromY, int toY) {
  var sum = 0.0;
  for (var y = fromY; y <= toY; y++) {
    sum += pool[(y * _w + x) * 4 + 3] / 255;
  }
  return sum;
}

void _write(String name, Uint8List art, Uint8List pool) {
  const scale = 3;
  final image = img.Image(width: _w * scale * 2 + 12, height: _h * scale);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      final line = art[i + 3] > 0;
      final a = pool[i + 3] / 255;
      // Left: the pool alone (red). Right: the pool under the line art.
      final poolColour = (
        (255 - (255 - 200) * a).round(),
        (255 - 255 * a).round(),
        (255 - 255 * a).round(),
      );
      final under = line ? (20, 20, 20) : poolColour;
      for (var sy = 0; sy < scale; sy++) {
        for (var sx = 0; sx < scale; sx++) {
          image.setPixelRgb(
            x * scale + sx,
            y * scale + sy,
            poolColour.$1,
            poolColour.$2,
            poolColour.$3,
          );
          image.setPixelRgb(
            _w * scale + 12 + x * scale + sx,
            y * scale + sy,
            under.$1,
            under.$2,
            under.$3,
          );
        }
      }
    }
  }
  final dir = Directory('build/ink-pool')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(img.encodePng(image));
}

/// 墨溜まり: ink pools inside the angles where lines meet (inside a corner,
/// under the bar of a T on both sides of its stem), never outside. At the
/// meeting point the pool shows the set width beyond the line's edge; along
/// each line it thins in a straight slope ("like a slide") to 1 px at the
/// end of the range, and nothing beyond, whether the line is thin or thick.
/// Curves and straight lines get none.
void main() {
  final engine = FilterEngine();

  test('the pool slopes from the set width to 1 px along every line', () {
    final art = _Art()
      // A T: a horizontal line with a line going down from its middle.
      ..stroke([(20, 50), (120, 50)], 3)
      ..stroke([(70, 50), (70, 140)], 3)
      // A smile and a straight line elsewhere: no pools.
      ..stroke([
        for (var a = 0.3; a <= math.pi - .3; a += .05)
          (160 + 18 * math.cos(a), 110 + 12 * math.sin(a)),
      ], 3)
      ..stroke([(140, 20), (190, 20)], 3);
    const range = 30.0, width = 10.0;
    final pool = engine.applyInkPoolLayer(
      art.rgba,
      _w,
      _h,
      color: 0xFF000000,
      rangePx: range,
      centerWidthPx: width,
    );
    _write('t_junction', art.rgba, pool);

    // Along the horizontal line, both ways from the meeting point. The bar
    // covers rows 48 to 51; what shows is below it.
    for (final side in [-1, 1]) {
      for (final d in [12, 18, 24]) {
        final x = 70 + side * d;
        // All of it under the bar (the stem's side), none above.
        final expected = 1 + (width - 1) * (1 - d / range);
        expect(
          _thicknessAcrossColumn(pool, x, 52, 70),
          closeTo(expected, 1),
          reason: '$d px from the meeting point (side $side)',
        );
        // Under the line art it reaches back to the line's centre, so no
        // gap shows along the line's edge.
        expect(
          _thicknessAcrossColumn(pool, x, 50, 51),
          greaterThan(1.5),
          reason: 'under the bar at $d px (side $side)',
        );
        expect(
          _thicknessAcrossColumn(pool, x, 30, 47),
          0,
          reason: 'nothing above the bar at $d px (side $side)',
        );
      }
      // Beyond the range there is no pool.
      expect(_thicknessAcrossColumn(pool, 70 + side * 34, 30, 70), 0);
    }
    // It keeps getting thinner: a slope, not a blob.
    final profile = [
      for (var d = 4; d <= 28; d += 2)
        _thicknessAcrossColumn(pool, 70 + d, 30, 70),
    ];
    for (var k = 1; k < profile.length; k++) {
      expect(profile[k], lessThanOrEqualTo(profile[k - 1] + .3));
    }
    // Next to the meeting point, the stem gets the pool on both sides
    // (inside both angles of the T), the bar only underneath.
    var left = 0.0, right = 0.0;
    for (var x = 55; x < 70; x++) {
      left += pool[(56 * _w + x) * 4 + 3] / 255;
    }
    for (var x = 71; x <= 85; x++) {
      right += pool[(56 * _w + x) * 4 + 3] / 255;
    }
    expect(left, greaterThan(3));
    expect(right, greaterThan(3));
    expect(left, closeTo(right, 2.5));
    // The smile and the straight line get no pool.
    for (var y = 0; y < _h; y++) {
      for (var x = 135; x < _w; x++) {
        expect(pool[(y * _w + x) * 4 + 3], 0, reason: '($x, $y)');
      }
    }
  });

  test('on a thick line the pool shows the same width beyond its edge', () {
    const range = 30.0, width = 10.0;
    final art = _Art()
      ..stroke([(20, 50), (150, 50)], 8)
      ..stroke([(85, 50), (85, 150)], 8);
    final pool = engine.applyInkPoolLayer(
      art.rgba,
      _w,
      _h,
      color: 0xFF000000,
      rangePx: range,
      centerWidthPx: width,
    );
    _write('t_junction_thick', art.rgba, pool);
    // The bar covers rows 46 to 53.
    for (final side in [-1, 1]) {
      for (final d in [12, 18, 24]) {
        final x = 85 + side * d;
        expect(
          _thicknessAcrossColumn(pool, x, 54, 74),
          closeTo(1 + (width - 1) * (1 - d / range), 1.5),
          reason: '$d px from the meeting point (side $side)',
        );
        expect(
          _thicknessAcrossColumn(pool, x, 26, 45),
          0,
          reason: 'nothing above the bar at $d px (side $side)',
        );
      }
      expect(_thicknessAcrossColumn(pool, 85 + side * 36, 26, 80), 0);
    }
    // Next to the stem, the pool shows on both sides of it too.
    var left = 0.0, right = 0.0;
    for (var x = 60; x < 81; x++) {
      left += pool[(62 * _w + x) * 4 + 3] / 255;
    }
    for (var x = 89; x <= 110; x++) {
      right += pool[(62 * _w + x) * 4 + 3] / 255;
    }
    expect(left, greaterThan(4));
    expect(left, closeTo(right, 2.5));
  });

  test('a corner pools too, in the pool colour', () {
    final art = _Art()..stroke([(30, 30), (110, 30), (110, 120)], 3);
    final pool = engine.applyInkPoolLayer(
      art.rgba,
      _w,
      _h,
      color: 0xFF7A2038,
      rangePx: 24,
      centerWidthPx: 8,
    );
    _write('corner', art.rgba, pool);
    // The corner itself is covered, in the pool colour (premultiplied).
    final corner = (31 * _w + 109) * 4;
    final a = pool[corner + 3];
    expect(a, greaterThan(180));
    expect(pool[corner] * 255 / a, closeTo(0x7A, 3));
    expect(pool[corner + 1] * 255 / a, closeTo(0x20, 3));
    expect(pool[corner + 2] * 255 / a, closeTo(0x38, 3));
    // Valid premultiplied colour everywhere.
    for (var i = 0; i < pool.length; i += 4) {
      for (var c = 0; c < 3; c++) {
        expect(pool[i + c], lessThanOrEqualTo(pool[i + 3]));
      }
    }
    // Inside the corner only: below the top line and left of the side.
    expect(pool[(36 * _w + 104) * 4 + 3], greaterThan(0), reason: 'inside');
    expect(pool[(25 * _w + 104) * 4 + 3], 0, reason: 'above the corner');
    expect(pool[(36 * _w + 115) * 4 + 3], 0, reason: 'right of the corner');
    // Far along either line, none.
    expect(pool[(30 * _w + 60) * 4 + 3], 0);
    expect(pool[(90 * _w + 110) * 4 + 3], 0);
  });
}
