import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

// A hand-authored strand like the user's rounded outline-pen reference. Every
// mode receives these exact positions and pressures; the renderer creates no
// wave or substitute centerline.
List<ui.Offset> referenceInput() {
  final path = ui.Path()
    ..moveTo(290, 90)
    ..cubicTo(287, 149, 308, 208, 352, 262)
    ..cubicTo(380, 298, 437, 314, 442, 357)
    ..cubicTo(448, 400, 373, 432, 338, 475)
    ..cubicTo(308, 513, 308, 551, 350, 589)
    ..cubicTo(386, 622, 426, 638, 425, 674)
    ..cubicTo(424, 710, 357, 724, 347, 758)
    ..cubicTo(337, 791, 378, 787, 384, 810)
    ..cubicTo(393, 839, 340, 854, 326, 872);
  final metric = path.computeMetrics().single;
  return [
    for (var d = 0.0; d < metric.length; d += 6)
      metric.getTangentForOffset(d)!.position,
    metric.getTangentForOffset(metric.length)!.position,
  ];
}

Future<({Uint8List pixels, Map<String, Object> timing})> captureReference(
  HairFoldMode mode, {
  bool folded = true,
}) async {
  final base = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0023');
  final brush = base.copyWith(
    size: 78,
    outlineWidth: 3,
    outlineColor: 0xff151515,
    stabilization: false,
    fadeMode: FadeMode.off,
    foldEnabled: folded,
    foldMode: mode,
    foldTriggerAngle: 30,
  );
  final tiles = TileManager(canvasWidth: 720, canvasHeight: 1000);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xffffffff)
    ..pressureEnabled = true;
  final points = referenceInput();
  StrokePoint sample(int i) => StrokePoint(
    x: points[i].dx,
    y: points[i].dy,
    pressure: 1 - .88 * i / (points.length - 1),
    tiltX: 0,
    tiltY: 0,
  );
  final elapsed = <int>[];
  final timer = Stopwatch()..start();
  engine.beginStroke(sample(0), 'hair', screenPosition: points.first * .6);
  for (var i = 1; i < points.length; i++) {
    timer.reset();
    engine.continueStroke(sample(i), 'hair', screenPosition: points[i] * .6);
    elapsed.add(timer.elapsedMicroseconds);
  }
  timer.reset();
  engine.endStroke();
  final endMicros = timer.elapsedMicroseconds;
  timer.stop();
  final layer = await tiles.compositeLayerToImage('hair');
  final data = await layer.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = Uint8List.fromList(data!.buffer.asUint8List());
  if (mode != HairFoldMode.crescent) {
    var remaining = 0.0;
    final tailDistances = List<double>.filled(points.length, 0);
    for (var i = points.length - 2; i >= 0; i--) {
      remaining += (points[i + 1] - points[i]).distance;
      tailDistances[i] = remaining;
    }
    for (var i = 1; i < points.length - 1; i++) {
      // The shared fold tail intentionally reaches zero coverage. Verify the
      // authored centerline in the body, outside its maximum taper length.
      if (folded && tailDistances[i] <= brush.size * 2) continue;
      final point = points[i];
      final alpha = pixels[(point.dy.floor() * 720 + point.dx.floor()) * 4 + 3];
      expect(
        alpha,
        greaterThan(240),
        reason: 'authored centerline ${mode.name} at $point',
      );
    }
  }
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src)
    ..drawImage(layer, ui.Offset.zero, ui.Paint());
  if (!folded) {
    final guide = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      guide.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      guide,
      ui.Paint()
        ..color = const ui.Color(0xff67a8bb)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(720, 1000);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(
    'build/hair_fold_visual/outline_${folded ? mode.name : "input"}.png',
  );
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  layer.dispose();
  tiles.dispose();
  elapsed.sort();
  return (
    pixels: pixels,
    timing: {
      'mode': folded ? mode.name : 'off',
      'samples': points.length,
      'median_us': elapsed[elapsed.length ~/ 2],
      'p95_us': elapsed[(elapsed.length * .95).floor()],
      'end_us': endMicros,
    },
  );
}

int edgeDifference(Uint8List a, Uint8List b) {
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() > 100 && a[i + 3] > 240 && b[i + 3] > 240) count++;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('five outline-pen modes follow a tapered hand-drawn strand', () async {
    final images = <HairFoldMode, Uint8List>{};
    final timings = <Map<String, Object>>[];
    for (final mode in HairFoldMode.values) {
      final result = await captureReference(mode);
      images[mode] = result.pixels;
      timings.add(result.timing);
    }
    await captureReference(HairFoldMode.waveTopView, folded: false);
    final top = images[HairFoldMode.waveTopView]!;
    for (final mode in [
      HairFoldMode.waveLowAngle,
      HairFoldMode.curlRight,
      HairFoldMode.curlLeft,
    ]) {
      final actual = images[mode]!;
      for (var p = 3; p < top.length; p += 4) {
        expect(actual[p], top[p], reason: 'same silhouette for ${mode.name}');
      }
    }
    expect(
      edgeDifference(top, images[HairFoldMode.waveLowAngle]!),
      greaterThan(80),
    );
    expect(
      edgeDifference(
        images[HairFoldMode.curlRight]!,
        images[HairFoldMode.curlLeft]!,
      ),
      greaterThan(80),
    );
    await File(
      'build/hair_fold_visual/outline_timings.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(timings));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
