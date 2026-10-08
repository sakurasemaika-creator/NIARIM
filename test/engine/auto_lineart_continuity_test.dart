import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

const _w = 220, _h = 180;

/// A rough of constant-width strokes on a transparent layer.
class _Rough {
  final rgba = Uint8List(_w * _h * 4);

  void stroke(List<(double, double)> points, double thickness) {
    final half = thickness / 2;
    for (var k = 0; k + 1 < points.length; k++) {
      final (ax, ay) = points[k];
      final (bx, by) = points[k + 1];
      final minX = math.max(0, (math.min(ax, bx) - half - 1).floor());
      final maxX = math.min(_w - 1, (math.max(ax, bx) + half + 1).ceil());
      final minY = math.max(0, (math.min(ay, by) - half - 1).floor());
      final maxY = math.min(_h - 1, (math.max(ay, by) + half + 1).ceil());
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          final px = x + .5, py = y + .5;
          final dx = bx - ax, dy = by - ay;
          final len2 = dx * dx + dy * dy;
          final t = len2 == 0
              ? 0.0
              : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
          final ex = px - (ax + dx * t), ey = py - (ay + dy * t);
          if (ex * ex + ey * ey <= half * half) {
            final i = (y * _w + x) * 4;
            rgba[i] = rgba[i + 1] = rgba[i + 2] = 36;
            rgba[i + 3] = 255;
          }
        }
      }
    }
  }

  void ring(double cx, double cy, double r, double thickness) => stroke([
    for (var a = 0.0; a <= 2 * math.pi + .01; a += .05)
      (cx + r * math.cos(a), cy + r * math.sin(a)),
  ], thickness);
}

Uint8List _autoLineart(
  Uint8List rough, {
  int color = 0xFF000000,
  bool taper = true,
}) => applyDrawFilterInIsolate((
  rough,
  _w,
  _h,
  FilterDef(
    id: 'Filter0023',
    name: '自動線画',
    kind: FilterKind.autoLineart,
    autoLineartRoughWidth: 12,
    autoLineartOutputWidth: 2,
    autoLineartTaperLength: 8,
    autoLineartSmoothing: 5,
    autoLineartColor: color,
    autoLineartTaper: taper,
  ),
  null,
));

/// Whether there is line within [reach] px of ([x], [y]).
bool _lineNear(Uint8List out, double x, double y, {int reach = 2}) {
  for (var dy = -reach; dy <= reach; dy++) {
    for (var dx = -reach; dx <= reach; dx++) {
      final px = x.round() + dx, py = y.round() + dy;
      if (px < 0 || py < 0 || px >= _w || py >= _h) continue;
      if (out[(py * _w + px) * 4 + 3] > 60) return true;
    }
  }
  return false;
}

void _write(String name, Uint8List rough, Uint8List out) {
  final image = img.Image(width: _w * 2 + 8, height: _h);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      final r = (255 - 200 * rough[i + 3] / 255).round();
      image.setPixelRgb(x, y, r, r, r);
      final o = (255 - 255 * out[i + 3] / 255).round();
      image.setPixelRgb(_w + 8 + x, y, o, o, o);
    }
  }
  final dir = Directory('build/auto-lineart')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(img.encodePng(image));
}

/// 自動線画 takes the centre line of a rough and draws it thin. A rough drawn
/// at a constant width comes out as one unbroken line: the thinned line's
/// diagonal steps are not junctions to cut it at, and short pieces between
/// two junctions are not thrown away. A dot stays a dot. Two strokes with
/// paper between them stay two lines, however close; only specks of paper
/// inside a stroke are filled.
void main() {
  test('constant-width strokes come out as unbroken centre lines', () {
    final rough = _Rough()
      // A ring, a slanted line, a zigzag and a T, all 8 px wide.
      ..ring(60, 60, 36, 8)
      ..stroke([(120, 20), (200, 70)], 8)
      ..stroke([(20, 150), (50, 120), (80, 150), (110, 120), (140, 150)], 8)
      ..stroke([(150, 110), (210, 110)], 8)
      ..stroke([(180, 110), (180, 170)], 8)
      // An eye: a filled dot.
      ..ring(60, 60, 2, 6);
    final out = _autoLineart(rough.rgba);
    _write('continuity', rough.rgba, out);

    for (var a = 0.0; a < 2 * math.pi; a += math.pi / 90) {
      expect(
        _lineNear(out, 60 + 36 * math.cos(a), 60 + 36 * math.sin(a)),
        isTrue,
        reason: 'the ring at ${(a * 180 / math.pi).round()} degrees',
      );
    }
    // Away from its tapered ends, the slanted line is all there.
    for (var t = .15; t <= .85; t += .02) {
      expect(
        _lineNear(out, 120 + 80 * t, 20 + 50 * t),
        isTrue,
        reason: 'slanted line at $t',
      );
    }
    const zigzag = [(20, 150), (50, 120), (80, 150), (110, 120), (140, 150)];
    for (var k = 0; k + 1 < zigzag.length; k++) {
      for (var t = 0.0; t <= 1; t += .05) {
        if (k == 0 && t < .3 || k == zigzag.length - 2 && t > .7) continue;
        final (ax, ay) = zigzag[k];
        final (bx, by) = zigzag[k + 1];
        expect(
          _lineNear(out, ax + (bx - ax) * t, ay + (by - ay) * t, reach: 3),
          isTrue,
          reason: 'zigzag segment $k at $t',
        );
      }
    }
    for (var x = 160; x <= 200; x += 2) {
      expect(_lineNear(out, x.toDouble(), 110), isTrue, reason: 'T bar $x');
    }
    for (var y = 112; y <= 160; y += 2) {
      expect(_lineNear(out, 180, y.toDouble()), isTrue, reason: 'T stem $y');
    }
    expect(_lineNear(out, 60, 60), isTrue, reason: 'the dot');
  });

  test('the line is thin and in valid premultiplied colour', () {
    final rough = _Rough()..ring(110, 90, 50, 10);
    final out = _autoLineart(rough.rgba, color: 0xFFD02060);
    var painted = 0;
    for (var i = 0; i < out.length; i += 4) {
      final a = out[i + 3];
      if (a == 0) continue;
      painted++;
      for (var c = 0; c < 3; c++) {
        expect(out[i + c], lessThanOrEqualTo(a));
      }
    }
    // About 2 px wide round a 50 px ring, far less than the 10 px rough.
    final circumference = 2 * math.pi * 50;
    expect(painted / circumference, inInclusiveRange(1.5, 4.5));
  });

  test('入り抜き can be turned off: the ends keep the full width', () {
    final rough = _Rough()..stroke([(30, 90), (190, 90)], 8);
    double inkNearEnd(Uint8List out) {
      var sum = 0.0;
      for (var x = 28; x <= 36; x++) {
        for (var y = 84; y <= 96; y++) {
          sum += out[(y * _w + x) * 4 + 3] / 255;
        }
      }
      return sum;
    }

    final tapered = _autoLineart(rough.rgba);
    final square = _autoLineart(rough.rgba, taper: false);
    _write('taper_on', rough.rgba, tapered);
    _write('taper_off', rough.rgba, square);
    expect(inkNearEnd(square), greaterThan(inkNearEnd(tapered) * 1.4));
    // In the middle, both are the same 2 px line.
    for (final out in [tapered, square]) {
      var middle = 0.0;
      for (var y = 84; y <= 96; y++) {
        middle += out[(y * _w + 110) * 4 + 3] / 255;
      }
      expect(middle, closeTo(2, .6));
    }
  });

  test('two strokes close together stay two lines, each on its own centre', () {
    const cx = 110.0, cy = 70.0, r = 50.0;
    final rough = _Rough()
      // A long narrow loop: two 8 px strokes with 6 px of paper between.
      ..stroke([(30, 120), (190, 120), (190, 134), (30, 134), (30, 120)], 8)
      // Two parallel 8 px strokes only 2 px apart.
      ..stroke([(30, 160), (190, 160)], 8)
      ..stroke([(30, 170), (190, 170)], 8)
      // A head and the hairline inside it, 6 px lines: they meet at the
      // sides and run 4 px apart at the top.
      ..stroke([
        for (var a = math.pi; a <= 2 * math.pi + .01; a += .04)
          (cx + r * math.cos(a), cy + r * math.sin(a)),
      ], 6)
      ..stroke([
        for (var a = math.pi; a <= 2 * math.pi + .01; a += .04)
          (
            cx + (r - 10 * -math.sin(a)) * math.cos(a),
            cy + (r - 10 * -math.sin(a)) * math.sin(a),
          ),
      ], 6);
    final out = _autoLineart(rough.rgba);
    _write('close_lines', rough.rgba, out);

    for (var x = 50; x <= 170; x += 4) {
      final at = x.toDouble();
      for (final (y, line) in [
        (120.0, true),
        (127.0, false),
        (134.0, true),
        (160.0, true),
        (165.0, false),
        (170.0, true),
      ]) {
        expect(
          _lineNear(out, at, y, reach: line ? 2 : 1),
          line,
          reason: line ? 'a line at ($x, $y)' : 'no line between, ($x, $y)',
        );
      }
    }
    // The head and the hairline, over the top.
    for (var a = 1.25 * math.pi; a <= 1.75 * math.pi; a += .05) {
      final inner = r - 10 * -math.sin(a);
      final between = (r + inner) / 2;
      expect(
        _lineNear(out, cx + r * math.cos(a), cy + r * math.sin(a)),
        isTrue,
        reason: 'the head at ${(a * 180 / math.pi).round()} degrees',
      );
      expect(
        _lineNear(out, cx + inner * math.cos(a), cy + inner * math.sin(a)),
        isTrue,
        reason: 'the hairline at ${(a * 180 / math.pi).round()} degrees',
      );
      if (r - inner >= 8.5) {
        expect(
          _lineNear(
            out,
            cx + between * math.cos(a),
            cy + between * math.sin(a),
            reach: 1,
          ),
          isFalse,
          reason: 'between them at ${(a * 180 / math.pi).round()} degrees',
        );
      }
    }
  });

  test('a speck of paper inside a stroke is filled: one line, no loop', () {
    final rough = _Rough()..stroke([(30, 90), (190, 90)], 12);
    // Specks: 3 x 3, 2 x 4 and a single pixel.
    for (final (x0, y0, w, h) in [
      (80, 89, 3, 3),
      (110, 88, 2, 4),
      (140, 91, 1, 1),
    ]) {
      for (var y = y0; y < y0 + h; y++) {
        for (var x = x0; x < x0 + w; x++) {
          rough.rgba[(y * _w + x) * 4 + 3] = 0;
        }
      }
    }
    final out = _autoLineart(rough.rgba);
    _write('speck', rough.rgba, out);
    for (var x = 50; x <= 170; x += 2) {
      final at = x.toDouble();
      expect(_lineNear(out, at, 90), isTrue, reason: 'the line at $x');
      expect(_lineNear(out, at, 85, reach: 1), isFalse, reason: 'above, $x');
      expect(_lineNear(out, at, 95, reach: 1), isFalse, reason: 'below, $x');
    }
  });
}
