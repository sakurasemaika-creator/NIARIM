import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

const _dark = ui.Color(0xff62504b);
const _colors = [
  ui.Color(0xffc49e7a),
  ui.Color(0xffd4b08d),
  ui.Color(0xffb89170),
];

List<ui.Offset> _sample(ui.Path path) => [
  for (final metric in path.computeMetrics()) ...[
    for (var d = 0.0; d < metric.length; d += 7)
      metric.getTangentForOffset(d)!.position,
    metric.getTangentForOffset(metric.length)!.position,
  ],
];

void _stroke(DrawingEngine engine, Brush brush, ui.Path path, ui.Color color) {
  engine.currentBrush = brush;
  engine.currentColor = color;
  final points = _sample(path);
  StrokePoint sample(ui.Offset p) =>
      StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0);
  // A 1000 px document displayed at 40% on a phone. Fold detection consumes
  // pointer screen coordinates, while DrawingEngine paints document pixels.
  engine.beginStroke(
    sample(points.first),
    'hair',
    screenPosition: points.first * .4,
  );
  for (final point in points.skip(1)) {
    engine.continueStroke(sample(point), 'hair', screenPosition: point * .4);
  }
  engine.endStroke();
}

Brush _brush(Brush base, HairFoldMode mode, double width) => base.copyWith(
  size: width,
  opacity: 100,
  stabilization: false,
  fadeMode: FadeMode.off,
  foldMode: mode,
  foldTriggerAngle: 30,
  outlineWidth: 2.4,
  outlineColor: 0xff5d4941,
  customImageSelectionMode: BrushImageSelectionMode.sequential,
);

void _mannequin(ui.Canvas canvas, bool front) {
  void shape(ui.Path path, ui.Color color) {
    canvas.drawPath(path, ui.Paint()..color = color);
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = const ui.Color(0xffaab2b8)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  shape(
    ui.Path()
      ..moveTo(250, 1080)
      ..cubicTo(230, 935, 320, 890, 410, 870)
      ..lineTo(590, 870)
      ..cubicTo(700, 885, 790, 950, 760, 1080)
      ..close(),
    const ui.Color(0xffdce4e7),
  );
  shape(
    ui.Path()
      ..moveTo(425, 735)
      ..lineTo(417, 875)
      ..quadraticBezierTo(500, 942, 583, 875)
      ..lineTo(575, 735)
      ..close(),
    const ui.Color(0xffeaded1),
  );
  shape(
    ui.Path()
      ..moveTo(500, 170)
      ..cubicTo(315, 165, 295, 380, 325, 575)
      ..cubicTo(335, 710, 425, 820, 500, 827)
      ..cubicTo(590, 808, 665, 700, 675, 575)
      ..cubicTo(710, 380, 685, 165, 500, 170)
      ..close(),
    const ui.Color(0xfff2e5d9),
  );
  if (front) {
    final features = ui.Path()
      ..moveTo(368, 547)
      ..quadraticBezierTo(410, 530, 445, 549)
      ..moveTo(555, 549)
      ..quadraticBezierTo(590, 530, 632, 547)
      ..moveTo(375, 580)
      ..quadraticBezierTo(410, 601, 444, 580)
      ..moveTo(556, 580)
      ..quadraticBezierTo(590, 601, 625, 580)
      ..moveTo(503, 593)
      ..lineTo(486, 657)
      ..quadraticBezierTo(501, 669, 518, 658)
      ..moveTo(457, 712)
      ..quadraticBezierTo(500, 735, 543, 712);
    canvas.drawPath(
      features,
      ui.Paint()
        ..color = const ui.Color(0xffa38b80)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = ui.StrokeCap.round,
    );
  }
}

Future<void> _save(
  ui.Picture picture,
  int width,
  int height,
  String name,
) async {
  final image = await picture.toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final output = File('build/hair_fold_visual/$name.png');
  await output.parent.create(recursive: true);
  await output.writeAsBytes(png!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

Future<Uint8List> _hairstyle(bool front, HairFoldMode mode) async {
  final presets = brushExtensionPresets();
  final hair = presets.singleWhere((b) => b.id == 'Brush0023');
  final bangs = presets.singleWhere((b) => b.id == 'Brush0024');
  await preloadBrushTextures(bangs.resolvedCustomImagePaths);
  final tiles = TileManager(canvasWidth: 1000, canvasHeight: 1120);
  final engine = DrawingEngine(tileManager: tiles)..pressureEnabled = false;
  final wash = _brush(
    hair,
    mode,
    145,
  ).copyWith(outlineEnabled: false, foldEnabled: false);
  if (front) {
    _stroke(
      engine,
      wash,
      ui.Path()
        ..moveTo(318, 408)
        ..cubicTo(265, 78, 712, 75, 684, 413),
      _dark,
    );
    for (var i = -2; i <= 2; i++) {
      final x = 500 + i * 48.0;
      _stroke(
        engine,
        wash.copyWith(size: 120),
        ui.Path()
          ..moveTo(500 + i * 25.0, 220)
          ..cubicTo(x, 265, x - 18, 340, x, 410),
        _dark,
      );
    }
    for (final side in [-1.0, 1.0]) {
      _stroke(
        engine,
        wash.copyWith(size: 70),
        ui.Path()
          ..moveTo(500 + side * 186, 358)
          ..cubicTo(
            500 + side * 242,
            520,
            500 + side * 184,
            645,
            500 + side * 204,
            818,
          ),
        _dark,
      );
    }
    for (var i = 6; i >= 0; i--) {
      final x = 370 + i * 39.0;
      final path = ui.Path()
        ..moveTo(440 + i * 22.0, 188 + i * 3.0)
        ..cubicTo(x - 72, 210, x - 78, 308, x - 25, 366)
        ..cubicTo(x + 30, 422, x + 22, 453 + i * 6.0, x - 12, 484 + i * 3.0);
      _stroke(engine, _brush(bangs, mode, 72), path, _colors[i % 3]);
    }
  } else {
    for (var i = -3; i <= 3; i++) {
      final x = 500 + i * 56.0;
      _stroke(
        engine,
        wash,
        ui.Path()
          ..moveTo(500 + i * 14.0, 190)
          ..cubicTo(x, 180, x - i * 11.0, 380, x, 630)
          ..quadraticBezierTo(x + i * 6.0, 745, x - i * 4.0, 860),
        _dark,
      );
    }
    for (var i = -3; i <= 3; i++) {
      final x = 500 + i * 61.0, phase = i.abs() * 12.0;
      final path = ui.Path()
        ..moveTo(500 + i * 16.0, 162 + i.abs() * 5.0)
        ..cubicTo(x, 180, x - 34, 309, x, 382 + phase)
        ..cubicTo(x + 56, 460 + phase, x + 58, 493 + phase, x, 556 + phase)
        ..cubicTo(x - 62, 620 + phase, x - 61, 673 + phase, x, 722 + phase)
        ..cubicTo(
          x + 51,
          775 + phase,
          x + 45,
          844 + phase,
          x - 18,
          924 - phase,
        );
      _stroke(engine, _brush(hair, mode, 78), path, _colors[(i + 3) % 3]);
    }
  }
  final layer = await tiles.compositeLayerToImage('hair');
  final raw = await layer.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = Uint8List.fromList(raw!.buffer.asUint8List());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xfff7f4ef), ui.BlendMode.src);
  _mannequin(canvas, front);
  canvas.drawImage(layer, ui.Offset.zero, ui.Paint());
  await _save(
    recorder.endRecording(),
    1000,
    1120,
    'usage_${front ? "front" : "back"}_${mode.name}',
  );
  layer.dispose();
  tiles.dispose();
  return bytes;
}

Future<void> _angles() async {
  final base = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0024');
  await preloadBrushTextures(base.resolvedCustomImagePaths);
  final tiles = TileManager(canvasWidth: 1280, canvasHeight: 370);
  final engine = DrawingEngine(tileManager: tiles)..pressureEnabled = false;
  final rotations = [-math.pi / 3, 0.0, math.pi / 3, math.pi / 2];
  for (var i = 0; i < rotations.length; i++) {
    final path = ui.Path();
    for (var step = 0; step <= 90; step++) {
      final angle = -math.pi / 2 + step * math.pi / 90 + rotations[i];
      final x = 155 + i * 320 + 97 * math.cos(angle),
          y = 182 + 97 * math.sin(angle);
      if (step == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    _stroke(engine, _brush(base, HairFoldMode.crescent, 84), path, _colors[1]);
  }
  final layer = await tiles.compositeLayerToImage('hair');
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xfff7f4ef), ui.BlendMode.src);
  canvas.drawImage(layer, ui.Offset.zero, ui.Paint());
  await _save(recorder.endRecording(), 1280, 370, 'crescent_stroke_angles');
  layer.dispose();
  tiles.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('production brushes draw folded back hair and bangs', () async {
    for (final front in [false, true]) {
      final wave = await _hairstyle(front, HairFoldMode.waveTopView);
      final crescent = await _hairstyle(front, HairFoldMode.crescent);
      var changed = 0;
      for (var i = 0; i < wave.length; i += 4) {
        if ((wave[i] - crescent[i]).abs() > 32 ||
            (wave[i + 3] - crescent[i + 3]).abs() > 64) {
          changed++;
        }
      }
      // Catch capture fixtures that never trigger folding at their zoom level.
      expect(changed, greaterThan(1000), reason: front ? 'bangs' : 'back hair');
    }
    await _angles();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
