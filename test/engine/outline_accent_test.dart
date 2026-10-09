import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/outline_accent.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const _size = 400;

/// A U: down the left, round a half circle of [radius] at the bottom, and up
/// the right, 2 px between points.
List<ui.Offset> _u({double radius = 120, double jitter = 0}) {
  final random = math.Random(7);
  double wobble() => (random.nextDouble() * 2 - 1) * jitter;
  const cx = 200.0, cy = 200.0;
  return [
    for (var y = 60.0; y < cy; y += 2) ui.Offset(cx - radius + wobble(), y),
    for (var a = math.pi; a > 0; a -= 2 / radius)
      ui.Offset(cx + radius * math.cos(a), cy + radius * math.sin(a)),
    for (var y = cy; y >= 60; y -= 2) ui.Offset(cx + radius + wobble(), y),
  ];
}

List<double> _lengths(List<ui.Offset> points) {
  final lengths = <double>[0];
  for (var i = 1; i < points.length; i++) {
    lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
  }
  return lengths;
}

Brush _pen({required bool accent}) => Brush(
  id: 'outline',
  name: 'Outline',
  size: 30,
  opacity: 100,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  outlineEnabled: true,
  outlineWidth: 2,
  outlineColor: 0xff000000,
  outlineAccentEnabled: accent,
  outlineAccentWidth: 10,
);

/// [points] drawn with [brush] as the canvas does it: live, then again once
/// the pen is lifted when the stroke asks for it.
Future<Uint8List> _draw(List<ui.Offset> points, Brush brush) async {
  final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
  final engine = DrawingEngine(tileManager: tiles)
    ..pressureEnabled = false
    ..currentColor = const ui.Color(0xffffffff)
    ..currentBrush = brush;
  StrokePoint sample(ui.Offset p) =>
      StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0);
  tiles.beginUndoRecording('test');
  engine.beginStroke(sample(points.first), 'test');
  for (final p in points.skip(1)) {
    engine.continueStroke(sample(p), 'test');
  }
  if (engine.needsFinalFadeReplay) {
    final live = tiles.endUndoRecording();
    if (live.before.isNotEmpty) tiles.applyTileSnapshot('test', live.before);
    tiles.beginUndoRecording('test');
    engine.replayCurrentStrokeWithFinalFade();
  }
  engine.endStroke();
  tiles.endUndoRecording();
  final image = await tiles.compositeLayerToImage('test');
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  tiles.dispose();
  return Uint8List.fromList(data!.buffer.asUint8List());
}

/// How many outline (dark, opaque) pixels from ([x], [y]) on, stepping by
/// ([dx], [dy]) for [steps].
int _outline(Uint8List rgba, int x, int y, int dx, int dy, int steps) {
  var count = 0;
  for (var k = 0; k < steps; k++) {
    final i = ((y + dy * k) * _size + x + dx * k) * 4;
    if (rgba[i + 3] > 128 && rgba[i] < 128) count++;
  }
  return count;
}

/// 縁取りの強弱: the outline thickens towards the apex of every curve, from
/// the outline width where the curve begins and ends to the set width at
/// its apex, gradually; straight parts keep the outline width.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a U: the outline width on the straight sides, the most at the '
      'bottom, growing gradually between', () {
    final points = _u();
    final accent = OutlineAccent.of(points, base: 2, apex: 10, span: 30);
    final lengths = _lengths(points);
    final total = lengths.last;
    // The half circle runs from 140 px to 140 + 120π px along the stroke.
    const start = 140.0;
    final end = start + 120 * math.pi, middle = (start + end) / 2;
    expect(accent.at(20), closeTo(2, .01), reason: 'the straight lead-in');
    expect(accent.at(total - 20), closeTo(2, .01), reason: 'the lead-out');
    expect(accent.at(middle), closeTo(10, .3), reason: 'the apex');
    var previous = accent.at(start);
    for (var s = start; s <= middle; s += 4) {
      final w = accent.at(s);
      expect(w, greaterThanOrEqualTo(previous - 1e-9), reason: 'grows at $s');
      previous = w;
    }
    final quarter = accent.at((start + middle) / 2);
    expect(quarter, inInclusiveRange(4, 8), reason: 'gradually');
  });

  test('an S: one bump on each curve, the outline width where they meet', () {
    // Two half circles turning opposite ways, meeting at (200, 200).
    const r = 80.0;
    final points = [
      for (var a = math.pi; a > 0; a -= 2 / r)
        ui.Offset(120 + r * math.cos(a), 200 - r * math.sin(a)),
      for (var a = math.pi; a < 2 * math.pi; a += 2 / r)
        ui.Offset(280 + r * math.cos(a), 200 - r * math.sin(a)),
    ];
    final accent = OutlineAccent.of(points, base: 2, apex: 10, span: 30);
    const half = r * math.pi;
    expect(accent.at(half / 2), closeTo(10, .4), reason: 'first apex');
    expect(accent.at(half * 1.5), closeTo(10, .4), reason: 'second apex');
    expect(accent.at(half), lessThan(3), reason: 'where the curves meet');
  });

  test('a straight line, even drawn by a shaky hand, keeps its width', () {
    final random = math.Random(3);
    final points = [
      for (var x = 20.0; x <= 380; x += 2)
        ui.Offset(x, 200 + (random.nextDouble() * 2 - 1) * 1.5),
    ];
    final accent = OutlineAccent.of(points, base: 2, apex: 10, span: 30);
    for (var s = 0.0; s < 360; s += 5) {
      expect(accent.at(s), lessThan(2.5), reason: 'at $s');
    }
    // A shaky U still has its one bump.
    final shaky = OutlineAccent.of(
      _u(jitter: 1.5),
      base: 2,
      apex: 10,
      span: 30,
    );
    expect(shaky.at(20), lessThan(2.5));
    expect(shaky.at(140 + 60 * math.pi), greaterThan(9));
  });

  test('a gentle bend thickens only a little', () {
    // An arc turning 20 degrees in all.
    const r = 600.0, turn = 20 * math.pi / 180;
    final points = [
      for (var a = 0.0; a <= turn; a += 2 / r)
        ui.Offset(r * math.sin(a), r - r * math.cos(a)),
    ];
    final accent = OutlineAccent.of(points, base: 2, apex: 10, span: 30);
    final top = accent.at(r * turn / 2);
    expect(top, greaterThan(3));
    expect(top, lessThan(8));
  });

  test('drawn: the outline is thick at the bottom of the U and keeps its '
      'width on the sides; off, it is the same all round', () async {
    final on = await _draw(_u(), _pen(accent: true));
    final off = await _draw(_u(), _pen(accent: false));
    // Down from the middle of the half circle's pen line (y = 320) and left
    // from the left side's (x = 80).
    final bottomOn = _outline(on, 200, 330, 0, 1, 40);
    final sideOn = _outline(on, 70, 100, -1, 0, 30);
    final bottomOff = _outline(off, 200, 330, 0, 1, 40);
    final sideOff = _outline(off, 70, 100, -1, 0, 30);
    expect(sideOn, inInclusiveRange(1, 3), reason: 'side with 強弱');
    expect(bottomOn, inInclusiveRange(9, 11), reason: 'bottom with 強弱');
    expect(sideOff, inInclusiveRange(1, 3));
    expect(bottomOff, inInclusiveRange(1, 3));
    // Inside the U too.
    expect(_outline(on, 200, 310, 0, -1, 40), inInclusiveRange(9, 11));
    final sheet = img.Image(width: _size * 2, height: _size);
    img.fill(sheet, color: img.ColorRgb8(200, 210, 230));
    for (final (k, rgba) in [(0, off), (1, on)]) {
      for (var y = 0; y < _size; y++) {
        for (var x = 0; x < _size; x++) {
          final i = (y * _size + x) * 4;
          final a = rgba[i + 3] / 255;
          int c(int v, int under) => (v * a + under * (1 - a)).round();
          sheet.setPixelRgb(
            k * _size + x,
            y,
            c(rgba[i], 200),
            c(rgba[i + 1], 210),
            c(rgba[i + 2], 230),
          );
        }
      }
    }
    final dir = Directory('build/outline-accent')..createSync(recursive: true);
    File('${dir.path}/u_off_on.png').writeAsBytesSync(img.encodePng(sheet));
  });

  test('folding strands get the same 強弱', () async {
    // A zigzag that folds twice, then a gentle curve.
    final corners = [
      const ui.Offset(60, 80),
      const ui.Offset(300, 140),
      const ui.Offset(80, 220),
      const ui.Offset(320, 300),
    ];
    final points = <ui.Offset>[
      for (var i = 1; i < corners.length; i++)
        for (
          var t = 0.0;
          t < 1;
          t += 2 / (corners[i] - corners[i - 1]).distance
        )
          ui.Offset.lerp(corners[i - 1], corners[i], t)!,
      corners.last,
    ];
    final on = await _draw(
      points,
      _pen(accent: true).copyWith(foldEnabled: true),
    );
    final off = await _draw(
      points,
      _pen(accent: false).copyWith(foldEnabled: true),
    );
    int dark(Uint8List rgba) {
      var count = 0;
      for (var i = 0; i < rgba.length; i += 4) {
        if (rgba[i + 3] > 128 && rgba[i] < 128) count++;
      }
      return count;
    }

    // The outline thickens round the folds: much more of it.
    expect(dark(on), greaterThan(dark(off) * 1.3));
    final sheet = img.Image(width: _size * 2, height: _size);
    for (final (k, rgba) in [(0, off), (1, on)]) {
      for (var y = 0; y < _size; y++) {
        for (var x = 0; x < _size; x++) {
          final i = (y * _size + x) * 4;
          final a = rgba[i + 3] / 255;
          int c(int v, int under) => (v * a + under * (1 - a)).round();
          sheet.setPixelRgb(
            k * _size + x,
            y,
            c(rgba[i], 200),
            c(rgba[i + 1], 210),
            c(rgba[i + 2], 230),
          );
        }
      }
    }
    final dir = Directory('build/outline-accent')..createSync(recursive: true);
    File('${dir.path}/fold_off_on.png').writeAsBytesSync(img.encodePng(sheet));
  });

  test('saved, restored, and off for older brushes', () {
    final brush = _pen(accent: true).copyWith(outlineAccentWidth: 7.5);
    final restored = Brush.fromJson(brush.toJson());
    expect(restored.outlineAccentEnabled, isTrue);
    expect(restored.outlineAccentWidth, 7.5);
    final old = brush.toJson()
      ..remove('outlineAccentEnabled')
      ..remove('outlineAccentWidth');
    expect(Brush.fromJson(old).outlineAccentEnabled, isFalse);
    expect(Brush.fromJson(old).outlineAccentWidth, 4);
  });
}
