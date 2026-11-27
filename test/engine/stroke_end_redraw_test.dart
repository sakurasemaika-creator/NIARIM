// ペンを離した後の描き直しは、線の終わりが変わる所（終点のフェード・入り抜きの
// 距離から届く64pxのマス）だけを描き直す（所有者の方針「機能を保ったまま軽く」、
// 2026-11-27）。結果は、全部のタイルを線の前へ戻して線全体を描き直したのと
// 1バイトも違わない（タイルと取り消しの記録の両方）。短い線（始点も変わる）・
// 縁取りペン・混色は線全体を描き直す。
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const _layer = 'l';

Brush _brush({
  double size = 20,
  int opacity = 100,
  FadeMode fade = FadeMode.off,
  FadeEndpointSettings fadeIn = FadeEndpointSettings.full,
  FadeEndpointSettings fadeOut = FadeEndpointSettings.full,
  FadeMode taper = FadeMode.off,
  FadeEndpointSettings taperIn = FadeEndpointSettings.full,
  FadeEndpointSettings taperOut = FadeEndpointSettings.full,
  bool pressure = false,
  int blur = 0,
  double scatter = 0,
  BrushMixingMode mixing = BrushMixingMode.off,
}) => Brush(
  id: 'b',
  name: 'b',
  size: size,
  opacity: opacity,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: PressureRangeSetting(enabled: pressure, weak: 30, strong: 100),
    opacity: PressureRangeSetting(enabled: pressure, weak: 50, strong: 100),
    blur: PressureRangeSetting(enabled: blur > 0, weak: blur, strong: blur),
    mixing: PressureMixingOnSetting(
      enabled: mixing != BrushMixingMode.off,
      mode: mixing == BrushMixingMode.off ? BrushMixingMode.oil : mixing,
      weakRate: 40,
      strongRate: 40,
    ),
  ),
  pressureOff: BrushPressureOffSettings.defaults,
  fadeMode: fade,
  fadeIn: fadeIn,
  fadeOut: fadeOut,
  taperMode: taper,
  taperIn: taperIn,
  taperOut: taperOut,
  strokeDecay: false,
  scatter: scatter,
);

typedef _Result = ({
  Map<String, Uint8List> tiles,
  Map<String, Uint8List?> before,
  Map<String, Uint8List?> after,
  bool partly,
});

/// Draws [points] with [brush] on a layer that already has [underneath]
/// drawn on it, as the canvas does: recording the undo, then at pen-up
/// either drawing only the end again ([partly]) or putting every tile back
/// and drawing the whole stroke again.
_Result _draw(
  Brush brush,
  List<StrokePoint> points, {
  required bool partly,
  bool eraser = false,
  List<StrokePoint>? underneath,
}) {
  final tiles = TileManager(canvasWidth: 640, canvasHeight: 360);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentColor = const ui.Color(0xFF2648D6)
    ..pressureEnabled = true;
  if (underneath != null) {
    engine.currentBrush = _brush(size: 60, opacity: 100);
    engine.currentColor = const ui.Color(0xFFE0B020);
    engine.beginStroke(underneath.first, _layer);
    for (final p in underneath.skip(1)) {
      engine.continueStroke(p, _layer);
    }
    engine.endStroke();
    engine.currentColor = const ui.Color(0xFF2648D6);
  }
  engine
    ..currentBrush = brush
    ..isEraser = eraser;
  tiles.beginUndoRecording(_layer);
  engine.beginStroke(points.first, _layer);
  for (final p in points.skip(1)) {
    engine.continueStroke(p, _layer);
  }
  var drewPartly = false;
  if (engine.needsFinalFadeReplay) {
    if (partly) drewPartly = engine.redrawStrokeEnd();
    if (!drewPartly) {
      final live = tiles.endUndoRecording();
      tiles.applyTileSnapshot(_layer, live.before);
      tiles.beginUndoRecording(_layer);
      engine.replayCurrentStrokeWithFinalFade();
    }
  }
  engine.endStroke();
  final undo = tiles.endUndoRecording();
  return (
    tiles: tiles.shareLayerTiles(_layer) ?? const {},
    before: undo.before,
    after: undo.after,
    partly: drewPartly,
  );
}

void _expectSameBytes(
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

List<StrokePoint> _straight(double length, {bool pressure = false}) => [
  for (var d = 0.0; d <= length; d += 3)
    StrokePoint(
      x: 40 + d,
      y: 180,
      pressure: pressure ? 0.4 + 0.6 * (0.5 + 0.5 * math.sin(d / 37)) : 1,
    ),
];

List<StrokePoint> _curve() => [
  for (var a = 200.0; a <= 520; a += 2)
    StrokePoint(
      x: 320 + 150 * math.cos(a * math.pi / 180),
      y: 300 + 150 * math.sin(a * math.pi / 180),
      pressure: 0.7 + 0.3 * math.sin(a / 23),
    ),
];

List<StrokePoint> _wave() => [
  for (var x = 30.0; x <= 610; x += 2.5)
    StrokePoint(
      x: x,
      y: 180 + 70 * math.sin(x / 60),
      pressure: 0.5 + 0.5 * math.cos(x / 90).abs(),
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final custom = (
    FadeEndpointSettings(value: 20, rangePx: 60),
    FadeEndpointSettings(value: 0, rangePx: 120),
  );
  final brushes = <String, Brush>{
    'fade weak': _brush(fade: FadeMode.weak),
    'fade medium': _brush(fade: FadeMode.medium),
    'fade strong': _brush(fade: FadeMode.strong),
    'fade both ends': _brush(
      fade: FadeMode.custom,
      fadeIn: custom.$1,
      fadeOut: custom.$2,
    ),
    'fade end only': _brush(fade: FadeMode.custom, fadeOut: custom.$2),
    'fade start only': _brush(fade: FadeMode.custom, fadeIn: custom.$1),
    'taper both ends': _brush(
      taper: FadeMode.custom,
      taperIn: custom.$1,
      taperOut: custom.$2,
    ),
    'taper end only': _brush(taper: FadeMode.custom, taperOut: custom.$2),
    'taper strong': _brush(taper: FadeMode.strong),
    'fade and taper': _brush(
      fade: FadeMode.medium,
      taper: FadeMode.custom,
      taperIn: custom.$1,
      taperOut: custom.$2,
    ),
    'pressure, both': _brush(
      fade: FadeMode.custom,
      fadeOut: custom.$2,
      taper: FadeMode.weak,
      pressure: true,
    ),
    'soft (blur), fade': _brush(size: 30, blur: 25, fade: FadeMode.strong),
    'translucent, taper': _brush(
      opacity: 60,
      taper: FadeMode.custom,
      taperOut: custom.$2,
    ),
    'scatter, taper': _brush(
      size: 12,
      scatter: .4,
      taper: FadeMode.custom,
      taperOut: custom.$2,
    ),
    'lateral repeat, taper': _brush(
      size: 10,
      taper: FadeMode.custom,
      taperOut: custom.$2,
    ).copyWith(lateralRepeatEnabled: true, lateralRepeatCount: 3),
    'nib (calligraphy), fade': _brush(
      size: 26,
      fade: FadeMode.strong,
    ).copyWith(calligraphyAngle: 30, nibWidthRatio: .3),
    'glitter flakes, taper': _brush(
      size: 18,
      taper: FadeMode.custom,
      taperOut: custom.$2,
    ).copyWith(tipShape: BrushTipShape.hexagon),
  };
  final strokes = <String, List<StrokePoint>>{
    'straight': _straight(420),
    'straight with pressure': _straight(420, pressure: true),
    'curve': _curve(),
    'wave': _wave(),
    'tilted pen': [
      for (final p in _wave())
        StrokePoint(x: p.x, y: p.y, pressure: p.pressure, tiltX: .6, tiltY: .3),
    ],
  };

  for (final brush in brushes.entries) {
    for (final stroke in strokes.entries) {
      test('${brush.key}, ${stroke.key}: drawing only the end again is the '
          'same as drawing the whole stroke again', () {
        final whole = _draw(brush.value, stroke.value, partly: false);
        final part = _draw(brush.value, stroke.value, partly: true);
        final startOnly = brush.key.contains('start only');
        expect(part.partly, !startOnly, reason: 'drawn again only in part');
        _expectSameBytes(whole.tiles, part.tiles, 'tiles');
        _expectSameBytes(whole.before, part.before, 'undo before');
        _expectSameBytes(whole.after, part.after, 'undo after');
      });
    }
  }

  test('over paint already on the layer, and erasing', () {
    final brush = brushes['fade and taper']!;
    final under = _straight(560);
    for (final eraser in [false, true]) {
      final whole = _draw(
        brush,
        _wave(),
        partly: false,
        eraser: eraser,
        underneath: under,
      );
      final part = _draw(
        brush,
        _wave(),
        partly: true,
        eraser: eraser,
        underneath: under,
      );
      expect(part.partly, isTrue);
      _expectSameBytes(whole.tiles, part.tiles, 'eraser $eraser tiles');
      _expectSameBytes(whole.before, part.before, 'eraser $eraser before');
    }
  });

  test('a short stroke, an outline pen and mixing are drawn again whole', () {
    final short = _draw(
      brushes['fade both ends']!,
      _straight(90),
      partly: true,
    );
    expect(short.partly, isFalse, reason: 'short stroke');
    final mixing = _brush(fade: FadeMode.strong, mixing: BrushMixingMode.oil);
    final mixed = _draw(mixing, _straight(420), partly: true);
    expect(mixed.partly, isFalse, reason: 'mixing');
    final whole = _draw(mixing, _straight(420), partly: false);
    _expectSameBytes(whole.tiles, mixed.tiles, 'mixing');
    final outline = _brush(
      taper: FadeMode.custom,
      taperOut: custom.$2,
    ).copyWith(outlineEnabled: true, outlineWidth: 2);
    expect(_draw(outline, _straight(420), partly: true).partly, isFalse);
  });
}
