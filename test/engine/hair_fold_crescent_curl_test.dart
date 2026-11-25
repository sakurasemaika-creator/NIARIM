// A 「三日月カール」 curl keeps the pen's own width on its outer side, makes
// one crescent per curl, and a ribbon's ends are its tip's straight cut.
//
// Round the bottom of a curl like 「し」 the crescent's bow, which lies across
// the chord of the curl and runs out towards its ends, used to pull the outer
// edge in as the crescent gave way to the ordinary strand: without pressure,
// a thick strand thinned to about two thirds of its width there. A curl
// turning on past half a turn was split into half-turns that each became a
// crescent, and the next one started from a hairline: a very thin crescent
// before the main one. And a ribbon (a solid rectangular tip) ended in round
// caps, or with its image loaded, in the upright tip's block with steps where
// it met the strand.
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

  /// The curl's point at [turned] degrees into the curl: its angle round
  /// [centre] goes from 180 degrees down through 90.
  ui.Offset at(double turned) =>
      centre + ui.Offset.fromDirection((180 - turned) * math.pi / 180, radius);

  List<ui.Offset> get points => [
    for (var i = 0; i <= (down / 4).round(); i++)
      top + ui.Offset(0, down * i / (down / 4).round()),
    for (var i = 1; i <= (sweep / 2).round(); i++)
      at(sweep * i / (sweep / 2).round()),
  ];

  /// The heading at the curl's end.
  ui.Offset get endHeading =>
      ui.Offset.fromDirection((90 - sweep) * math.pi / 180);

  double get length => down + radius * sweep * math.pi / 180;
}

Future<Uint8List> _draw(
  Brush brush,
  List<ui.Offset> input,
  int width,
  int height,
) async {
  final tiles = TileManager(canvasWidth: width, canvasHeight: height);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xff8a5a44)
    ..pressureEnabled = false;
  StrokePoint p(ui.Offset a) =>
      StrokePoint(x: a.dx, y: a.dy, pressure: 1, tiltX: 0, tiltY: 0);
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

  double coverage(ui.Offset at) {
    final x0 = at.dx.floor(), y0 = at.dy.floor();
    final fx = at.dx - x0, fy = at.dy - y0;
    double alpha(int x, int y) => x < 0 || y < 0 || x >= width || y >= height
        ? 0
        : rgba[(y * width + x) * 4 + 3] / 255;
    return alpha(x0, y0) * (1 - fx) * (1 - fy) +
        alpha(x0 + 1, y0) * fx * (1 - fy) +
        alpha(x0, y0 + 1) * (1 - fx) * fy +
        alpha(x0 + 1, y0 + 1) * fx * fy;
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final presets = brushExtensionPresets();
  Brush preset(String id, double scale) {
    final brush = presets.singleWhere((b) => b.id == id);
    // Without stabilisation the strand follows the curl exactly.
    return brush.copyWith(
      size: brush.size * scale,
      outlineWidth: brush.outlineWidth * scale,
      stabilization: false,
    );
  }

  // The ribbon's tip image, as the app loads it. (The hair's round tip
  // draws the same strand as without it, only far more slowly.)
  setUpAll(() async {
    final ribbon = presets.singleWhere((b) => b.id == 'Brush0040');
    await preloadBrushTextures(
      ribbon.resolvedCustomImagePaths,
      mode: ribbon.imageInkMode,
    );
  });

  // Without pressure, the outer edge of the curl stays where the pen's own
  // width puts it, from the curl's start round its bottom, up to where the
  // brush's own taper begins near the tip.
  for (final scale in [2.0, 4.0]) {
    test(
      'a ${scale}x crescent curl keeps the pen width on its outer side',
      () async {
        const shi = _Shi(ui.Offset(170, 70), 300, 110, 216);
        final brush = preset('Brush0035', scale);
        final ink = _Ink(await _draw(brush, shi.points, 520, 640), 520, 640);
        final expected = shi.radius + brush.size / 2 + brush.outlineWidth;
        // The brush's taper (its fade-out range) starts this far into the
        // curl.
        final taperFrom =
            (shi.length - brush.fadeOut.rangePx - shi.down) /
            shi.radius *
            180 /
            math.pi;
        var least = (double.infinity, 0.0);
        for (var turned = 5.0; turned < taperFrom - 10; turned += 1) {
          final direction = ui.Offset.fromDirection(
            (180 - turned) * math.pi / 180,
          );
          final runs = ink.runs(shi.centre, direction, shi.radius * 2);
          expect(runs, isNotEmpty, reason: 'no ink at $turned degrees');
          final outer = runs.last.$2;
          if (outer < least.$1) least = (outer, turned);
        }
        expect(
          least.$1,
          greaterThan(expected - 1.5),
          reason:
              'the outer edge is ${expected - least.$1}px inside the pen '
              'width at ${least.$2} degrees into the curl',
        );
      },
    );
  }

  // A curl turning on past half a turn is one crescent: it closes once, at
  // its waist, and opens into one lobe; it does not run on as a hairline
  // into a second crescent.
  for (final sweep in [300.0, 330.0, 360.0]) {
    test('a curl of $sweep degrees makes one crescent', () async {
      const top = ui.Offset(90, 70);
      final shi = _Shi(top, 160, 100, sweep);
      final brush = preset('Brush0035', 2);
      final ink = _Ink(await _draw(brush, shi.points, 420, 460), 420, 460);
      // Across the strand round the curl, a degree apart, up to where it
      // narrows to its tip.
      final across = <double>[];
      for (var turned = 0.0; turned <= sweep - 60; turned += 1) {
        final direction = ui.Offset.fromDirection(
          (180 - turned) * math.pi / 180,
        );
        // Out from the centre, the curl's own strand: the ink round its
        // circle (where the curl comes back to the stem, the two meet).
        final runs = ink.runs(shi.centre, direction, shi.radius * 1.6);
        final own = runs.where(
          (run) =>
              run.$1 < shi.radius + brush.size &&
              run.$2 > shi.radius - brush.size,
        );
        across.add(own.isEmpty ? 0 : own.first.$2 - own.first.$1);
      }
      final closed = 2 * brush.outlineWidth + 1;
      var closedLength = 0.0;
      var stretches = 0;
      for (var i = 0; i < across.length; i++) {
        if (across[i] < closed) {
          closedLength += shi.radius * math.pi / 180;
          if (i == 0 || across[i - 1] >= closed) stretches++;
        }
      }
      expect(
        stretches,
        lessThanOrEqualTo(1),
        reason: 'the strand closes $stretches times',
      );
      // Where it closes, the outlines meet and part again within a short
      // stretch (the extra crescent ran on as bare outline for 60px).
      expect(
        closedLength,
        lessThan(brush.size * .4),
        reason:
            'the strand runs on as a hairline of bare outline for '
            '${closedLength.toStringAsFixed(1)}px',
      );
      // Past where it closes, the lobe opens to well over a hairline.
      final waist = across.indexWhere((width) => width < closed);
      if (waist >= 0) {
        final lobe = across.skip(waist).reduce(math.max);
        expect(lobe, greaterThan(brush.size * .3));
      }
    });
  }

  // While a curl is drawn on past half a turn, only its deepest half-turn
  // stays a crescent, move by move: the strand still ends exactly as if it
  // had been drawn at once.
  test('a long curl drawn point by point ends as drawn at once', () {
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
    const shi = _Shi(ui.Offset(120, 60), 200, 120, 330);
    final points = [for (final at in shi.points) HairRibbonPoint(at, 36, 1)];
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

  // The ribbon's tip is a tall, narrow rectangle. Its ends are that
  // rectangle's straight cut, across the whole strand, not round caps.
  group('a ribbon crescent', () {
    const shi = _Shi(ui.Offset(120, 90), 260, 110, 216);
    final ribbon = preset('Brush0040', 2);
    late _Ink ink;
    setUpAll(() async {
      ink = _Ink(await _draw(ribbon, shi.points, 460, 560), 460, 560);
    });

    // Where the strand ends, along lines parallel to [heading] across the
    // middle of the strand: the last ink on each.
    List<ui.Offset> cut(ui.Offset end, ui.Offset heading) {
      final normal = ui.Offset(-heading.dy, heading.dx);
      final half = ribbon.size / 2;
      return [
        for (var k = -.8; k <= .8001; k += .1)
          () {
            final from = end + normal * (k * half) - heading * half;
            final runs = ink.runs(from, heading, 2 * half);
            return runs.isEmpty
                ? ui.Offset.infinite
                : from + heading * runs.last.$2;
          }(),
      ];
    }

    test('is as wide as the pen along its straight start', () {
      final runs = ink.runs(
        shi.top + ui.Offset(-ribbon.size, shi.down / 2),
        const ui.Offset(1, 0),
        ribbon.size * 2,
      );
      expect(runs, hasLength(1));
      expect(
        runs.single.$2 - runs.single.$1,
        closeTo(ribbon.size + 2 * ribbon.outlineWidth, 2),
      );
    });

    for (final (name, end, heading) in [
      ('start', shi.top, const ui.Offset(0, -1)),
      ('end', shi.at(shi.sweep), shi.endHeading),
    ]) {
      test('ends at its $name in the tip\'s straight cut', () {
        final ends = cut(end, heading);
        expect(ends.any((at) => at.isInfinite), isFalse);
        // A straight line across the strand: the ends of the lines lie on
        // the line through the outermost two within a pixel.
        final a = ends.first, b = ends.last;
        final along = (b - a) / (b - a).distance;
        final apart = [
          for (final at in ends)
            ((at - a).dx * along.dy - (at - a).dy * along.dx).abs(),
        ];
        expect(
          apart.reduce(math.max),
          lessThan(1),
          reason: 'not straight across: $ends',
        );
        // Across the strand (to within the strand's own turn there).
        expect(
          (along.dx * heading.dx + along.dy * heading.dy).abs(),
          lessThan(math.sin(8 * math.pi / 180)),
        );
        // Half the tip's thickness on from the end, and its outline.
        final reach = ribbon.size / 2 * 40 / 128 + ribbon.outlineWidth;
        final middle = ends[ends.length ~/ 2] - end;
        expect(
          middle.dx * heading.dx + middle.dy * heading.dy,
          closeTo(reach, 2),
        );
      });
    }
  });

  test('a hair crescent keeps its round start', () async {
    const shi = _Shi(ui.Offset(120, 90), 260, 110, 216);
    final hair = preset('Brush0035', 2);
    final ink = _Ink(await _draw(hair, shi.points, 460, 560), 460, 560);
    final half = hair.size / 2;
    double topAt(double x) {
      final runs = ink.runs(
        shi.top + ui.Offset(x, -half * 2),
        const ui.Offset(0, 1),
        half * 3,
      );
      return runs.first.$1;
    }

    // A round cap: the middle reaches past the sides by most of the radius.
    expect(topAt(half * .8) - topAt(0), greaterThan(half * .3));
  });
}
