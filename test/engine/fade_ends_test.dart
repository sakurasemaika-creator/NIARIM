// フェードは線の始点と終点に向かって透けていき、それ以外は不透明度100%
// （ブラシの不透明度）のまま（所有者の定義、2026-11-27「エアブラシが360度全体に
// 向かって透けていくペンだとしたら、フェードは始点と終点に向かって透けていくが
// それ以外は不透明度100%になるペンと考えてください。」）。
//
// - 始点から「距離」の間は開始値から100%へ、終点までの「距離」の間は100%から
//   終了値へ、なめらかに変わる。その間は100%で、線の長さで薄れない。
// - 透け方は線に沿ってだけ変わる（太さ・線を横切る形は変わらず、重なった
//   スタンプで真ん中に濃い筋が立たない）。
// - 2つの距離より短い線は、2つの変わり方が100%で出会い、途中で開始値・終了値
//   より薄くならない。
// - 筆圧の不透明度にフェードを掛ける。
// - 縁取りペンのフェードは全体の形（太さ）を変え、不透明度は変えない（別の
//   test：hair_preset_taper_test ほか）。
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const _w = 640;
const _h = 200;
const _y = 100.0;
const _x0 = 20.0;
const _level = 1 / 255;

Brush _pen(
  FadeMode mode, {
  FadeEndpointSettings fadeIn = FadeEndpointSettings.full,
  FadeEndpointSettings fadeOut = FadeEndpointSettings.full,
  PressureRangeSetting opacityPressure = const PressureRangeSetting(
    enabled: false,
    weak: 100,
    strong: 100,
  ),
}) => Brush(
  id: 'fade',
  name: 'fade',
  size: 20,
  opacity: 100,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: const PressureRangeSetting(enabled: false, weak: 100, strong: 100),
    opacity: opacityPressure,
  ),
  pressureOff: BrushPressureOffSettings.defaults,
  fadeMode: mode,
  fadeIn: fadeIn,
  fadeOut: fadeOut,
  strokeDecay: false,
);

/// Draws [brush] along y [_y] from x [_x0] for [length] px at [pressure],
/// drawn again once complete when it needs to be (as the canvas does, for
/// the ramp at the end); [redrawn] is whether it needs to be.
TileManager _stroke(
  Brush brush,
  double length, {
  double pressure = 1,
  bool redrawn = true,
}) {
  final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xFF2648D6)
    ..pressureEnabled = true;
  tiles.beginUndoRecording('l');
  engine.beginStroke(StrokePoint(x: _x0, y: _y, pressure: pressure), 'l');
  for (var d = 2.0; d <= length; d += 2) {
    engine.continueStroke(
      StrokePoint(x: _x0 + d, y: _y, pressure: pressure),
      'l',
    );
  }
  expect(engine.needsFinalFadeReplay, redrawn);
  if (redrawn) {
    final preview = tiles.endUndoRecording();
    tiles.applyTileSnapshot('l', preview.before);
    tiles.beginUndoRecording('l');
    engine.replayCurrentStrokeWithFinalFade();
  }
  engine.endStroke();
  tiles.endUndoRecording();
  return tiles;
}

double _alpha(TileManager tiles, int x, int y) =>
    tiles.getPixelColorAt('l', x, y)?.a ?? 0;

/// The eased ramp: 0 at the tip, 1 where it meets the full stroke, level
/// there.
double _shoulder(double p) => p + p * p * (1 - p);

/// The fade [s] px along a stroke [total] px long.
double _expected(double s, double total, (double, double, double, double) r) {
  final (inValue, inRange, outValue, outRange) = r;
  var fade = 1.0;
  if (inRange > 0 && s < inRange) {
    fade = inValue + (1 - inValue) * _shoulder((s / inRange).clamp(0, 1));
  }
  final left = total - s;
  if (outRange > 0 && left < outRange) {
    fade *=
        outValue + (1 - outValue) * _shoulder((left / outRange).clamp(0, 1));
  }
  return fade;
}

void main() {
  const presets = {
    FadeMode.weak: (0.5, 40.0, 0.5, 40.0),
    FadeMode.medium: (0.2, 80.0, 0.2, 80.0),
    FadeMode.strong: (0.0, 150.0, 0.0, 150.0),
    FadeMode.custom: (0.3, 60.0, 0.1, 120.0),
  };
  Brush brushFor(FadeMode mode) => mode == FadeMode.custom
      ? _pen(
          mode,
          fadeIn: const FadeEndpointSettings(value: 30, rangePx: 60),
          fadeOut: const FadeEndpointSettings(value: 10, rangePx: 120),
        )
      : _pen(mode);

  for (final entry in presets.entries) {
    test('${entry.key.name}: a long stroke is full between its ends and '
        'fades smoothly only towards them', () {
      const length = 560.0;
      final tiles = _stroke(brushFor(entry.key), length);
      final (_, inRange, _, outRange) = entry.value;
      var last = -1.0;
      for (var x = _x0.toInt() + 1; x < _x0 + length; x++) {
        final s = x + 0.5 - _x0;
        final centre = _alpha(tiles, x, _y.toInt());
        final want = _expected(s, length, entry.value);
        expect(
          (centre - want).abs(),
          lessThanOrEqualTo(3 * _level),
          reason: 'at $s px: ${centre.toStringAsFixed(3)} for $want',
        );
        if (s > inRange + 2 && s < length - outRange - 2) {
          expect(centre, greaterThanOrEqualTo(1 - _level), reason: 'at $s px');
        }
        // No steps along it.
        if (last >= 0) {
          expect((centre - last).abs(), lessThan(0.03), reason: 'at $s px');
        }
        last = centre;
        // Across the stroke it fades evenly: no denser middle in the ramps.
        for (var k = 1; k <= 6; k++) {
          for (final y in [_y.toInt() - k, _y.toInt() + k]) {
            expect(
              (_alpha(tiles, x, y) - centre).abs(),
              lessThanOrEqualTo(2 * _level),
              reason: 'at $s px, $k px from the middle',
            );
          }
        }
      }
    });
  }

  test('the fade keeps the stroke as wide as it is', () {
    final tiles = _stroke(brushFor(FadeMode.custom), 400);
    int width(int x) => [
      for (var y = 0; y < _h; y++)
        if (_alpha(tiles, x, y) > 0) y,
    ].length;
    final full = width(220);
    expect(width(_x0.toInt() + 5), full);
    expect(width((_x0 + 400 - 5).toInt()), full);
  });

  test('a stroke shorter than both fades: the ramps meet at full, never '
      'below the end values', () {
    final brush = _pen(
      FadeMode.custom,
      fadeIn: const FadeEndpointSettings(value: 40, rangePx: 100),
      fadeOut: const FadeEndpointSettings(value: 40, rangePx: 100),
    );
    const length = 80.0;
    final tiles = _stroke(brush, length);
    final along = [
      for (var x = _x0.toInt(); x <= _x0 + length; x++)
        _alpha(tiles, x, _y.toInt()),
    ];
    final peak = along.indexOf(along.reduce((a, b) => a > b ? a : b));
    expect(along[peak], greaterThan(0.97));
    expect((peak - length / 2).abs(), lessThanOrEqualTo(3));
    for (var i = 0; i < along.length; i++) {
      expect(along[i], greaterThanOrEqualTo(0.4 - 3 * _level), reason: '$i');
      // Up to the middle, then down: no dip where the ramps meet.
      if (i > 0 && i <= peak) {
        expect(along[i], greaterThanOrEqualTo(along[i - 1] - _level));
      }
      if (i > peak) {
        expect(along[i], lessThanOrEqualTo(along[i - 1] + _level));
      }
    }
  });

  test('a fade at the start only is drawn once, as it will be; its untouched '
      'end takes no share of a short stroke', () {
    // The end is left at 100% (over 500px, the custom fade's default).
    final brush = _pen(
      FadeMode.custom,
      fadeIn: const FadeEndpointSettings(value: 30, rangePx: 60),
    );
    const length = 300.0;
    final tiles = _stroke(brush, length, redrawn: false);
    for (var x = _x0.toInt() + 1; x < _x0 + length; x++) {
      final s = x + 0.5 - _x0;
      expect(
        (_alpha(tiles, x, _y.toInt()) -
                _expected(s, length, (0.3, 60.0, 1.0, 0.0)))
            .abs(),
        lessThanOrEqualTo(3 * _level),
        reason: 'at $s px',
      );
    }
    // Shorter than the start's distance: the ramp is drawn again to reach
    // full at the end.
    final short = _stroke(brush, 40);
    expect(_alpha(short, _x0.toInt(), _y.toInt()), closeTo(0.3, 3 * _level));
    expect(_alpha(short, (_x0 + 39).toInt(), _y.toInt()), greaterThan(0.97));
  });

  test('pen pressure still sets the opacity; the fade multiplies it', () {
    final brush = _pen(
      FadeMode.weak,
      opacityPressure: const PressureRangeSetting(
        enabled: true,
        weak: 50,
        strong: 100,
      ),
    );
    final tiles = _stroke(brush, 400, pressure: 0.5);
    // 75% between the ends, half of that at the start.
    expect(_alpha(tiles, 220, _y.toInt()), closeTo(0.75, 2 * _level));
    expect(
      _alpha(tiles, _x0.toInt(), _y.toInt()),
      closeTo(0.75 * 0.5, 3 * _level),
    );
  });
}
