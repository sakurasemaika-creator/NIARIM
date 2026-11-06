import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/auto_lineart_engine.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

const _size = 256;

typedef _Pt = (double, double);

/// The centre lines of a rough: each shape is a polyline, drawn [_ink] px
/// wide with round ends and joins.
const _ink = 8.0;

List<_Pt> _quad(_Pt a, _Pt c, _Pt b) => [
  for (var t = 0.0; t <= 1.0001; t += 1 / 24)
    (
      (1 - t) * (1 - t) * a.$1 + 2 * (1 - t) * t * c.$1 + t * t * b.$1,
      (1 - t) * (1 - t) * a.$2 + 2 * (1 - t) * t * c.$2 + t * t * b.$2,
    ),
];

List<_Pt> _arc(double cx, double cy, double r, double from, double to) => [
  for (var a = from; a <= to + 1e-9; a += (to - from) / 48)
    (cx + r * math.cos(a), cy + r * math.sin(a)),
];

/// A character drawn as a rough: a round head, a hairline over it, a shirt
/// whose collar runs across the bottom of the head, two eyes and a smile.
final _head = _arc(115, 93, 60, 0, 2 * math.pi);
final _shirt = <_Pt>[
  (64, 145),
  (165, 145),
  (194, 217),
  ..._quad((194, 217), (115, 240), (35, 217)).skip(1),
  (64, 145),
];
final _hairOutline = <_Pt>[
  ..._quad((55, 95), (48, 20), (115, 27)),
  ..._quad((115, 27), (186, 20), (178, 98)).skip(1),
];
final _hair = <_Pt>[..._hairOutline, (145, 66), (114, 86), (94, 63), (55, 95)];
final _smile = _arc(115.5, 122, 13.5, .2, 2.9);
const _eyes = <_Pt>[(91, 104), (141, 104)];

/// [line] with its centre wobbling up to [amount] px to either side, the
/// way a hand-drawn stroke does ([seed] varies the wobble).
List<_Pt> _wobbled(List<_Pt> line, double amount, int seed) {
  var travelled = 0.0;
  return [
    for (var k = 0; k < line.length; k++)
      () {
        final (x, y) = line[k];
        final (px, py) = line[math.max(0, k - 1)];
        final (nx, ny) = line[math.min(line.length - 1, k + 1)];
        travelled += math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
        var tx = nx - px, ty = ny - py;
        final l = math.sqrt(tx * tx + ty * ty);
        if (l > 0) {
          tx /= l;
          ty /= l;
        }
        final off =
            amount *
            (math.sin(travelled / 9 + seed) * .6 +
                math.sin(travelled / 23 + seed * 2.3) * .4);
        return (x - ty * off, y + tx * off);
      }(),
  ];
}

/// The character's strokes (head, shirt, hair, smile), each wobbling by
/// [wobble] px.
List<List<_Pt>> _strokes(double wobble) => [
  _wobbled(_head, wobble, 2),
  _wobbled(_shirt, wobble, 1),
  _wobbled(_hair, wobble, 3),
  _wobbled(_smile, wobble, 4),
];

/// [lines] and the eyes drawn with a [width] px pen the way the canvas
/// strokes them: anti-aliased, with round ends and joins.
Future<Uint8List> _penRough(List<List<_Pt>> lines, double width) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()
    ..color = const ui.Color(0xff242739)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = ui.StrokeJoin.round
    ..strokeCap = ui.StrokeCap.round;
  for (final line in lines) {
    final path = ui.Path()..moveTo(line.first.$1, line.first.$2);
    for (final (x, y) in line.skip(1)) {
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }
  for (final (x, y) in _eyes) {
    canvas.drawCircle(ui.Offset(x, y), 4, ui.Paint()..color = paint.color);
  }
  final image = await recorder.endRecording().toImage(_size, _size);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

Uint8List _rough({double ink = _ink, List<List<_Pt>>? lines}) {
  final rgba = Uint8List(_size * _size * 4);
  void disc(double cx, double cy, double r) {
    for (var y = (cy - r - 1).floor(); y <= (cy + r + 1).ceil(); y++) {
      for (var x = (cx - r - 1).floor(); x <= (cx + r + 1).ceil(); x++) {
        final dx = x + .5 - cx, dy = y + .5 - cy;
        if (dx * dx + dy * dy > r * r) continue;
        final i = (y * _size + x) * 4;
        rgba
          ..[i] = 36
          ..[i + 1] = 39
          ..[i + 2] = 57
          ..[i + 3] = 255;
      }
    }
  }

  for (final line in lines ?? [_head, _shirt, _hair, _smile]) {
    for (var k = 0; k + 1 < line.length; k++) {
      final (ax, ay) = line[k];
      final (bx, by) = line[k + 1];
      final steps = (math.sqrt(math.pow(bx - ax, 2) + math.pow(by - ay, 2)) * 2)
          .ceil();
      for (var s = 0; s <= steps; s++) {
        final t = steps == 0 ? 0.0 : s / steps;
        disc(ax + (bx - ax) * t, ay + (by - ay) * t, ink / 2);
      }
    }
  }
  for (final (x, y) in _eyes) {
    disc(x, y, 4);
  }
  return rgba;
}

/// The distance from ([x], [y]) to the polyline [line].
double _toLine(List<_Pt> line, double x, double y) {
  var best = double.infinity;
  for (var k = 0; k + 1 < line.length; k++) {
    final (ax, ay) = line[k];
    final (bx, by) = line[k + 1];
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0
        ? 0.0
        : (((x - ax) * dx + (y - ay) * dy) / len2).clamp(0.0, 1.0);
    final ex = x - (ax + dx * t), ey = y - (ay + dy * t);
    best = math.min(best, math.sqrt(ex * ex + ey * ey));
  }
  return best;
}

/// 自動線画 keeps the rough's picture and only makes its lines thin: each
/// stroke comes out on its own centre line, without wobbling off it, and
/// where strokes cross or lie over each other they carry on as they were
/// drawn.
/// 自動線画 of [rough], as the filter applies it.
Uint8List _lineart(Uint8List rough) => applyDrawFilterInIsolate((
  rough,
  _size,
  _size,
  const FilterDef(
    id: 'Filter0023',
    name: '自動線画',
    kind: FilterKind.autoLineart,
    autoLineartRoughWidth: 12,
    autoLineartOutputWidth: 2,
    autoLineartTaperLength: 8,
    autoLineartSmoothing: 5,
  ),
  null,
));

/// How far the nearest line pixel of [out] is from ([x], [y]), up to
/// [reach].
double _nearestLine(Uint8List out, double x, double y, {int reach = 5}) {
  var best = double.infinity;
  for (var dy = -reach; dy <= reach; dy++) {
    for (var dx = -reach; dx <= reach; dx++) {
      final px = x.floor() + dx, py = y.floor() + dy;
      if (px < 0 || py < 0 || px >= _size || py >= _size) continue;
      if (out[(py * _size + px) * 4 + 3] <= 100) continue;
      final ex = px + .5 - x, ey = py + .5 - y;
      best = math.min(best, math.sqrt(ex * ex + ey * ey));
    }
  }
  return best;
}

/// Saves [rough] beside its 自動線画 [lines] (over the rough, faint) to
/// build/auto-lineart/[name], for review.
void _saveForReview(String name, Uint8List rough, Uint8List lines) {
  final sheet = img.Image(width: _size * 2 + 8, height: _size);
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final i = (y * _size + x) * 4;
      final r = (255 - 200 * rough[i + 3] / 255).round();
      sheet.setPixelRgb(x, y, r, r, r);
      final g = (255 - .25 * rough[i + 3]).round();
      final o = ((255 - lines[i + 3]) * g / 255).round();
      sheet.setPixelRgb(_size + 8 + x, y, o, o, o);
    }
  }
  final dir = Directory('build/auto-lineart')..createSync(recursive: true);
  File('${dir.path}/$name').writeAsBytesSync(img.encodePng(sheet));
}

void main() {
  final rough = _rough();
  final out = _lineart(rough);
  bool lineAt(int x, int y) => out[(y * _size + x) * 4 + 3] > 100;
  double nearestLine(double x, double y) => _nearestLine(out, x, y);

  test('drawn for review', () {
    _saveForReview('fidelity.png', rough, out);
  });

  /// Whether ([x], [y]) on [own] is more than [gap] px from the other
  /// strokes (with paper between them in the rough).
  bool alone(double x, double y, List<_Pt> own, {double gap = 12}) => [
    _head,
    _shirt,
    _hair,
    _smile,
  ].where((l) => !identical(l, own)).every((l) => _toLine(l, x, y) > gap);

  test('every stroke of the rough is there, on its own centre line', () {
    // Away from the tapered ends and the other strokes, each centre line has
    // the thin line within a pixel and a half all along: no wobble.
    for (final (name, line, samples) in [
      ('head', _head, 20),
      ('shirt', _shirt, 100),
      ('hair', _hair, 30),
      ('smile', _smile, 20),
    ]) {
      var checked = 0;
      for (var k = 0; k + 1 < line.length; k++) {
        final (ax, ay) = line[k];
        final (bx, by) = line[k + 1];
        for (var t = 0.0; t < 1; t += .25) {
          final x = ax + (bx - ax) * t, y = ay + (by - ay) * t;
          if (!alone(x, y, line)) continue;
          if (identical(line, _smile) &&
              (_toLine([line.first], x, y) < 6 ||
                  _toLine([line.last], x, y) < 6)) {
            continue;
          }
          checked++;
          expect(
            nearestLine(x, y),
            lessThan(1.6),
            reason: '$name at (${x.round()}, ${y.round()})',
          );
        }
      }
      expect(checked, greaterThan(samples), reason: name);
    }
  });

  test('no line is drawn off the rough\'s ink', () {
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        if (!lineAt(x, y)) continue;
        var inked = false;
        for (var dy = -1; dy <= 1 && !inked; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (rough[((y + dy) * _size + x + dx) * 4 + 3] != 0) {
              inked = true;
              break;
            }
          }
        }
        expect(inked, isTrue, reason: '($x, $y)');
      }
    }
  });

  test('the round head stays round where the collar and hair lie over it', () {
    // All the way round, under the hair and behind the collar too; where
    // its ink is apart from the others', on its own centre line.
    var apart = 0;
    for (var a = 0.0; a < 2 * math.pi; a += math.pi / 90) {
      final x = 115 + 60 * math.cos(a), y = 93 + 60 * math.sin(a);
      final own = alone(x, y, _head, gap: 9);
      if (own) apart++;
      expect(
        nearestLine(x, y),
        lessThan(own ? 1.6 : _ink / 2 + 1),
        reason: 'head at ${(a * 180 / math.pi).round()} degrees',
      );
    }
    expect(apart, greaterThan(60));
  });

  test('the collar runs straight across, the head\'s bottom round under '
      'it', () {
    for (var x = 70; x <= 160; x += 2) {
      expect(
        nearestLine(x.toDouble(), 145),
        lessThan(1.2),
        reason: 'collar at x = $x',
      );
    }
    for (var x = 100; x <= 130; x += 2) {
      final y = 93 + math.sqrt(3600 - math.pow(x - 115, 2));
      expect(
        nearestLine(x.toDouble(), y),
        lessThan(1.6),
        reason: 'head at x = $x',
      );
      // And nothing between them.
      expect(
        lineAt(x, ((145 + y) / 2).round()),
        isFalse,
        reason: 'between at x = $x',
      );
    }
  });

  test('the eyes are filled dots, not specks', () {
    for (final (ex, ey) in _eyes) {
      var count = 0;
      var sx = 0.0, sy = 0.0;
      for (var y = ey.floor() - 8; y <= ey.floor() + 8; y++) {
        for (var x = ex.floor() - 8; x <= ex.floor() + 8; x++) {
          if (!lineAt(x, y)) continue;
          count++;
          sx += x + .5;
          sy += y + .5;
        }
      }
      expect(count, greaterThanOrEqualTo(12), reason: 'eye at ($ex, $ey)');
      final cx = sx / count, cy = sy / count;
      expect(
        math.sqrt(math.pow(cx - ex, 2) + math.pow(cy - ey, 2)),
        lessThan(1),
        reason: 'eye at ($ex, $ey)',
      );
      for (final (dx, dy) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
        expect(
          lineAt((cx + dx).floor(), (cy + dy).floor()),
          isTrue,
          reason: 'eye at ($ex, $ey) + ($dx, $dy)',
        );
      }
    }
  });

  test('crossing strokes run straight on through the crossing, whichever '
      'way their pixels fall', () {
    for (final thickness in [6.0, 8.0, 10.0]) {
      for (final shift in [0.0, .3, .5]) {
        const w = 96;
        final x = Uint8List(w * w * 4);
        void stroke(double ax, double ay, double bx, double by) {
          final half = thickness / 2;
          for (var py = 0; py < w; py++) {
            for (var px = 0; px < w; px++) {
              final cx = px + .5, cy = py + .5;
              final dx = bx - ax, dy = by - ay;
              final t =
                  (((cx - ax) * dx + (cy - ay) * dy) / (dx * dx + dy * dy))
                      .clamp(0.0, 1.0);
              final ex = cx - ax - dx * t, ey = cy - ay - dy * t;
              if (ex * ex + ey * ey <= half * half) {
                x
                  ..[(py * w + px) * 4] = 20
                  ..[(py * w + px) * 4 + 3] = 255;
              }
            }
          }
        }

        stroke(14 + shift, 14, 82 + shift, 82);
        stroke(82 + shift, 14, 14 + shift, 82);
        final graph = AutoLineartEngine.analyze(x, w, w, roughWidthPx: 12);
        expect(
          graph.paths,
          hasLength(2),
          reason: 'two strokes, $thickness px, shifted $shift',
        );
        for (final path in graph.paths) {
          final first = path.points.first, last = path.points.last;
          // Each from one end of its stroke to the other.
          expect(
            math.sqrt(
              math.pow(last.x - first.x, 2) + math.pow(last.y - first.y, 2),
            ),
            greaterThan(68 * math.sqrt2 - thickness),
            reason: '$thickness px, shifted $shift',
          );
          for (final p in path.points) {
            final along = (first.x - last.x).sign == (first.y - last.y).sign
                ? (p.x - shift - p.y).abs()
                : (p.x - shift + p.y - 96).abs();
            expect(
              along / math.sqrt2,
              lessThan(1.5),
              reason: '$thickness px, shifted $shift: (${p.x}, ${p.y})',
            );
          }
        }
      }
    }
  });

  test('the hair outline stays its own line just outside the head, over the '
      'top and down both sides, with either pen', () {
    // Where the head's outline runs 4 to 9 px inside the hair outline (their
    // ink one band, or nearly), each is on its own centre line: neither
    // merged into one line down the middle nor crossing the other.
    for (final ink in [_ink, 6.0, 10.0]) {
      final lines = ink == _ink ? out : _lineart(_rough(ink: ink));
      var checked = 0;
      for (var k = 0; k + 1 < _hairOutline.length; k++) {
        final (ax, ay) = _hairOutline[k];
        final (bx, by) = _hairOutline[k + 1];
        for (var t = 0.0; t < 1; t += .25) {
          final x = ax + (bx - ax) * t, y = ay + (by - ay) * t;
          final dx = x - 115, dy = y - 93;
          final r = math.sqrt(dx * dx + dy * dy);
          if (r - 60 < 4 || r - 60 > 9) continue;
          checked++;
          expect(
            _nearestLine(lines, x, y),
            lessThan(1.6),
            reason: '$ink px: hair at (${x.round()}, ${y.round()})',
          );
          final hx = 115 + dx / r * 60, hy = 93 + dy / r * 60;
          expect(
            _nearestLine(lines, hx, hy),
            lessThan(1.6),
            reason: '$ink px: head inside it at (${hx.round()}, ${hy.round()})',
          );
        }
      }
      expect(checked, greaterThan(30), reason: '$ink px');
    }
  });

  test('a smile pressed on the collar by a thick pen stays a round smile, '
      'with no line down to the collar', () {
    for (final wobble in [0.0, 1.2]) {
      final strokes = _strokes(wobble);
      final pressed = _rough(ink: 10, lines: strokes);
      final lines = _lineart(pressed);
      if (wobble == 0) _saveForReview('thick_pen_smile.png', pressed, lines);
      final smile = strokes[3];
      for (final (x, y) in smile) {
        if (_toLine([smile.first], x, y) < 6 ||
            _toLine([smile.last], x, y) < 6) {
          continue;
        }
        expect(
          _nearestLine(lines, x, y),
          lessThan(1.6),
          reason: 'wobble $wobble: smile at (${x.round()}, ${y.round()})',
        );
      }
      for (var y = 139; y <= 141; y++) {
        for (var x = 106; x <= 126; x++) {
          expect(
            lines[(y * _size + x) * 4 + 3],
            lessThanOrEqualTo(100),
            reason: 'wobble $wobble: between smile and collar at ($x, $y)',
          );
        }
      }
    }
  });

  test('with a thick, wobbling pen the head runs on round past the slits of '
      'paper between it and the hair outline, with no hook off it', () async {
    final strokes = _strokes(1.2);
    final thick = await _penRough(strokes, 10);
    final lines = _lineart(thick);
    _saveForReview('thick_pen.png', thick, lines);
    final head = strokes[0], hair = strokes[2];
    for (final (x, y) in head) {
      if (y > 90) continue;
      expect(
        _nearestLine(lines, x, y),
        lessThan(1.6),
        reason: 'head at (${x.round()}, ${y.round()})',
      );
    }
    // Over the top, above the hairline, every line is on the head or the
    // hair outline (its soft edge within 3 px of their centre lines; the
    // hook was 5 px off).
    for (var y = 15; y < 60; y++) {
      for (var x = 40; x < 190; x++) {
        if (lines[(y * _size + x) * 4 + 3] <= 100) continue;
        expect(
          math.min(
            _toLine(head, x + .5, y + .5),
            _toLine(hair, x + .5, y + .5),
          ),
          lessThan(3),
          reason: '($x, $y)',
        );
      }
    }
  });

  test('the hairline runs on into the tips of the hair outline', () {
    for (final ((fx, fy), (tx, ty)) in const [
      ((94.0, 63.0), (55.0, 95.0)),
      ((145.0, 66.0), (178.0, 98.0)),
    ]) {
      for (final t in const [.7, .8, .9]) {
        final x = fx + (tx - fx) * t, y = fy + (ty - fy) * t;
        expect(
          nearestLine(x, y),
          lessThan(1.6),
          reason: 'hairline at (${x.round()}, ${y.round()})',
        );
      }
      expect(nearestLine(tx, ty), lessThan(3), reason: 'tip at ($tx, $ty)');
    }
  });

  test('strokes crossing at a slant run straight on through their shared '
      'ink', () {
    const angles = [15.0, 20.0, 30.0, 45.0, 60.0];
    // The strokes, for review: rough above, 自動線画 below, each angle cut
    // to the strokes' height.
    const top = 58, rows = 140;
    final sheet = img.Image(width: _size * angles.length, height: rows * 2);
    img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
    for (final (column, angle) in angles.indexed) {
      for (final thickness in [6.0, 8.0]) {
        const c = _size / 2, reach = 100.0;
        final rough = Uint8List(_size * _size * 4);
        final half = angle / 2 * math.pi / 180;
        final strokes = [
          (
            c - reach * math.cos(half),
            c - reach * math.sin(half),
            c + reach * math.cos(half),
            c + reach * math.sin(half),
          ),
          (
            c - reach * math.cos(half),
            c + reach * math.sin(half),
            c + reach * math.cos(half),
            c - reach * math.sin(half),
          ),
        ];
        double toStroke(int s, double px, double py) {
          final (ax, ay, bx, by) = strokes[s];
          final dx = bx - ax, dy = by - ay;
          final t = (((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
              .clamp(0.0, 1.0);
          final ex = px - ax - dx * t, ey = py - ay - dy * t;
          return math.sqrt(ex * ex + ey * ey);
        }

        for (var py = 0; py < _size; py++) {
          for (var px = 0; px < _size; px++) {
            if (toStroke(0, px + .5, py + .5) <= thickness / 2 ||
                toStroke(1, px + .5, py + .5) <= thickness / 2) {
              rough
                ..[(py * _size + px) * 4] = 20
                ..[(py * _size + px) * 4 + 3] = 255;
            }
          }
        }
        final graph = AutoLineartEngine.analyze(
          rough,
          _size,
          _size,
          roughWidthPx: 12,
        );
        final reason = '$angle°, $thickness px';
        expect(graph.paths, hasLength(2), reason: reason);
        for (final path in graph.paths) {
          final first = path.points.first, last = path.points.last;
          // Each from one end of a stroke to its other end, on it all along.
          expect(
            math.sqrt(
              math.pow(last.x - first.x, 2) + math.pow(last.y - first.y, 2),
            ),
            greaterThan(reach * 2 - thickness * 2),
            reason: reason,
          );
          final own =
              toStroke(0, first.x, first.y) < toStroke(1, first.x, first.y)
              ? 0
              : 1;
          for (final p in path.points) {
            expect(
              toStroke(own, p.x, p.y),
              lessThan(1.5),
              reason: '$reason: (${p.x}, ${p.y})',
            );
          }
        }
        if (thickness != 8) continue;
        final lines = _lineart(rough);
        for (var y = 0; y < rows; y++) {
          for (var x = 0; x < _size; x++) {
            final i = ((top + y) * _size + x) * 4;
            final r = (255 - 200 * rough[i + 3] / 255).round();
            sheet.setPixelRgb(column * _size + x, y, r, r, r);
            final g = (255 - .25 * rough[i + 3]).round();
            final o = ((255 - lines[i + 3]) * g / 255).round();
            sheet.setPixelRgb(column * _size + x, rows + y, o, o, o);
          }
        }
      }
    }
    final dir = Directory('build/auto-lineart')..createSync(recursive: true);
    File('${dir.path}/crossings.png').writeAsBytesSync(img.encodePng(sheet));
  });
}
