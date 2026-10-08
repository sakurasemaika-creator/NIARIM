import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/lasso_line_snap_engine.dart';

/// Line art on a transparent layer, drawn with round-capped strokes.
class _LineArt {
  _LineArt(this.width, this.height) : rgba = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Uint8List rgba;

  void stroke(List<Offset> points, double thickness, {bool closed = false}) {
    final segments = [
      for (var i = 0; i + 1 < points.length; i++) (points[i], points[i + 1]),
      if (closed) (points.last, points.first),
    ];
    final half = thickness / 2;
    for (final (a, b) in segments) {
      final minX = math.max(0, (math.min(a.dx, b.dx) - half).floor());
      final maxX = math.min(width - 1, (math.max(a.dx, b.dx) + half).ceil());
      final minY = math.max(0, (math.min(a.dy, b.dy) - half).floor());
      final maxY = math.min(height - 1, (math.max(a.dy, b.dy) + half).ceil());
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          final p = Offset(x + .5, y + .5);
          if (_distanceToSegment(p, a, b) <= half) {
            rgba[(y * width + x) * 4 + 3] = 255;
          }
        }
      }
    }
  }

  bool isInk(int x, int y) => rgba[(y * width + x) * 4 + 3] > 0;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
  if (lengthSquared == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).distance;
}

double _distanceToPolyline(
  Offset p,
  List<Offset> points, {
  bool closed = true,
}) {
  var best = double.infinity;
  for (var i = 0; i < points.length; i++) {
    if (!closed && i + 1 == points.length) break;
    final b = points[(i + 1) % points.length];
    best = math.min(best, _distanceToSegment(p, points[i], b));
  }
  return best;
}

/// Pixels whose centres lie inside [polygon] (even-odd), like the canvas's
/// lasso selection.
List<bool> _polygonMask(List<Offset> polygon, int width, int height) {
  final mask = List<bool>.filled(width * height, false);
  for (var y = 0; y < height; y++) {
    final cy = y + .5;
    final crossings = <double>[];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if ((a.dy <= cy) == (b.dy <= cy)) continue;
      crossings.add(a.dx + (cy - a.dy) / (b.dy - a.dy) * (b.dx - a.dx));
    }
    crossings.sort();
    for (var k = 0; k + 1 < crossings.length; k += 2) {
      for (var x = 0; x < width; x++) {
        final cx = x + .5;
        if (cx >= crossings[k] && cx < crossings[k + 1]) {
          mask[y * width + x] = true;
        }
      }
    }
  }
  return mask;
}

double _iou(List<bool> a, List<bool> b) {
  var both = 0, either = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] && b[i]) both++;
    if (a[i] || b[i]) either++;
  }
  return either == 0 ? 1 : both / either;
}

/// A hand-drawn-looking guide: [waypoints] joined densely, with a small
/// wobble across the direction of travel.
List<Offset> _roughGuide(List<Offset> waypoints, {double wobble = 2}) {
  final out = <Offset>[];
  var phase = 0.0;
  for (var i = 0; i < waypoints.length; i++) {
    final a = waypoints[i];
    final b = waypoints[(i + 1) % waypoints.length];
    final length = (b - a).distance;
    final steps = math.max(1, (length / 3).ceil());
    final normal = Offset(-(b - a).dy, (b - a).dx) / math.max(length, 1e-6);
    for (var k = 0; k < steps; k++) {
      phase += .35;
      out.add(
        Offset.lerp(a, b, k / steps)! + normal * (math.sin(phase) * wobble),
      );
    }
  }
  out.add(out.first);
  return out;
}

/// Writes the fixture, the user's guide (red), the snapped boundary (blue)
/// and the resulting selection (tinted) for a visual check.
void _writeEvidence(
  String name,
  _LineArt art,
  List<Offset> guide,
  List<Offset> snapped,
  List<bool> selection,
) {
  const scale = 3;
  final image = img.Image(width: art.width * scale, height: art.height * scale);
  for (var y = 0; y < art.height; y++) {
    for (var x = 0; x < art.width; x++) {
      final i = y * art.width + x;
      final color = art.isInk(x, y)
          ? img.ColorRgb8(20, 20, 20)
          : selection[i]
          ? img.ColorRgb8(196, 226, 255)
          : img.ColorRgb8(255, 255, 255);
      img.fillRect(
        image,
        x1: x * scale,
        y1: y * scale,
        x2: x * scale + scale - 1,
        y2: y * scale + scale - 1,
        color: color,
      );
    }
  }
  void polyline(List<Offset> points, img.Color color) {
    for (var i = 0; i + 1 < points.length; i++) {
      img.drawLine(
        image,
        x1: (points[i].dx * scale).round(),
        y1: (points[i].dy * scale).round(),
        x2: (points[i + 1].dx * scale).round(),
        y2: (points[i + 1].dy * scale).round(),
        color: color,
        thickness: 2,
      );
    }
  }

  polyline(guide, img.ColorRgb8(230, 40, 40));
  polyline([...snapped, snapped.first], img.ColorRgb8(30, 90, 230));
  final dir = Directory('build/lasso-snap')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(img.encodePng(image));
}

void main() {
  const engine = LassoLineSnapEngine();

  test('follows the contour straight through a perpendicular crossing', () {
    final art = _LineArt(80, 80)
      ..stroke([const Offset(5, 40.5), const Offset(75, 40.5)], 1)
      ..stroke([const Offset(40.5, 5), const Offset(40.5, 75)], 1);
    final guide = [for (var x = 8; x <= 72; x += 4) Offset(x.toDouble(), 43)];
    final snapped = engine.snapPath(
      guide: guide,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      radius: 8,
    );

    expect(snapped, isNotEmpty);
    for (final p in snapped) {
      expect(p.dy, closeTo(40.5, 1), reason: 'left the contour at $p');
    }
    for (var i = 1; i < snapped.length; i++) {
      expect(snapped[i].dx, greaterThanOrEqualTo(snapped[i - 1].dx));
    }
  });

  test('a coarse rectangle is pulled onto the nearby square', () {
    final square = [
      const Offset(16.5, 16.5),
      const Offset(48.5, 16.5),
      const Offset(48.5, 48.5),
      const Offset(16.5, 48.5),
    ];
    final art = _LineArt(64, 64)..stroke(square, 1, closed: true);
    final guide = _roughGuide([
      const Offset(13, 13),
      const Offset(51, 13),
      const Offset(51, 51),
      const Offset(13, 51),
    ], wobble: .5);
    final snapped = engine.snapPath(
      guide: guide,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      radius: 6,
    );
    final onSquare = snapped.where((p) => _distanceToPolyline(p, square) <= 1);
    expect(onSquare.length / snapped.length, greaterThan(.9));
  });

  test('with no line in reach the guide itself is kept', () {
    final art = _LineArt(64, 64);
    final guide = [for (var x = 10; x <= 50; x += 2) Offset(x.toDouble(), 30)];
    final snapped = engine.snapPath(
      guide: guide,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      radius: 6,
    );
    for (final p in snapped) {
      expect(p.dy, 30);
    }
  });

  test('line art with internal lines: one region is selected along its own '
      'lines, past a crossing stroke', () {
    const size = 200, cx = 100.0, cy = 100.0, r = 80.0;
    final circle = [
      for (var k = 0; k < 120; k++)
        Offset(
          cx + r * math.cos(k * math.pi * 2 / 120),
          cy + r * math.sin(k * math.pi * 2 / 120),
        ),
    ];
    final art = _LineArt(size, size)
      ..stroke(circle, 3, closed: true)
      // Internal lines split the disc into four regions.
      ..stroke([const Offset(cx - r, cy), const Offset(cx + r, cy)], 3)
      ..stroke([const Offset(cx, cy - r), const Offset(cx, cy + r)], 3)
      // A fold line crossing the arc of the selected region at right angles.
      ..stroke([
        Offset(
          cx + 60 * math.cos(math.pi / 4),
          cy + 60 * math.sin(math.pi / 4),
        ),
        Offset(
          cx + 98 * math.cos(math.pi / 4),
          cy + 98 * math.sin(math.pi / 4),
        ),
      ], 3);
    // The user traces the lower-right region roughly, a few px inside it.
    final guide = _roughGuide([
      const Offset(cx + 7, cy + 7),
      const Offset(cx + 72, cy + 7),
      for (var k = 1; k < 9; k++)
        Offset(
          cx + 72 * math.cos(k * math.pi / 18),
          cy + 72 * math.sin(k * math.pi / 18) + 7 * (1 - k / 9),
        ),
      const Offset(cx + 7, cy + 72),
    ]);
    final snapped = engine.snapPath(
      guide: guide,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      radius: 16,
    );

    final expected = List<bool>.generate(size * size, (i) {
      final p = Offset(i % size + .5, i ~/ size + .5);
      return p.dx >= cx &&
          p.dy >= cy &&
          (p - const Offset(cx, cy)).distance <= r;
    });
    final selection = _polygonMask(snapped, size, size);
    _writeEvidence(
      'regions_and_internal_lines',
      art,
      guide,
      snapped,
      selection,
    );
    expect(_iou(selection, expected), greaterThan(.97));
    // Nothing of the boundary wanders off along the crossing fold line.
    final fold = [
      Offset(cx + 60 * math.cos(math.pi / 4), cy + 60 * math.sin(math.pi / 4)),
      Offset(cx + 98 * math.cos(math.pi / 4), cy + 98 * math.sin(math.pi / 4)),
    ];
    final onFoldOnly = snapped.where(
      (p) =>
          _distanceToPolyline(p, fold, closed: false) < 2 &&
          ((p - const Offset(cx, cy)).distance - r).abs() > 4,
    );
    expect(onFoldOnly, isEmpty);
  });

  test('clothing enclosed roughly from outside snaps to its outer contour, '
      'not to the seams, pocket or buttons inside', () {
    const size = 240;
    const shirt = [
      Offset(95, 40), Offset(60, 50), Offset(20, 95), Offset(35, 115), //
      Offset(70, 95), Offset(72, 210), Offset(168, 210), Offset(170, 95),
      Offset(205, 115), Offset(220, 95), Offset(180, 50), Offset(145, 40),
      Offset(120, 70),
    ];
    final art = _LineArt(size, size)
      ..stroke(shirt, 4, closed: true)
      ..stroke([const Offset(60, 50), const Offset(70, 95)], 3)
      ..stroke([const Offset(180, 50), const Offset(170, 95)], 3)
      ..stroke([const Offset(120, 70), const Offset(120, 206)], 3)
      ..stroke(
        [
          const Offset(135, 120),
          const Offset(155, 120),
          const Offset(155, 140),
          const Offset(135, 140),
        ],
        3,
        closed: true,
      );
    // A loose loop 8-16 px outside the shirt, as a finger would draw it.
    final guide = _roughGuide([
      const Offset(95, 29),
      const Offset(55, 39),
      const Offset(9, 93),
      const Offset(32, 128),
      const Offset(60, 110),
      const Offset(60, 222),
      const Offset(180, 222),
      const Offset(181, 110),
      const Offset(208, 128),
      const Offset(232, 93),
      const Offset(186, 39),
      const Offset(145, 29),
      const Offset(120, 58),
    ], wobble: 2.5);
    final snapped = engine.snapPath(
      guide: guide,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      radius: 22,
    );

    final expected = _polygonMask(shirt, size, size);
    final selection = _polygonMask(snapped, size, size);
    _writeEvidence('clothing_rough_enclosure', art, guide, snapped, selection);
    expect(_iou(selection, expected), greaterThan(.98));
    final onContour = snapped.where((p) => _distanceToPolyline(p, shirt) <= 3);
    expect(onContour.length / snapped.length, greaterThan(.97));
  });

  test('lines that cross the lasso itself do not pull the boundary out along '
      'them', () {
    const size = 400, centre = Offset(200, 200), r = 150.0;
    final art = _LineArt(size, size)
      ..stroke(
        [
          for (var k = 0; k < 160; k++)
            centre + Offset.fromDirection(k * math.pi * 2 / 160, r),
        ],
        4,
        closed: true,
      );
    // Spokes through the middle that run on past the circle and under the
    // finger's path.
    for (var k = 0; k < 4; k++) {
      final direction = Offset.fromDirection(k * math.pi / 2);
      art.stroke([centre, centre + direction * 185], 4);
    }
    final guide = [
      for (var k = 0; k <= 240; k++)
        centre +
            Offset.fromDirection(
              k * math.pi * 2 / 240,
              165 + 8 * math.sin(k * .3),
            ),
    ];
    final snapped = engine.snapPath(
      guide: guide,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      radius: 24,
    );
    final onCircle = snapped.where(
      (p) => ((p - centre).distance - r).abs() <= 3,
    );
    expect(onCircle.length / snapped.length, greaterThan(.97));
    final expected = List<bool>.generate(
      size * size,
      (i) => (Offset(i % size + .5, i ~/ size + .5) - centre).distance <= r,
    );
    final selection = _polygonMask(snapped, size, size);
    _writeEvidence('lines_crossing_the_lasso', art, guide, snapped, selection);
    expect(_iou(selection, expected), greaterThan(.98));
  });

  test('small gaps between line-art segments are bridged naturally', () {
    final art = _LineArt(100, 80)
      ..stroke([const Offset(12, 40.5), const Offset(46, 40.5)], 2)
      ..stroke([const Offset(51, 40.5), const Offset(88, 40.5)], 2);
    final guide = [
      for (var x = 10; x <= 90; x += 2) Offset(x.toDouble(), 45),
    ];
    final snapped = engine.snapPath(
      guide: guide,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      radius: 10,
    );
    final gapPoints = snapped.where((p) => p.dx >= 45 && p.dx <= 53);
    expect(gapPoints, isNotEmpty);
    expect(
      gapPoints.every((p) => (p.dy - 40.5).abs() <= 2.0),
      isTrue,
      reason: 'the selection boundary should cross the small line-art gap '
          'without jumping away from the contour',
    );
  });

  test('the live preview is the final route, closed at the end', () {
    final art = _LineArt(80, 80)
      ..stroke([const Offset(5, 40.5), const Offset(75, 40.5)], 2);
    final guide = [for (var x = 8; x <= 72; x += 3) Offset(x.toDouble(), 45)];
    final tracker = LassoLineSnapTracker(
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      radius: 8,
    );
    guide.forEach(tracker.add);
    expect(
      tracker.closedPath,
      engine.snapPath(
        guide: guide,
        rgba: art.rgba,
        width: art.width,
        height: art.height,
        radius: 8,
      ),
    );
  });

  test('lasso selection exposes a dedicated snap checkbox only for lasso '
      'mode', () {
    final source = File(
      'lib/screens/canvas/canvas_screen.dart',
    ).readAsStringSync();
    expect(source, contains("ValueKey('lasso-snap-to-lines')"));
    expect(source, contains('_currentTool == DrawingTool.selectLasso'));
    expect(source, contains('l10n.canvasLassoSnapToLines'));
  });
}
