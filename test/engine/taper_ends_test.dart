// 入り抜きは線の始点と終点に向かって太さだけを細くし、色・不透明度は変えない
// （フェード〔透け方〕とは別の設定。所有者の方針「今できる機能を削る行為で
// なければ、いくらでもブラッシュアップしてよい」：以前のカスタムのフェードが
// 端を細くしていたのを、入り抜きとして残す）。
//
// - 始点から「距離」の間は入りの値から100%へ、終点までの「距離」の間は100%
//   から抜きの値へ、なめらかに（`_taperShoulder`の曲線で）太くなる・細くなる。
//   その間はブラシの太さのまま。
// - 色・不透明度は変わらない（細くなった所でも真ん中は選んだ色）。
// - 2つの距離より短い線は、2つの変わり方が100%で出会う。
// - 筆圧の太さに入り抜きを掛ける。
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const _w = 640;
const _h = 120;
const _y = 60.0;
const _x0 = 20.0;
const _size = 24.0;

Brush _pen(
  FadeMode mode, {
  FadeEndpointSettings taperIn = FadeEndpointSettings.full,
  FadeEndpointSettings taperOut = FadeEndpointSettings.full,
  bool pressure = false,
}) => Brush(
  id: 'taper',
  name: 'taper',
  size: _size,
  opacity: 100,
  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: PressureRangeSetting(enabled: pressure, weak: 50, strong: 100),
  ),
  pressureOff: BrushPressureOffSettings.defaults,
  fadeMode: FadeMode.off,
  taperMode: mode,
  taperIn: taperIn,
  taperOut: taperOut,
  strokeDecay: false,
);

TileManager _stroke(Brush brush, double length, {double pressure = 1}) {
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
  expect(engine.needsFinalFadeReplay, isTrue);
  if (!engine.redrawStrokeEnd()) {
    final live = tiles.endUndoRecording();
    tiles.applyTileSnapshot('l', live.before);
    tiles.beginUndoRecording('l');
    engine.replayCurrentStrokeWithFinalFade();
  }
  engine.endStroke();
  tiles.endUndoRecording();
  return tiles;
}

double _alpha(TileManager tiles, int x, int y) =>
    tiles.getPixelColorAt('l', x, y)?.a ?? 0;

/// The width of the stroke across column [x]: its coverage summed.
double _width(TileManager tiles, int x) {
  var sum = 0.0;
  for (var y = 0; y < _h; y++) {
    sum += _alpha(tiles, x, y);
  }
  return sum;
}

double _shoulder(double p) => p + p * p * (1 - p);

double _expected(double s, double total, (double, double, double, double) r) {
  final (inValue, inRange, outValue, outRange) = r;
  var taper = 1.0;
  if (inRange > 0 && inValue < 1 && s < inRange) {
    taper = inValue + (1 - inValue) * _shoulder((s / inRange).clamp(0, 1));
  }
  final left = total - s;
  if (outRange > 0 && outValue < 1 && left < outRange) {
    taper *=
        outValue + (1 - outValue) * _shoulder((left / outRange).clamp(0, 1));
  }
  return taper;
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
          taperIn: const FadeEndpointSettings(value: 30, rangePx: 60),
          taperOut: const FadeEndpointSettings(value: 10, rangePx: 120),
        )
      : _pen(mode);

  for (final entry in presets.entries) {
    test('${entry.key.name}: the width narrows only towards the ends; the '
        'colour stays the chosen colour', () {
      const length = 560.0;
      final tiles = _stroke(brushFor(entry.key), length);
      for (var x = _x0.toInt() + 4; x < _x0 + length - 4; x++) {
        final s = x + 0.5 - _x0;
        final want = _size * _expected(s, length, entry.value);
        expect(_width(tiles, x), closeTo(want, 1.3), reason: 'width at $s px');
        // Wherever the stroke is at least a few pixels wide, its middle is
        // not see-through.
        if (want >= 3) {
          expect(
            _alpha(tiles, x, _y.toInt()),
            greaterThanOrEqualTo(254 / 255),
            reason: 'colour at $s px',
          );
        }
      }
    });
  }

  test('a stroke shorter than both distances: the ramps meet at the full '
      'width, never narrower than the end values', () {
    final brush = _pen(
      FadeMode.custom,
      taperIn: const FadeEndpointSettings(value: 40, rangePx: 100),
      taperOut: const FadeEndpointSettings(value: 40, rangePx: 100),
    );
    const length = 80.0;
    final tiles = _stroke(brush, length);
    final widths = [
      for (var x = _x0.toInt() + 4; x <= _x0 + length - 4; x++)
        _width(tiles, x),
    ];
    final peak = widths.reduce((a, b) => a > b ? a : b);
    expect(peak, closeTo(_size, 1.3));
    for (final w in widths) {
      expect(w, greaterThanOrEqualTo(_size * 0.4 - 1.3));
    }
  });

  test('pen pressure still sets the width; 入り抜き narrows it further', () {
    final tiles = _stroke(
      _pen(FadeMode.weak, pressure: true),
      400,
      pressure: 0.5,
    );
    // Pressure 0.5 between 50 and 100: 75% between the ends.
    expect(_width(tiles, 220), closeTo(_size * 0.75, 1.3));
    expect(_width(tiles, _x0.toInt() + 4), closeTo(_size * 0.75 * 0.55, 1.6));
    expect(_alpha(tiles, 220, _y.toInt()), greaterThanOrEqualTo(254 / 255));
  });
}
