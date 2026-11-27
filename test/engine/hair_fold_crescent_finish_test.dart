// The remaining rough spots of a 「三日月カール」 strand, drawn with the brush
// tip images loaded as the app does.
//
// - A curl past half a turn (270-300 degrees) whose folded crescent narrows
//   to its tip along a long chord: pressed towards that chord, the lobe left
//   the outer edge at a degree or two, and the two outlines ran on together
//   from the waist for about 14px.
// - A thick curl that rejoins the strand before its tip: where the pen's
//   taper begins along the curl, its inner edge ran straight and could turn
//   slightly against the curve.
// - A thin tip under weakening pressure broke up into dots.
// - A curl past a whole turn that comes back over its stem or itself: the
//   two parts merged into one silhouette. The later part now lies on top,
//   its own outline drawn over the earlier part.
// - A wobble along a thin curl split it into separate crescents, which met
//   at points: the strand pinched to nothing.
// - The tip-side leg of a hairpin: its inner edge ran straight from the
//   curl and turned a corner where the taper went on.
// - A curl tip that only just reaches back over its stem: its last
//   hairline, bare outline with no fill of its own, lay on top of the stem
//   and poked into it as a dark sliver.
// - Where a thick strand meets a tight curl, its inner edge drew back a
//   pixel or two before it turned with the curl; inside a thick hairpin the
//   inner edge ran on past the tip-side leg and came back (a hook), and
//   turned a corner where a lowered stretch left it.
// Thick strands drawn with the tip images loaded take a while each.
@Timeout(Duration(minutes: 5))
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/hair_fold_raster.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

/// A stroke straight down from [top] for [down], then round a circle of
/// [radius] to the right and up for [sweep] degrees, like 「し」.
class _Shi {
  final ui.Offset top;
  final double down, radius, sweep;
  const _Shi(this.top, this.down, this.radius, this.sweep);

  ui.Offset get centre => top + ui.Offset(radius, down);

  /// The curl's point at [turned] degrees into the curl.
  ui.Offset at(double turned) =>
      centre + ui.Offset.fromDirection((180 - turned) * math.pi / 180, radius);

  List<ui.Offset> get points => [
    for (var i = 0; i <= (down / 4).round(); i++)
      top + ui.Offset(0, down * i / (down / 4).round()),
    for (var i = 1; i <= (sweep / 2).round(); i++)
      at(sweep * i / (sweep / 2).round()),
  ];
}

/// A stroke from [start] heading [heading] degrees (on the screen), drawn
/// as straight runs (`[0, length]`) and arcs (`[1, radius, turn]`, turning
/// by [turn] degrees) with points about 4px apart, as a hand would draw it.
List<ui.Offset> _turtle(
  ui.Offset start,
  double heading,
  List<List<double>> parts,
) {
  var x = start.dx, y = start.dy, h = heading * math.pi / 180;
  final out = <ui.Offset>[start];
  for (final part in parts) {
    if (part[0] == 0) {
      final n = math.max(1, (part[1] / 4).round());
      for (var i = 1; i <= n; i++) {
        x += math.cos(h) * part[1] / n;
        y += math.sin(h) * part[1] / n;
        out.add(ui.Offset(x, y));
      }
    } else {
      final r = part[1], turn = part[2] * math.pi / 180;
      final n = math.max(2, (r * turn.abs() / 4).round());
      for (var i = 1; i <= n; i++) {
        final step = turn / n;
        final chord = 2 * r * math.sin(step.abs() / 2);
        x += math.cos(h + step / 2) * chord;
        y += math.sin(h + step / 2) * chord;
        h += step;
        out.add(ui.Offset(x, y));
      }
    }
  }
  return out;
}

/// A smooth wavering between -1 and 1 along [t], the same for each [seed].
double _wavering(double t, int seed, int octave) {
  final random = math.Random(seed * 31 + octave);
  var v = 0.0;
  for (var k = 1; k <= 4; k++) {
    v += math.sin(2 * math.pi * (k * 1.7 * t + random.nextDouble())) / k;
  }
  return v / 2.08;
}

Future<Uint8List> _draw(
  Brush brush,
  List<(ui.Offset, double)> input,
  int width,
  int height, {
  bool pressure = false,
}) async {
  final tiles = TileManager(canvasWidth: width, canvasHeight: height);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xff8a5a44)
    ..pressureEnabled = pressure;
  StrokePoint p((ui.Offset, double) a) =>
      StrokePoint(x: a.$1.dx, y: a.$1.dy, pressure: a.$2, tiltX: 0, tiltY: 0);
  tiles.beginUndoRecording('hair');
  engine.beginStroke(p(input.first), 'hair');
  for (final point in input.skip(1)) {
    engine.continueStroke(p(point), 'hair');
  }
  if (engine.needsFinalFadeReplay) {
    final preview = tiles.endUndoRecording();
    tiles.applyTileSnapshot('hair', preview.before);
    tiles.beginUndoRecording('hair');
    engine.replayCurrentStrokeWithFinalFade();
  }
  engine.endStroke();
  tiles.endUndoRecording();
  final image = await tiles.compositeLayerToImage('hair');
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  tiles.dispose();
  return Uint8List.fromList(data!.buffer.asUint8List());
}

class _Ink {
  final Uint8List rgba;
  final int width, height;
  const _Ink(this.rgba, this.width, this.height);

  double alphaAt(int x, int y) => x < 0 || y < 0 || x >= width || y >= height
      ? 0
      : rgba[(y * width + x) * 4 + 3] / 255;

  double coverage(ui.Offset at) {
    final x0 = at.dx.floor(), y0 = at.dy.floor();
    final fx = at.dx - x0, fy = at.dy - y0;
    return alphaAt(x0, y0) * (1 - fx) * (1 - fy) +
        alphaAt(x0 + 1, y0) * fx * (1 - fy) +
        alphaAt(x0, y0 + 1) * (1 - fx) * fy +
        alphaAt(x0 + 1, y0 + 1) * fx * fy;
  }

  /// How dark the ink is at a pixel: its green channel, straight (the fill
  /// is 0x5a there, the outline 0).
  double green(int x, int y) {
    final i = (y * width + x) * 4;
    final a = rgba[i + 3];
    return a == 0 ? 255 : rgba[i + 1] * 255 / a;
  }

  /// Along a ray from [from] heading [direction], the runs of ink it crosses
  /// (coverage at least a half), as (from, to) distances.
  List<(double, double)> runs(
    ui.Offset from,
    ui.Offset direction,
    double reach,
  ) {
    final found = <(double, double)>[];
    double? entry;
    for (var d = 0.0; d < reach; d += .1) {
      final inside = coverage(from + direction * d) >= .5;
      if (inside && entry == null) {
        entry = d;
      } else if (!inside && entry != null) {
        found.add((entry, d));
        entry = null;
      }
    }
    if (entry != null) found.add((entry, reach));
    return found;
  }

  /// The curl's own strand across, by degree into the curl round [shi], up
  /// to [last] degrees.
  List<double> across(_Shi shi, double size, double last) => [
    for (var turned = 0.0; turned <= last; turned += 1)
      () {
        final direction = ui.Offset.fromDirection(
          (180 - turned) * math.pi / 180,
        );
        final own = runs(shi.centre, direction, shi.radius * 1.6).where(
          (run) => run.$1 < shi.radius + size && run.$2 > shi.radius - size,
        );
        return own.isEmpty ? 0.0 : own.first.$2 - own.first.$1;
      }(),
  ];
}

/// How deep the deepest dent in the outline of a hole in [ink] is: the
/// furthest any point of its outline lies inside its convex hull. The hole
/// is the paper (coverage under a half) reached from [seed] over rows
/// [top] to [bottom]; its outline is found to a fraction of a pixel by each
/// row's ink coverage either side.
double _holeDent(_Ink ink, ui.Offset seed, int top, int bottom) {
  bool paper(int x, int y) => y >= top && y <= bottom && ink.alphaAt(x, y) < .5;
  final start = (seed.dx.floor(), seed.dy.floor());
  expect(paper(start.$1, start.$2), isTrue, reason: 'the seed is not paper');
  final seen = <(int, int)>{start};
  final queue = [start];
  while (queue.isNotEmpty) {
    final (x, y) = queue.removeLast();
    for (final next in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
      if (paper(next.$1, next.$2) && seen.add(next)) queue.add(next);
    }
  }
  final rows = <int, (int, int)>{};
  for (final (x, y) in seen) {
    final row = rows[y];
    rows[y] = row == null ? (x, x) : (math.min(row.$1, x), math.max(row.$2, x));
  }
  final outline = <ui.Offset>[];
  for (final MapEntry(key: y, value: (left, right)) in rows.entries) {
    outline
      ..add(ui.Offset(left - (1 - ink.alphaAt(left - 1, y)), y + .5))
      ..add(ui.Offset(right + 1 + (1 - ink.alphaAt(right + 1, y)), y + .5));
  }
  // The convex hull, by Andrew's monotone chain.
  final sorted = [
    ...outline,
  ]..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
  double turn(ui.Offset o, ui.Offset a, ui.Offset b) =>
      (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
  final hull = <ui.Offset>[];
  for (final pass in [sorted, sorted.reversed.toList()]) {
    final start = hull.length;
    for (final point in pass) {
      while (hull.length >= start + 2 &&
          turn(hull[hull.length - 2], hull.last, point) <= 0) {
        hull.removeLast();
      }
      hull.add(point);
    }
    hull.removeLast();
  }
  var deepest = 0.0;
  for (final point in outline) {
    var nearest = double.infinity;
    for (var i = 0; i < hull.length; i++) {
      final a = hull[i], b = hull[(i + 1) % hull.length];
      final ab = b - a;
      final t = ab.distanceSquared < 1e-12
          ? 0.0
          : (((point - a).dx * ab.dx + (point - a).dy * ab.dy) /
                    ab.distanceSquared)
                .clamp(0.0, 1.0);
      nearest = math.min(nearest, (point - (a + ab * t)).distance);
    }
    deepest = math.max(deepest, nearest);
  }
  return deepest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final presets = brushExtensionPresets();
  Brush preset(String id, double scale, {bool steadied = false}) {
    final brush = presets.singleWhere((b) => b.id == id);
    return brush.copyWith(
      size: brush.size * scale,
      outlineWidth: brush.outlineWidth * scale,
      // Without the brush's own steadying the strand follows the input
      // exactly; with it, as the app draws a hand's stroke.
      stabilization: steadied ? null : false,
    );
  }

  // The hair's round tip and the ribbon's rectangle, as the app loads them.
  setUpAll(() async {
    for (final id in ['Brush0035', 'Brush0040']) {
      final brush = presets.singleWhere((b) => b.id == id);
      await preloadBrushTextures(
        brush.resolvedCustomImagePaths,
        mode: brush.imageInkMode,
      );
    }
  });

  // Where the folded crescent closes, the outlines meet and part again
  // within a few pixels, however long the lobe after the waist: as soon as
  // they do on a curl of 216 degrees, whose lobe is short.
  for (final (scale, sweep) in [(2.0, 270.0), (2.0, 300.0), (4.0, 300.0)]) {
    test(
      'a ${scale}x curl of $sweep degrees parts at its waist like a short one',
      () async {
        final brush = preset('Brush0035', scale);
        Future<double> closedLength(double sweep) async {
          final shi = _Shi(const ui.Offset(130, 100), 160, 100, sweep);
          final ink = _Ink(
            await _draw(
              brush,
              [for (final p in shi.points) (p, 1.0)],
              520,
              560,
            ),
            520,
            560,
          );
          final across = ink.across(shi, brush.size, sweep - 40);
          final closed = 2 * brush.outlineWidth + 1;
          return across.where((width) => width < closed).length *
              shi.radius *
              math.pi /
              180;
        }

        final short = await closedLength(216);
        final long = await closedLength(sweep);
        expect(
          long,
          lessThan(short + 4),
          reason:
              'the outlines run together for ${long.toStringAsFixed(1)}px '
              'at the waist (${short.toStringAsFixed(1)}px at 216 degrees)',
        );
      },
    );
  }

  // A curl that rejoins its strand before the tip (a thick strand curled
  // past a whole turn): from where it rejoins to the tip, through where the
  // pen's taper begins, the inner edge only ever bends with the curl.
  for (final sweep in [330.0, 360.0]) {
    test(
      'a 4x curl of $sweep degrees bends with itself up to its tip',
      () async {
        final shi = _Shi(const ui.Offset(130, 140), 160, 140, sweep);
        final brush = preset('Brush0035', 4);
        final points = _turtle(shi.top, 90, [
          [0, shi.down],
          [1, shi.radius, -sweep],
        ]);
        final ink = _Ink(
          await _draw(brush, [for (final p in points) (p, 1.0)], 640, 640),
          640,
          640,
        );
        // The inside of the curl seen from its centre, a quarter degree
        // apart, from past where the strand rejoins to before the tip.
        final edge = <ui.Offset>[];
        for (var turned = 210.0; turned <= sweep - 50; turned += .25) {
          final direction = ui.Offset.fromDirection(
            (180 - turned) * math.pi / 180,
          );
          final runs = ink.runs(shi.centre, direction, shi.radius * 1.5);
          if (runs.isEmpty) continue;
          edge.add(shi.centre + direction * runs.first.$1);
        }
        // About 3px apart along it.
        final even = <ui.Offset>[edge.first];
        for (final point in edge) {
          if ((point - even.last).distance >= 3) even.add(point);
        }
        var against = 0.0;
        for (var k = 4; k + 4 < even.length; k++) {
          final a = even[k] - even[k - 4], b = even[k + 4] - even[k];
          // The curl turns counterclockwise on the screen (y downwards):
          // turning with it is a negative cross product, against it positive.
          final turn =
              math.atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy) *
              180 /
              math.pi;
          against = math.max(against, turn);
        }
        expect(
          against,
          lessThanOrEqualTo(0),
          reason:
              'the inner edge turns ${against.toStringAsFixed(2)} degrees '
              'against the curl over 24px',
        );
      },
    );
  }

  // Under weakening pressure a thin strand narrows to a hairline: it stays
  // one line to its end, not a row of dots.
  test('a thin tip under weakening pressure stays unbroken', () async {
    const shi = _Shi(ui.Offset(60, 60), 200, 110, 216);
    final brush = preset('Brush0035', .6);
    final points = _turtle(shi.top, 90, [
      [0, shi.down],
      [1, shi.radius, -shi.sweep],
    ]);
    final ink = _Ink(
      await _draw(
        brush,
        [
          for (var i = 0; i < points.length; i++)
            (points[i], 1 - .7 * i / (points.length - 1)),
        ],
        360,
        420,
        pressure: true,
      ),
      360,
      420,
    );
    // Along the last 60 degrees of the curl, a pixel apart: the ink across
    // the strand there (its coverage summed over 4px across).
    final along = <double>[];
    for (
      var turned = shi.sweep - 60;
      turned <= shi.sweep;
      turned += 180 / (math.pi * shi.radius)
    ) {
      final at = shi.at(turned);
      final across = (at - shi.centre) / shi.radius;
      var sum = 0.0;
      for (var d = -2.0; d <= 2; d += .25) {
        sum += ink.coverage(at + across * d) * .25;
      }
      along.add(sum);
    }
    // Where the ink is gone and comes back further on.
    final last = along.lastIndexWhere((ink) => ink > .2);
    final gaps = [
      for (var i = 0; i < last; i++)
        if (along[i] < .05) i,
    ];
    expect(gaps, isEmpty, reason: 'the tip breaks off at $gaps of $last');
  });

  // A curl past a whole turn comes back over its stem: the later part lies
  // on top, its own outline drawn over the stem, rather than the two merging
  // into one silhouette.
  test('a curl that comes back over its stem lies on top of it', () async {
    const shi = _Shi(ui.Offset(130, 100), 160, 100, 360);
    final brush = preset('Brush0035', 2);
    final ink = _Ink(
      await _draw(brush, [for (final p in shi.points) (p, 1.0)], 420, 460),
      420,
      460,
    );
    // Inside the stem, away from its own outlines, above where it turns
    // into the curl: outline drawn there is the curl's, lying on top.
    var outline = 0;
    for (var y = 190; y < 255; y++) {
      for (var x = 112; x <= 148; x++) {
        if (ink.alphaAt(x, y) > .9 && ink.green(x, y) < 40) outline++;
      }
    }
    expect(outline, greaterThan(20));
    // Where the curl does not reach the stem, the stem is all fill inside.
    var stray = 0;
    for (var y = 110; y < 170; y++) {
      for (var x = 112; x <= 148; x++) {
        if (ink.alphaAt(x, y) > .9 && ink.green(x, y) < 40) stray++;
      }
    }
    expect(stray, 0);
  });

  // A hand's wobble along a thin curl, with wavering pressure, does not
  // split it into crescents that meet at points: the strand pinches to its
  // outline alone nowhere but at the waist of its one crescent.
  test('a wobbly thin curl never pinches', () async {
    const shi = _Shi(ui.Offset(40, 40), 200, 110, 216);
    const seed = 9, wobble = 4.0;
    final path = _turtle(shi.top, 90, [
      [0, shi.down],
      [1, shi.radius, -shi.sweep],
    ]);
    final shake = math.Random(seed), press = math.Random(seed + 7);
    final count = path.length;
    final points = [
      for (var i = 0; i < count; i++)
        () {
          final a = path[math.max(0, i - 1)];
          final b = path[math.min(count - 1, i + 1)];
          final normal = ui.Offset(-(b.dy - a.dy), b.dx - a.dx);
          final unit = normal.distance == 0
              ? ui.Offset.zero
              : normal / normal.distance;
          final t = i / (count - 1);
          final off =
              wobble * _wavering(t * 3, seed, 0) +
              wobble * .25 * (shake.nextDouble() - .5);
          return path[i] + unit * off;
        }(),
    ];
    final pressures = [
      for (var i = 0; i < count; i++)
        (.4 +
                .08 * _wavering(i / (count - 1) * 4, seed, 3) +
                .06 * (press.nextDouble() - .5))
            .clamp(.15, 1.0),
    ];
    final brush = preset('Brush0035', 1, steadied: true);
    final ink = _Ink(
      await _draw(
        brush,
        [for (var i = 0; i < count; i++) (points[i], pressures[i])],
        360,
        420,
        pressure: true,
      ),
      360,
      420,
    );
    // Round the bottom of the curl, before it narrows to its tip: it closes
    // only where its one folded crescent does, at a single short waist.
    final across = ink.across(shi, brush.size, 150);
    final closed = [
      for (var turned = 0; turned < across.length; turned++)
        if (across[turned] < 2 * brush.outlineWidth + 1) turned,
    ];
    var stretches = 0;
    for (var k = 0; k < closed.length; k++) {
      if (k == 0 || closed[k] != closed[k - 1] + 1) stretches++;
    }
    expect(
      stretches,
      lessThanOrEqualTo(1),
      reason: 'closed at $closed degrees',
    );
    expect(
      closed.length * shi.radius * math.pi / 180,
      lessThan(brush.size * .5),
      reason: 'closed at $closed degrees',
    );
  });

  // The leg of a hairpin that runs on to the tip narrows like the pen's
  // own taper, the same on both sides: its inner edge does not run straight
  // from the curl and turn a corner where the taper goes on.
  test('the tip-side leg of a hairpin tapers evenly on both sides', () async {
    const x0 = 80.0, y0 = 60.0, down = 220.0, r = 40.0;
    final points = _turtle(const ui.Offset(x0, y0), 90, [
      [0, down],
      [1, r, -180],
      [0, down],
    ]);
    final brush = preset('Brush0035', 2, steadied: true);
    final ink = _Ink(
      await _draw(brush, [for (final p in points) (p, 1.0)], 260, 420),
      260,
      420,
    );
    var worst = (0.0, 0);
    // From just past the curl up to near the tip.
    for (var y = (y0 + down - 10).round(); y > y0 + 30; y -= 2) {
      final runs = ink.runs(
        ui.Offset(x0 + r, y.toDouble()),
        const ui.Offset(1, 0),
        2 * r,
      );
      if (runs.isEmpty) continue;
      final left = x0 + r + runs.first.$1, right = x0 + r + runs.first.$2;
      final off = ((left + right) / 2 - (x0 + 2 * r)).abs();
      if (off > worst.$1) worst = (off, y);
    }
    expect(
      worst.$1,
      lessThan(.75),
      reason:
          'the leg is ${worst.$1.toStringAsFixed(2)}px off its centre line '
          'at y=${worst.$2}',
    );
  });

  // A curl tip that comes back only just over its stem ends in a hairline,
  // bare outline: it joins the stem rather than lie on top of it, and no
  // outline shows inside the stem (a whole turn and more lies on top, as
  // above).
  for (final (scale, down, radius) in [
    (2.0, 160.0, 30.0),
    (4.0, 200.0, 50.0),
  ]) {
    test('a ${scale}x curl tip that just reaches its stem leaves no sliver '
        'in it', () async {
      const x0 = 120.0, y0 = 70.0;
      final points = _turtle(const ui.Offset(x0, y0), 90, [
        [0, down],
        [1, radius, -300],
      ]);
      final brush = preset('Brush0035', scale, steadied: true);
      final ink = _Ink(
        await _draw(brush, [for (final p in points) (p, 1.0)], 460, 520),
        460,
        520,
      );
      // Inside the stem, clear of its own outlines.
      final inset = brush.size / 2 - brush.outlineWidth - 1;
      final dark = <String>[];
      for (var y = (y0 + 20).round(); y < (y0 + down).round(); y++) {
        for (var x = (x0 - inset).ceil(); x <= (x0 + inset).floor(); x++) {
          if (ink.alphaAt(x, y) > .5 && ink.green(x, y) < 60) {
            dark.add('($x, $y)');
          }
        }
      }
      expect(dark, isEmpty, reason: 'outline inside the stem at $dark');
    });
  }

  // The paper inside a tight turn of a thick strand is bounded by edges that
  // only ever turn with the curve: no dent, hook or corner in its outline.
  for (final (scale, down, radius, sweep) in [
    (2.0, 160.0, 30.0, 300.0),
    (4.0, 200.0, 50.0, 300.0),
    (4.0, 220.0, 60.0, 180.0),
    (2.0, 220.0, 40.0, 180.0),
  ]) {
    final hairpin = sweep == 180;
    test('the inside of a ${scale}x ${hairpin ? 'hairpin' : 'tight curl'} '
        'has no dent', () async {
      const x0 = 120.0, y0 = 70.0;
      final points = _turtle(const ui.Offset(x0, y0), 90, [
        [0, down],
        [1, radius, -sweep],
        if (hairpin) [0, down],
      ]);
      final brush = preset('Brush0035', scale, steadied: true);
      final ink = _Ink(
        await _draw(brush, [for (final p in points) (p, 1.0)], 460, 560),
        460,
        560,
      );
      // The curl's eye, or the bottom of the hairpin's slot, from where it
      // turns (above, the tip-side leg narrows to its tip and the slot
      // widens, as the pen does).
      final centre = ui.Offset(x0 + radius, y0 + down);
      final dent = hairpin
          ? _holeDent(
              ink,
              centre + ui.Offset(0, radius / 2 - brush.size / 2 - 2),
              (y0 + down - radius / 2).round(),
              560,
            )
          : _holeDent(ink, centre, 0, 560);
      expect(
        dent,
        lessThan(.5),
        reason:
            'the outline of the paper inside dents by '
            '${dent.toStringAsFixed(2)}px',
      );
    });
  }

  // Where a curl drawn first runs into its straight stem, the ordinary
  // strand's outer edge is as smooth as its outline: the round tip image
  // no longer steps along it a pixel at a time.
  test('a reversed curl runs smoothly into its stem', () async {
    const shi = _Shi(ui.Offset(130, 100), 200, 110, 216);
    final brush = preset('Brush0035', 2, steadied: true);
    final points = _turtle(shi.top, 90, [
      [0, shi.down],
      [1, shi.radius, -shi.sweep],
    ]).reversed.toList();
    final ink = _Ink(
      await _draw(brush, [for (final p in points) (p, 1.0)], 420, 520),
      420,
      520,
    );
    // The outer (left) edge by rows, from its coverage: where the curl
    // turns up into the stem.
    final edges = <double>[];
    for (var y = 282; y < 362; y++) {
      var full = 0;
      while (full < 420 && ink.alphaAt(full, y) < .999) {
        full++;
      }
      var partial = 0.0;
      for (var x = math.max(0, full - 10); x < full; x++) {
        partial += ink.alphaAt(x, y);
      }
      edges.add(full - partial);
    }
    // Its largest step from a quadratic through the 7 rows around it.
    var worst = 0.0;
    for (var i = 3; i + 3 < edges.length; i++) {
      // The quadratic's value at the middle of 7 evenly spaced rows.
      var fitted = 0.0;
      const weights = [-2.0, 3.0, 6.0, 7.0, 6.0, 3.0, -2.0];
      for (var k = 0; k < 7; k++) {
        fitted += weights[k] * edges[i - 3 + k];
      }
      worst = math.max(worst, (fitted / 21 - edges[i]).abs());
    }
    expect(
      worst,
      lessThan(.15),
      reason: 'the edge steps ${worst.toStringAsFixed(2)}px between rows',
    );
  });

  // Drawn point by point, a curl that comes back over itself, widening as
  // it goes (where parts cross depends on the widest point so far), ends
  // exactly as drawn at once.
  test('a widening curl over itself drawn point by point ends as at once', () {
    const brush = Brush(
      id: 'fold',
      name: 'fold',
      size: 36,
      opacity: 100,
      spacing: 2,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      strokeDecay: false,
      fadeMode: FadeMode.off,
      outlineEnabled: true,
      outlineWidth: 2,
      foldEnabled: true,
      foldMode: HairFoldMode.crescent,
    );
    const shi = _Shi(ui.Offset(120, 60), 180, 100, 400);
    final path = shi.points;
    final points = [
      for (var i = 0; i < path.length; i++)
        HairRibbonPoint(path[i], 20 + 24 * i / (path.length - 1), 1),
    ];
    Uint8List pixels(TileManager tiles) {
      final all = BytesBuilder();
      for (var ty = 0; ty < tiles.tilesY; ty++) {
        for (var tx = 0; tx < tiles.tilesX; tx++) {
          all.add(
            tiles.getTile('test', tx, ty) ??
                Uint8List(TileManager.tileSize * TileManager.tileSize * 4),
          );
        }
      }
      return all.toBytes();
    }

    const fill = ui.Color(0xfff0d0a0);
    final moving = TileManager(canvasWidth: 520, canvasHeight: 520);
    final raster = HairFoldRaster(moving, 'test');
    for (var n = 2; n <= points.length; n++) {
      raster.render(
        points: points.sublist(0, n),
        brush: brush,
        fillColor: fill,
        taperEnd: n == points.length,
      );
    }
    final once = TileManager(canvasWidth: 520, canvasHeight: 520);
    HairFoldRaster(
      once,
      'test',
    ).render(points: points, brush: brush, fillColor: fill, taperEnd: true);
    final drawn = pixels(moving);
    expect(drawn.any((v) => v != 0), isTrue);
    expect(drawn, orderedEquals(pixels(once)));
    moving.dispose();
    once.dispose();
  });
}
