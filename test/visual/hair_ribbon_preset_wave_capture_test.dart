import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';

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

const sampleWidth = 360;
const sampleHeight = 240;

Map<String, List<ui.Offset>> curvedSamples() {
  List<ui.Offset> trace(ui.Offset Function(double) point) => [
    for (var i = 0; i <= 68; i++) point(i / 68),
  ];

  return {
    'horizontal': trace(
      (t) =>
          ui.Offset(24 + 312 * t, 119 + 41 * math.sin((t * 4 - .5) * math.pi)),
    ),
    'vertical': trace(
      (t) =>
          ui.Offset(180 + 45 * math.sin((t * 3 - .5) * math.pi), 24 + 192 * t),
    ),
    'diagonal': trace(
      (t) => ui.Offset(
        35 + 290 * t,
        198 - 156 * t + 34 * math.sin(t * 4 * math.pi),
      ),
    ),
    'curl': trace((t) {
      final angle = (-.92 + t * 1.65) * math.pi;
      final radius = 98 - 49 * t;
      return ui.Offset(
        183 + 1.25 * radius * math.cos(angle),
        119 + radius * math.sin(angle),
      );
    }),
  };
}

Future<int> middleWidth(Brush brush, double angle) async {
  const center = ui.Offset(96, 96);
  final tangent = ui.Offset(math.cos(angle), math.sin(angle));
  final normal = ui.Offset(-tangent.dy, tangent.dx);
  final image = await drawStroke(
    brush,
    [for (var i = -12; i <= 12; i++) center + tangent * (i * 5.0)],
    width: 192,
    height: 192,
  );
  final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  var width = 0;
  for (var i = -45; i <= 45; i++) {
    final point = center + normal * i.toDouble();
    if (pixels.getUint8((point.dy.floor() * 192 + point.dx.floor()) * 4 + 3) >=
        128) {
      width++;
    }
  }
  image.dispose();
  return width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final brushes = BrushService.builtInBrushes;
  Brush preset(String id) => brushes.singleWhere((brush) => brush.id == id);

  setUpAll(() async {
    for (final id in [...hairRibbonPresetIds, 'Brush0024']) {
      final brush = preset(id);
      await preloadBrushTextures(
        brush.resolvedCustomImagePaths,
        mode: brush.imageInkMode,
      );
    }
  });

  test('saved vertical nib migrates to editable flat tip settings', () {
    final data = preset('Brush0036').toJson()
      ..remove('calligraphyAngle')
      ..remove('nibWidthRatio')
      ..['verticalNib'] = true;
    final migrated = Brush.fromJson(data);
    expect(migrated.calligraphyAngle, 0);
    expect(migrated.nibWidthRatio, .38);
    expect(migrated.toJson().containsKey('verticalNib'), isFalse);
  });

  test('built-in and imported tips draw the same folded brush', () async {
    final home = await Directory.systemTemp.createTemp('folded-brush-tip');
    addTearDown(() => home.delete(recursive: true));
    final stroke = curvedSamples()['horizontal']!;
    for (final id in ['Brush0023', 'Brush0036', 'Brush0040']) {
      final brush = preset(id);
      final path = (await File(
        brush.resolvedCustomImagePaths.single,
      ).copy('${home.path}/$id.png')).path;
      await preloadBrushTextures([path], mode: brush.imageInkMode);
      final imported = Brush.fromJson({
        ...brush.toJson(),
        'id': 'imported-folding-brush',
        'customImagePaths': [path],
      });
      final reference = await drawStroke(
        brush,
        stroke,
        width: 360,
        height: 240,
      );
      final actual = await drawStroke(
        imported,
        stroke,
        width: 360,
        height: 240,
      );
      final expectedPixels = (await reference.toByteData())!.buffer
          .asUint8List();
      final actualPixels = (await actual.toByteData())!.buffer.asUint8List();
      expect(actualPixels, orderedEquals(expectedPixels), reason: id);
      actual.dispose();
      reference.dispose();
    }
  });

  test('each ribbon is widest horizontally and narrowest vertically', () async {
    for (final id in hairRibbonPresetIds.skip(5)) {
      final brush = preset(id);
      final restored = Brush.fromJson(brush.toJson());
      expect(restored.calligraphyAngle, isNull, reason: id);
      expect(restored.foldFlatEnds, isFalse, reason: id);
      expect(restored.resolvedCustomImagePaths, [
        'assets/brushes/ribbon_tip.png',
      ]);
      final horizontal = await middleWidth(brush, 0);
      final diagonal = await middleWidth(brush, math.pi / 4);
      final vertical = await middleWidth(brush, math.pi / 2);
      expect(horizontal, greaterThanOrEqualTo(24), reason: id);
      expect(
        diagonal,
        inInclusiveRange(vertical + 4, horizontal - 3),
        reason: id,
      );
      expect(vertical, inInclusiveRange(7, 13), reason: id);
      expect(
        await middleWidth(brush, math.pi),
        closeTo(horizontal, 1),
        reason: id,
      );
      expect(
        await middleWidth(brush, -math.pi / 2),
        closeTo(vertical, 1),
        reason: id,
      );
    }

    final ribbon = preset('Brush0036').copyWith(foldEnabled: false);
    final flatHorizontal = await middleWidth(ribbon, 0);
    final flatVertical = await middleWidth(ribbon, math.pi / 2);
    expect(flatHorizontal, greaterThan(flatVertical * 1.7));
  });

  test('the image alone supplies the ribbon directionality', () async {
    final round = preset(
      'Brush0036',
    ).copyWith(customImagePaths: const ['assets/brushes/round_tip.png']);
    expect(
      await middleWidth(round, math.pi / 2),
      closeTo(await middleWidth(round, 0), 1),
    );
  });

  test('crescent pixels are independent of the crease line sliders', () async {
    final brush = preset('Brush0040');
    final path = curvedSamples()['horizontal']!;
    final original = await drawStroke(
      brush,
      path,
      width: sampleWidth,
      height: sampleHeight,
    );
    final changed = await drawStroke(
      brush.copyWith(
        foldLengthRatio: 0,
        foldAngleRatio: 1,
        foldCurveStartRatio: 1,
        foldEndTaperRatio: 0,
      ),
      path,
      width: sampleWidth,
      height: sampleHeight,
    );
    expect(
      (await changed.toByteData())!.buffer.asUint8List(),
      orderedEquals((await original.toByteData())!.buffer.asUint8List()),
    );
    changed.dispose();
    original.dispose();
  });

  test(
    'ribbon creases connect to the inner outline of a textured S curve',
    () async {
      for (final id in hairRibbonPresetIds.skip(5).take(4)) {
        final image = await drawStroke(
          preset(id),
          curvedSamples()['vertical']!,
          width: sampleWidth,
          height: sampleHeight,
        );
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        image.dispose();

        // The red fill is brighter than the outline ink. Use premultiplied
        // channels so that the partially transparent edge has the same cutoff.
        int alpha(int x, int y) =>
            x < 0 || y < 0 || x >= sampleWidth || y >= sampleHeight
            ? 0
            : pixels.getUint8((y * sampleWidth + x) * 4 + 3);
        final ink = <(int, int)>{
          for (var y = 0; y < sampleHeight; y++)
            for (var x = 0; x < sampleWidth; x++)
              if (alpha(x, y) > 225 &&
                  pixels.getUint8((y * sampleWidth + x) * 4) <
                      alpha(x, y) * .785)
                (x, y),
        };
        var interiorInk = 0;
        while (ink.isNotEmpty) {
          final component = [ink.first];
          ink.remove(component.first);
          var touchesOutline = false;
          for (var i = 0; i < component.length; i++) {
            final (x, y) = component[i];
            var nearEdge = false;
            for (var dy = -2; dy <= 2; dy++) {
              for (var dx = -2; dx <= 2; dx++) {
                final neighbor = (x + dx, y + dy);
                if (alpha(neighbor.$1, neighbor.$2) <= 128) nearEdge = true;
                if (dx.abs() <= 1 && dy.abs() <= 1 && ink.remove(neighbor)) {
                  component.add(neighbor);
                }
              }
            }
            touchesOutline |= nearEdge;
            if (!nearEdge) interiorInk++;
          }
          if (component.length > 2) {
            expect(
              touchesOutline,
              isTrue,
              reason: 'isolated crease: $id at ${component.first}',
            );
          }
        }
        expect(
          interiorInk,
          greaterThan(10),
          reason: 'creases remain visible: $id',
        );
      }
    },
  );

  test('ribbon crease starts straight and its settings move the end', () async {
    const center = ui.Offset(165, 106);
    const radius = 107.0;
    const turn = 70 * math.pi / 180;
    ui.Offset onBend(double angle) =>
        center + ui.Offset(math.sin(angle), math.cos(angle)) * radius;
    final end = onBend(turn);
    final heading = ui.Offset(math.cos(turn), -math.sin(turn));
    final stroke = [
      for (var x = 38; x < center.dx; x += 2)
        ui.Offset(x.toDouble(), center.dy + radius),
      for (var i = 0; i <= 64; i++) onBend(turn * i / 64),
      for (var i = 1; i <= 30; i++) end + heading * (i * 3),
    ];
    const width = 400, height = 270;
    final ribbon = preset(
      'Brush0036',
    ).copyWith(size: 50, outlineWidth: 2, stabilization: false);
    Future<ByteData> render(Brush brush) async {
      final image = await drawStroke(
        brush,
        stroke,
        width: width,
        height: height,
      );
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      image.dispose();
      return data;
    }

    final body = await render(ribbon.copyWith(foldLengthRatio: 0));
    Future<List<ui.Offset>> crease(Brush brush) async {
      final pixels = await render(brush);
      final ink = <ui.Offset>[];
      for (var x = 0; x < width; x++) {
        for (var y = 0; y < height; y++) {
          final i = (y * width + x) * 4;
          if (pixels.getUint8(i + 3) != body.getUint8(i + 3)) {
            fail('A crease setting moved the silhouette at ($x, $y)');
          }
          if (body.getUint8(i) - pixels.getUint8(i) > 16) {
            ink.add(ui.Offset(x.toDouble(), y.toDouble()));
          }
        }
      }
      expect(ink, isNotEmpty);
      return ink;
    }

    final straight = await crease(ribbon.copyWith(foldCurveStartRatio: 1));
    expect(straight.map((pixel) => pixel.dy).toSet(), hasLength(lessThan(4)));
    final folded = await crease(ribbon);
    final shortened = await crease(ribbon.copyWith(foldLengthRatio: .65));
    final earlier = await crease(ribbon.copyWith(foldCurveStartRatio: .35));
    final angleOff = await crease(ribbon.copyWith(foldAngleRatio: 0));

    expect((folded.first - straight.first).distance, lessThan(2));
    expect(folded.last.dy, lessThan(straight.last.dy));
    expect(earlier.last.dy, lessThan(folded.last.dy));
    expect(shortened.last.dx, lessThan(folded.last.dx - 8));
    expect(angleOff.last.dy, closeTo(straight.last.dy, 1));
  });

  test('capture every hair and ribbon brush on four curved paths', () async {
    final out = Directory('build/hair_ribbon_presets')
      ..createSync(recursive: true);
    final paths = curvedSamples();
    for (final id in [...hairRibbonPresetIds, 'Brush0024']) {
      final brush = preset(id);
      for (final entry in paths.entries) {
        final layer = await drawStroke(
          brush,
          entry.value,
          width: sampleWidth,
          height: sampleHeight,
        );
        final png = await layer.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${out.path}/${id}_${entry.key}.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        layer.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
