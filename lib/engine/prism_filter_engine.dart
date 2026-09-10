import 'dart:math' as math;
import 'dart:typed_data';

import 'filter_engine.dart';

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
/// The source alpha is the clipping mask. Across the selected shape's actual alpha
/// extent, six equal bands are painted red -> green -> cyan -> blue -> purple -> red
/// at HSV saturation 100% and value/brightness 30%. The alpha lock is then considered
/// released and Gaussian blur is applied, so the glow may extend beyond the original
/// alpha boundary. The caller replaces the selected/reference layer pixels with this
/// result and switches that layer to the app's Linear Dodge/additive blend mode.
class PrismFilterEngine {
  PrismFilterEngine({FilterEngine? filterEngine})
    : _filterEngine = filterEngine ?? FilterEngine();

  static const double minBlurPx = 0;
  static const double maxBlurPx = 40;
  static const double defaultBlurPx = 17;
  static const double minDirectionDegrees = 0;
  static const double maxDirectionDegrees = 359;
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
        : _filterEngine.applyGaussianBlur(
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

    // The six equal sections belong to the selected shape, not to the whole canvas.
    // Determine the projected extent using only pixels that participate in the source
    // alpha mask. This is especially important for narrow prism shapes and non-square
    // canvases, where canvas-corner bounds would otherwise compress or omit bands.
    var minProjection = double.infinity;
    var maxProjection = double.negativeInfinity;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (source[i + 3] == 0) continue;
        final projection = x * dx + y * dy;
        minProjection = math.min(minProjection, projection);
        maxProjection = math.max(maxProjection, projection);
      }
    }
    if (!minProjection.isFinite || !maxProjection.isFinite) return out;
    final span = math.max(1e-9, maxProjection - minProjection).toDouble();

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final sourceAlpha = source[i + 3];
        if (sourceAlpha == 0) continue;
        final projection = x * dx + y * dy;
        final t = ((projection - minProjection) / span)
            .clamp(0.0, 1.0)
            .toDouble();
        final rgb = _sixBandColorAt(t);
        out[i] = rgb.$1;
        out[i + 1] = rgb.$2;
        out[i + 2] = rgb.$3;
        out[i + 3] = sourceAlpha;
      }
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
