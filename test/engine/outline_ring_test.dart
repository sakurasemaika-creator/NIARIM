import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

/// The outline ring is every pixel that is not part of the shape and has a
/// shape pixel within the disk of the outline's radius: what looking at
/// every pixel of that disk finds (the way the filter used to search it).
Uint8List _bruteForceRing(
  Uint8List data,
  int width,
  int height, {
  required int color,
  required double widthPx,
  double erosion = 0,
}) {
  final radius = widthPx.round().clamp(1, 100);
  final result = Uint8List(data.length);
  final ca = (color >> 24) & 0xFF;
  final cr = (color >> 16) & 0xFF;
  final cg = (color >> 8) & 0xFF;
  final cb = color & 0xFF;
  final threshold = (10 + (erosion / 100).clamp(0.0, 1.0) * (254 - 10)).round();
  final r2 = radius * radius;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final idx = (y * width + x) * 4;
      if (data[idx + 3] > threshold) continue;
      var hit = false;
      for (var dy = -radius; dy <= radius && !hit; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= height) continue;
        final dxMax = math.sqrt(r2 - dy * dy).floor();
        for (var dx = -dxMax; dx <= dxMax; dx++) {
          final nx = x + dx;
          if (nx < 0 || nx >= width) continue;
          if (data[(ny * width + nx) * 4 + 3] > threshold) {
            hit = true;
            break;
          }
        }
      }
      if (hit) {
        result[idx] = (cr * ca + 127) ~/ 255;
        result[idx + 1] = (cg * ca + 127) ~/ 255;
        result[idx + 2] = (cb * ca + 127) ~/ 255;
        result[idx + 3] = ca;
      }
    }
  }
  return result;
}

Uint8List _shapes(int width, int height, int seed) {
  final random = math.Random(seed);
  final data = Uint8List(width * height * 4);
  final blobs = 1 + random.nextInt(6);
  for (var b = 0; b < blobs; b++) {
    final cx = random.nextDouble() * width;
    final cy = random.nextDouble() * height;
    final r = 0.5 + random.nextDouble() * math.min(width, height) * 0.3;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final d = math.sqrt(
          (x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy),
        );
        if (d > r + 1) continue;
        final a = d < r ? 255 : ((r + 1 - d) * 255).round();
        final i = (y * width + x) * 4;
        if (a > data[i + 3]) {
          data[i] = data[i + 1] = data[i + 2] = a ~/ 3;
          data[i + 3] = a;
        }
      }
    }
  }
  // A few lone and half-transparent pixels, some at the edges.
  for (var k = 0; k < 5; k++) {
    final x = random.nextBool()
        ? random.nextInt(width)
        : (k.isEven ? 0 : width - 1);
    final y = random.nextInt(height);
    data[(y * width + x) * 4 + 3] = random.nextInt(256);
  }
  return data;
}

void main() {
  test('the ring is the same as searching the whole disk', () {
    final engine = FilterEngine();
    var cases = 0;
    for (var seed = 0; seed < 40; seed++) {
      final width = 1 + (seed * 7) % 53;
      final height = 1 + (seed * 11) % 41;
      final data = _shapes(width, height, seed);
      for (final widthPx in const [1.0, 2.4, 6.0, 13.0, 60.0]) {
        for (final erosion in const [0.0, 40.0, 100.0]) {
          final expected = _bruteForceRing(
            data,
            width,
            height,
            color: 0xCC336699,
            widthPx: widthPx,
            erosion: erosion,
          );
          expect(
            engine.applyOutlineLayer(
              data,
              width,
              height,
              color: 0xCC336699,
              widthPx: widthPx,
              erosion: erosion,
            ),
            expected,
            reason: 'seed $seed, ${width}x$height, $widthPx px, $erosion',
          );
          cases++;
        }
      }
    }
    expect(cases, 600);
  });

  test('an empty layer has no ring', () {
    final engine = FilterEngine();
    expect(
      engine.applyOutlineLayer(
        Uint8List(20 * 10 * 4),
        20,
        10,
        color: 0xFF000000,
        widthPx: 6,
      ),
      Uint8List(20 * 10 * 4),
    );
  });
}
