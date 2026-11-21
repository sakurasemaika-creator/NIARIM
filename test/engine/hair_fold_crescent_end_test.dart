// The end of a finished 「三日月カール」 stroke gives way to the ordinary strand
// the same way its start does. A C turned a little past half a turn used to
// end in a long hairline of bare outline (hair) or a thread followed by a
// square block (ribbon): the crescent's bow ran out at the end of its chord,
// the head's lead adjustment removed the strand's width along the chord, and
// the short sliver past half a turn was swollen into a crescent of its own.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

import '../helpers/color_channels.dart';

const _width = 400, _height = 220;
const _fill = ui.Color(0xffc4886e);

/// A C of radius 85, from its top clockwise round to a little past its
/// bottom (198 degrees).
List<ui.Offset> _c() => [
  for (var i = 0; i <= 120; i++)
    () {
      final a = -math.pi / 2 + math.pi * 1.1 * i / 120;
      return ui.Offset(200 + 85 * math.cos(a), 105 + 85 * math.sin(a));
    }(),
];

Future<Uint8List> _draw(WidgetTester tester, Brush brush) async {
  final tiles = TileManager(canvasWidth: _width, canvasHeight: _height);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = _fill
    ..pressureEnabled = false;
  StrokePoint p(ui.Offset a) =>
      StrokePoint(x: a.dx, y: a.dy, pressure: 1, tiltX: 0, tiltY: 0);
  final input = _c();
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

/// Across the strand at [distanceFromEnd] (along the drawn path) before the
/// end: how many pixels are covered, and how many of those are fill rather
/// than outline.
({int covered, int fill}) _crossSection(
  Uint8List rgba,
  double distanceFromEnd,
) {
  final path = _c();
  var remaining = distanceFromEnd;
  var i = path.length - 1;
  while (i > 0 && remaining > (path[i] - path[i - 1]).distance) {
    remaining -= (path[i] - path[i - 1]).distance;
    i--;
  }
  final a = path[i - 1], b = path[i];
  final along = (b - a) / (b - a).distance;
  final at = b - along * remaining;
  final normal = ui.Offset(-along.dy, along.dx);
  var covered = 0, fill = 0;
  for (var k = -40; k <= 40; k++) {
    final q = at + normal * (k / 2);
    final x = q.dx.round(), y = q.dy.round();
    if (x < 0 || y < 0 || x >= _width || y >= _height) continue;
    final j = (y * _width + x) * 4;
    if (rgba[j + 3] < 200) continue;
    covered++;
    final close =
        (rgba[j] - _fill.red8).abs() +
            (rgba[j + 1] - _fill.green8).abs() +
            (rgba[j + 2] - _fill.blue8).abs() <
        40;
    if (close) fill++;
  }
  // Half-pixel steps: back to pixels.
  return (covered: covered ~/ 2, fill: fill ~/ 2);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a ribbon crescent keeps its width into its square cut', (
    tester,
  ) async {
    final ribbon = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0040',
    );
    final rgba = await _draw(tester, ribbon);
    for (final distance in [4.0, 10.0, 20.0, 30.0, 45.0]) {
      final section = _crossSection(rgba, distance);
      expect(
        section.covered,
        greaterThan(ribbon.size * .5),
        reason: '${distance}px before the end: $section',
      );
    }
  });

  testWidgets('a hair crescent ends in a filled tip, not bare outline', (
    tester,
  ) async {
    final hair = brushExtensionPresets().singleWhere(
      (b) => b.id == 'Brush0035',
    );
    final rgba = await _draw(tester, hair);
    for (final distance in [30.0, 45.0]) {
      final section = _crossSection(rgba, distance);
      expect(
        section.fill,
        greaterThanOrEqualTo(2),
        reason: '${distance}px before the end: $section',
      );
    }
  });
}
