// Along a 「三日月カール」 curl, the inner edge bends the same way as the
// stroke and its outer edge, whatever the brush size, pressure or taper. A
// curl drawn like 「し」 used to thin to a waist near its tip and swell again:
// the end of the last crescent changed back to the ordinary strand over at
// most 60 degrees of turn, while the crescent's bow had run out long before,
// so the inner edge turned against the curve. A thicker brush or pressure
// rising towards the tip made the lump larger.
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

/// The least curvature of the inner edge along the curl, relative to the
/// curl's own (1 for an edge parallel to the curl, below 0 where it bends
/// against it), with the angle where it is least.
///
/// From the curl's centre, each ray at a whole degree meets the ink's inner
/// edge (its coverage crossing a half, between pixels by interpolation).
/// Where the strand is at least 6px across, a parabola fitted to the edge's
/// distance over at least 13 degrees and 24px of the edge gives its
/// curvature, so pixel steps do not read as bends.
(double, double) _leastInnerCurvature(Uint8List rgba, _Curl curl) {
  double coverage(double x, double y) {
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

  // The inner edge's distance, or null where the strand is too thin there.
  double? inner(double degrees) {
    final direction = ui.Offset.fromDirection(degrees * math.pi / 180);
    double? entry;
    var previous = coverage(curl.centre.dx, curl.centre.dy);
    for (var d = .1; d < curl.radius * 2; d += .1) {
      final q = curl.centre + direction * d;
      final value = coverage(q.dx, q.dy);
      if (entry == null && previous < .5 && value >= .5) {
        entry = d - .1 + .1 * (.5 - previous) / (value - previous);
      } else if (entry != null && previous >= .5 && value < .5) {
        return d - entry >= 6 ? entry : null;
      }
      previous = value;
    }
    return null;
  }

  final step = curl.to > curl.from ? 1.0 : -1.0;
  final count = ((curl.to - curl.from) / step).round();
  final radii = [for (var i = 0; i <= count; i++) inner(curl.from + i * step)];
  var least = (double.infinity, 0.0);
  for (var i = 0; i <= count; i++) {
    final middle = radii[i];
    if (middle == null) continue;
    // At least 6 degrees and 12px of the edge either side.
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
    if (relative < least.$1) least = (relative, curl.from + i * step);
  }
  return least;
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

  for (final (scale, curl, pressure) in [
    (2.0, _shi(_flat), null),
    (2.0, _shi(_rising), 'pressing harder towards the tip'),
    (2.0, _shi(_late), 'pressing hard just before the tip'),
    (4.0, _shi(_flat), null),
    (4.0, _shi(_rising), 'pressing harder towards the tip'),
    (4.0, _shi(_flat, reversed: true), null),
    (2.0, _c(_flat), null),
    (4.0, _c(_late), 'pressing hard just before the tip'),
  ]) {
    final label =
        '${curl.name} at ${scale}x the brush size, '
        '${pressure ?? 'without pressure'}';
    testWidgets('the inner edge of $label bends with the curl', (tester) async {
      final rgba = await _draw(
        tester,
        sized(scale),
        curl,
        pressure: pressure != null,
      );
      final (least, at) = _leastInnerCurvature(rgba, curl);
      // An edge parallel to the curl measures 1 or more; pixel steps along
      // a curving edge stay well within this.
      expect(
        least,
        greaterThan(-.1),
        reason:
            'the inner edge bends against the curl at $at degrees '
            '(relative curvature $least)',
      );
    });
  }
}
