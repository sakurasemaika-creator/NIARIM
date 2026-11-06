import 'dart:math' as math;
import 'dart:typed_data';

import 'filter_engine.dart';
import 'premultiplied.dart';

/// Isolate entry point used by full-resolution prism application.
Uint8List applyPrismFilterInIsolate(
  (
    Uint8List data,
    int width,
    int height,
    double blurPx,
    double directionDegrees,
  )
  args,
) {
  final (data, width, height, blurPx, directionDegrees) = args;
  return PrismFilterEngine().apply(
    data,
    width,
    height,
    blurPx: blurPx,
    gradientDirectionDegrees: directionDegrees,
  );
}

/// Prism effect pixels for a single layer.
///
/// The source alpha is the clipping mask. Across each separate shape of the
/// layer (each connected area of its alpha), six equal bands are painted red
/// -> green -> cyan -> blue -> purple -> red at HSV saturation 100% and
/// value/brightness 30%, so every small streak drawn on the layer gets the
/// whole rainbow, as when one prism layer is duplicated many times. The
/// alpha lock is then considered released and Gaussian blur is applied, so
/// the glow may extend beyond the original alpha boundary. The caller
/// replaces the selected/reference layer pixels with this result and
/// switches that layer to the app's Linear Dodge/additive blend mode.
class PrismFilterEngine {
  PrismFilterEngine({FilterEngine? filterEngine})
    : _filterEngine = filterEngine ?? FilterEngine();

  static const double minBlurPx = 0;
  static const double maxBlurPx = 40;
  static const double defaultBlurPx = 17;
  static const double defaultDirectionDegrees = 90;

  final FilterEngine _filterEngine;

  static double normalizeDirectionDegrees(double value) {
    final normalized = value % 360.0;
    return normalized < 0 ? normalized + 360.0 : normalized;
  }

  static double clampBlurPx(double value) =>
      value.clamp(minBlurPx, maxBlurPx).toDouble();

  Uint8List apply(
    Uint8List source,
    int width,
    int height, {
    required double blurPx,
    required double gradientDirectionDegrees,
  }) {
    if (width <= 0 || height <= 0 || source.length != width * height * 4) {
      return Uint8List.fromList(source);
    }

    final clippedBands = _buildClippedSixBands(
      source,
      width,
      height,
      gradientDirectionDegrees,
    );
    final safeBlurPx = clampBlurPx(blurPx);
    return safeBlurPx <= 0
        ? clippedBands
        // As in other painting apps, the blur amount is the Gaussian's
        // standard deviation: 17 px blends the bands into one soft streak.
        : _filterEngine.applyGaussianBlurSigma(
            clippedBands,
            width,
            height,
            safeBlurPx,
          );
  }

  Uint8List _buildClippedSixBands(
    Uint8List source,
    int width,
    int height,
    double directionDegrees,
  ) {
    final out = Uint8List(source.length);
    final radians =
        normalizeDirectionDegrees(directionDegrees) * math.pi / 180.0;
    final dx = math.cos(radians);
    final dy = math.sin(radians);

    // The six equal sections belong to each shape, not to the whole canvas
    // or layer: every connected area of the source alpha (8-neighbour) has
    // its own projected extent along the colour direction.
    final n = width * height;
    final shapeOf = Int32List(n)..fillRange(0, n, -1);
    final low = <double>[], high = <double>[];
    final queue = Int32List(n);
    for (var start = 0; start < n; start++) {
      if (source[start * 4 + 3] == 0 || shapeOf[start] >= 0) continue;
      final shape = low.length;
      var minProjection = double.infinity;
      var maxProjection = double.negativeInfinity;
      var head = 0, tail = 0;
      queue[tail++] = start;
      shapeOf[start] = shape;
      while (head < tail) {
        final p = queue[head++];
        final x = p % width, y = p ~/ width;
        final projection = x * dx + y * dy;
        minProjection = math.min(minProjection, projection);
        maxProjection = math.max(maxProjection, projection);
        for (
          var ny = math.max(0, y - 1);
          ny <= math.min(height - 1, y + 1);
          ny++
        ) {
          for (
            var nx = math.max(0, x - 1);
            nx <= math.min(width - 1, x + 1);
            nx++
          ) {
            final q = ny * width + nx;
            if (shapeOf[q] >= 0 || source[q * 4 + 3] == 0) continue;
            shapeOf[q] = shape;
            queue[tail++] = q;
          }
        }
      }
      low.add(minProjection);
      high.add(maxProjection);
    }

    for (var p = 0; p < n; p++) {
      final shape = shapeOf[p];
      if (shape < 0) continue;
      final i = p * 4;
      final sourceAlpha = source[i + 3];
      final projection = (p % width) * dx + (p ~/ width) * dy;
      final span = math.max(1e-9, high[shape] - low[shape]);
      final t = ((projection - low[shape]) / span).clamp(0.0, 1.0).toDouble();
      final rgb = _sixBandColorAt(t);
      // Premultiplied like every layer pixel.
      out[i] = premultipliedChannel(rgb.$1, sourceAlpha);
      out[i + 1] = premultipliedChannel(rgb.$2, sourceAlpha);
      out[i + 2] = premultipliedChannel(rgb.$3, sourceAlpha);
      out[i + 3] = sourceAlpha;
    }
    return out;
  }

  /// HSV(S=100%, V=30%) => max channel round(255 * .30) == 77.
  /// Six *discrete*, equally-sized bands. The repeated red is intentional.
  (int, int, int) _sixBandColorAt(double t) {
    const bands = <(int, int, int)>[
      (77, 0, 0), // red
      (0, 77, 0), // green
      (0, 77, 77), // cyan
      (0, 0, 77), // blue
      (77, 0, 77), // purple
      (77, 0, 0), // red
    ];
    final v = t.clamp(0.0, 1.0).toDouble();
    final index = math.min(5, (v * 6).floor());
    return bands[index];
  }
}
