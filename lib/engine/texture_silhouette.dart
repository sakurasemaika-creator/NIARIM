import 'dart:math' as math;
import 'dart:typed_data';

/// Lift the alpha of the original image into a flat mask without losing the
/// antialiased edge. The low cutoff retains the shape of soft source tips.
int silhouetteAlpha(int alpha) => ((alpha - 18) * 255 ~/ 32).clamp(0, 255);

const silhouetteDistanceUnits = 8;

/// Approximate distance to the silhouette, in eighths of a source texel.
Uint8List silhouetteDistance(Uint8List mask, int size) {
  const far = 255;
  final length = size * size;
  final distance = Uint8List(length);
  for (var p = 0; p < length; p++) {
    final alpha = mask[p * 4 + 3];
    distance[p] = alpha == 0 ? far : (255 - alpha) * 8 ~/ 255;
  }
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final p = y * size + x;
      var d = distance[p];
      if (x > 0) d = math.min(d, distance[p - 1] + 8);
      if (y > 0) {
        d = math.min(d, distance[p - size] + 8);
        if (x > 0) d = math.min(d, distance[p - size - 1] + 11);
        if (x + 1 < size) d = math.min(d, distance[p - size + 1] + 11);
      }
      distance[p] = d;
    }
  }
  for (var y = size - 1; y >= 0; y--) {
    for (var x = size - 1; x >= 0; x--) {
      final p = y * size + x;
      var d = distance[p];
      if (x + 1 < size) d = math.min(d, distance[p + 1] + 8);
      if (y + 1 < size) {
        d = math.min(d, distance[p + size] + 8);
        if (x > 0) d = math.min(d, distance[p + size - 1] + 11);
        if (x + 1 < size) d = math.min(d, distance[p + size + 1] + 11);
      }
      distance[p] = d;
    }
  }
  return distance;
}

double sampleSilhouetteDistance(
  Uint8List distance,
  int size,
  double x,
  double y,
) {
  final sx = x.clamp(0.0, size - 1.0);
  final sy = y.clamp(0.0, size - 1.0);
  final left = sx.floor(), top = sy.floor();
  final right = math.min(left + 1, size - 1),
      bottom = math.min(top + 1, size - 1);
  final tx = sx - left, ty = sy - top;
  final a =
      distance[top * size + left] * (1 - tx) +
      distance[top * size + right] * tx;
  final b =
      distance[bottom * size + left] * (1 - tx) +
      distance[bottom * size + right] * tx;
  final gapX = x - sx, gapY = y - sy;
  return (a * (1 - ty) + b * ty) / silhouetteDistanceUnits +
      math.sqrt(gapX * gapX + gapY * gapY);
}
