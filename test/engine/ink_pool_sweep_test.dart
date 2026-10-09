import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';

const _w = 240, _h = 200;

/// The sharp corner every case is drawn as: a V of 1 px anti-aliased lines,
/// [_angle] wide, its point at [_apex] and opening to the right.
const _angle = 50 * math.pi / 180;
const _apex = (40.0, 100.0);
final _up = (math.cos(-_angle / 2), math.sin(-_angle / 2));
final _down = (math.cos(_angle / 2), math.sin(_angle / 2));

Uint8List _corner() {
  final rgba = Uint8List(_w * _h * 4);
  const length = 230.0;
  void line((double, double) u) {
    final (ax, ay) = _apex;
    final bx = ax + u.$1 * length, by = ay + u.$2 * length;
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final px = x + .5, py = y + .5;
        final dx = bx - ax, dy = by - ay;
        final t = (((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
            .clamp(0.0, 1.0);
        final ex = px - (ax + dx * t), ey = py - (ay + dy * t);
        final cover = (1 - math.sqrt(ex * ex + ey * ey)).clamp(0.0, 1.0);
        final i = (y * _w + x) * 4 + 3;
        final a = (cover * 255).round();
        if (a > rgba[i]) rgba[i] = a;
      }
    }
  }

  line(_up);
  line(_down);
  return rgba;
}

/// How far the ideal pool can reach from a line's edge per px before its
/// end: the straight line between the two lines' pool ends, which a wide
/// centre is flattened to rather than bulging past.
final _flat = 1 / math.tan(_angle / 2);

/// Where the ideal pool is: inside the corner, along each line, from the
/// line's edge out by the centre width at the point, thinning in a straight
/// line to nothing at [range] along it, and never past the straight line
/// between the two lines' pool ends.
bool _inIdeal(double x, double y, double width, double range) {
  const edge = .5;
  final (ax, ay) = _apex;
  final px = x - ax, py = y - ay;
  // Across each line, towards the other one.
  final hUp = -(px * _up.$2 - py * _up.$1);
  final hDown = px * _down.$2 - py * _down.$1;
  if (hUp < -edge || hDown < -edge) return false;
  for (final (u, h) in [(_up, hUp), (_down, hDown)]) {
    final s = px * u.$1 + py * u.$2;
    if (s < 0 || s > range) continue;
    final thickness = math.min(width * (1 - s / range), _flat * (range - s));
    if (h <= edge + thickness) return true;
  }
  return false;
}

/// The ideal pool's coverage of pixel ([x], [y]), from 4 x 4 samples.
double _ideal(int x, int y, double width, double range) {
  var n = 0;
  for (var sy = 0; sy < 4; sy++) {
    for (var sx = 0; sx < 4; sx++) {
      if (_inIdeal(x + (sx + .5) / 4, y + (sy + .5) / 4, width, range)) n++;
    }
  }
  return n / 16;
}

/// The pool's thickness beyond the edge of the upper line, [s] px from the
/// point, measured straight across the line.
double _thicknessAt(Uint8List pool, double s, double reach) {
  final (ax, ay) = _apex;
  // Into the corner from the upper line.
  final nx = -_up.$2, ny = _up.$1;
  // Read between pixel centres, so the pixel grid does not jitter it.
  double at(double x, double y) {
    final fx = x - .5, fy = y - .5;
    final x0 = fx.floor(), y0 = fy.floor();
    final tx = fx - x0, ty = fy - y0;
    double px(int x, int y) => x < 0 || y < 0 || x >= _w || y >= _h
        ? 0
        : pool[(y * _w + x) * 4 + 3] / 255;
    return (px(x0, y0) * (1 - tx) + px(x0 + 1, y0) * tx) * (1 - ty) +
        (px(x0, y0 + 1) * (1 - tx) + px(x0 + 1, y0 + 1) * tx) * ty;
  }

  var sum = 0.0;
  for (var h = .5; h <= reach; h += .1) {
    sum += at(ax + _up.$1 * s + nx * h, ay + _up.$2 * s + ny * h) * .1;
  }
  return sum;
}

/// 墨溜まり's two settings, swept independently on a sharp corner of 1 px
/// lines: at the point the pool reaches out from the line's edge by the
/// centre width, it thins smoothly and evenly to a point at the end of the
/// range, and there is nothing else: no steps, no specks, nothing outside the
/// corner or past the range.
void main() {
  final engine = FilterEngine();
  final art = _corner();
  const widths = [2.0, 4.0, 6.0, 10.0, 16.0, 24.0];
  const ranges = [6.0, 12.0, 24.0, 40.0, 60.0];
  final results = <(double, double), Uint8List>{};

  for (final width in widths) {
    for (final range in ranges) {
      test('centre width ${width.round()} px, range ${range.round()} px', () {
        final pool = engine.applyInkPoolLayer(
          art,
          _w,
          _h,
          color: 0xFF000000,
          rangePx: range,
          centerWidthPx: width,
        );
        results[(width, range)] = pool;

        // Pixel by pixel against the ideal shape, where it shows (not under
        // the lines' ink), away from the very point.
        var worst = 0.0, off = 0;
        (int, int)? worstAt;
        for (var y = 0; y < _h; y++) {
          for (var x = 0; x < _w; x++) {
            final i = (y * _w + x) * 4 + 3;
            if (art[i] > 64) continue;
            final dx = x + .5 - _apex.$1, dy = y + .5 - _apex.$2;
            if (dx * dx + dy * dy < 4) continue;
            final diff = (pool[i] / 255 - _ideal(x, y, width, range)).abs();
            if (diff > worst) {
              worst = diff;
              worstAt = (x, y);
            }
            if (diff > .5) off++;
          }
        }
        // Only the anti-aliased rim may differ, and never by a whole pixel.
        expect(worst, lessThan(.9), reason: 'worst pixel at $worstAt');
        expect(
          off,
          lessThan(4 + range ~/ 6),
          reason: 'pixels off by half or more (worst at $worstAt)',
        );

        // Along the upper line, where the lower line's pool is out of the
        // way: the set width tapering evenly to nothing (the last pixel is
        // checked with the rest above).
        final profile = <(double, double)>[];
        for (var s = 1.0; s <= range - 1; s += 1) {
          final expected = math.min(
            width * (1 - s / range),
            _flat * (range - s),
          );
          // The lower line's pool across this point's measuring line.
          final apart = s * math.sin(_angle);
          final lowerReach = math.min(
            width * (1 - s * math.cos(_angle) / range),
            _flat * (range - s * math.cos(_angle)),
          );
          if (apart - expected - lowerReach < 2) continue;
          final measured = _thicknessAt(pool, s, expected + 3);
          profile.add((s, measured));
          expect(
            measured,
            closeTo(expected, .8),
            reason: '$s px along the line',
          );
        }
        for (var k = 1; k < profile.length; k++) {
          final step = profile[k].$2 - profile[k - 1].$2;
          expect(
            step,
            lessThanOrEqualTo(.45),
            reason: 'thinning evenly, at ${profile[k].$1} px: $profile',
          );
          expect(
            step,
            greaterThanOrEqualTo(-width / range - .6),
            reason: 'no sudden drop at ${profile[k].$1} px: $profile',
          );
        }
      });
    }
  }

  tearDownAll(() {
    // A sheet of every case: the pool in red under the black lines; across,
    // the range (R), down, the centre width (W).
    const crop = (x: 30, y: 30, w: 150, h: 140), scale = 2, gap = 6;
    const left = 130, top = 30;
    final sheet = img.Image(
      width: left + ranges.length * (crop.w * scale + gap),
      height: top + widths.length * (crop.h * scale + gap),
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    final ink = img.ColorRgb8(37, 48, 71);
    for (var col = 0; col < ranges.length; col++) {
      img.drawString(
        sheet,
        'R = ${ranges[col].round()} px',
        font: img.arial24,
        x: left + col * (crop.w * scale + gap) + 90,
        y: 2,
        color: ink,
      );
    }
    for (var row = 0; row < widths.length; row++) {
      img.drawString(
        sheet,
        'W = ${widths[row].round()} px',
        font: img.arial24,
        x: 4,
        y: top + row * (crop.h * scale + gap) + crop.h * scale ~/ 2 - 12,
        color: ink,
      );
    }
    for (var row = 0; row < widths.length; row++) {
      for (var col = 0; col < ranges.length; col++) {
        final pool = results[(widths[row], ranges[col])];
        if (pool == null) continue;
        for (var y = 0; y < crop.h; y++) {
          for (var x = 0; x < crop.w; x++) {
            final i = ((crop.y + y) * _w + crop.x + x) * 4 + 3;
            final a = pool[i] / 255, line = art[i] / 255;
            var r = 255 - 55 * a, g = 255 - 255 * a, b = 255 - 255 * a;
            r = r * (1 - line) + 20 * line;
            g = g * (1 - line) + 20 * line;
            b = b * (1 - line) + 20 * line;
            for (var sy = 0; sy < scale; sy++) {
              for (var sx = 0; sx < scale; sx++) {
                sheet.setPixelRgb(
                  left + col * (crop.w * scale + gap) + x * scale + sx,
                  top + row * (crop.h * scale + gap) + y * scale + sy,
                  r.round(),
                  g.round(),
                  b.round(),
                );
              }
            }
          }
        }
      }
    }
    final dir = Directory('build/ink-pool')..createSync(recursive: true);
    File('${dir.path}/sweep.png').writeAsBytesSync(img.encodePng(sheet));
  });
}
