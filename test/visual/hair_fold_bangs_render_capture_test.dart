import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

const modeNames = <HairFoldMode, String>{
  HairFoldMode.waveTopView: 'wave_top_view',
  HairFoldMode.waveLowAngle: 'wave_low_angle',
  HairFoldMode.curlRight: 'curl_right',
  HairFoldMode.curlLeft: 'curl_left',
  HairFoldMode.crescent: 'crescent',
};
Future<Uint8List> capture(
  Brush brush,
  String name, {
  List<ui.Offset>? input,
}) async {
  await preloadBrushTextures(
    brush.resolvedCustomImagePaths,
    mode: brush.imageInkMode,
  );
  for (final path in brush.resolvedCustomImagePaths) {
    expect(
      getCachedBrushTexture(path, mode: brush.imageInkMode),
      isNotNull,
      reason: path,
    );
  }
  final tiles = TileManager(canvasWidth: 720, canvasHeight: 1040);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xfffff5e7)
    ..pressureEnabled = false;
  final points = input ?? <ui.Offset>[];
  // Actual input fixture, shared unchanged by all five modes.
  if (input == null) {
    for (var i = 0; i <= 160; i++) {
      final t = i / 160;
      points.add(
        ui.Offset(350 + 130 * math.sin(t * math.pi * 5), 95 + 850 * t),
      );
    }
  }
  StrokePoint p(ui.Offset a) =>
      StrokePoint(x: a.dx, y: a.dy, pressure: 1, tiltX: 0, tiltY: 0);
  tiles.beginUndoRecording('hair');
  engine.beginStroke(p(points.first), 'hair');
  for (final point in points.skip(1)) {
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
  final raw = await layer.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = Uint8List.fromList(raw!.buffer.asUint8List());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xffedf1f5), ui.BlendMode.src);
  final paragraph =
      (ui.ParagraphBuilder(
              ui.ParagraphStyle(fontSize: 23, fontFamily: 'NotoSerifJP'),
            )
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xff182233)))
            ..addText(name))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 670));
  canvas.drawParagraph(paragraph, const ui.Offset(25, 20));
  canvas.drawImage(layer, ui.Offset.zero, ui.Paint());
  final picture = recorder.endRecording();
  final image = await picture.toImage(720, 1040);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final out = File('build/hair_fold_visual/$name.png');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(png!.buffer.asUint8List());
  image.dispose();
  layer.dispose();
  picture.dispose();
  tiles.dispose();
  return pixels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('NotoSerifJP')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifJP.ttf'));
    await loader.load();
  });
  test(
    'production hair and textured bangs follow the same curve in five modes',
    () async {
      final presets = brushExtensionPresets();
      for (final entry in modeNames.entries) {
        for (final id in ['Brush0023', 'Brush0024']) {
          final base = presets.singleWhere((b) => b.id == id);
          final settings = base.copyWith(
            size: 64,
            outlineWidth: 2.5,
            stabilization: false,
            fadeMode: FadeMode.off,
            foldTriggerAngle: 30,
            foldMode: entry.key,
            customImageSelectionMode: BrushImageSelectionMode.sequential,
          );
          final name = '${id == "Brush0023" ? "hair" : "bangs"}_${entry.value}';
          final presetPixels = await capture(settings, '${name}_same_curve');
          // A saved custom definition must render exactly the same authored
          // curve. This catches preset-ID/name dispatch in the real engine.
          final custom = Brush.fromJson(
            settings.copyWith(id: 'user-$id', name: 'My strand').toJson(),
          );
          final customPixels = await capture(
            custom,
            '${name}_custom_same_curve',
          );
          expect(customPixels, orderedEquals(presetPixels), reason: name);
        }
      }
      await capture(
        presets.singleWhere((b) => b.id == 'Brush0024'),
        'bangs_production_preset',
      );
      await capture(
        presets.singleWhere((b) => b.id == 'Brush0023'),
        'hair_production_preset',
      );
      List<ui.Offset> arc(double degrees, double radius) {
        final count = (degrees.abs() / 3).ceil();
        // Use an open spiral rather than retracing the same circle beyond
        // 360 degrees. The latter overlaps a 64 px brush with itself before
        // the second 270-degree boundary and hides the fold we want to judge.
        return [
          for (var i = 0; i <= count; i++)
            ui.Offset(
              360 +
                  (radius + math.min(i * 3, degrees) * .18) *
                      math.cos(math.min(i * 3, degrees) * math.pi / 180),
              420 +
                  (radius + math.min(i * 3, degrees) * .18) *
                      math.sin(math.min(i * 3, degrees) * math.pi / 180),
            ),
        ];
      }

      for (final mode in [
        HairFoldMode.crescent,
        HairFoldMode.waveTopView,
        HairFoldMode.waveLowAngle,
      ]) {
        final base = presets.singleWhere((b) => b.id == 'Brush0023');
        for (final degrees in [
          175.0,
          185.0,
          265.0,
          275.0,
          355.0,
          365.0,
          535.0,
          545.0,
        ]) {
          await capture(
            base.copyWith(
              size: 64,
              outlineWidth: 2.5,
              stabilization: false,
              fadeMode: FadeMode.off,
              foldTriggerAngle: 30,
              foldMode: mode,
            ),
            'hair_${modeNames[mode]}_${degrees.toInt()}deg_continuous',
            input: arc(degrees, 70),
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
