// Along a 「三日月カール」 curl, the inner edge bends the same way as the
// stroke and its outer edge, whatever the brush size, pressure or taper, and
// the folded crescent stays: a fold line inside the strand, along its outer
// side, that bends with the curl too.
//
// A curl drawn like 「し」 used to thin to a waist near its tip and swell
// again: the end of the last crescent changed back to the ordinary strand
// over at most 60 degrees of turn, while the crescent's bow had run out long
// before, so the inner edge turned against the curve. A thicker brush or
// pressure rising towards the tip made the lump larger. The waist and the
// lobe after it are the folded crescent's own look, which the strand now
// keeps as its fold line instead of as its silhouette.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

typedef _Sample = (ui.Offset, double);

/// A stroke and the circle its curl follows.
class _Curl {
  final String name;
  final int width, height;
  final List<_Sample> samples;
  final ui.Offset centre;
  final double radius;

  /// The curl's angles around [centre] (screen angles, degrees), in drawing
  /// order.
  final double from, to;
  const _Curl(
    this.name,
    this.width,
    this.height,
    this.samples,
    this.centre,
    this.radius,
    this.from,
    this.to,
  );
}

double _flat(double t) => 1;

/// Light at the start, pressing harder towards the tip.
double _rising(double t) => .35 + .65 * t;

/// Pressing harder just before the tip, then lifting.
double _late(double t) =>
    t < .6 ? .6 : .6 + .4 * math.sin(math.pi * (t - .6) / .4);

/// Straight down, then round a circle to the right and up past half a turn,
/// like 「し」.
_Curl _shi(double Function(double) pressure, {bool reversed = false}) {
  const x0 = 160.0, y0 = 60.0, down = 340.0, r = 110.0;
  final points = <ui.Offset>[
    for (var i = 0; i <= 60; i++) ui.Offset(x0, y0 + down * i / 60),
    for (var i = 1; i <= 90; i++)
      ui.Offset(
        x0 + r + r * math.cos(math.pi - 1.2 * math.pi * i / 90),
        y0 + down + r * math.sin(math.pi - 1.2 * math.pi * i / 90),
      ),
  ];
  final ordered = reversed ? points.reversed.toList() : points;
  return _Curl(
    reversed ? 'reversed し' : 'し',
    500,
    620,
    [
      for (var i = 0; i < ordered.length; i++)
        (ordered[i], pressure(i / (ordered.length - 1))),
    ],
    const ui.Offset(x0 + r, y0 + down),
    r,
    reversed ? -36 : 180,
    reversed ? 180 : -36,
  );
}

/// A C from its top, clockwise round to a little past its bottom.
_Curl _c(double Function(double) pressure) {
  const r = 110.0, centre = ui.Offset(200, 200);
  return _Curl(
    'C',
    400,
    400,
    [
      for (var i = 0; i <= 120; i++)
        (
          centre +
              ui.Offset.fromDirection(
                -math.pi / 2 + math.pi * 1.2 * i / 120,
                r,
              ),
          pressure(i / 120),
        ),
    ],
    centre,
    r,
    -90,
    126,
  );
}

Future<Uint8List> _draw(
  WidgetTester tester,
  Brush brush,
  _Curl curl, {
  required bool pressure,
}) async {
  final tiles = TileManager(canvasWidth: curl.width, canvasHeight: curl.height);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xff8a5a44)
    ..pressureEnabled = pressure;
  StrokePoint p(_Sample s) =>
      StrokePoint(x: s.$1.dx, y: s.$1.dy, pressure: s.$2, tiltX: 0, tiltY: 0);
  tiles.beginUndoRecording('hair');
  engine.beginStroke(p(curl.samples.first), 'hair');
  for (final sample in curl.samples.skip(1)) {
    engine.continueStroke(p(sample), 'hair');
  }
  if (engine.needsFinalFadeReplay) {
    final preview = tiles.endUndoRecording();
    tiles.applyTileSnapshot('hair', preview.before);
    tiles.beginUndoRecording('hair');
    engine.replayCurrentStrokeWithFinalFade();
  }
  engine.endStroke();
  tiles.endUndoRecording();
  final pixels = (await tester.runAsync(() async {
    final image = await tiles.compositeLayerToImage('hair');
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return Uint8List.fromList(data!.buffer.asUint8List());
  }))!;
  tiles.dispose();
  return pixels;
}

double _coverageAt(Uint8List rgba, _Curl curl, double x, double y) {
  final x0 = x.floor(), y0 = y.floor();
  final fx = x - x0, fy = y - y0;
  double at(int px, int py) =>
      px < 0 || py < 0 || px >= curl.width || py >= curl.height
      ? 0
      : rgba[(py * curl.width + px) * 4 + 3] / 255;
  return at(x0, y0) * (1 - fx) * (1 - fy) +
      at(x0 + 1, y0) * fx * (1 - fy) +
      at(x0, y0 + 1) * (1 - fx) * fy +
      at(x0 + 1, y0 + 1) * fx * fy;
}

/// Brightness (0-255) of the ink at a point, from its premultiplied colour,
/// between pixels by interpolation like [_coverageAt].
double _brightnessAt(Uint8List rgba, _Curl curl, double x, double y) {
  final x0 = x.floor(), y0 = y.floor();
  final fx = x - x0, fy = y - y0;
  double at(int px, int py) {
    if (px < 0 || py < 0 || px >= curl.width || py >= curl.height) return 0;
    final i = (py * curl.width + px) * 4;
    return .299 * rgba[i] + .587 * rgba[i + 1] + .114 * rgba[i + 2];
  }

  return at(x0, y0) * (1 - fx) * (1 - fy) +
      at(x0 + 1, y0) * fx * (1 - fy) +
      at(x0, y0 + 1) * (1 - fx) * fy +
      at(x0 + 1, y0 + 1) * fx * fy;
}

/// The angles along the curl, a whole degree apart, in drawing order.
List<double> _angles(_Curl curl) {
  final step = curl.to > curl.from ? 1.0 : -1.0;
  final count = ((curl.to - curl.from) / step).round();
  return [for (var i = 0; i <= count; i++) curl.from + i * step];
}

/// From the curl's centre, where each ray meets the ink's inner edge (its
/// coverage crossing a half, between pixels by interpolation); null where
/// the strand is less than 6px across.
List<double?> _innerRadii(Uint8List rgba, _Curl curl) => [
  for (final degrees in _angles(curl))
    () {
      final direction = ui.Offset.fromDirection(degrees * math.pi / 180);
      double? entry;
      var previous = _coverageAt(rgba, curl, curl.centre.dx, curl.centre.dy);
      for (var d = .1; d < curl.radius * 2; d += .1) {
        final q = curl.centre + direction * d;
        final value = _coverageAt(rgba, curl, q.dx, q.dy);
        if (entry == null && previous < .5 && value >= .5) {
          entry = d - .1 + .1 * (.5 - previous) / (value - previous);
        } else if (entry != null && previous >= .5 && value < .5) {
          return d - entry >= 6 ? entry : null;
        }
        previous = value;
      }
      return null;
    }(),
];

/// From the curl's centre, where each ray crosses a fold line: a run of the
/// outline's dark colour inside the strand, with at least a pixel of fill on
/// both sides of it (past the inner edge's outline, short of the outer
/// edge's); null where the ray crosses none.
List<double?> _foldRadii(Uint8List rgba, _Curl curl) => [
  for (final degrees in _angles(curl))
    () {
      const step = .25, clear = 4;
      final direction = ui.Offset.fromDirection(degrees * math.pi / 180);
      // Along the ray through the strand: each sample's brightness.
      final light = <double>[];
      double? from;
      for (var d = step; d < curl.radius * 2; d += step) {
        final q = curl.centre + direction * d;
        final inside = _coverageAt(rgba, curl, q.dx, q.dy) >= .9;
        if (!inside) {
          if (from != null) break;
          continue;
        }
        from ??= d;
        light.add(_brightnessAt(rgba, curl, q.dx, q.dy));
      }
      final dark = [for (final value in light) value < 50];
      if (from == null) return null;
      // The first and last fill, inside the edges' outlines.
      final first = dark.indexOf(false), last = dark.lastIndexOf(false);
      if (first < 0) return null;
      var i = first;
      while (i <= last) {
        if (!dark[i]) {
          i++;
          continue;
        }
        final start = i;
        while (i <= last && dark[i]) {
          i++;
        }
        var before = 0, after = 0;
        while (before < clear &&
            start - 1 - before >= 0 &&
            !dark[start - 1 - before]) {
          before++;
        }
        while (after < clear && i + after <= last && !dark[i + after]) {
          after++;
        }
        if (before == clear && after == clear) {
          // Where the brightness crosses into and out of the run, between
          // samples.
          double crossing(int a, int b) =>
              a + (b - a) * (light[a] - 50) / (light[a] - light[b]);
          return from +
              step * (crossing(start - 1, start) + crossing(i, i - 1)) / 2;
        }
      }
      return null;
    }(),
];

/// The least curvature of a line given by its distance from the curl's
/// centre along each ray ([radii]), relative to the curl's own (1 for a line
/// parallel to the curl, below 0 where it bends against it), with the angle
/// where it is least.
///
/// A parabola fitted to the distance over at least 13 degrees and 24px of
/// the line gives its curvature, so pixel steps do not read as bends.
(double, double) _leastCurvature(List<double?> radii, _Curl curl) {
  final angles = _angles(curl);
  final count = angles.length - 1;
  var least = (double.infinity, 0.0);
  for (var i = 0; i <= count; i++) {
    final middle = radii[i];
    if (middle == null) continue;
    // At least 6 degrees and 12px of the line either side.
    final half = math.max(6, (12 / middle * 180 / math.pi).ceil());
    if (i < half || i > count - half) continue;
    var complete = true;
    // Least squares rho = a + b u + c u^2 over u in radians; the samples
    // are symmetric about u = 0, so the odd sums vanish.
    var s0 = 0.0, s2 = 0.0, s4 = 0.0;
    var t0 = 0.0, t1 = 0.0, t2 = 0.0;
    for (var j = -half; j <= half; j++) {
      final rho = radii[i + j];
      if (rho == null) {
        complete = false;
        break;
      }
      final u = j * math.pi / 180;
      s0 += 1;
      s2 += u * u;
      s4 += u * u * u * u;
      t0 += rho;
      t1 += rho * u;
      t2 += rho * u * u;
    }
    if (!complete) continue;
    final c = (t2 * s0 - t0 * s2) / (s4 * s0 - s2 * s2);
    final a = (t0 - c * s2) / s0;
    final b = t1 / s2;
    final rho = a, rho1 = b, rho2 = 2 * c;
    final curvature =
        (rho * rho + 2 * rho1 * rho1 - rho * rho2) /
        math.pow(rho * rho + rho1 * rho1, 1.5);
    // Relative to a circle round the same centre through this point.
    final relative = curvature * rho;
    if (relative < least.$1) least = (relative, angles[i]);
  }
  return least;
}

/// The most whole degrees in a row a line was found on.
int _longestRun(List<double?> radii) {
  var longest = 0, run = 0;
  for (final rho in radii) {
    run = rho == null ? 0 : run + 1;
    longest = math.max(longest, run);
  }
  return longest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final crescent = brushExtensionPresets().singleWhere(
    (b) => b.id == 'Brush0035',
  );
  Brush sized(double scale) => crescent.copyWith(
    size: crescent.size * scale,
    outlineWidth: crescent.outlineWidth * scale,
  );

  // The し curls end past the crescent's waist, so they keep a fold; the
  // others may or may not, but any fold they have bends with the curl.
  for (final (scale, curl, pressure, folds) in [
    (2.0, _shi(_flat), null, true),
    (2.0, _shi(_rising), 'pressing harder towards the tip', true),
    (2.0, _shi(_late), 'pressing hard just before the tip', true),
    (4.0, _shi(_flat), null, true),
    (4.0, _shi(_rising), 'pressing harder towards the tip', true),
    (4.0, _shi(_flat, reversed: true), null, false),
    (2.0, _c(_flat), null, false),
    (4.0, _c(_late), 'pressing hard just before the tip', false),
  ]) {
    final label =
        '${curl.name} at ${scale}x the brush size, '
        '${pressure ?? 'without pressure'}';
    testWidgets('$label: the inner edge and the fold bend with the curl', (
      tester,
    ) async {
      final rgba = await _draw(
        tester,
        sized(scale),
        curl,
        pressure: pressure != null,
      );
      final (least, at) = _leastCurvature(_innerRadii(rgba, curl), curl);
      // An edge parallel to the curl measures 1 or more; pixel steps along
      // a curving edge stay well within this.
      expect(
        least,
        greaterThan(-.1),
        reason:
            'the inner edge bends against the curl at $at degrees '
            '(relative curvature $least)',
      );
      final fold = _foldRadii(rgba, curl);
      if (folds) {
        expect(
          _longestRun(fold),
          greaterThanOrEqualTo(40),
          reason: 'the folded crescent shows a fold line inside the strand',
        );
      }
      final (foldLeast, foldAt) = _leastCurvature(fold, curl);
      expect(
        foldLeast,
        greaterThan(-.1),
        reason:
            'the fold line bends against the curl at $foldAt degrees '
            '(relative curvature $foldLeast)',
      );
    });
  }
}
