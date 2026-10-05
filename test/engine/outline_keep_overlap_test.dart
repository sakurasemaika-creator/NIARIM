import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const size = 400;
const white = 0xffffffff, black = 0xff000000;
const red = 0xffff0000, blue = 0xff0000ff;

/// A white strand outlined in black across the canvas, then a red strand
/// outlined in blue crossing it, both 40px wide with a 4px outline.
Brush outlinePen({
  required int outline,
  required bool keep,
  required bool fold,
  double size = 40,
}) => Brush(
  id: 'outline',
  name: 'Outline',
  size: size,
  opacity: 100,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  outlineEnabled: true,
  outlineWidth: 4,
  outlineColor: outline,
  outlineKeepOverlap: keep,
  foldEnabled: fold,
);

Future<Uint8List> draw(
  List<(List<ui.Offset>, int fill, Brush brush)> strokes,
) async {
  final tiles = TileManager(canvasWidth: size, canvasHeight: size);
  final engine = DrawingEngine(tileManager: tiles)..pressureEnabled = false;
  StrokePoint sample(ui.Offset p) =>
      StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0);
  for (final (corners, fill, brush) in strokes) {
    engine
      ..currentColor = ui.Color(fill)
      ..currentBrush = brush;
    engine.beginStroke(sample(corners.first), 'test');
    for (var i = 1; i < corners.length; i++) {
      final count = ((corners[i] - corners[i - 1]).distance / 2).ceil();
      for (var j = 1; j <= count; j++) {
        engine.continueStroke(
          sample(ui.Offset.lerp(corners[i - 1], corners[i], j / count)!),
          'test',
        );
      }
    }
    engine.endStroke();
  }
  final image = await tiles.compositeLayerToImage('test');
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  tiles.dispose();
  return Uint8List.fromList(data!.buffer.asUint8List());
}

Future<Uint8List> crossing({required bool keep, required bool fold}) async {
  final tiles = TileManager(canvasWidth: size, canvasHeight: size);
  final engine = DrawingEngine(tileManager: tiles)..pressureEnabled = false;
  void stroke(ui.Offset from, ui.Offset to, int fill, int outline) {
    engine
      ..currentColor = ui.Color(fill)
      ..currentBrush = Brush(
        id: 'outline',
        name: 'Outline',
        size: 40,
        opacity: 100,
        spacing: 1,
        stabilization: false,
        stabilizationStrength: 0,
        pixelMode: false,
        fadeMode: FadeMode.off,
        strokeDecay: false,
        outlineEnabled: true,
        outlineWidth: 4,
        outlineColor: outline,
        outlineKeepOverlap: keep,
        foldEnabled: fold,
      );
    StrokePoint sample(ui.Offset p) =>
        StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0);
    engine.beginStroke(sample(from), 'test');
    for (var i = 1; i <= 100; i++) {
      engine.continueStroke(sample(ui.Offset.lerp(from, to, i / 100)!), 'test');
    }
    engine.endStroke();
  }

  stroke(const ui.Offset(40, 200), const ui.Offset(360, 200), white, black);
  stroke(const ui.Offset(200, 40), const ui.Offset(200, 360), red, blue);
  final image = await tiles.compositeLayerToImage('test');
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  tiles.dispose();
  return Uint8List.fromList(data!.buffer.asUint8List());
}

int colorAt(Uint8List pixels, int x, int y) {
  final i = (y * size + x) * 4;
  return pixels[i + 3] << 24 |
      pixels[i] << 16 |
      pixels[i + 1] << 8 |
      pixels[i + 2];
}

bool bluish(Uint8List pixels, int x, int y) {
  final i = (y * size + x) * 4;
  return pixels[i + 3] > 128 && pixels[i + 2] > 128 && pixels[i] < 100;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A wide white strand, then a folding zigzag drawn over it again and again
  // as when drawing hair, whose last fold lies outside the white strand.
  Future<Uint8List> layered(bool keep) => draw([
    (
      const [ui.Offset(20, 160), ui.Offset(380, 160)],
      white,
      outlinePen(outline: black, keep: keep, fold: true, size: 140),
    ),
    for (var pass = 0; pass < 3; pass++)
      (
        [
          ui.Offset(40, 120 + pass * 4.0),
          ui.Offset(100, 200 + pass * 4.0),
          ui.Offset(160, 120 + pass * 4.0),
          ui.Offset(220, 200 + pass * 4.0),
          const ui.Offset(300, 330),
          const ui.Offset(360, 240),
        ],
        red,
        outlinePen(outline: blue, keep: keep, fold: true, size: 26),
      ),
  ]);
  // Well inside the white strand drawn on its own.
  late final Future<Uint8List> base = draw([
    (
      const [ui.Offset(20, 160), ui.Offset(380, 160)],
      white,
      outlinePen(outline: black, keep: true, fold: true, size: 140),
    ),
  ]);
  bool whiteAt(Uint8List pixels, int x, int y) =>
      colorAt(pixels, x.clamp(0, size - 1), y.clamp(0, size - 1)) == white;
  Future<int> blueInside(Uint8List pixels) async {
    final alone = await base;
    var count = 0, inside = 0;
    for (var y = 90; y <= 240; y++) {
      for (var x = 20; x <= 380; x++) {
        if (![
          for (final (dx, dy) in [(0, 0), (6, 0), (-6, 0), (0, 6), (0, -6)])
            whiteAt(alone, x + dx, y + dy),
        ].every((w) => w)) {
          continue;
        }
        inside++;
        if (bluish(pixels, x, y)) count++;
      }
    }
    expect(inside, greaterThan(10000));
    return count;
  }

  int blueOutside(Uint8List pixels) {
    var count = 0;
    for (var y = 300; y <= 360; y++) {
      for (var x = 260; x <= 340; x++) {
        if (bluish(pixels, x, y)) count++;
      }
    }
    return count;
  }

  test('without keeping overlaps, fold lines vanish with the outline where '
      'strokes merge', () async {
    final merged = await layered(false);
    expect(
      await blueInside(merged),
      0,
      reason: 'no outline or fold line floats inside the merged strands',
    );
    expect(blueOutside(merged), greaterThan(100), reason: 'on its own');
    final kept = await layered(true);
    expect(
      await blueInside(kept),
      greaterThan(300),
      reason: 'keeping overlaps',
    );
  });
  // The red strand's outline runs at x = 200 ± 22; the white strand's at
  // y = 200 ± 22.
  for (final fold in [false, true]) {
    final path = fold ? 'fold on' : 'fold off';
    test('$path: keeping overlaps outlines the later strand across the '
        'earlier one', () async {
      final pixels = await crossing(keep: true, fold: fold);
      expect(colorAt(pixels, 222, 200), blue, reason: 'over the white fill');
      expect(colorAt(pixels, 222, 120), blue, reason: 'on its own');
      expect(colorAt(pixels, 200, 178), red, reason: 'covers the old outline');
    });
    test('$path: without keeping overlaps the strands merge and only the '
        'outside is outlined', () async {
      final pixels = await crossing(keep: false, fold: fold);
      expect(
        colorAt(pixels, 222, 200),
        white,
        reason: 'no outline over the earlier strand',
      );
      expect(colorAt(pixels, 222, 120), blue, reason: 'outside both strands');
      expect(
        colorAt(pixels, 200, 178),
        red,
        reason: 'the earlier outline inside the new strand is gone',
      );
      expect(
        colorAt(pixels, 222, 178),
        black,
        reason: 'the earlier outline stays where both outlines meet',
      );
      expect(
        colorAt(pixels, 120, 178),
        black,
        reason: 'the earlier strand keeps its own outline elsewhere',
      );
    });
  }
}
