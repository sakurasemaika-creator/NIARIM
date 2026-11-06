import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/premultiplied.dart';
import 'package:niarim/engine/tone_curve.dart';

/// Tone Curve and Levels work on the straight colour of premultiplied
/// layer pixels: a transparent pixel stays transparent (no colour appears
/// in it), and a half-transparent edge comes out as the same colour as the
/// solid paint, at its own opacity. The tone curve is a smooth curve through
/// every point; a channel's levels apply on top of the RGB ones.
void main() {
  final engine = FilterEngine();

  /// One transparent pixel, one solid (200, 100, 50) and the same colour at
  /// 50 % opacity (premultiplied).
  Uint8List sample() => Uint8List.fromList([
    0, 0, 0, 0, //
    200, 100, 50, 255, //
    100, 50, 25, 128, //
  ]);

  /// The straight colour of pixel [i] of [data].
  List<int> straight(Uint8List data, int i) {
    final a = data[i * 4 + 3];
    return [for (var c = 0; c < 3; c++) straightChannel(data[i * 4 + c], a)];
  }

  void expectValidPremultiplied(Uint8List data) {
    for (var i = 0; i < data.length; i += 4) {
      for (var c = 0; c < 3; c++) {
        expect(
          data[i + c],
          lessThanOrEqualTo(data[i + 3]),
          reason: 'pixel ${i ~/ 4} channel $c is brighter than its alpha',
        );
      }
    }
  }

  group('tone curve', () {
    test('invert keeps transparent pixels transparent and edges true', () {
      final out = engine.applyToneCurve(sample(), 3, 1, const [
        Offset(0, 1),
        Offset(1, 0),
      ]);
      expect(out.sublist(0, 4), [0, 0, 0, 0]);
      expectValidPremultiplied(out);
      expect(straight(out, 1), [55, 155, 205]);
      // The half-transparent copy inverts to the same colour, ±1 for
      // rounding, and keeps its opacity.
      for (var c = 0; c < 3; c++) {
        expect(straight(out, 2)[c], closeTo(straight(out, 1)[c], 2));
      }
      expect(out[11], 128);
    });

    test('a smooth curve passes through every point without overshoot', () {
      const points = [
        Offset(0, 0),
        Offset(0.25, 0.4),
        Offset(0.5, 0.45),
        Offset(1, 1),
      ];
      final curve = ToneCurve(points);
      for (final p in points) {
        expect(curve.valueAt(p.dx), closeTo(p.dy, 1e-9));
      }
      // Smooth: no corner at the point (equal slopes on both sides)…
      double slope(double a, double b) =>
          (curve.valueAt(b) - curve.valueAt(a)) / (b - a);
      expect(
        slope(0.249, 0.25),
        closeTo(slope(0.25, 0.251), 0.05),
        reason: 'no corner',
      );
      // …and monotone between points that rise (it never dips below the
      // lower one or above the higher one).
      final lut = curve.lut();
      for (var i = 1; i < 256; i++) {
        expect(lut[i], greaterThanOrEqualTo(lut[i - 1]));
      }
      for (var x = 0.25; x <= 0.5; x += 0.01) {
        expect(curve.valueAt(x), inInclusiveRange(0.4, 0.45));
      }
    });

    test('a channel curve follows the RGB curve', () {
      // RGB brightens, the red curve then halves red.
      final out = engine.applyToneCurve(
        Uint8List.fromList([100, 100, 100, 255]),
        1,
        1,
        const [Offset(0, 0.2), Offset(1, 1)],
        redPoints: const [Offset(0, 0), Offset(1, 0.5)],
      );
      final brightened = (0.2 + 0.8 * 100 / 255) * 255;
      expect(out[1], closeTo(brightened, 1));
      expect(out[0], closeTo(brightened / 2, 1));
    });
  });

  group('levels', () {
    test('output black does not paint transparent pixels', () {
      final out = engine.applyLevels(
        sample(),
        3,
        1,
        inputBlack: 0,
        inputWhite: 255,
        outputBlack: 60,
        outputWhite: 255,
      );
      expect(out.sublist(0, 4), [0, 0, 0, 0]);
      expectValidPremultiplied(out);
      for (var c = 0; c < 3; c++) {
        expect(straight(out, 2)[c], closeTo(straight(out, 1)[c], 2));
      }
    });

    test('a channel\'s levels apply on top of the RGB levels', () {
      final pixel = Uint8List.fromList([128, 128, 128, 255]);
      final rgbOnly = engine.applyLevels(
        pixel,
        1,
        1,
        inputBlack: 0,
        inputWhite: 200,
        outputBlack: 0,
        outputWhite: 255,
      );
      // The red channel then lifts its output black.
      final withRed = engine.applyLevels(
        pixel,
        1,
        1,
        inputBlack: 0,
        inputWhite: 200,
        outputBlack: 0,
        outputWhite: 255,
        redLevels: const [0, 255, 1, 100, 255],
      );
      expect(withRed[1], rgbOnly[1], reason: 'green untouched');
      expect(rgbOnly[0], greaterThan(128), reason: 'RGB brightened red too');
      final expectedRed = (100 + rgbOnly[0] / 255 * 155).round();
      expect(withRed[0], closeTo(expectedRed, 1));
      // A channel at its defaults changes nothing.
      final defaults = engine.applyLevels(
        pixel,
        1,
        1,
        inputBlack: 0,
        inputWhite: 200,
        outputBlack: 0,
        outputWhite: 255,
        greenLevels: const [0, 255, 1, 0, 255],
      );
      expect(defaults, orderedEquals(rgbOnly));
    });
  });
}
