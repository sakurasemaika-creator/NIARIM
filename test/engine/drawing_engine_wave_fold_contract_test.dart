import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const foldCurve = <ui.Offset>[
  ui.Offset(60, 40),
  ui.Offset(180, 140),
  ui.Offset(60, 240),
  ui.Offset(180, 340),
];

Future<Uint8List> renderFold(
  HairFoldMode mode, {
  bool reverse = false,
  bool enabled = true,
  double size = 44,
  int opacity = 100,
  void Function(DrawingEngine)? beforeBegin,
  void Function(DrawingEngine)? beforeEnd,
  List<ui.Offset> curve = foldCurve,
}) async {
  final tiles = TileManager(canvasWidth: 256, canvasHeight: 400);
  final engine = DrawingEngine(tileManager: tiles)
    ..pressureEnabled = false
    ..currentColor = const ui.Color(0xffffffff)
    ..currentBrush = Brush(
      id: 'fold',
      name: 'Fold',
      size: size,
      spacing: 1,
      opacity: opacity,
      density: 1,
      fadeMode: FadeMode.off,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      strokeDecay: false,
      outlineEnabled: true,
      outlineWidth: 2,
      outlineColor: 0xff000000,
      foldEnabled: enabled,
      foldTriggerAngle: 45,
      foldMode: mode,
    );
  final points = reverse ? curve.reversed.toList() : curve;
  StrokePoint sample(ui.Offset p) =>
      StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0);
  beforeBegin?.call(engine);
  engine.beginStroke(sample(points.first), 'test');
  for (var i = 1; i < points.length; i++) {
    final count = (points[i] - points[i - 1]).distance.ceil();
    for (var j = 1; j <= count; j++) {
      engine.continueStroke(
        sample(ui.Offset.lerp(points[i - 1], points[i], j / count)!),
        'test',
      );
    }
  }
  beforeEnd?.call(engine);
  engine.endStroke();
  final image = await tiles.compositeLayerToImage('test');
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  tiles.dispose();
  return bytes;
}

int changedPixels(Uint8List a, Uint8List b) {
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() > 80 || (a[i + 3] - b[i + 3]).abs() > 80) count++;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'opposite views change visible fold edges, not just line thickness',
    () async {
      final top = await renderFold(HairFoldMode.waveTopView);
      final low = await renderFold(HairFoldMode.waveLowAngle);
      expect(changedPixels(top, low), greaterThan(80));
    },
  );
  test('opposite curls change which diagonal occludes the other', () async {
    final right = await renderFold(HairFoldMode.curlRight);
    final left = await renderFold(HairFoldMode.curlLeft);
    expect(changedPixels(right, left), greaterThan(100));
  });
  test('fold off ignores the selected mode', () async {
    expect(
      await renderFold(HairFoldMode.curlLeft, enabled: false),
      await renderFold(HairFoldMode.waveTopView, enabled: false),
    );
  });
  test('straight input is ordinary drawing for every mode', () async {
    const line = [ui.Offset(60, 40), ui.Offset(60, 340)];
    final plain = await renderFold(
      HairFoldMode.waveTopView,
      enabled: false,
      curve: line,
    );
    for (final mode in HairFoldMode.values) {
      expect(await renderFold(mode, curve: line), plain);
    }
  });
  test('depth choices preserve the same input silhouette', () async {
    final baseline = await renderFold(HairFoldMode.waveTopView);
    for (final mode in [
      HairFoldMode.waveLowAngle,
      HairFoldMode.curlRight,
      HairFoldMode.curlLeft,
    ]) {
      final actual = await renderFold(mode);
      for (var i = 3; i < actual.length; i += 4) {
        expect(actual[i], baseline[i]);
      }
    }
  });
  test('reversing the input keeps all four depth choices', () async {
    for (final mode in HairFoldMode.values.where(
      (m) => m != HairFoldMode.crescent,
    )) {
      expect(
        changedPixels(
          await renderFold(mode),
          await renderFold(mode, reverse: true),
        ),
        lessThan(80),
        reason: mode.name,
      );
    }
  });
  test('one crescent has no extra straight-tail piece when reversed', () async {
    const curve = [ui.Offset(60, 40), ui.Offset(180, 140), ui.Offset(60, 240)];
    expect(
      changedPixels(
        await renderFold(HairFoldMode.crescent, curve: curve),
        await renderFold(HairFoldMode.crescent, curve: curve, reverse: true),
      ),
      lessThan(500),
    );
  });
  List<ui.Offset> circularArc(double degrees, {double radius = 92}) {
    final count = (degrees.abs() / 5).ceil();
    final sign = degrees.sign;
    return [
      for (var i = 0; i <= count; i++)
        ui.Offset(
          128 + radius * math.cos(sign * i * 5 * math.pi / 180),
          190 + radius * math.sin(sign * i * 5 * math.pi / 180),
        ),
    ];
  }

  test('continuous 270 degree turns affect crescent production rendering', () async {
    final before = await renderFold(
      HairFoldMode.crescent,
      curve: circularArc(265),
      size: 30,
    );
    final after = await renderFold(
      HairFoldMode.crescent,
      curve: circularArc(275),
      size: 30,
    );
    expect(changedPixels(before, after), greaterThan(40));
  });

  test('both wave views add a fold after 270 continuous degrees', () async {
    for (final mode in [
      HairFoldMode.waveTopView,
      HairFoldMode.waveLowAngle,
    ]) {
      final before = await renderFold(
        mode,
        curve: circularArc(265),
        size: 30,
      );
      final after = await renderFold(
        mode,
        curve: circularArc(275),
        size: 30,
      );
      expect(
        changedPixels(before, after),
        greaterThan(20),
        reason: mode.name,
      );
    }
  });

  test('front strand hides a lower bend crease', () async {
    const curve = [
      ui.Offset(170, 150),
      ui.Offset(230, 200),
      ui.Offset(170, 250),
      ui.Offset(230, 300),
    ];
    final bytes = await renderFold(
      HairFoldMode.waveTopView,
      size: 160,
      curve: curve,
    );
    final pixel = (250 * 256 + 247) * 4;
    expect(bytes.sublist(pixel, pixel + 4), [255, 255, 255, 255]);
  });
  test('live translucent folds are composited only once', () async {
    var checked = false;
    final bytes = await renderFold(
      HairFoldMode.waveTopView,
      opacity: 50,
      beforeEnd: (engine) {
        for (final tile in engine.tileManager.exportAll()['test']!.values) {
          for (var i = 3; i < tile.length; i += 4) {
            expect(tile[i], lessThanOrEqualTo(128));
          }
        }
        checked = true;
      },
    );
    expect(checked, isTrue);
    for (var i = 3; i < bytes.length; i += 4) {
      expect(bytes[i], lessThanOrEqualTo(128));
    }
  });
  test(
    'cancelling after restoring the canvas never repaints the fold',
    () async {
      final bytes = await renderFold(
        HairFoldMode.curlRight,
        beforeEnd: (engine) {
          final empty = <String, Uint8List?>{
            for (final k in engine.tileManager.exportAll()['test']!.keys)
              k: null,
          };
          engine.tileManager.applyTileSnapshot('test', empty);
          engine.endStroke(cancel: true);
        },
      );
      expect(bytes.every((byte) => byte == 0), isTrue);
    },
  );
  test('final fade replay keeps the selected texture and sampling', () {
    final tiles = TileManager(canvasWidth: 400, canvasHeight: 400);
    final engine = DrawingEngine(tileManager: tiles)
      ..currentBrush = Brush(
        id: 'replay',
        name: 'Replay',
        size: 40,
        opacity: 100,
        spacing: 1,
        stabilization: true,
        stabilizationStrength: 80,
        pixelMode: false,
        strokeDecay: false,
        fadeMode: FadeMode.custom,
        outlineEnabled: true,
        foldEnabled: true,
        foldTriggerAngle: 30,
        customImagePaths: const ['first.png', 'second.png'],
        customImageSelectionMode: BrushImageSelectionMode.sequential,
      );
    const a = StrokePoint(x: 50, y: 50, pressure: 1, tiltX: 0, tiltY: 0);
    const b = StrokePoint(x: 150, y: 100, pressure: 1, tiltX: 0, tiltY: 0);
    engine.beginStroke(a, 'layer', screenPosition: const ui.Offset(5, 5));
    engine.continueStroke(b, 'layer', screenPosition: const ui.Offset(15, 10));
    engine.replayCurrentStrokeWithFinalFade();
    expect(engine.debugActiveBrushTexturePath, 'first.png');
    engine.endStroke();
    engine.beginStroke(a, 'layer');
    expect(engine.debugActiveBrushTexturePath, 'second.png');
    engine.endStroke();
    tiles.dispose();
  });
  test(
    'cross-tile folds preserve artwork through fade replay and Undo/Redo',
    () async {
      final background = Uint8List(
        TileManager.tileSize * TileManager.tileSize * 4,
      );
      for (var i = 0; i < background.length; i += 4) {
        background.setRange(i, i + 4, [30, 90, 150, 255]);
      }
      final original = {
        'test': {'0,0': background},
      };
      var checked = false;
      await renderFold(
        HairFoldMode.crescent,
        opacity: 50,
        beforeBegin: (engine) {
          engine.currentBrush = engine.currentBrush!.copyWith(
            fadeMode: FadeMode.custom,
          );
          engine.tileManager.importAll(original);
          engine.tileManager.beginUndoRecording('test');
        },
        beforeEnd: (engine) {
          final tiles = engine.tileManager;
          expect(engine.needsFinalFadeReplay, isTrue);
          final preview = tiles.endUndoRecording();
          tiles.applyTileSnapshot('test', preview.before);
          tiles.beginUndoRecording('test');
          engine.replayCurrentStrokeWithFinalFade();
          engine.endStroke();
          final stroke = tiles.endUndoRecording();
          expect(stroke.before.keys, containsAll(['0,0', '0,1']));
          final drawn = {
            'test': {
              for (final entry in tiles.exportAll()['test']!.entries)
                entry.key: Uint8List.fromList(entry.value),
            },
          };
          expect(drawn, isNot(equals(original)));
          // Existing opaque artwork must never be erased by translucent ink.
          for (var i = 3; i < drawn['test']!['0,0']!.length; i += 4) {
            expect(drawn['test']!['0,0']![i], 255);
          }
          tiles.applyTileSnapshot('test', stroke.before);
          expect(tiles.exportAll(), original);
          tiles.applyTileSnapshot('test', stroke.after);
          expect(tiles.exportAll(), drawn);
          checked = true;
        },
      );
      expect(checked, isTrue);
    },
  );
}
