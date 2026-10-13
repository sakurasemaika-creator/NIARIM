import 'dart:math' as math;
import 'dart:ui' as ui;

/// Mixes two opaque paint colours by moving around the hue wheel instead of
/// drawing an RGB chord through its desaturated centre.
///
/// [belowWeight] is the contribution of the colour already on the canvas:
/// 0 produces [selected], 1 produces [below]. Hue follows the shortest arc;
/// exact half-turns keep their signed direction so swapping the two inputs
/// produces the same midpoint. Saturation and lightness are interpolated
/// separately, which helps yellow + blue travel through green/cyan rather
/// than the dull grey-green produced by a straight RGB average.
///
/// This is a practical perceptual/analog-style approximation for brush
/// mixing, not an attempt to reproduce Clip Studio Paint's proprietary
/// pigment-mixing implementation bit-for-bit.
///
/// [brightnessCorrection] ranges from 1 (darker), through 3 (neutral), to
/// 5 (brighter). The correction fades near the mixing endpoints so 0% and
/// 100% mixing still preserve the respective input colour.
ui.Color mixPerceptualColor(
  ui.Color below,
  ui.Color selected,
  double belowWeight, {
  int brightnessCorrection = 3,
}) {
  final weight = belowWeight.clamp(0.0, 1.0).toDouble();
  final selectedWeight = 1.0 - weight;
  final a = _rgbToHsl(below);
  final b = _rgbToHsl(selected);

  // Hue has no useful value for a neutral colour. Borrow the chromatic
  // partner's hue so mixing a colour with white, grey or black does not spin
  // around the wheel unpredictably.
  final hueA = a.saturation <= 1e-6 ? b.hue : a.hue;
  final hueB = b.saturation <= 1e-6 ? hueA : b.hue;
  final rawDelta = hueB - hueA;
  var delta = _wrapHue(rawDelta);
  if (delta > 180.0) {
    delta -= 360.0;
  } else if ((delta - 180.0).abs() <= 1e-9) {
    // Two hues exactly opposite on the wheel have two equally short paths.
    // Retaining the signed direction makes mixing commutative at the midpoint.
    delta = rawDelta < 0 ? -180.0 : 180.0;
  }

  final hue = _wrapHue(hueA + delta * selectedWeight);
  final saturation =
      a.saturation + (b.saturation - a.saturation) * selectedWeight;
  final baseLightness =
      a.lightness + (b.lightness - a.lightness) * selectedWeight;
  final inputDifference = math.max(
    (below.r - selected.r).abs(),
    math.max(
      (below.g - selected.g).abs(),
      (below.b - selected.b).abs(),
    ),
  ).toDouble();
  final blendStrength = 4.0 * weight * selectedWeight;
  final correction = (brightnessCorrection.clamp(1, 5).toDouble() - 3.0) *
      0.035 *
      blendStrength *
      inputDifference;
  final lightness = (baseLightness + correction).clamp(0.0, 1.0).toDouble();
  return _hslToRgb(hue, saturation, lightness);
}

({double hue, double saturation, double lightness}) _rgbToHsl(ui.Color color) {
  final r = color.r.clamp(0.0, 1.0).toDouble();
  final g = color.g.clamp(0.0, 1.0).toDouble();
  final b = color.b.clamp(0.0, 1.0).toDouble();
  final maximum = math.max(r, math.max(g, b));
  final minimum = math.min(r, math.min(g, b));
  final chroma = maximum - minimum;
  final lightness = (maximum + minimum) / 2.0;

  if (chroma <= 1e-9) {
    return (hue: 0.0, saturation: 0.0, lightness: lightness);
  }

  final denominator = 1.0 - (2.0 * lightness - 1.0).abs();
  final saturation = denominator <= 1e-9 ? 0.0 : chroma / denominator;
  double hue;
  if (maximum == r) {
    hue = 60.0 * (((g - b) / chroma) % 6.0);
  } else if (maximum == g) {
    hue = 60.0 * ((b - r) / chroma + 2.0);
  } else {
    hue = 60.0 * ((r - g) / chroma + 4.0);
  }
  return (
    hue: _wrapHue(hue),
    saturation: saturation.clamp(0.0, 1.0).toDouble(),
    lightness: lightness,
  );
}

ui.Color _hslToRgb(double hue, double saturation, double lightness) {
  final h = _wrapHue(hue);
  final s = saturation.clamp(0.0, 1.0).toDouble();
  final l = lightness.clamp(0.0, 1.0).toDouble();
  final chroma = (1.0 - (2.0 * l - 1.0).abs()) * s;
  final section = h / 60.0;
  final secondary = chroma * (1.0 - ((section % 2.0) - 1.0).abs());

  double r1;
  double g1;
  double b1;
  if (h < 60.0) {
    r1 = chroma;
    g1 = secondary;
    b1 = 0.0;
  } else if (h < 120.0) {
    r1 = secondary;
    g1 = chroma;
    b1 = 0.0;
  } else if (h < 180.0) {
    r1 = 0.0;
    g1 = chroma;
    b1 = secondary;
  } else if (h < 240.0) {
    r1 = 0.0;
    g1 = secondary;
    b1 = chroma;
  } else if (h < 300.0) {
    r1 = secondary;
    g1 = 0.0;
    b1 = chroma;
  } else {
    r1 = chroma;
    g1 = 0.0;
    b1 = secondary;
  }

  final offset = l - chroma / 2.0;
  return ui.Color.from(
    alpha: 1.0,
    red: (r1 + offset).clamp(0.0, 1.0).toDouble(),
    green: (g1 + offset).clamp(0.0, 1.0).toDouble(),
    blue: (b1 + offset).clamp(0.0, 1.0).toDouble(),
  );
}

double _wrapHue(double hue) {
  final value = hue % 360.0;
  return value < 0.0 ? value + 360.0 : value;
}
