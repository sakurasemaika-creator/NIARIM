import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/lasso_region_snap_engine.dart';

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

  void dot(int x, int y) {
    for (var dy = 0; dy < 2; dy++) {
      for (var dx = 0; dx < 2; dx++) {
        rgba[((y + dy) * width + x + dx) * 4 + 3] = 255;
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

/// A hand-drawn-looking lasso: [waypoints] joined densely, with a wobble
/// across the direction of travel.
List<Offset> _roughLasso(List<Offset> waypoints, {double wobble = 3}) {
  final out = <Offset>[];
  var phase = 0.0;
  for (var i = 0; i < waypoints.length; i++) {
    final a = waypoints[i];
    final b = waypoints[(i + 1) % waypoints.length];
    final length = (b - a).distance;
    final steps = math.max(1, (length / 3).ceil());
    final normal = Offset(-(b - a).dy, (b - a).dx) / math.max(length, 1e-6);
    for (var k = 0; k < steps; k++) {
      phase += .45;
      out.add(
        Offset.lerp(a, b, k / steps)! + normal * (math.sin(phase) * wobble),
      );
    }
  }
  return out;
}

/// Writes the line art, the lasso as drawn (red) and the selection (tinted)
/// for a visual check.
void _writeEvidence(
  String name,
  _LineArt art,
  List<Offset> lasso,
  Uint8List? selection,
) {
  const scale = 3;
  final image = img.Image(width: art.width * scale, height: art.height * scale);
  for (var y = 0; y < art.height; y++) {
    for (var x = 0; x < art.width; x++) {
      final i = y * art.width + x;
      final selected = selection != null && selection[i] != 0;
      final color = art.isInk(x, y)
          ? (selected ? img.ColorRgb8(20, 60, 140) : img.ColorRgb8(20, 20, 20))
          : selected
          ? img.ColorRgb8(170, 210, 255)
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
  for (var i = 0; i < lasso.length; i++) {
    final a = lasso[i];
    final b = lasso[(i + 1) % lasso.length];
    img.drawLine(
      image,
      x1: (a.dx * scale).round(),
      y1: (a.dy * scale).round(),
      x2: (b.dx * scale).round(),
      y2: (b.dy * scale).round(),
      color: img.ColorRgb8(230, 40, 40),
      thickness: 2,
    );
  }
  final dir = Directory('build/lasso-snap')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(img.encodePng(image));
}

bool _on(Uint8List mask, int x, int y, [int width = 160]) =>
    mask[y * width + x] != 0;

void main() {
  test('a rough lasso around a figure selects it out to the outer edge of '
      'its outline, with the lines inside it, like a bucket fill', () {
    final art = _LineArt(160, 140);
    // The figure: a body with a collar line and a fold inside, and a 4px
    // outline.
    const body = [
      Offset(50, 30),
      Offset(110, 30),
      Offset(120, 110),
      Offset(40, 110),
    ];
    art.stroke(body, 4, closed: true);
    art.stroke(const [Offset(52, 50), Offset(108, 50)], 3);
    art.stroke(const [Offset(80, 60), Offset(70, 100)], 2);
    // Dots between the lasso and the figure, and a line crossing the lasso.
    art.dot(36, 70);
    art.dot(124, 70);
    art.dot(80, 20);
    art.stroke(const [Offset(130, 20), Offset(150, 130)], 2);
    final lasso = _roughLasso(const [
      Offset(30, 16),
      Offset(132, 14),
      Offset(140, 124),
      Offset(26, 126),
    ]);
    final selection = LassoRegionSnap.select(
      lasso: lasso,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
    );
    _writeEvidence('regions_bucket_edge', art, lasso, selection);
    expect(selection, isNotNull);
    final s = selection!;
    // Inside, the areas on both sides of the collar and the fold, and the
    // lines themselves.
    expect(_on(s, 80, 40), isTrue);
    expect(_on(s, 60, 80), isTrue);
    expect(_on(s, 100, 80), isTrue);
    expect(_on(s, 80, 50), isTrue, reason: 'the collar line');
    expect(_on(s, 75, 80), isTrue, reason: 'the fold');
    // Outside the figure: nothing, though the lasso went round it.
    for (final (x, y) in const [(36, 70), (124, 70), (80, 20), (33, 20)]) {
      expect(_on(s, x, y), isFalse, reason: '($x, $y) is outside the figure');
    }
    expect(_on(s, 136, 50), isFalse, reason: 'the line crossing the lasso');
    // The edge runs along the outer edge of the 4px outline: on the left
    // side the whole line is selected and nothing outside it.
    final row = [for (var x = 30; x < 60; x++) _on(s, x, 70)];
    final first = row.indexOf(true) + 30;
    expect(art.isInk(first, 70), isTrue, reason: 'the edge is on the line');
    expect(art.isInk(first - 1, 70), isFalse, reason: 'at its outer edge');
    // Every pixel of the outline, its corners included, is selected.
    for (var y = 27; y < 114; y++) {
      for (var x = 38; x < 124; x++) {
        if (!art.isInk(x, y) || (x - 80).abs() < 30 && y > 40 && y < 105) {
          continue;
        }
        expect(_on(s, x, y), isTrue, reason: 'outline at ($x, $y)');
      }
    }
  });

  test('of two shapes sharing a line, only the one mostly inside the lasso '
      'is taken, with the whole shared line, and the other\'s sides cut '
      'where they leave it', () {
    final art = _LineArt(160, 140);
    // A head on a body: they share the line at y = 60.
    art.stroke(
      const [Offset(60, 20), Offset(100, 20), Offset(100, 60), Offset(60, 60)],
      4,
      closed: true,
    );
    art.stroke(
      const [
        Offset(40, 60),
        Offset(120, 60),
        Offset(120, 120),
        Offset(40, 120),
      ],
      4,
      closed: true,
    );
    // A lasso round the body that also clips the bottom of the head.
    final lasso = _roughLasso(const [
      Offset(30, 48),
      Offset(130, 48),
      Offset(132, 130),
      Offset(28, 130),
    ]);
    final s = LassoRegionSnap.select(
      lasso: lasso,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
    )!;
    _writeEvidence('shared_line', art, lasso, s);
    expect(_on(s, 80, 90), isTrue, reason: 'the body');
    expect(_on(s, 80, 52), isFalse, reason: 'the head, though in the lasso');
    expect(_on(s, 80, 30), isFalse);
    // The shared line (y 58-61) belongs to the body's outline.
    expect(_on(s, 80, 61), isTrue);
    expect(_on(s, 80, 58), isTrue);
    // The head's sides run on up out of it: cut at the outline.
    for (final y in [40, 50, 55]) {
      expect(_on(s, 60, y), isFalse, reason: 'the head\'s side at y $y');
      expect(_on(s, 100, y), isFalse, reason: 'the head\'s side at y $y');
    }
  });

  test('a coloured shape: the fill with its border out to the outer edge, '
      'the line sticking out of it cut off, nothing round it', () {
    // A light blue fill with a blue border and a blue line sticking up out
    // of its top, on a transparent layer, and the same flattened on white.
    const width = 160, height = 140;
    for (final flat in [false, true]) {
      final rgba = Uint8List(width * height * 4);
      if (flat) rgba.fillRange(0, rgba.length, 255);
      void paint(int x, int y, List<int> c) =>
          rgba.setAll((y * width + x) * 4, [...c, 255]);
      bool border(int x, int y) =>
          x >= 40 &&
          x < 120 &&
          y >= 40 &&
          y < 110 &&
          (x < 44 || x >= 116 || y < 44 || y >= 106);
      bool stub(int x, int y) => x >= 78 && x < 82 && y >= 10 && y < 75;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (border(x, y) || stub(x, y)) {
            paint(x, y, const [30, 110, 220]);
          } else if (x >= 44 && x < 116 && y >= 44 && y < 106) {
            paint(x, y, const [150, 240, 250]);
          }
        }
      }
      final lasso = _roughLasso(const [
        Offset(28, 24),
        Offset(132, 22),
        Offset(134, 122),
        Offset(26, 124),
      ]);
      final s = LassoRegionSnap.select(
        lasso: lasso,
        rgba: rgba,
        width: width,
        height: height,
      )!;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final inShape = x >= 40 && x < 120 && y >= 40 && y < 110;
          if (inShape) {
            expect(_on(s, x, y), isTrue, reason: 'flat $flat: ($x, $y)');
          } else if (!stub(x, y) || y < 37) {
            expect(_on(s, x, y), isFalse, reason: 'flat $flat: ($x, $y)');
          }
        }
      }
    }
  });

  test('the gap tolerance closes a break in the outline, like a bucket '
      'fill\'s gap closing', () {
    final art = _LineArt(140, 120);
    // A square outline with a 4px break (rows 58-61) in its right side.
    art.stroke(const [Offset(30, 30), Offset(110, 30), Offset(110, 58)], 3);
    art.stroke(const [
      Offset(110, 64),
      Offset(110, 90),
      Offset(30, 90),
      Offset(30, 30),
    ], 3);
    final lasso = _roughLasso(const [
      Offset(18, 18),
      Offset(122, 18),
      Offset(122, 102),
      Offset(18, 102),
    ]);
    Uint8List? withGap(int tolerance) => LassoRegionSnap.select(
      lasso: lasso,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
      gapTolerancePx: tolerance,
    );
    final closed = withGap(6)!;
    _writeEvidence('gap_closed', art, lasso, closed);
    expect(_on(closed, 70, 60, 140), isTrue);
    expect(_on(closed, 120, 60, 140), isFalse, reason: 'outside the break');
    expect(
      _on(closed, 109, 60, 140),
      isTrue,
      reason: 'the inner half of the break',
    );
    // Too small a tolerance: the inside runs out through the break into the
    // surroundings, which lie mostly outside the lasso, so there is nothing
    // to snap to and the lasso is taken as drawn.
    final open = withGap(2);
    _writeEvidence('gap_open', art, lasso, open);
    expect(open, isNull);
  });

  test('a lasso round almost the whole canvas still takes only the figure, '
      'not the paper round it', () {
    final art = _LineArt(120, 100);
    art.stroke(
      const [Offset(40, 30), Offset(80, 30), Offset(80, 70), Offset(40, 70)],
      3,
      closed: true,
    );
    final lasso = _roughLasso(const [
      Offset(4, 4),
      Offset(116, 4),
      Offset(116, 96),
      Offset(4, 96),
    ], wobble: 1.5);
    final s = LassoRegionSnap.select(
      lasso: lasso,
      rgba: art.rgba,
      width: art.width,
      height: art.height,
    )!;
    _writeEvidence('whole_canvas_lasso', art, lasso, s);
    expect(_on(s, 60, 50, 120), isTrue);
    expect(_on(s, 20, 50, 120), isFalse, reason: 'the paper round it');
    expect(_on(s, 100, 90, 120), isFalse, reason: 'the paper round it');
  });

  test('with no line inside the lasso, the lasso is taken as drawn', () {
    final art = _LineArt(80, 80);
    art.stroke(const [Offset(70, 0), Offset(70, 80)], 3);
    final lasso = _roughLasso(const [
      Offset(10, 10),
      Offset(50, 10),
      Offset(50, 50),
      Offset(10, 50),
    ]);
    expect(
      LassoRegionSnap.select(
        lasso: lasso,
        rgba: art.rgba,
        width: art.width,
        height: art.height,
      ),
      isNull,
    );
  });

  test('a flattened reference on white paper reads only the dark lines', () {
    const width = 60, height = 60;
    final rgba = Uint8List(width * height * 4)
      ..fillRange(0, width * height * 4, 255);
    for (var y = 15; y <= 45; y++) {
      for (var x = 15; x <= 45; x++) {
        if (x <= 16 || x >= 44 || y <= 16 || y >= 44) {
          final i = (y * width + x) * 4;
          rgba[i] = rgba[i + 1] = rgba[i + 2] = 20;
        }
      }
    }
    final lasso = _roughLasso(const [
      Offset(6, 6),
      Offset(54, 6),
      Offset(54, 54),
      Offset(6, 54),
    ], wobble: 1);
    final s = LassoRegionSnap.select(
      lasso: lasso,
      rgba: rgba,
      width: width,
      height: height,
    )!;
    expect(_on(s, 30, 30, width), isTrue);
    expect(_on(s, 10, 30, width), isFalse);
  });

  test('the lasso mask covers pixels whose centres are inside', () {
    final mask = LassoRegionSnap.polygonMask(
      const [Offset(2, 2), Offset(6, 2), Offset(6, 5), Offset(2, 5)],
      8,
      8,
    );
    final rows = [
      for (var y = 0; y < 8; y++)
        [for (var x = 0; x < 8; x++) mask[y * 8 + x]].join(),
    ];
    expect(rows, [
      '00000000',
      '00000000',
      '00111100',
      '00111100',
      '00111100',
      '00000000',
      '00000000',
      '00000000',
    ]);
  });
}
