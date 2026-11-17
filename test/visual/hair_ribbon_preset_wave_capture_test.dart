import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

/// The wave of the owner's reference (「ウェーブ俯瞰」 of the hair and ribbon
/// brushes): drawn left to right, down into a trough, over a crest and down
/// into a second trough, ending rising to the right. At the presets' own
/// size, as drawn on the canvas.
List<ui.Offset> referenceWave({double scale = 1}) => [
  for (var i = 0; i <= 220; i++)
    () {
      final t = i / 220;
      final x = 30 + 410 * t;
      return ui.Offset(
        x * scale,
        (100 + 34 * math.cos(2 * math.pi * (x - 110) / 190)) * scale,
      );
    }(),
];

/// Draws [brush] along [input] with the real engine (pressure off, the
/// preset's own taper and fold settings) and returns the layer.
Future<ui.Image> drawStroke(
  Brush brush,
  List<ui.Offset> input, {
  int width = 480,
  int height = 200,
}) async {
  final tiles = TileManager(canvasWidth: width, canvasHeight: height);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = ui.Color(brush.presetColor ?? 0xffc4886e)
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
  final layer = await tiles.compositeLayerToImage('hair');
  tiles.dispose();
  return layer;
}

/// Hair and ribbon presets, in the brush list's order.
const hairRibbonPresetIds = [
  'Brush0023',
  'Brush0031',
  'Brush0032',
  'Brush0034',
  'Brush0035',
  'Brush0036',
  'Brush0037',
  'Brush0038',
  'Brush0039',
  'Brush0040',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every hair and ribbon preset on the reference wave', () async {
    final presets = brushExtensionPresets();
    final out = Directory('build/hair_ribbon_presets')
      ..createSync(recursive: true);
    for (final id in hairRibbonPresetIds) {
      final brush = presets.singleWhere((b) => b.id == id);
      final layer = await drawStroke(brush, referenceWave());
      // Enlarged 3x on the reference's paper colour, to read the fold lines.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xfffbf9f3), ui.BlendMode.src)
        ..scale(3);
      canvas.drawImage(
        layer,
        ui.Offset.zero,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final image = await recorder.endRecording().toImage(1440, 600);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${out.path}/$id.png').writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
      layer.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
