import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

const _w = 240, _h = 200;

/// 1 px anti-aliased lines along [points].
Uint8List _lines(List<List<(double, double)>> strokes) {
  final rgba = Uint8List(_w * _h * 4);
  for (final points in strokes) {
    for (var k = 0; k + 1 < points.length; k++) {
      final (ax, ay) = points[k];
      final (bx, by) = points[k + 1];
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          final px = x + .5, py = y + .5;
          final dx = bx - ax, dy = by - ay;
          final t = (((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
              .clamp(0.0, 1.0);
          final ex = px - (ax + dx * t), ey = py - (ay + dy * t);
          final a = ((1 - math.sqrt(ex * ex + ey * ey)).clamp(0.0, 1.0) * 255)
              .round();
          final i = (y * _w + x) * 4 + 3;
          if (a > rgba[i]) rgba[i] = a;
        }
      }
    }
  }
  return rgba;
}

/// A corner of [degrees] with its point at ([x], [y]): one arm to the left,
/// the other turned [degrees] from it, 30 px each.
List<(double, double)> _corner(double x, double y, double degrees) {
  final a = degrees * math.pi / 180;
  return [(x - 30, y), (x, y), (x - 30 * math.cos(a), y + 30 * math.sin(a))];
}

/// The pool's coverage summed over a disc of [radius] round ([x], [y]).
double _around(Uint8List pool, double x, double y, double radius) {
  var sum = 0.0;
  for (var py = (y - radius).floor(); py <= (y + radius).ceil(); py++) {
    for (var px = (x - radius).floor(); px <= (x + radius).ceil(); px++) {
      final dx = px + .5 - x, dy = py + .5 - y;
      if (dx * dx + dy * dy > radius * radius) continue;
      sum += pool[(py * _w + px) * 4 + 3] / 255;
    }
  }
  return sum;
}

/// 墨溜まり's 「最大角度」: ink pools inside corners no wider than the set
/// angle (90 by default: acute and right angles), with a few degrees to
/// spare for lines drawn by hand, from 0 (none at all) to 180 (obtuse
/// corners too, but never the two sides of a straight line).
void main() {
  final engine = FilterEngine();
  // Corners of 50, 110, 135 and 160 degrees, and a T (90 under its bar,
  // 180 above it).
  const corners = [(50.0, 20.0), (110.0, 65.0), (135.0, 110.0), (160.0, 155.0)];
  final art = _lines([
    for (final (degrees, y) in corners) _corner(100, y, degrees),
    [(140, 60.5), (220, 60.5)],
    [(180.5, 60.5), (180.5, 140)],
  ]);
  // A point inside each corner, a few px in along its middle.
  (double, double) inside(double degrees, double y) {
    final half = degrees / 2 * math.pi / 180;
    final r = 1.5 / math.sin(half) + 2;
    return (100 - r * math.cos(half), y + r * math.sin(half));
  }

  Uint8List pool(double maxAngle) => engine.applyInkPoolLayer(
    art,
    _w,
    _h,
    color: 0xFF000000,
    rangePx: 24,
    centerWidthPx: 8,
    maxAngleDegrees: maxAngle,
  );
  bool pooled(Uint8List p, double degrees, double y) {
    final (x, py) = inside(degrees, y);
    return _around(p, x, py, 1.5) > 1.5;
  }

  final results = <double, Uint8List>{};
  for (final (maxAngle, expected) in [
    (90.0, [true, false, false, false]),
    (30.0, [false, false, false, false]),
    (0.0, [false, false, false, false]),
    (120.0, [true, true, false, false]),
    (150.0, [true, true, true, false]),
    (180.0, [true, true, true, true]),
  ]) {
    test('at ${maxAngle.round()} degrees: '
        '${[for (var k = 0; k < 4; k++)
          if (expected[k]) corners[k].$1.round()]} '
        'pool', () {
      final p = results[maxAngle] = pool(maxAngle);
      for (var k = 0; k < corners.length; k++) {
        final (degrees, y) = corners[k];
        expect(
          pooled(p, degrees, y),
          expected[k],
          reason: '${degrees.round()} degree corner',
        );
      }
      // The T: under the bar (two right angles) as soon as 90 is reached;
      // above it, along the straight bar, never.
      expect(
        _around(p, 188, 66, 2) > 1.5,
        maxAngle >= 90,
        reason: 'under the bar of the T',
      );
      expect(_around(p, 180.5, 55, 4), 0, reason: 'above the bar of the T');
      if (maxAngle == 0) {
        var total = 0;
        for (var i = 3; i < p.length; i += 4) {
          total += p[i];
        }
        expect(total, 0, reason: 'nothing at all at 0 degrees');
      }
    });
  }

  test('the setting is saved, restored, and 90 for older settings', () {
    const filter = FilterDef(
      id: 'pool',
      name: '墨溜まり',
      kind: FilterKind.inkPool,
      strength: 0,
    );
    expect(filter.inkPoolMaxAngle, 90);
    final changed = filter.copyWith(inkPoolMaxAngle: 135);
    expect(FilterDef.fromJson(changed.toJson()).inkPoolMaxAngle, 135);
    final old = changed.toJson()..remove('inkPoolMaxAngle');
    expect(FilterDef.fromJson(old).inkPoolMaxAngle, 90);
  });

  tearDownAll(() {
    final angles = results.keys.toList()..sort();
    const scale = 2;
    final sheet = img.Image(
      width: angles.length * _w * scale,
      height: _h * scale,
    );
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (var k = 0; k < angles.length; k++) {
      final p = results[angles[k]]!;
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          final i = (y * _w + x) * 4 + 3;
          final a = p[i] / 255, line = art[i] / 255;
          final r = ((255 - 55 * a) * (1 - line) + 20 * line).round();
          final g = ((255 - 255 * a) * (1 - line) + 20 * line).round();
          for (var sy = 0; sy < scale; sy++) {
            for (var sx = 0; sx < scale; sx++) {
              sheet.setPixelRgb(
                (k * _w + x) * scale + sx,
                y * scale + sy,
                r,
                g,
                g,
              );
            }
          }
        }
      }
      img.drawString(
        sheet,
        '${angles[k].round()} deg',
        font: img.arial24,
        x: k * _w * scale + 8,
        y: 4,
        color: img.ColorRgb8(37, 48, 71),
      );
    }
    final dir = Directory('build/ink-pool')..createSync(recursive: true);
    File('${dir.path}/max_angle.png').writeAsBytesSync(img.encodePng(sheet));
  });
}
