// スタンプを置くときの近道（ペン先の画像の透明な外側・不透明な内側は画像を
// 引かない、行ごとに画像が届く所だけを回る、この線がすでに覆った画素は計算
// しない）は、全部の画素をまともに計算したときと1バイトも違わない（所有者の
// 方針「機能を保ったまま軽く」、2026-11-27）。組み込みのブラシの先端の画像を
// 読み、太さ・筆圧・傾けたペン・消しゴム・不透明度・下の絵で確かめる。
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';

const _layer = 'l';

List<StrokePoint> _wave({bool tilt = false, bool pressure = true}) => [
  for (var i = 0; i <= 90; i++)
    StrokePoint(
      x: 30 + i * 3.7,
      y: 120 + 70 * math.sin(i / 90 * 2.5 * math.pi),
      pressure: pressure ? 0.3 + 0.7 * math.sin(math.pi * i / 90) : 1,
      tiltX: tilt ? (0.5 + 0.004 * i) * math.cos(0.6 + i / 45) : 0,
      tiltY: tilt ? (0.5 + 0.004 * i) * math.sin(0.6 + i / 45) : 0,
      inputType: InputType.stylus,
    ),
];

typedef _Result = ({
  Map<String, Uint8List> tiles,
  Map<String, Uint8List?> before,
  Map<String, Uint8List?> after,
});

_Result _draw(
  Brush brush,
  List<StrokePoint> points, {
  required bool everyPixel,
  bool eraser = false,
}) {
  DrawingEngine.debugEveryDabPixel = everyPixel;
  try {
    final tiles = TileManager(canvasWidth: 400, canvasHeight: 240);
    final engine = DrawingEngine(tileManager: tiles)..pressureEnabled = true;
    // Paint under the stroke, for the brushes that pick it up or erase it.
    engine
      ..currentBrush = brush.copyWith(
        size: 30,
        pressureOn: BrushPressureOnSettings.defaults,
        pressureOff: BrushPressureOffSettings.defaults,
      )
      ..currentColor = const ui.Color(0xFFE0B020);
    engine.beginStroke(const StrokePoint(x: 10, y: 110), _layer);
    for (var x = 14.0; x < 395; x += 4) {
      engine.continueStroke(StrokePoint(x: x, y: 110 + x / 20), _layer);
    }
    engine.endStroke();
    engine
      ..currentBrush = brush
      ..currentColor = const ui.Color(0xFF2648D6)
      ..isEraser = eraser;
    tiles.beginUndoRecording(_layer);
    engine.beginStroke(points.first, _layer);
    for (final p in points.skip(1)) {
      engine.continueStroke(p, _layer);
    }
    if (engine.needsFinalFadeReplay && !engine.redrawStrokeEnd()) {
      final live = tiles.endUndoRecording();
      tiles.applyTileSnapshot(_layer, live.before);
      tiles.beginUndoRecording(_layer);
      engine.replayCurrentStrokeWithFinalFade();
    }
    engine.endStroke();
    final undo = tiles.endUndoRecording();
    return (
      tiles: {...?tiles.shareLayerTiles(_layer)},
      before: undo.before,
      after: undo.after,
    );
  } finally {
    DrawingEngine.debugEveryDabPixel = false;
  }
}

void _expectSame(
  Map<String, Uint8List?> a,
  Map<String, Uint8List?> b,
  String what,
) {
  expect(a.keys.toSet(), b.keys.toSet(), reason: '$what: tiles');
  for (final key in a.keys) {
    final x = a[key], y = b[key];
    if (x == null || y == null) {
      expect(x, y, reason: '$what $key');
      continue;
    }
    var differ = -1;
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) {
        differ = i;
        break;
      }
    }
    expect(differ, -1, reason: '$what $key: first byte that differs');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final builtIns = {for (final b in BrushService.builtInBrushes) b.id: b};

  setUpAll(() async {
    for (final b in builtIns.values) {
      await preloadBrushTextures(
        b.resolvedCustomImagePaths,
        mode: b.imageInkMode,
      );
    }
  });

  // Edge jitter, paper tooth and bristle marks depend only on where the
  // pixel is, so the dry media and the bristle brushes are in too.
  final cases = <String, Brush Function()>{
    'pen 5': () => builtIns['Brush0001']!,
    'pen 30': () => builtIns['Brush0001']!.copyWith(size: 30),
    'pen 80 at 40%': () =>
        builtIns['Brush0001']!.copyWith(size: 80, opacity: 40),
    'G-pen 30': () => builtIns['Brush0002']!.copyWith(size: 30),
    'airbrush': () => builtIns['Brush0003']!,
    'airbrush 10': () => builtIns['Brush0003']!.copyWith(size: 10),
    'blur': () => builtIns['Brush0011']!,
    'marker': () => builtIns['Brush0005']!,
    'calligraphy': () => builtIns['Brush0006']!,
    'flat brush (oil)': () => builtIns['Brush0009']!,
    'watercolor': () => builtIns['Brush0010']!,
    'mixing brush': () => builtIns['Brush0004']!,
    'pencil': () => builtIns['Brush0007']!,
    'pencil 4B': () => builtIns['Brush0028']!,
    'chalk': () => builtIns['Brush0012']!,
    'charcoal': () => builtIns['Brush0026']!,
    'pastel': () => builtIns['Brush0029']!,
    'gouache': () => builtIns['Brush0027']!,
    'oil brush': () => builtIns['Brush0042']!,
    'dry brush': () => builtIns['Brush0043']!,
    'palette knife': () => builtIns['Brush0044']!,
    'palette knife, light': () =>
        builtIns['Brush0044']!.copyWith(size: 30, dryBrush: 80),
  };
  for (final entry in cases.entries) {
    for (final tilt in [false, true]) {
      final name = '${entry.key}${tilt ? ', tilted pen' : ''}';
      test('$name: the same tiles and undo record as every pixel', () {
        final brush = entry.value();
        expect(
          getCachedBrushTexture(
            brush.resolvedCustomImagePaths.first,
            mode: brush.imageInkMode,
          ),
          isNotNull,
        );
        final points = _wave(tilt: tilt);
        final quick = _draw(brush, points, everyPixel: false);
        final slow = _draw(brush, points, everyPixel: true);
        _expectSame(quick.tiles, slow.tiles, '$name tiles');
        _expectSame(quick.before, slow.before, '$name undo before');
        _expectSame(quick.after, slow.after, '$name undo after');
      });
    }
  }

  test('a tap of a bristle brush (a round dab with splayed hair ends): the '
      'same as every pixel', () {
    for (final id in ['Brush0009', 'Brush0042', 'Brush0043', 'Brush0027']) {
      final points = [const StrokePoint(x: 200, y: 120, pressure: 0.8)];
      final quick = _draw(builtIns[id]!, points, everyPixel: false);
      final slow = _draw(builtIns[id]!, points, everyPixel: true);
      _expectSame(quick.tiles, slow.tiles, '$id tap tiles');
      _expectSame(quick.before, slow.before, '$id tap undo');
    }
  });

  test('eraser and a mouse line: the same as every pixel', () {
    for (final id in ['Brush0001', 'Brush0003', 'Brush0005']) {
      final brush = builtIns[id]!.copyWith(size: 40);
      for (final eraser in [false, true]) {
        final points = _wave(pressure: false);
        final quick = _draw(brush, points, everyPixel: false, eraser: eraser);
        final slow = _draw(brush, points, everyPixel: true, eraser: eraser);
        _expectSame(quick.tiles, slow.tiles, '$id eraser=$eraser tiles');
        _expectSame(quick.before, slow.before, '$id eraser=$eraser undo');
      }
    }
  });
}
