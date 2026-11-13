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

int changedPixels(Uint8List a, Uint8List b, {bool interiorOnly = false}) {
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (interiorOnly) {
      final point = ui.Offset(
        (i ~/ 4 % 256).toDouble(),
        (i ~/ 4 ~/ 256).toDouble(),
      );
      if ((point - foldCurve.first).distance < 90 ||
          (point - foldCurve.last).distance < 90) {
        continue;
      }
    }
    if ((a[i] - b[i]).abs() > 80 || (a[i + 3] - b[i + 3]).abs() > 80) count++;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in HairFoldMode.values.where(
    (m) => m != HairFoldMode.crescent,
  )) {
    test('${mode.name} folded stroke finishes at zero width', () async {
      final pixels = await renderFold(mode);
      int alpha(int x, int y) => pixels[(y * 256 + x) * 4 + 3];
      expect(
        alpha(180, 340),
        lessThan(16),
        reason: 'the actual stroke endpoint',
      );
      expect(
        alpha(120, 290),
        greaterThan(240),
        reason: 'the body retains its width',
      );
      expect(
        [
          for (var x = 150; x <= 210; x++)
            if (alpha(x, 340) > 127) x,
        ],
        isEmpty,
        reason: 'no rounded terminal cap',
      );
    });
  }
  test(
    'a wide fold with a short final run still finishes at zero width',
    () async {
      const curve = [
        ui.Offset(60, 40),
        ui.Offset(120, 100),
        ui.Offset(60, 100),
      ];
      final pixels = await renderFold(
        HairFoldMode.waveTopView,
        size: 60,
        curve: curve,
      );
      expect(pixels[(100 * 256 + 60) * 4 + 3], lessThan(16));
    },
  );
  test('short straight wave/curl dashes finish at a point', () async {
    for (final mode in HairFoldMode.values.where(
      (m) => m != HairFoldMode.crescent,
    )) {
      final pixels = await renderFold(
        mode,
        size: 60,
        curve: const [ui.Offset(60, 40), ui.Offset(70, 40)],
      );
      expect(pixels[(40 * 256 + 70) * 4 + 3], lessThan(16), reason: mode.name);
    }
  });
  test('duplicate stationary wave/curl input preserves its tap', () async {
    const point = ui.Offset(60, 40);
    final plain = await renderFold(
      HairFoldMode.waveTopView,
      enabled: false,
      curve: const [point],
    );
    for (final mode in HairFoldMode.values.where(
      (m) => m != HairFoldMode.crescent,
    )) {
      final pixels = await renderFold(
        mode,
        curve: const [point],
        beforeEnd: (engine) {
          engine.continueStroke(
            const StrokePoint(x: 60, y: 40, pressure: 1, tiltX: 0, tiltY: 0),
            'test',
          );
        },
      );
      expect(pixels, plain, reason: mode.name);
    }
  });
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
  test(
    'straight wave/curl input keeps its body and finishes at zero width',
    () async {
      const line = [ui.Offset(60, 40), ui.Offset(60, 340)];
      final plain = await renderFold(
        HairFoldMode.waveTopView,
        enabled: false,
        curve: line,
      );
      expect(await renderFold(HairFoldMode.crescent, curve: line), plain);
      for (final mode in HairFoldMode.values.where(
        (m) => m != HairFoldMode.crescent,
      )) {
        final actual = await renderFold(mode, curve: line);
        final body = (120 * 256 + 60) * 4;
        expect(actual.sublist(body, body + 4), plain.sublist(body, body + 4));
        expect(
          actual[(340 * 256 + 60) * 4 + 3],
          lessThan(16),
          reason: mode.name,
        );
      }
    },
  );
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
  test(
    'fold depth follows the stroke, so a rotated stroke folds the same way',
    () async {
      // Folds are relative to the stroke's own direction, never to screen
      // axes: rotating the input by 180 degrees rotates the result exactly.
      for (final mode in HairFoldMode.values.where(
        (m) => m != HairFoldMode.crescent,
      )) {
        final original = await renderFold(mode);
        final rotated = await renderFold(
          mode,
          curve: [for (final p in foldCurve) ui.Offset(256 - p.dx, 400 - p.dy)],
        );
        // A fold line may land a pixel off, with slightly different
        // antialiasing, after rotation. A different depth choice moves the
        // fold line to the other section (about 70 such pixels here).
        bool near(int x, int y) {
          final a = (y * 256 + x) * 4;
          for (var dy = -2; dy <= 2; dy++) {
            for (var dx = -2; dx <= 2; dx++) {
              final rx = 255 - x + dx, ry = 399 - y + dy;
              if (rx < 0 || ry < 0 || rx >= 256 || ry >= 400) continue;
              final b = (ry * 256 + rx) * 4;
              var same = true;
              for (var c = 0; c < 4; c++) {
                if ((original[a + c] - rotated[b + c]).abs() > 48) same = false;
              }
              if (same) return true;
            }
          }
          return false;
        }

        var changed = 0;
        for (var y = 0; y < 400; y++) {
          for (var x = 0; x < 256; x++) {
            if (!near(x, y)) changed++;
          }
        }
        expect(changed, lessThan(20), reason: mode.name);
      }
    },
  );
  test(
    'a later crescent keeps the ordinary outline pen start and straight lead',
    () async {
      const curve = [
        ui.Offset(60, 40),
        ui.Offset(60, 160),
        ui.Offset(180, 220),
        ui.Offset(60, 340),
      ];
      final plain = await renderFold(
        HairFoldMode.crescent,
        enabled: false,
        curve: curve,
      );
      final folded = await renderFold(HairFoldMode.crescent, curve: curve);
      var changed = 0;
      for (var y = 16; y < 120; y++) {
        for (var x = 25; x < 95; x++) {
          final p = (y * 256 + x) * 4;
          if ((plain[p] - folded[p]).abs() > 80 ||
              (plain[p + 3] - folded[p + 3]).abs() > 80) {
            changed++;
          }
        }
      }
      expect(
        changed,
        lessThan(10),
        reason:
            'folding must not turn the already drawn lead into a pointed crescent',
      );
      expect(changedPixels(plain, folded), greaterThan(100));
    },
  );
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

  test(
    'continuous 270 degree turns affect crescent production rendering',
    () async {
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
    },
  );

  test('both wave views add a fold after 270 continuous degrees', () async {
    for (final mode in [HairFoldMode.waveTopView, HairFoldMode.waveLowAngle]) {
      final before = await renderFold(mode, curve: circularArc(265), size: 30);
      final after = await renderFold(mode, curve: circularArc(275), size: 30);
      expect(changedPixels(before, after), greaterThan(20), reason: mode.name);
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
