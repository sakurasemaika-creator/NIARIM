import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/ink_pool_engine.dart';

const _w = 120;

/// Hard-edged strokes [thickness] px wide on a transparent layer, from
/// (ax, ay) to (bx, by) each.
Uint8List _strokes(
  double thickness,
  List<(double, double, double, double)> lines,
) {
  final rgba = Uint8List(_w * _w * 4);
  final r = thickness / 2;
  for (final (ax, ay, bx, by) in lines) {
    for (var y = 0; y < _w; y++) {
      for (var x = 0; x < _w; x++) {
        final cx = x + .5, cy = y + .5;
        final dx = bx - ax, dy = by - ay;
        final t = (((cx - ax) * dx + (cy - ay) * dy) / (dx * dx + dy * dy))
            .clamp(0.0, 1.0);
        final ex = cx - ax - dx * t, ey = cy - ay - dy * t;
        if (ex * ex + ey * ey <= r * r) rgba[(y * _w + x) * 4 + 3] = 255;
      }
    }
  }
  return rgba;
}

/// A line through the middle, shifted [shift] px right, at [angle]
/// radians, 50 px each way.
(double, double, double, double) _through(double angle, double shift) => (
  60 + shift - 50 * math.cos(angle),
  60 - 50 * math.sin(angle),
  60 + shift + 50 * math.cos(angle),
  60 + 50 * math.sin(angle),
);

Uint8List _pool(Uint8List art) => InkPoolEngine.layer(
  art,
  _w,
  _w,
  color: 0xFF000000,
  rangePx: 20,
  centreWidthPx: 8,
);

/// Two lines crossing at a right angle make four right-angled corners, and
/// at the default maximum angle (90°) every one of them pools, however the
/// lines' pixels fall. Thinning used to eat one of the two lines whole (a
/// diagonal peeled down to a 2 px staircase loses its end pass after pass),
/// and a crossing thinned to a small knot had no junction: either way no
/// corner pooled.
void main() {
  test('every corner of a right-angled X pools', () {
    for (final thickness in [4.0, 6.0, 8.0, 10.0]) {
      for (final shift in [0.0, .3, .5]) {
        final pool = _pool(
          _strokes(thickness, [
            (20 + shift, 20, 100 + shift, 100),
            (100 + shift, 20, 20 + shift, 100),
          ]),
        );
        // The pool in each corner: above, right, below and left of the
        // crossing.
        final corners = [0.0, 0.0, 0.0, 0.0];
        for (var y = 30; y < 90; y++) {
          for (var x = 30; x < 90; x++) {
            final a = pool[(y * _w + x) * 4 + 3] / 255;
            if (a == 0) continue;
            final dx = x + .5 - 60 - shift, dy = y + .5 - 60;
            corners[dy.abs() > dx.abs()
                    ? (dy < 0 ? 0 : 2)
                    : (dx > 0 ? 1 : 3)] +=
                a;
          }
        }
        final most = corners.reduce((a, b) => a > b ? a : b);
        for (final (k, c) in corners.indexed) {
          expect(
            c,
            greaterThan(most * .75),
            reason: '$thickness px, shifted $shift: corner $k of $corners',
          );
          expect(c, greaterThan(100));
        }
      }
    }
  });

  test('drawn for review: the pool in red under the lines', () {
    const scale = 2, gap = 8;
    final cases = [4.0, 6.0, 8.0, 10.0];
    final sheet = img.Image(
      width: (_w * scale + gap) * cases.length - gap,
      height: _w * scale,
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (final (k, thickness) in cases.indexed) {
      final art = _strokes(thickness, const [
        (20, 20, 100, 100),
        (100, 20, 20, 100),
      ]);
      final pool = _pool(art);
      for (var y = 0; y < _w * scale; y++) {
        for (var x = 0; x < _w * scale; x++) {
          final i = ((y ~/ scale) * _w + x ~/ scale) * 4 + 3;
          final line = art[i] / 255, a = pool[i] / 255;
          int over(double c) => (c * (1 - line) + 20 * line).round();
          sheet.setPixelRgb(
            k * (_w * scale + gap) + x,
            y,
            over(255 - 55 * a),
            over(255 - 255 * a),
            over(255 - 255 * a),
          );
        }
      }
    }
    final dir = Directory('build/ink-pool')..createSync(recursive: true);
    File('${dir.path}/x_crossing.png').writeAsBytesSync(img.encodePng(sheet));
  });

  test('both narrow angles of a crossing at a slant pool, however thin the '
      'lines', () {
    // Thinning leaves two lines crossing at a slant as two forks joined by
    // a short bridge. Just past the far fork its two lines still touch, and
    // were counted as one there: that fork's narrow angle never pooled.
    for (final thickness in [2.0, 3.0, 4.0, 5.0, 6.0, 8.0]) {
      for (final angle in [20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0, 60.0]) {
        for (final shift in [0.0, .3, .5]) {
          for (final turn in [0.0, 17.0]) {
            final a = turn * math.pi / 180, b = a - angle * math.pi / 180;
            final pool = _pool(
              _strokes(thickness, [_through(a, shift), _through(b, shift)]),
            );
            // The pool in each of the two narrow angles.
            final narrow = [0.0, 0.0];
            for (var y = 20; y < 100; y++) {
              for (var x = 20; x < 100; x++) {
                final alpha = pool[(y * _w + x) * 4 + 3] / 255;
                if (alpha == 0) continue;
                final from =
                    (math.atan2(y + .5 - 60, x + .5 - 60 - shift) - b) %
                    (2 * math.pi);
                if (from < angle * math.pi / 180) narrow[0] += alpha;
                if (from >= math.pi && from < math.pi + angle * math.pi / 180) {
                  narrow[1] += alpha;
                }
              }
            }
            final reason =
                '$thickness px at $angle°, shifted $shift, turned $turn°: '
                '$narrow';
            final most = math.max(narrow[0], narrow[1]);
            expect(
              math.min(narrow[0], narrow[1]),
              greaterThan(most * .75),
              reason: reason,
            );
            expect(most, greaterThan(20), reason: reason);
          }
        }
      }
    }
  });

  test('drawn for review: thin lines crossing at a slant', () {
    const scale = 2, gap = 8;
    final angles = [25.0, 30.0, 35.0, 40.0, 45.0];
    final sheet = img.Image(
      width: (_w * scale + gap) * angles.length - gap,
      height: _w * scale,
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (final (k, angle) in angles.indexed) {
      final half = angle / 2 * math.pi / 180;
      final art = _strokes(4, [_through(half, 0), _through(-half, 0)]);
      final pool = _pool(art);
      for (var y = 0; y < _w * scale; y++) {
        for (var x = 0; x < _w * scale; x++) {
          final i = ((y ~/ scale) * _w + x ~/ scale) * 4 + 3;
          final line = art[i] / 255, a = pool[i] / 255;
          int over(double c) => (c * (1 - line) + 20 * line).round();
          sheet.setPixelRgb(
            k * (_w * scale + gap) + x,
            y,
            over(255 - 55 * a),
            over(255 - 255 * a),
            over(255 - 255 * a),
          );
        }
      }
    }
    final dir = Directory('build/ink-pool')..createSync(recursive: true);
    File(
      '${dir.path}/slant_crossings.png',
    ).writeAsBytesSync(img.encodePng(sheet));
  });

  test('a straight diagonal line on its own does not pool', () {
    for (final thickness in [4.0, 6.0, 8.0, 10.0]) {
      for (final shift in [0.0, .3, .5]) {
        for (final line in [
          (20 + shift, 20.0, 100 + shift, 100.0),
          (100 + shift, 20.0, 20 + shift, 100.0),
        ]) {
          final pool = _pool(_strokes(thickness, [line]));
          var sum = 0;
          for (var i = 3; i < pool.length; i += 4) {
            sum += pool[i];
          }
          expect(sum, 0, reason: '$thickness px, shifted $shift, $line');
        }
      }
    }
  });
}
