import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'spectral_pigment_data.dart';

/// Mixes two opaque paint colours the way paint mixes: around the painter's
/// colour wheel instead of through its grey centre, keeping them vivid.
///
/// [belowWeight] is the contribution of the colour already on the canvas:
/// 0 produces [selected], 1 produces [below]. See [AnalogPaintMixer] for the
/// model; [brightnessCorrection] ranges from 1 (darker), through 3
/// (neutral), to 5 (brighter) and never changes the two input colours.
ui.Color mixPerceptualColor(
  ui.Color below,
  ui.Color selected,
  double belowWeight, {
  int brightnessCorrection = 3,
}) {
  final mixer = AnalogPaintMixer(
    selected: _rgb24(selected),
    brightnessCorrection: brightnessCorrection,
  );
  return ui.Color(0xFF000000 | mixer.mix(_rgb24(below), belowWeight));
}

int _rgb24(ui.Color color) =>
    (_channel8(color.r) << 16) | (_channel8(color.g) << 8) | _channel8(color.b);

int _channel8(double value) => (value.clamp(0.0, 1.0) * 255).round().toInt();

/// Paint-like mixing of one selected colour into the colours below it.
///
/// Each pair of colours is joined by a path through OKLab:
/// - The hue turns the short way round the painter's (red–yellow–blue)
///   colour wheel, so red and blue make purple, yellow and blue green, red
///   and yellow orange — whatever the exact shades: a warm red and a blue
///   still make purple, not the brown a physical pigment mix gives. The more
///   vivid colour leads, so mixing with white, grey or black only tints or
///   shades.
/// - The chroma is the straight interpolation of the two colours' chroma,
///   so the middle stays as vivid as the ends. Colours nearly opposite on
///   that wheel (red and green, blue and orange) instead mix towards a soft
///   neutral, as paint does.
/// - The lightness is halfway between a Kubelka–Munk pigment mix of the two
///   colours' reflectance spectra (spectral.js), which darkens as paint
///   does, and the straight interpolation; the brightness correction moves
///   it.
/// - A colour sRGB cannot show that vividly at that lightness first moves
///   towards the lightness where its hue is most vivid — up to 0.08 darker,
///   but never lighter than the straight interpolation of the two colours'
///   lightness, so a mix never suddenly brightens — and only then loses
///   chroma.
///
/// The weight is measured along the path's length in OKLab, so 10% mixing
/// changes the colour by a tenth of the way.
///
/// Paths are cached per colour below, so painting over a flat area costs one
/// lookup per pixel.
class AnalogPaintMixer {
  AnalogPaintMixer({required int selected, int brightnessCorrection = 3})
    : selected = selected & 0xFFFFFF,
      brightnessCorrection = brightnessCorrection.clamp(1, 5).toInt(),
      _selectedPaint = _Paint(selected & 0xFFFFFF);

  /// The paint colour as 0xRRGGBB.
  final int selected;

  /// 1 (darker) to 5 (brighter); 3 is neutral.
  final int brightnessCorrection;

  final _Paint _selectedPaint;
  final Map<int, Float64List> _paths = {};

  static const int _maxCachedPaths = 2048;
  static const int _nodes = 11;
  static const int _stride = 6;

  /// The colour [below] (0xRRGGBB) becomes when the paint is mixed into it
  /// with [belowWeight] (0 = the paint, 1 = [below]), as 0xRRGGBB.
  int mix(int below, double belowWeight) =>
      mixNear(below, belowWeight, selected);

  /// [mix] for paint of colour [paint], a few levels from [selected]: the
  /// difference is added back in linear light, in full where the result is
  /// the paint and not at all where it is the colour below. Lets paint whose
  /// colour keeps drifting (油彩風's picked-up colour) share one mixer.
  int mixNear(int below, double belowWeight, int paint) {
    final colour = below & 0xFFFFFF;
    final own = paint & 0xFFFFFF;
    final weight = belowWeight.isNaN
        ? 0.0
        : belowWeight.clamp(0.0, 1.0).toDouble();
    if (weight <= 0.0 || colour == own) return own;
    if (weight >= 1.0) return colour;
    // Colours one level apart share a path (a smooth gradient below would
    // otherwise need a new one for nearly every pixel); the level left over
    // is added back the same way.
    final shared = colour & 0xFEFEFE;
    var path = _paths[shared];
    if (path == null) {
      if (_paths.length >= _maxCachedPaths) _paths.clear();
      path = _paths[shared] = _pathTo(_Paint(shared));
    }
    _pointOn(path, weight);
    if (shared != colour) _addDifference(colour, shared, weight);
    if (own != selected) _addDifference(own, selected, 1 - weight);
    return (_encode(_scratch[0]) << 16) |
        (_encode(_scratch[1]) << 8) |
        _encode(_scratch[2]);
  }

  static void _addDifference(int colour, int near, double share) {
    final lut = _linearLut;
    _scratch[0] += share * (lut[colour >> 16 & 0xFF] - lut[near >> 16 & 0xFF]);
    _scratch[1] += share * (lut[colour >> 8 & 0xFF] - lut[near >> 8 & 0xFF]);
    _scratch[2] += share * (lut[colour & 0xFF] - lut[near & 0xFF]);
  }

  /// Nodes (L, C, h, a, b, distance from the paint as a fraction of the
  /// whole) from the paint to [below], denser near both ends where the
  /// pigment mix changes fastest.
  Float64List _pathTo(_Paint below) {
    final paint = _selectedPaint;
    final path = Float64List(_nodes * _stride);
    _setNode(path, 0, paint.l, paint.a, paint.b);
    _setNode(path, _nodes - 1, below.l, below.a, below.b);
    final spread = math
        .max(
          ((paint.rgb >> 16 & 0xFF) - (below.rgb >> 16 & 0xFF)).abs(),
          math.max(
            ((paint.rgb >> 8 & 0xFF) - (below.rgb >> 8 & 0xFF)).abs(),
            ((paint.rgb & 0xFF) - (below.rgb & 0xFF)).abs(),
          ),
        )
        .toDouble();
    final correction = (brightnessCorrection - 3) * 0.04 * spread / 255.0;
    for (var i = 1; i < _nodes - 1; i++) {
      final t = (1 - math.cos(math.pi * i / (_nodes - 1))) / 2;
      _mixNode(path, i, paint, below, t, correction);
    }
    var total = 0.0;
    for (var i = 1; i < _nodes; i++) {
      final o = i * _stride;
      final p = o - _stride;
      final dl = path[o] - path[p];
      final da = path[o + 3] - path[p + 3];
      final db = path[o + 4] - path[p + 4];
      total += math.sqrt(dl * dl + da * da + db * db);
      path[o + 5] = total;
    }
    for (var i = 1; i < _nodes; i++) {
      final o = i * _stride + 5;
      path[o] = total > 1e-9 ? path[o] / total : i / (_nodes - 1);
    }
    path[(_nodes - 1) * _stride + 5] = 1.0;
    return path;
  }

  static void _setNode(Float64List path, int i, double l, double a, double b) {
    final o = i * _stride;
    path[o] = l;
    path[o + 1] = math.sqrt(a * a + b * b);
    path[o + 2] = math.atan2(b, a);
    path[o + 3] = a;
    path[o + 4] = b;
  }

  /// The node [t] of the way (by pigment) from [paint] to [below].
  static void _mixNode(
    Float64List path,
    int i,
    _Paint paint,
    _Paint below,
    double t,
    double correction,
  ) {
    // Kubelka–Munk: average the pigments' absorption/scattering per band,
    // each weighted by its share squared and its luminance (spectral.js).
    final paintShare = (1 - t) * (1 - t) * paint.luminance;
    final belowShare = t * t * below.luminance;
    final scale = 1 / (paintShare + belowShare);
    final paintKs = paint.ks;
    final belowKs = below.ks;
    var x = 0.0;
    var y = 0.0;
    var z = 0.0;
    for (var band = 0; band < kSpectralBands; band++) {
      final ks =
          (paintKs[band] * paintShare + belowKs[band] * belowShare) * scale;
      // 1 + ks − √(ks² + 2ks), written so it stays exact for dark pigments.
      final reflectance = 1 / (1 + ks + math.sqrt(ks * (ks + 2)));
      x += kCmfX[band] * reflectance;
      y += kCmfY[band] * reflectance;
      z += kCmfZ[band] * reflectance;
    }
    const m = kXyzToLms;
    _lmsToOklab(
      m[0] * x + m[1] * y + m[2] * z,
      m[3] * x + m[4] * y + m[5] * z,
      m[6] * x + m[7] * y + m[8] * z,
    );
    final mixedL = _scratch[0];
    final straightL = paint.l + (below.l - paint.l) * t;
    final lightness = ((mixedL + straightL) / 2).clamp(0.0, 1.0).toDouble();

    // The hue turns the short way round the painter's colour wheel; the
    // more vivid of the two colours leads, so a nearly grey one only tints.
    var turn = below.ryb - paint.ryb;
    if (turn > 180) turn -= 360;
    if (turn < -180) turn += 360;
    final lead = (1 - t) * paint.c + t * below.c;
    final share = lead > 1e-9 ? t * below.c / lead : t;
    final wheelHue = _fromRyb(paint.ryb + turn * share);
    final chroma = paint.c + (below.c - paint.c) * t;
    var a = chroma * math.cos(wheelHue);
    var b = chroma * math.sin(wheelHue);
    // Opposite colours on that wheel mix to a soft neutral, as paint does:
    // the closer to opposite (and the more vivid both are), the more the mix
    // follows the straight line between them, through grey.
    final muddy =
        _smoothstep((turn.abs() - 130) / 45) *
        _smoothstep(math.min(paint.c, below.c) / 0.08);
    if (muddy > 0) {
      a += (paint.a + (below.a - paint.a) * t - a) * muddy;
      b += (paint.b + (below.b - paint.b) * t - b) * muddy;
    }
    final hue = math.atan2(b, a);
    final cosH = math.cos(hue);
    final sinH = math.sin(hue);
    _fitToGamut(
      lightness,
      math.sqrt(a * a + b * b),
      hue,
      cosH,
      sinH,
      maxLighten: (straightL - lightness).clamp(0.0, 0.08).toDouble(),
    );
    if (correction != 0) {
      // The brightness correction moves the fitted colour; only its chroma
      // gives way, or fitting would undo the correction.
      _fitToGamut(
        (_fitted[0] + correction * 4 * t * (1 - t)).clamp(0.0, 1.0).toDouble(),
        _fitted[1],
        hue,
        cosH,
        sinH,
        maxLighten: 0,
        maxDarken: 0,
      );
    }
    final o = i * _stride;
    path[o] = _fitted[0];
    path[o + 1] = _fitted[1];
    path[o + 2] = hue;
    path[o + 3] = _fitted[1] * cosH;
    path[o + 4] = _fitted[1] * sinH;
  }

  /// The colour [weight] of the way along [path], in linear light into
  /// [_scratch].
  static void _pointOn(Float64List path, double weight) {
    var i = 1;
    while (i < _nodes - 1 && path[i * _stride + 5] < weight) {
      i++;
    }
    final o = i * _stride;
    final p = o - _stride;
    final span = path[o + 5] - path[p + 5];
    final f = span > 0 ? ((weight - path[p + 5]) / span).clamp(0.0, 1.0) : 0.0;
    final l = path[p] + (path[o] - path[p]) * f;
    var a = path[p + 3] + (path[o + 3] - path[p + 3]) * f;
    var b = path[p + 4] + (path[o + 4] - path[p + 4]) * f;
    // Between two coloured nodes of similar hue keep turning around the
    // wheel, so the chroma does not sag along the chord. Where the hues are
    // far apart or a node is nearly grey (the path passes close to grey),
    // blend straight across instead: which way round is shorter flips there
    // with the slightest change of colour.
    var turn = path[o + 2] - path[p + 2];
    if (turn > math.pi) turn -= 2 * math.pi;
    if (turn < -math.pi) turn += 2 * math.pi;
    final around =
        _smoothstep(math.min(path[p + 1], path[o + 1]) / 0.02) *
        (1 - _smoothstep((turn.abs() - math.pi / 4) / (math.pi / 4)));
    if (around > 0) {
      final c = path[p + 1] + (path[o + 1] - path[p + 1]) * f;
      final h = path[p + 2] + turn * f;
      a += (c * math.cos(h) - a) * around;
      b += (c * math.sin(h) - b) * around;
    }
    _oklabToLinear(l, a, b);
  }
}

/// A colour as paint: its OKLab coordinates and pigment absorption.
class _Paint {
  _Paint(this.rgb) : ks = Float64List(kSpectralBands) {
    final lut = _linearLut;
    var r = lut[rgb >> 16 & 0xFF];
    var g = lut[rgb >> 8 & 0xFF];
    var b = lut[rgb & 0xFF];
    const m = _rgbToLmsMatrix;
    _lmsToOklab(
      m[0] * r + m[1] * g + m[2] * b,
      m[3] * r + m[4] * g + m[5] * b,
      m[6] * r + m[7] * g + m[8] * b,
    );
    l = _scratch[0];
    a = _scratch[1];
    this.b = _scratch[2];
    c = math.sqrt(a * a + this.b * this.b);
    ryb = _toRyb(math.atan2(this.b, a));

    // Split into white plus one secondary and one primary pigment, and
    // build the reflectance from spectral.js's base spectra.
    final white = math.min(r, math.min(g, b));
    r -= white;
    g -= white;
    b -= white;
    final cyan = math.min(g, b);
    final magenta = math.min(r, b);
    final yellow = math.min(r, g);
    final red = math.max(0.0, math.min(r - b, r - g));
    final green = math.max(0.0, math.min(g - b, g - r));
    final blue = math.max(0.0, math.min(b - g, b - r));
    var y = 0.0;
    for (var band = 0; band < kSpectralBands; band++) {
      final reflectance = math.max(
        _reflectanceFloor,
        white * kSpectrumW[band] +
            cyan * kSpectrumC[band] +
            magenta * kSpectrumM[band] +
            yellow * kSpectrumY[band] +
            red * kSpectrumR[band] +
            green * kSpectrumG[band] +
            blue * kSpectrumB[band],
      );
      final absorbed = 1 - reflectance;
      ks[band] = absorbed * absorbed / (2 * reflectance);
      y += kCmfY[band] * reflectance;
    }
    luminance = y;
  }

  final int rgb;
  final Float64List ks;
  late final double l;
  late final double a;
  late final double b;
  late final double c;

  /// The hue on the painter's colour wheel, in degrees.
  late final double ryb;
  late final double luminance;
}

/// OKLab hues (degrees) of the sRGB primaries and secondaries (and violet),
/// and where they sit on the painter's red–yellow–blue colour wheel: red,
/// orange, yellow, green, cyan, blue, violet, magenta, red again.
const List<double> _wheelOklab = [
  29.2,
  53.0,
  109.8,
  142.5,
  194.8,
  264.1,
  293.9,
  328.4,
  389.2,
];
const List<double> _wheelRyb = [0, 60, 120, 180, 210, 240, 275, 315, 360];

/// OKLab hue [radians] → angle on the painter's wheel (degrees, 0–360).
double _toRyb(double radians) {
  var h = radians * 180 / math.pi;
  h %= 360;
  if (h < _wheelOklab[0]) h += 360;
  for (var i = 1; i < _wheelOklab.length; i++) {
    if (h <= _wheelOklab[i]) {
      final f =
          (h - _wheelOklab[i - 1]) / (_wheelOklab[i] - _wheelOklab[i - 1]);
      return (_wheelRyb[i - 1] + f * (_wheelRyb[i] - _wheelRyb[i - 1])) % 360;
    }
  }
  return 0;
}

/// Angle on the painter's wheel (degrees) → OKLab hue in radians.
double _fromRyb(double degrees) {
  final r = degrees % 360;
  for (var i = 1; i < _wheelRyb.length; i++) {
    if (r <= _wheelRyb[i]) {
      final f = (r - _wheelRyb[i - 1]) / (_wheelRyb[i] - _wheelRyb[i - 1]);
      final h = _wheelOklab[i - 1] + f * (_wheelOklab[i] - _wheelOklab[i - 1]);
      return h * math.pi / 180;
    }
  }
  return _wheelOklab[0] * math.pi / 180;
}

/// No paint reflects nothing. spectral.js floors reflectance at machine
/// epsilon, which makes a colour with a channel at exactly 0 absorb that
/// band about a trillion times harder than one at 1/255, so a one-level
/// change of a dark colour could swing the mix. 0.1% (darker than any of
/// the base spectra, which stay above 0.4%) only affects very dark colours.
const double _reflectanceFloor = 1e-3;

double _smoothstep(double x) {
  final v = x.clamp(0.0, 1.0).toDouble();
  return v * v * (3 - 2 * v);
}

/// sRGB 8-bit channel [value] → linear light (0–1).
double linearFromSrgb8(int value) => _linearLut[value & 0xFF];

/// Linear light → sRGB 8-bit channel, clamped.
int srgb8FromLinear(double linear) => _encode(linear);

/// sRGB 8-bit channel → linear light.
final Float64List _linearLut = () {
  final lut = Float64List(256);
  for (var i = 0; i < 256; i++) {
    final v = i / 255;
    lut[i] = v > 0.04045
        ? math.pow((v + 0.055) / 1.055, 2.4).toDouble()
        : v / 12.92;
  }
  return lut;
}();

int _encode(double linear) {
  final v = linear <= 0
      ? 0.0
      : linear >= 1
      ? 1.0
      : linear > 0.0031308
      ? 1.055 * math.pow(linear, 1 / 2.4) - 0.055
      : 12.92 * linear;
  return (v * 255).round().clamp(0, 255).toInt();
}

double _cbrt(double v) =>
    v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

/// Results of the conversions below, to keep the per-pixel path free of
/// allocations.
final Float64List _scratch = Float64List(3);
final Float64List _fitted = Float64List(2);

/// Linear sRGB → LMS and back: spectral.js's XYZ matrices, multiplied out.
const List<double> _rgbToLmsMatrix = [
  0.41222146947076294,
  0.5363325372617349,
  0.051445993267502196,
  0.21190349581782517,
  0.6806995506452345,
  0.10739695353694056,
  0.08830245919005639,
  0.2817188391361215,
  0.6299787016738223,
];
const List<double> _lmsToRgbMatrix = [
  4.07674163607596,
  -3.307711539258063,
  0.23096990318210486,
  -1.2684379732850315,
  2.609757349287688,
  -0.34131937600265727,
  -0.004196076138675495,
  -0.7034186179359363,
  1.7076146940746117,
];

/// LMS → OKLab into [_scratch].
void _lmsToOklab(double l, double m, double s) {
  final cl = _cbrt(l);
  final cm = _cbrt(m);
  final cs = _cbrt(s);
  const t = kLmsToLab;
  _scratch[0] = t[0] * cl + t[1] * cm + t[2] * cs;
  _scratch[1] = t[3] * cl + t[4] * cm + t[5] * cs;
  _scratch[2] = t[6] * cl + t[7] * cm + t[8] * cs;
}

/// OKLab → linear sRGB into [_scratch].
void _oklabToLinear(double l, double a, double b) {
  const t = kLabToLms;
  final cl = t[0] * l + t[1] * a + t[2] * b;
  final cm = t[3] * l + t[4] * a + t[5] * b;
  final cs = t[6] * l + t[7] * a + t[8] * b;
  final lm = cl * cl * cl;
  final mm = cm * cm * cm;
  final sm = cs * cs * cs;
  const m = _lmsToRgbMatrix;
  _scratch[0] = m[0] * lm + m[1] * mm + m[2] * sm;
  _scratch[1] = m[3] * lm + m[4] * mm + m[5] * sm;
  _scratch[2] = m[6] * lm + m[7] * mm + m[8] * sm;
}

bool _inGamut(double l, double c, double cosH, double sinH) {
  const t = kLabToLms;
  final a = c * cosH;
  final b = c * sinH;
  final cl = t[0] * l + t[1] * a + t[2] * b;
  final cm = t[3] * l + t[4] * a + t[5] * b;
  final cs = t[6] * l + t[7] * a + t[8] * b;
  final lm = cl * cl * cl;
  final mm = cm * cm * cm;
  final sm = cs * cs * cs;
  const m = _lmsToRgbMatrix;
  const lo = -1e-7;
  const hi = 1 + 1e-7;
  final r = m[0] * lm + m[1] * mm + m[2] * sm;
  if (r < lo || r > hi) return false;
  final g = m[3] * lm + m[4] * mm + m[5] * sm;
  if (g < lo || g > hi) return false;
  final bl = m[6] * lm + m[7] * mm + m[8] * sm;
  return bl >= lo && bl <= hi;
}

/// The lightness and chroma sRGB can show for ([l], [c]) at hue [hue], into
/// [_fitted]: first closer to the hue's most vivid lightness — at most
/// [maxDarken] darker or [maxLighten] lighter — then less chroma.
void _fitToGamut(
  double l,
  double c,
  double hue,
  double cosH,
  double sinH, {
  required double maxLighten,
  double maxDarken = 0.08,
}) {
  if (l >= 1 || l <= 0) {
    _fitted[0] = l >= 1 ? 1.0 : 0.0;
    _fitted[1] = 0.0;
    return;
  }
  _fitted[0] = l;
  _fitted[1] = c;
  if (_inGamut(l, c, cosH, sinH)) return;
  final shift = (_cuspLightness(hue) - l)
      .clamp(-maxDarken, maxLighten)
      .toDouble();
  final end = l + shift;
  if (_inGamut(end, c, cosH, sinH)) {
    var lo = 0.0;
    var hi = 1.0;
    for (var k = 0; k < 10; k++) {
      final mid = (lo + hi) / 2;
      if (_inGamut(l + shift * mid, c, cosH, sinH)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    _fitted[0] = l + shift * hi;
    return;
  }
  var lo = 0.0;
  var hi = c;
  for (var k = 0; k < 11; k++) {
    final mid = (lo + hi) / 2;
    if (_inGamut(end, mid, cosH, sinH)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  _fitted[0] = end;
  _fitted[1] = lo;
}

const int _cuspBins = 1024;

/// For each OKLab hue, the lightness of the most vivid sRGB colour (the
/// edge of the RGB cube where one channel is full and another empty).
final Float64List _cuspTable = () {
  final table = Float64List(_cuspBins);
  const corners = [
    [1.0, 0.0, 0.0],
    [1.0, 1.0, 0.0],
    [0.0, 1.0, 0.0],
    [0.0, 1.0, 1.0],
    [0.0, 0.0, 1.0],
    [1.0, 0.0, 1.0],
  ];
  const steps = 256;
  const m = _rgbToLmsMatrix;
  double? lastHue;
  var lastL = 0.0;
  for (var edge = 0; edge < corners.length; edge++) {
    final from = corners[edge];
    final to = corners[(edge + 1) % corners.length];
    for (var k = 0; k <= steps; k++) {
      final s = k / steps;
      final r = from[0] + (to[0] - from[0]) * s;
      final g = from[1] + (to[1] - from[1]) * s;
      final b = from[2] + (to[2] - from[2]) * s;
      _lmsToOklab(
        m[0] * r + m[1] * g + m[2] * b,
        m[3] * r + m[4] * g + m[5] * b,
        m[6] * r + m[7] * g + m[8] * b,
      );
      final lightness = _scratch[0];
      final hue = math.atan2(_scratch[2], _scratch[1]);
      final previous = lastHue;
      if (previous != null) {
        var turn = hue - previous;
        if (turn > math.pi) turn -= 2 * math.pi;
        if (turn < -math.pi) turn += 2 * math.pi;
        // OKLab's hue turns back by a fraction of a degree just before
        // blue; those few samples are skipped.
        if (turn > 0) {
          final start = (previous / (2 * math.pi) * _cuspBins).floor() + 1;
          final stop = ((previous + turn) / (2 * math.pi) * _cuspBins).floor();
          for (var bin = start; bin <= stop; bin++) {
            final angle = bin / _cuspBins * 2 * math.pi;
            final f = (angle - previous) / turn;
            table[bin % _cuspBins] = lastL + (lightness - lastL) * f;
          }
        }
      }
      lastHue = hue;
      lastL = lightness;
    }
  }
  return table;
}();

double _cuspLightness(double hue) {
  var x = hue / (2 * math.pi) * _cuspBins;
  x %= _cuspBins;
  final i = x.floor();
  final f = x - i;
  final table = _cuspTable;
  final a = table[i % _cuspBins];
  final b = table[(i + 1) % _cuspBins];
  return a + (b - a) * f;
}
