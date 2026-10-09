import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
