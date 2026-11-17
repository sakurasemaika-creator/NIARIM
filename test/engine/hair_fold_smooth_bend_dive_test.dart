// On a smooth bend (radius larger than the strand's half width, so the two
// inner outlines never cross) the fold line is the front section's inner
// outline carried on straight from where it is straightest (a wave's
// inflection), then turned with the stroke: it leaves the outline at no
// angle, passes under the apex, never runs outside that straight extension
// (where the folded part would look suddenly thinner) and stays clear of
// the far outline (the owner's blue, green and yellow marks on the
// 「ウェーブ俯瞰」 hair and ribbon samples). It used to leave the apex along
// its tangent and run beside the inner outline.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

const _width = 480, _height = 200;

/// Down into a trough at x = 110, over a crest at x = 205 and down again.
List<ui.Offset> _wave() => [
  for (var i = 0; i <= 220; i++)
    () {
      final x = 30 + 410 * i / 220;
      return ui.Offset(x, 100 + 34 * math.cos(2 * math.pi * (x - 110) / 190));
    }(),
];

Future<Uint8List> _draw(WidgetTester tester, Brush brush) async {
  final tiles = TileManager(canvasWidth: _width, canvasHeight: _height);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xffc4886e)
    ..pressureEnabled = false;
  StrokePoint p(ui.Offset a) =>
      StrokePoint(x: a.dx, y: a.dy, pressure: 1, tiltX: 0, tiltY: 0);
  final input = _wave();
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
  final pixels = (await tester.runAsync(() async {
    final image = await tiles.compositeLayerToImage('hair');
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return Uint8List.fromList(data!.buffer.asUint8List());
  }))!;
  tiles.dispose();
  return pixels;
}

/// Each column's strand top and bottom, and its crease pixel nearest the
/// middle (darker than the fill, away from the strand's own edges).
({int top, int bottom, int? crease})? _column(Uint8List rgba, int x) {
  int? top;
  var bottom = 0;
  for (var y = 0; y < _height; y++) {
    if (rgba[(y * _width + x) * 4 + 3] > 200) {
      top ??= y;
      bottom = y;
    }
  }
  if (top == null) return null;
  int? crease;
  for (var y = top + 3; y <= bottom - 3; y++) {
    final i = (y * _width + x) * 4;
    final luma = rgba[i] * .3 + rgba[i + 1] * .59 + rgba[i + 2] * .11;
    if (luma < 110) crease = y;
  }
  return (top: top, bottom: bottom, crease: crease);
}

/// How far below the inner apex of the first trough the fold line reaches:
/// the lowest crease pixel (darker than the fill, away from the strand's own
/// edges) in the columns just after the apex, from the apex's height. A line
/// along the apex tangent turns up with the stroke and never goes below it.
/// Also the deepest crease as a share of its column's strand, to check that
/// it stays inside.
({double dive, double share}) _diveBelowApex(
  Uint8List rgba,
  double strandWidth,
) {
  int? topAt(int x) {
    for (var y = 0; y < _height; y++) {
      if (rgba[(y * _width + x) * 4 + 3] > 200) return y;
    }
    return null;
  }

  final apex = topAt(110)!;
  var dive = 0.0, share = 0.0;
  for (var x = 112; x <= 112 + strandWidth * .7; x++) {
    final top = topAt(x);
    if (top == null) continue;
    var bottom = top;
    for (var y = top; y < _height; y++) {
      if (rgba[(y * _width + x) * 4 + 3] > 200) bottom = y;
    }
    for (var y = top + 3; y <= bottom - 3; y++) {
      final i = (y * _width + x) * 4;
      final luma = rgba[i] * .3 + rgba[i + 1] * .59 + rgba[i + 2] * .11;
      if (luma < 110) {
        dive = math.max(dive, (y - apex).toDouble());
        share = math.max(share, (y - top) / (bottom - top));
      }
    }
  }
  return (dive: dive, share: share);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the hair and ribbon fold lines dive into the strand on a '
      'smooth bend', (tester) async {
    final presets = brushExtensionPresets();
    for (final (id, minimum) in const [
      ('Brush0023', .2), // hair: dips about a third of the strand
      ('Brush0036', .35), // ribbon: dives about half the strand
    ]) {
      final brush = presets.singleWhere((b) => b.id == id);
      final strandWidth = brush.size + brush.outlineWidth * 2;
      final (:dive, :share) = _diveBelowApex(
        await _draw(tester, brush),
        strandWidth,
      );
      expect(
        dive,
        greaterThan(strandWidth * minimum),
        reason:
            '$id reaches ${dive}px below the apex of a ${strandWidth}px '
            'strand',
      );
      // ...and stays inside it (it never runs into the outer outline).
      expect(share, lessThan(.85), reason: id);
      final rgba = await _draw(tester, brush);
      final (:leading, :outside) = _againstExtension(rgba, brush);
      expect(
        leading,
        greaterThanOrEqualTo(2),
        reason: '$id leads in from the outline',
      );
      expect(outside, 0, reason: '$id runs outside the straight extension');
    }
  });

  testWidgets('no fold setting takes the line outside the straight '
      'extension', (tester) async {
    final presets = brushExtensionPresets();
    for (final id in const ['Brush0023', 'Brush0036']) {
      for (final (angle, start, length) in const [
        (.2, .95, 1.0),
        (.5, .9, 1.0),
        (1.0, .9, 1.0),
        (.5, 0.0, 1.0),
      ]) {
        final brush = presets
            .singleWhere((b) => b.id == id)
            .copyWith(
              foldAngleRatio: angle,
              foldCurveStartRatio: start,
              foldLengthRatio: length,
            );
        final (:leading, :outside) = _againstExtension(
          await _draw(tester, brush),
          brush,
        );
        expect(outside, 0, reason: '$id $angle/$start/$length');
      }
    }
  });
}

/// Against the inner outline's straight extension from the inflection
/// before the first trough (x = 62.5, where the wave descends steepest):
/// columns where the line already runs just inside the incoming outline
/// before the apex, and columns where it runs outside the extension.
({int leading, int outside}) _againstExtension(Uint8List rgba, Brush brush) {
  final strandWidth = brush.size + brush.outlineWidth * 2;
  final tangent = ui.Offset(1, 34 * 2 * math.pi / 190);
  final along = tangent / tangent.distance;
  final inner = ui.Offset(along.dy, -along.dx);
  final nibAngle = brush.calligraphyAngle;
  final widthAtInflection = nibAngle == null
      ? brush.size
      : brush.size *
            nibWidthAcross(
              along,
              brush.nibWidthRatio,
              nibAngle * math.pi / 180,
            );
  final rim = widthAtInflection / 2 + brush.outlineWidth / 2;
  final branch = const ui.Offset(62.5, 100) + inner * rim;
  var leading = 0, outside = 0;
  for (var x = branch.dx.round() + 4; x <= 110 + strandWidth; x++) {
    final c = _column(rgba, x);
    if (c?.crease == null) continue;
    final at = ui.Offset(x.toDouble(), c!.crease!.toDouble());
    if (x < 110 - strandWidth * .25 && at.dy - c.top <= strandWidth * .45) {
      leading++;
    }
    final side = (at - branch).dx * inner.dx + (at - branch).dy * inner.dy;
    if (side < -2) outside++;
  }
  return (leading: leading, outside: outside);
}
