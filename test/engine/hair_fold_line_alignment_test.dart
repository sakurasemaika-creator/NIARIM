import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_render_plan.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/hair_fold_raster.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

const size = 600;
const width = 64.0;
const outlineWidth = 2.5;

Brush pen({
  HairFoldMode mode = HairFoldMode.waveTopView,
  bool fold = true,
  bool outlined = true,
  double angle = 0,
  FadeMode fade = FadeMode.off,
}) => Brush(
  id: 'fold',
  name: 'Fold',
  size: width,
  spacing: 1,
  opacity: 100,
  fadeMode: fade,
  // Ends at zero, like the hair preset's custom taper.
  fadeOut: const FadeEndpointSettings(value: 0, rangePx: 120),
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  strokeDecay: false,
  outlineEnabled: outlined,
  outlineWidth: outlineWidth,
  outlineColor: 0xff000000,
  foldEnabled: fold,
  foldMode: mode,
  foldAngleRatio: angle,
);

class Pixels {
  Pixels(this.bytes);
  final Uint8List bytes;
  int _at(int x, int y, int c) => x < 0 || y < 0 || x >= size || y >= size
      ? 0
      : bytes[(y * size + x) * 4 + c];

  /// Channel [c] of the pixel containing [p].
  int channel(ui.Offset p, int c) => _at(p.dx.floor(), p.dy.floor(), c);

  int alpha(ui.Offset p) => channel(p, 3);

  /// Outline coverage (black outline, white fill; the bytes are
  /// premultiplied, so alpha minus red is the outline's share), sampled
  /// bilinearly between pixel centres so sub-pixel positions can be measured.
  double ink(ui.Offset p) {
    double at(int x, int y) =>
        ((_at(x, y, 3) - _at(x, y, 0)) / 255).clamp(0.0, 1.0);
    final fx = p.dx - .5, fy = p.dy - .5;
    final x = fx.floor(), y = fy.floor();
    final tx = fx - x, ty = fy - y;
    return (at(x, y) * (1 - tx) + at(x + 1, y) * tx) * (1 - ty) +
        (at(x, y + 1) * (1 - tx) + at(x + 1, y + 1) * tx) * ty;
  }
}

/// Draws through [corners], sampled every 3px with each corner a sample, or
/// exactly the given [samples].
Future<Pixels> render(
  Brush brush,
  List<ui.Offset> corners, {
  List<ui.Offset>? samples,
  double Function(ui.Offset)? pressure,
}) async {
  final tiles = TileManager(canvasWidth: size, canvasHeight: size);
  final engine = DrawingEngine(tileManager: tiles)
    ..pressureEnabled = pressure != null
    ..currentColor = const ui.Color(0xffffffff)
    ..currentBrush = brush;
  StrokePoint sample(ui.Offset p) => StrokePoint(
    x: p.dx,
    y: p.dy,
    pressure: pressure?.call(p) ?? 1,
    tiltX: 0,
    tiltY: 0,
  );
  // The canvas records the stroke so that a custom taper, which needs the
  // finished length, can restore the canvas and replay it on pointer up.
  tiles.beginUndoRecording('test');
  if (samples != null) {
    engine.beginStroke(sample(samples.first), 'test');
    for (final p in samples.skip(1)) {
      engine.continueStroke(sample(p), 'test');
    }
  } else {
    engine.beginStroke(sample(corners.first), 'test');
  }
  for (var i = 1; samples == null && i < corners.length; i++) {
    final count = ((corners[i] - corners[i - 1]).distance / 3).ceil();
    for (var j = 1; j <= count; j++) {
      engine.continueStroke(
        sample(ui.Offset.lerp(corners[i - 1], corners[i], j / count)!),
        'test',
      );
    }
  }
  if (engine.needsFinalFadeReplay) {
    final preview = tiles.endUndoRecording();
    tiles.applyTileSnapshot('test', preview.before);
    tiles.beginUndoRecording('test');
    engine.replayCurrentStrokeWithFinalFade();
  }
  engine.endStroke();
  tiles.endUndoRecording();
  final image = await tiles.compositeLayerToImage('test');
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  tiles.dispose();
  return Pixels(bytes);
}

ui.Offset unit(ui.Offset v) => v / v.distance;

/// [polyline] sampled every [step] px of arc length from [phase] on, so its
/// corners need not be samples; [jitter] shakes every sample like a hand.
List<ui.Offset> resample(
  List<ui.Offset> polyline,
  double step, {
  double phase = 0,
  double jitter = 0,
}) {
  final result = [polyline.first];
  var travelled = 0.0, next = phase > 0 ? phase : step;
  for (var i = 1; i < polyline.length; i++) {
    final a = polyline[i - 1], b = polyline[i];
    final length = (b - a).distance;
    while (next <= travelled + length) {
      result.add(ui.Offset.lerp(a, b, (next - travelled) / length)!);
      next += step;
    }
    travelled += length;
  }
  if ((result.last - polyline.last).distance > .01) result.add(polyline.last);
  return [
    for (var i = 0; i < result.length; i++)
      result[i] +
          ui.Offset(
                math.sin(i * 12.9898) * 43758.5453 % 1 - .5,
                math.sin(i * 78.233) * 43758.5453 % 1 - .5,
              ) *
              (jitter * 2),
  ];
}

/// The middle corner of [corners] rounded off with a [radius] arc.
List<ui.Offset> rounded(List<ui.Offset> corners, double radius) {
  final a = corners[0], v = corners[1], b = corners[2];
  final incoming = unit(v - a), outgoing = unit(b - v);
  final turn = math.atan2(
    incoming.dx * outgoing.dy - incoming.dy * outgoing.dx,
    incoming.dx * outgoing.dx + incoming.dy * outgoing.dy,
  );
  final tangent = radius * math.tan(turn.abs() / 2);
  final normal = ui.Offset(-incoming.dy, incoming.dx) * turn.sign;
  final centre = v - incoming * tangent + normal * radius;
  final from = math.atan2(-normal.dy, -normal.dx);
  return [
    a,
    for (var k = 0; k <= 64; k++)
      centre +
          ui.Offset(
                math.cos(from + turn * k / 64),
                math.sin(from + turn * k / 64),
              ) *
              radius,
    b,
  ];
}

/// Centre of the outline ink crossing [at] along [across], within [reach].
double? inkCentre(Pixels pixels, ui.Offset at, ui.Offset across, double reach) {
  var weight = 0.0, sum = 0.0;
  for (var s = -reach; s <= reach; s += .25) {
    final w = pixels.ink(at + across * s);
    if (w < .5) continue;
    weight += w;
    sum += w * s;
  }
  return weight == 0 ? null : sum / weight;
}

/// The inner outline of a straight leg from [from] towards the corner [to],
/// measured on the rendered strand away from the corner (at [near] and [far]
/// of the leg's length from [from]): a point on it and its direction
/// towards the corner.
({ui.Offset point, ui.Offset direction}) innerOutline(
  Pixels pixels,
  ui.Offset from,
  ui.Offset to,
  ui.Offset inner, {
  double near = .35,
  double far = .6,
}) {
  final direction = unit(to - from);
  ui.Offset measure(double t) {
    final centre = ui.Offset.lerp(from, to, t)!;
    // Scan the inner half of the strand; the outline sits at its edge.
    var edge = width / 2;
    while (edge > 2 && pixels.alpha(centre + inner * edge) < 128) {
      edge -= 1;
    }
    final guess = centre + inner * edge;
    final offset = inkCentre(pixels, guess, inner, 8);
    expect(offset, isNotNull, reason: 'inner outline at $t');
    return guess + inner * offset!;
  }

  final a = measure(near), b = measure(far);
  expect(
    ((b - a) / (b - a).distance - direction).distance,
    lessThan(.02),
    reason: 'the measured outline runs parallel to the leg',
  );
  return (point: b, direction: direction);
}

ui.Offset intersect(ui.Offset p, ui.Offset d, ui.Offset q, ui.Offset e) {
  final denominator = d.dx * e.dy - d.dy * e.dx;
  final t = ((q - p).dx * e.dy - (q - p).dy * e.dx) / denominator;
  return p + d * t;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A sharp zigzag corner and its mirror image, which turns the other way;
  // the corner between input samples, rounded off like a hand-drawn corner,
  // shaken by jitter and across a change of pressure; and a hairpin.
  const right = [ui.Offset(160, 160), ui.Offset(430, 358), ui.Offset(160, 556)];
  final left = [for (final p in right) ui.Offset(size - p.dx, p.dy)];
  // A 160-degree turn; long legs keep the measured outlines clear of the
  // overlap near the turn and of the strand's pointed tail.
  const hairpin = [ui.Offset(40, 200), ui.Offset(470, 200), ui.Offset(19, 364)];
  final hair = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0023');
  final cases =
      <
        (
          String,
          List<ui.Offset>,
          List<ui.Offset>?,
          double Function(ui.Offset)?,
          (double, double, double, double),
        )
      >[
        ('right', right, null, null, (.35, .6, .35, .6)),
        ('left', left, null, null, (.35, .6, .35, .6)),
        (
          'between samples',
          right,
          resample(right, 7, phase: 3.5),
          null,
          (.35, .6, .35, .6),
        ),
        for (final radius in [4.0, 8.0, 16.0])
          (
            'rounded $radius',
            right,
            resample(rounded(right, radius), 1),
            null,
            (.35, .6, .35, .6),
          ),
        (
          'rounded 8 jittered',
          left,
          resample(rounded(left, 8), 1, jitter: .25),
          null,
          (.35, .6, .35, .6),
        ),
        (
          'pressure change',
          right,
          null,
          // Thinner from the corner on, so the two legs differ in width
          // where their outlines meet.
          (p) => 1 - .4 * ((p.dy - 352) / 12).clamp(0.0, 1.0),
          (.35, .6, .35, .6),
        ),
        ('hairpin', hairpin, null, null, (.1, .25, .3, .45)),
        (
          'hairpin with a narrower back',
          hairpin,
          null,
          (p) => p.dy > 201 ? .6 : 1.0,
          (.1, .25, .3, .45),
        ),
      ];
  for (final (name, corner, samples, pressure, measure) in cases) {
    for (final mode in [HairFoldMode.waveTopView, HairFoldMode.waveLowAngle]) {
      test('${mode.name} $name: fold line continues the inner outline '
          'with no offset', () async {
        final pixels = await render(
          pen(
            mode: mode,
          ).copyWith(pressureOn: pressure == null ? null : hair.pressureOn),
          corner,
          samples: samples,
          pressure: pressure,
        );
        final a = corner[0], v = corner[1], b = corner[2];
        final bisector = unit(unit(b - v) - unit(v - a));
        ui.Offset innerSide(ui.Offset direction) {
          final normal = ui.Offset(-direction.dy, direction.dx);
          return normal.dx * bisector.dx + normal.dy * bisector.dy > 0
              ? normal
              : -normal;
        }

        final (nearA, farA, nearB, farB) = measure;
        final legA = innerOutline(
          pixels,
          a,
          v,
          innerSide(unit(v - a)),
          near: nearA,
          far: farA,
        );
        final legB = innerOutline(
          pixels,
          b,
          v,
          innerSide(unit(b - v)),
          near: nearB,
          far: farB,
        );
        // Where the two inner outlines meet: the fold line starts here.
        final start = intersect(
          legA.point,
          legA.direction,
          legB.point,
          legB.direction,
        );
        // Top view keeps the first section in front, so its inner outline
        // carries on as the fold line; low angle does the same with the
        // second section, backwards.
        final front = mode == HairFoldMode.waveTopView
            ? legA.direction
            : legB.direction;
        final across = ui.Offset(-front.dy, front.dx);
        // On a very sharp turn the other section's outline runs close beside
        // the fold line at first; measure where the two have parted.
        final other = mode == HairFoldMode.waveTopView ? legB : legA;
        var checked = 0;
        for (var s = 1.5; s <= 36; s += 1.5) {
          final at = start + front * s;
          final apart = at - other.point;
          if ((apart.dx * other.direction.dy - apart.dy * other.direction.dx)
                  .abs() <
              4.5) {
            continue;
          }
          if (++checked > 16) break;
          final offset = inkCentre(pixels, at, across, 4);
          expect(offset, isNotNull, reason: 'fold line ${s}px past the start');
          expect(
            offset!.abs(),
            lessThan(.6),
            reason: 'fold line ${s}px past the start is offset by $offset',
          );
          for (final side in [-4.0, 4.0]) {
            expect(
              pixels.alpha(at + across * side),
              255,
              reason: 'both sides of the line are opaque fill at $s',
            );
          }
        }
        expect(checked, greaterThan(8));
        // Nothing sticks out of the corner: just outside both outlines,
        // past the point where they meet, is empty canvas.
        final sinHalf = (unit(b - v) + unit(v - a)).distance / 2;
        final clear = (outlineWidth / 2 + 1.25) / sinHalf;
        for (var s = clear; s <= clear + 4; s += .5) {
          expect(
            pixels.alpha(start + bisector * s),
            lessThan(16),
            reason: 'no cap or ink ${s}px outside the inner corner',
          );
        }
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  }

  double angleBetween(ui.Offset a, ui.Offset b) =>
      math.atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy).abs() *
      180 /
      math.pi;
  test('a curl loop starts each fold line at its fold, not where the loop '
      'crosses itself', () {
    for (final mode in [HairFoldMode.curlRight, HairFoldMode.curlLeft]) {
      for (final (c, r) in [(10.0, 45.0), (20.0, 60.0), (30.0, 80.0)]) {
        final points = [
          for (var t = -4.2; t <= 4.2; t += .01)
            HairRibbonPoint(
              ui.Offset(300 + c * t - r * math.sin(t), 300 + r * math.cos(t)),
              28,
              1,
            ),
        ];
        final folds = HairFoldRaster.foldLineStarts(
          points,
          pen(mode: mode).copyWith(size: 28, outlineWidth: 1.5),
        );
        expect(folds, isNotEmpty);
        for (final fold in folds) {
          expect(fold.start, isNotNull, reason: '${mode.name} c$c r$r');
          expect(
            (fold.start!.origin - fold.vertex).distance,
            lessThan(28 * 1.5),
            reason: '${mode.name} c$c r$r starts at its fold',
          );
        }
      }
    }
  });
  test(
    'a fold line heads along a front outline that narrows into the fold',
    () {
      // The first leg narrows from 64 to 38 over its last 60px; the fold line
      // continues that converging outline, not the centre line.
      const v = ui.Offset(430, 358);
      final incoming = unit(v - const ui.Offset(160, 160));
      final outgoing = unit(const ui.Offset(160, 556) - v);
      double widthAt(double before) =>
          before >= 60 ? 64 : 38 + 26 * before / 60;
      final points = [
        for (var d = 330.0; d > 0; d -= 1)
          HairRibbonPoint(v - incoming * d, widthAt(d), 1),
        HairRibbonPoint(v, 38, 1),
        for (var d = 1.0; d <= 330; d += 1)
          HairRibbonPoint(v + outgoing * d, 64, 1),
      ];
      final fold = HairFoldRaster.foldLineStarts(points, pen()).single;
      final start = fold.start!;
      // The front's inner outline centre line, analytically.
      final inner =
          ui.Offset(-incoming.dy, incoming.dx) *
          (incoming.dx * outgoing.dy - incoming.dy * outgoing.dx).sign;
      ui.Offset outlineAt(double before) =>
          v -
          incoming * before +
          inner * (widthAt(before) / 2 + outlineWidth / 2);
      final before =
          (v - start.origin).dx * incoming.dx +
          (v - start.origin).dy * incoming.dy;
      final expected = unit(outlineAt(before) - outlineAt(before + 4));
      expect(angleBetween(start.direction, expected), lessThan(1.5));
      expect((start.origin - outlineAt(before)).distance, lessThan(.75));
    },
  );
  test(
    'a fold line near the previous corner still heads along its own leg',
    () {
      // A 120-degree zigzag of 70px legs: the outlines meet 12px before the
      // previous corner.
      final corners = [
        for (var k = 0; k < 6; k++)
          ui.Offset(100 + k * 35.0, k.isEven ? 100 : 160.6),
      ];
      final points = [
        for (var k = 1; k < corners.length; k++)
          for (var j = k == 1 ? 0 : 1; j <= 70; j++)
            HairRibbonPoint(
              ui.Offset.lerp(corners[k - 1], corners[k], j / 70)!,
              64,
              1,
            ),
      ];
      final folds = HairFoldRaster.foldLineStarts(points, pen());
      expect(folds.where((f) => f.start != null), isNotEmpty);
      for (final fold in folds) {
        final start = fold.start;
        if (start == null) continue;
        final k =
            [
              for (var i = 1; i < corners.length - 1; i++)
                (corners[i] - fold.vertex).distance,
            ].indexed.reduce((a, b) => a.$2 <= b.$2 ? a : b).$1 +
            1;
        final leg = unit(corners[k] - corners[k - 1]);
        expect(angleBetween(start.direction, leg), lessThan(2));
      }
    },
  );
  test(
    'past where the fold line starts, the front\'s own edge is hidden',
    () async {
      // A 155-degree turn: the outlines meet far from the fold, and with the
      // default angle the fold line curves away from the front's straight
      // inner outline, which must not run on beside it.
      final out = ui.Offset(
        math.cos(math.pi * 155 / 180),
        math.sin(math.pi * 155 / 180),
      );
      final corner = [
        const ui.Offset(40, 200),
        const ui.Offset(470, 200),
        const ui.Offset(470, 200) + out * 430,
      ];
      final pixels = await render(pen(angle: .5), corner);
      final a = corner[0], v = corner[1], b = corner[2];
      final bisector = unit(unit(b - v) - unit(v - a));
      ui.Offset innerSide(ui.Offset direction) {
        final normal = ui.Offset(-direction.dy, direction.dx);
        return normal.dx * bisector.dx + normal.dy * bisector.dy > 0
            ? normal
            : -normal;
      }

      final legA = innerOutline(
        pixels,
        a,
        v,
        innerSide(unit(v - a)),
        near: .1,
        far: .3,
      );
      // Clear of the strand's pointed tail at the other end.
      final legB = innerOutline(
        pixels,
        b,
        v,
        innerSide(unit(b - v)),
        near: .32,
        far: .5,
      );
      final start = intersect(
        legA.point,
        legA.direction,
        legB.point,
        legB.direction,
      );
      for (var s = 16.0; s <= 60; s += 2) {
        expect(
          pixels.ink(start + legA.direction * s),
          lessThan(.3),
          reason: 'no straight edge ${s}px past the fold line start',
        );
      }
    },
  );
  // A straight stroke whose custom taper ends at zero over its last 120px.
  const straight = [ui.Offset(80, 300), ui.Offset(520, 300)];
  const zigzag = [
    ui.Offset(120, 80),
    ui.Offset(400, 300),
    ui.Offset(120, 520),
    ui.Offset(230, 586),
  ];
  // Samples every 2px, or ending in a fast 40px flick, the usual input for
  // an exit stroke: a single sparse segment across most of the taper.
  final flick = [
    ...resample(const [ui.Offset(80, 300), ui.Offset(480, 300)], 2),
    const ui.Offset(520, 300),
  ];
  for (final (input, samples) in [('dense', null), ('exit flick', flick)]) {
    // A straight stroke never starts a crescent; see the crescent test below.
    for (final mode in HairFoldMode.values.where(
      (m) => m != HairFoldMode.crescent,
    )) {
      test(
        '${mode.name} $input: the taper narrows the tail like fold off, never '
        'fades it',
        () async {
          Brush tapered(bool fold) =>
              pen(mode: mode, fold: fold, fade: FadeMode.custom);
          final off = await render(tapered(false), straight, samples: samples);
          final on = await render(tapered(true), straight, samples: samples);
          // 60px and 30px before the end (halfway and a quarter of the way
          // into the 120px taper, as steep at the tip as a straight ramp and
          // rounding into the full width) the taper has narrowed the width to
          // five eighths and under a third, yet the centre stays fully
          // opaque.
          for (final x in [460, 490]) {
            expect(
              on.alpha(ui.Offset(x.toDouble(), 300)),
              greaterThan(250),
              reason: 'centre of the tapered tail at x=$x',
            );
          }
          final tail = [
            for (var y = 250; y <= 350; y++)
              if (on.alpha(ui.Offset(460, y.toDouble())) > 127) y,
          ];
          expect(
            tail.length,
            inInclusiveRange(41, 48),
            reason: 'five eighths of the whole width, outline included',
          );
          // Column by column, the tail has the ordinary outline pen's width
          // and solid outline ink, up to the sharp tip.
          for (var x = 380; x <= 516; x += 2) {
            double coverage(Pixels pixels) => [
              for (var y = 250; y <= 350; y++)
                pixels.alpha(ui.Offset(x.toDouble(), y.toDouble())) / 255,
            ].fold(0.0, (a, b) => a + b);
            double darkest(Pixels pixels) => [
              for (var y = 250; y <= 350; y++)
                pixels.ink(ui.Offset(x + .5, y + .5)),
            ].fold(0.0, math.max);
            expect(
              (coverage(on) - coverage(off)).abs(),
              lessThan(.5),
              reason: 'tail width at x=$x',
            );
            expect(darkest(on), greaterThan(.9), reason: 'outline ink at x=$x');
            expect(darkest(off), greaterThan(.9), reason: 'fold off at x=$x');
          }
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  }
  for (final mode in [
    HairFoldMode.waveTopView,
    HairFoldMode.waveLowAngle,
    HairFoldMode.curlRight,
    HairFoldMode.curlLeft,
  ]) {
    test(
      '${mode.name}: the folded strand keeps its opacity to the tip',
      () async {
        final pixels = await render(
          pen(mode: mode, fade: FadeMode.custom, angle: .5),
          zigzag,
        );
        // The final run, after the last fold, up to the tip.
        final end = zigzag.last, from = zigzag[2];
        final direction = unit(end - from);
        for (var s = 10.0; s <= 80; s += 10) {
          expect(
            pixels.alpha(end - direction * s),
            greaterThan(250),
            reason: '${s}px before the end',
          );
        }
        // The tip ends in solid outline ink, not a faint hairline.
        var tip = 0.0;
        for (var dy = -3.0; dy <= 3; dy += .5) {
          for (var dx = -3.0; dx <= 3; dx += .5) {
            tip = math.max(tip, pixels.ink(end + ui.Offset(dx, dy)));
          }
        }
        expect(tip, greaterThan(.9));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
  // Pressure rises over the first half and the custom taper ends the stroke:
  // both reshape the whole strand while its outline band keeps its width.
  for (final fold in [false, true]) {
    test('outline band keeps its width under pressure and taper '
        '(fold ${fold ? 'on' : 'off'})', () async {
      final hair = brushExtensionPresets().singleWhere(
        (b) => b.id == 'Brush0023',
      );
      final pixels = await render(
        pen(
          fold: fold,
          fade: FadeMode.custom,
        ).copyWith(size: 48, pressureOn: hair.pressureOn),
        straight,
        pressure: (p) => ((p.dx - 80) / 220).clamp(.05, 1.0),
      );
      var measured = 0;
      for (var x = 90; x <= 512; x += 6) {
        var ink = 0.0, coverage = 0.0;
        for (var y = 250; y <= 350; y++) {
          final at = ui.Offset(x + .5, y + .5);
          ink += pixels.ink(at);
          coverage += pixels.alpha(at) / 255;
        }
        // Wherever fill still shows, the two outline bands are each the
        // outline width, however narrow pressure or the taper made it.
        if (coverage < outlineWidth * 2 + 3) continue;
        measured++;
        expect(
          ink / 2,
          closeTo(outlineWidth, .2),
          reason: 'outline band at x=$x (strand ${coverage}px)',
        );
      }
      expect(measured, greaterThan(50));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
  test('a crescent tail narrows with the taper, never fades or thins its '
      'outline', () async {
    // A C-curve deep enough to start a crescent, then a straight run whose
    // last 120px taper to nothing.
    final curl = [
      for (var i = 0; i <= 90; i++)
        ui.Offset(250, 200) +
            ui.Offset(
                  math.cos(-math.pi / 2 + math.pi * i / 90),
                  math.sin(-math.pi / 2 + math.pi * i / 90),
                ) *
                110,
      for (var i = 1; i <= 95; i++) ui.Offset(250 - i * 2.0, 310),
    ];
    Brush crescent(bool fold) => pen(
      mode: HairFoldMode.crescent,
      fold: fold,
      fade: FadeMode.custom,
    ).copyWith(size: 40);
    final on = await render(crescent(true), curl, samples: curl);
    final off = await render(crescent(false), curl, samples: curl);
    var changed = 0;
    for (var i = 0; i < on.bytes.length; i += 4) {
      if ((on.bytes[i + 3] - off.bytes[i + 3]).abs() > 64) changed++;
    }
    expect(changed, greaterThan(500), reason: 'the crescent is drawn');
    // The tail is the crescent's own horn, narrower than the ordinary pen.
    // Wherever it is wider than its two outlines, it is fully opaque and its
    // outline keeps its width.
    var measured = 0;
    for (var x = 64; x <= 230; x += 2) {
      var ink = 0.0, coverage = 0.0;
      for (var y = 270; y <= 350; y++) {
        final at = ui.Offset(x + .5, y + .5);
        ink += on.ink(at);
        coverage += on.alpha(at) / 255;
      }
      if (coverage < outlineWidth * 2 + 3) continue;
      measured++;
      var centre = 0;
      for (var y = 300; y <= 320; y++) {
        centre = math.max(centre, on.alpha(ui.Offset(x.toDouble(), y + .5)));
      }
      expect(centre, 255, reason: 'opaque at x=$x');
      expect(ink / 2, closeTo(outlineWidth, .2), reason: 'outline at x=$x');
    }
    expect(measured, greaterThan(40));

    // Light pressure narrows the whole crescent; across its curved body the
    // outline still keeps its width.
    final hair = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0023',
    );
    final light = await render(
      crescent(true).copyWith(pressureOn: hair.pressureOn),
      curl,
      samples: curl,
      pressure: (_) => .3,
    );
    var bands = 0;
    for (var degrees = 40; degrees <= 140; degrees += 10) {
      final angle = -math.pi / 2 + degrees * math.pi / 180;
      final across = ui.Offset(math.cos(angle), math.sin(angle));
      var ink = 0.0, coverage = 0.0;
      for (var r = 40.0; r <= 200; r += .5) {
        final at = const ui.Offset(250, 200) + across * r;
        ink += light.ink(at) * .5;
        coverage += light.alpha(at) / 255 * .5;
      }
      if (coverage < outlineWidth * 2 + 3) continue;
      bands++;
      expect(
        ink / 2,
        closeTo(outlineWidth, .3),
        reason: 'outline across the curve at $degrees degrees',
      );
    }
    expect(bands, greaterThan(5));
  }, timeout: const Timeout(Duration(minutes: 2)));
  for (final fold in [false, true]) {
    test('pressure never changes an outline pen\'s opacity '
        '(fold ${fold ? 'on' : 'off'})', () async {
      // A pen whose pressure would otherwise also set its opacity.
      const pressureOn = BrushPressureOnSettings(
        size: PressureRangeSetting(enabled: true, weak: 20, strong: 100),
        opacity: PressureRangeSetting(enabled: true, weak: 10, strong: 100),
        blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        edgeJitter: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
        mixing: PressureMixingOnSetting(
          enabled: false,
          mode: BrushMixingMode.simple,
          weakRate: 0,
          strongRate: 0,
        ),
      );
      final pixels = await render(
        pen(fold: fold).copyWith(pressureOn: pressureOn),
        straight,
        pressure: (_) => .4,
      );
      var darkest = 0.0;
      for (var y = 250; y <= 350; y++) {
        darkest = math.max(darkest, pixels.ink(ui.Offset(300.5, y + .5)));
      }
      expect(pixels.alpha(const ui.Offset(300, 300)), 255);
      expect(darkest, greaterThan(.95));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
  test(
    'repeated strands keep the ordinary spacing under light pressure',
    () async {
      // Lateral repeats are spaced by the strand's width; pressure scales the
      // whole strand, so fold on and off place them alike.
      final hair = brushExtensionPresets().singleWhere(
        (b) => b.id == 'Brush0023',
      );
      Brush repeated(bool fold) => pen(fold: fold).copyWith(
        size: 28,
        pressureOn: hair.pressureOn,
        lateralRepeatEnabled: true,
        lateralRepeatCount: 3,
        lateralRepeatSpacing: 1.5,
      );
      final off = await render(repeated(false), straight, pressure: (_) => .05);
      final on = await render(repeated(true), straight, pressure: (_) => .05);
      var different = 0;
      for (var y = 250; y <= 350; y++) {
        final at = ui.Offset(300.5, y + .5);
        if ((on.alpha(at) > 127) != (off.alpha(at) > 127) ||
            (on.ink(at) > .5) != (off.ink(at) > .5)) {
          different++;
        }
      }
      expect(different, lessThanOrEqualTo(2));
    },
  );
  test('an unscaled outline pen keeps exactly half its width as fill', () {
    for (var outline = .25; outline <= 8; outline += .01) {
      expect(
        outlinedStrokeRadii(width: 1, scale: 1, outlineWidth: outline).fill,
        .5,
        reason: 'outline $outline',
      );
    }
  });
  test('a pixel-mode outline pen tip stays binary', () async {
    final pixels = await render(
      pen(fold: false, fade: FadeMode.custom).copyWith(pixelMode: true),
      straight,
    );
    for (var i = 3; i < pixels.bytes.length; i += 4) {
      expect(pixels.bytes[i] == 0 || pixels.bytes[i] == 255, isTrue);
    }
  });
  test('a custom taper rounds into the full width, with no corner where it '
      'begins, and still ends in a point', () async {
    for (final fold in [false, true]) {
      final pixels = await render(
        pen(fold: fold, fade: FadeMode.custom),
        straight,
      );
      int width(int x) => [
        for (var y = 250; y <= 350; y++)
          if (pixels.alpha(ui.Offset(x.toDouble(), y.toDouble())) > 127) y,
      ].length;
      // The 120px taper begins at x = 400. A straight ramp would already
      // have taken a tenth of the width 12px in, and a fifth 24px in.
      final full = width(380);
      expect(width(400), closeTo(full, 2), reason: 'fold $fold');
      expect(full - width(412), lessThanOrEqualTo(3), reason: 'fold $fold');
      expect(full - width(424), lessThanOrEqualTo(7), reason: 'fold $fold');
      // Halfway, five eighths of the width (a little more where the
      // shrinking pen's edge sweeps past).
      expect(
        width(460),
        inInclusiveRange(full * .6, full * .7),
        reason: 'fold $fold',
      );
      expect(width(516), lessThanOrEqualTo(6), reason: 'fold $fold');
    }
  });
  test('other brushes keep fading their opacity', () async {
    final pixels = await render(
      pen(fold: false, outlined: false, fade: FadeMode.custom),
      straight,
    );
    // A quarter of the way into the taper: under a third of the opacity.
    final alpha = pixels.alpha(const ui.Offset(490, 300));
    expect(alpha, lessThan(200));
    expect(alpha, greaterThan(40));
  });
}
